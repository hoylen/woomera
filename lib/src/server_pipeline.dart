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
  //================================================================
  // Constructors

  //----------------------------------------------------------------
  /// Pipeline constructor.
  ///
  /// Creates a new pipeline that doesn't contain any rules. This method does
  /// not populate rules from annotations. Use [ServerPipeline.fromAnnotations]
  /// instead.
  ///
  /// This method might be deprecated in a future release.

  ServerPipeline() : name = null;

  //----------------------------------------------------------------
  /// Creates pipeline and populates it with rules from annotations.
  ///
  /// Create a pipeline and automatically populates it with rules based from
  /// [Handles] annotations that are found on request handler functions.
  /// The _Handles_ annotations must have the same [pipelineName] for it to
  /// be used.
  ///
  /// **Important:** provide the correct values in _libraries_, otherwise the
  /// annotations might not be found.
  ///
  /// When scanning the program for annotations, it only looks in libraries
  /// explicitly listed in [libraries]. Unless [scanAllFileLibraries] is true
  /// (which is the default), in which case all libraries with a "file" scheme
  /// are scanned, even if they don't appear in the list of _libraries_.
  ///
  /// Every part of a Dart problem belongs to a library which is identified by
  /// a URI. Libraries with a URI scheme of "dart" are never scanned (even
  /// if they are listed in _libraries_). For example, "dart:io" is a library
  /// that is never scanned. Libraries with a URI scheme of "package" are
  /// also common, and the libraries that you want scanned must be listed.
  /// If you find an annotated request handler is not getting invoked, check
  /// if its library has been included in the list.
  ///
  /// Libraries must be listed for them to be scanned. Firstly, because it is
  /// inefficient to scan all the libraries of the program: third party packages
  /// won't have any _Handles_ annotations. Secondly, for security, since you
  /// don't want a third-party package from adding request handlers that you
  /// don't know about.

  ServerPipeline.fromAnnotations(
      String pipelineName, Iterable<String> libraries,
      {bool scanAllFileLibraries = true})
      : name = pipelineName ?? defaultName {
    // Make sure annotations from the desired libraries have been scanned

    _annotations.scan(libraries ?? [],
        scanAllFileLibraries: scanAllFileLibraries);

    // Set the request handlers from annotations

    var haveRequestHandlers = false;
    for (final arh in _annotations.listRequestHandlers(name)) {
      _register(arh.httpMethod, arh.pattern, arh.handler,
          manualRegistration: false);
      haveRequestHandlers = true;
    }

    if (!haveRequestHandlers) {
      // Usually a programming error, since there is no point in creating a
      // pipeline with no request handlers. Check the name is correct.

      throw ArgumentError.value(pipelineName, 'pipelineName',
          'no Handles annotations on request handlers exist for this pipeline');
    }

    // Set the pipeline exception handler from annotations

    final apeh = _annotations.findPipelineExceptionHandler(name);
    if (apeh != null) {
      exceptionHandler = apeh.handler;
    }

    // Record that annotations with the name have been used to create a pipeline

    _annotations.markAsUsed(name);
  }

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
  // Static members

  /// Annotated handlers in the program
  ///
  /// This is effectively a global variable, since a program only has one set
  /// of libraries. So once the libraries have been scanned, the annotated
  /// handlers can be cached for creating multiple pipelines, setting server
  /// exception handlers and server raw exception handlers.
  ///
  /// This static member is used by [ServerPipeline.fromAnnotations] and
  /// [Server.fromAnnotations].

  static final _annotations = _AnnotationScanner();

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
  /// Generic registration of a request handler for any HTTP method.
  ///
  /// Register a request [handler] to match a HTTP [httpMethod] and [pattern].
  ///
  /// Convenience methods for common methods exist: [get], [post], [put],
  /// [patch], [delete]. They simply invoke this method with corresponding
  /// values for the HTTP method.
  ///
  /// Throws an [ArgumentError] if the values are invalid (in particular, if
  /// the pattern is not a valid pattern).

  void register(String httpMethod, String pattern, RequestHandler handler) {
    if (httpMethod == null) {
      throw ArgumentError.notNull('method');
    }
    if (httpMethod.isEmpty) {
      throw ArgumentError.value(httpMethod, 'method', 'Empty string');
    }
    if (pattern == null) {
      throw ArgumentError.notNull('pattern');
    }
    if (handler == null) {
      throw ArgumentError.notNull('handler');
    }

    // Note: the Pattern constructor below can also throw an ArgumentError

    _register(httpMethod, Pattern(pattern), handler, manualRegistration: true);
  }

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
  /// Internal registration method for adding a rule.
  ///
  /// Used by both [register] and [ServerPipeline.fromAnnotations].

  void _register(String method, Pattern pattern, RequestHandler handler,
      {bool manualRegistration}) {
    _logServer.config('register: $method $pattern');

    // Get the list of rules for the HTTP method

    var methodRules = _rulesByMethod[method];
    if (methodRules == null) {
      methodRules = []; // new List<ServerRule>();
      _rulesByMethod[method] = methodRules;
    }

    // Check another rule does not already exist with the same path

    final newRule = ServerRule(pattern.toString(), handler);
    final existingRule = methodRules
        .firstWhere((sr) => sr.pattern == newRule.pattern, orElse: () => null);

    // TODO: fix the above check for an existing rule with the "same" pattern
    // The above check treats variable names as significant, but for the
    // purposes of detecting "duplicate rules", rules which only differ by their
    // variable names should be considered a duplicate. What about wildcards?

    if (existingRule != null) {
      throw DuplicateRule(method, pattern, handler, existingRule.handler);
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
