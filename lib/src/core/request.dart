part of core;

//================================================================
/// Request class.
///
/// Represents a HTTP request.
///
/// The framework will invoke the request handlers or exception handlers
/// of a [Server] with an instance of this class. That request object will
/// be created from the real HTTP request.
///
/// For testing, with the [Server.simulate] method, instances can be created
/// using the [Request.simulated] constructor or one of the convenience
/// constructors: [Request.simulatedGet] or [Request.simulatedPost].

class Request {
  //================================================================
  // Constructors

  //----------------------------------------------------------------
  /// Constructor
  ///
  /// Creates a Woomera Request from a [HttpRequest].
  ///
  /// This is only used internally, when the Woomera server receives a HTTP
  /// request.

  Request(HttpRequest hReq, String id, Server server)
      : _id = id,
        _server = server,
        _coreRequest = _CoreRequestReal(hReq),
        _coreResponse = _CoreResponseReal(hReq.response) {
    _logRequest.fine(
        '[$id] ${_coreRequest.method} ${_coreRequest.internalPath(server._basePath)}');

    _logRequestHeader.finer(() {
      // Log request
      final buf = StringBuffer('[$id] HTTP headers:');
      _coreRequest.headers.forEach((name, values) {
        buf.write('\n  $name: ');
        if (values.isEmpty) {
          buf.write('<noValue>');
        } else if (values.length == 1) {
          buf.write('${values[0]}');
        } else {
          var index = 1;
          for (var v in values) {
            buf.write('\n  [${index++}] $v');
          }
        }
      });
      return buf.toString();
    });

    // Check length of URI does not exceed limits

    var length = hReq.uri.path.length;

    if (hReq.uri.hasQuery) {
      length += hReq.uri.query.length;
    }

    if (hReq.uri.hasFragment) {
      length += hReq.uri.fragment.length;
    }

    if (server.urlMaxSize < length) {
      throw PathTooLongException();
    }

    // Set queryParams from the request
    // Do not use uri.queryParams, because it does not handle repeating keys.

    queryParams = RequestParams._fromQueryString(hReq.uri.query);

    // Determine method used for maintaining (future) sessions

    if (_coreRequest.cookies.isNotEmpty) {
      _sessionUsingCookies = true; // got cookies, so browser must support them
    } else {
      // Cannot detect from HTTP request whether cookies are supported or not.
      // Use default setting from server.
      _sessionUsingCookies = _server.sessionCookieAlways;
    }

    _constructorCommon();
  }

  //----------------------------------------------------------------
  /// Creates a simulated request.
  ///
  /// A simulated HTTP request is used for testing a server. The simulated
  /// request is "sent" to the server using the [Server.simulate] method.
  /// This is an alternative to testing by sending real HTTP requests to it
  /// over the network.
  ///
  /// The request has the HTTP [method] (e.g. "GET", "POST", "PATCH") and
  /// is for the [internalPath] (a string starting with "~/").
  ///
  /// The [id] is an identifier for the request. This identifier is used in any
  /// log entries about the request. If not provided, an identifier will
  /// be generated ("SIM:" followed by a number).
  ///
  /// The [sessionId] is identifier of a session. Sessions are optional.
  ///
  /// The [queryParams] contain the query parameters of the request.
  /// Conceptually, the URL of the request would include the _internalPath_
  /// and any _queryParameters_.
  ///
  /// The [connectionInfo] contains the information about the connection the
  /// request was sent over. In a simulated request, no real network connection
  /// is involved. But a value can be provided for it, for use by the
  /// request handler (e.g. to test logging or to allow list checking).
  ///
  /// The client [certificate] for the TLS connect the request was sent over.
  /// In a simulated request, no real TLS connection is involved. But a
  /// value can be provided for the client certificate, for use by the request
  /// handler (e.g. to test client authentication using client certificates).
  ///
  /// The HTTP [headers] contains the headers of the request.
  ///
  /// The [cookies] contains the cookies of the request.
  ///
  /// The body of the request can be provided as [bodyBytes] or [bodyStr].
  /// If neither is provided, the body is empty. Do not provide both.
  /// If the request handler retrieves the body as a stream using
  /// [Request.bodyStream], [bodyStreamEventSize] is the maximum number
  /// of bytes in each event from the stream.

