part of woomera;

//================================================================
/// Request class.

abstract class Request {
  //================================================================
  /// Internal constructor
  ///
  /// This class can only be instantiated as either a [RequestImpl] or
  /// [RequestSimulated].

  Request._internal(this._id, bool defaultToCookiesForSession)
      : _sessionUsingCookies = defaultToCookiesForSession;

  //----------------------------------------------------------------
  // Internal method used to populate the [postParams] value.

  Future _postParamsInit(int maxPostSize);

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

  String get method;

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

  String requestPath();

  //----------------
  /// The request path as a list of segments.
  ///
  /// See [requestPath] for more information.

  List<String> get _pathSegments;

  //----------------------------------------------------------------
  /// HTTP request headers.

  HttpHeaders get headers;

  //----------------------------------------------------------------
  /// Cookies

  Iterable<Cookie> get cookies;

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

  Future<String> bodyStr(int maxBytes);

  /// Retrieves the entire body of the request as a sequence of bytes.

  Future<List<int>> bodyBytes(int maxBytes);

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

  Future _sessionRestore();

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
  // Response producing methods

  //----------------------------------------------------------------

  /// Sets the headers in the response.

  void _produceResponseHeaders(int status, ContentType ct, List<Cookie> cookies,
      Map<String, List<String>> headers);

  /// Sets the body of the response using a string.
  ///
  /// This is used by the [ResponseBuffered._finish] method to produce the
  /// response body.

  void _outputBody(String str);

  /// Sets the body of the response using a stream.
  ///
  /// This is used by [ResponseStream.addStream] to set the stream it uses
  /// to produce the response body.

  Future _streamBody(Stream<List<int>> stream);

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
  /// situation, set it to false and use [RequestImpl.sessionHiddenInputElement]
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
  /// [RequestImpl.sessionHiddenInputElement] method inside the form element.
  /// See [RequestImpl.sessionHiddenInputElement] for more details.

  String ura(String iUrl, {bool includeSession}) =>
      HEsc.attr(rewriteUrl(iUrl, includeSession: includeSession));
}
