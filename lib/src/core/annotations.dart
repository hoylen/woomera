part of core;

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

typedef HandlerWrapper = RequestHandler Function(Handles rego, Object obj);

//################################################################
/// Information for creating a rule or initializing exception handlers.
///
/// Instances of this class is designed to be used as an annotation on a
/// top-level function or static member that will be used to populate rules
/// and exception handlers when using `serverFromAnnotations` and
/// `serverPipelineFromAnnotations`.
///
/// ## Annotating request handlers
///
/// Annotate a request handler to automatically populate pipelines with
/// [ServerRule] objects.
///
/// Use the convenience constructors [Handles.get], [Handles.post],
/// [Handles.put] etc. that are named after a standard HTTP method,
/// or the generic [Handles.request] constructor.
///
/// The [httpMethod] is the HTTP request method that the rule will handle.
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
/// When a named pipeline is created and populated using these annotations,
/// rules are automatically added to the pipeline from the annotations where
/// the pipeline name matches.
///
/// The rules are added in an order determined firstly by the [priority] and
/// secondly by the [pattern].
///
/// Normally, the priority can be left as the default, since sorting by the
/// pattern should produce a properly functioning pipeline.
/// See the [Pattern.compareTo] operator for how patterns are ordered.
/// For special situations, the priority can be set to a non-zero value; but
/// multiple pipelines can also be used to achieve the same behaviour.
///
/// ## Request handler
///
/// A server rule consists of a pattern and a request handler. For rules created
/// by a _Handles_ annotation, the request handler comes from the item the
/// annotation is on.
///
/// Currently, the item must be a top-level function or a static method.
/// While there is nothing preventing the annotation being placed on other
/// items, they will be ignored.
///
/// By default, the [handlerWrapper] is not set (i.e. it is null). In this
/// case, the item with the annotation must be a [RequestHandler] function.
///
/// If the [handlerWrapper] is set, the annotated function is passed to it,
/// and the result it returns is used as the request handler.
///
/// For example, this example allows a function that is not a _RequestHandler_
/// to be used in a rule.
///
/// ```dart
///
/// RequestHandler myWrapper(Handles info, Object obj) {
///   if (obj is Function) {
///      return (Request req) {
///        final myParam = ... // convert the [Request] req into [MyParamType]
///        final myResponse = obj(myParam);
///        final response = ... // convert [MyResponseType] into a [Response]
///        return response;
///      };
///   } else {
///     throw ...
///   }
/// }
///
/// @Handles.get('~/foo/bar/')
/// Future<MyResponseType> baz(MyParamType t) {
///    ...
/// }
///
/// Handles.handlerWrapper = myWrapper;
/// ```
///
/// ## Annotating exception handlers
///
/// Annotate exception handlers to automatically set them. The three types of
/// exception handlers are supported.
///
/// Use the [Handles.exceptions] constructor for the server exception
/// handler. Servers should at least provide one of these exception handlers
/// to customise the "not found" error page.
///
/// ```dart
/// @Handles.exceptions()
/// Future<Response> foo(Request req, Object exception, StackTrace st) async {
///   ...
/// }
/// ```
///
/// Use the [Handles.pipelineExceptions] constructor for pipeline exception
/// handlers. This allows exception handling to be customised per-pipeline,
/// instead of having all exceptions handled the same way by the server
/// exception handler.
///
/// An optional pipeline name can be passed to it, otherwise it will be the
/// pipeline exception handler for the default pipeline.
///
/// ```dart
/// @Handles.pipelineExceptions(pipeline='mySpecialPipeline')
/// Future<Response> foo(Request req, Object exception, StackTrace st) async {
///   ...
/// }
/// ```
///
/// Use the [Handles.rawExceptions] constructor for the raw server
/// exception handler.
///
/// ```dart
/// @Handles.rawException()
/// Future<void> Function(HttpRequest rawRequest, String requestId,
///   Object exception, StackTrace st) async {
///   ...
/// }
/// ```
///
/// In a program, there cannot be more than one pipeline exception handler for
/// the same pipeline (i.e. the same pipeline name). There cannot be more than
/// one server exception handler, and there cannot be more than one server raw
/// exception handler.
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
/// the [ServerPipeline] constructor or [Server] constructor).
///
/// ## Migration from explicit registration to using _Handles_ annotations
///
/// In previous versions of Woomera (version 4.3.1 and earlier), [ServerRule]
/// must be created and added to pipelines. While this is still supported,
/// the use of _Handles_ annotation is now the preferred mechanism for
/// populating a pipeline with rules. The code is easier to maintain, since
/// no extra code is needed to create the server rules and to add them to the
/// pipelines.
///
/// To migrate old programs to using _Handles_ annotations, one approach is to:
///
/// 1. Add code to print out all the pipelines and their rules.
/// 2. Run the original program and save the output.
/// 3. Modify the code: removing the explicit creation of server rules and
///    adding _Handles_ annotations to the request handler functions.
///    Use priority values to control the order the rules appear in the
///    pipeline.
/// 4. Run the modified program and compare the output with the original output.
/// 5. Repeat steps 3 and 4 until the new output matches the original output.
/// 6. Consider removing most of the priority values: only keep those which
///    are significant to how HTTP requests are processed or use multiple
///    pipelines to achieve the same behaviour.
///
/// The following example can be used to print out all the pipelines and their
/// rules:
///
/// ```dart
///   final theServer = ...
///
///   ... // old pipeline and server rule creation code
///
///   // Immediately after all the pipelines have been created...
///
///   print('---- BEGIN server rules ----');
///    var pCount = 0;
///    for (final pipeline in theServer.pipelines) {
///      pCount++;
///      final methodNames = List<String>.from(pipeline.methods());
///      methodNames.sort();
///      for (final method in methodNames) {
///        final rules = pipeline.rules(method);
///        var rCount = 0;
///        for (final rule in rules) {
///          rCount++;
///          print('Pipeline $pCount: $method $rCount: $rule');
///        }
///      }
///    }
///    print('---- END server rules ----');
///    throw UnsupportedError('code in migration to Handles annotations');
///    // Abort after printing rules. Remove above code after migration.
/// ```