  Request.simulated(String method, String internalPath,
      {String? id,
      String? sessionId,
      RequestParams? queryParams,
      HttpConnectionInfo? connectionInfo,
      X509Certificate? certificate,
      SimulatedHttpHeaders? headers,
      List<Cookie>? cookies,
      String? bodyStr,
      List<int>? bodyBytes,
      int? bodyStreamEventSize,
      this.postParams})
      : _id = id ?? _defaultSimulatedId,
        queryParams = queryParams ?? RequestParams._internalConstructor(),
        _sessionUsingCookies = true,
        _coreRequest = _CoreRequestSimulated(method, internalPath,
            sessionId: sessionId ?? '',
            queryParams: queryParams,
            certificate: certificate,
            connectionInfo: connectionInfo,
            headers: headers ?? SimulatedHttpHeaders(),
            cookies: cookies ?? <Cookie>[],
            bodySteamEventSize: bodyStreamEventSize,
            bodyStr: bodyStr,
            bodyBytes: bodyBytes),
        _coreResponse = _CoreResponseSimulated() {
    _constructorCommon();
  }

  // All simulated requests force the use of cookies to maintain session.
  //
  //     _sessionUsingCookies = true
  //
  // When the [SimulatedResponse] is produced, the session cookie is
  // extracted to populate the sessionId.

  //----------------
  /// Convenience method for creating a simulated GET request.
  ///
  /// See [Request.simulated] for details.

  Request.simulatedGet(String internalPath,
      {String? sessionId,
      String? id,
      RequestParams? pathParams,
      RequestParams? queryParams,
      HttpConnectionInfo? connectionInfo,
      X509Certificate? certificate,
      SimulatedHttpHeaders? headers,
      List<Cookie>? cookies,
      String? bodyStr,
      List<int>? bodyBytes,
      int? bodyStreamEventSize})
      : _id = id ?? _defaultSimulatedId,
        _server = Server(),
        pathParams = pathParams ?? RequestParams._internalConstructor(),
        queryParams = queryParams ?? RequestParams._internalConstructor(),
        _sessionUsingCookies = true,
        _coreRequest = _CoreRequestSimulated('GET', internalPath,
            sessionId: sessionId ?? '',
            queryParams: queryParams,
            certificate: certificate,
            connectionInfo: connectionInfo,
            headers: headers ?? SimulatedHttpHeaders(),
            cookies: cookies ?? <Cookie>[],
            bodySteamEventSize: bodyStreamEventSize,
            bodyStr: bodyStr,
            bodyBytes: bodyBytes),
        _coreResponse = _CoreResponseSimulated() {
    // Important: this must be a constructor and not a factory.
    // Some tests may implement their own subclass of it.
    _constructorCommon();
  }

  //----------------
  /// Constructor for a simulated Post request.
  ///
  /// Note: [postParams] is mandatory, but it can contain no actual parameters.
  ///
  /// See [Request.simulated] for details.

  Request.simulatedPost(String internalPath, this.postParams,
      {String? sessionId,
      String? id,
      RequestParams? queryParams,
      HttpConnectionInfo? connectionInfo,
      X509Certificate? certificate,
      SimulatedHttpHeaders? headers,
      List<Cookie>? cookies,
      String? bodyStr,
      List<int>? bodyBytes,
      int? bodyStreamEventSize})
      : _id = id ?? _defaultSimulatedId,
        queryParams = queryParams ?? RequestParams._internalConstructor(),
        _sessionUsingCookies = true,
        _coreRequest = _CoreRequestSimulated('POST', internalPath,
            sessionId: sessionId ?? '',
            queryParams: queryParams,
            certificate: certificate,
            connectionInfo: connectionInfo,
            headers: headers ?? SimulatedHttpHeaders(),
            cookies: cookies ?? <Cookie>[],
            bodySteamEventSize: bodyStreamEventSize,
            bodyStr: bodyStr,
            bodyBytes: bodyBytes),
        _coreResponse = _CoreResponseSimulated() {
    // Important: this must be a constructor and not a factory.
    // Some tests may implement their own subclass of it.
    _constructorCommon();
  }

