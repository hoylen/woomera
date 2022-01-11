part of scan;

//################################################################
// Static members

/// Annotated handlers in the program
///
/// This is effectively a global variable, since a program only has one set
/// of libraries. So once the libraries have been scanned, the annotated
/// handlers can be cached for creating multiple pipelines, setting server
/// exception handlers and server raw exception handlers.
///
/// This static member is used by [serverPipelineFromAnnotations] and
/// [serverFromAnnotations].

final _annotations = _AnnotationScanner();

//################################################################

class _AnnotatedHandlerBase {
  //================================================================
  // Constructors

  //----------------------------------------------------------------
  /// Constructor of an annotated handler.

  _AnnotatedHandlerBase(MethodMirror methodMirror) {
    // Information about the request handler

    final _loc = methodMirror.location;
    ArgumentError.checkNotNull(_loc, 'no location');
    location = _loc!;

    final qn = MirrorSystem.getName(methodMirror.qualifiedName);
    // Set the name to the qualified name with any leading "." stripped off.
    name = (qn.startsWith('.')) ? qn.substring(1) : qn;
  }

  //================================================================
  // Members

  /// Source location of the request handler

  late final SourceLocation location;

  /// Name of the handler function

  late final String name;
}

//################################################################
/// Annotated request handler
///
/// This class represents a function or static method that has a [Handles]
/// annotation for a request handler.
///
/// Instances of this class are created by the scanning process.
///
/// Instances contain the request [handler] itself along with information about
/// where in the code it was found: the [location] it is in and its [name].
/// It also contains a copy of the information from the annotation: the
/// [pipelineName], [httpMethod], [priority] and [pattern].

class _AnnotatedRequestHandler extends _AnnotatedHandlerBase {
  //================================================================
  // Constructors

  //----------------------------------------------------------------
  /// Constructor of an annotated request handler.

  _AnnotatedRequestHandler(
      Handles annotation, MethodMirror methodMirror, this.annotatedFunction)
      : assert(annotation.isRequestHandler),
        super(methodMirror) {
    // Assume default values if (somehow) the values in the registration are
    // null. This is to reduce the amount of possible errors. The only value
    // that can't be null is the pattern.

    pipelineName = annotation.pipeline ?? ServerPipeline.defaultName;

    ArgumentError.checkNotNull(annotation.httpMethod, 'httpMethod');
    httpMethod = annotation.httpMethod!;

    priority = annotation.priority ?? 0;

    ArgumentError.checkNotNull(annotation.pattern, 'pattern');
    pattern = Pattern(annotation.pattern!);

    // Convert the function into a request handler (if necessary)

    var gotHandler = false;

    final _hw = Handles.handlerWrapper;
    if (_hw != null) {
      // A handler wrapper was defined. Use it to process the object that
      // was annotated (even if it is already a RequestHandler).
      handler = _hw(annotation, annotatedFunction);
      gotHandler = true;
      // Warning: above handlerWrapper could return null
    } else {
      final af = annotatedFunction;
      if (af is RequestHandler) {
        // Function can be used as a handler
        // ignore: avoid_as
        handler = af;
        gotHandler = true;
      }
    }

    if (!gotHandler) {
      // Cannot use the annotated object.
      // Either: there was no handler wrapper (or it strangely returned
      // null) or the object was not a RequestHandler.

      throw NotRequestHandler(location, name, annotation);
    }
  }

  //================================================================
  // Members

  // Values derived from the [Handles] annotation.
  //
  // Note: we don't simply store the annotation, because it is a const object
  // and we want to change the pipeline name, method, and priority to defaults
  // if (for some strange reason) they were null in the annotation. Also,
  // the pattern is a string in the _Handles_, and we want to covert it into
  // a [Pattern] object. The conversion will detect bad patterns.

  late String pipelineName;
  late String httpMethod;
  late int priority;
  late Pattern pattern;

  /// The function the annotation was on (before applying any `handlerWrapper`)

  final Function annotatedFunction;

