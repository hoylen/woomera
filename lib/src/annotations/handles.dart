part of annotations;

//################################################################
/// Function type for handler wrapper.
///
/// Set the [Handles.handlerWrapper] to a function of this type.
///
/// A handler wrapper is a function that the application provides for use
/// in converting the object that has a [Handles] annotation into a
/// [RequestHandler] function. It is used for the [Handles.handlerWrapper].
///
/// Note: currently registration annotations are only used when they are on
/// top level functions and static methods. Therefore, the object passed to
/// the handler wrapper is always a [Function]. An implementation of a
/// [HandlerWrapper] should keep in mind that a future release might also allow
/// the annotation to be used elsewhere too.

@Deprecated('Annotation function with @RequestHandlerWrapper instead,'
    ' unless using the woomera "scan" library which still uses this.')
typedef HandlerWrapper = RequestHandler Function(Handles rego, Object obj);

//################################################################
/// Annotation for a _request handler_.
///
/// Instances of this class is designed to be used as an annotation on a
/// top-level function or static member that act as _request handlers_.
///
/// ## Annotating request handlers
///
/// Use the convenience constructors [Handles.get], [Handles.post],
/// [Handles.put] etc. that are named after a standard HTTP method;
/// or the generic [Handles.request] constructor that supports any HTTP method.
///
/// The [httpMethod] is the HTTP request method that the rule will handle.
/// It is a string such as "GET" or "POST".
///
/// The [ServerPipeline] it is for is identified by the [pipeline].
/// The order for the rule is determined by the [priority] and then the
/// [pattern]. Normally, the _priority_ does not need to be changed from the
/// default of zero, since sorting by the _pattern_ usually produces a correctly
/// working pipeline.
///
/// For example, used as an annotation on a top-level function, for the
/// default pipeline:
///
/// ```dart
/// @Handles.get('~/foo/bar')
/// Future<Response> myBarHandler(Request req) {
///   ...
/// }
/// ```
///
/// Usage as an annotation on a static method, for a named pipeline:
///
/// ```dart
/// class SomeClass {
///
///   @Handles.post('~/foo/bar/baz', pipeline='mySpecialPipeline')
///   static Future<Response> myPostHandler(Request req) {
///     ...
///   }
/// }
/// ```
///
/// Normally, the priority can be left as the default, since sorting by the
/// pattern should produce a properly functioning pipeline.
/// See the _Pattern.compareTo_ operator for how patterns are ordered.
/// For special situations, the priority can be set to a non-zero value; but
/// multiple pipelines can also be used to achieve the same behaviour.
///
/// ## Logging
///
/// The "woomera.handles" logger is used for _Handles_ related log entries.
///
/// - CONFIG: shows only the number of annotations found
/// - FINE: lists what they handle
/// - FINER: lists what they handle and the request handler that was annotated
/// - FINEST: also logs the libraries that were scanned for annotations
///
/// Note: the above logs the _Handles_ annotations that were found, but they
/// will only be used if a pipeline was created with the same name (i.e. via
/// the [ServerPipeline] constructor or _Server_ constructor).

class Handles extends WoomeraAnnotation {
  //================================================================
  // Constructors

  //----------------------------------------------------------------
  /// Constructor with an explicitly specified HTTP method.
  ///
  /// The [httpMethod] is the name of the HTTP method, and [pattern] is the
  /// string representation of the pattern to match.
  ///
  /// The optional [pipeline] name identifies the pipeline the rule is for.
  /// If no value is provided, it defaults to the [ServerPipeline.defaultName].
  ///
  /// The [priority] can be used to control the position of the rule in the
  /// pipeline. It takes precedence over the pattern. Specifying the _priority_
  /// is not recommended, because it can reorder the rules such that some
  /// rules will never be found. That would only make sense if an earlier
  /// rule deliberately didn't produce a response. Consider using
  /// multiple pipelines instead of the priority.
  ///
  /// This constructor is usually used for non-standard HTTP methods.
  /// For standard HTTP methods, the [Handles.get], [Handles.post],
  /// [Handles.put], [Handles.patch], [Handles.delete], [Handles.head]
  /// constructors can also be used.

  const Handles.request(this.httpMethod, this.pattern,
      {String? pipeline, int? priority})
      : pipeline = pipeline ?? ServerPipeline.defaultName,
        priority = priority ?? 0;

