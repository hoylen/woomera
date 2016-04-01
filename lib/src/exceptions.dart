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
/// Exception indicating a rule for the request could not be found.
///
class NotFoundException extends WoomeraException {

  Request request;

  /// Indicates that no handlers for the HTTP method was found.
  ///
  /// If true, no rules for the HTTP method was found. If false, rules for the
  /// method were found, but none of them matched the request.
  ///
  /// This should be used to set the HTTP response status to either
  /// [HttpStatus.NOT_FOUND] to [HttpStatus.METHOD_NOT_ALLOWED].

  bool methodNotFound;

  NotFoundException(Request req, {bool methodNotFound: false}) {
    this.request = req;
    this.methodNotFound = methodNotFound;
  }

  String toString() => "Not found: ${request.requestPath()}";
}

//================================================================
// Exception handling exception

//----------------------------------------------------------------
/// Exception indicating an exception occurred in an exception handler.
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
  Object previousException;

  /// The exception that the exception handler was processing.
  Object exception;

  ExceptionHandlerException(this.previousException, this.exception);
}