  /// The request handler function the annotation was on.

  late RequestHandler handler;

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
}

//################################################################
/// Annotated exception handler
///
/// This class represents a function or static method that has a [Handles]
/// annotation for a pipeline exception handler or server exception handler.
///
/// Instances of this class are created by the scanning process.

class _AnnotatedExceptionHandler extends _AnnotatedHandlerBase {
  //================================================================
  // Constructors

  //----------------------------------------------------------------
  /// Constructor of an annotated exception handler.

  _AnnotatedExceptionHandler(
      Handles annotation, MethodMirror methodMirror, Function theFunction)
      : assert(!annotation.isRequestHandler),
        super(methodMirror) {
    // Note: a null pipelineName means this is the server exception handler,
    // instead of an exception handler for a pipeline.

    pipelineName = annotation.pipeline;

    // Get the request handler to use

    if (theFunction is ExceptionHandler) {
      // The function is suitable
      handler = theFunction;
    } else {
      // Cannot use the annotated object.
      // Either: there was no handler wrapper (or it strangely returned
      // null) or the object was not a ExceptionHandler.
      throw NotExceptionHandler(location, name, annotation);
    }
  }

  //================================================================
  // Members

  /// Name of the pipeline for pipeline exception handlers
  ///
  /// Null is used for server exception handler (i.e. it does not belong to
  /// any pipeline).

  late final String? pipelineName;

  /// The exception handler function the annotation was on.

  late final ExceptionHandler handler;

  //================================================================
  // Methods

  //----------------------------------------------------------------

  @override
  String toString() {
    final desc = (pipelineName == null)
        ? 'server exception handler'
        : (pipelineName != ServerPipeline.defaultName)
            ? 'pipeline "$pipelineName" exception handler'
            : 'default pipeline exception handler';

    return '$desc => $name ($location)';
  }
}

//################################################################
/// Annotated raw exception handler
///
/// This class represents a function or static method that has a [Handles]
/// annotation for a server raw exception handler.
///
/// Instances of this class are created by the scanning process.

class _AnnotatedRawExceptionHandler extends _AnnotatedHandlerBase {
  //================================================================
  // Constructors

  //----------------------------------------------------------------
  /// Constructor of an annotated exception handler.

  _AnnotatedRawExceptionHandler(
      Handles annotation, MethodMirror methodMirror, Function theFunction)
      : assert(!annotation.isRequestHandler),
        super(methodMirror) {
    var gotHandler = false;

    // Get the request handler to use

    if (theFunction is ExceptionHandlerRaw) {
      // Function cannot be used as a handler
      handler = theFunction;
      gotHandler = true;
    }

    if (!gotHandler) {
      // Cannot use the annotated object.
      throw NotExceptionHandler(location, name, annotation);
    }
  }

  //================================================================
  // Members

  /// The exception handler function the annotation was on.

  late ExceptionHandlerRaw handler;

  //================================================================
  // Methods

  //----------------------------------------------------------------

  @override
  String toString() => 'server raw exception handler => $name ($location)';
}

//################################################################
/// Annotation scanner
///
/// Used to scan the libraries of a program for [Handles] annotations.

class _AnnotationScanner {
  //================================================================
  // Members

  //----------------
  // What has already been found

  /// Cache of the already found annotated request handlers.
  ///
  /// These have been populated from the [_librariesScanned] libraries.

  final Map<String, List<_AnnotatedRequestHandler>> _found = {};

  /// Cache of the already found exception handlers.
  ///
  /// The pipeline name is used as the key (for pipeline exception handlers).
  /// The key is null for the server exception handler.
  ///
  /// These have been populated from the [_librariesScanned] libraries.

  final Map<String?, _AnnotatedExceptionHandler> _foundExceptionHandlers = {};

  /// Cache of the found raw exception handler.
  ///
  /// There can only be at most one such handler for the program.

  _AnnotatedRawExceptionHandler? _foundRawExceptionHandler;

  //----------------
  // What was scanned to find them

