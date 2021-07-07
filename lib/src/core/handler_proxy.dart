part of core;

//================================================================
/// Proxy for handling requests to another server.
///
/// **This is an experimental implementation.** It is not complete, so it
/// might not work in all situations.
///
/// Create _Proxy_ objects for the requests and then register request handlers
/// with the server's pipelines.
///
/// Example:
///
/// ```dart
/// final server = ...
///
/// final pipeline = ...
///
/// final proxy = Proxy('~/foobar/*', 'http://example.com');
///
/// // Register the proxy as the handler for the requests
///
/// pipeline.get(proxy.pattern, proxy.handler);
///
/// // Register all HTTP methods to proxy:
///
/// pipeline.head(proxy.pattern, proxy.handler);
/// pipeline.post(proxy.pattern, proxy.handler);
///
/// // The above syntax is equivalent to passing in a function that invokes the
/// // `handler` method on the _proxy_ object. That is,
/// //     pipeline.put(p.pattern, (r) => p.handler(r));
///
/// await server.run();
/// ```
///
/// GET/HEAD/POST requests for '~/foobar/abc/def' will return the response from
/// sending a request to "http://example.com/abc/def".
///
/// The _Proxy_ object constructor takes the pattern for the requests the
/// proxy will handle, and the URL that the requests will be sent to.
///
/// When registering request handlers, the _proxy.pattern_ getter should be used
/// to ensure consistency. If the registered pattern does not match the pattern
/// used to create the object, it might not work properly. Also, in the above
/// example, _proxy.handler_ is a tear-off which is equivalent to invoking
/// the _handler_ method on the _proxy_ object. That is, `p.handler` is
/// the same as creating a new function `(r) { return p.handler(r); }` that
/// invokes the method on the object.
///
/// ## Debugging client side Dart scripts
///
/// This was developed to proxy requests for the Web assets (e.g. images, CSS
/// and client side scripts) to a running "webdev serve" instance, so client
/// side Dart can be debugged in conjunction with a Web server running
/// server side Dart. Currently, this seems to work when `webdev serve`
/// is run with `--no-injected-client`. But it does not work with "webdev
/// daemon" (which is what _WebStorm_ uses to debug client side Dart).
/// So you can set Dart breakpoints in Chrome, but not in WebStorm.

class Proxy {
  //================================================================
  // Constructors

  //----------------------------------------------------------------
  /// Create a request handler that proxies requests to another URL.
  ///
  /// This request handler is used to handle requests that match the [pattern].
  /// The pattern MUST end with a wildcard segment "*" (e.g. "~/*" or
  /// "~/foobar/*"). The path that matches the "*" is the sub-path.
  ///
  /// When handling a request, it will make a proxy request to a URL that is
  /// made up of the [proxy] with the sub-path appended. The response from that
  /// proxy request is forwarded back as the response.
  ///
  /// A "Via" header is always added to the proxy request, but is optional for
  /// the proxy response. The value of [receivedBy] is used to generate the
  /// value of the proxy's Via header. A default value is used if _receivedBy_
  /// is a blank or empty string.
  ///
  /// The value of [includeViaHeaderInResponse] controls whether the proxy's
  /// Via header is added to the proxy response or not. It defaults to true.
  ///
  /// **Null-safety breaking change:** this deprecated named parameters
  /// _requestBlockHeaders_ and _responseBlockHeaders_ have been removed.
  /// If you were using them, please submit an issue in GitHub.

  Proxy(String pattern, String proxy,
      {String receivedBy = _receivedByDefault,
      this.includeViaHeaderInResponse = true})
      : _receivedBy = (receivedBy.trim().isNotEmpty)
            ? receivedBy.trim()
            : _receivedByDefault,
        _pathPrefix = _removeSlashes(pattern.substring(2, pattern.length - 1)),
        _targetUriPrefix = _removeSlashes(proxy) {
    // Set _pathPrefix (leading and trailing slashes are removed)
    // e.g. "~/" -> empty string
    // "~/foo/bar/*" -> "foo/bar"
    // "~/strange//*" -> "strange"
    // "~////very-strange////*" -> "very-strange"

    if (!pattern.startsWith('~/')) {
      throw ArgumentError.value(pattern, 'pattern', 'does not start with "~/"');
    }
    if (!pattern.endsWith('/*')) {
      throw ArgumentError.value(pattern, 'pattern', 'does not end with "/*"');
    }

    // _targetUriPrefix is set to a value with any trailing slashes removed
    // e.g. "http://remote.example.com/" -> "http://remove.example.com"

    /*
    Previous versions allowed headers to block to be specified.
    Probably no longer needed.

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
     */
  }

