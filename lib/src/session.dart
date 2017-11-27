part of woomera;

//----------------------------------------------------------------
/// Session that is maintained between HTTP requests.
///
/// **Using sessions**
///
/// A session is used to maintain state between HTTP requests. Once a session
/// has been created, set a [Session] object as the request's [Request.session]
/// property and it should be available to subsequent requests from that client.
/// Sessions will be removed if the application explicitly invokes [terminate]
/// on the session (and clears the [Request.session] property), or if it times
/// out.
///
/// The timeout timer is automatically restarted when a new request arrives and
/// the session is restored to it. Therefore, the session is kept alive by
/// HTTP requests from the user.
///
/// The square bracket operators should be used to set and lookup application
/// values associated with the session.
///
/// For example:
///
/// ```dart
/// Future<Response> handleSuccessfulLogin(Request req) async {
///   var uid = ...;
///   ...
///   var s = new Session(req.server, new Duration(minutes: 10));
///   s["user"] = uid;
///   req.session = s; // important: gets the response to preserve the session
///   ...
/// }
///
/// Future<Response> handleActivity(Request req) async {
///   // the session (if available) will be automatically restored
///   ...
///   if (req.hasSession) {
///     // User is logged in
///     var loggedInUser = req.session["user"];
///     ...
///   } else {
///     // User is not logged in
///   }
///   ...
/// }
///
/// Future<Response> handleLogout(Request req) async {
///   assert(req.hasSession);
///   await req.session.terminate();
///   req.session = null; // important: gets the response to clear the session
///   ...
/// }
/// ```
///
/// **Preserving sessions across HTTP requests**
///
/// HTTP is a stateless protocol, so session preserving is implemented on top of
/// HTTP using either cookies or URL rewriting. The application **must** perform
/// extra steps to make this work.
///
/// _Cookies_
///
/// To use cookies, the package needs to find out if the client uses cookies.
/// Not just if it supports cookies, but if cookie support has been turned on.
/// The package detects this by seeing whether there are cookies set sent by the
/// HTTP request (any cookies, not just the special session cookie). Therefore,
/// the application must create a cookie in a previous HTTP response, **before**
/// the HTTP request where the session will be created.
///
/// ```dart
/// const String testCookieName = "browser-test";
///
/// Future<Response> handleShowLoginPage(Request req) async {
///   var resp = new ResponseBuffered(ContentType.HTML);
///
///   // Add a test cookie to determine if cookies are supported
///   var testCookie = new Cookie(testCookieName, "cookies_work!");
///   testCookie.path = req.server.basePath;
///   testCookie.httpOnly = true;
///   resp.cookieAdd(testCookie);
///   ...
///   return resp; // will _attempt_ to set the test cookie in the client.
/// }
///
/// Future<Response> handleSuccessfulLogin(Request req) async {
///   // If the client uses cookies, the test cookie will have been presented
///   // by the client with this HTTP request, and the package will know
///   // that it can use cookies to remember the session.
///
///   var uid = ...;
///   ...
///   var s = new Session(req.server, new Duration(minutes: 10));
///   s["user"] = uid;
///   req.session = s; // important!
///   ...
///   var resp = new ResponseBuffered(ContentType.HTML);
///
///   // Remove the test cookie (if any) since it has done its job
///   resp.cookieDelete(testCookieName, req.server.basePath);
///
///   return resp; // the new session will be preserved using cookies if it can.
/// }
/// ```
///
/// _URL rewriting_
///
/// URL rewriting can be used when cookies are not always available (such as
/// if the client does not support cookies, or the user has disabled them).
///
/// To support URL rewriting, every URL within the application must be rewritten
/// to add the session ID as a query parameter. This is done using the
/// [Request.rewriteUrl], [Request.ura] or [Request.sessionHiddenInputElement]
/// methods.
///
/// ```dart
///    var dest = "~/foo/bar/baz";
///
///    resp.write('<a href="${HEsc.attr(req.rewriteUrl(dest))}">link</a>);
///    resp.write('<a href="${req.ura(dest)}">link</a>);
/// ```
///
/// _Recommendation_
///
/// URL rewriting will always work as long as links containing the session ID
/// are always followed. The client cannot go to an external page and then
/// come back to a URL without the session ID. Cookies do not have this
/// limitation (and the URLs look much cleaner without the session ID in them),
/// but won't work if cookies are not used by the client. Therefore, it is
/// recommended to use both mechanisms (i.e. try to enable cookies by
/// creating a test coookie, and also perform URL rewriting throughout the
/// application) unless cookie support can be guaranteed.
///
/// **Lifecycle events**
///
/// If the application is interested in the lifecycle events of the session, it
/// should implement its own subclass of [Session] and use those objects as
/// the session. It can then implement its own [suspend], [resume] and
/// [finish] methods, which will be invoked when those events occur.
/// Note: there is no "start" method, because the application can use the
/// constructor for that purpose.
///
/// An application might be interested in these events to persist session
/// properties (e.g. save session properties in an external database). The
/// base implementation keeps the sessions and their properties in memory.
///
/// The current API allows session properties to be saved, but the
/// sessions themselves are still all maintained in memory. If this does not
/// satisfy your needs, please raise an issue for the API to be
/// enhanced.

class Session {
  //================================================================
  // Constants

  /// Reason for the [finish] method: sesson's [terminate] method was invoked.

  static const int endByTerminate = 0;

