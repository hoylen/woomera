part of woomera;

//----------------------------------------------------------------
/// Details of the HTTP request.
///
/// Representation of the HTTP request that is passed to the request handlers
/// and exception handlers.
///
/// The different parameters are available via the [pathParams], [queryParams]
/// and [postParams] properties. The session is in the [session] property.
///
/// Custom properties can be added to and retrieved from the request object
/// using the square bracket operators. This may be useful for passing
/// information between different request handlers, when the application
/// has been designed to match on multiple rules (and earlier rules deliberately
/// do not return a response).

class Request {
  /// An identity for the request.
  ///
  /// This is commonly used in log messages:
  ///
  ///     mylog.info("[${req.id}] something happened");
  ///
  /// Note: the value is a [String], because its value is the [Server.id] from
  /// the server (which is a String) concatinated with the request number.
  /// By default, the server ID is the empty string, so this value looks like
  /// a number even though it is a String. But the application can set the
  /// [Server.id] to a non-empty String.

  final String id;

  /// The server that received this request.
  ///
  /// Identifies the [Server] that received the HTTP request.

  final Server server;

  /// The HTTP request.
  ///
  /// An instance of [HttpRequest] the produced the context.

  final HttpRequest request;

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

    if (request.method == "POST" &&
        request.headers.contentType != null &&
        request.headers.contentType.mimeType ==
            "application/x-www-form-urlencoded") {
      // Read in the contents of the request

      // TODO: check specification whether this can use AsciiDecoder instead of UTF-8

      var buf = new List<int>();
      await for (var bytes in request) {
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

      if (postParams.isNotEmpty && _logRequestParam.level <= Level.FINE) {
        var str =
            "[${id}] post: ${postParams.length} key(s): ${postParams.toString()}";
        _logRequestParam.finer(str);
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
  Request._constructor(HttpRequest httpRequest, String requestId, Server svr)
      : request = httpRequest,
        id = requestId,
        server = svr {
    assert(request != null);
    assert(requestId != null);
    assert(server != null);

    _logRequest.fine("[${id}] ${request.method} ${request.uri.path}");

    if (_logRequest.level <= Level.FINE) {
      // Log request
      var str = "[${id}] HTTP headers:";
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
      _logRequestHeader.finest(str);
    }

    // Check length of URI does not exceed limits

    var length = request.uri.path.length;

    if (request.uri.hasQuery) {
      length += request.uri.query.length;
    }

    if (request.uri.hasFragment) {
      length += request.uri.fragment.length;
    }

    if (server.urlMaxSize < length) {
      throw new PathTooLongException();
    }

    // Set queryParams from the request
    // Do not use uri.queryParams, because it does not handle repeating keys.

    _queryParams = new RequestParams._fromQueryString(request.uri.query);

    if (_queryParams.isNotEmpty && _logRequestParam.level <= Level.FINE) {
      var str =
          "[${id}] query: ${queryParams.length} key(s): ${queryParams.toString()}";
      _logRequestParam.finer(str);
    }

    // Determine method used for maintaining (future) sessions

    if (request.cookies.isNotEmpty) {
      _sessionUsingCookies = true; // got cookies, so browser must support them
    } else {
      _sessionUsingCookies = false; // don't know, so assume browser doesn't
    }
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
  ///
  /// The [includeSession] parameter indicates if the session is added as
  /// a query parameter. The default value of "null" causes it to be only
  /// added if there is a session and cookies are not being used. If it is
  /// false, it is never added. There is no good reason to ever use it with true.
  ///
  /// The [includeSession[ should be left as null in all situations, except
  /// when used for the "method" attribute of a HTML form element. In that
  /// situation, set it to false and use [sessionHiddenInputElement] to
  /// preserve the session. See [sessionHiddenInputElement] for details.
  ///
  /// Note: this method is on the request object, even though it ultimately
  /// affects the HTTP response. This is because the request object carries the
  /// context for the request and the response. The session is a part of that
  /// context.

  String rewriteUrl(String iUrl, {bool includeSession: null}) {
    if (!iUrl.startsWith("~/")) {
      throw new ArgumentError.value(
          iUrl, "rUrl", "rewriteUrl: does not start with '~/'");
    }

    var result = server._basePath + (server._basePath.endsWith("/") ? "" : "/");

    if (iUrl != "~/") {
      result += iUrl.substring(2); // append rUrl without leading "~/"
    }

    if (session == null ||
        (this._sessionUsingCookies && includeSession != true) ||
        includeSession == false) {
      // Don't include the extra query parameter, because:
      // - there is no session to preserve;
      // - there is a session, but cookies are being used to preserve the
      //   session (and includeSession is not explicitly true); or
      // - invoker explicitly asked to not include it.
      return result;
    } else {
      // Append extra query parameter to preserve session
      var separator = (result.contains("?")) ? "&" : "?";
      return "${result}${separator}${server.sessionParamName}=${session.id}";
    }
  }

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
    if (hasSession && !this._sessionUsingCookies) {
      // Require hidden POST form parameter to preserve session
      return "<input type=\"hidden\" name=\"" +
          HEsc.attr(server.sessionParamName) +
          "\" value=\"" +
          HEsc.attr(session.id) +
          "\"/>";
    } else {
      return ""; // hidden POST form parameter not required
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
  /// Note: it is an error for multiple session parameters with different values
  /// to be defined. If that happens, a severe error is logged to the
  /// "woomera.session" logger and they are all ignored (i.e. no session is
  /// restored). However, multiple session parameters with the same value is
  /// permitted (this could happen if the program uses
  /// [sessionHiddenInputElement] and did not set includeSession to false when
  /// rewriting the URL for the "action" attribute of the form element).

  Future _sessionRestore() async {
    // Attempt to retrieve a session ID from the request.

    var sessionId = null;
    var conflictingSessionId;

    // First, try finding a session cookie

    for (var cookie in request.cookies) {
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
        var candidate = server._sessionFind(sessionId);

        if (candidate != null) {
          if (await candidate.resume(this)) {
            _logSession.finest("[$id] session resumed: $sessionId");
            candidate._refresh(); // restart timeout timer
            this.session = candidate;
          } else {
            _logSession
                .finest("[$id] session could not be resumed: $sessionId");
            await candidate._terminate(Session.endByFailureToResume);
            this.session = null;
          }
          this._sessionWasSetInRequest = true;
          return; // found session (but might not have been restored)

        } else {
          _logSession.finest("[$id] session not found: $sessionId");
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

    this.session = null;
    this._sessionWasSetInRequest = false;
  }

  //----------------------------------------------------------------
  // Invoked by the server at the very end of processing a request (after
  // the response's `finish` method is invoked.
  //
  // Causes the session's suspend method to be invoked, if there is a session.

  Future _sessionSuspend() async {
    if (this.session != null) {
      await this.session.suspend(this);
    }
  }

  //================================================================
  // Other methods

  //----------------------------------------------------------------
  /// Returns the request's path as a internal URL.
  ///
  /// That is, starting with "~/" (if possible), otherwise the full path is
  /// returned.

  String requestPath() {
    var p = this.request.uri.path;

    if (p.startsWith(server._basePath)) {
      // TODO: this needs more work to account for # and ? parameters

      if (p.length <= server._basePath.length)
        p = "~/";
      else
        p = "~/" + p.substring(server._basePath.length);
    } else {
      p = "~/";
    }

    return p;
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
  /// [includeSession] to false and use the [sessionHiddenInputElement] method
  /// inside the form element. See [sessionHiddenInputElement] for more details.

  String ura(String iUrl, {bool includeSession: null}) {
    return HEsc.attr(this.rewriteUrl(iUrl, includeSession: includeSession));
  }
}
