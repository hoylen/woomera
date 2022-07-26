part of core;

//################################################################
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

  //================================================================
  // Body methods

  /// The body of the HTTP request, as a list of bytes.
  Future<List<int>> bodyBytes(int maxSize);

  /// The body of the HTTP request, decoded as UTF-8 into a String.
  Future<String> bodyStr(int maxBytes);

  /// The body of the HTTP request as a stream of bytes.
  Stream<Uint8List> bodyStream();

  //================================================================

  /// Retrieves the session ID, if any.
  ///
  /// Returns the empty string if there is no session ID in the request, or
  /// there is something wrong with them (i.e. there are multiple different
  /// session IDs in the request).
  String _extractSessionId(Server server, Request req);
}

//################################################################
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
  // There are three methods to retrieve the body: [bodyBytes], [bodyStr]
  // and [bodyStream].
  //
  // The contents of the HTTP request body is provided by the [HttpRequest]
  // as a stream of bytes. Once read, a stream cannot be read again.
  //
  // If [bodyBytes] or [bodyStr] is invoked first, it reads the stream and
  // stores it (in either _bodyBytes or _bodyStr, respectively). It is stored
  // so the body can be retrieved by subsequent invocation of either method.
  //
  // The [bodyStream] is different: it does not store a copy of the body and
  // it can only be invoked at most once. It also cannot be used in conjunction
  // with the other two methods.
  //
  // Future implementations might need to support other encodings, in which case
  // the encoding for the cached string needs to be kept track of.

  /// Cache of bytes read in.
  ///
  /// This is set if [bodyBytes] was invoked first. Otherwise, it is null.
  ///
  /// If this is set, [_bodyStreamHasBeenRead] will be always be true and
  /// [_bodyStr] will always remain null.

  List<int>? _bodyBytes;

  /// Cache of string decoded from the body.
  ///
  /// This is set if [bodyStr] was invoked first. Otherwise, it is null.
  ///
  /// The [_bodyBytes] is never set if this is set to a value.

  /// If this is set, [_bodyStreamHasBeenRead] will always be true and
  /// [_bodyBytes] will always remain null.

  String? _bodyStr;

  /// Indicates if the stream has been read.
  ///
  /// This is set when any of the three body methods have been invoked.
  /// This prevents [bodyStream] from being invoked multiple times, or
  /// it being invoked before (or after) either [_bodyBytes] or [_bodyStr]
  /// have been (or will be) invoked.

  bool _bodyStreamHasBeenRead = false;

  //----------------------------------------------------------------
  // The HTTP request body as a list of bytes.

  @override
  Future<List<int>> bodyBytes(int maxSize) async {
    if (!_bodyStreamHasBeenRead) {
      assert(_bodyBytes == null);
      assert(_bodyStr == null);

      _bodyBytes = await _internalBodyBytes(maxSize);
      assert(_bodyStreamHasBeenRead);

      // Return the bytes that have just ben read in

      return _bodyBytes!;
    } else {
      if (_bodyBytes != null) {
        // Stream was previously read and stored as bytes
        return _bodyBytes!; // return the previously read in bytes
      } else if (_bodyStr != null) {
        // Stream was previously read and stored as a string
        return utf8.encode(_bodyStr!); // encode string in UTF-8
      } else {
        // Stream was previously used for [_bodyStream], so cannot be re-read
        throw StateError('bodyBytes cannot be invoked after bodyStream');
      }
    }
  }

  //----------------------------------------------------------------
  // The HTTP request body as a UTF-8 string.

  @override
  Future<String> bodyStr(int maxBytes) async {
    if (!_bodyStreamHasBeenRead) {
      assert(_bodyBytes == null);
      assert(_bodyStr == null);

      _bodyStr = utf8.decode(await _internalBodyBytes(maxBytes),
          allowMalformed: false);
      assert(_bodyStreamHasBeenRead);

      return _bodyStr!;
    } else {
      if (_bodyBytes != null) {
        // Stream was previously read and stored as bytes
        return utf8.decode(_bodyBytes!); // decode the previously read in bytes
      } else if (_bodyStr != null) {
        // Stream was previously read and stored as a string
        return _bodyStr!;
      } else {
        // Stream was previously used for [_bodyStream], so cannot be re-read
        throw StateError('bodyStr cannot be invoked after bodyStream');
      }
    }
  }

  //----------------------------------------------------------------
  // Internal method used by both [bodyBytes] and [bodyStr].

  Future<List<int>> _internalBodyBytes(int maxSize) async {
    final bytes = <int>[];
    await for (var chunk in bodyStream()) {
      if (maxSize < bytes.length + chunk.length) {
        throw PostTooLongException();
      }
      bytes.addAll(chunk);
    }

    return bytes;
  }

  //----------------------------------------------------------------
  // The HTTP body as a stream of bytes.

  @override
  Stream<Uint8List> bodyStream() {
    if (_bodyStreamHasBeenRead) {
      throw StateError(
          'bodyStream cannot be invoked after bodyBytes/bodyStr/bodyStream');
    }

    _bodyStreamHasBeenRead = true;
    return _httpRequest;
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
