part of woomera;

//----------------------------------------------------------------

/// HTTP request handler function type.
///
/// Methods of this type are used as the handler that is invoked when a
/// rule's pattern matches the request.
///
/// If the future returns a response, processing stops and that response is
/// used to produce the HTTP response. If the future returns null, the search
/// continues for another matching rule.
///
/// Used for in the rules of a [ServerPipeline].

typedef Future<Response> RequestHandler(Request req);

//----------------------------------------------------------------

/// Exception handler for high-level situations.
///
/// These high-level situations usually occur because a server exception
/// handler or pipeline exception handler raised an exception.
///
/// Implementations of this function type are used for setting the
/// [Server.exceptionHandler] and [ServerPipeline.exceptionHandler].
///
/// The implementation must return a Future to a Woomera [Response], which
/// should be an error page for the HTTP response.
///
/// The exception [exception] can be used to detect certain conditions and
/// customize the message in the response.
///
/// In addition to the exception, the stack trace [stackTrace] can provide
/// additional information about the problem. But exposing
/// internal implementation details in the response is not recommended.
///
/// Example:
/// ```
/// Future<Response> myExceptionHandler(Request request,
///  Object e, StackTrace st) async {
///   final r = new ResponseBuffered(ContentType.html);
///    r.status = HttpStatus.internalServerError;
///    r.write('''<!doctype html>
///<html>
///  <head><title>Error</title></head>
///  <body>
///     <h1>Error</h1>
///     <p>Something went wrong.</p>
///  </body>
///</html>
///''');
///    return r;
///}
/// ```

typedef Future<Response> ExceptionHandler(
    Request request, Object exception, StackTrace stackTrace);

//----------------------------------------------------------------
/// Exception handler for low-level situations.
///
/// These exception handlers are only used when the Woomera framework is unable
/// to use an [ExceptionHandler].
///
/// Implementations of this function type are used for setting the
/// [Server.exceptionHandlerRaw].
///
/// The implementation must produce a HTTP response without the aid of the
/// Woomera Response classes. As always, when producing a response using the
/// standard Dart HttpResponse, the "rawRequest.response" must be closed.
///
/// The exception [exception] can be used to detect certain conditions and
/// customize the message in the response.
///
/// In addition to the exception, the stack trace [stackTrace] can provide
/// additional information about the problem. But exposing
/// internal implementation details in the response is not recommended.
/// The [requestId] is an internal identifier assigned to the raw request by
/// Woomera, and is used in log messages produced by Woomera.
///
/// Example:
///
/// ```
/// Future<void> myLowLevelExceptionHandler(HttpRequest rawRequest,
///      String requestId, Object ex, StackTrace st) async {
///    _log.severe('[$requestId] raw exception (${ex.runtimeType}): $ex\n$st');
///
///    final resp = rawRequest.response;
///
///    resp
///      ..statusCode = HttpStatus.internalServerError
///      ..headers.contentType = ContentType.html
///      ..write('''<!doctype html>
///<html>
///<head><title>Error</title></head>
///<body>
///  <h1>Error</h1>
///  <p>Something went wrong.</p>
///</body>
///</html>
///''');
///
///    await resp.close();
///  }
/// ```

typedef Future<void> ExceptionHandlerRaw(HttpRequest rawRequest,
    String requestId, Object exception, StackTrace stackTrace);

//----------------------------------------------------------------

/// Invoke the request handler making sure all exceptions are captured.
///
Future<Response> _invokeRequestHandler(
    RequestHandler handler, Request req) async {
  Object thrownObject; // can be any object, not just Exception or Error
  // var stacktrace;

  final hCompleter = new Completer<Response>();

  // Invoke the handler in its own zone, so all exceptions are captured
  // (both those thrown from async methods and those thrown from methods
  // that don't use async). Must use zones, since a simple try/catch
  // would only catch exceptions thrown from async methods.

  // ignore: UNUSED_LOCAL_VARIABLE
  final doNotWaitOnThis = runZoned(() async {
    final result = await handler(req); // call the handler
    hCompleter.complete(result);
  }, onError: (Object e, StackTrace s) {
    thrownObject = e;
    // stacktrace = s;
    if (!hCompleter.isCompleted) {
      _logRequest.finest("[${req.id}] handler onError (${e.runtimeType}): $e");
      hCompleter.complete(null);
    } else {
      _logRequest
          .finest("[${req.id}] handler onError ignored (${e.runtimeType}): $e");
    }
  });

  // Wait for invocation to finish

  final resp = await hCompleter.future;

  // Return result or throw the error/exception (which can be of any type)

  if (thrownObject != null) {
    throw thrownObject; // ignore: only_throw_errors
  }
  return resp; // which could be null (i.e. handler could not process request)
}

//----------------------------------------------------------------

/// Invoke the exception handler making sure all exceptions are captured.
///
Future<Response> _invokeExceptionHandler(
    ExceptionHandler eh, Request req, Object ex, StackTrace st) async {
  Object thrownObject; // can be any object, not just Exception or Error
  // var stacktrace;

  final hCompleter = new Completer<Response>();

  // Invoke the handler in its own zone, so all exceptions are captured
  // (both those thrown from async methods and those thrown from methods
  // that don't use async). Must use zones, since a simple try/catch
  // would only catch exceptions thrown from async methods.

  // ignore: UNUSED_LOCAL_VARIABLE
  final doNotWaitOnThis = runZoned(() async {
    final result = await eh(req, ex, st); // call the exception handler
    hCompleter.complete(result);
  }, onError: (Object e, StackTrace s) {
    thrownObject = e;
    // stacktrace = s;
    hCompleter.complete(null);
  });

  // Wait for invocation to finish

  final resp = await hCompleter.future;

  // Return result or throw the error/exception (which can be of any type)

  if (thrownObject != null) {
    throw thrownObject; // ignore: only_throw_errors
  }
  return resp; // which could be null
}