  //----------------
  // Code common to all constructors.

  void _constructorCommon() {
    if (queryParams.isNotEmpty) {
      _logRequestParam.finer(() => '[$id] query: $queryParams');
    }
  }

  //================================================================

  // Used to generate a unique ID for simulated requests, if none was set on it.

  static int _simulatedRequestCount = 0;

  static String get _defaultSimulatedId => 'SIM:${++_simulatedRequestCount}';

  //================================================================

  //----------------------------------------------------------------
  // Internal method used to populate the [postParams] value.

  Future _postParamsInit(int maxPostSize) async {
    // Typically, this is for POST requests, but it actually handles any HTTP
    // request where the MIME type is "application/x-www-form-urlencoded".
    // For example, it could be a PUT request.

    final ct = _coreRequest.headers.contentType;

    if (ct != null && ct.mimeType == 'application/x-www-form-urlencoded') {
      // Read in the contents of the request

      // Get the request body into a string
      //
      // URL-encoded form data only contains ASCII characters (when properly
      // encoded). But here we'll use _bodyStr_ which interprets the body bytes
      // as UTF-8: to avoid extra code to decode ASCII (which is a subset of
      // UTF-8) and just in case a non-compliant client sends non-ASCII code
      // points in the common UTF-8 encoding.
      //
      // In the extremely unlikely situation where a non-compliant client
      // incorrectly sends non-ASCII code points and doesn't use UTF-8, this
      // code will raise an encoding exception or silently produce the wrong
      // result. Undefined behaviour is expected if the client produces wrong
      // data! It could could try to detect a character encoding in the header,
      // but that would be an overkill, since there is no charset parameter for
      // this media type.
      //
      // So treating the body as UTF-8 is good enough. It works for correct
      // input, and the behaviour is undefined for incorrect input.

      final str = await _coreRequest.bodyStr(maxPostSize); // assumes UTF-8

      // Parse the string into parameters

      postParams = RequestParams._fromQueryString(str);

      // Logging
      //
      // Note: postParams is not null, because it was set in the above statement

      if (postParams!.isNotEmpty) {
        _logRequestParam
            .finer(() => '[$id] ${_coreRequest.method}: $postParams');
      }
    }
  }

  //================================================================
  /// The underlying HTTP request.
  ///
  /// An instance of [HttpRequest] the produced the context.
  ///
  /// Applications do not have access this member, because it is not available
  /// in a simulated request (created using [Request.simulated]). So using it
  /// would prevent the application from being tested using the simulation.

  final _CoreRequest _coreRequest;

  /// Returns the underlying [HttpRequest].
  ///
  /// This member should not be used unless absolutely necessary.
  /// Please use [method], [requestPath], [connectionInfo], [certificate],
  /// [headers], [cookies], [bodyBytes], [bodyStr] or [bodyStream] to obtain
  /// information about the request.
  ///
  /// It is only available for [Request] objects from real HTTP requests, and
  /// will throw an [UnsupportedError] exception when called on a simulated
  /// _Request_. Therefore, using it will prevent the server from being
  /// tested using [Server.simulate].
  ///
  /// If a value is required from [HttpRequest], consider submitting an issue
  /// to have it exposed by [Request] in a manner that allows it to be used for
  /// both real and simulated HTTP requests.

  @Deprecated('Use methods to get info about a request; not the request itself')
  HttpRequest get request {
    final _cr = _coreRequest;
    if (_cr is _CoreRequestReal) {
      return _cr._httpRequest;
    } else {
      throw UnsupportedError('request not available on simulated Requests');
    }
  }

  final _CoreResponse _coreResponse;

  /// Returns the [SimulatedResponse] from the _CoreResponse object.
  ///
  /// This method only works for the Request is for a simulated HTTP request.

  SimulatedResponse get _simulatedResponse {
    final _cr = _coreResponse;
    if (_cr is _CoreResponseSimulated) {
      return SimulatedResponse(_cr, _server.sessionCookieName);
    } else {
      throw StateError('not a SimulatedRequest');
    }
  }

  //================================================================
  // Members and accessors

