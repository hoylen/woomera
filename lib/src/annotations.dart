part of woomera;

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
/// Information for creating a rule.
///
/// Instances of this class is designed to be used as an annotation on a
/// top-level function or static member, intended to handle a HTTP request.
/// The [Server.fromAnnotations] and [ServerPipeline.fromAnnotations]
/// constructors uses these annotations to create [ServerRule] for the
/// pipelines.
///
/// ## Usage as an annotation
///
/// It identifies the [ServerPipeline] that the request handler is for: by its
/// [pipeline] member and also the order in which the rule is added to that
/// pipeline. The HTTP method and request path the rule will match is indicated
/// by the [httpMethod] and the string representation of the [pattern].
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
/// Usage as an annotation on a method:
///
/// ```dart
/// class SomeClass {
///
///   @Handles.put('~/foo/bar/baz', pipeline='mySpecialPipeline')
///   Future<Response> myPostHandler(Request req) {
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
/// ## Constructors
///
/// The named constructors can be used for the the standard HTTP methods.
///
/// - [Handles.get]
/// - [Handles.post]
/// - [Handles.put]
/// - [Handles.patch]
/// - [Handles.delete]
/// - [Handles.head]
///
/// The default constructor accepts the HTTP method as a parameter.
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

  /// Constructor with a specific HTTP method.
  ///
  /// The [httpMethod] is the name of the HTTP method, and [pattern] is the
  /// string representation of the pattern to match. The optional [pipeline]
  /// name identifies the pipeline the rule is for, and [priority] controls
  /// the order in which the rule is added to the pipeline.

  const Handles(this.httpMethod, this.pattern,
      {this.priority = 0, this.pipeline = ServerPipeline.defaultName});

  //----------------

  /// Constructor with the HTTP GET method.
  ///
  /// The [pattern] is the string representation of the pattern to match.
  /// The optional [pipeline] name identifies the pipeline the rule is for, and
  /// [priority] controls the order in which the rule is added to the pipeline.

  const Handles.get(this.pattern,
      {this.priority = 0, this.pipeline = ServerPipeline.defaultName})
      : httpMethod = 'GET';

  /// Constructor with the HTTP POST method.
  ///
  /// The [pattern] is the string representation of the pattern to match.
  /// The optional [pipeline] name identifies the pipeline the rule is for, and
  /// [priority] controls the order in which the rule is added to the pipeline.

  const Handles.post(this.pattern,
      {this.priority = 0, this.pipeline = ServerPipeline.defaultName})
      : httpMethod = 'POST';

  /// Constructor with the HTTP PUT method.

  const Handles.put(this.pattern,
      {this.priority = 0, this.pipeline = ServerPipeline.defaultName})
      : httpMethod = 'PUT';

  /// Constructor with the HTTP PATCH method.

  const Handles.patch(this.pattern,
      {this.priority = 0, this.pipeline = ServerPipeline.defaultName})
      : httpMethod = 'PATCH';

  /// Constructor with the HTTP DELETE method.

  const Handles.delete(this.pattern,
      {this.priority = 0, this.pipeline = ServerPipeline.defaultName})
      : httpMethod = 'DELETE';

  /// Constructor with the HTTP HEAD method.

  const Handles.head(this.pattern,
      {this.priority = 0, this.pipeline = ServerPipeline.defaultName})
      : httpMethod = 'HEAD';

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

  /// Name of the pipeline for the rule to be created in.

  final String pipeline;

  /// The HTTP method for the server rule.
  ///
  /// The value should be an uppercase string. For example, "GET", "POST" and
  /// "PUT".

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

  final int priority;

  /// The string representation of the pattern for the server rule.
  ///
  /// Note: this has to be the string representation of a pattern instead of
  /// a [Pattern] object, since _Registration_ objects must have a constant
  /// constructor for it to be used as an annotation.

  final String pattern;

  //================================================================
  // Methods

  //----------------------------------------------------------------

  @override
  String toString() {
    final pipeStr =
        (pipeline != ServerPipeline.defaultName) ? 'pipeline="$pipeline" ' : '';
    final priorityStr = (priority != 0) ? 'priority=$priority ' : '';

    return '$pipeStr$priorityStr$httpMethod $pattern';
  }
}

