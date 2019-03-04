part of woomera;

//================================================================
/// The abstract core request.
///
/// This is an abstract class used by [Request] to represent the underlying
/// request it is dealing with.
///
/// The _Request_ will use a [_CoreRequestReal] when dealing with real HTTP
/// requests, and a [_CoreRequestSimulated] when dealing with a simulated HTTP
/// request. This base class allows _Request_ to handle both types of HTTP
/// requests with the same code.

abstract class _CoreRequest {
  /// The HTTP request method.
  String get method;

  /// The HTTP headers.
  HttpHeaders get headers;

  /// The internal path (a string starting with "~/").
  String internalPath(String serverBasePath);

  /// The internal path as a sequence of components.
  ///
  /// Returns null if the request path is invalid (e.g. containing invalid
  /// percent encodings or "..").

  List<String> _pathSegments(String serverBasePath);

  /// The cookies in the request.
  List<Cookie> get cookies;

  /// The body of the HTTP request, as a sequence of bytes.
  Future<List<int>> bodyBytes(int maxSize);

  /// The body of the HTTP request, decoded as UTF-8 into a String.
  Future<String> bodyStr(int maxBytes);
}

//================================================================
/// Implementation of [_CoreRequest] for real HTTP requests.
///
/// It is a wrapper around the [HttpRequest] passed to its constructor.
/// That constructor is invoked by [Request..withHttpRequest], the constructor
/// that is used for real HTTP requests.

class _CoreRequestReal implements _CoreRequest {
  //================================================================
  /// Constructor

  _CoreRequestReal(this._httpRequest);

  //================================================================
  // Internal implementation
  //
  // This implementation stores the [HttpRequest] (provided to the [Request]
  // constructor) and the different methods extract values from it.

  final HttpRequest _httpRequest;

  //================================================================

  @override
  String get method => _httpRequest.method;

  @override
  String internalPath(String serverBasePath) {
    var p = _httpRequest.uri.path;

    if (p.startsWith(serverBasePath)) {
      // TODO: this needs more work to account for # and ? parameters

      if (p.length <= serverBasePath.length)
        p = "~/";
      else
        p = "~/${p.substring(serverBasePath.length)}";
    } else {
      p = "~/";
    }

    return p;
  }

  @override
  List<String> _pathSegments(String serverBasePath) {
    try {
      final segments = _httpRequest.uri.pathSegments;

      // TODO: remove the base path segments
      assert(serverBasePath == '/'); // TODO: support real values in base path
      if (serverBasePath != '/') {}

      if (segments.contains('..')) {
        _logRequest.finest('path contains "..": request rejected');
        return null;
      }

      return segments;
    } on FormatException catch (_) {
      // This is usually due to malformed paths, due to malicious attackers
      // For example putting "/certsrv/..%C0%AF../winnt/system32/cmd.exe" and
      // "/scripts/..%C1%1C../winnt/system32/cmd.exe"
      _logRequest.finest("invalid char encoding in path: request rejected");
      return null;
    }
  }

  @override
  HttpHeaders get headers => _httpRequest.headers;

  @override
  List<Cookie> get cookies => _httpRequest.cookies;

  //================================================================
  // Body
  //
  // With a [HttpRequest], the body is obtained from a stream of bytes.
  //
  // This implementation reads the stream and stores them in [_bodyBytes].
  // If the bytes are requested again, that cached copy is returned (since the
  // stream cannot be read again).
  //
  // The implementation of [bodyStr] obtains the bytes and decodes them as
  // UTF-8, storing the result in [_bodyStr]. If the string value is requested
  // again, the cached copy is returned to save decoding it again.
  //
  // Future implementations might need to support other encodings, in which case
  // the encoding for the cached string needs to be kept track of.

  List<int> _bodyBytes; // cache of bytes read in

  String _bodyStr; // cache of decoded string value

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
  // The HTTP request body as a UTF-8 string.

  @override
  Future<String> bodyStr(int maxBytes) async {
    if (_bodyStr == null) {
      // String not cached: get the bytes and decode them into the string cache
      final bytes = _bodyBytes ?? await bodyBytes(maxBytes);

      _bodyStr = utf8.decode(bytes, allowMalformed: false);
    }
    return _bodyStr;
  }
}

//================================================================
/// Implementation of [_CoreRequest] for simulated HTTP requests.
///
/// It stores and returns the values passed to its constructor.
/// That constructor is invoked by [Request.simulated], [Request.simulatedGet]
/// and [Request.simulatedPost] - the constroctors used for simulated HTTP
/// requests.

class _CoreRequestSimulated implements _CoreRequest {
  //================================================================
  /// Constructor

  _CoreRequestSimulated(this._method, this._internalPath,
      {this.queryParams,
      SimulatedHttpHeaders headers,
      List<Cookie> cookies,
      String bodyStr,
      List<int> bodyBytes})
      : _headers = headers ?? new SimulatedHttpHeaders(),
        _cookies = cookies ?? <Cookie>[],
        assert(!(bodyStr != null && bodyBytes != null), 'set only one body'),
        _bodyStr = bodyStr,
        _bodyBytes = bodyBytes {
    if (!_internalPath.startsWith('~/')) {
      throw ArgumentError.value(
          _internalPath, 'path', 'does not start with "~/"');
    }
  }

  //================================================================
  // Internal implementation
  //
  // This implementation stores the values provided by the application
  // (via one of the simulated constructors of a [Request]).

  final String _method;

  final String _internalPath;

  HttpHeaders _headers;

  List<Cookie> _cookies;

  List<int> _bodyBytes;

  String _bodyStr;

  /// The query parameters, or null
  final RequestParams queryParams;

  //================================================================

  /// HTTP method

  @override
  String get method => _method;

  // This implementation stores the internal path, so it does not have any
  // server base path to strip out.
  @override
  String internalPath(String serverBasePath) => _internalPath;

  @override
  HttpHeaders get headers => _headers;

  @override
  List<String> _pathSegments(String serverBasePath) {
    // Since this implementation stores the internal path as a string, just
    // split the string, remove the leading "~", and account for the special
    // case of the root path.

    final s = _internalPath.split('/');

    final firstItem = s.removeAt(0);
    assert(firstItem == '~');

    if (s.length == 1 && s.first.isEmpty) {
      // Internal path was "~/"
      return [];
    } else if (s.contains('..')) {
      _logRequest.finest('path contains "..": request rejected');
      return null;
    } else {
      // Success

      return s;
    }
  }

  @override
  List<Cookie> get cookies => _cookies;

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
  // Both are the value of the body, just in different forms.

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
}
