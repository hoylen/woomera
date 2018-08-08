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

/// Exception/error handler function type.
///
/// Define server exception handlers or pipeline exception
/// handlers matching this type.
///
/// The [ex] is `Object` because these methods are expected to handle anything
/// that can be thrown or raised in Dart. This includes `Error` and `Exception`,
/// but can be any type of object.
///
/// Used for [Server.exceptionHandler] and [ServerPipeline.exceptionHandler].

typedef Future<Response> ExceptionHandler(Request r, Object ex, StackTrace st);

//----------------------------------------------------------------

/// Invoke the handler making sure all exceptions are captured.
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

/// Invoke the handler making sure all exceptions are captured.
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