class Handles {
  //================================================================
  // Constructors

  //----------------------------------------------------------------
  // Constructors for request handler annotations.

  //----------------
  /// Use the [Handles.request] constructor instead.
  ///
  /// The default constructor made sense when this class was only used for
  /// annotating request handlers, but the annotations are more readable
  /// using _Handles.request_ now that it is also used for different types of
  /// exception handlers.

  @deprecated
  const Handles(this.httpMethod, this.pattern,
      {String pipeline, this.priority = 0})
      : pipeline = pipeline ?? ServerPipeline.defaultName,
        assert(httpMethod != null),
        assert(pattern != null),
        assert(priority != null);

  //----------------
  /// Constructor with a specific HTTP method.
  ///
  /// The [httpMethod] is the name of the HTTP method, and [pattern] is the
  /// string representation of the pattern to match. The optional [pipeline]
  /// name identifies the pipeline the rule is for, and [priority] controls
  /// the order in which the rule is added to the pipeline.

  const Handles.request(this.httpMethod, this.pattern,
      {String pipeline, this.priority = 0})
      : pipeline = pipeline ?? ServerPipeline.defaultName,
        assert(httpMethod != null),
        assert(pattern != null),
        assert(priority != null);

  //----------------
  /// Constructor with the HTTP GET method.
  ///
  /// The [pattern] is the string representation of the pattern to match.
  /// The optional [pipeline] name identifies the pipeline the rule is for, and
  /// [priority] controls the order in which the rule is added to the pipeline.

  const Handles.get(this.pattern,
      {this.priority = 0, this.pipeline = ServerPipeline.defaultName})
      : httpMethod = 'GET';

  //----------------
  /// Constructor with the HTTP POST method.
  ///
  /// The [pattern] is the string representation of the pattern to match.
  /// The optional [pipeline] name identifies the pipeline the rule is for, and
  /// [priority] controls the order in which the rule is added to the pipeline.

  const Handles.post(this.pattern,
      {this.priority = 0, this.pipeline = ServerPipeline.defaultName})
      : httpMethod = 'POST';

  //----------------
  /// Constructor with the HTTP PUT method.

  const Handles.put(this.pattern,
      {this.priority = 0, this.pipeline = ServerPipeline.defaultName})
      : httpMethod = 'PUT';

  //----------------
  /// Constructor with the HTTP PATCH method.

  const Handles.patch(this.pattern,
      {this.priority = 0, this.pipeline = ServerPipeline.defaultName})
      : httpMethod = 'PATCH';

  //----------------
  /// Constructor with the HTTP DELETE method.

  const Handles.delete(this.pattern,
      {this.priority = 0, this.pipeline = ServerPipeline.defaultName})
      : httpMethod = 'DELETE';

  //----------------
  /// Constructor with the HTTP HEAD method.

  const Handles.head(this.pattern,
      {this.priority = 0, this.pipeline = ServerPipeline.defaultName})
      : httpMethod = 'HEAD';

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

  const Handles.pipelineExceptions({String pipeline})
      : pipeline = pipeline ?? ServerPipeline.defaultName,
        httpMethod = null,
        pattern = null,
        priority = null;

  //----------------------------------------------------------------
  /// Constructor for server exception handler annotation.
  ///
  /// A program can have at most one such annotation.

  const Handles.exceptions()
      : pipeline = null,
        httpMethod = null,
        pattern = null,
        priority = _serverHighLevel;

  //----------------------------------------------------------------
  /// Constructor for low-level server exception handler annotation.
  ///
  /// A program can have at most one such annotation.

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

  /// Indicator for a raw server exception handler.
  ///
  /// The object annotates a raw server exception handler when
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

  static HandlerWrapper handlerWrapper;

  //================================================================
  // Members

  /// Name of the pipeline.
  ///
  /// Not null when this annotates a request handler or pipeline exception
  /// handler. Null means this annotates a server exception handler or
  /// server raw exception handler.

  final String pipeline;

  /// The HTTP method for the server rule.
  ///
  /// The value should be an uppercase string. For example, "GET", "POST" and
  /// "PUT".
  ///
  /// Only used when annotating request handlers. Null when it is annotating
  /// an exception handler, server exception handler or server raw exception
  /// handler.

  final String httpMethod;

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
  /// annotating a server exception handler or raw server exception handler,
  /// this value is set to either [_serverHighLevel] or [_serverLowLevel],
  /// respectively.

  final int priority;

  /// The string representation of the pattern for the server rule.
  ///
  /// Note: this has to be the string representation of a pattern instead of
  /// a [Pattern] object, since _Registration_ objects must have a constant
  /// constructor for it to be used as an annotation.
  ///
  /// Only used when annotating request handlers. Null when it is annotating
  /// an exception handler, server exception handler or server raw exception
  /// handler.

  final String pattern;

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
