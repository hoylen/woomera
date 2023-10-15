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

  ServerPipeline([this.name = defaultName]);

  //================================================================
  // Constants

  /// Default pipeline name.
  ///
  /// This value is the default name used in _Handles_ annotations, where no
  /// explicit name is provided. And it is matched by the default pipeline
  /// that is created by [Server] when no explicit pipelines is
  /// requested.

  static const defaultName = '';

  //================================================================
  // Members

  /// Name of the pipeline.

  final String name;

  /// Pipeline level exception/error handler.
  ///
  /// Exception/error handler for the pipeline. If not set, exceptions/errors
  /// will be handled by the server-level exception/error handler.
  ///
  /// A pipeline exception handler can be annotated with
  /// `@PipelineExceptionHandler()`.

  ExceptionHandler? exceptionHandler;

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
  /// Register a request handler for any HTTP method with a pattern string.
  ///
  /// Register a request [handler] to match a HTTP [method] and pattern.
  ///
  /// Convenience methods for common HTTP methods exist: [get], [post], [put],
  /// [patch], [delete]. They simply invoke this method with corresponding
  /// values for the HTTP method.
  ///
  /// This method is a convenience method that just converts the string
  /// representation of a pattern into a _Pattern_ and then passes that object
  /// into [registerPattern].
  ///
  /// Throws an [ArgumentError] if the values are invalid (i.e. if
  /// the pattern string is not a valid pattern).
  ///
  /// Throws a [DuplicateRule] if there is a conflict with an existing rule.
  /// A conflict is if [Pattern.matchesSamePaths] is true for the two patterns.
  ///
  /// **Null-safety breaking change:** this method used to have a named
  /// parameter to use a _Pattern_ instead of the string representation of a
  /// pattern. To register a rule using a [Pattern] object, use the
  /// [registerPattern] method instead.

  void register(String method, String pattern, RequestHandler handler) {
    final patternObj = Pattern(pattern); // can throw an ArgumentError

    registerPattern(method, patternObj, handler);
  }

  //----------------------------------------------------------------
  /// Register a request handler for any HTTP method with a Pattern.
  ///
  /// This method is used if the caller already has a [Pattern] object.
  /// Usually, an application will have the pattern as a _String_, in which
  /// case it can use the [register] method instead, which simply converts that
  /// string into a _Pattern_ object and then invokes this method.
  ///
  /// Throws a [DuplicateRule] if there is a conflict with an existing rule.
  /// A conflict is if [Pattern.matchesSamePaths] is true for the two patterns.

  void registerPattern(String method, Pattern pattern, RequestHandler handler) {
    if (method.isEmpty) {
      throw ArgumentError.value(method, 'method', 'Empty string');
    }

    _logServer.config('register: $method $pattern');

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

    final newRule = ServerRule(pattern.toString(), handler);

    try {
      final existingRule = methodRules
          .firstWhere((sr) => sr.pattern.matchesSamePaths(newRule.pattern));

      // A rule with the "same" pattern already exists: cannot add it
      throw DuplicateRule(method, pattern, handler, existingRule.handler);

      // ignore: avoid_catching_errors
    } on StateError {
      // A rule with the "same" pattern does not exist: success: record the rule
      methodRules.add(newRule);
    }
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
  ///
  /// Returns the empty list if there are no rules for that method.

  List<ServerRule> rules(String method) => _rulesByMethod[method] ?? [];
}