  //----------------------------------------------------------------
  /// An identity for the request.
  ///
  /// This is commonly used in log messages:
  ///
  ///     myLog.info('[${req.id}] something happened');
  ///
  /// Note: the value is a [String], because its value is the [Server.id] from
  /// the server (which is a String) concatenated with the request number.
  /// By default, the server ID is the empty string, so this value looks like
  /// a number even though it is a String. But the application can set the
  /// [Server.id] to a non-empty String.

  String get id => _id;

  final String _id;

  //----------------------------------------------------------------
  /// The server that received this request.
  ///
  /// Identifies the [Server] that received the HTTP request.

  Server get server => _server;

  /// Server the request is from.
  ///
  /// In a normal request, the server is initialized by the constructor of
  /// the Request.
  ///
  /// In a simulated request, the request is created but the server is only
  /// assigned when a simulation is performed with it and a server.
  /// With a simulated request, this value may or may not have a value outside
  /// a simulated run. Outside a simulated run, any value it may or may not
  /// have should not be used.

  late Server _server;

  /*
  // This is only used by the [Server.simulate] method.

  void _serverClear() {
    assert(_server != null, '_serverSet invoked incorrectly');
    _server = null;
  }
   */

  //================================================================
  // Request details

  //----------------------------------------------------------------
  /// Request HTTP method
  ///
  /// For example, 'GET' or 'POST'.

  String get method => _coreRequest.method;

  //----------------------------------------------------------------
  // Request path
  //
  // There are three possible ways to retrieve the (same) path value.

  /// The request path as a String.
  ///
  /// The request path is the path of the internal URL. That is, it excludes
  /// the host, port, base path, query parameters and fragment identifiers
  ///
  /// This method returns the request path as a string. This is a value that
  /// starts with '~/' (e.g. '~/foo/bar/baz').
  ///
  /// This is a value that starts with '~/'.

  String requestPath() => _coreRequest.internalPath(_server._basePath);

  //----------------
  /// The request path as a list of segments.
  ///
  /// For example, if [requestPath] would have returned "~/foo/bar/baz",
  /// this method would return ["foo", "bar, "baz"].
  ///
  /// Note: since this is equivalent to the internal URL, segments from the
  /// server base path are not included.
  ///
  /// See [requestPath] for more information.

  List<String>? get _pathSegments =>
      _coreRequest._pathSegments(_server._basePath);

  //----------------------------------------------------------------
  /// Information about the client connection.
  ///
  /// Returns the client connection information.
  /// Returns null if the socket is not available.

  HttpConnectionInfo? get connectionInfo => _coreRequest.connectionInfo;

  //----------------------------------------------------------------
  /// Client certificate for client authenticated TLS connections.
  ///
  /// Returns the client certificate used to establish the TLS connection
  /// the request was sent over. Returns null if there was no client certificate
  /// (either because the connection was not over TLS, the server did not
  /// request the client to present a certificate, or the client did not provide
  /// one).

  X509Certificate? get certificate => _coreRequest.certificate;

  //----------------------------------------------------------------
  /// HTTP request headers.

  HttpHeaders get headers => _coreRequest.headers;

  //----------------------------------------------------------------
  /// Cookies
  ///
  /// Warning: this may include the session cookie created by the Woomera
  /// session feature.

  Iterable<Cookie> get cookies => _coreRequest.cookies;

  //================================================================
  // Body of the request

  /// The entire body of the request as a string.
  ///
  /// The bytes in the body of the HTTP request are interpreted as an UTF-8
  /// encoded string. If the bytes cannot be decoded as UTF-8, a
  /// [FormatException] is thrown.
  ///
  /// If the body has more than [maxBytes] bytes, [PostTooLongException] is
  /// thrown. Set the _maxBytes_ to a value that is not less than the maximum
  /// size the request handler ever expects to receive. This limit prevents
  /// incorrect/malicious clients from flooding the request handler with
  /// too much data in the body (e.g. several gigabytes).
  /// To retrieve arbitrarily large bodies, use [bodyStream].
  ///
  /// Note: the maximum number of **characters** allowed in the string may be
  /// equal to or less than the specified maximum number of **bytes**.
  /// This is because a single Unicode code point may require multiple bytes
  /// to represent in UTF-8.

