part of core;

//================================================================
/// Abstract base class for a response.
///
/// The various handlers return a [Future] to an object based on
/// this type. See the [RequestHandler] and [ExceptionHandler] typedefs.

abstract class Response {
  //================================================================
  /// Constructor

  Response() {
    // Populate default headers
    //
    // This needs to explicitly manage these rather than accept them from
    // the default values populated in a [HttpResponse]. This is so it can
    // implement the [Proxy] request handler properly. When proxying requests,
    // it must respond with the header values from the target response rather
    // than the defaults from [HttpResponse].

    _headers[_headerCanonicalName('x-content-type-options')] = ['nosniff'];
    _headers[_headerCanonicalName('x-xss-protection')] = ['1; mode=block'];
    _headers[_headerCanonicalName('x-frame-options')] = ['SAMEORIGIN'];
  }

  //================================================================
  // Members

  /// Content-type of the response.

  ContentType? contentType;

  /// Headers that will be used to populate the response.
  ///
  /// Key is the header name as processed by [_headerCanonicalName].

  final Map<String, List<String>> _headers = {};

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
      throw StateError('Header already outputted');
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
  // Internal method to canonicalize name of headers.
  //
  // The keys to the [_headers] map use the canonical name.

  String _headerCanonicalName(String str) => str.trim().toUpperCase();

  //----------------------------------------------------------------
  /// Whether a header has been set or not.
  ///
  /// Returns true if one or more headers with the [name] has been set.
  ///
  /// The name is case-insensitive. The name is considered the same, whether it
  /// is represented using uppercase or lowercase letters.

  bool headerExists(String name) =>
      _headers.containsKey(_headerCanonicalName(name));

  //----------------------------------------------------------------
  /// Header names
  ///
  /// Returns an iterator to the names of the HTTP headers.
  ///
  /// This includes all the headers set using [headerAdd] or [headerAddDate],
  /// but will not necessarily be all the HTTP headers in the response.
  /// For example, "cookies" never appears and "content-type" usually does not
  /// appear.

  Iterable<String> headerNames() => _headers.keys;

  //----------------------------------------------------------------
  /// Header values
  ///
  /// Returns an iterator to the values of the HTTP headers that will be added
  /// to the HTTP response with [name].
  ///
  /// The name is case-insensitive. The name is considered the same, whether it
  /// is represented using uppercase or lowercase letters.
  ///
  /// Returns null if no headers exist with the name.

  Iterable<String>? headerValues(String name) =>
      _headers[_headerCanonicalName(name)];

  //----------------------------------------------------------------
  /// Adds a HTTP header
  ///
  /// Adds a HTTP header with the [name] and String [value] to the HTTP
  /// response.
  ///
  /// The name is case-insensitive. The name is considered the same, whether it
  /// is represented using uppercase or lowercase letters.
  ///
  /// The value is case sensitive.
  ///
  /// HTTP allows for multiple headers with the same name: the new header is
  /// added after any existing headers with the same name.
  ///
  /// Do not use this method for adding/setting the content type. Use the
  /// [contentType] member instead.
  ///
  /// Do not use this method for adding/setting cookies. Use the [cookieAdd] and
  /// [cookieDelete] methods. An exception will be raised if the name matches
  /// "set-cookie".

  void headerAdd(String name, String value) {
    ArgumentError.checkNotNull(name);
    ArgumentError.checkNotNull(value);

    if (name.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Empty string');
    }

    if (_headersOutputted) {
      throw StateError('Header already outputted');
    }

    final canonicalName = _headerCanonicalName(name);

    if (canonicalName == _headerCanonicalName('content-type')) {
      throw ArgumentError.value(
          canonicalName, 'name', 'use contentType to set Content-Type');
    }
    if (canonicalName == _headerCanonicalName('set-cookie')) {
      throw ArgumentError.value(
          canonicalName, 'name', 'use cookieAdd to set a cookie');
    }

    final _values = _headers[canonicalName];
    if (_values == null) {
      _headers[canonicalName] = <String>[value]; // create new list
    } else {
      _values.add(value); // append to existing list d
    }
  }

  //----------------------------------------------------------------
  /// Sets a HTTP header
  ///
  /// Sets a HTTP header to the [name] and String [value] to the HTTP
  /// response. Any existing header(s) with the same name are removed.
  ///
  /// The name is case-insensitive. The name is considered the same, whether it
  /// is represented using uppercase or lowercase letters.
  ///
  /// The value is case sensitive.
  ///
  /// Do not use this method for setting the content type. Use the
  /// [contentType] member instead.
  ///
  /// Do not use this method for setting cookies. Use the [cookieAdd] and
  /// [cookieDelete] methods. An exception will be raised if the name matches
  /// "set-cookie".

