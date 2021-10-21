part of core;

//################################################################
/// The source format for the body in a simulated response.
///
/// See [SimulatedResponse] for details and the [SimulatedResponse.bodyType]
/// getter.

enum SimulatedResponseBodyType {
  /// There is no body.
  none,

  /// The source format of the body was a sequence of bytes.
  bytes,

  /// The source format of the body was a String.
  string
}

//################################################################
/// Response returned by simulations.
///
/// The [Server.simulate] method returns an instance of this class.
///
/// This class extends [Response] with methods to retrieve the body of the
/// HTTP response. The other response classes (used by request handlers to
/// produce HTTP responses) only allow the body to be produced.
///
/// **Body**
///
/// The body of the simulated response can be retrieved as a sequence of bytes
/// using [bodyBytes], or as a String using either [bodyStr] or [bodyString].
///
/// The Handler that produced the response could have provided the body as
/// a sequence of bytes, a String, or not provided any body at all. The
/// simulated response internally stores any body in its source format.
///
/// The retrieval methods encode/decode the source into the desired format,
/// if needed. If the source was a String, then _bodyString_
/// does not perform any encoding; but _bodyBytes_ will require encoding the
/// string value into bytes. If the source was a sequence of bytes, then
/// _bodyBytes_ does not perform any decoding; but retrieving it with
/// _bodyString_ will require decoding those bytes into a String.
/// The _bodyStr_ getter is a convenience method for invoking _bodyString_
/// with the UTF-8 encoding.
///
/// The [bodyIsEmpty] getter indicates if the body has content or not.
/// This is more efficient than retrieving the body and then checking if it
/// is empty or not, since no encoding/decoding will be performed.
///
/// The source format of the body can be determined from the [bodyType].

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
        _body = SimulatedResponseBodyType.string;
      } else if (core.hasBodyBytes) {
        _bodyBytes = core.bodyBytes();
        _body = SimulatedResponseBodyType.bytes;
      } else {
        throw StateError('core has neither bytes or string body');
      }
    } else {
      _body = SimulatedResponseBodyType.none;
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

  late final SimulatedResponseBodyType _body;

  late final String? _bodyStr; // store complete body

  late final List<int>? _bodyBytes; // store streamed body

  //================================================================
  // Methods

  //----------------------------------------------------------------
  /// The source format of the body.
  ///
  /// Indicates if there is a body, and (if there is) whether its source format
  /// was a String or a sequence of bytes.

  SimulatedResponseBodyType get bodyType => _body;

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
  /// If the source format of the body is a String, it is returned and the
  /// _encoding_ is not used.
  ///
  /// If the source format of the body is a sequence of bytes, it is converted
  /// to a String using the decoder of the [encoding]. Note: if the _encoding_
  /// is `utf8`, this method may throw a [FormatException] when the bytes
  /// do not represent a valid UTF-8 encoded code point.
  ///
  /// If there is no source for the body, returns the empty string.
  ///
  /// **Related methods**
  ///
  /// Use [bodyBytes] to retrieve the body as a sequence of bytes.
  ///
  /// Use [bodyStr] as a shorthand for invoking this method with the [utf8]
  /// encoding.
  ///
  /// If retrieving the String to only see if it is empty, use [bodyIsEmpty]
  /// instead (which works more efficiently if the body had been set to
  /// a sequence of bytes, since it doesn't need to decode them).

  String bodyString(Encoding encoding) {
    switch (_body) {
      case SimulatedResponseBodyType.none:
        return ''; // empty String
      case SimulatedResponseBodyType.bytes:
        return encoding.decode(_bodyBytes!);
      case SimulatedResponseBodyType.string:
        return _bodyStr!;
    }
  }

  //----------------------------------------------------------------
  /// Retrieves the body as a sequence of bytes.
  ///
  /// If the source format of the body is a sequence of bytes, it is returned
  /// and the _encoding_ is not used.
  ///
  /// If the source format of the body is a String, it is converted to a
  /// sequence of bytes using the encoder of the [encoding].
  ///
  /// If there is no source for the body, returns an empty list.
  ///
  /// **Related methods**
  ///
  /// Use [bodyStr] or [bodyString] to retrieve the body as a String.
  ///
  /// If retrieving the bytes to only see if they are empty, use [bodyIsEmpty]
  /// instead (which works more efficiently if the body had been set to a
  /// String, since it doesn't need to encode it).

  List<int> bodyBytes(Encoding encoding) {
    switch (_body) {
      case SimulatedResponseBodyType.none:
        return <int>[]; // empty list of bytes
      case SimulatedResponseBodyType.bytes:
        return _bodyBytes!;
      case SimulatedResponseBodyType.string:
        return encoding.encode(_bodyStr!);
    }
  }

  //----------------------------------------------------------------
  /// Indicates if there is a body has content or not.
  ///
  /// Returns true if the body is non-empty (i.e. has been set to more than one
  /// byte or a string with one or more characters).
  ///
  /// Returns true if the body has not been set, or has been set to zero bytes
  /// or an empty string.

  bool get bodyIsEmpty {
    switch (_body) {
      case SimulatedResponseBodyType.none:
        return true;
      case SimulatedResponseBodyType.bytes:
        final b = _bodyBytes;
        return b == null || b.isEmpty;
      case SimulatedResponseBodyType.string:
        final s = _bodyStr;
        return s == null || s.isEmpty;
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

    buf
      ..write('\n')
      ..write(bodyStr);

    return buf.toString();
  }
}
