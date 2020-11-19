part of core;

//================================================================
/// Handler for proxying requests to another server.
///
/// Example:
///
/// ```dart
/// proxy = Proxy('GET', '~/foobar/*', 'http://example.com');
/// proxy.register(pipeline);
/// ```
///
/// GET requests for '~/foobar/abc/def' will return the response from
/// sending a request to "http://example.com/abc/def".

class Proxy {
  //================================================================
  // Constructors

  //----------------------------------------------------------------
  /// Create a request handler that proxies requests to another URL.
  ///
  /// This request handler is used to handle requests that match the [method]
  /// and [pattern]. The pattern must end with a "*" (e.g. "~/*" or
  /// "~/foobar/*"). The path that matches the "*" is the sub-path.
  ///
  /// When handling a request, it will make a proxy request to a URL that is
  /// made up of the [proxy] with the sub-path appended. The response from that
  /// proxy request is forwarded back as the response.
  ///
  /// A "Via" header is always added to the proxy request. The value of [via]
  /// is used, unless it is null or the empty string. Otherwise, a default
  /// value is used. A "Via" header containing the same value is added to the
  /// response, unless [includeViaHeaderInResponse] is false.

  Proxy(this.method, String pattern, String proxy,
      {String via,
      this.includeViaHeaderInResponse = true,
      @deprecated Iterable<String> requestBlockHeaders,
      @deprecated Iterable<String> responseBlockHeaders})
      : _via = (via != null && via.isNotEmpty) ? via : _viaDefault {
    if (method != 'GET' && method != 'HEAD') {
      throw ArgumentError.value(
          method, 'method', 'only GET and HEAD supported');
    }

    if (!pattern.startsWith('~/')) {
      throw ArgumentError.value(pattern, 'pattern', 'does not start with "~/"');
    }

    if (!pattern.endsWith('/*')) {
      throw ArgumentError.value(pattern, 'pattern', 'does not end with "*"');
    }

    _pathPrefix =
        pattern == '~/*' ? '' : pattern.substring(2, pattern.length - 2);
    _proxyHost = proxy;

    // Store lower case versions of headers to block.

    if (requestBlockHeaders != null) {
      for (final name in requestBlockHeaders) {
        this.requestBlockHeaders.add(name.toLowerCase());
      }
    }

    if (responseBlockHeaders != null) {
      for (final name in responseBlockHeaders) {
        this.responseBlockHeaders.add(name.toLowerCase());
      }
    }
  }

  //================================================================
  // Static constants

  /// Headers in the request which are never passed through to the target.
  ///
  /// Important: these must be in all lowercase, otherwise matching won't work.

  static const List<String> requestHeadersNeverPass = [
    'host', // host will be recreated for the request
    'connection', // HTTP/1.1 keep-alive is not supported
    'keep-alive',
    'te',
    'upgrade',
    'upgrade-insecure-requests', // should this be included or not?
    'proxy-authorization',
  ];

  /// Headers in the response which are never passed through to the client.
  ///
  /// Important: these must be in all lowercase, otherwise matching won't work.

  static const List<String> responseHeadersNeverPass = [
    'content-type', // content-type will be recreated for the response
    'connection', // HTTP/1.1 keep-alive is not supported
    'keep-alive',
    'transfer-encoding',
    'trailer',
    'proxy-authenticate',
  ];

  // Default value to use for the "Via" header when forwarding the request.
  // Used when no value of via was provided.

  static const String _viaDefault = '1.1 woomera_proxy';

  //================================================================
  // Members

  /// The HTTP method to proxy for.

  final String method;

  String _proxyHost;

  String _pathPrefix;

  /// Value for the "Via" header.

  final String _via;

  /// Indicates if a Via header is added to the response.

  final bool includeViaHeaderInResponse;

  /// Additional request headers which are not passed through to the target.
  ///
  /// In addition to the [requestHeadersNeverPass], these headers are also not
  /// passed through in the request.
  ///
  /// Set this value in the constructor.

  final List<String> requestBlockHeaders = [];

