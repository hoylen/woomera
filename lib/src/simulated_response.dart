part of woomera;

//================================================================
/// Response returned by simulations.
///
/// The [Server.simulate] method returns an instance of this class.
///
/// This class extends [Response] with methods to retrieve the body of the
/// HTTP response. The other response classes (used by request handlers to
/// produce HTTP responses) only allow the body to be produced.

class SimulatedResponse extends Response {
  //----------------------------------------------------------------
  /// Constructor

  SimulatedResponse(_CoreResponseSimulated core) {
    _status = core.status;

    contentType = core.headers.contentType;

    for (var c in core.cookies) {
      assert(c != null);
      cookieAdd(c);
    }

    // TODO: copy headers from core
    /*for (var k in core.headers.keys) {
      for (var v in core.headers[k]) {
        headerAdd(k, v);
      }
    }
    */

    // Set the body using one of (but not both) string or bytes

    assert(!(core.bodyStr != null && core.bodyBytes != null), 'both set');
    _bodyStr = core.bodyStr;
    _bodyBytes = core.bodyBytes;
  }

  //----------------------------------------------------------------
  // The response body is either stored in [_bodyStr] or [_bodyBytes],
  // but never in both. The one that is used depends on whether the request
  // used a stream or not to produce the body. That is, if the
  // [Request._streamBody] or [Request._outputBody] was invoked by the
  // [Response]. Acutally, it will be [RequestSimulated._streamBody] or
  // [RequestSimulated._outputBody], since this simulated response is only used
  // with a simulated request.
  //
  // When there is no body (e.g. with a redirect response), both are null.

  String _bodyStr; // store complete body

  List<int> _bodyBytes; // store streamed body

  //----------------------------------------------------------------
  /// Retrieves the body as a String.
  ///
  /// The empty string is returned if there is no body.
  ///
  /// Throws a [FormatException] if the body contains a sequence of bytes that
  /// do not represent a UTF-8 encoded code point.
  ///
  /// Use [bodyBytes] to retrieve the body as a sequence of bytes.

  String get bodyStr {
    if (_bodyStr != null) {
      assert(_bodyBytes == null, 'both _bodyBytes and _bodyStr are set');
      return _bodyStr;
    } else if (_bodyBytes != null) {
      return utf8.decode(_bodyBytes, allowMalformed: false);
    } else {
      return ''; // empty String
    }
  }

  //----------------------------------------------------------------
  /// Retrieves the body as a list of bytes.
  ///
  /// The empty list is returned if there is no body.
  ///
  /// If the handler produced a String value, the UTF-8 encoding of that
  /// value is returned.
  ///
  /// Use [bodyStr] to retrieve the body as a String.

  List<int> get bodyBytes {
    if (_bodyBytes != null) {
      assert(_bodyStr == null, 'both _bodyBytes and _bodyStr are set');
      return _bodyBytes;
    } else if (_bodyStr != null) {
      return utf8.encode(_bodyStr);
    } else {
      return <int>[]; // empty list of bytes
    }
  }

  //----------------------------------------------------------------

  @override
  String toString() {
    final buf = new StringBuffer('HTTP $status\n')
      ..write('Content-Type: $contentType\n');

    for (var k in headers.keys) {
      for (var v in headers[k]) {
        buf.write('$k: $v\n');
      }
    }

    for (var c in cookies) {
      buf.write('COOKIE: $c\n');
    }

    buf..write('\n')..write(bodyStr);

    return buf.toString();
  }
}