  Future<String> bodyStr(int maxBytes) => _coreRequest.bodyStr(maxBytes);

  /// The entire body of the request as a list of bytes.
  ///
  /// Returns a Future to a list of integers.
  ///
  /// Throws [PostTooLongException] if the HTTP request body is longer than
  /// [maxBytes]. To retrieve arbitrarily large bodies, use [bodyStream].

  Future<List<int>> bodyBytes(int maxBytes) => _coreRequest.bodyBytes(maxBytes);

  /// The body of the request as a stream of bytes.
  ///
  /// There is no limit on the size of the body that can be retrieved using this
  /// stream, unlike with [bodyStr] or [bodyBytes].
  ///
  /// Returns a Stream of [Uint8List].
  ///
  /// Throws a [StateError] if  _bodyStr_, _bodyBytes_ or _bodyStream_ has
  /// previously been invoked. The stream can only be retrieved once.
  ///
  /// ## Example
  ///
  /// ```dart
  /// Future<void> processBody(Request req) async {
  ///   var total = 0;
  ///   var count = 0;
  ///   await for (final chunk in req.bodyStream()) {
  ///     count++;
  ///     total += chunk.length;
  ///     print('[$count] ${chunk.length} bytes');
  ///     ...
  ///   }
  ///   print('body: $total bytes, received on $count events from bodyStream');
  /// }
  /// ```

  Stream<Uint8List> bodyStream() => _coreRequest.bodyStream();

  //================================================================

  //----------------------------------------------------------------
  // Parameters

  /// The three different sources of parameters.
  ///
  /// - path - from matching components in the request path
  /// - query - URI query parameters
  /// - post - from POST requests
  ///
  /// For example:
  ///     POST http://example.com/foo/bar/baz?a=1&b=2
  ///     x=8&y=9
  ///
  ///
  /// The parameters from the URL path.

  late RequestParams pathParams;

  // The [pathParams] will be set by the server when it processes the request.

  //----------------
  /// The parameters from a 'application/x-www-form-urlencoded' request:
  /// typically from a POST request from a HTML form.
  ///
  /// This is not null if the context is a request with a MIME type of
  /// 'application/x-www-form-urlencoded'.
  ///
  /// Typically, this is associated with a POST request. For example, from
  /// a HTML form submitted with "method=POST". But there can be other HTTP
  /// methods that use that format; and there can be POST requests that do not
  /// use that format (e.g. POST requests with JSON in the body).
  /// Therefore, the name "postParams" is sometimes incorrect, but it is a
  /// nicer name than "xWwwFormUrlencodedParams".

  RequestParams? postParams;

  // The [postParams] will be set by the server when it processes the request.
  // The code will invoke [_postParamsInit] to do it.

  //----------------
  /// The parameters from the query parameters in the URL.
  ///
  /// This is never null when the context is created, but there is nothing
  /// stopping a filter from modifying it.
  ///
  /// The parameters from the URL path.

  late RequestParams queryParams;

  // The [queryParams] needs to be set by the subclass constructors.

  //================================================================
  // Session

  /// The session associated with the context or null.
  ///
  /// If the HTTP request indicated that it belongs to a session (either by
  /// presenting a session cookie or URI parameter) the session will be
  /// automatically retrieved and this member set to it. That is, if the
  /// session has not been terminated or has expired. If there is no session,
  /// this will be set to null.
  ///
  /// The request handler can set this member to a non-null value. That will
  /// cause the session to be indicated in the HTTP response (either by
  /// setting a session cookie or rewriting URLs).
  ///
  /// The request handler can also set this member to null to make the browser
  /// no longer identify future requests as belonging to a session. For example,
  /// if a session cookie was presented in the HTTP request, it will be deleted
  /// by the HTTP response.
  ///
  /// Note: sessions should be set/cleared before calling rewriteURL.

  Session? session;

