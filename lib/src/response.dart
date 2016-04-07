part of woomera;

//================================================================
/// Abstract base class for a response.
///
/// The handlers (both in the rules in a [ServerPipeline] as well as the
/// exception handlers) return an object based on this type.

abstract class Response {
  int _status = HttpStatus.OK;
  ContentType _contentType = ContentType.BINARY;
  var _headers = new Map<String, List<String>>();
  var _cookies = new List<Cookie>();
  bool _headersOutputted = false;

  /// Sets the HTTP status code
  ///
  /// Default status is 200 "OK", if this method is not used to set it to
  /// a different value.
  ///
  void set status(int value) {
    if (_headersOutputted) {
      throw new StateError("Header already outputted");
    }
    _status = value;
  }

  /// Set a HTTP header
  ///
  void header(String name, String value) {
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

    var values = _headers[name];
    if (values == null) {
      values = new List<String>();
      _headers[name] = values;
    }
    _headers[name].add(value);
  }

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
  /// Typically, the [Cookies.path] should be set to the server's [Server.basePath].
  /// For improved security, the [Cookies.httpOnly] should be set to true.
  ///
  /// The [Cookies.name] must not be the same as the server's [Server.sessionCookieName].
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
    _cookies.add(cookie);
  }

  void cookieDelete(String name, [String path, String domain]) {
    if (_headersOutputted) {
      throw new StateError("Header already outputted");
    }
    var delCookie = new Cookie(name, "");
    delCookie.path = path;
    delCookie.domain = domain;
    delCookie.expires = new DateTime.utc(1970, 1, 1, 0, 0, 1, 0);
    delCookie.maxAge = 0;
    return cookieAdd(delCookie);
  }

  /// Output the status and headers.
  ///
  void _outputHeaders(Request req) {
    if (_headersOutputted) {
      throw new StateError("Header already outputted");
    }

    // Check that application has not tried to use the session cookie
    var sessionCookieName = req.server.sessionCookieName;
    for (var c in _cookies) {
      if (c.name == sessionCookieName) {
        throw new ArgumentError.value(
            c.name, "cookieName", "Clashes with name of session cookie");
      }
    }

    if (req._sessionUsingCookies) {
      // Set up cookie for session management

      if (req.session != null) {
        // Need to set the session cookie
        var c = new Cookie(req.server.sessionCookieName, req.session.id);
        c.path = req.server.basePath;
        c.httpOnly = true;
        if (req.server.sessionCookieForceSecure || req.server.isSecure) {
          c.secure = true; // HTTPS only: better security, but not for testing
        }
        this.cookieAdd(c);
      } else if (req._sessionWasSetInRequest) {
        // Need to clear the session cookie
        cookieDelete(req.server.sessionCookieName, req.server.basePath);
      }
    }
    // Output the status, headers and cookies

    var response = req.request.response;

    response.statusCode = _status;
    response.headers.contentType = _contentType;
    response.cookies.addAll(_cookies);

    for (var name in _headers.keys) {
      for (var value in _headers[name]) {
        response.headers.add(name, value);
      }
    }

    _headersOutputted = true;
  }

  /// Method that is invoked at the end of creating the HTTP response.
  ///
  /// The framework automatically invokes this method when it creates a HTTP
  /// response from the [Request] object returned by the application's request
  /// handler or exception handler.
  ///
  /// The implementation in the base [Request] class does nothing. But an
  /// application could create their own subclass (usually of [RequestBuffered],
  /// [RequestStream]) and implement its own [finish] method. A typical use of a
  /// subclass is to generate HTML pages for an application: the subclass's
  /// constructor could produce the common HTML headers and the subclass's
  /// [finish] method could produce the common HTML footers.

  Future finish(Request req) async {
    // do nothing
  }

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
  StringBuffer _buf = new StringBuffer();
  bool _contentOutputted = false;

  ResponseBuffered(ContentType ct) {
    if (ct != null) {
      _contentType = ct;
    }
  }

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
  void _finish(Request req) {
    if (req == null) {
      throw new ArgumentError.notNull("req");
    }
    if (_contentOutputted) {
      throw new StateError("Content already outputted");
    }
    super._outputHeaders(req);

    var str = _buf.toString();
    req.request.response.write(str);

    _logResponse.fine(
        "[${req.id}] status=${_status}, contentSize=${str.length} bytes");
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
  bool _contentOutputted = false;

  ResponseStream(ContentType ct) {
    if (ct != null) {
      _contentType = ct;
    }
  }

  /// Provide a stream that produces the content.
  ///
  /// Note: any headers must be defined before this method is called.
  /// Headers cannot be defined after the stream has started.

  Future<ResponseStream> addStream(Request req, Stream<List<int>> stream) async {
    if (req == null) {
      throw new ArgumentError.notNull("req");
    }
    if (_contentOutputted) {
      throw new StateError("Stream content already added");
    }

    super._outputHeaders(req);
    await req.request.response.addStream(stream);
    _contentOutputted = true;

    return this;
  }

  /// Produce the response.
  ///
  void _finish(Request req) {
    if (req == null) {
      throw new ArgumentError.notNull("req");
    }
    if (!_contentOutputted) {
      throw new StateError("Stream content was not added");
    }
    super._finish(req);
  }
}

//================================================================
/// HTTP response that redirects the browser to a URL.
///
class ResponseRedirect extends Response {
  // The address to redirect to.
  //
  // Can be a internal relative-path or an external URL.

  String _addr;

  /// Constructor.
  ///
  /// The response will redirect the browser to [url], which can be
  /// a relative to the deployment URL (i.e. starts with "~/") or a real URL.
  ///
  /// The [status] must be a redirection HTTP status code.
  ///
  /// The default status is [HttpStatus.SEE_OTHER] (303).
  /// Other commonly used values are [HttpStatus.MOVED_PERMANENTLY] (301) and
  /// [HttpStatus.MOVED_TEMPORARILY] (302).
  ///
  /// The value of [HttpStatus.TEMPORARY_REDIRECT] (307) is used when the method
  /// is preserved. That is, GET request is redirected to a GET request
  /// and a POST request is redirected to a POST request. Old browsers might
  /// not support this status code.
  ///
  /// For more information on HTTP status codes, see
  /// <https://www.w3.org/Protocols/rfc2616/rfc2616-sec10.html#sec10.3>

  ResponseRedirect(String addr, {int status: HttpStatus.SEE_OTHER}) {
    if (status < 300 || 399 < status) {
      throw new ArgumentError.value(
          status, "status", "ResponseRedirect: not a redirection HTTP status");
    }
    if (addr == null) {
      throw new ArgumentError.notNull("ResponseRedirect.addr");
    }
    if (addr.isEmpty) {
      throw new ArgumentError.value(addr, "addr", "ResponseRedirect: empty string");
    }
    if (addr.startsWith("/")) {
      _logResponse.warning("ResponseRedirect address should start with '~/' : $addr");
    }

    _addr = addr;

    this.status = status;
  }

  /// Produce the response.
  ///
  void _finish(Request req) {
    if (req == null) {
      throw new ArgumentError.notNull("req");
    }

    var url = (_addr.startsWith("~/")) ? req.rewriteUrl(_addr) : _addr;

    _logResponse.fine("[${req.id}] redirecting to ${url}");

    header('Location', url);
    super._outputHeaders(req);
    req.request.response.write("Redirect\n");
    super._finish(req);
  }
}