  //----------------
  /// Constructor with the HTTP GET method.
  ///
  /// The [pattern] is the string representation of the pattern to match.
  /// The optional [pipeline] name identifies the pipeline the rule is for, and
  /// [priority] controls the order in which the rule is added to the pipeline.

  const Handles.get(this.pattern, {String? pipeline, int? priority})
      : httpMethod = 'GET',
        pipeline = pipeline ?? ServerPipeline.defaultName,
        priority = priority ?? 0;

  //----------------
  /// Constructor with the HTTP POST method.
  ///
  /// The [pattern] is the string representation of the pattern to match.
  /// The optional [pipeline] name identifies the pipeline the rule is for, and
  /// [priority] controls the order in which the rule is added to the pipeline.

  const Handles.post(this.pattern, {String? pipeline, int? priority})
      : httpMethod = 'POST',
        pipeline = pipeline ?? ServerPipeline.defaultName,
        priority = priority ?? 0;

  //----------------
  /// Constructor with the HTTP PUT method.

  const Handles.put(this.pattern, {String? pipeline, int? priority})
      : httpMethod = 'PUT',
        pipeline = pipeline ?? ServerPipeline.defaultName,
        priority = priority ?? 0;

  //----------------
  /// Constructor with the HTTP PATCH method.

  const Handles.patch(this.pattern, {String? pipeline, int? priority})
      : httpMethod = 'PATCH',
        pipeline = pipeline ?? ServerPipeline.defaultName,
        priority = priority ?? 0;

  //----------------
  /// Constructor with the HTTP DELETE method.

  const Handles.delete(this.pattern, {String? pipeline, int? priority})
      : httpMethod = 'DELETE',
        pipeline = pipeline ?? ServerPipeline.defaultName,
        priority = priority ?? 0;

  //----------------
  /// Constructor with the HTTP HEAD method.

  const Handles.head(this.pattern, {String? pipeline, int? priority})
      : httpMethod = 'HEAD',
        pipeline = pipeline ?? ServerPipeline.defaultName,
        priority = priority ?? 0;

  //----------------------------------------------------------------
  /// Constructor for pipeline exception handler annotations.
  ///
  /// The optional [pipeline] name identifies the pipeline the exception handler
  /// is for. If it is not provided, the exception handler is for the default
  /// pipeline.
  ///
  /// Note: page not found exceptions are not processed by the pipeline
  /// exception handlers, but by the server exception handlers. You should
  /// have a `@Handles.exceptions()` annotation before annotating additional
  /// exception handlers with this pipeline exception annotation.

  @Deprecated('Use @PipelineExceptionHandler instead')
  const Handles.pipelineExceptions({String? pipeline})
      : pipeline = pipeline ?? ServerPipeline.defaultName,
        httpMethod = null,
        pattern = null,
        priority = null;

  //----------------------------------------------------------------
  /// Constructor for server exception handler annotation.
  ///
  /// A program can have at most one such annotation.

  @Deprecated('Use @ServerExceptionHandler instead')
  const Handles.exceptions()
      : pipeline = null,
        httpMethod = null,
        pattern = null,
        priority = _serverHighLevel;

  //----------------------------------------------------------------
  /// Constructor for low-level server exception handler annotation.
  ///
  /// A program can have at most one such annotation.

  @Deprecated('Use @ServerRawExceptionHandler instead')
  const Handles.rawExceptions()
      : pipeline = null,
        httpMethod = null,
        pattern = null,
        priority = _serverLowLevel;

  // If the pipeline name and priority are both not null, it is an annotation
  // for a request handler.
  //
  // If the pipeline name is not null, but the priority is null, it is a
  // pipeline exception handler.
  //
  // If pipeline name is null, it is a server exception handler (when the
  // priority is 0) and a low-level server exception handler (when the
  // priority is ).

  //================================================================
  // Constants

  /// Indicator for a server exception handler.
  ///
  /// The object annotates a server exception handler when
  /// the [pipeline] is null and [priority] set to this value.

  static const _serverHighLevel = 1;

  /// Indicator for a _server raw exception handler_.
  ///
  /// The object annotates a _server raw exception handler_ when
  /// the [pipeline] is null and [priority] set to this value.

  static const _serverLowLevel = -1;

  //================================================================
  // Static members