//################################################################
/// Annotated request handler
///
/// This class represents a function or static method that has a [Handles]
/// annotation.
///
/// Instances of this class are created by the scanning process. The scanning
/// process is triggered by the creation of a pipeline that uses automatic
/// registration to populate its rules. The pipeline constructor invokes the
/// [list] method to obtain the annoated request handlers for the pipeline.
///
/// Instances contain the request [handler] itself along with information about
/// it: the [location] it is in and its [name]. It also contains a copy of the
/// information from the annotation: the [pipelineName],
/// [httpMethod], [priority] and [pattern].

class _AnnotatedRequestHandler {
  //================================================================
  // Constructors

  //----------------------------------------------------------------
  /// Constructor of an annotated request handler.

  _AnnotatedRequestHandler(
      Handles registration, MethodMirror methodMirror, Function theFunction) {
    // Assume default values if (somehow) the values in the registration are
    // null. This is to reduce the amount of possible errors. The only value
    // that can't be null is the pattern.

    if (registration.pattern == null) {
      throw ArgumentError.notNull('pattern');
    }

    pipelineName = registration.pipeline ?? ServerPipeline.defaultName;
    httpMethod = registration.httpMethod ?? 'GET';
    priority = registration.priority ?? 0;
    pattern = Pattern(registration.pattern);

    // Information about the request handler

    location = methodMirror.location;

    name = MirrorSystem.getName(methodMirror.qualifiedName);
    if (name.startsWith('.')) {
      name = name.substring(1); // strip off "."
    }

    // Get the request handler to use

    if (Handles.handlerWrapper != null) {
      // A handler wrapper was defined. Use it to process the object that
      // was annotated (even if it is already a RequestHandler).
      handler = Handles.handlerWrapper(registration, theFunction);
    } else if (theFunction is RequestHandler) {
      // Function cannot be used as a handler
      handler = theFunction;
    }

    if (handler == null) {
      // Cannot use the annotated object.
      // Either: there was no handler wrapper (or it strangely returned
      // null) or the object was not a RequestHandler.

      throw RegistrationNotRequestHandler(location, name, registration);
    }
  }

  //================================================================
  // Static members

  /// Cache of the already found annotated request handlers.
  ///
  /// These have been populated from the [_librariesScanned] libraries.

  static final Map<String, List<_AnnotatedRequestHandler>> _found = {};

  /// The libraries that have already been scanned to populate [_found].
  ///
  /// It is possible, but unusual, for the pipeline constructor to be invoked
  /// on different occasions with a different list of packages to be scanned.
  /// This member tracks all the packages that have already been scanned, so
  /// they don't have to be re-scanned.

  static final List<String> _librariesScanned = [];

  /// Indicates if the [_librariesScanned] already includes all file libraries.

  static bool _allFilesLibrariesScanned = false;

  //================================================================
  // Members

  // Values derived from the [Handles] annotation.
  //
  // Note: we don't simply store the annotation, because it is a const object
  // and we want to change the pipeline name, method, and priority to defaults
  // if (for some strange reason) they were null in the annotation. Also,
  // the pattern is a string in the _Handles_, and we want to covert it into
  // a [Pattern] object. The conversion will detect bad patterns.

  String pipelineName;
  String httpMethod;
  int priority;
  Pattern pattern;

  /// Source location of the request handler

  SourceLocation location;

  /// Name of the handler function

  String name;

  /// The request handler function the annotation was on.

  RequestHandler handler;

  //================================================================
  // Methods

  //----------------------------------------------------------------
  /// Compares this annotated registration handler to [other].
  ///
  /// Returns a negative value if `this` is order before `other`, a positive
  /// value if `this` is ordered after `other`, or zero if `this` and `other`
  /// are equivalent.
  ///
  /// The order is determined by these values, in order:
  ///
  /// - pipeline name;
  /// - HTTP method;
  /// - priority; and finally
  /// - the pattern.
  ///
  /// Note: when sorting a list of annotated request handlers in a value of
  /// [_found], the pipeline name are all the same value. Also,
  /// sorting by HTTP method will not matter when it is used to create a rule
  /// on the pipeline, since those rules will be grouped according to the HTTP
  /// method.
  ///
  /// The priority allows explicit control over the ordering of the rules. But
  /// it is probably not necessary, since the order of the patterns will
  /// produce a working pipeline. See [Pattern.compareTo] for how patterns are
  /// ordered.