  static String _removeSlashes(String str) {
    var s = str;
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }

    while (s.startsWith('/')) {
      s = s.substring(1);
    }

    return s;
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

  // Default value to use for received-by in the "Via" header.
  //
  // This is used to identify the proxy when no value for received-by was
  // provided to the constructor.

  static const String _receivedByDefault = 'woomera_proxy';

  //================================================================
  // Members

  /// The URL of the target.

  final String _targetUriPrefix;

  /// Part of the path from the pattern.
  ///
  /// For example, if the pattern was "~/foo/*", this value will be "foo".
  /// Or if the pattern was "~/*", this value will be the empty string.

  final String _pathPrefix;

  /// Identifies this proxy in "Via" headers this proxy will add.

  final String _receivedBy;

  /// Indicates if a Via header is added to the response.
  ///
  /// Adding a Via header into the HTTP response is optional. This member
  /// controls whether it is added or not.

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

  /// Maximum size of POST contents before it is rejected.
  ///
  /// The number of raw bytes in the contents of the request. Change this to
  /// a different value to proxy larger POST requests.

  int postMaxRequestSize = 10 * 1024 * 1024;

  //================================================================
  // Methods

  //----------------------------------------------------------------

  /// The pattern handled for this proxy.
  ///
  /// This is a cleaned up version of the pattern that was passed to the
  /// constructor.

  String get pattern => _pathPrefix.isEmpty ? '~/*' : '~/$_pathPrefix/*';

  //----------------------------------------------------------------
  /// Derive the target URI from the request.

  Uri _targetUri(Request req) {
    final values = req.pathParams.values('*');

    assert(values.isEmpty || values.length == 1,
        'Proxy registered without exactly one *: $_targetUriPrefix/$_pathPrefix');

    final subPath = (values.isNotEmpty) ? values.first : null;

    final fullPath = (_pathPrefix.isNotEmpty)
        ? ((subPath != null) ? '$_pathPrefix/$subPath' : _pathPrefix)
        : ((subPath != null) ? subPath : '');

    // Build the target URL

    final buf = StringBuffer('$_targetUriPrefix/$fullPath');

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

    return Uri.parse(buf.toString());
  }

  //----------------------------------------------------------------
  /// Request handler.
  ///
  /// Invoke this method to handle the request.

  Future<Response> handler(Request req) async {
    final method = req.method;

    _logProxy.fine('[${req.id}] $method ${req.requestPath()}');

    // Determine the target URI for the proxy request

    final targetUrl = _targetUri(req);
    _logProxyRequest.finer('[${req.id}] $method $targetUrl');

    try {
      // Determine headers and body for the proxy request

      final r = await _proxyRequestHeaders(req, targetUrl);

      // Perform the proxy request

      http.Response targetResponse;
      switch (method) {
        case 'GET':
          targetResponse = await http.get(targetUrl, headers: r.headers);
          break;

        case 'HEAD':
          targetResponse = await http.head(targetUrl, headers: r.headers);
          break;

        case 'POST':
          targetResponse =
              await http.post(targetUrl, headers: r.headers, body: r.body);
          break;

        case 'PUT':
          targetResponse =
              await http.put(targetUrl, headers: r.headers, body: r.body);
          break;

        case 'PATCH':
          targetResponse =
              await http.patch(targetUrl, headers: r.headers, body: r.body);
          break;

        case 'DELETE':
          targetResponse = await http.delete(targetUrl, headers: r.headers);
          break;

        default:
          throw UnimplementedError('proxy unsupported method: $method');
      }

      // Produce the response from the response of the proxy request

      return await _produceResponse(req, targetResponse);
    } catch (e) {
      _logProxy.warning('[${req.id}] proxy: $e');

      final errorResponse = http.Response(
          'An error has occurred.\n', HttpStatus.internalServerError,
          headers: {
            'content-type': 'text/text',
            'date': HttpDate.format(DateTime.now()),
            'server': _receivedBy
          });
      return await _produceResponse(req, errorResponse);

      // final proxyException = ProxyHandlerException(targetUrl, e);
      // _logProxy.fine('[${req.id}] $proxyException');
      // throw proxyException;
    }
  }

  //----------------

