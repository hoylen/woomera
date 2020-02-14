part of woomera;

//================================================================
// Exception Base class

/// Base class for all exceptions defined in the Woomera package.

abstract class WoomeraException implements Exception {}

//================================================================
// Exceptions relating to Handles annotations

//----------------------------------------------------------------
/// Library not found
///
/// One or more of the libraries that was passed into [Server.fromAnnotations]
/// or [ServerPipeline.fromAnnotations] does not exist.
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

class DupliateExceptionHandler extends WoomeraException {
  /// Constructor
  DupliateExceptionHandler(
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

//----------------------------------------------------------------
/// Attempt to register a duplicate rule in a pipeline.
///
/// A rule already exists in the pipeline for the same HTTP method and path.
///
/// This is treated as an error, because it usually a sign of a coding error.
///
/// If there are duplicate rules, the first one will match the request and the
/// subsequent ones will normally never get used. The only situation where
/// duplicate rules are useful is if the earlier rule(s) deliberately returned
/// null, so the rule matching process continues and tries to match the request
/// to subsequent rules. That is, the application deliberately wants a single
/// request to be processed by multiple request handlers. This rare situation
/// can be implemented by putting subsequent rules into different pipelines.
/// There is no restriction on duplicate rules if they appear in different
/// pipelines. The restriction is only on duplicate rules in the same pipeline.

class DuplicateRule extends WoomeraException {
  /// Constructor
  DuplicateRule(
      this.method, this.pattern, this.newHandler, this.existingHandler);

  /// HTTP method
  final String method;

  /// Path
  final Pattern pattern;

  /// The new request handler being registered.
  final RequestHandler newHandler;

  /// The request handler that has already been registered in the pipeline.
  final RequestHandler existingHandler;

  @override
  String toString() {
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

      return 'duplicate rule: $method $pattern already handled by $n ($loc)';

      // ignore: avoid_catching_errors
    } on UnsupportedError {
      // No location information to report
      return 'duplicate rule: $method $pattern';
    }
  }
}

//================================================================
// Limit exceptions

//----------------------------------------------------------------
/// Exception indicating the URL path is too large.
///
/// Usually this means a malformed or malicious request has been received.
/// It has stopped trying to parse/process it to avoid consuming
/// resources in what could be a denial-of-service attack.
///
/// If the request is a legitimate request for the application, the
/// limits on the server need to be increased.

class PathTooLongException extends WoomeraException {}

//----------------------------------------------------------------
/// Exception indicating the contents of the POST request is too large.
///
/// Usually this means a malformed or malicious request has been received.
/// It has stopped trying to parse/process it to avoid consuming
/// resources in what could be a denial-of-service attack.
///
/// If the request is a legitimate request for the application, the
/// limits on the server need to be increased.

class PostTooLongException extends WoomeraException {}

//================================================================
// Handler matching exceptions

//----------------------------------------------------------------
/// Exception indicating malformed request.
///
/// Usually a sign of an attacker trying to exploit vulnerabilities in a Web
/// server.

class MalformedPathException extends WoomeraException {}

//----------------------------------------------------------------
/// Exception indicating a response could not be created.
///
class NotFoundException extends WoomeraException {
  /// Constructor.

  NotFoundException(this.found);

  /// Value for [found] when no handlers for the HTTP method were found.

  static const int foundNothing = 0;

  /// Value for [found] when at least one handler for the HTTP method
  /// was found, but none of them matched the request path.

  static const int foundMethod = 1;

  /// Value for [found] when a handler was found, but no result was produced.

  static const int foundHandler = 2;

  /// Value for [found] when a StaticFile handler failed to produce a response.
  ///
  /// The StaticFile.handler failed to find a file or directory. In the case
  /// of a directory, this could be because the directory could not be read,
  /// the default file in the directory could not be read, or an automatic
  /// listing of the directory was not permitted.

  static const int foundStaticHandler = 3;

  /// Indicates how much was found before a result could not be created.
  ///
  /// This member is typically used to distinguish between the situation of
  /// the HTTP method not being supported (when its value is
  /// [NotFoundException.foundNothing] and when at least there were some rules
  /// for processing the HTTP method (when its value is any other value).
  /// In the former situation, the HTTP response should return a status of
  /// [HttpStatus.methodNotAllowed]. In the later situation, the HTTP
  /// response should return a status of [HttpStatus.notFound].

  final int found;

  /// String representation
  @override
  String toString() {
    var s = 'unknown';
    switch (found) {
      case foundNothing:
        s = 'method not supported';
        break;
      case foundMethod:
        s = 'path not supported';
        break;
      case foundHandler:
        s = 'no result';
        break;
      case foundStaticHandler:
        s = 'no resource';
        break;
    }
    return s;
  }
}

//================================================================
// Exception handling exception

//----------------------------------------------------------------
/// Exception indicating an exception/error occurred in an exception handler.
///
/// The exception that was raised by the exception handler is stored in
/// [exception].
///
/// The exception that was passed into the exception handler was
/// [previousException]. Note: it could be an instance of
/// [ExceptionHandlerException] when multiple exception handlers are invoked
/// in processing an exception.
///
class ExceptionHandlerException extends WoomeraException {
  /// Constructor.

  ExceptionHandlerException(this.previousException, this.exception);

  /// Exception object that was being processed by exception handler.

  Object previousException;

  /// The exception that thrown by the exception handler.

  Object exception;
}

//================================================================
// Proxy exception

//----------------------------------------------------------------
/// Exception indicating an exception/error occurred in the proxy handler.

class ProxyHandlerException extends WoomeraException {
  /// Constructor.

  ProxyHandlerException(this.targetUri, this.exception);

  /// The target URI

  final String targetUri;

  /// The exception that was thrown when trying to retrieve the [targetUri].

  final Object exception;

  /// String representation of the exception.

  @override
  String toString() {
    var message = 'exception ${exception.runtimeType}: $exception';

    final e = exception;
    if (e is SocketException) {
      if (e.message == '' &&
          e.osError != null &&
          e.osError.errorCode == 61 &&
          e.osError.message == 'Connection refused') {
        // Known situation: more compact error message
        message = 'cannot connect';
      }
    }
    return 'proxy: $message: $targetUri';
  }
}
