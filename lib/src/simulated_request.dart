part of woomera;

//================================================================
/// Request used for simulations.

class RequestSimulated extends Request {
  //================================================================
  /// Constructor for a simulated request.

  RequestSimulated(String method, String path,
      {RequestParams queryParams, String id})
      : _method = method,
        _path = path,
        super._internal(id, true) {
    if (!_path.startsWith('~/')) {
      throw new ArgumentError.value(_path, '_path', 'does not start with "~/"');
    }

    // TODO _sessionUsingCookies = false;

    // TODO_queryParams = new RequestParams._internalConstructor();

    this.queryParams = queryParams ?? new RequestParams._internalConstructor();
  }

  //----------------------------------------------------------------
  /// Constructor for a simulated POST request.
  ///
  /// This is equivalent to creating a new [RequestSimulated] with the method
  /// set to "GET".

  RequestSimulated.get(String path, {RequestParams queryParams, String id})
      : _method = 'GET',
        _path = path,
        super._internal(id, true) {
    this.queryParams = queryParams ?? new RequestParams._internalConstructor();
  }
  //----------------------------------------------------------------
  /// Constructor for a simulated POST request.
  ///
  /// This is equivalent to creating a new [RequestSimulated] with the method
  /// set to "POS
  ///
  /// The [postParams] is mandatory, since a POST request usually includes some
  /// POST parameters. To create a simulated request without any POST
  /// parameters, use the [RequestSimulated] constructor.

  RequestSimulated.post(String path, RequestParams postParams,
      {RequestParams queryParams, String id})
      : _method = 'POST',
        _path = path,
        super._internal(id, true) {
    this.queryParams = queryParams ?? new RequestParams._internalConstructor();
    this.postParams = postParams;
  }

  //----------------------------------------------------------------

  @override
  Future _postParamsInit(int maxPostSize) async {
    // Don't need to do anything, because in a simulated request the application
    // must explicitly create the postParams before processing the request.

    assert(method == 'POST' || postParams == null,
        'postParams set when method is not POST');
    // contentType == 'application/x-www-form-urlencoded') {
  }

  //================================================================
  // Request details

  //----------------------------------------------------------------
  /// Request HTTP method

  @override
  String get method => _method;

  String _method;

  //----------------------------------------------------------------
  // URL path
  //
  // In this implementation, the request path is stored as a string value
  // in [_path].

  String _path;

  //----------------

  @override
  String requestPath() => _path;

  //----------------

  @override
  List<String> get _pathSegments {
    assert(_path.startsWith('~/'));

    final segments = _path.split('/');

    // Remove the first item, which will be caused by the "~/" at the beginning
    final prefix = segments.removeAt(0);
    assert(prefix == '~');

    // Special case for when the whole internal path is "~/": return empty list
    if (segments.length == 1 && segments.first.isEmpty) {
      segments.removeAt(0);
      assert(segments.isEmpty);
    }
//    final segments = _path.split('/')..removeWhere((seg) => seg.isEmpty);

    return segments;
  }

  //----------------------------------------------------------------
  // HTTP request headers

  HttpHeaders _headers; // TODO: set this

  @override
  HttpHeaders get headers => _headers;

  //----------------------------------------------------------------
  /// Cookies

  @override
  Iterable<Cookie> get cookies => _cookies;

  final List<Cookie> _cookies = [];

  //================================================================
  // Body
  //
  // The body of the simulated request is stored in the [_bodyBytes] and/or
  // [_bodyStr] members.
  //
  // If they are both null, there is no body.
  //
  // If one has a value and the other is null, the one is the value that was
  // set. The first time the other format is requested, it will be converted
  // from the set value and stored for future requests.
  //
  // If both are not null, then one was set and the other was converted from it.
  // Both are the value of the body, just in different formats.

  List<int> _bodyBytes;
  String _bodyStr;

  //----------------------------------------------------------------
  /// Set the body to a sequence of bytes

  void bodySetBytes(List<int> bytes) {
    _bodyBytes = bytes;
    _bodyStr = null; // clear any cached string
  }

  //----------------------------------------------------------------
  /// Set the body to a string.

  void bodySetStr(String string) {
    _bodyBytes = null; // clear any cached bytes
    _bodyStr = string;
  }

  //----------------------------------------------------------------

  @override
  Future<String> bodyStr(int maxBytes) async {
    if (_bodyStr != null) {
      // Have string: return it

      if (maxBytes < _bodyStr.length) {
        // Note: this is not exact, since the number of bytes needed to encode
        // in UTF-8 may be larger than the number of code points in the string.
        throw new PostTooLongException();
      }

      return _bodyStr;
    } else if (_bodyBytes != null) {
      // Have bytes: need to convert it into a string

      if (maxBytes < _bodyBytes.length) {
        throw new PostTooLongException();
      }
      _bodyStr = utf8.decode(_bodyBytes); // cache the string value
      assert(_bodyStr.length < maxBytes);
      return _bodyStr;
    } else {
      // No body
      return '';
    }
  }

  //----------------------------------------------------------------
  /// Retrieves the entire body of the request as a sequence of bytes.

  @override
  Future<List<int>> bodyBytes(int maxBytes) async {
    if (_bodyBytes != null) {
      // Have bytes: return it

      if (maxBytes < _bodyBytes.length) {
        throw new PostTooLongException();
      }

      return _bodyBytes;
    } else if (_bodyStr != null) {
      // Have string: need to convert it into bytes

      if (maxBytes < _bodyStr.length) {
        // Note: this is not exact, since the number of bytes needed to encode
        // in UTF-8 may be larger than the number of code points in the string.
        throw new PostTooLongException();
      }

      final _bodyBytes = utf8.encode(_bodyStr); // cache the bytes value

      if (maxBytes < _bodyBytes.length) {
        // Now we have the exact bytes, an exact check can be done
        throw new PostTooLongException();
      }

      return _bodyBytes;
    } else {
      // No body
      return <int>[];
    }
  }

  //================================================================
  // Session

  //----------------------------------------------------------------

  @override
  Future _sessionRestore() async {
    /*
    for (var cookie in cookies) {
      if (cookie.name == server.sessionCookieName) {
        _logSession.warning('in simulation, session cookie ignored');
      }
    }
    */

    for (var _ in queryParams.values(server.sessionParamName)) {
      _logSession.warning('in simulation, session query parameter ignored');
    }

    if (postParams != null) {
      for (var _ in postParams.values(server.sessionParamName)) {
        _logSession.warning('in simulation, session post parameter ignored');
      }
    }

    _sessionWasSetInRequest = (session != null);
  }

  //================================================================
  // Response producing methods

  //----------------------------------------------------------------

  @override
  void _produceResponseHeaders(int status, ContentType ct, List<Cookie> cookies,
      Map<String, List<String>> headers) {
    _simulatedResponse = new ResponseSimulated(status, ct, cookies, headers);
  }

  //----------------------------------------------------------------

  @override
  void _outputBody(String str) {
    assert(_simulatedResponse != null, '_produceResponseHeaders not invoked');

    _simulatedResponse._bodyStr = str;
  }

  //----------------------------------------------------------------

  @override
  Future _streamBody(Stream<List<int>> stream) async {
    assert(_simulatedResponse != null, '_produceResponseHeaders not invoked');

    // Create list on first invocation

    _simulatedResponse._bodyBytes ??= <int>[];

    // Append all items from [stream] to the list

    final byteBuf = _simulatedResponse._bodyBytes;
    await for (var data in stream) {
      assert(true);
      byteBuf.addAll(data);
    }
  }

  ResponseSimulated _simulatedResponse;
}
