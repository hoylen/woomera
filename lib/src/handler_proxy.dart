part of woomera;

//================================================================
/// Handler for proxying requests to another server.
///
/// Example:
///
/// ```dart
/// proxy = new Proxy('~/foobar/*', 'http://example.com');
/// proxy.register(pipeline);
/// ```
///
/// Requests for '~/foobar/abc/def' will return the response from
/// "http://example.com/foobar/abc/def".

class Proxy {
  //================================================================
  // Static constants

  /// Headers in the request which are never passed through to the target.

  static const List<String> requestHeadersNeverPass = ['host', 'connection'];

  /// Headers in the response which are never passed through to the client.

  static const List<String> responseHeadersNeverPass = [
    'content-type',
    'x-content-type-options',
    'x-frame-options',
    'x-xss-protection'
  ];

  //================================================================
  // Members

  /// The HTTP method to proxy for.

  final String method;

  String _proxyHost;

  String _pathPrefix;

  /// Paths that will be ignored if the target returns HTTP Status 404.
  ///
  /// No warnings are logged for these.

  final List<String> _ignoreNotFound = [];

  /// Additional request headers which are not passed through to the target.
  ///
  /// In addition to the [requestHeadersNeverPass], these headers are also not
  /// passed through in the request.
  ///
  /// Set this value in the constructor.

  final List<String> requestBlockHeaders;

  /// Additional response headers which are not passed through to the client.
  ///
  /// In addition to the [responseHeadersNeverPass], these headers are also not
  /// passed through in the response.
  ///
  /// Set this value in the constructor.

  final List<String> responseBlockHeaders;

  //================================================================
  // Constructors

  //----------------------------------------------------------------
  /// Constructor

  Proxy(this.method, String pattern, String proxy,
      {List<String> ignoreNotFound,
      this.requestBlockHeaders,
      this.responseBlockHeaders}) {
    if (method != 'GET' && method != 'HEAD') {
      throw new ArgumentError.value(
          method, 'method', 'only GET and HEAD supported');
    }

    if (!pattern.startsWith('~/')) {
      throw new ArgumentError.value(
          pattern, 'pattern', 'does not start with "~/"');
    }

    if (!pattern.endsWith('/*')) {
      throw new ArgumentError.value(
          pattern, 'pattern', 'does not end with "*"');
    }

    _pathPrefix = pattern.substring(2, pattern.length - 2);
    _proxyHost = proxy;

    if (ignoreNotFound != null) {
      for (var path in ignoreNotFound) {
        _ignoreNotFound.add('$proxy/$path');
      }
    }
  }

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
    assert(values.length == 1,
        'Proxy registered without exactly one *: $_proxyHost/$_pathPrefix');

    final subPath = values.first;

    final fullPath = (_pathPrefix != null && _pathPrefix.isNotEmpty)
        ? '$_pathPrefix/$subPath'
        : subPath;

    return '$_proxyHost/$fullPath';
  }

  //----------------------------------------------------------------
  /// GET or HEAD request handler.
  ///

  Future<Response> handleGetOrHead(Request req) async {
    // Determine the target URI

    final targetUrl = _targetUri(req);
    _logProxy.fine('[${req.id}] $method $targetUrl');

    try {
      // Determine the request headers to send to the target
      //
      // Note: the 'http' package does not support multiple headers with the
      // same name (which are possible in HTTP).

      final passHeaders = <String, String>{};

      final u = Uri.parse(targetUrl);
      passHeaders['host'] = (u.hasPort) ? '${u.host}:${u.port}' : u.host;

      req.request.headers.forEach((headerName, values) {
        if (!(requestHeadersNeverPass.contains(headerName) ||
            (requestBlockHeaders?.contains(headerName) ?? false))) {
          if (values.length == 1) {
            passHeaders[headerName] = values.first;
          } else {
            _logProxy.warning('request header not a single value: $headerName');
          }
        }
      });

      // Perform request for the target

      final targetResponse = await http.get(targetUrl, headers: passHeaders);
      assert(targetResponse != null);

      if (targetResponse.statusCode != HttpStatus.ok &&
          targetResponse.statusCode != HttpStatus.notModified) {
        if (!(targetResponse.statusCode == HttpStatus.notFound &&
            _ignoreNotFound.contains(targetUrl))) {
          _logProxy.warning("$targetUrl: status ${targetResponse.statusCode}");
        }
      }

      // Pass the target's response back as the response

      final contentType = (targetResponse.headers.containsKey('content-type'))
          ? ContentType.parse(targetResponse.headers['content-type'])
          : ContentType.binary;

      // Use the response from the target as the response

      final resp = new ResponseBuffered(contentType)
        ..status = targetResponse.statusCode;

      for (var headerName in targetResponse.headers.keys) {
        if (!(responseHeadersNeverPass.contains(headerName) ||
            (responseBlockHeaders?.contains(headerName) ?? false))) {
          // Not one of the special headers: copy it to the response
          resp.header(headerName, targetResponse.headers[headerName]);
        }
      }

      resp.write(targetResponse.body);
      return resp;
    } catch (e) {
      _logProxy.warning("$targetUrl: exception ${e.runtimeType}: $e");
      rethrow;
    }
  }
}
