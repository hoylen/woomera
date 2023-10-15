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

class MalformedPathException extends WoomeraException {
  /// Constructor
  ///
  /// The [message] is optional.

  MalformedPathException([this.message]);

  /// Details of the exception.

  final String? message;
}

//----------------------------------------------------------------
/// Exception indicating a response could not be created.
///
/// The exact cause is indicated by the [found] property:
///
/// - `NotFoundException.foundNothing` means the request URI matched no rule on
///   both the HTTP method and the pattern.
/// - `NotFoundException.foundMethod` means, while there were rules with the
///   same HTTP method, their patterns did not match.
/// - `NotFoundException.foundHandler` means at least one rule matched, but they
///   all threw the special _NoResponseProduced_ exception and there was no
///   subsequent rule that matched and produced a _Response_.
/// - `NotFoundException.foundStaticHandler` means the _request handler_
///   that serves up files from under a directory was matched, but there
///   was no file/directory that matched the URI path.
///
/// These should all result in a HTTP status of _HTTP 404 Not Found_ for the
/// HTTP response.
///
/// **Known issue:** the _NotFoundException.foundMethod_ value was intended to
/// distinguish between _HTTP 404 Not Found_ and _HTTP 405 Method Not
/// Allowed_. But the implementation is incorrect. Currently, it is used when
/// the HTTP method is not known to any rule (ignoring all the patterns). The
/// correct situation for a HTTP 405 is when there are patterns that match but
/// none of the HTTP methods in those rules match.

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
/// Exception to indicate a [RequestHandler] did not produce a response.
///
/// This exception should be thrown by a handler when it deliberately does not
/// produce a [Response], but expects a subsequent rule in the pipeline (or a
/// rule in a subsequent pipeline) to produce the response.
///
/// Currently, the [RequestHandler] is defined to return a Future<Response?>,
/// and it completes with a null to indicate the handler did not produce any
/// response. In a future release, the _RequestHandler_ will be redefined as
/// `Future<Response>`. To prepare for that breaking change, define
/// response handlers as returning a _Future<Response>_ and throw this
/// exception instead of returning a Future that completes with a null.

class NoResponseFromHandler extends WoomeraException {}

//================================================================
// No response

//----------------------------------------------------------------
/// Indicates a handler cannot produce a response.
///
/// This is not necessarily an error: it just means that particular handler
/// function expects some other function to produce the response.
///
/// For request handlers, the function expects another handler in the pipeline,
/// or a subsequent pipeline, to further process the request.
///
/// Note: before _null safety_ handlers used to return _null_ to indicate a
/// response was not produced. With _null safety_ the handlers cannot return
/// null, so they throw this exception instead.

class NoResponseProduced extends WoomeraException {
  /// Constructor.

  NoResponseProduced();
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
      if (e.message.isEmpty) {
        final ose = e.osError;
        if (ose != null) {
          if (ose.errorCode == 61 && ose.message == 'Connection refused') {
            // Known situation: use a more compact error message
            message = 'cannot connect';
          }
        }
      }
    }

    return 'proxy: $message: $targetUri';
  }
}
