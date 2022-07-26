part of core;

//################################################################
/// Implementation of [_CoreRequest] for simulated HTTP requests.
///
/// It stores and returns the values passed to its constructor.
/// That constructor is invoked by [Request.simulated], [Request.simulatedGet]
/// and [Request.simulatedPost] - the constructors used for simulated HTTP
/// requests.

class _CoreRequestSimulated implements _CoreRequest {
  //================================================================
  /// Constructor

  _CoreRequestSimulated(this._method, this._internalPath,
      {required SimulatedHttpHeaders headers,
      required List<Cookie> cookies,
      this.sessionId = '',
      this.queryParams,
      int? bodySteamEventSize,
      HttpConnectionInfo? connectionInfo,
      X509Certificate? certificate,
      String? bodyStr,
      List<int>? bodyBytes})
      : _headers = headers,
        _connectionInfo = connectionInfo,
        _certificate = certificate,
        _cookies = cookies,
        _bodySteamEventSize = bodySteamEventSize ?? _defaultBodySteamEventSize,
        _bodyStr = bodyStr,
        _bodyBytes = bodyBytes {
    if (!_internalPath.startsWith('~/')) {
      throw ArgumentError.value(
          _internalPath, 'path', 'does not start with "~/"');
    }
    if (_bodySteamEventSize <= 0) {
      throw ArgumentError.value(_bodySteamEventSize, 'bodySteamEventSize',
          'must be greater than zero');
    }
    if (bodyStr != null && bodyBytes != null) {
      throw ArgumentError('both bodyBytes and bodyStr cannot be set');
    }
  }

  //================================================================
  // Internal implementation
  //
  // This implementation stores the values provided by the application
  // (via one of the simulated constructors of a [Request]).

  final String _method;

  final String _internalPath;

  final HttpConnectionInfo? _connectionInfo;

  final X509Certificate? _certificate;

  final HttpHeaders _headers;

  final List<Cookie> _cookies;

  /// The body as a list of bytes.
  ///
  /// At most, only one of [_bodyBytes] or [_bodyStr] will have a value and the
  /// other will be null. They cannot both be set.
  ///
  /// If the body has not been set, they are both null.
  /// Attempts to retrieve either the bytes or string returns an empty
  /// list of bytes or the empty string, respectively.

  List<int>? _bodyBytes;

  // The body as a string.
  //
  // See comment on [_bodyBytes].

  String? _bodyStr;

  /// The query parameters

  final RequestParams? queryParams;

  //================================================================

  /// HTTP method

  @override
  String get method => _method;

  // This implementation stores the internal path, so it does not have any
  // server base path to strip out.
  @override
  String internalPath(String serverBasePath) => _internalPath;

  @override
  HttpConnectionInfo? get connectionInfo => _connectionInfo;

  @override
  X509Certificate? get certificate => _certificate;

  @override
  HttpHeaders get headers => _headers;

  @override
  List<String>? _pathSegments(String serverBasePath) {
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
  // Implementation of the core request bodyStr method.

  @override
  Future<String> bodyStr(int maxBytes) async {
    final str = _bodyStr;
    final bytes = _bodyBytes;

    if (str != null) {
      // Have string: return it

      if (maxBytes < str.length) {
        // Note: this is not exact, since the number of bytes needed to encode
        // in UTF-8 may be larger than the number of code points in the string.
        throw PostTooLongException();
      }

      return str;
    } else if (bytes != null) {
      // Have bytes: need to convert it into a string

      if (maxBytes < bytes.length) {
        throw PostTooLongException();
      }

      return utf8.decode(bytes);
    } else {
      // No body
      return '';
    }
  }

  //----------------------------------------------------------------
  /// Retrieves the entire body of the request as a sequence of bytes.

  @override
  Future<List<int>> bodyBytes(int maxBytes) async {
    final str = _bodyStr;
    final bytes = _bodyBytes;

    if (bytes != null) {
      // Have bytes: return it

      if (maxBytes < bytes.length) {
        throw PostTooLongException();
      }

      return bytes;
    } else if (str != null) {
      // Have string: need to convert it into bytes

      if (maxBytes < str.length) {
        // Note: this is not exact, since the number of bytes needed to encode
        // in UTF-8 may be larger than the number of code points in the string.
        throw PostTooLongException();
      }

      final asBytes = utf8.encode(str);

      if (maxBytes < asBytes.length) {
        // Now we have the exact bytes, an exact check can be done
        throw PostTooLongException();
      }

      return asBytes;
    } else {
      // No body
      return <int>[];
    }
  }

  //----------------------------------------------------------------
  /// Number of bytes per event when the body is retrieved as a stream.

  final int _bodySteamEventSize;

  static const _defaultBodySteamEventSize = 1024;

  //----------------------------------------------------------------
  /// Retrieves the entire body of the request as a stream of bytes.
  ///
  /// The stream delivers [_bodySteamEventSize] bytes at each event; except for
  /// the last event, which may contain fewer bytes.

  @override
  Stream<Uint8List> bodyStream() async* {
    List<int> allBytes;

    if (_bodyBytes != null) {
      // Have bytes
      allBytes = _bodyBytes!;
    } else if (_bodyStr != null) {
      // Have string: need to convert it into bytes
      allBytes = utf8.encode(_bodyStr!);
    } else {
      // No body
      allBytes = <int>[];
    }

    // Return the bytes as a stream of events

    assert(0 < _bodySteamEventSize);

    var offset = 0;
    while (offset < allBytes.length) {
      var end = offset + _bodySteamEventSize;
      if (allBytes.length < end) {
        end = allBytes.length;
      }
      final chunk = Uint8List.fromList(allBytes.sublist(offset, end));
      yield chunk;

      offset = end;
    }
  }

  //================================================================
  // Session ID

  String sessionId;

  @override
  String _extractSessionId(Server server, Request req) => sessionId;
// The implementation for a simulated request is trivial.
}