  /// Reason for the [finish] method: session's timer had timed out.

  static const int endByTimeout = 1;

  /// Reason for the [finish] method: session's [resume] method returned false.

  static const int endByFailureToResume = 2;

  //================================================================
  // Members

  final Server _server;

  /// Session ID
  ///
  /// The unique identifier for the session which can be used
  /// for logging. It is a UUID.

  final String id =
      (new Uuid().v4() as String).replaceAll("-", ""); // random session ID

  final DateTime _created; // When the session was created

  /// Timer that expires the session after inactivity.

  Timer _expiryTimer;

  /// Timer duration. For resetting the timer when a HTTP request is received
  /// and the session is restored to it.

  Duration _timeout;

  //================================================================
  /// Constructor
  ///
  /// Creates a new session and associate it to the [server].
  ///
  /// The [timeout] is the duration the session remains alive, before it
  /// is automatically terminated. The timeout timer is restarted when a new
  /// HTTP request is received that is associated with the session.
  ///
  /// The [timeout] duration cannot be null.
  ///
  /// The expiry duration can be changed using the [timeout] method.

  Session(Server server, Duration timeout)
      : _server = server,
        _created = new DateTime.now() {
    if (server == null) {
      throw new ArgumentError.notNull("server");
    }
    if (timeout == null) {
      throw new ArgumentError.notNull("timeout");
    }

    _timeout = timeout;

    // Set up expiry timer to expire this session if it
    // becomes inactive (i.e. is not used after some time).

    _refresh(); // create a new expiry timer

    // Register it in the Web server's list of all sessions

    assert(!_server._allSessions.containsKey(id));
    server._sessionRegister(this);

    _logSession.fine("[session:$id]: created");
  }

  //----------------------------------------------------------------
  /// Duration the session remains alive after the last HTTP request.
  ///
  /// The duration the session remains alive, before it is automatically
  /// terminated. The timeout timer is restarted with this value when
  /// a new HTTP request is received that is associated with the session.
  ///
  /// This value is set by the session's constructor or by the [timeout]
  /// setter.

  Duration get timeout => _timeout;

  //----------------------------------------------------------------
  /// Sets the expiry duration and restarts the timer to that new value.
  ///
  /// This method is used to change the expiry duration. Setting the expiry
  /// duration also restarts the timer.
  ///
  /// The expiry duration is also set by the [Session] constructor, so this
  /// method is only required if a different expiry duration is required
  /// after the session has been created.
  ///
  /// The [newTimeout] cannot be null. Since all active sessions are kept in
  /// memory and explicit terminate usually can't be guaranteed, they must
  /// expire otherwise the server could run out of memory.

  set timeout(Duration newTimeout) {
    if (newTimeout == null) {
      throw new ArgumentError.notNull("timeout");
    }
    _timeout = newTimeout;
    _refresh();
  }

  //================================================================
  // Properties

  final Map<String, Object> _properties = {};

  /// Set a property on the session.
  ///
  /// The application can use properties to associate arbitrary values
  /// with the session.

  void operator []=(String key, dynamic value) {
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
  /// This is used when an application wants to terminate a session without
  /// without waiting for it to time out.
  ///
  /// Important: the application must also remove the session from the [Request]
  /// before the request handler returns.

  Future terminate() async {
    _expiryTimer.cancel();
    _expiryTimer = null;
    await _terminate(endByTerminate);
  }

  //----------------------------------------------------------------
  /// Refreshes the expiry time of the session.
  ///
  /// The session is set to expire in [_timeout].

  void _refresh() {
    if (_expiryTimer != null) {
      // Cancel the old timer. This always happens except when this method is
      // invoked for the very first time by the session constructor.
      _expiryTimer.cancel();
      _expiryTimer = null;
    }

    // Create a new timer

    if (_timeout != null) {
      _expiryTimer = new Timer(_timeout, () => _terminate(endByTimeout));
    }
  }

  //----------------------------------------------------------------
  // Internal method to consistently terminate a session. Used by all code
  // that terminates a session (i.e. terminate and the refresh timeout).

  Future _terminate(int endReason) async {
    final duration = new DateTime.now().difference(_created);
    String r;
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
    _logSession.fine("[session:$id]: $r after ${duration.inSeconds}s");

    _server._sessionUnregister(this);
    await finish(endReason);
  }

  //----------------------------------------------------------------
  /// Invoked when the session is suspended.
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
  /// The base implementation does nothing.
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
  /// Invoked when a session is resumed.
  ///
  /// This method is invoked when the session is restored to a HTTP request.
  ///
  /// If it returns true, the session is associated with the HTTP request.
  /// Otherwise, the session is treated as no longer being valid and is
  /// terminated.
  ///
  /// The base implementation does nothing and always returns true.
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

  Future<bool> resume(Request req) async => true;

  //----------------------------------------------------------------
  /// Invoked when a session is terminated.
  ///
  /// This method is invoked when the session is ended. The [endReason]
  /// indicates why the session has ended. Possible values are:
  ///
  /// - [endByTerminate] the application explicitly terminated the session.
  /// - [endByTimeout] the session was automatically terminated because it had
  ///   timed out.
  /// - [endByFailureToResume] the [resume] method returned false, so the
  ///   session can no longer be used.
  ///
  /// The base implementation does nothing.
  ///
  /// This instance method is intended to be overridden by subclasses of the
  /// [Session] class.

  Future finish(int endReason) async {
    // do nothing
  }
}
