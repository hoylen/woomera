part of woomera;

//================================================================
// Exception Base class

/// Base class for all exceptions defined in the Woomera package.

abstract class WoomeraException implements Exception {}

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
/// Exception indicating a response could not be created.
///
class NotFoundException extends WoomeraException {
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

  int found;

  /// Constructor.
  ///
  NotFoundException(this.found);

  /// String representation
  @override
  String toString() {
    var s = "unknown";
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
  /// Exception object that was being processed by exception handler.
  ///
  Object previousException;

  /// The exception that thrown by the exception handler.
  ///
  Object exception;

  /// Constructor.
  ///
  ExceptionHandlerException(this.previousException, this.exception);
}