  /// Additional response headers which are not passed through to the client.
  ///
  /// In addition to the [responseHeadersNeverPass], these headers are also not
  /// passed through in the response.
  ///
  /// Set this value in the constructor.

  final List<String> responseBlockHeaders = [];

  //================================================================
  // Methods

  //----------------------------------------------------------------
  /// Register a proxy with a pipeline.

  void register(ServerPipeline ws) {
    assert(method == 'GET' || method == 'HEAD',
        'only GET and HEAD is implemented right now');
    // ignore: unnecessary_lambdas
    ws.register(method, '~/$_pathPrefix/*', (req) => handleGetOrHead(req));
  }

  //----------------------------------------------------------------
  /// Derive the target URI from the request.

  String _targetUri(Request req) {
    final values = req.pathParams.values('*');

    assert(values.isEmpty || values.length == 1,
        'Proxy registered without exactly one *: $_proxyHost/$_pathPrefix');

    final subPath = (values.isNotEmpty) ? values.first : null;

    final fullPath = (_pathPrefix != null && _pathPrefix.isNotEmpty)
        ? ((subPath != null) ? '$_pathPrefix/$subPath' : _pathPrefix)
        : ((subPath != null) ? subPath : '');

    // Build the target URL

    final buf = StringBuffer('$_proxyHost/$fullPath');

    if (req.queryParams.isNotEmpty) {
      // Add all the query parameters to the URL

      var sep = '?';
      for (var key in req.queryParams.keys) {
        for (var value in req.queryParams.values(key, mode: ParamsMode.raw)) {
          buf
            ..write(sep)
            ..write(Uri.encodeQueryComponent(key))
            ..write('=')
            ..write(Uri.encodeQueryComponent(value));
          sep = '&';
        }
      }
    }

    // Return the target URI

    return buf.toString();
  }

  //----------------------------------------------------------------
  /// GET or HEAD request handler.
  ///

  Future<Response> handleGetOrHead(Request req) async {
    _logProxy.fine('[${req.id}] $method ${req.requestPath()}');

    // Determine the target URI for the proxy request

    final targetUrl = _targetUri(req);
    _logProxyRequest.finer('[${req.id}] $method $targetUrl');

    try {
      // Determine headers for the proxy request

      final _prHeaders = await _proxyRequestHeaders(req, targetUrl);

      // Perform the proxy request

      final targetResponse = await http.get(targetUrl, headers: _prHeaders);
      assert(targetResponse != null);

      // Produce the response from the response of the proxy request

      return await _produceResponse(req, targetResponse);
    } catch (e) {
      final proxyException = ProxyHandlerException(targetUrl, e);
      _logProxy.fine('[${req.id}] $proxyException');
      throw proxyException;
    }
  }

  //----------------

  Future<Map<String, String>> _proxyRequestHeaders(
      Request req, String targetUrl) async {
    // Determine the request headers to send to the target
    //
    // Note: the 'http' package does not support multiple headers with the
    // same name (which are possible in HTTP).

    final passHeaders = <String, String>{};

    // New "Host" header for outgoing request

    final u = Uri.parse(targetUrl);
    final _newHost = (u.hasPort) ? '${u.host}:${u.port}' : u.host;
    passHeaders['host'] = _newHost;
    _logProxyRequest.finest('[${req.id}] + host=$_newHost');

    // Identify any connection headers that must not be passed through

    // ignore: prefer_collection_literals
    final requestConnectionExclude = Set<String>();

    final c = req.headers['connection'];
    if (c != null) {
      for (final v in c) {
        for (final name in v.split(',')) {
          requestConnectionExclude.add(name.trim().toLowerCase());
        }
      }
    }

    // Headers from incoming request to outgoing request

    req.headers.forEach((key, values) {
      final headerName = key.toLowerCase();

      if ((requestHeadersNeverPass.contains(headerName) ||
              requestConnectionExclude.contains(headerName.toLowerCase()) ||
              (requestBlockHeaders.contains(headerName))) ||
          headerName == 'via') {
        // Do not pass through header
        _logProxyRequest.finest('[${req.id}] - $headerName=${values.first}');
      } else {
        // Pass through header
        if (values.length == 1) {
          final value = values.first;
          _logProxyRequest.finest('[${req.id}]   $headerName=$value');
          passHeaders[headerName] = value;
        } else {
          _logProxyRequest
              .warning('[${req.id}] header not a single value: $headerName');
        }
      }
    });

    /// A "Via" header is _always_ added to forwarded requests.
    /// It is mandatory according to
    /// [RFC 7230](https://tools.ietf.org/html/rfc7230#section-5.7.1).

    final _newVia = req.headers['via'] != null
        ? '${req.headers['via'].where((s) => s.isNotEmpty).join(', ')}, $_via'
        : _via;

    passHeaders['via'] = _newVia;
    _logProxyRequest.finest('[${req.id}] + via=$_newVia');

    return passHeaders;
  }

