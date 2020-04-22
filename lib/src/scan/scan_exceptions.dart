part of scan;

//================================================================
/// Attempt to register a duplicate rule in a pipeline.
///
/// This class extends [DuplicateRule] when the Mirrors package is available
/// to describe the existing handler.

class DuplicateRuleWithExistingHandler extends DuplicateRule {
  /// Constructor

  DuplicateRuleWithExistingHandler(String method, Pattern pattern,
      RequestHandler newHandler, RequestHandler existingHandler)
      : super(method, pattern, newHandler, existingHandler);

  //----------------------------------------------------------------

  @override
  String toString() {
    String describeExisting;
    try {
      String n;
      SourceLocation loc;

      final r1 = reflect(existingHandler);
      if (r1 is ClosureMirror) {
        loc = r1.function.location;
        n = MirrorSystem.getName(r1.function.qualifiedName);
        if (n.startsWith('.')) {
          n = n.substring(1); // remove leading '.'
        }
      }

      describeExisting = ' already handled by $n ($loc)';
      // ignore: avoid_catching_errors
    } on UnsupportedError {
      // No location information to report
      describeExisting = '';
    }

    return super.toString() + describeExisting;
  }
}

//----------------------------------------------------------------
/// Library not found
///
/// One or more of the libraries that was passed into [serverFromAnnotations]
/// or [serverPipelineFromAnnotations] does not exist.
///
/// To fix the problem, remove or fix the offending value.
///
/// To discover the correct library URIs that can be used, set the logging level
/// for the "woomera.handles" logger to FINEST. It will then log the URI for
/// libraries that are scanned or skipped.

class LibraryNotFound extends WoomeraException {
  /// Constructor
  LibraryNotFound(Iterable<String> missing)
      : libraryUris = List<String>.from(missing);

  /// Packages which were not found
  final List<String> libraryUris;

  @override
  String toString() {
    final noun = (libraryUris.length == 1) ? 'library' : 'libraries';
    return '$noun not found:\n  ${libraryUris.join('\n  ')}';
  }
}

//----------------------------------------------------------------
/// Indicates the pattern to create a Handles object is invalid.

class BadHandlesPattern extends WoomeraException {
  /// Constructor for a bad handles pattern

  BadHandlesPattern(MethodMirror mm, this.error) {
    try {
      location = mm.location;
      // ignore: avoid_catching_errors
    } on UnsupportedError {
      // No location information to report
    }

    name = MirrorSystem.getName(mm.qualifiedName);
    if (name.startsWith('.')) {
      name = name.substring(1); // remove leading "."
    }
  }

  /// Name of method
  String name;

  /// The location of the object.
  SourceLocation location;

  /// The error message indicating why the pattern was invalid.
  final ArgumentError error;

  @override
  String toString() {
    final loc = (location != null) ? ' ($location)' : '';
    return 'bad pattern: ${error.message}: "${error.invalidValue}": $name$loc';
  }
}

//----------------------------------------------------------------
/// Indicates an Handles annotation was place on the wrong type of function.
///
/// The type signature of the function or method was not the [RequestHandler]
/// function type.

class NotRequestHandler extends WoomeraException {
  /// Constructor
  NotRequestHandler(this.location, this.name, this.annotation);

  /// Library where the function was defined.
  final SourceLocation location;

  /// Name of the function
  final String name;

  /// The annotation
  final Handles annotation;

  @override
  String toString() =>
      'function is not a RequestHandler: $annotation: $name ($location)';
}

//----------------------------------------------------------------
/// Indicates an Handles annotation was place on the wrong type of function.
///
/// The type signature of the function or method was not the [ExceptionHandler]
/// function type.

class NotExceptionHandler extends WoomeraException {
  /// Constructor
  NotExceptionHandler(this.location, this.name, this.annotation);

  /// Library where the function was defined.
  final SourceLocation location;

  /// Name of the function
  final String name;

  /// The annotation
  final Handles annotation;

  @override
  String toString() =>
      'function is not a ExceptionHandler: $annotation: $name ($location)';
}

//----------------------------------------------------------------
/// Indicates a Handles annotation already exists for the exception handler.

class DuplicateExceptionHandler extends WoomeraException {
  /// Constructor
  DuplicateExceptionHandler(
    this.location,
    this.name,
    this.annotation,
    this.existingLocation,
    this.existingName,
  );

  /// Library where the function was defined.
  final SourceLocation location;

  /// Name of the function
  final String name;

  /// The annotation
  final Handles annotation;

  /// Location of the already existing annotated exception handler
  final SourceLocation existingLocation;

  /// Name of the already existing annotated exception handler
  final String existingName;

  @override
  String toString() => 'duplicate $annotation: $name ($location)\n'
      '  existing exception handler: $existingName ($existingLocation)';
}
