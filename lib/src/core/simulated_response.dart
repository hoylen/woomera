part of core;

//################################################################

enum _SimulatedResponseBody { none, bytes, string }

//################################################################
/// Response returned by simulations.
///
/// The [Server.simulate] method returns an instance of this class.
///
/// This class extends [Response] with methods to retrieve the body of the
/// HTTP response. The other response classes (used by request handlers to
/// produce HTTP responses) only allow the body to be produced.

class SimulatedResponse extends Response {
  //================================================================
  // Constructors

  //----------------------------------------------------------------
  /// Constructor
  ///
  /// Creates a simulated response.

  SimulatedResponse(_CoreResponseSimulated core, String sessionCookieName) {
    ArgumentError.checkNotNull(core);
    ArgumentError.checkNotNull(sessionCookieName);

    _status = core.status;

    contentType = core.headers.contentType;

    // Copy cookies from core's cookies (omitting any session cookie)

    assert(sessionId == null);

    for (var c in core.cookies) {
      if (c.name == sessionCookieName) {
        // Session cookie: do not copy it to the cookies, but use as sessionId

        final _maxAge = c.maxAge;
        final _expires = c.expires;

        if (c.value.isNotEmpty &&
            (_maxAge == null || 0 < _maxAge) &&
            (_expires == null || 1970 < _expires.year)) {
          // Is setting the session cookie (not deleting it): set the session
          assert(sessionId == null);
          sessionId = c.value;
        } else {
          // Not the session cookie: copy it
          cookieAdd(c);
        }
      }
    }

    // Copy headers from core's headers

    core.headers.forEach((name, values) {
      for (var v in values) {
        headerAdd(name, v);
      }
    });

    // Set the body using one of (but not both) string or bytes

    if (core.hasBody) {
      if (core.hasBodyString) {
        _bodyStr = core.bodyStr();
        _body = _SimulatedResponseBody.string;
      } else if (core.hasBodyBytes) {
        _bodyBytes = core.bodyBytes();
        _body = _SimulatedResponseBody.bytes;
      } else {
        throw StateError('core has neither bytes or string body');
      }
    } else {
      _body = _SimulatedResponseBody.none;
    }
  }

  //================================================================
  // Members

  //----------------------------------------------------------------
  /// Identification of the session.
  ///
  /// When not simulating, this value is communicated in the response using a
  /// session cookie or URL rewriting.

  String? sessionId;

  //----------------------------------------------------------------
  // The response body is either stored in [_bodyStr] or [_bodyBytes],
  // but never in both. The one that is used depends on whether the request
  // used a stream or not to produce the body. That is, if the
  // [Request._streamBody] or [Request._outputBody] was invoked by the
  // [Response]. Actually, it will be [RequestSimulated._streamBody] or
  // [RequestSimulated._outputBody], since this simulated response is only used
  // with a simulated request.
  //
  // When there is no body (e.g. with a redirect response), both are null.

  late final _SimulatedResponseBody _body;

  late final String? _bodyStr; // store complete body

  late final List<int>? _bodyBytes; // store streamed body

  //================================================================
  // Methods

  //----------------------------------------------------------------
  /// Retrieves the body as a String.
  ///
  /// The empty string is returned if there is no body.
  ///
  /// Throws a [FormatException] if the body contains a sequence of bytes that
  /// do not represent a UTF-8 encoded code point.
  ///
  /// Use [bodyBytes] to retrieve the body as a sequence of bytes.
  /// Use [bodyString] to interpret the body bytes as a string in an encoding
  /// other than UTF-8.

  String get bodyStr => bodyString(utf8);

  //----------------------------------------------------------------
  /// Retrieves the body as a String.
  ///
  /// The empty string is returned if there is no body.
  ///
  /// If the body is a sequence of bytes, it is converted to a string using
  /// the decoder of the [encoding]. If the _encoding_ is `utf8`, this method
  /// may throw a [FormatException] if the body contains a sequence of bytes
  /// that do not represent a UTF-8 encoded code point.
  ///
  /// Use [bodyBytes] to retrieve the body as a sequence of bytes.
  /// Use [bodyStr] as a shorthand for invoking this method with the [utf8]
  /// encoding.

  String bodyString(Encoding encoding) {
    switch (_body) {
      case _SimulatedResponseBody.none:
        return '';
      case _SimulatedResponseBody.bytes:
        return encoding.decode(_bodyBytes!);
      case _SimulatedResponseBody.string:
        return _bodyStr!;
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

  List<int> bodyBytes([Encoding enc = utf8]) {
    switch (_body) {
      case _SimulatedResponseBody.none:
        return <int>[]; // empty list of bytes
      case _SimulatedResponseBody.bytes:
        return _bodyBytes!;
      case _SimulatedResponseBody.string:
        return enc.encode(_bodyStr!);
    }
  }

  //----------------------------------------------------------------

  @override
  String toString() {
    final buf = StringBuffer('HTTP $status\n');

    if (sessionId != null) {
      buf.write('SESSION ID: $sessionId\n');
    }

    if (contentType != null) {
      buf.write('CONTENT-TYPE: $contentType\n');
    }

    for (var e in _headers.entries) {
      buf.write('${e.key}: ${e.value}\n');
    }

    for (var c in cookies) {
      buf.write('COOKIE: $c\n');
    }

    buf..write('\n')..write(bodyStr);

    return buf.toString();
  }
}
