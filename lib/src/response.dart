part of woomera;

//================================================================
/// Abstract base class for a response.
///
/// The various handlers return a [Future] to an object based on
/// this type. See the [RequestHandler] and [ExceptionHandler] typedefs.

abstract class Response {
  //================================================================

  /// Content-type of the response.
  ContentType contentType;

  /// HTTP headers in the response.
  final Map<String, List<String>> headers = {};

  /// Cookies in the response.
  final List<Cookie> cookies = [];

  // State variable
  bool _headersOutputted = false;

  //================================================================
  // Status code

  int _status = HttpStatus.ok; // defaults to OK

  /// Sets the HTTP status code
  ///
  /// Default status is 200 "OK", if this method is not used to set it to
  /// a different value.
  ///
  /// The HTTP status code cannot be changed after the production of the
  /// response has started. Attempts to change it will result in a
  /// [StateError] exception.
  ///
  set status(int value) {
    if (_headersOutputted) {
      throw new StateError("Header already outputted");
    }
    _status = value;
  }

  /// HTTP status code.
  ///
  /// Returns the HTTP status code of the response.

  int get status => _status;

  //================================================================
  // Setting the HTTP headers

  //----------------------------------------------------------------
  /// Set a HTTP header
  ///
  void headerAdd(String name, String value) {
    if (name == null) {
      throw new ArgumentError.notNull("name");
    }
    if (name.isEmpty) {
      throw new ArgumentError.value(name, "name", "Empty string");
    }
    if (value == null) {
      throw new ArgumentError.notNull("value");
    }
    if (_headersOutputted) {
      throw new StateError("Header already outputted");
    }

    if (!headers.containsKey(name)) {
      headers[name] = <String>[value]; // create new values list
    } else {
      headers[name].add(value); // append to existing
    }
  }

  //----------------------------------------------------------------
  /// Set a HTML header
  ///
  /// Use [headerAdd] instead. This old method name should be avoided, because
  /// it is easily confused with the new [headers] member.

  @deprecated
  void header(String name, String value) {
    headerAdd(name, value);
  }

  //================================================================
  // Cookies

  /// Set a cookie.
  ///
  /// A session cookie is one that does not have an expiry date. It gets
  /// deleted when the browser is closed.
  ///
  /// A persistent cookie is one that has an expiry date.
  ///
  /// Secure cookie ... The browser only sends the cookie over HTTPS and never
  /// sends it over HTTP.
  ///
  /// HttpOnly cookies are only used when transmitted over HTTP or HTTPS.
  /// They cannot be accessed by JavaScript etc.
  ///
  /// Note: the name and value of the cookie cannot contain whitespace.
  /// Cookie names are case sensitive
  ///
  /// Typically, the [Cookie.path] should be set to the server's
  /// [Server.basePath]. For improved security, the [Cookie.httpOnly] should be
  /// set to true.
  ///
  /// The [Cookie.name] must not be the same as the server's [Server.sessionCookieName].
  ///
  /// A refresher on cookies:
  ///
  /// - The value may consist of any printable ASCII character (! (33) through
  ///   ~ (126)) excluding , (44) and ; (59) and excluding whitespace
  ///   (space (32)).
  /// - The name excludes the same characters, as well as = (61).
  /// - The name is case-sensitive.

  void cookieAdd(Cookie cookie) {
    if (_headersOutputted) {
      throw new StateError("Header already outputted");
    }
    cookies.add(cookie);
  }

  /// Delete a cookie.
  ///
  void cookieDelete(String name, [String path, String domain]) {
    if (_headersOutputted) {
      throw new StateError("Header already outputted");
    }
    try {
      // Normally, to delete a cookie, the value can be an empty string, but
      // since Dart 2.1.0 (at least until and including Dart 2.2.0), the
      // Cookie constructor throws a RangeError if passed an empty string.
      // So the dummy value of "_DEL_" is used.
      final delCookie = new Cookie(name, "_DEL_")
        ..path = path
        ..domain = domain
        ..expires = new DateTime.utc(1970, 1, 1, 0, 0, 1, 0)
        ..maxAge = 0;
      return cookieAdd(delCookie);
      // ignore: avoid_catching_errors
    } on RangeError {
      throw new UnsupportedError(
          'do not use Dart 2.1.x, 2.2.0: a bug prevents cookie deletion');
    }
  }

