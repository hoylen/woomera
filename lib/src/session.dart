part of woomera;

//----------------------------------------------------------------
/// A user's login session.
///
/// A session is created when the user logs in and is active until the
/// session is terminated. A session is terminated either when the user
/// explicitly logs out, or is automatically expired after a period of
/// inactivity. This time period is reset everytime there is new
/// activity. Activity, being the session is retrieved because a new Web page
/// request has come in that belongs to the session.
///
/// A session is created by calling the [Server.sessionCreate] method on the [Server].

class Session {
  //================================================================
  // Constants

  static const int endByTerminate = 0;
  static const int endByTimeout = 1;
  static const int endByFailureToResume = 2;

  //================================================================
  // Members

  final Server _server;

  /// Session ID
  ///
  /// Returns a unique identifier for the session which can be used
  /// for logging. It is a UUID.
  ///
  String get id => _id;

  final String _id = new Uuid().v4().replaceAll("-", ""); // random session ID

  final DateTime _created; // When the session was created

  /// Timer that expires the session after inactivity.

  Timer _expiryTimer;

  /// Duration the session remains alive after the last HTTP request.
  ///
  /// The duration the session remains alive, before it is automatically
  /// terminated. The timeout timer is restarted with this value when
  /// a new HTTP request is received that is associated with the session.

  Duration keepAlive;

  //================================================================
  /// Constructor
  ///
  /// Creates a new session in the [server].
  ///
  /// The [expiry] is the duration the session remains alive, before it
  /// is automatically terminated. The timeout timer is restarted when a new
  /// HTTP request is received that is associated with the session.

  Session(Server server, Duration expiry)
      : _server = server,
        _created = new DateTime.now() {
    if (server == null) {
      throw new ArgumentError.notNull("server");
    }

    keepAlive = expiry;

    // Set up expiry timer to expire this session if it
    // becomes inactive (i.e. is not used after some time).

    _refresh(); // create a new expiry timer

    // Register it in the Web server's list of all sessions

    assert(!_server._allSessions.containsKey(this.id));
    server._sessionRegister(this);

    _logSession.fine("[session:${id}]: created");
  }

  //----------------------------------------------------------------
  /// Sets the expiry time and restarts the timer.
  ///
  /// This method is used to change the expiry duration. Setting the expiry
  /// duration also restarts the timer.
  ///
  /// The expiry duration is also set by the [Session] constructor, so this
  /// method is only required if a different expiry duration is required
  /// after the session has been created.

  void expirySet(Duration e) {
    keepAlive = e;
    _refresh();
  }

  //================================================================
  // Properties

  final Map<String, Object> _properties = new Map<String, Object>();

  /// Set a property on the session.
  ///
  /// The application can use properties to associate arbitrary values
  /// with the session.

  void operator []=(String key, var value) {
    assert(key != null);
    _properties[key] = value;
  }

  /// Lookup a property on the session.

  Object operator [](String key) {
    assert(key != null);
    return _properties[key];
  }

  //================================================================
  // Lifecycle

  //----------------------------------------------------------------
  /// Explicitly terminate a session.
  ///
  /// This is used when the user deliberately logs out, to terminate
  /// the session without waiting for it to time out.

  Future terminate() async {
    this._expiryTimer.cancel();
    await _terminate(endByTerminate);
  }

  //----------------------------------------------------------------
  /// Refreshes the expiry time of the session.
  ///
  /// The session is set to expire in [keepAlive].

  void _refresh() {
    if (_expiryTimer != null) {
      // Cancel the old timer, if any.
      _expiryTimer.cancel();
      _expiryTimer = null;
    }

    // Create a new timer

    if (keepAlive != null) {
      _expiryTimer = new Timer(keepAlive, () async => await _terminate(endByTimeout));
    }
  }

  //----------------------------------------------------------------
  // Internal method to consistently terminate a session. Used by all code
  // that terminates a session (i.e. terminate and the refresh timeout).

  Future _terminate(int endReason) async {
    var duration = new DateTime.now().difference(_created);
    var r;
    switch (endReason) {
      case endByTerminate:
        r = "terminated";
        break;
      case endByTimeout:
        r = "timeout";
        break;
      case endByFailureToResume:
        r = "failed to resume";
        break;
      default:
        r = "?";
        break;
    }
    _logSession.fine("[session:$id]: ${r} after ${duration.inSeconds}s");

    _server._sessionUnregister(this);
    await finish(endReason);
  }

  //----------------------------------------------------------------
  /// Suspend
  ///
  /// This method is invoked after the HTTP response has been produced
  /// for a HTTP request.
  ///
  /// This method can be implemented by subclasses of [Session] to perform
  /// operations on the session at the end of using it in handling a HTTP
  /// request. For example, to persist its state to a database. After this, the
  /// [Session] will not be used again until it is restored for another HTTP
  /// request or it is terminated by the timeout timer.
  ///
  /// Note: this method is only automatically invoked if the session is set on
  /// the [Request] at the end of providing the response for it.  If the handler
  /// removes the session from the [Request], this method is not automatically
  /// invoked. For example, when a session is cleared because the user has
  /// logged out.  In that situation, if this method needs to be invoked, the
  /// handler should explicitly invoke it.
  ///
  /// This instance method is intended to be overridden by subclasses of the
  /// [Session] class.

  Future suspend(Request req) async {
    // do nothing
  }

  //----------------------------------------------------------------
  /// Resume
  ///
  /// This method is invoked when the session is restored to a HTTP request.
  ///
  /// If it returns true, the session is associated with the HTTP request.
  /// Otherwise, the session is treated as no longer being valid and is
  /// terminated.
  ///
  /// Note: this method is only automatically invoked when the session is
  /// automatically restored to a HTTP request. If the handler associates a
  /// session to the [Request], this method is not automatically invoked.  For
  /// example, when a new session is created and associated with the [Request]
  /// because a user has logged in.  In that situation, if this method needs to
  /// be invoked, the handler should explicitly invoke it.
  ///
  /// This instance method is intended to be overridden by subclasses of the
  /// [Session] class.

  Future<bool> resume(Request req) async {
    return true;
  }

  //----------------------------------------------------------------
  /// Finish method.
  ///
  /// This method is invoked when the session is ended. The [endReason]
  /// indicates why the session has ended.
  ///
  /// This instance method is intended to be overridden by subclasses of the
  /// [Session] class.

  Future finish(int endReason) async {
    // do nothing
    return;
  }
}
