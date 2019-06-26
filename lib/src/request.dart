part of woomera;

//================================================================
/// Request class.

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
      : assert(hReq != null),
        assert(id != null),
        assert(server != null),
        _id = id,
        _coreRequest = new _CoreRequestReal(hReq),
        _coreResponse = new _CoreResponseReal(hReq.response) {
    _logRequest.fine(
        "[$id] ${_coreRequest.method} ${_coreRequest.internalPath(server._basePath)}");

    _serverSet(server);

    _logRequestHeader.finer(() {
      // Log request
      final buf = new StringBuffer("[$id] HTTP headers:");
      _coreRequest.headers.forEach((name, values) {
        buf.write("\n  $name: ");
        if (values.isEmpty) {
          buf.write("<noValue>");
        } else if (values.length == 1) {
          buf.write("${values[0]}");
        } else {
          var index = 1;
          for (var v in values) {
            buf.write("\n  [${index++}] $v");
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
      throw new PathTooLongException();
    }

    // Set queryParams from the request
    // Do not use uri.queryParams, because it does not handle repeating keys.

    queryParams = new RequestParams._fromQueryString(hReq.uri.query);

    if (queryParams.isNotEmpty) {
      _logRequestParam.finer(() => "[$id] query: $queryParams");
    }

    // Determine method used for maintaining (future) sessions

    if (_coreRequest.cookies.isNotEmpty) {
      _sessionUsingCookies = true; // got cookies, so browser must support them
    } else {
      _sessionUsingCookies = false; // don't know, so assume browser doesn't
    }
  }

  //----------------------------------------------------------------
  /// Constructor for a simulated request.

  Request.simulated(String method, String internalPath,
      {String sessionId,
      String id,
      RequestParams queryParams,
      SimulatedHttpHeaders headers,
      List<Cookie> cookies,
      String bodyStr,
      List<int> bodyBytes,
      this.postParams})
      : _id = id,
        _coreRequest = new _CoreRequestSimulated(method, internalPath,
            sessionId: sessionId,
            queryParams: queryParams,
            headers: headers,
            cookies: cookies,
            bodyStr: bodyStr,
            bodyBytes: bodyBytes),
        _coreResponse = new _CoreResponseSimulated() {
    _simulatedConstructorCommon(queryParams);
  }

  //----------------
  /// Constructor for a simulated GET request.

  Request.simulatedGet(String internalPath,
      {String sessionId,
      String id,
      RequestParams queryParams,
      SimulatedHttpHeaders headers,
      List<Cookie> cookies,
      String bodyStr,
      List<int> bodyBytes})
      : _id = id,
        _coreRequest = new _CoreRequestSimulated('GET', internalPath,
            sessionId: sessionId,
            queryParams: queryParams,
            headers: headers,
            cookies: cookies,
            bodyStr: bodyStr,
            bodyBytes: bodyBytes),
        _coreResponse = new _CoreResponseSimulated() {
    _simulatedConstructorCommon(queryParams);
  }

  //----------------
  /// Constructor for a simulated Post request.

  Request.simulatedPost(String internalPath, this.postParams,
      {String sessionId,
      String id,
      RequestParams queryParams,
      SimulatedHttpHeaders headers,
      List<Cookie> cookies,
      String bodyStr,
      List<int> bodyBytes})
      : _id = id,
        _coreRequest = new _CoreRequestSimulated('POST', internalPath,
            sessionId: sessionId,
            queryParams: queryParams,
            headers: headers,
            cookies: cookies,
            bodyStr: bodyStr,
            bodyBytes: bodyBytes),
        _coreResponse = new _CoreResponseSimulated() {
    _simulatedConstructorCommon(queryParams);
  }

  //----------------
  // Code common to all simulated request constructors.
  //
  // Used by [simulated], [simulatedGet] and [simulatedPost].

  void _simulatedConstructorCommon(RequestParams queryParams) {
    _id ??= 'SIM:${++_simulatedRequestCount}';

    this.queryParams =
        (queryParams ?? new RequestParams._internalConstructor());
    if (this.queryParams.isNotEmpty) {
      _logRequestParam.finer(() => "[$id] query: $queryParams");
    }

    // Force the use of cookies to maintain session.
    //
    // When the [SimulatedResponse] is produced, the session cookie is
    // extracted to populate the sessionId.

    _sessionUsingCookies = true;
  }

  // Used to generate a unique ID for simulated requests, if none was set on it.

  static int _simulatedRequestCount = 0;

  //================================================================

  //----------------------------------------------------------------
  // Internal method used to populate the [postParams] value.

  Future _postParamsInit(int maxPostSize) async {
    // Set post parameters (if any)

    if (_coreRequest.method == "POST" &&
        _coreRequest.headers.contentType != null &&
        _coreRequest.headers.contentType.mimeType ==
            "application/x-www-form-urlencoded") {
      // Read in the contents of the request

      // Convert the contents into a string
      // TODO: check specification whether this can use AsciiDecoder instead of UTF-8

      final str = await _coreRequest.bodyStr(maxPostSize);

      // Parse the string into parameters

      postParams = new RequestParams._fromQueryString(str);

      // Logging

      if (postParams.isNotEmpty) {
        _logRequestParam.finer(() => "[$id] post: $postParams");
      }
    }
  }

  //================================================================
  /*
  /// The underlying HTTP request.
  ///
  /// An instance of [HttpRequest] the produced the context.
  ///
  /// Applications should not use this member, because it is not available in
  /// the [RequestSimulated]. So using it would preven the application from
  /// being tested using the simulation.
  ///
  /// It is provided in case there are some properties of the [HttpRequest]
  /// that is not yet exposed in a Woomera [Request]. If there is, please
  /// submit an issue, so it could be included in _Request_.

  @deprecated
  HttpRequest get httpRequest => _httpRequest;*/

  final _CoreRequest _coreRequest;

  /// Returns the [HttpRequest].
  ///
  /// This member should not be used unless absolutely necessary. It is now
  /// deprecated: please use [method], [requestPath], [headers], [cookies],
  /// [bodyBytes], [bodyStr] to obtain information that was previously obtained
  /// from the Request's `request` member.
  ///
  /// It is only implemented for [Request] objects from real HTTP requests, and
  /// will throw an [UnsupportedError] exception when called on a simulated
  /// _Request_. Therefore, using it will prevent the server from being tested
  /// using [Server.simulate].
  ///
  /// If a value is required from [HttpRequest], consider submitting an issue
  /// to have it exposed by [Request] in a manner that allows it to be used for
  /// both real and simulated HTTP requests.

  @deprecated
  HttpRequest get request {
    if (_coreRequest is _CoreRequestReal) {
      // ignore: avoid_as
      return (_coreRequest as _CoreRequestReal)._httpRequest;
    } else {
      throw new UnsupportedError('request not available on simulated Requests');
    }
  }

  final _CoreResponse _coreResponse;

  /// Returns the [SimulatedResponse] from the _CoreResponse object.
  ///
  /// This method only works for the Request is for a simulated HTTP request.

  SimulatedResponse get _simulatedResponse {
    SimulatedResponse result;
    assert(_coreResponse is _CoreResponseSimulated);
    if (_coreResponse is _CoreResponseSimulated) {
      // ignore: avoid_as
      final simCoreResp = _coreResponse as _CoreResponseSimulated;
      result = new SimulatedResponse(simCoreResp, server.sessionCookieName);
    }
    return result;
  }

  //================================================================
  // Members and accessors

  //----------------------------------------------------------------
  /// An identity for the request.
  ///
  /// This is commonly used in log messages:
  ///
  ///     mylog.info("[${req.id}] something happened");
  ///
  /// Note: the value is a [String], because its value is the [Server.id] from
  /// the server (which is a String) concatenated with the request number.
  /// By default, the server ID is the empty string, so this value looks like
  /// a number even though it is a String. But the application can set the
  /// [Server.id] to a non-empty String.

  String get id => _id;

  String _id;

  //----------------------------------------------------------------
  /// The server that received this request.
  ///
  /// Identifies the [Server] that received the HTTP request.

  Server get server => _server;

  Server _server;

  // The server can only be set by code in the Woomera package.

  void _serverSet(Server s) {
    assert(_server == null || s == null, '_servertSet invoked incorrectly');
    _server = s;
  }

  //================================================================
  // Request details

  //----------------------------------------------------------------
  /// Request HTTP method
  ///
  /// For example, "GET" or "POST".

  String get method => _coreRequest.method;

  //----------------------------------------------------------------
  // Request path
  //
  // There are three possible ways to retrieve the (same) path value.

  /// The request path as a String.
  ///
  /// The request path is the path of the internal URL. That is, it excludes
  /// the host, port, base path and any query parameters.
  ///
  /// This method returns the request path as a string. This is a value that
  /// starts with "~/" (e.g. "~/foo/bar/baz/").
  ///
  /// This is a value that starts with "~/".

  String requestPath() => _coreRequest.internalPath(server._basePath);

  //----------------
  /// The request path as a list of segments.
  ///
  /// See [requestPath] for more information.

  List<String> get _pathSegments =>
      _coreRequest._pathSegments(server._basePath);

  //----------------------------------------------------------------
  /// HTTP request headers.

  HttpHeaders get headers => _coreRequest.headers;

  //----------------------------------------------------------------
  /// Cookies

  Iterable<Cookie> get cookies => _coreRequest.cookies;
  // TODO: remove session cookie from result

  //================================================================
  // Body of the request

  /// Retrieves the entire body of the request as a string.
  ///
  /// The bytes in the body of the HTTP request are interpreted as an UTF-8
  /// encoded string. If the bytes cannot be decoded as UTF-8, a
  /// [FormatException] is thrown.
  ///
  /// If the body has more than [maxBytes] bytes, [PostTooLongException] is
  /// thrown. Set the _maxBytes_ to a value that is not less than the maximum
  /// size the request handler ever expects to receive. This limit prevents
  /// incorrect/malicious clients from flooding the request handler with
  /// too much data om the body (e.g. several gigabytes). Note: the maximum
  /// number of characters in the string may be equal to or less than the
  /// maximum number of bytes, since a single Unicode code point may require
  /// one or more bytes to encode.

  Future<String> bodyStr(int maxBytes) => _coreRequest.bodyStr(maxBytes);

  /// Retrieves the entire body of the request as a sequence of bytes.

  Future<List<int>> bodyBytes(int maxBytes) => _coreRequest.bodyBytes(maxBytes);

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

  RequestParams pathParams;

  // The [pathParams] will be set by the server when it processes the request.

  //----------------
  /// The parameters from the POST request.
  ///
  /// This is not null if the context is a POST request with a MIME type of
  /// "application/x-www-form-urlencoded". Beware that it will be null for
  /// other types of POST requests (e.g. JSON).

  RequestParams postParams;

  // The [postParams] will be set by the server when it processes the request.
  // The code will invoke [_postParamsInit] to do it.

  //----------------
  /// The parameters from the URL's query parameters.
  ///
  /// This is never null when the context is created, but there is nothing
  /// stopping a filter from modifying it.
  ///
  /// The parameters from the URL path.

  RequestParams queryParams;

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

  Session session;

  /// Indicates how sessions are indicated to the browser.
  ///
  /// By default, this is set to false to use URL rewriting. That is the most
  /// reliable mechanism since browsers might not have cookie support enabled.
  /// But if the HTTP request contained some cookies (any cookie, not just the
  /// session one) this is set to true.
  ///
  /// A session handler should not change the value of this member. Since the
  /// Web server normally does not have a reliable mechanism of knowning if
  /// the browser supports cookies or not.
  ///
  /// A better approach is for the application to set some cookie (any cookie)
  /// before establishing the session. If the browser supports cookies, then it
  /// will be returned and this member will automatically be set to true.
  ///
  /// In summary, the application should not need to examine or change this
  /// member. It should simply attempt to set a cookie before it tries to
  /// set a session.

  bool _sessionUsingCookies;

  /// Indicated if a session was established from the HTTP request.
  ///
  /// The main purpose of this member is so the [Response] can know that it
  /// needs to explicitly delete a cookie if the session is cleared.

  bool _sessionWasSetInRequest;

  //----------------------------------------------------------------
  /// Attempt to restore the session (if there was one).
  ///
  /// Using the cookies, query parameters or POST parameters, to restore
  /// a session for the request.
  ///
  /// If a session was successfully found, the [session] member is set to it
  /// and [_sessionWasSetInRequest] is set to true. Otherwise, [session] is
  /// set to null and [_sessionWasSetInRequest] set to false.
  ///
  /// Any session query parameter and/or POST parameter are removed. So the
  /// application never sees them. But any session cookie(s) are not removed
  /// (since the list is read only).
  ///
  /// Note: it is an error for multiple session parameters with different values
  /// to be defined. If that happens, a severe error is logged to the
  /// "woomera.session" logger and they are all ignored (i.e. no session is
  /// restored). However, multiple session parameters with the same value is
  /// permitted (this could happen if the program uses
  /// [sessionHiddenInputElement] and did not set includeSession to false when
  /// rewriting the URL for the "action" attribute of the form element).

  Future _sessionRestore() async {
    // Attempt to retrieve a session ID from the request.

    String sessionId;
    bool conflictingSessionId;

    // First, try finding a session cookie

    assert(_coreRequest != null); // todo: if never false, remove following if

    if (_coreRequest != null) {
      if (_coreRequest.sessionId != null) {
        // Explicitly passed in sessionId (simulations only)
        sessionId = _coreRequest.sessionId;
        conflictingSessionId = false;
      } else {
        // Examine cookies for the session cookie

        for (var cookie in _coreRequest.cookies) {
          if (cookie.name == server.sessionCookieName) {
            if (sessionId == null) {
              sessionId = cookie.value;
              assert(conflictingSessionId == null);
              conflictingSessionId = false;
            } else {
              if (sessionId != cookie.value) {
                conflictingSessionId = true;
              }
            }
          }
        }
      }
    }

    // Second, try query parameters (i.e. URL rewriting)

    for (var value in queryParams.values(server.sessionParamName)) {
      if (sessionId == null) {
        sessionId = value;
        assert(conflictingSessionId == null);
        conflictingSessionId = false;
      } else {
        if (sessionId != value) {
          conflictingSessionId = true;
        }
      }
    }
    queryParams._removeAll(server.sessionParamName);

    // Finally, try POST parameters (i.e. URL rewriting in a POST request)

    if (postParams != null) {
      for (var value in postParams.values(server.sessionParamName)) {
        if (sessionId == null) {
          sessionId = value;
          assert(conflictingSessionId == null);
          conflictingSessionId = false;
        } else {
          if (sessionId != value) {
            conflictingSessionId = true;
          }
        }
      }
      postParams._removeAll(server.sessionParamName);
    }

    // Retrieve session (if any)

    if (sessionId != null) {
      if (!conflictingSessionId) {
        final candidate = server._sessionFind(sessionId);

        if (candidate != null) {
          if (await candidate.resume(this)) {
            _logSession.finest("[$id] [session:$sessionId] resumed");
            candidate._refresh(); // restart timeout timer
            session = candidate;
          } else {
            _logSession.finest("[$id] [sessionL$sessionId] can't resume");
            await candidate._terminate(SessionTermination.resumeFailed);
            session = null;
          }
          _sessionWasSetInRequest = true;
          return; // found session (but might not have been restored)

        } else {
          _logSession.finest("[$id] [session:$sessionId] not found");
          // fall through to treat as no session found
        }
      } else {
        // Multiple session IDs of different values found: this should not happen
        _logSession.shout(
            "[$id] multiple different session IDs in request: not restoring any of them");
        // fall through to treat as no session found
      }
    } else {
      _logSession.finest("[$id] no session ID in request");
      // fall through to treat as no session found
    }

    // No session found

    session = null;
    _sessionWasSetInRequest = false;
  }

  //----------------------------------------------------------------
  // Invoked by the server at the very end of processing a request (after
  // the response's `finish` method is invoked.
  //
  // Causes the session's suspend method to be invoked, if there is a session.

  Future _sessionSuspend() async {
    if (session != null) {
      await session.suspend(this);
    }
  }

  /// Indicates if the request has a session or not.
  ///
  /// Deprecated: please use `x.session != null` instead of `x.hasSession`.

  // TODO: @deprecated
  bool get hasSession => session != null;

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
    if (session != null && !_sessionUsingCookies) {
      // Require hidden POST form parameter to preserve session
      final name = HEsc.attr(server.sessionParamName);
      final value = HEsc.attr(session.id);
      return '<input type="hidden" name="$name" value="$value"/>';
    } else {
      return ""; // hidden POST form parameter not required
    }
  }

  //================================================================
  // Response producing methods

  //----------------------------------------------------------------

  /// Sets the headers in the response.

  void _produceResponseHeaders(int status, ContentType ct, List<Cookie> cookies,
      Map<String, List<String>> headers) {
    _coreResponse.status = status;
    _coreResponse.cookies.addAll(cookies);

    if (ct != null) {
      // Only set the contentType if there is one.
      // Redirection responses don't: they will have the default (text/plain).
      _coreResponse.headers.contentType = ct;
    }

    for (var name in headers.keys) {
      for (var value in headers[name]) {
        _coreResponse.headers.add(name, value);
      }
    }
  }

  /// Sets the body of the response using a string.
  ///
  /// This is used by the [ResponseBuffered._finish] method to produce the
  /// response body.

  void _outputBody(String body, List<int> encodedBody) {
    _coreResponse._setBody(body, encodedBody);
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

  /// Convert an internal URL to a URL that can be used by a browser.
  ///
  /// An internal URL is one that starts with "~/". This method converts that
  /// to a URL that can be presented (e.g. written in a HTML HREF attribute).
  /// If there is a session and session cookies are not being used, URL
  /// rewriting is performed (i.e. the session identifier is added as a query
  /// parameter).
  ///
  /// For sessions to be preserved when cookies are not being used, *all*
  /// URLs referencing the application's pages must be processed by this method.
  /// If a link is not processed, then the URL rewriting does not occur and
  /// the session will not be preserved.
  ///
  /// The concept of an internal URL serves two purposes. The main purpose is
  /// to try to force all URLs through this method; making it more difficult to
  /// forget to rewrite the URL. The second purpose is to make it easy to change
  /// the path to the entire application by changing the [Server.basePath] of
  /// the server.
  ///
  /// A good way to check if all URLs are internal URLs that have been properly
  /// processed is to change the [Server.basePath] and test if the application
  /// still functions properly. If there are broken links, then those links
  /// were not defined as internal URLs processed through this method.
  ///
  /// The [includeSession] parameter indicates if the session is added as
  /// a query parameter. The default value of "null" causes it to be only
  /// added if there is a session and cookies are not being used. If it is
  /// false, it is never added. There is no good reason to ever use it with true.
  ///
  /// The [includeSession[ should be left as null in all situations, except
  /// when used for the "method" attribute of a HTML form element. In that
  /// situation, set it to false and use [Request.sessionHiddenInputElement]
  /// to preserve the session. See [RequestImpl,sessionHiddenInputElement] for
  /// details.
  ///
  /// Note: this method is on the request object, even though it ultimately
  /// affects the HTTP response. This is because the request object carries the
  /// context for the request and the response. The session is a part of that
  /// context.

  String rewriteUrl(String iUrl, {bool includeSession}) {
    if (!iUrl.startsWith("~/")) {
      throw new ArgumentError.value(
          iUrl, "rUrl", "rewriteUrl: does not start with '~/'");
    }

    final buf = new StringBuffer(server._basePath);
    if (!server._basePath.endsWith("/")) {
      buf.write("/");
    }

    if (iUrl != "~/") {
      buf.write(iUrl.substring(2)); // append rUrl without leading "~/"
    }

    if (session == null ||
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
      final separator = (result.contains("?")) ? "&" : "?";
      return "$result$separator${server.sessionParamName}=${session.id}";
    }
  }

  //----------------------------------------------------------------
  /// URL Rewritten for an Attribute.
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

  String ura(String iUrl, {bool includeSession}) =>
      HEsc.attr(rewriteUrl(iUrl, includeSession: includeSession));
}
