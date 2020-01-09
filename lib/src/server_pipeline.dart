part of woomera;

//----------------------------------------------------------------
/// A pipeline.
///
/// A pipeline contains an ordered sequence of rules, grouped by their method.
///
/// When a HTTP request is processed by a [Server], it is processed by the
/// pipelines of the server (in order). Although, often there is often only one
/// pipeline in the server. Multiple pipelines are usually used for applications
/// with complex processing requirements.
///
/// When a HTTP request is processed by a [ServerPipeline], the rules for the
/// request method (e.g. GET or POST) are examined in order. If a rule's
/// [ServerRule] matches the request, its handler is invoked with the request.
/// If the handler returns a [Response], processing stops and that becomes
/// the HTTP response. If the handler returns null, processing continues by
/// attempting to match the request with subsequent rules in the pipeline
/// (if any) and then subsequent pipelines in the server. That is, handlers
/// are invoked if their pattern matches the request, and processing
/// stops with the first handler that doesn't return null.

class ServerPipeline {
  /// Pipeline level exception/error handler.
  ///
  /// Exception/error handler for the pipeline. If not set, exceptions/errors
  /// will be handled by the server-level exception/error handler.

  ExceptionHandler exceptionHandler;

  final Map<String, List<ServerRule>> _rulesByMethod = {};

  //================================================================

  /// Generic registration of a request handler for any HTTP method.
  ///
  /// Register a request [handler] when a [method] request asks for [path].
  ///
  /// Convenience methods for common methods exist: [get], [post], [put],
  /// [patch], [delete]. They simply invoke this method with corresponding
  /// values for the HTTP method.

  void register(String method, String path, RequestHandler handler) {
    _logServer.config('register: $method $path');

    if (method == null) {
      throw ArgumentError.notNull('method');
    }
    if (method.isEmpty) {
      throw ArgumentError.value(method, 'method', 'Empty string');
    }
    if (path == null) {
      throw ArgumentError.notNull('path');
    }
    if (!path.startsWith('~/')) {
      throw ArgumentError.value(path, 'path', 'does not start with "~/"');
    }
    if (handler == null) {
      throw ArgumentError.notNull('handler');
    }

    // Get the list of rules for the method

    var methodRules = _rulesByMethod[method];
    if (methodRules == null) {
      methodRules = []; // new List<ServerRule>();
      _rulesByMethod[method] = methodRules;
    }

    // Append a new pattern to the list of rules

    methodRules.add(ServerRule(path, handler));
  }

  //----------------------------------------------------------------
  /// Register a GET request handler.
  ///
  /// Shorthand for calling [register] with the method set to "GET".
  ///
  void get(String path, RequestHandler handler) {
    register('GET', path, handler);
  }

  //----------------------------------------------------------------
  /// Register a POST request handler.
  ///
  /// Shorthand for calling [register] with the method set to "POST".
  ///
  void post(String path, RequestHandler handler) {
    register('POST', path, handler);
  }

  //----------------------------------------------------------------
  /// Register a PUT request handler.
  ///
  /// Shorthand for calling [register] with the method set to "PUT".
  ///
  void put(String path, RequestHandler handler) {
    register('PUT', path, handler);
  }

  //----------------------------------------------------------------
  /// Register a PATCH request handler.
  ///
  /// Shorthand for calling [register] with the method set to "PATCH".
  ///
  void patch(String path, RequestHandler handler) {
    register('PATCH', path, handler);
  }

  //----------------------------------------------------------------
  /// Register a DELETE request handler.
  ///
  /// Shorthand for calling [register] with the method set to "DELETE".
  ///
  void delete(String path, RequestHandler handler) {
    register('DELETE', path, handler);
  }

  //----------------------------------------------------------------
  /// Register a HEAD request handler.
  ///
  /// Shorthand for calling [register] with the method set to "HEAD".
  ///
  void head(String path, RequestHandler handler) {
    register('HEAD', path, handler);
  }

  //================================================================
  // Retrieval methods

  //----------------------------------------------------------------
  /// Returns the methods in the pipeline
  ///
  /// This method is probably only useful for testing.

  Iterable<String> methods() => _rulesByMethod.keys;

  //----------------------------------------------------------------
  /// Returns the rules in the pipeline for a given [method].

  List<ServerRule> rules(String method) => _rulesByMethod[method];
}