  //================================================================
  // Response production methods

  //----------------------------------------------------------------
  /// Output the status and headers.
  ///
  void _outputHeaders(Request req) {
    if (_headersOutputted) {
      throw new StateError("Header already outputted");
    }

    // Check that application has not tried to use the session cookie
    final sessionCookieName = req.server.sessionCookieName;
    for (var c in cookies) {
      if (c.name == sessionCookieName) {
        throw new ArgumentError.value(
            c.name, "cookieName", "Clashes with name of session cookie");
      }
    }

    if (req._sessionUsingCookies) {
      // Set up cookie for session management

      if (req.session != null) {
        // Need to set the session cookie
        final c = new Cookie(req.server.sessionCookieName, req.session.id)
          ..path = req.server.basePath
          ..httpOnly = true;
        if (req.server.sessionCookieForceSecure ||
            (req.server.isSecure != null && req.server.isSecure)) {
          c.secure = true; // HTTPS only: better security, but not for testing
        }
        cookieAdd(c);
      } else if (req._sessionWasSetInRequest) {
        // Need to clear the session cookie
        cookieDelete(req.server.sessionCookieName, req.server.basePath);
      }
    }

    // Output the status, headers and cookies

    req._produceResponseHeaders(_status, contentType, cookies, headers);

    _headersOutputted = true;
  }

  //----------------------------------------------------------------
  /// Method that is invoked at the end of creating the HTTP response.
  ///
  /// The framework automatically invokes this method when it creates a HTTP
  /// response from the [Request] object returned by the application's request
  /// handler or exception handler.
  ///
  /// The implementation in the base [Request] class does nothing. But an
  /// application could create their own subclass (usually a subclass of
  /// [ResponseBuffered] or [ResponseStream]) and that implement its own
  /// [finish] method. A typical use of a
  /// subclass is to generate HTML pages for an application: the subclass's
  /// constructor could produce the common HTML headers and the subclass's
  /// [finish] method could produce the common HTML footers.

  Future finish(Request req) async {
    // do nothing
  }

  //----------------------------------------------------------------
  /// The internal finish method is called at the end of the response.
  ///
  /// The framework automatically invokes this method when it creates a HTTP
  /// response from the [Request] object returned by the application's request
  /// handler or exception handler. This private [_finish] method is invoked
  /// after the public [finish] method.
  ///
  /// Although it could have been incorporated into the base-class' public
  /// [finish] method, that would have required any application's [finish]
  /// method to remember to invoke the [finish] method from its
  /// superclass. There is no guarantee an application defined subclass will do
  /// that. So this is a separate internal method to guarantee that it always
  /// gets invoked by the framework.

  void _finish(Request req) {
    // Do nothing
    if (!_headersOutputted) {
      throw new StateError("Header has not been outputted");
    }
  }
}

//================================================================
/// A response where the contents is buffered text.
///
/// Do not use this type of response if the contents is binary data
/// (i.e. not [String]) and/or needs to be streamed to the client. Use the
/// [ResponseStream] for those types of responses.

class ResponseBuffered extends Response {
  /// Constructor

  ResponseBuffered(ContentType ct) {
    contentType = ct;
  }

  final StringBuffer _buf = new StringBuffer();
  bool _contentOutputted = false;

  /// Append to the content.
  ///
  void write(Object obj) {
    if (_contentOutputted) {
      throw new StateError("Content already outputted");
    }
    _buf.write(obj);
  }

  /// Produce the response.
  ///
  @override
  void _finish(Request req) {
    if (req == null) {
      throw new ArgumentError.notNull("req");
    }
    if (_contentOutputted) {
      throw new StateError("Content already outputted");
    }
    super._outputHeaders(req);

    final str = _buf.toString();

    req._outputBody(str);

    _logResponse.fine("[${req.id}] status=$_status, size=${str.length}");
    _contentOutputted = true;

    super._finish(req);
  }
}