  /// Indicates how sessions are indicated to the browser.
  ///
  /// By default, this is set to false to use URL rewriting. That is the most
  /// reliable mechanism since browsers might not have cookie support enabled.
  /// But if the HTTP request contained some cookies (any cookie, not just the
  /// session one) this is set to true.
  ///
  /// A session handler should not change the value of this member. Since the
  /// Web server normally does not have a reliable mechanism of determining if
  /// the browser supports cookies or not.
  ///
  /// A better approach is for the application to set some cookie (any cookie)
  /// before establishing the session. If the browser supports cookies, then it
  /// will be returned and this member will automatically be set to true.
  ///
  /// In summary, the application should not need to examine or change this
  /// member. It should simply attempt to set a cookie before it tries to
  /// set a session.

  late bool _sessionUsingCookies;

  /// Indicated if a session was established from a cookie in the HTTP request.
  ///
  /// The only purpose of this member is so the [Response] can know that it
  /// needs to explicitly delete the session cookie if the session is cleared.

  // Note: this is modified to true in "core_request.dart", so it is
  // deliberately not a final member.
  //
  // ignore: prefer_final_fields
  bool _haveSessionCookie = false;

  //----------------------------------------------------------------
  /// Attempt to restore the session (if there was one).
  ///
  /// Using the cookies, query parameters or POST parameters, to restore
  /// a session for the request.
  ///
  /// If a session was successfully found and resumed, the [session] member is
  /// set to it. Otherwise, _session_ is set to null.
  ///
  /// Also, [_haveSessionCookie] is set depending on if there was a cookie with
  /// a session ID. Note: this may be set to true even if the the _session_ is
  /// set to null. For example, if the value from the cookie is unknown or is
  /// for a session that has expired (i.e. cannot be resumed).
  ///
  /// Any session query parameter and/or POST parameter are removed. So the
  /// application never sees them. But any session cookie(s) are not removed
  /// (since the list is read only).
  ///
  /// Note: it is an error for multiple session parameters with different values
  /// to be defined. If that happens, a severe error is logged to the
  /// 'woomera.session' logger and they are all ignored (i.e. no session is
  /// restored). However, multiple session parameters with the same value is
  /// permitted (this could happen if the program uses
  /// [sessionHiddenInputElement] and did not set includeSession to false when
  /// rewriting the URL for the 'action' attribute of the form element).

  Future<void> _sessionRestore() async {
    // Attempt to retrieve a session ID from the request.
    // Sets [_haveSessionCookie] too.

    final sessionId = _coreRequest._extractSessionId(server, this);

    // Retrieve session (if any)

    session = null; // assume no session, unless one is successfully resumed

    if (sessionId.isNotEmpty) {
      // Session ID was found: try to find session with that ID and resume it

      /*
      Session? candidateSession;
      if (_server != null) {
        // Real request
        candidateSession = _server._sessionFind(sessionId);
      } else {
        // Simulated request
        candidateSession = null;
      }

       */

      final candidateSession = _server._sessionFind(sessionId);

      if (candidateSession != null) {
        // Session with matching ID found: try to resume using it

        if (await candidateSession.resume(this)) {
          _logSession.finest('[$id] [session:$sessionId] resumed');
          candidateSession._refresh(); // restart timeout timer
          session = candidateSession; // successfully resumed the session
        } else {
          _logSession.finest("[$id] [session:$sessionId] can't resume");
          await candidateSession._terminate(SessionTermination.resumeFailed);
        }
      } else {
        _logSession.finest('[$id] [session:$sessionId] not found');
      }
    }

    // At this point [session] has been set or not.
  }

  //----------------------------------------------------------------
  // Invoked by the server at the very end of processing a request (after
  // the response's `finish` method is invoked.
  //
  // Causes the session's suspend method to be invoked, if there is a session.

  Future _sessionSuspend() async {
    final _session = session;
    if (_session != null) {
      await _session.suspend(this);
    }
  }

  //================================================================
  // Internal methods

  //----------------------------------------------------------------