  /// The libraries that have already been scanned to populate [_found] and
  /// [_foundExceptionHandlers].
  ///
  /// It is possible, but unusual, for the pipeline constructor to be invoked
  /// on different occasions with a different list of packages to be scanned.
  /// This member tracks all the packages that have already been scanned, so
  /// they don't have to be re-scanned.

  final List<String> _librariesScanned = [];

  /// Indicates if the [_librariesScanned] already includes all file libraries.

  bool _allFilesLibrariesScanned = false;

  //----------------
  // What has been used

  /// Tracks which pipelines have been created using annotations.
  ///
  /// This is used by [serverFromAnnotations] to check if all the annotations
  /// have been used to create pipelines. If not a warning is logged, since
  /// a possible mistake is to create annotations that are never used.

  static final _pipelineNamesUsed = <String, int>{};

  //================================================================
  // Methods to retrieved scanned annotations

  //----------------------------------------------------------------
  /// Retrieve a list of annotated request handlers for a pipeline.
  ///
  /// Only those where the [Handles] annotation's pipeline name is
  /// [pipelineName] are returned.

  Iterable<_AnnotatedRequestHandler> listRequestHandlers(String pipelineName) =>
      _found[pipelineName] ?? <_AnnotatedRequestHandler>[];

  //----------------------------------------------------------------
  /// Retrieve an annotated exception handler for a pipeline.
  ///
  /// Returns null if there is none

  _AnnotatedExceptionHandler? findPipelineExceptionHandler(
      String pipelineName) {
    ArgumentError.checkNotNull(pipelineName);

    return _foundExceptionHandlers[pipelineName];
  }

  //----------------------------------------------------------------
  /// Retrieve an annotated exception handler for the server.
  ///
  /// Returns null if there is none.

  _AnnotatedExceptionHandler? findServerExceptionHandler() =>
      _foundExceptionHandlers[null];

  //----------------------------------------------------------------
  /// Retrieve an annotated raw exception handler for the server.
  ///
  /// Returns null if there is none.

  _AnnotatedRawExceptionHandler? findServerRawExceptionHandler() =>
      _foundRawExceptionHandler;

  //================================================================
  // Methods for detecting unused annotations

  //----------------------------------------------------------------
  /// Mark a pipeline name as being used.

  void markAsUsed(String pipelineName) {
    // Record the name has been used

    final existing = _pipelineNamesUsed[pipelineName];
    _pipelineNamesUsed[pipelineName] = existing == null ? 1 : existing + 1;
  }

  //----------------------------------------------------------------
  /// Check all the annotations found have been used.
  ///
  /// Note: this does not check that any server exception handler or
  /// server raw exception handler has been used or not. Since this method
  /// is invoked by [serverFromAnnotations], which uses them before invoking
  /// this method.

  List<String> checkForUnusedAnnotations() {
    final notUsed = <String>[];

    for (final entry in _found.entries) {
      if (!_pipelineNamesUsed.containsKey(entry.key)) {
        for (final arh in entry.value) {
          notUsed.add('$arh');
        }
      }
    }

    for (final entry in _foundExceptionHandlers.entries) {
      // Note: null is the key for the server exception handler: ignore it
      if (entry.key != null && !_pipelineNamesUsed.containsKey(entry.key)) {
        notUsed.add('${entry.value}');
      }
    }

    return notUsed;
  }

  //================================================================
  // Methods for scanning

  //----------------------------------------------------------------
  /// Populates [_found] for files and the identified packages.
  ///
  /// Ensures a scan has been performed on the [libraries] and files that don't
  /// belong to any package.
  ///
  /// This does nothing if [_found] already contains all the
  /// annotated request handlers from the requested [libraries].

