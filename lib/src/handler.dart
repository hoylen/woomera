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

typedef Future<Response> RequestHandler(Request req);

//----------------------------------------------------------------

/// Exception handler function type.
///
/// Create server exception handler or pipeline exception
/// handlers matching this type.

typedef Future<Response> ExceptionHandler(
    Request req, Object ex, StackTrace st);

//----------------------------------------------------------------

/// Invoke the handler making sure all exceptions are captured.
///
Future<Response> _invokeRequestHandler(
    RequestHandler handler, Request req) async {
  var result;
  var exception;
  // var stacktrace;

  var hCompleter = new Completer();

  // Invoke the handler in its own zone, so all exceptions are captured
  // (both those thrown from async methods and those thrown from methods
  // that don't use async). Must use zones, since a simple try/catch
  // would only catch exceptions thrown from async methods.

  runZoned(() async {
    result = await handler(req); // call the handler

    hCompleter.complete();
  }, onError: (e, s) {
    exception = e;
    // stacktrace = s;
    hCompleter.complete(e);
  });

  // Wait for invocation to finish

  await hCompleter.future;

  // Return result or throw the exception

  if (exception != null) {
    throw exception;
  }
  return result; // which could be null
}

//----------------------------------------------------------------

/// Invoke the handler making sure all exceptions are captured.
///
Future<Response> _invokeExceptionHandler(
    ExceptionHandler eh, Request req, Object ex, StackTrace st) async {
  var result;
  var exception;
  // var stacktrace;

  var hCompleter = new Completer();

  // Invoke the handler in its own zone, so all exceptions are captured
  // (both those thrown from async methods and those thrown from methods
  // that don't use async). Must use zones, since a simple try/catch
  // would only catch exceptions thrown from async methods.

  runZoned(() async {
    result = await eh(req, ex, st); // call the exception handler

    hCompleter.complete();
  }, onError: (e, s) {
    exception = e;
    // stacktrace = s;
    hCompleter.complete(e);
  });

  // Wait for invocation to finish

  await hCompleter.future;

  // Return result or throw the exception

  if (exception != null) {
    throw exception;
  }
  return result; // which could be null
}
