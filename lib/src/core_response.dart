part of woomera;

//================================================================
/// The abstract core response.
///
/// This is an abstract class used by [Request] to represent the underlying
/// response that will be produced.
///
/// The _Request_ wull use a [_CoreResponseReal] when dealing with real HTTP
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

  /// Set the body
  ///
  /// This method requires both the String representation as well as the
  /// encoded representation of that string. That is because the
  /// [_CoreResponseReal] uses the encoded version and the
  /// [_CoreResponseSimulated] uses the string version.

  void _setBody(String unencoded, List<int> encoded);

  /// Adds all elements of the given [stream] to `this`.
  ///
  /// Returns a [Future] that completes when
  /// all elements of the given [stream] are added to `this`.

  Future addStream(Stream<List<int>> stream);
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
  void _setBody(String unencoded, List<int> encoded) {
    // Use the encoded version of the body
    _httpResponse.add(encoded);
  }

  @override
  Future addStream(Stream<List<int>> stream) => _httpResponse.addStream(stream);
}

//================================================================
/// Implementation of [_CoreResponse] for simulated HTTP requests.
///
/// It stores and returns the values passed to its constructor.
/// That constructor is invoked by [Request.simulated], [Request.simulatedGet]
/// and [Request.simulatedPost] - the constroctors used for simulated HTTP
/// requests.

class _CoreResponseSimulated extends _CoreResponse {
  /// Constructor

  _CoreResponseSimulated();

  @override
  int status;

  @override
  final HttpHeaders headers = new SimulatedHttpHeaders();

  @override
  List<Cookie> cookies = <Cookie>[];

  //----------------------------------------------------------------

  String _bodyStr;

  @override
  void _setBody(String unencoded, List<int> encoded) {
    // Use the string version of the body
    assert(_bodyStr == null, 'string value for body already set');
    _bodyStr = unencoded;
  }

  /// Returns the string value of the body, or null if [_setBody] was not used.
  String get bodyStr => _bodyStr;

  List<int> _byteBuf;

  @override
  Future addStream(Stream<List<int>> stream) async {
    _byteBuf ??= <int>[];

    // ignore: prefer_foreach
    await for (var data in stream) {
      _byteBuf.addAll(data);
    }
  }

  /// Returns the bytes of the body, or null if [addStream] was not used
  List<int> get bodyBytes => _byteBuf;
}
