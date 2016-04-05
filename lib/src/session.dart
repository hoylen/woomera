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
  /// The duration a session can remain active before it is automatically terminated.

  static Duration _defaultExpiry =
      new Duration(hours: 0, minutes: 10, seconds: 0);

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

  //================================================================
  /// Constructor
  ///
  /// Creates a new session in the [server].
  ///
  /// If the [expiry] duration is provided, initially the session lasts for
  /// that duration. This value is not remembered for refreshes: if the
  /// [refresh] method is used to refresh the session an expiry duration
  /// must be passed to it (unless the default durations are desired).
  ///
  /// If [expiry] is not provided (or is null), the [Server.sessionDuration]
  /// from the [server] is used. If the server does not have a default duration
  /// then an internal default value is used.

  Session(Server server, [Duration expiry])
      : _server = server,
        _created = new DateTime.now() {
    if (server == null) {
      throw new ArgumentError.notNull("server");
    }

    // Set up expiry timer to expire this session if it
    // becomes inactive (i.e. is not used after some time).

    refresh(expiry); // create a new expiry timer

    // Register it in the Web server's list of all sessions

    assert(!_server._allSessions.containsKey(this.id));
    server._sessionRegister(this);

    _logSession.fine("[session:${id}]: created");
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

  void terminate() {
    this._expiryTimer.cancel();
    _terminate(false);
  }

  //----------------------------------------------------------------
  /// Refreshes the expiry time of the session.
  ///
  /// The session is set to expire in [expiry] time. If [expiry] is not
  /// provided, the default in the server ([Server.sessionExpiry] is used.
  /// If that is also not set, an internal default (of 10 minutes) is used.

  void refresh([Duration expiry]) {
    if (_expiryTimer != null) {
      // Cancel the old timer. This always happens except when this method
      // is used by the Session constructor to create its first timer.
      _expiryTimer.cancel();
    }

    if (expiry == null) {
      expiry = _server.sessionExpiry ?? _defaultExpiry;
    }
    // Create a new timer
    _expiryTimer = new Timer(expiry, () {
      _terminate(true);
    });
  }

  //----------------------------------------------------------------
  // Internal method to consistently terminate a session. Used by all code
  // that terminates a session (i.e. terminate and the refresh timeout).

  void _terminate(bool byTimeOut) {
    var duration = new DateTime.now().compareTo(_created);
    _logSession.fine(
        "[session:$id]: ${(byTimeOut) ? "timeout" : "terminated"} after $duration");

    _server._sessionUnregister(this);
    finalize(byTimeOut);
  }

  //----------------------------------------------------------------
  /// Finalize method.
  ///
  /// This method is invoked when the session is ended. The [byTimeOut]
  /// is true if the sessions is ending because it has timed out, or is false
  /// if it is being ended by [terminate] being invoked.
  ///
  /// The implementation of this method in [Session] does nothing, but this
  /// method can be implemented by subclasses of it.

  void finalize(bool byTimeOut) {
    // do nothing
  }

}