  int compareTo(_AnnotatedRequestHandler other) {
    // Compare by pipeline name

    final x = pipelineName.compareTo(other.pipelineName);
    if (x != 0) {
      return x;
    }

    // Compare by HTTP method

    final a = httpMethod.compareTo(other.httpMethod);
    if (a != 0) {
      return a; // method determines order
    }

    // Compare by priority

    final b = priority.compareTo(other.priority);
    if (b != 0) {
      return -b; // priority order: negate so higher priority appears earlier
    }

    // Compare by pattern

    return pattern.compareTo(other.pattern); // pattern determines order
  }

  //----------------------------------------------------------------

  @override
  String toString() {
    final pipeStr = (pipelineName != ServerPipeline.defaultName)
        ? 'pipeline="$pipelineName" '
        : '';
    final priorityStr = (priority != 0) ? 'priority=$priority ' : '';

    return '$pipeStr$priorityStr$httpMethod $pattern => $name ($location)';
  }

  //================================================================
  // Static methods

  //----------------------------------------------------------------
  /// Retrieve a list of annotated request handlers for a pipeline.
  ///
  /// Only those where the [Handles] annotation's pipeline name is
  /// [pipelineName] are returned.
  ///
  /// Only annotated request handlers found in the listed [libraries] and from
  /// files outside any packages are considered.

  static Iterable<_AnnotatedRequestHandler> list(
      String pipelineName, Iterable<String> libraries,
      {bool scanAllFileLibraries = true}) {
    assert(pipelineName != null);
    assert(libraries != null);

    // Make sure cache is populated from the explicitly requested libraries or
    // from all the files (if scanAllFileLibraries is true).
    // Previous scans might not have been told about these same libraries.

    _updateCache(libraries, scanAllFileLibraries: scanAllFileLibraries);

    // Pick the registrations with the desired pipeline name

    return _found[pipelineName] ?? <_AnnotatedRequestHandler>[];
  }

  //----------------------------------------------------------------
  /// Populates [_found] for files and the identified packages.
  ///
  /// Ensures a scan has been performed on the [libraries] and files that don't
  /// belong to any package.
  ///
  /// This does nothing if [_found] already contains all the
  /// annotated request handlers from the requested [libraries].

  static void _updateCache(Iterable<String> libraries,
      {bool scanAllFileLibraries = true}) {
    // Determine if a scan is required

    final needToScanFiles =
        (scanAllFileLibraries && !_allFilesLibrariesScanned);
    final unscanned =
        libraries.where((lib) => !_librariesScanned.contains(lib));

    // Perform scan if needed

    if (needToScanFiles || unscanned.isNotEmpty) {
      // Scan

      _scanSystem(unscanned, doFiles: needToScanFiles);

      _allFilesLibrariesScanned = needToScanFiles;
      _librariesScanned.addAll(unscanned);

      // Sort the annotated request handlers (from this and any previous scans)

      for (final arh in _found.values) {
        arh.sort((a, b) => a.compareTo(b));
      }

      // Logging

      for (final pipelineName in List<String>.from(_found.keys)..sort()) {
        // Above sorting is just so the logging is stable/consistent
        final regosWithHandlers = _found[pipelineName];

        final p = (pipelineName != ServerPipeline.defaultName)
            ? '"$pipelineName" pipeline'
            : 'default pipeline';
        final c = (regosWithHandlers.length != 1)
            ? '${regosWithHandlers.length} Registration annotations found'
            : '${regosWithHandlers.length} Registration annotation found';

        if (_logHandles.level <= Level.FINER) {
          // Log all the registrations with their request handlers
          _logHandles.finer('$p: $c\n  ${regosWithHandlers.join('\n  ')}');
        } else if (_logHandles.level <= Level.FINE) {
          // Log all the registrations without the request handler
          final brief =
              regosWithHandlers.map((r) => '${r.httpMethod} ${r.pattern}');
          _logHandles.fine('$p: $c\n  ${brief.join('\n  ')}');
        } else if (_logHandles.level <= Level.CONFIG) {
          // Only log the number of registrations found
          _logHandles.config('$p: $c');
        }
      }
    }
  }

  //----------------------------------------------------------------
  /// Scan the program for annotations.
  ///
  /// Libraries are scanned for annotations, if those libraries have not already
  /// been scanned.
  ///
  /// This method will only scan the libraries whose URLs are explicitly listed
  /// in [librariesToScan]. Or if [doFiles] is true, which treats all libraries
  /// that have a URL with the "file" scheme to be scanned (even if it is not
  /// explicitly listed in _librariesToScan_).
  ///
  /// Throws a [LibraryNotFound] if any of the libraries listed in
  /// [librariesToScan] does not exist.

