part of core;

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

  List<String>? _pathSegments(String serverBasePath);

  /// Information about the client connection.
  ///
  /// Returns the client connection information.
  /// Returns null if the socket is not available.
  HttpConnectionInfo? get connectionInfo;

  /// Client certificate for client authenticated TLS connections.
  ///
  /// Returns the client certificate used to establish the TLS connection
  /// the request was sent over. Returns null if there was no client certificate
  /// (either because the connection was not over TLS, the server did not
  /// request the client to present a certificate, or the client did not provide
  /// one).
  X509Certificate? get certificate;

  /// The cookies in the request.
  List<Cookie> get cookies;

  /// The body of the HTTP request, as a sequence of bytes.
  Future<List<int>> bodyBytes(int maxSize);

  /// The body of the HTTP request, decoded as UTF-8 into a String.
  Future<String> bodyStr(int maxBytes);

  /// Retrieves the session ID, if any.
  ///
  /// Returns the empty string if there is no session ID in the request, or
  /// there is something wrong with them (i.e. there are multiple different
  /// session IDs in the request).
  String _extractSessionId(Server server, Request req);
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
      if (p.length <= serverBasePath.length) {
        p = '~/';
      } else {
        p = '~/${p.substring(serverBasePath.length)}';
      }
    } else {
      p = '~/';
    }

    return p;
  }

  @override
  List<String>? _pathSegments(String serverBasePath) {
    try {
      var segments = _httpRequest.uri.pathSegments;

      // Remove server base path from the start of the segments

      assert(serverBasePath.startsWith('/'));
      if (1 < serverBasePath.length) {
        final sbpSegments = serverBasePath.substring(1).split('/');

        if (segments.length < sbpSegments.length) {
          return null; // request's path is shorter than the server base path
        }
        for (var x = 0; x < sbpSegments.length; x++) {
          if (segments[x] != sbpSegments[x]) {
            return null; // request's path does not match the server base path
          }
        }

        segments = segments.sublist(sbpSegments.length); // remaining segments
      }

      // Check for malicious segments

      if (segments.contains('..')) {
        _logRequest.finest('path contains "..": request rejected');
        return null;
      }

      return segments;
    } on FormatException catch (_) {
      // This is usually due to malformed paths, due to malicious attackers
      // For example putting "/certsrv/..%C0%AF../winnt/system32/cmd.exe" and
      // "/scripts/..%C1%1C../winnt/system32/cmd.exe"
      _logRequest.finest('invalid char encoding in path: request rejected');
      return null;
    }
  }

  @override
  HttpConnectionInfo? get connectionInfo => _httpRequest.connectionInfo;

  @override
  X509Certificate? get certificate => _httpRequest.certificate;

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

  List<int>? _bodyBytes; // cache of bytes read in

  String? _bodyStr; // cache of decoded string value

  @override
  Future<List<int>> bodyBytes(int maxSize) async {
    if (_bodyBytes == null) {
      // Bytes not cached: read them in and Ystore them in the bytes cache

      _bodyBytes = <int>[];
      await for (var bytes in _httpRequest) {
        if (maxSize < _bodyBytes!.length + bytes.length) {
          throw PostTooLongException();
        }
        _bodyBytes!.addAll(bytes);
      }
    }

    return _bodyBytes!;
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
    return _bodyStr!;
  }

  //================================================================

  @override
  String _extractSessionId(Server server, Request req) {
    final id = req.id;

    // The session can be conveyed in three possible mechanisms:
    //
    // - session cookie;
    // - session query parameter (when using URL rewriting); or
    // - session POST parameter.
    //
    // Normally, at most one mechanism will be used. But there can be edge cases
    // where more than one mechanism is present. These are usually extremely
    // rare (e.g. the user switches cookies support on/off in their browser
    // while interacting with the Web application). When that happens, the
    // different mechanisms should have the same session value. But more rare is
    // if there are multiple _different_ session values (from different
    // mechanisms or multiples of the same mechanism).
    //
    // This method handles all these situations.

    // First, gather all the session ID values

    final candidates = <String>[];

    // 1. Look for session cookies

    var foundSessionCookie = false; // assume false unless one is found

    // Real requests may have a session cookie: look for it.

    for (var cookie in cookies) {
      if (cookie.name == server.sessionCookieName) {
        final value = cookie.value;
        if (value.isNotEmpty) {
          candidates.add(cookie.value);
          foundSessionCookie = true;
        }
      }
    }

    req._haveSessionCookie = foundSessionCookie;

    if (foundSessionCookie && !req._sessionUsingCookies) {
      // This should never happen!
      // Since _sessionUsingCookies is true if _coreRequest.cookies.isNotEmpty.
      //
      // But in production, this situation has occurred: it is as if the list
      // of cookies was initially empty and strangely now contains values.
      // How can that happen? It seems to happen consistently with one user
      // running FireFox on Ubuntu, so it doesn't appear to be a race condition
      // on the server side.

      _logSession.shout('[$id] cookies in request changed while processing!');
      if (!cookies.isNotEmpty) {
        // This is the test used to set _sessionUsingCookies.
        // So why does it indicate the list is empty, but iterating over it
        // (in the code above) finds values?
        _logSession.shout('[$id] cookies.isNotEmpty but there were cookies!');
      }

      // Update value, even though it should never change.
      // If this is not updated, URL rewriting may be used and that causes
      // future requests to have multiple session IDs, which is a worse
      // problem.
      req._sessionUsingCookies = true; // fix value since there are now cookies!
    }

    // 2. Look for session query parameters (i.e. URL rewriting)

    final _sessionQueryParams = req.queryParams.values(server.sessionParamName);
    if (_sessionQueryParams.isNotEmpty) {
      for (final value in _sessionQueryParams) {
        if (value.isNotEmpty) {
          candidates.add(value);
        }
      }
      req.queryParams._removeAll(server.sessionParamName);
    }

    // 2. Look for session POST parameters (i.e. URL rewriting in POST request)

    final _postP = req.postParams;
    if (_postP != null) {
      final _sessionPostParams = _postP.values(server.sessionParamName);
      if (_sessionPostParams.isNotEmpty) {
        for (var value in _sessionPostParams) {
          if (value.isNotEmpty) {
            candidates.add(value);
          }
        }
        _postP._removeAll(server.sessionParamName);
      }
    }

    // Secondly, determine the session ID (if any) to use

    var result = ''; // assume no session ID unless set by code below

    if (candidates.isEmpty) {
      _logSession.finest('[$id] no session ID in request');
    } else if (candidates.length == 1) {
      result = candidates.first; // typical case of one session ID
    } else {
      // Multiple session IDs found (need to sort it out)

      final firstValue = candidates.first;

      if (candidates.every((value) => value == firstValue)) {
        // There are multiple copies of the SAME session ID: return it
        result = firstValue;
      } else {
        // There are DIFFERENT session IDs: discard them all and treat the
        // situation as having no session ID. Something very strange went wrong.
        _logSession.severe('[$id] multiple session IDs: ignoring them all');
      }
    }

    return result;
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
      {required SimulatedHttpHeaders headers,
      required List<Cookie> cookies,
      this.sessionId = '',
      this.queryParams,
      HttpConnectionInfo? connectionInfo,
      X509Certificate? certificate,
      String? bodyStr,
      List<int>? bodyBytes})
      : _headers = headers,
        _connectionInfo = connectionInfo,
        _certificate = certificate,
        _cookies = cookies,
        _bodyStr = bodyStr,
        _bodyBytes = bodyBytes {
    if (!_internalPath.startsWith('~/')) {
      throw ArgumentError.value(
          _internalPath, 'path', 'does not start with "~/"');
    }

    if (bodyStr != null && bodyBytes != null) {
      throw ArgumentError('do not set body as both a String and bytes');
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

  // The body as a series of bytes.
  //
  // If the body has not been set, both [_bodyBytes] and [_bodyStr] are null.
  // Attempts to retrieve either the bytes or string returns an empty
  // list of bytes or the empty string, respectively.
  //
  // If the body has been set as bytes, then [_bodyBytes] is not null.
  //
  // If the body has been set as a string, then [_bodyStr] is not null.
  //
  // If the body has been set in one form and then retrieved in the other form,
  // then the other form is also set (i.e. both forms are available/cached).

  List<int>? _bodyBytes;

  // The body as a string.
  //
  // See [_bodyBytes].

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

      final decodedStr = utf8.decode(bytes);

      _bodyStr = decodedStr; // cache the body string value
      return decodedStr;
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

      final encodedAsBytes = utf8.encode(str);

      if (maxBytes < encodedAsBytes.length) {
        // Now we have the exact bytes, an exact check can be done
        throw PostTooLongException();
      }

      _bodyBytes = encodedAsBytes; // cache the body bytes value
      return encodedAsBytes;
    } else {
      // No body
      return <int>[];
    }
  }

  //================================================================
  // Session ID

  String sessionId;

  @override
  String _extractSessionId(Server server, Request req) => sessionId;
  // The implementation for a simulated request is trivial.
}