  void headerSet(String name, String value) {
    ArgumentError.checkNotNull(name);
    ArgumentError.checkNotNull(value);

    if (name.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Empty string');
    }
    if (_headersOutputted) {
      throw StateError('Header already outputted');
    }

    final canonicalName = _headerCanonicalName(name);

    if (canonicalName == _headerCanonicalName('content-type')) {
      throw ArgumentError.value(
          canonicalName, 'name', 'use contentType to set Content-Type');
    }
    if (canonicalName == _headerCanonicalName('set-cookie')) {
      throw ArgumentError.value(
          canonicalName, 'name', 'use cookieAdd to set a cookie');
    }

    _headers[canonicalName] = [value];
  }

  //----------------------------------------------------------------
  /// Adds a HTTP header containing a RFC1123 formatted date.
  ///
  /// Adds a HTTP header with the [name] and whose value is the [date] formatted
  /// according to `rfc1123-date` as defined by section 3.3.1 of RFC 2616
  /// <https://tools.ietf.org/html/rfc2616#section-3.3>. This is the date format
  /// that is preferred as an Internet standard and required by HTTP 1.1.
  /// For example, "Sun, 06 Nov 1994 08:49:37 GMT".
  ///
  /// The name is case-insensitive. The name is considered the same, whether it
  /// is represented using uppercase or lowercase letters.
  ///
  /// The date can either be in localtime or UTC. (The rfc1123-date is always
  /// encoded as GMT. This implementation assumes the GMT value is the same as
  /// UTC, even though in reality they are different.)
  ///
  /// HTTP allows for multiple headers with the same name: the new header is
  /// added after any existing headers with the same name.

  void headerAddDate(String name, DateTime date) {
    headerAdd(name, _rfc1123DateFormat(date));
  }

  //----------------------------------------------------------------
  /// Removes named header
  ///
  /// If no [value] is provided, removes all headers matching the [name]. That
  /// is, the header's value is ignored; and multiple headers are removed if
  /// there are more than one header with the name.
  ///
  /// If a [value] is provided, removes the first header that matches the [name]
  /// and has that value. If there are multiple headers for the name, those with
  /// other values or the other headers with the same value are not removed.
  ///
  /// Returns false if there was nothing to remove. Otherwise, true is returned.
  ///
  /// The name is case-insensitive. The name is considered the same, whether it
  /// is represented using uppercase or lowercase letters.

  bool headerRemove(String name, [String? value]) {
    final canonicalName = _headerCanonicalName(name);

    final _values = _headers[canonicalName];
    if (_values != null) {
      if (value == null) {
        // Remove all headers, regardless of their value(s)
        _headers.remove(canonicalName);
        return true;
      } else {
        // Only remove the first header with a matching value, if there is any.
        return _values.remove(value);
      }
    } else {
      // Name does not exist
      return false;
    }
  }

  //----------------------------------------------------------------
  /// Remove all headers.

  void headerRemoveAll() {
    _headers.clear();
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
      throw StateError('Header already outputted');
    }
    cookies.add(cookie);
  }

  /// Delete a cookie.
  ///
  void cookieDelete(String name, [String? path, String? domain]) {
    if (_headersOutputted) {
      throw StateError('Header already outputted');
    }
    try {
      // Normally, to delete a cookie, the value can be an empty string, but
      // since Dart 2.1.0 (at least until and including Dart 2.2.0), the
      // Cookie constructor throws a RangeError if passed an empty string.
      // So the dummy value of "_DEL_" is used.
      final delCookie = Cookie(name, '_DEL_')
        ..path = path
        ..domain = domain
        ..expires = DateTime.utc(1970, 1, 1, 0, 0, 1, 0)
        ..maxAge = 0;
      return cookieAdd(delCookie);
      // ignore: avoid_catching_errors
    } on RangeError {
      throw UnsupportedError(
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
      throw StateError('Header already outputted');
    }

    // Check that application has not tried to use the session cookie
    final sessionCookieName = req.server.sessionCookieName;
    for (var c in cookies) {
      if (c.name == sessionCookieName) {
        throw ArgumentError.value(
            c.name, 'cookieName', 'Clashes with name of session cookie');
      }
    }

    if (req._sessionUsingCookies) {
      // Set up cookie for session management

      final _session = req.session;
      if (_session != null) {
        // Need to set the session cookie
        final c = Cookie(req.server.sessionCookieName, _session.id)
          ..path = req.server.basePath
          ..httpOnly = true;
        if (req.server.sessionCookieForceSecure || req.server.isSecure) {
          c.secure = true; // HTTPS only: better security, but not for testing
        }
        cookieAdd(c);
      } else if (req._haveSessionCookie) {
        // Need to clear the session cookie
        cookieDelete(req.server.sessionCookieName, req.server.basePath);
      }
    }

    // Output the status, headers and cookies

    req._produceResponseHeaders(_status, contentType, cookies, _headers);

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
      throw StateError('Header has not been outputted');
    }
  }

  //================================================================
  // Static methods

  //----------------------------------------------------------------
  // Formats a DateTime for use in HTTP headers.
  //
  // Format a DateTime in the `rfc1123-date` format as defined by section 3.3.1
  // of RFC 2616 <https://tools.ietf.org/html/rfc2616#section-3.3>.

  static String _rfc1123DateFormat(DateTime datetime) {
    final u = datetime.toUtc();
    final wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][u.weekday - 1];
    final mon = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ][u.month - 1];
    final dd = u.day.toString().padLeft(2, '0');
    final year = u.year.toString().padLeft(4, '0');
    final hh = u.hour.toString().padLeft(2, '0');
    final mm = u.minute.toString().padLeft(2, '0');
    final ss = u.second.toString().padLeft(2, '0');

    return '$wd, $dd $mon $year $hh:$mm:$ss GMT';
  }
}