  static void _scanSystem(Iterable<String> librariesToScan, {bool doFiles}) {
    // Track packages which were encountered

    final seenPackages = <String, bool>{};

    // Scan all the libraries for registrations

    final mirrorSys = currentMirrorSystem();

    if (mirrorSys == null) {
      throw UnimplementedError('cannot scan for annotations: no mirror system');
    }

    for (final entry in mirrorSys.libraries.entries) {
      final libUrl = entry.key;
      final library = entry.value;

      if (libUrl.scheme != 'dart') {
        // Not a core library, so might be ok (core libraries are never scanned)

        if (!_librariesScanned.contains(library)) {
          // Hasn't been previously scanned

          if (librariesToScan.contains(libUrl.toString()) ||
              (libUrl.scheme == 'file' && doFiles)) {
            // Need to scan this library, since it is either one of the
            // libraries there were explicitly asked to be scanned, or it is
            // a file-library and it was asked to scan all file-libraries.

            _logHandles.finest('scanning $libUrl');
            _scanLibrary(libUrl, library);
            _librariesScanned.add(libUrl.toString());
          }
        }
      }
    }

    // Check all the explicitly requested libraries were encountered

    final missing =
        librariesToScan.where((url) => !seenPackages.containsKey(url));
    if (missing.isNotEmpty) {
      throw LibraryNotFound(missing);
    }
  }

  //----------------------------------------------------------------
  /// Scan a library for _Handles_ annotations.
  ///
  /// Finds all the top-level functions and static methods inside classes, and
  /// scans each of them for [Handles] annotations.

  static void _scanLibrary(Uri library, LibraryMirror libMirror) {
    for (final declaration in libMirror.declarations.values) {
      if (declaration is ClassMirror) {
        _scanClass(library, declaration);
      } else if (declaration is MethodMirror) {
        // Top level function: process it

        final cm = libMirror.getField(declaration.simpleName);
        final dynamic item = cm.hasReflectee ? cm.reflectee : null;

        if (item is Function) {
          _scanFunction(library, declaration, item);
        } else {
          _logHandles
              .severe('not a function: $library ${declaration.qualifiedName}');
        }
      }
    }
  }

  //----------------------------------------------------------------
  // Scan a class for static members with [Handles] annotations.

  static void _scanClass(Uri library, ClassMirror classMirror) {
    // Class: process its static methods

    for (final staticMember in classMirror.staticMembers.values) {
      if (staticMember is MethodMirror) {
        if (!(staticMember.isGetter ||
            staticMember.isSetter ||
            staticMember.isOperator)) {
          final cm = classMirror.getField(staticMember.simpleName);
          final dynamic item = cm.hasReflectee ? cm.reflectee : null;

          if (item is Function) {
            _scanFunction(library, staticMember, item);
          } else {
            _logHandles.severe(
                'not a function: $library ${staticMember.qualifiedName}');
          }
        }
      }
    }
  }

  //----------------------------------------------------------------
  /// Scan a function or static method for [Handles] annotations.
  ///
  /// For all the registration annotations found on it, a
  /// [_AnnotatedRequestHandler] object is created and appended to the
  /// [_found] list under the pipeline identified in the
  /// annotation.
  ///
  /// Note: a method may have more than one registration annotation on it.
  /// Each one will result in its own annotated request handler.

  static void _scanFunction(
      Uri library, MethodMirror methodMirror, Function theFunction) {
    for (final instanceMirror in methodMirror.metadata) {
      if (instanceMirror.hasReflectee) {
        // The annotation is an instance of the [Registration] class

        final dynamic annotation = instanceMirror.reflectee;

        if (annotation is Handles) {
          // [Handles] annotation found

          try {
            // Create a new annotated request handler and add it to [_found].

            final entry =
                _AnnotatedRequestHandler(annotation, methodMirror, theFunction);

            // Note: entry.pipelineName will always have a value, even if the
            // annotation.pipelineName was null.
            final goodName = entry.pipelineName;

            if (!_found.containsKey(goodName)) {
              _found[goodName] = []; // new pipeline name: start a new list
            }
            _found[goodName].add(entry); // add the entry to the named list

            // ignore: avoid_catching_errors
          } on ArgumentError catch (e) {
            // Pattern constructor did not accept the pattern string.
            // Throw an exception that indicates the location of the annotation
            // (from the methodMirror) for easier debugging.
            throw BadRegistrationPattern(methodMirror, e);
          }
        } else {
          // ignore all other types of annotation
        }
      }
    }
  }
}
