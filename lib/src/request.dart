part of woomera;

//----------------------------------------------------------------

class Request {
  final int _requestNo;

  /// The server that received this request.
  ///
  /// Identifies the [Server] that received the HTTP request.

  Server get server => _server;

  final Server _server;

  /// The HTTP request.
  ///
  /// An instance of [HttpRequest] the produced the context.

  HttpRequest get request => _request;

  final HttpRequest _request;

  /// The session associated with the context.
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
  /// Note: sessions should be set/cleared before calling [rewriteURL].

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

  /// Indicates if the request has a session or not.

  bool get hasSession => session != null;

  //================================================================
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

  /// The parameters from the URL path.

  RequestParams get pathParams => _pathParams;

  RequestParams _pathParams;

  //================================================================

  /// The parameters from the POST request.
  ///
  /// Is null if this context is not from a POST request.
  ///

  RequestParams get postParams => _postParams;

  RequestParams _postParams; // set by setPostParams method

  //----------------------------------------------------------------

  Future _postParmsInit(int maxPostSize) async {
    // Set post parameters (if any)

    if (_request.method == "POST" &&
        _request.headers.contentType != null &&
        _request.headers.contentType.mimeType ==
            "application/x-www-form-urlencoded") {
      // Read in the contents of the request

      // TODO: check specification whether this can use AsciiDecoder instead of UTF-8

      var buf = new List<int>();
      await for (var bytes in _request) {
        if (maxPostSize < buf.length + bytes.length) {
          throw new PostTooLongException();
        }
        buf.addAll(bytes);
      }

      // Convert the contents into a string

      var str = UTF8.decoder.convert(buf);

      // Parse the string into parameters

      _postParams = new RequestParams._fromQueryString(str);

      // Logging

      if (_logRequest.level <= Level.FINE) {
        var str = "[${_requestNo}] post parameters:";
        if (postParams.isNotEmpty) {
          str += " ${postParams.length} key(s)";
          str += postParams.toString();
        } else {
          str += " none";
        }
        _logRequest.fine(str);
      }
    }
  }

  //================================================================

  /// The parameters from the URL's query parameters.
  ///
  /// This is never null when the context is created, but there is nothing
  /// stopping a filter from modifying it.
  ///
  /// The parameters from the URL path.

  RequestParams get queryParams => _queryParams;

  RequestParams _queryParams; // initially set by constructor

  //================================================================
  // Properties

  final Map<String, Object> _properties = new Map<String, Object>();

  /// Set a property on the request.
  ///
  /// The application can use properties to associate arbitrary values
  /// with the context.

  void operator []=(String key, var value) {
    assert(key != null);
    _properties[key] = value;
  }

  /// Lookup a property on the request.

  Object operator [](String key) {
    assert(key != null);
    return _properties[key];
  }

  //================================================================

  /// Constructor
  ///
  /// Internal constructor invoked by [Server] code. Code outside this package
  /// cannot create [Request] objects.
  ///
  Request._internal(HttpRequest request, int requestNo, Server server)
      : _request = request,
        _requestNo = requestNo,
        _server = server {
    assert(request != null);
    assert(requestNo != null);
    assert(server != null);

    _logRequest.fine("[${_requestNo}] ${request.method} ${request.uri}");

    if (_logRequest.level <= Level.FINE) {
      // Log request
      var str = "[${_requestNo}] HTTP headers:";
      request.headers.forEach((name, values) {
        str += "\n  ${name}: ";
        if (values.length == 0) {
          str += "<noValue>";
        } else if (values.length == 1) {
          str += "${values[0]}";
        } else {
          var index = 1;
          for (var v in values) {
            str += "\n  [${index++}] $v";
          }
        }
      });
      _logRequest.finest(str);
    }

    // Check length of URI does not exceed limits

    var length = request.uri.path.length;

    if (request.uri.hasQuery) {
      length += request.uri.query.length;
    }

    if (request.uri.hasFragment) {
      length += request.uri.fragment.length;
    }

    if (_server.urlMaxSize < length) {
      throw new PathTooLongException();
    }

    // Set queryParams from the request
    // Do not use uri.queryParams, because it does not handle repeating keys.

    _queryParams = new RequestParams._fromQueryString(request.uri.query);

    if (_queryParams.isNotEmpty && _logRequest.level <= Level.FINE) {
      var str = "[${_requestNo}] query parameters:";
      str += " ${queryParams.length} key(s)";
      str += queryParams.toString();
      _logRequest.fine(str);
    }

    // Determine method used for maintaining (future) sessions

    if (request.cookies.isNotEmpty) {
      _sessionUsingCookies = true; // got cookies, so browser must support them
    } else {
      _sessionUsingCookies = false; // don't know, so assume browser doesn't
    }
  }

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
  /// Note: it is an error for multiple session parameters to be defined. If
  /// that happens, a severe error is logged to the "woomera.session" logger
  /// and they are all ignored (i.e. no session is restored).