  /// Wrapper for the annotated function.
  ///
  /// If this is set, it is used to process the object with the [Handles]
  /// annotation, before it is used as a [RequestHandler] in a pipeline's rule.
  ///
  /// For example, this allows the request handler to perform some common code,
  /// before invoking the annotated function. The annotated function does not
  /// have to be a _RequestHandler_, as long as this handler wrapper returns
  /// a _RequestHandler_.
  ///
  /// If set, this handler wrapper is always invoked -- even if the annotated
  /// object is already a _RequestHandler_.

  @Deprecated('Annotation function with @RequestHandlerWrapper, unless using'
      ' the scan library which still relies on this.')
  static HandlerWrapper? handlerWrapper;

  //================================================================
  // Members

  /// Name of the pipeline.
  ///
  /// Not null when this annotates a request handler or pipeline exception
  /// handler. Null means this annotates a server exception handler or
  /// server raw exception handler.

  final String? pipeline;
  // TODO(any): change to String when the deprecated constructors are removed

  /// The HTTP method for the server rule.
  ///
  /// The value should be an uppercase string. For example, "GET", "POST" and
  /// "PUT".
  ///
  /// Only used when annotating request handlers. Null when it is annotating
  /// a pipeline exception handler, server exception handler or
  /// server raw exception handler.

  final String? httpMethod;
  // TODO(any): change to String when the deprecated constructors are removed

  /// The priority for the rule within the pipeline.
  ///
  /// This determines the order in which it will be matched. A higher priority
  /// will be registered earlier in the pipeline, and therefore will be checked
  /// for a match before later rules.
  ///
  /// The default priority is zero.
  ///
  /// Setting the priority allows explicit control over the order in which
  /// automatic registrations are added to a pipeline. But normally, setting
  /// the priority is not necessary, since the ordering of registrations by
  /// their [pattern] should produce the correct result.
  ///
  /// Null if this is annotating a pipeline exception handler. When this is
  /// annotating a server exception handler or server raw exception handler,
  /// this value is set to either [_serverHighLevel] or [_serverLowLevel],
  /// respectively.

  final int? priority;
  // TODO(any): change to int when the deprecated constructors are removed

  /// The string representation of the pattern for the server rule.
  ///
  /// Note: this has to be the string representation of a pattern instead of
  /// a [Pattern] object, since _Registration_ objects must have a constant
  /// constructor for it to be used as an annotation.
  ///
  /// Only used when annotating request handlers. Null when it is annotating
  /// an exception handler, server exception handler or server raw exception
  /// handler.

  final String? pattern;
  // TODO(any): change to String when the deprecated constructors are removed
  // or even to a Pattern object.

  //================================================================
  // Methods

  /// Indications if this is describing an exception handler or not.

  //bool get isExceptionHandler => pipelineName == null;

  /// Indications if this is describing a request handler or not.

  bool get isRequestHandler => pattern != null;

  /// Indicates if this is describing a pipeline exception handler

  bool get isPipelineExceptionHandler =>
      (!isRequestHandler) && pipeline != null;

  /// Indicates if this is describing a server exception handler

  bool get isServerExceptionHandler =>
      (!isRequestHandler) && pipeline == null && priority == _serverHighLevel;

  /// Indicates if this is describing a server raw exception handler

  bool get isServerRawExceptionHandler =>
      (!isRequestHandler) && pipeline == null && priority == _serverLowLevel;

  //----------------------------------------------------------------

  @override
  String toString() {
    if (pipeline != null) {
      // For a pipeline

      final pipeStr = (pipeline != ServerPipeline.defaultName)
          ? 'pipeline="$pipeline" '
          : '';

      if (pattern != null) {
        // Request handler
        assert(httpMethod != null, 'invalid Handler');
        assert(priority != null, 'invalid Handler');

        final priorityStr = (priority != 0) ? 'priority=$priority ' : '';
        return '$pipeStr$priorityStr$httpMethod $pattern';
      } else {
        // Pipeline exception handler
        assert(httpMethod == null, 'invalid Handler');
        assert(priority == null, 'invalid Handler');

        return '${pipeStr}pipeline exception handler';
      }
    } else {
      // For the server

      assert(pattern == null);
      assert(httpMethod == null);

      if (priority == _serverHighLevel) {
        return 'server exception handler';
      } else if (priority == _serverLowLevel) {
        return 'server raw exception handler';
      } else {
        assert(false, 'invalid Handler');
        return 'invalid Handler';
      }
    }
  }
}