  //----------------------------------------------------------------
  /// Returns HTML for a hidden form input for the session parameter.
  ///
  /// If there is no session (i.e. [session] is null) or cookies are being used
  /// to preserve the session, returns the empty string.
  ///
  /// This method can be used to maintain the session across form submissions
  /// when URL rewriting is being used (i.e. cookies are not being used).
  ///
  /// There are two ways to preserve the session when using forms. Applications
  /// must use one of these methods, if it needs to preserve sessions and
  /// cookies might not be available.
  ///
  /// Method 1: Rewrite the method URL, to preserve the session with a query
  /// parameter.
  ///
  /// ```html
  /// <form method="POST" action="${HEsc.attr(req.rewriteUrl("~/form/processing/url"))}">
  ///   ...
  /// </form>
  /// ```
  ///
  /// Method 2: Add a hidden input, to preserve the session with a POST
  /// parameter.
  ///
  /// ```html
  /// <form method="POST" action="${HEsc.rewriteUrl("~/form/processing/url", includeSession: false)}">
  ///   ${req.sessionHiddenInputElement()}
  ///   ...
  /// </form>
  /// ```
  ///
  /// The first method is consistent with how links are outputted when not
  /// using forms, but it is inconsistent to use both query parameters with a
  /// POST request. The second method does not mix both query and POST
  /// parameters. Both methods work on most browsers with the "POST" method.
  ///
  /// The second method **must** be used when the method is "GET". This is
  /// because the Chrome browser drops the query parameters found in the
  /// "action" attribute when the method is "GET".
  ///
  /// The second method is recommended, because the pattern will be consistent
  /// between POST and GET methods, even though it is slightly different from
  /// when a URL is used outside a form's method attribute.
  ///
  /// If cookies are being used to preserve the session, either method will
  /// produce the same HTML.
  ///
  /// Note: this method is on the request object, even though it ultimately
  /// affects the HTTP response. This is because the request object carries the
  /// context for the request and the response. The session is a part of that
  /// context.

  String sessionHiddenInputElement() {
    final _server = server;
    final _session = session;

    if (_session != null && !_sessionUsingCookies) {
      // Require hidden POST form parameter to preserve session
      final name = HEsc.attr(_server.sessionParamName);
      final value = HEsc.attr(_session.id);
      return '<input type="hidden" name="$name" value="$value"/>';
    } else {
      return ''; // hidden POST form parameter not required
    }
  }

  //================================================================
  // Response producing methods

  //----------------------------------------------------------------

  /// Sets the headers in the response.

  void _produceResponseHeaders(int status, ContentType? ct,
      List<Cookie> cookies, Map<String, List<String>> headers) {
    _coreResponse.status = status;
    _coreResponse.cookies.addAll(cookies);

    // Remove default headers (i.e. x-frame-options, x-xss-protection
    // and x-content-type-options).

    _coreResponse.headers.clear();

    if (ct != null) {
      // Only set the contentType if there is one.
      // Redirection responses don't: they will have the default (text/plain).
      _coreResponse.headers.contentType = ct;
    }

    // Add all other desired ones

    for (var name in headers.keys) {
      final values = headers[name];
      if (values != null) {
        for (var value in values) {
          _coreResponse.headers.add(name, value);
        }
      }
    }
  }

  /// Sets the body of the response using a sequence of bytes.
  ///
  /// This is used by the [ResponseBuffered._finish] method to produce the
  /// response body.

  void _outputBodyBytes(List<int> bodyBytes) {
    _coreResponse.setBodyFromBytes(bodyBytes);
  }

  /// Sets the body of the response using a stream.
  ///
  /// Adds all elements of the given [stream] to this response.
  ///
  /// This is used by [ResponseStream.addStream] to set the stream it uses
  /// to produce the response body.

  Future _streamBody(Stream<List<int>> stream) async {
    await _coreResponse.addStream(stream);
  }

  //----------------------------------------------------------------
  /// Release method
  ///
  /// This method is guaranteed to be invoked when the server is finished
  /// with the [Request] object.
  ///
  /// It does nothing in [Request], but applications implementing their own
  /// custom subclass can use it to clean up. For example, if the custom
  /// subclass creates a transaction, commit/rollback on it can be invoked
  /// in its implementation of release.

  Future release() async {
    // do nothing
  }

  //================================================================
  // Response content helper methods