  void _sessionRestore() {
    // Attempt to retrieve a session ID from the request.

    var sessionId = null;
    var numIdsFound = 0;

    // First, try finding a session cookie

    for (var cookie in request.cookies) {
      if (cookie.name == server.sessionCookieName) {
        sessionId = cookie.value;
        numIdsFound++;
      }
    }

    // Second, try query parameters (i.e. URL rewriting)

    for (var value in queryParams.values(server.sessionParamName)) {
      sessionId = value;
      numIdsFound++;
    }
    queryParams._removeAll(server.sessionParamName);

    // Finally, try POST parameters (i.e. URL rewriting in a POST request)

    if (postParams != null) {
      for (var value in postParams.values(server.sessionParamName)) {
        sessionId = value;
        numIdsFound++;
      }
      postParams._removeAll(server.sessionParamName);
    }

    // Retrieve session (if any)

    if (sessionId != null) {
      if (numIdsFound == 1) {
        this.session = server._sessionFind(sessionId);

        if (this.session != null) {
          _logSession.finest("[$_requestNo] session restored: $sessionId");
          this._sessionWasSetInRequest = true;
          this.session.refresh(); // restart timeout timer
          return; // session restored
        } else {
          _logSession.finest("[$_requestNo] session not found: $sessionId");
          // fall through to treat as no session found
        }
      } else {
        // Multiple session IDs found: this should not happen
        _logSession.shout("[$_requestNo] multiple session IDs in request: not restoring any of them");
        // fall through to treat as no session found
      }
    } else {
      _logSession.finest("[$_requestNo] no session ID in request");
      // fall through to treat as no session found
    }

    // No session found

    this.session = null;
    this._sessionWasSetInRequest = false;
  }

  //================================================================

  /// The HTTP request method.
  ///
  /// Returns "GET", "POST", etc.

  String get method => _request.method;

  //----------------------------------------------------------------
  /// Returns the request's path as a relative path.
  ///
  /// That is, starting with "~/" (if possible), otherwise the full path is
  /// returned.

  String requestPath() {
    var p = this.request.uri.path;

    if (p.startsWith(_server._basePath)) {
      // TODO: this needs more work to account for # and ? parameters

      if (p.length <= _server._basePath.length)
        p = "~/";
      else
        p = "~/" + p.substring(_server._basePath.length);
    } else {
      p = "~/";
    }

    return p;
  }

  //================================================================
  // Session

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

  String rewriteUrl(String url) {
    if (url.startsWith("~/")) {
      if (url == "~/") {
        url = server._basePath;
      } else {
        url = server._basePath +
            (server._basePath.endsWith("/") ? "" : "/") +
            url.substring(2);
      }

      if (session == null || this._sessionUsingCookies) {
        // Does not need extra query parameter to preserve session
        return url;
      } else {
        // Append extra query parameter to preserve session
        var separator = (url.contains("?")) ? "&" : "?";
        return "${url}${separator}${server.sessionParamName}=${session.id}";
      }
    } else {
      throw new ArgumentError.value(url, "url", "rewriteUrl: does not start with '~/'");
      return url;
    }
  }

  //----------------------------------------------------------------
  /// Returns hidden form parameter input to include the session parameter.
  ///
  /// If there is no session (i.e. session is null) or cookies are being used
  /// to preserve the session, returns the empty string.

  String sessionFormHiddenParameter() {
    if (hasSession && !this._sessionUsingCookies) {
      // Require hidden POST form parameter to preserve session
      return "<input type=\"hidden\" name=\"" +
          HEsc.attr(_server.sessionParamName) +
          "\" value=\"" +
          HEsc.attr(session.id) +
          "\"/>";
    } else {
      return ""; // hidden POST form parameter not required
    }
  }
}
