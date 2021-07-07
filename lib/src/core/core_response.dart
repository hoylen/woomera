part of core;

//================================================================
/// The abstract core response.
///
/// This is an abstract class used by [Request] to represent the underlying
/// response that will be produced.
///
/// The _Request_ will use a [_CoreResponseReal] when dealing with real HTTP
/// requests, and a [_CoreResponseSimulated] when dealing with a simulated
/// HTTP request. This base class allows _Request_ to handle both types of
/// HTTP requests with the same code.

abstract class _CoreResponse {
  /// HTTP response status
  int get status;

  set status(int value);

  /// Headers
  HttpHeaders get headers;

  /// Cookies
  List<Cookie> get cookies;

  bool? _bodyIsString;

  bool get hasBody => _bodyIsString != null;

  bool get hasBodyString => _bodyIsString == true;

  bool get hasBodyBytes => _bodyIsString == false;

  //----------------------------------------------------------------
  // Body setting and getting methods

  /// Set the body with a string.
  ///
  /// The [_CoreResponseReal] class uses [setBodyFromBytes] while
  /// [_CoreResponseSimulated] uses [setBodyFromString].

  void setBodyFromString(String str, {Encoding encoding = utf8}) {
    assert(_bodyIsString == null);
    _bodyIsString = true;

    _setBodyFromString(str, encoding);
  }

  /// Set the body with a sequence of bytes.
  ///
  /// The [_CoreResponseReal] class uses [setBodyFromBytes] while
  /// [_CoreResponseSimulated] uses [setBodyFromString].

  void setBodyFromBytes(List<int> encoded) {
    assert(_bodyIsString == null);
    _bodyIsString = false;

    _setBodyFromBytes(encoded);
  }

  /// Adds all elements of the given [stream] to `this`.
  ///
  /// Returns a [Future] that completes when
  /// all elements of the given [stream] are added to `this`.

  Future addStream(Stream<List<int>> stream) {
    assert(_bodyIsString == null || _bodyIsString == false);
    _bodyIsString = false;

    return _addStream(stream);
  }

  void _setBodyFromString(String str, Encoding encoding);

  void _setBodyFromBytes(List<int> encoded);

  Future _addStream(Stream<List<int>> stream);
}

//================================================================
/// Implementation of [_CoreResponse] for real HTTP requests.
///
/// It is a wrapper around the [HttpResponse] passed to its constructor.
/// That constructor is invoked by [Request..withHttpRequest], the constructor
/// that is used for real HTTP requests.

class _CoreResponseReal extends _CoreResponse {
  /// Constructor

  _CoreResponseReal(this._httpResponse);

  final HttpResponse _httpResponse;

  @override
  int get status => _httpResponse.statusCode;

  @override
  set status(int s) {
    _httpResponse.statusCode = s;
  }

  @override
  HttpHeaders get headers => _httpResponse.headers;

  @override
  List<Cookie> get cookies => _httpResponse.cookies;

  @override
  void _setBodyFromString(String unencoded, Encoding encoding) {
    _httpResponse.add(encoding.encode(unencoded));
  }

  @override
  void _setBodyFromBytes(List<int> encoded) {
    _httpResponse.add(encoded);
  }

  @override
  Future _addStream(Stream<List<int>> stream) =>
      _httpResponse.addStream(stream);
}

//================================================================
/// Implementation of [_CoreResponse] for simulated HTTP requests.
///
/// It stores and returns the values passed to its constructor.
/// That constructor is invoked by [Request.simulated], [Request.simulatedGet]
/// and [Request.simulatedPost] - the constructors used for simulated HTTP
/// requests.

class _CoreResponseSimulated extends _CoreResponse {
  /// Constructor

  _CoreResponseSimulated();

  @override
  int status = HttpStatus.ok;

  @override
  final HttpHeaders headers = SimulatedHttpHeaders();

  @override
  List<Cookie> cookies = <Cookie>[];

  //----------------------------------------------------------------

  List<int>? _byteBuf;

  //----------------------------------------------------------------

  @override
  void _setBodyFromString(String unencoded, Encoding encoding) {
    _byteBuf = encoding.encode(unencoded);
  }

  @override
  void _setBodyFromBytes(List<int> encoded) {
    _byteBuf = encoded;
  }

  /// Returns the string value of the body
  ///
  /// Only valid if [_setBodyFromString] had been used.
  /// Otherwise, throws a [StateError].

  String bodyStr({Encoding encoding = utf8}) {
    final bytes = _byteBuf;

    if (bytes != null) {
      assert(_bodyIsString == true);
      return encoding.decode(bytes);
    } else {
      throw StateError('no String body');
    }
  }

  @override
  Future _addStream(Stream<List<int>> stream) async {
    _byteBuf ??= <int>[];

    // ignore: prefer_foreach
    await for (var data in stream) {
      _byteBuf!.addAll(data);
    }
  }

  /// Returns the bytes of the body.
  ///
  /// Only valid if [_setBodyFromBytes] or [_addStream] had been used.
  /// Otherwise, throws a [StateError].

  List<int> bodyBytes() {
    final _bytes = _byteBuf;
    if (_bytes != null) {
      assert(_bodyIsString == false);
      return _bytes;
    } else {
      throw StateError('no bytes body');
    }
  }
}
