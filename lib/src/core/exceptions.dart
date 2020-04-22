part of core;

//================================================================
// Exception Base class

/// Base class for all exceptions defined in the Woomera package.

abstract class WoomeraException implements Exception {}

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
  String toString() => 'duplicate rule: $method $pattern';
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