  void scan(Iterable<String> libraries, {bool scanAllFileLibraries = true}) {
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
      //
      // Note: the name of the pipeline is the same for every member of the list
      // and sorting by the HTTP method is just makes the log entries look nicer
      // since it doesn't affect the behaviour of the rules in a pipeline.

      for (final arh in _found.values) {
        arh.sort((a, b) => a.compareTo(b));
      }

      // Logging request handlers, pipeline exception handlers, server
      // exception handler and server raw exception handler

      for (final pipelineName in List<String>.from(_found.keys)..sort()) {
        // Above sorting is just so the logging is stable/consistent
        final regosWithHandlers = _found[pipelineName]!;

        final p = (pipelineName != ServerPipeline.defaultName)
            ? '"$pipelineName" pipeline'
            : 'default pipeline';
        final c = (regosWithHandlers.length != 1)
            ? '${regosWithHandlers.length} annotated request handlers found'
            : '${regosWithHandlers.length} annotated request handler found';

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

      var numEH = 0;

      final pipelinesWithEP = List<String?>.from(_foundExceptionHandlers.keys)
        ..remove(null); // null represents the server exception handler

      for (final pipelineName in pipelinesWithEP..sort()) {
        // Above sorting is just so the logging is stable/consistent
        final apeh = _foundExceptionHandlers[pipelineName];

        final p = (pipelineName != ServerPipeline.defaultName)
            ? '"$pipelineName" pipeline'
            : 'default pipeline';

        if (_logHandles.level <= Level.FINER) {
          // Log all the registrations with their request handlers
          _logHandles.finer(apeh);
        } else if (_logHandles.level <= Level.FINE) {
          // Log all the registrations without the request handler
          _logHandles.fine('$p: pipeline exception handler');
        }
        numEH++;
      }

      final serverEH = _foundExceptionHandlers[null];
      if (serverEH != null) {
        if (_logHandles.level <= Level.FINER) {
          _logHandles.finer(serverEH);
        } else if (_logHandles.level <= Level.FINE) {
          // Log all the registrations without the request handler
          _logHandles.fine('server exception handler');
        }
        numEH++;
      }

      if (_foundRawExceptionHandler != null) {
        if (_logHandles.level <= Level.FINER) {
          _logHandles.finer(_foundRawExceptionHandler);
        } else if (_logHandles.level <= Level.FINE) {
          // Log all the registrations without the request handler
          _logHandles.fine('server raw exception handler');
        }
        numEH++;
      }

      if (_logHandles.level <= Level.CONFIG &&
          !(_logHandles.level <= Level.FINE)) {
        final noun = (numEH != 1) ? 'handlers' : 'handler';
        _logHandles.config('$numEH annotated exception $noun found');
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

  void _scanSystem(Iterable<String> librariesToScan, {required bool doFiles}) {
    // Track packages which were encountered

    final seenPackages = <String, bool>{};

    // Scan all the libraries for registrations

    final mirrorSys = currentMirrorSystem();
    ArgumentError.checkNotNull(
        mirrorSys, 'cannot scan for annotations: no mirror system');

    for (final entry in mirrorSys.libraries.entries) {
      final libUrl = entry.key;
      final library = entry.value;

      if (libUrl.scheme != 'dart') {
        // Not a core library, so might be ok (core libraries are never scanned)

        if (!_librariesScanned.contains(libUrl.toString())) {
          // Hasn't been previously scanned

          if (librariesToScan.contains(libUrl.toString()) ||
              (libUrl.scheme == 'file' && doFiles)) {
            // Need to scan this library, since it is either one of the
            // libraries there were explicitly asked to be scanned, or it is
            // a file-library and it was asked to scan all file-libraries.

            _logHandles.finest('scanning $libUrl');
            _scanLibrary(libUrl, library);
            _librariesScanned.add(libUrl.toString());
          } else {
            _logHandles.finest('skipped $libUrl');
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

  void _scanLibrary(Uri library, LibraryMirror libMirror) {
    for (final declaration in libMirror.declarations.values) {
      if (declaration is ClassMirror) {
        _scanClass(library, declaration);
      } else if (declaration is MethodMirror) {
        // Top level function: process it

        try {
          final cm = libMirror.getField(declaration.simpleName);
          final dynamic item = cm.hasReflectee ? cm.reflectee : null;

          if (item is Function) {
            _scanFunction(library, declaration, item);
          } else {
            _logHandles.severe(
                'not a function: $library ${declaration.qualifiedName}');
          }
          // ignore: avoid_catching_errors
        } on NoSuchMethodError {
          final name = MirrorSystem.getName(declaration.simpleName);
          if (name.contains('.')) {
            // Dart extensions result in top level methods/functions whose names
            // are "ExtensionName.MethodName". Ignore the exceptions cause by
            // these.
            _logHandles.finer('ignored extension method: $name');
          } else {
            // Some other cause
            rethrow;
          }
        }
      }
    }
  }

  //----------------------------------------------------------------
  // Scan a class for static members with [Handles] annotations.

  void _scanClass(Uri library, ClassMirror classMirror) {
    // Class: process its static methods

    for (final staticMember in classMirror.staticMembers.values) {
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

  void _scanFunction(
      Uri library, MethodMirror methodMirror, Function theFunction) {
    for (final instanceMirror in methodMirror.metadata) {
      if (instanceMirror.hasReflectee) {
        // The annotation is an instance of the [Registration] class

        final dynamic annotation = instanceMirror.reflectee;

        if (annotation is Handles) {
          // [Handles] annotation found

          if (annotation.isRequestHandler) {
            _foundRequestHandler(annotation, methodMirror, theFunction);
          } else {
            _foundExceptionHandler(annotation, methodMirror, theFunction);
          }
        } else {
          // ignore all other types of annotation
        }
      }
    }
  }

  //----------------

  void _foundRequestHandler(
      Handles annotation, MethodMirror methodMirror, Function theFunction) {
    try {
      // Create a new annotated request handler and add it to [_found].

      final entry =
          _AnnotatedRequestHandler(annotation, methodMirror, theFunction);

      // Note: entry.pipelineName will always have a value, even if the
      // annotation.pipelineName was null.
      final goodName = entry.pipelineName;

      final existing = _found[goodName];
      if (existing == null) {
        _found[goodName] = [entry]; // new pipeline name: start a new list
      } else {
        existing.add(entry); // add the entry to the named list
      }

      // ignore: avoid_catching_errors
    } on ArgumentError catch (e) {
      // Pattern constructor did not accept the pattern string.
      // Throw an exception that indicates the location of the annotation
      // (from the methodMirror) for easier debugging.
      throw BadHandlesPattern(methodMirror, e);
    }
  }

  //----------------

  void _foundExceptionHandler(
      Handles annotation, MethodMirror methodMirror, Function theFunction) {
    if (annotation.isPipelineExceptionHandler ||
        annotation.isServerExceptionHandler) {
      // Both are handled the same.
      // The only difference is with the server exception handler, the pipeline
      // name is null.

      final entry =
          _AnnotatedExceptionHandler(annotation, methodMirror, theFunction);

      // Note: entry.pipelineName will always have a value, even if the
      // annotation.pipelineName was null.
      final goodName = entry.pipelineName;

      final existing = _foundExceptionHandlers[goodName];
      if (existing != null) {
        var name = MirrorSystem.getName(methodMirror.qualifiedName);
        if (name.startsWith('.')) {
          name = name.substring(1); // strip off "."
        }

        throw DuplicateExceptionHandler(methodMirror.location, name, annotation,
            existing.location, existing.name);
      }
      _foundExceptionHandlers[goodName] = entry;
    } else {
      // Raw server exception handler

      assert(annotation.isServerRawExceptionHandler);

      final found = _foundRawExceptionHandler;
      if (found != null) {
        var name = MirrorSystem.getName(methodMirror.qualifiedName);
        if (name.startsWith('.')) {
          name = name.substring(1); // strip off "."
        }

        throw DuplicateExceptionHandler(methodMirror.location, name, annotation,
            found.location, found.name);
      }

      _foundRawExceptionHandler =
          _AnnotatedRawExceptionHandler(annotation, methodMirror, theFunction);
    }
  }
}