  /// Convert an internal path to an external path.
  ///
  /// An internal path is one that starts with "~/". This method converts that
  /// to a path that can be used outside of the application (e.g. written in a
  /// HTML HREF attribute).
  /// If there is a session and session cookies are not being used, URL
  /// rewriting is performed (i.e. the session identifier is added as a query
  /// parameter).
  ///
  /// For sessions to be preserved when cookies are not being used, *all* paths
  /// referencing the application's pages must be processed by this method.
  /// If a link is not processed, then the URL rewriting does not occur and
  /// the session will not be preserved.
  ///
  /// The concept of an internal path serves two purposes. The main purpose is
  /// to try to force all paths through this method; making it more difficult to
  /// forget to rewrite the URL. The second purpose is to make it easy to change
  /// the path to the entire application by changing the [Server.basePath] of
  /// the server.
  ///
  /// A good way to check if all paths are internal URLs that have been properly
  /// processed is to change the [Server.basePath] and test if the application
  /// still functions properly. If there are broken links, then those links
  /// were not defined as internal paths processed through this method.
  ///
  /// The [includeSession] parameter indicates if the session is added as
  /// a query parameter. The default value of "null" causes it to be only
  /// added if there is a session and cookies are not being used. If it is
  /// false, it is never added. There is no good reason to ever use it with true.
  ///
  /// The [includeSession] should be left as true in all situations, except
  /// when used for the "method" attribute of a HTML form element. In that
  /// situation, set it to false and use [Request.sessionHiddenInputElement]
  /// to preserve the session.
  ///
  /// If the [internalPath] has any query parameters, they will be included in
  /// the result. So it is not just a pure path, but a path with optional
  /// query parameters.
  ///
  /// Note: this method is on the request object, even though it ultimately
  /// affects the HTTP response. This is because the request object carries the
  /// context for the request and the response. The session is a part of that
  /// context.
  ///
  /// See also [ura].

  String rewriteUrl(String internalPath, {bool? includeSession}) {
    if (!internalPath.startsWith('~/')) {
      throw ArgumentError.value(
          internalPath, 'internalPath', 'rewriteUrl: does not start with "~/"');
    }

    final buf = StringBuffer(server._basePath);

    // Start with the base path

    if (!server._basePath.endsWith('/')) {
      buf.write('/');
    }

    // Add the path segments

    if (internalPath != '~/') {
      buf.write(internalPath.substring(2)); // without leading '~/'
    }

    // Add state preserving query parameter (if needed)

    final _session = session;

    if (_session == null ||
        (_sessionUsingCookies && includeSession != true) ||
        includeSession == false) {
      // Don't include the extra query parameter, because:
      // - there is no session to preserve;
      // - there is a session, but cookies are being used to preserve the
      //   session (and includeSession is not explicitly true); or
      // - invoker explicitly asked to not include it.
      return buf.toString();
    } else {
      // Append extra query parameter to preserve session
      final result = buf.toString();
      final separator = (result.contains('?')) ? '&' : '?';
      return '$result$separator${_server.sessionParamName}=${_session.id}';
    }
    //} else {
    // Simulated request
    // return internalPath;
    //}
  }

  //----------------------------------------------------------------
  /// Rewrite an internal path and encode for an attribute.
  ///
  /// It is very common to rewrite an internal URL and then put its value
  /// into an attribute. For example,
  ///
  /// ```dart
  /// var link = "~/foo?a=1&b=2";
  /// resp.write('<a href="${HEsc.attr(req.rewriteUrl(link))}">here</a>');
  /// ```
  ///
  /// This convenience method invokes both [rewriteUrl] and [HEsc.attr] so the
  /// above can be simply written as:
  ///
  /// ```dart
  /// resp.write('<a href="${req.ura(link)}">here</a>');
  /// ```
  ///
  /// If used for the method attribute of a HTML form element, set
  /// [includeSession] to false and use the
  /// [Request.sessionHiddenInputElement] method inside the form element.
  /// See [Request.sessionHiddenInputElement] for more details.

  String ura(String internalPath, {bool? includeSession}) {
    // Rewrite

    String r;
    if (includeSession != null) {
      r = rewriteUrl(internalPath, includeSession: includeSession);
    } else {
      r = rewriteUrl(internalPath);
    }

    // Escape for use in a HTML attribute

    return HEsc.attr(r);
  }
}