  Future<_HeadBody> _proxyRequestHeaders(Request req, Uri uri) async {
    final core = req._coreRequest;

    // Determine the request headers to send to the target
    //
    // Note: the 'http' package does not support multiple headers with the
    // same name (which are possible in HTTP).

    final passHeaders = <String, String>{};

    // New "Host" header for outgoing request

    final _newHost = (uri.hasPort) ? '${uri.host}:${uri.port}' : uri.host;
    passHeaders['host'] = _newHost;
    _logProxyRequest.finest('[${req.id}] + host=$_newHost');

    // Identify any link-only headers that must not be passed through.
    // These are identified in the "Connection" header, if any.

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

    // Add explicit connection close header to disable _persistent connections_
    // in HTTP/1.1 (where the absence of the header means persistence desired).
    // Having an explicit connection close header also disables it with
    // legacy (but commonly implemented) HTTP/1.0+ _keep-alive connections_
    // (where the absence of the header means no persistence).

    passHeaders['connection'] = 'close';
    _logProxyRequest.finest('[${req.id}] + connection=close');

    // Content-type

    if (core is _CoreRequestReal) {
      final ct = core._httpRequest.headers.contentType;
      if (ct != null) {
        final cSet = ct.charset;
        final newCt = '${ct.mimeType}${cSet != null ? '; charset=$cSet' : ''}';
        _logProxyRequest.finest('[${req.id}] + content-type=$newCt');
        passHeaders['content-type'] = newCt;
      }
    }

    // Headers from incoming request to outgoing request

    int? _contentLength;
    var _wasCompressed = false;

    req.headers.forEach((key, values) {
      final headerName = key.toLowerCase();

      if (requestHeadersNeverPass.contains(headerName) ||
          requestConnectionExclude.contains(headerName) ||
          requestBlockHeaders.contains(headerName) ||
          headerName == 'content-type' ||
          headerName == 'via') {
        // Do not pass through header
        // Note: any "Via" headers are skipped here, but their values will all
        // be put back immediately after this loop (see below).
        for (final v in values) {
          _logProxyRequest.finest('[${req.id}] - $headerName=$v');
        }
      } else if (headerName == 'content-length') {
        if (values.length == 1) {
          final v = values.first;
          try {
            _contentLength = int.parse(values.first);
            _logProxyResponse.finest('[${req.id}] - $headerName=$v');
          } on FormatException {
            throw FormatException('bad content-length header: $v');
          }
        } else {
          throw FormatException('bad content-length: ${values.join(',')}');
        }
        _logProxyRequest.finest('[${req.id}] - $headerName=${values.first}');
      } else if (headerName == 'content-encoding') {
        for (final v in values) {
          if ((v.split(',').map<String>((s) => s.trim()))
              .any((e) => e != 'identity')) {
            _wasCompressed = true;
          }
          _logProxyResponse.finest('[${req.id}] - $headerName=$v');
        }
      } else {
        // Pass through header

        // The _http.get_ function does not support multiple headers with the
        // same name, so multiple values are combined together with commas as
        // permitted by
        // https://www.w3.org/Protocols/rfc2616/rfc2616-sec4.html#sec4.2
        final singleValue = values.join(', ');

        // Except Set-Cookies is a special case where commas might not
        // work: https://tools.ietf.org/html/rfc7230#section-3.2.2

        _logProxyRequest.finest('[${req.id}]   $headerName=$singleValue');
        passHeaders[headerName] = singleValue;
      }
    });

    // A "Via" header is _always_ added to forwarded requests.
    // It is mandatory according to
    // [RFC 7230](https://tools.ietf.org/html/rfc7230#section-5.7.1).
    //
    // Again, since _http.get_ does not support multiple headers, if there are
    // any existing Via header(s), their values are concatenated together
    // with the new value and separated by a comma.

    String protocolVersion;
    if (core is _CoreRequestReal) {
      protocolVersion = core._httpRequest.protocolVersion;
    } else {
      protocolVersion = '1.1'; // not a real HTTP request: assume common value
    }

    final _via = '$protocolVersion $_receivedBy';

    final viaHeadersInReq = req.headers['via'];
    final _newVia = viaHeadersInReq != null
        ? '${viaHeadersInReq.where((s) => s.isNotEmpty).join(', ')}, $_via'
        : _via;

    passHeaders['via'] = _newVia;
    _logProxyRequest.finest('[${req.id}] + via=$_newVia');

    // Request body

    final body = await req._coreRequest.bodyBytes(postMaxRequestSize);

    if (_contentLength != null && body.length != _contentLength) {
      if (!_wasCompressed) {
        throw FormatException('content-length!=body:'
            ' $_contentLength!=${body.length}');
      }
    }

    if (body.isNotEmpty) {
      // Set the request content-length

      final realSize = body.length.toString();
      _logProxyResponse.finest('[${req.id}] + content-length=$realSize');
      passHeaders['content-length'] = realSize;
    }

    return _HeadBody(passHeaders, body);
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

    final _ct = targetResponse.headers['content-type'];
    final contentType =
        (_ct != null) ? ContentType.parse(_ct) : ContentType.binary;

    _logProxyResponse.finest('[${req.id}] + content-type=$contentType');

    // Identify any connection headers that must not be passed back.

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

    assert(resp.headerNames().isEmpty);

    // Add connection close header to indicate connection will not persist

    resp.headerAdd('connection', 'close');
    _logProxyResponse.finest('[${req.id}] + connection=close');

    // Above removes all default headers, since some/all of them might be
    // present in the proxy response. Only the ones from the proxy response will
    // appear in the response.
    //
    // Cannot blindly use resp.headerAdd since that could produce multiple
    // headers as well as we need to avoid this bug:
    //   https://github.com/dart-lang/sdk/issues/43627

    // Forward headers from proxy response to the response

    int? _contentLength; // null if no "content-length" header
    var _hasNonIdentityContentEncoding = false;

    for (var key in targetResponse.headers.keys) {
      final headerName = key.toLowerCase();
      final headerValue = targetResponse.headers[key] ?? '';

      if (responseHeadersNeverPass.contains(headerName) ||
          responseConnectionExclude.contains(headerName) ||
          responseBlockHeaders.contains(headerName)) {
        // Do not pass back header
        _logProxyResponse.finest('[${req.id}] - $headerName=$headerValue');
      } else if (headerName == 'content-length') {
        try {
          _contentLength = int.parse(headerValue);
          _logProxyResponse.finest('[${req.id}] - $headerName=$headerValue');
        } on FormatException {
          throw FormatException('bad content-length header: $headerValue');
        }
      } else if (headerName == 'content-encoding') {
        if ((headerValue.split(',').map<String>((s) => s.trim()))
            .any((e) => e != 'identity')) {
          _hasNonIdentityContentEncoding = true;
        }
        _logProxyResponse.finest('[${req.id}] - $headerName=$headerValue');
      } else {
        // Pass header back to client
        resp.headerAdd(headerName, headerValue);
        _logProxyResponse.finest('[${req.id}]   $headerName=$headerValue');
      }
    }

    // Via header

    if (includeViaHeaderInResponse) {
      // Add a Via header to the HTTP response.
      //
      // A "Via" header is optional in forwarded responses according to
      // [RFC 7230](https://tools.ietf.org/html/rfc7230#section-5.7.1).
      //
      // Important: this must be done _after_ copying the headers from the
      // proxy response, since this new "Via" header must appear _after_ any
      // previous ones.

      final _via = '1.1 $_receivedBy'; // assumes _http.get_ uses HTTP 1.1
      resp.headerAdd('via', _via);
      _logProxyResponse.finest('[${req.id}] + via=$_via');
    }

    // Get the body of the proxy response

    final body = targetResponse.bodyBytes;

    // Check content-length (if any) matches actual body (if it is supposed to)

    String? realSize = body.length.toString();

    if (req.method == 'HEAD' ||
        targetResponse.statusCode == HttpStatus.noContent ||
        targetResponse.statusCode == HttpStatus.notModified ||
        (100 <= targetResponse.statusCode &&
            targetResponse.statusCode <= 199)) {
      // Message is not allowed to have a body:
      // Any content-length is only informational: ignore it
      if (body.isNotEmpty) {
        throw FormatException('body forbidden, but got ${body.length} bytes');
      }
      // Use the real size from the content-length header provided by the target
      realSize = _contentLength?.toString();
    } else if (!_hasNonIdentityContentEncoding) {
      // Content-length (if it exists) should be correct

      if (_contentLength != null && _contentLength != body.length) {
        throw FormatException('content-length!=body:'
            ' $_contentLength!=${body.length}');
      }
    }
    // Note: content-type is "multipart/byteranges" is another situation
    // where the content-length might not match.

    // Create a stream from the bodyBytes, and use it for the response

    if (realSize != null) {
      _logProxyResponse.finest('[${req.id}] + content-length=$realSize');
      resp.headerSet('content-length', realSize);
    } else {
      _logProxyResponse.finest('[${req.id}]');
    }

    final result = await resp.addStream(req, () async* {
      yield body;
    }());

    _logProxy.finer('[${req.id}] status=${targetResponse.statusCode}');

    return result;
  }
}

class _HeadBody {
  _HeadBody(this.headers, this.body);

  final Map<String, String> headers;
  final List<int> body;
}