//================================================================
/// A response where the contents is buffered text.
///
/// The body is produced by one more more invocations of the [write] method,
/// which appends String values to form the body. The encoding of the body
/// is determined by the encoding specified to the constructor.
///
/// In the HTTP headers, a "Content-Type" header is automatically produced.
///
/// Do not use this type of response if the contents is binary data
/// (i.e. not [String]) and/or needs to be streamed to the client. Use the
/// [ResponseStream] for those types of responses.

class ResponseBuffered extends Response {
  //================================================================
  // Constructors

  //----------------------------------------------------------------
  /// Constructor
  ///
  /// The body of the HTTP response will be encoded using [encoding] (utf8 by
  /// default).
  ///
  /// If the content type [ct] has a character set, it must match the encoding.

  ResponseBuffered(ContentType ct, {Encoding? encoding})
      : _encoding = encoding ?? _defaultEncoding {
    // Check content type's character set is compatible with the encoding

    if (ct.charset != null && ct.charset != _encoding.name) {
      throw ArgumentError.value(ct, 'ct',
          'character set "${ct.charset}" != encoding "${_encoding.name}"');
    }

    contentType = ct;
  }

  //================================================================
  // Static members

  static final Encoding _defaultEncoding = utf8;

  //================================================================
  // Members

  final StringBuffer _buf = StringBuffer();

  final Encoding _encoding;

  bool _contentOutputted = false;

  //================================================================
  // Methods

  //----------------------------------------------------------------
  /// Append to the content.
  ///
  /// The string value of [obj] is appended to make up the body.

  void write(Object obj) {
    if (_contentOutputted) {
      throw StateError('Content already outputted');
    }
    _buf.write(obj);
  }

  //----------------------------------------------------------------
  /// Produce the response.

  @override
  void _finish(Request req) {
    ArgumentError.checkNotNull(req);

    if (_contentOutputted) {
      throw StateError('Content already outputted');
    }
    final body = _buf.toString();
    final encodedBody = _encoding.encode(body);

    if (!headerExists('content-length')) {
      // Automatically add a Content-Length header, if there is not one already
      // Need to used the encoded body to get this number.
      headerAdd('content-length', encodedBody.length.toString());
    }

    super._outputHeaders(req);

    req._outputBodyBytes(encodedBody);

    _logResponse
        .fine('[${req.id}] status=$_status, size=${encodedBody.length}');
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
    ArgumentError.checkNotNull(req);

    if (_streamState == 1) {
      throw StateError('addStream invoked when stream not finished');
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
    ArgumentError.checkNotNull(req);

    if (_streamState == 0) {
      throw StateError('Stream content was never added');
    }
    if (_streamState == 1) {
      throw StateError('Stream content stream source was not finished');
    }
    assert(_streamState == 2);

    _logResponse.fine('[${req.id}] status=$_status, stream');

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
  /// a relative to the deployment URL (i.e. starts with "~/") or a real URI
  /// (absolute or relative).
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

  ResponseRedirect(String addr, {int status = HttpStatus.seeOther})
      : _addr = addr,
        super() {
    if (status < 300 || 399 < status) {
      throw ArgumentError.value(
          status, 'status', 'ResponseRedirect: not a redirection HTTP status');
    }
    this.status = status;

    if (addr.isEmpty) {
      throw ArgumentError.value(addr, 'addr', 'ResponseRedirect: empty string');
    }
  }

  // The address to redirect to.
  //
  // Can be a internal relative-path or an external URL.

  final String _addr;

  /// Produce the response.
  ///
  @override
  void _finish(Request req) {
    final url = (_addr.startsWith('~/')) ? req.rewriteUrl(_addr) : _addr;

    _logResponse.fine('[${req.id}] status=$_status, redirect=$url');

    headerAdd('Location', url);
    super._outputHeaders(req);
    // Note: there is no body

    super._finish(req);
  }
}

//================================================================
/// HTTP response has no response body.

class ResponseNoContent extends Response {
  /// Constructor.
  ///
  /// The default status is [HttpStatus.noContent] (204) and no
  /// _Content-Type_ header.

  ResponseNoContent({int status = HttpStatus.noContent}) : super() {
    this.status = status;
  }

  /// Produce the response.
  ///
  @override
  void _finish(Request req) {
    _logResponse.fine('[${req.id}] no response body: status=$_status');

    super._outputHeaders(req);
    // Note: there is no body

    super._finish(req);
  }
}
