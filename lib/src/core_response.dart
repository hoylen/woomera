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

  // Produce body
  /// Converts [obj] to a String by invoking [Object.toString] and
  //  [add]s the encoding of the result to the target consumer.

  void write(Object obj);

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
  void write(Object obj) {
    _httpResponse.write(obj);
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

  StringBuffer _strBuf;

  @override
  void write(Object obj) {
    _strBuf ??= new StringBuffer();
    _strBuf.write(obj);
  }

  /// Returns the string value of the body, or null if [write] was not used.
  String get bodyStr => _strBuf?.toString();

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