//================================================================
/// A response where the contents come from a stream.
///
/// Use this type of response when the content contains binary data and/or
/// the contents is to be streamed.
///
/// Use this type of response when the content is produced as a [Stream].
/// If the contents is a stream of text ([String]), use this type of response,
/// but produce a binary stream by converting the [String] into binary data
/// using the [String.codeUnits] method.

class ResponseStream extends Response {
  /// Constructor.
  ///
  ResponseStream(ContentType ct) {
    contentType = ct;
    _streamState = 0;
  }

  int _streamState = 0; // 0 = no stream, 1 = set, 2 = finished

  /// Provide a stream that produces the content.
  ///
  /// Note: any headers must be defined before this method is called.
  /// Headers cannot be defined after the stream has started.

  Future<ResponseStream> addStream(
      Request req, Stream<List<int>> stream) async {
    if (req == null) {
      throw new ArgumentError.notNull("req");
    }
    if (_streamState == 1) {
      throw new StateError("addStream invoked when stream not finished");
    }

    if (_streamState == 0) {
      // First invocation of addStream
      super._outputHeaders(req);
    }
    _streamState = 1;

    await req._streamBody(stream);

    _streamState = 2;

    return this;
  }

  /// Produce the response.
  ///
  @override
  void _finish(Request req) {
    if (req == null) {
      throw new ArgumentError.notNull("req");
    }

    if (_streamState == 0) {
      throw new StateError("Stream content was never added");
    }
    if (_streamState == 1) {
      throw new StateError("Stream content stream source was not finished");
    }
    assert(_streamState == 2);

    _logResponse.fine("[${req.id}] status=$_status, stream");

    super._finish(req);
  }
}

//================================================================
/// HTTP response that redirects the browser to a URL.
///
class ResponseRedirect extends Response {
  /// Constructor.
  ///
  /// The response will redirect the browser to [addr], which can be
  /// a relative to the deployment URL (i.e. starts with "~/") or a real URL.
  ///
  /// The [status] must be a redirection HTTP status code.
  ///
  /// The default status is [HttpStatus.seeOther] (303).
  /// Other commonly used values are [HttpStatus.movedPermanently] (301) and
  /// [HttpStatus.movedTemporarily] (302).
  ///
  /// The value of [HttpStatus.temporaryRedirect] (307) is used when the method
  /// is preserved. That is, GET request is redirected to a GET request
  /// and a POST request is redirected to a POST request. Old browsers might
  /// not support this status code.
  ///
  /// For more information on HTTP status codes, see
  /// <https://www.w3.org/Protocols/rfc2616/rfc2616-sec10.html#sec10.3>

  ResponseRedirect(String addr, {int status = HttpStatus.seeOther}) : super() {
    if (status < 300 || 399 < status) {
      throw new ArgumentError.value(
          status, "status", "ResponseRedirect: not a redirection HTTP status");
    }
    if (addr == null) {
      throw new ArgumentError.notNull("ResponseRedirect.addr");
    }
    if (addr.isEmpty) {
      throw new ArgumentError.value(
          addr, "addr", "ResponseRedirect: empty string");
    }
    if (addr.startsWith("/")) {
      _logResponse
          .warning("ResponseRedirect address should start with '~/' : $addr");
    }

    _addr = addr;

    this.status = status;
  }

  // The address to redirect to.
  //
  // Can be a internal relative-path or an external URL.

  String _addr;

  /// Produce the response.
  ///
  @override
  void _finish(Request req) {
    if (req == null) {
      throw new ArgumentError.notNull("req");
    }

    final url = (_addr.startsWith("~/")) ? req.rewriteUrl(_addr) : _addr;

    _logResponse.fine("[${req.id}] status=$_status, redirect=$url");

    headerAdd('Location', url);
    super._outputHeaders(req);
    // Note: there is no body

    super._finish(req);
  }
}
