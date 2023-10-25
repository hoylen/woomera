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
/// The HTTP response should have a status of _HTTP 404 Not Found_
/// or _HTTP 405 Method Not Allowed_ depending on if [resourceExists]
/// is false or true, respectively.
///
/// For debugging purposes, the exact cause is indicated by the [found]
/// property.

class NotFoundException extends WoomeraException {
  /// Constructor.

  NotFoundException(this.found);

  /// Value for [found] when no handlers for the HTTP method were found.
  ///
  /// This value has been deprecated in woomera 8.0.0. In previous releases,
  /// it was implemented incorrectly. This value was used when no rules
  /// existed for the HTTP method. And was intended for a _HTTP 405 Method
  /// Not Found_ status; as opposed to _foundMethod_ which was intended
  /// to produce a _HTTP 401 Not Found_ status — that behaviour was not
  /// correct. Use [foundResourceDoesNotSupportMethod] instead.

  @Deprecated('use foundResourceDoesNotSupportMethod or resourceExists instead')
  static const int foundNothing = 0;

  /// Value for [found] when the resource exists but has no such HTTP method.
  ///
  /// That is, the URI path matched the pattern in one or more rules. But those
  /// rules were not for the same HTTP method.
  ///
  /// This should result in a HTTP 405 _Method Not Allowed_ status in the
  /// HTTP response (which means "the server knows the request method, but the
  /// target resource doesn't support this method") and MUST include `Allow`
  /// headers indicating which methods are allowed.
  ///
  /// See <https://developer.mozilla.org/en-US/docs/Web/HTTP/Status/405>
  /// for details.

  static const int foundResourceDoesNotSupportMethod = 0;

  /// Value for [found] when at least one handler for the HTTP method
  /// was found, but none of them matched the request path.

  /// This value has been deprecated in woomera 8.0.0. In previous releases,
  /// it was implemented incorrect. THis value was used when there existed
  /// one or more rules that matched the HTTP method (but could be for any
  /// pattern). It was intended for a _HTTP 401 Not Found_ status;
  /// as opposed to _foundNothing_ which was intended to produce a
  /// _HTTP 405 Method Not Found_ status — that behaviour was not correct.
  /// Use [foundNoResource] instead.

  @Deprecated('use foundNoResource instead')
  static const int foundMethod = 1;

  /// Value for [found] when the resource does not exist.
  ///
  /// That is, there are no rules with a pattern that matches the URI path.
  ///
  /// This should result in a _HTTP 401 Not Found_ status in the HTTP
  /// response.

  static const int foundNoResource = 1;

  /// Value for [found] when a handler was found, but no result was produced.
  ///
  /// That is, one or more rules exist where its pattern matches the URI path
  /// and the HTTP methods are the same. But all of those _request handler_
  /// functions did not produce a response.
  ///
  /// This should result in a _HTTP 401 Not Found_ status in the HTTP response.
  /// But, unlike [foundNoResource], this value probably indicates an
  /// incomplete implementation or a bug. Since it is expected that a
  /// matching _request handler_ should produce a response.

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
  /// the resource exists but does not support the HTTP method (when its value
  /// is [NotFoundException.foundResourceDoesNotSupportMethod] when
  /// a _HTTP 405 Method Not Allow_ status ([HttpStatus.methodNotAllowed])
  /// should be produced.
  ///
  /// All other values should produce a _HTTP 404 Not Found_ status
  /// [HttpStatus.notFound]. But their different values may indicate exactly
  /// why the resource was not found. Specifically,
  ///
  /// - [foundNoResource] normal situation;
  /// - [foundHandler] may indicate an incomplete implementation or a bug; or
  /// - [foundStaticHandler] may indicate a missing file or directory
  ///
  /// It is recommended to use [resourceExists] instead of examining
  /// this member directly.
  ///
  /// Historical note: this is an integer and not an enum.
  /// Because when woomera was first written in Dart 1.x, Dart did not
  /// support enums. It was a very long time ago!

  final int found;

  /// Indicates if the resource exists, even though the response was not found.
  ///
  /// Example:
  ///
  /// ```dart
  /// } on NotFoundException catch (ex) {
  ///   if (! ex.resourceExists) {
  ///     response.status = HttpStatus.notFound; // HTTP 404
  ///     ...
  ///   } else {
  ///     response.status = HttpStatus.methodNotAllowed; // HTTP 405
  ///     ...
  ///     // Set Allow header in response.
  ///     // See <https://developer.mozilla.org/en-US/docs/Web/HTTP/Status/405>
  ///   }
  ///   ...
  /// }
  /// ```

  bool get resourceExists => found == foundResourceDoesNotSupportMethod;

  /// String representation
  @override
  String toString() {
    var s = 'unknown';
    switch (found) {
      case foundResourceDoesNotSupportMethod:
        s = 'method not supported';
        break;
      case foundNoResource:
        s = 'resource not found';
        break;
      case foundHandler:
        s = 'no response';
        break;
      case foundStaticHandler:
        s = 'static resource not found';
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
