part of woomera;

//================================================================

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

class RequestImpl extends Request {
  //================================================================
  /// Constructor
  ///
  /// Creates a Woomera Request from a [HttpRequest].

  RequestImpl(this._httpRequest, String id, Server server)
      : assert(_httpRequest != null),
        assert(id != null),
        assert(server != null),
        super._internal(id, false) {
    _logRequest.fine("[$id] ${_httpRequest.method} ${_httpRequest.uri.path}");

    _serverSet(server);

    _logRequestHeader.finer(() {
      // Log request
      final buf = new StringBuffer("[$id] HTTP headers:");
      _httpRequest.headers.forEach((name, values) {
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

    var length = _httpRequest.uri.path.length;

    if (_httpRequest.uri.hasQuery) {
      length += _httpRequest.uri.query.length;
    }

    if (_httpRequest.uri.hasFragment) {
      length += _httpRequest.uri.fragment.length;
    }

    if (server.urlMaxSize < length) {
      throw new PathTooLongException();
    }

    // Set queryParams from the request
    // Do not use uri.queryParams, because it does not handle repeating keys.

    queryParams = new RequestParams._fromQueryString(_httpRequest.uri.query);

    if (queryParams.isNotEmpty) {
      _logRequestParam.finer(() => "[$id] query: $queryParams");
    }

    // Determine method used for maintaining (future) sessions

    if (_httpRequest.cookies.isNotEmpty) {
      _sessionUsingCookies = true; // got cookies, so browser must support them
    } else {
      _sessionUsingCookies = false; // don't know, so assume browser doesn't
    }
  }

  //================================================================
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
  HttpRequest get httpRequest => _httpRequest;

  final HttpRequest _httpRequest;

  @override
  String get method => _httpRequest.method;

  //================================================================
  // Request path
  //
  // In this implementation, the request path is in the HttpRequest's "uri"
  // member (i.e. in [request.uri])

  //----------------

  @override
  String requestPath() {
    var p = _httpRequest.uri.path;

    if (p.startsWith(server._basePath)) {
      // TODO: this needs more work to account for # and ? parameters

      if (p.length <= server._basePath.length)
        p = "~/";
      else
        p = "~/${p.substring(server._basePath.length)}";
    } else {
      p = "~/";
    }

    return p;
  }

  //----------------

  @override
  List<String> get _pathSegments {
    try {
      final segments = _httpRequest.uri.pathSegments;

      // TODO: remove the base path segments
      assert(server._basePath == '/'); // TODO: support real values in base path

      return segments;
    } on FormatException catch (_) {
      // This is usually due to malformed paths, due to malicious attackers
      // For example putting "/certsrv/..%C0%AF../winnt/system32/cmd.exe" and
      // "/scripts/..%C1%1C../winnt/system32/cmd.exe"
      _logRequest.finest("invalid char encoding in path: request rejected");
      return null;
    }
  }

  //================================================================

  //----------------------------------------------------------------
  /// Headers

  @override
  HttpHeaders get headers => _httpRequest.headers;

  //----------------------------------------------------------------
  /// Cookies

  @override
  Iterable<Cookie> get cookies => _httpRequest.cookies;
  // TODO: remove session cookie from result

  //================================================================

  List<int> _bodyBytes;
  String _bodyStr;

  @override
  Future<List<int>> bodyBytes(int maxSize) async {
    if (_bodyBytes == null) {
      // Bytes not cached: read them in and store them in the bytes cache

      _bodyBytes = <int>[];
      await for (var bytes in _httpRequest) {
        if (maxSize < _bodyBytes.length + bytes.length) {
          throw new PostTooLongException();
        }
        _bodyBytes.addAll(bytes);
      }
    }

    return _bodyBytes;
  }

  //----------------------------------------------------------------

  @override
  Future<String> bodyStr(int maxBytes) async {
    if (_bodyStr == null) {
      // String not cached: get the bytes and decode them into the string cache
      final bytes = _bodyBytes ?? await bodyBytes(maxBytes);

      _bodyStr = utf8.decode(bytes, allowMalformed: false);
    }
    return _bodyStr;
  }

  //================================================================
  // Internal methods

  //----------------------------------------------------------------

  @override
  Future _postParamsInit(int maxPostSize) async {
    // Set post parameters (if any)

    if (_httpRequest.method == "POST" &&
        _httpRequest.headers.contentType != null &&
        _httpRequest.headers.contentType.mimeType ==
            "application/x-www-form-urlencoded") {
      // Read in the contents of the request

      // TODO: check specification whether this can use AsciiDecoder instead of UTF-8

      final buf = <int>[];
      await for (var bytes in _httpRequest) {
        if (maxPostSize < buf.length + bytes.length) {
          throw new PostTooLongException();
        }
        buf.addAll(bytes);
      }

      // Convert the contents into a string

      final str = utf8.decoder.convert(buf);

      // Parse the string into parameters

      postParams = new RequestParams._fromQueryString(str);

      // Logging

      if (postParams.isNotEmpty) {
        _logRequestParam.finer(() => "[$id] post: $postParams");
      }
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
    if (session != null && !_sessionUsingCookies) {
      // Require hidden POST form parameter to preserve session
      final name = HEsc.attr(server.sessionParamName);
      final value = HEsc.attr(session.id);
      return '<input type="hidden" name="$name" value="$value"/>';
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

  @override
  Future _sessionRestore() async {
    // Attempt to retrieve a session ID from the request.

    String sessionId;
    bool conflictingSessionId;

    // First, try finding a session cookie

    if (_httpRequest != null) {
      for (var cookie in _httpRequest.cookies) {
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

  //================================================================

  //================================================================

  @override
  void _produceResponseHeaders(int status, ContentType ct, List<Cookie> cookies,
      Map<String, List<String>> headers) {
    _httpRequest.response.statusCode = status;
    _httpRequest.response.headers.contentType = ct;
    _httpRequest.response.cookies.addAll(cookies);

    for (var name in headers.keys) {
      for (var value in headers[name]) {
        _httpRequest.response.headers.add(name, value);
      }
    }
  }

  //----------------------------------------------------------------
  //    * Adds all elements of the given [stream] to `this`.

  @override
  Future _streamBody(Stream<List<int>> stream) async {
    await _httpRequest.response.addStream(stream);
  }

  //----------------------------------------------------------------

  @override
  void _outputBody(String str) {
    _httpRequest.response.write(str);
  }

  //================================================================
  // Other methods

}
