part of core;

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
  //================================================================
  // Constructors

  //----------------------------------------------------------------
  /// Pipeline constructor.
  ///
  /// Creates a new pipeline that doesn't contain any rules. This method does
  /// not populate rules from annotations.
  ///
  /// To create a pipeline and populate the rules from annotations, use
  /// `serverPipelineFromAnnotations` instead.

  ServerPipeline([this.name]);

  //================================================================
  // Constants

  /// Default pipeline name.
  ///
  /// This value is the default name used in [Handles] objects, where no
  /// explicit name is provided. And it is matched by the default pipeline
  /// that is created by [Server] when no explicit pipelines is
  /// requested.

  static const defaultName = '';

  //================================================================
  // Members

  /// Name of the pipeline.
  ///
  /// This is null if the pipeline was not initialized with a name. That is,
  /// if it was created without using automatic registration for its rules.

  final String name;

  /// Pipeline level exception/error handler.
  ///
  /// Exception/error handler for the pipeline. If not set, exceptions/errors
  /// will be handled by the server-level exception/error handler.
  ///
  /// This pipeline exception handler can also be set using a
  /// `@Handles.exception()` annotation, providing it the name of the
  /// pipeline if it is not the default pipeline.

  ExceptionHandler exceptionHandler;

  // The rules that have been registered with the pipeline

  final Map<String, List<ServerRule>> _rulesByMethod = {};

  //================================================================
  // Methods

  //----------------------------------------------------------------
  /// Register a GET request handler.
  ///
  /// Shorthand for calling [register] with the method set to "GET".
  ///
  void get(String pattern, RequestHandler handler) {
    register('GET', pattern, handler);
  }

  //----------------------------------------------------------------
  /// Register a POST request handler.
  ///
  /// Shorthand for calling [register] with the method set to "POST".
  ///
  void post(String pattern, RequestHandler handler) {
    register('POST', pattern, handler);
  }

  //----------------------------------------------------------------
  /// Register a PUT request handler.
  ///
  /// Shorthand for calling [register] with the method set to "PUT".
  ///
  void put(String pattern, RequestHandler handler) {
    register('PUT', pattern, handler);
  }

  //----------------------------------------------------------------
  /// Register a PATCH request handler.
  ///
  /// Shorthand for calling [register] with the method set to "PATCH".
  ///
  void patch(String pattern, RequestHandler handler) {
    register('PATCH', pattern, handler);
  }

  //----------------------------------------------------------------
  /// Register a DELETE request handler.
  ///
  /// Shorthand for calling [register] with the method set to "DELETE".
  ///
  void delete(String pattern, RequestHandler handler) {
    register('DELETE', pattern, handler);
  }

  //----------------------------------------------------------------
  /// Register a HEAD request handler.
  ///
  /// Shorthand for calling [register] with the method set to "HEAD".
  ///
  void head(String pattern, RequestHandler handler) {
    register('HEAD', pattern, handler);
  }

  //----------------------------------------------------------------
  /// Registration of a request handler for any HTTP method.
  ///
  /// Register a request [handler] to match a HTTP [method] and pattern.
  /// The pattern can be provided as a string [patternStr] or a [Pattern]
  /// object. If the [pattern] object is provided, the _patternStr_ is ignored.
  ///
  /// Convenience methods for common HTTP methods exist: [get], [post], [put],
  /// [patch], [delete]. They simply invoke this method with corresponding
  /// values for the HTTP method.
  ///
  /// Throws an [ArgumentError] if the values are invalid (in particular, if
  /// the pattern string is not a valid pattern).

  void register(String method, String patternStr, RequestHandler handler,
      {Pattern pattern}) {
    if (method == null) {
      throw ArgumentError.notNull('method');
    }
    if (method.isEmpty) {
      throw ArgumentError.value(method, 'method', 'Empty string');
    }
    if (handler == null) {
      throw ArgumentError.notNull('handler');
    }

    if (pattern == null && patternStr == null) {
      throw ArgumentError.notNull('patternStr');
    }

    final patternObj = pattern ?? Pattern(patternStr); // throws ArgumentError

    _logServer.config('register: $method $patternObj');

    // Get the list of rules for the HTTP method

    var methodRules = _rulesByMethod[method];
    if (methodRules == null) {
      methodRules = []; // new List<ServerRule>();
      _rulesByMethod[method] = methodRules;
    }

    // Check if another rule already exists with the "same" pattern.
    // It is an error if one exists.
    //
    // It is not an error to have two rules that match a path. The order
    // of those rules will determine which one matches, and there can be other
    // paths that match one and not the other. So both have a purpose.
    //
    // But it is an error to have two rules with the "same" pattern. With them,
    // the first rule will always match, and there are no paths which will
    // not match one and match the other. So one of them is redundant. If it
    // was allowed, one of them will never get used.

    final newRule = ServerRule(patternObj.toString(), handler);
    final existingRule = methodRules.firstWhere(
        (sr) => sr.pattern.matchesSamePaths(newRule.pattern),
        orElse: () => null);

    if (existingRule != null) {
      throw DuplicateRule(method, patternObj, handler, existingRule.handler);
    }

    // Record the rule

    methodRules.add(newRule);
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