  //----------------

  Future<Response> _produceResponse(
      Request req, http.Response targetResponse) async {
    // Log response status

    _logProxyResponse.finer('[${req.id}] status=${targetResponse.statusCode}');

    // Pass the target's response back as the response

    // Extract the Content-Type header to be used to create ResponseStream.
    //
    // If there is no Content-Type header, assume application/binary, since
    // ResponseStream must have a content type.

    final contentType = (targetResponse.headers.containsKey('content-type'))
        ? ContentType.parse(targetResponse.headers['content-type'])
        : ContentType.binary;

    _logProxyResponse.finest('[${req.id}] + content-type=$contentType');

    // Identify any connection headers that must not be passed through

    // ignore: prefer_collection_literals
    final responseConnectionExclude = Set<String>();

    final c2 = targetResponse.headers['connection'];
    if (c2 != null) {
      for (final name in c2.split(',')) {
        responseConnectionExclude.add(name.trim().toLowerCase());
      }
    }

    // Use the response from the target as the response
    //
    // Must use a _ResponseStream_ because the response body needs to be treated
    // as binary data and not a string in any particular encoding. Otherwise,
    // any encoding changes will not match the content-length header.

    final resp = ResponseStream(contentType)
      ..status = targetResponse.statusCode
      ..headerRemoveAll();

    // Above removes all default headers, since some/all of them might be
    // present in the proxy response. Only the ones from the proxy response will
    // appear in the response.
    //
    // Cannot blindly use resp.headerAdd since that could produce multiple
    // headers as well as we need to avoid this bug:
    //   https://github.com/dart-lang/sdk/issues/43627

    // Forward headers from proxy response to the response

    int _size;
    for (var key in targetResponse.headers.keys) {
      final headerName = key.toLowerCase();
      final headerValue = targetResponse.headers[key];

      if (responseHeadersNeverPass.contains(headerName) ||
          responseConnectionExclude.contains(headerName.toLowerCase()) ||
          (responseBlockHeaders.contains(headerName)) ||
          headerName == 'via') {
        // Do not pass back header
        _logProxyResponse.finest('[${req.id}] - $headerName=$headerValue');
      } else {
        // Pass header back to client
        if (headerName == 'content-length') {
          _size = int.parse(headerValue);
        }
        resp.headerAdd(headerName, headerValue);
        _logProxyResponse.finest('[${req.id}]   $headerName=$headerValue');
      }
    }

    // Via header

    if (includeViaHeaderInResponse) {
      /// A "Via" header is optional in forwarded responses according to
      /// [RFC 7230](https://tools.ietf.org/html/rfc7230#section-5.7.1).

      final _newVia = (targetResponse.headers['via'] != null)
          ? '${targetResponse.headers['via']}, $_via'
          : _via;

      resp.headerAdd('via', _newVia);
      _logProxyResponse.finest('[${req.id}] + via=$_newVia');
    }

    // Create a stream from the bodyBytes, and use it for the response

    _logProxy.finer('[${req.id}] status=${targetResponse.statusCode}');

    return await resp.addStream(req, () async* {
      final body = targetResponse.bodyBytes;
      assert(_size == null || _size == body.length);
      yield body;
    }());
  }
}
