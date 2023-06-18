/// Woomera exception handling example.
///
/// This program demonstrates the exception handling features of Woomera.
///
/// Woomera has two key features, when it comes to exception handling:
///
/// 1. It aims to be complete. It tries to handle all exceptions, no matter
///    where or when they are thrown. This includes when they are thrown from
///    your code, from third-party packages that you chose to not catch, from
///    code that is processing another exception, and from Woomera itself.
///    This completeness is valuable when it comes to third-party packages,
///    since they rarely document all the exceptions they can throw, so your
///    server must be able to deal with unexpected exceptions.
///
///  2. It aims to be flexible. It allows you to customise how exceptions are
///     handled. That is the aim of this example, to demonstrate how custom
///     exception handlers can be used.
///
///  3. It aims to be hide exceptions from your server's users. Users should not
///     see internal implementation details on their Web pages. Not only is it
///     unpolished and useless to the user, it could leak internal information.
///     Your custom exception handlers can be used to generate user-friendly
///     error pages.
///
///     Also, the Woomera Response is designed to buffer the HTTP response until
///     it is complete. If that was not done and an exception was raised
///     half-way through generating the response page, the user would see a
///     partial page followed by an error message. There is no way to create
///     a clean error page, since the page has already started. With the Woomera
///     Response and exception handlers, the user always sees either a complete
///     successful page or a complete error page -- no more ugly errors in the
///     middle of a partial page.
///
/// Copyright (c) 2019, Hoylen Sue. All rights reserved. Use of this source code
/// is governed by a BSD-style license that can be found in the LICENSE file.
//----------------------------------------------------------------

import 'dart:async';
import 'dart:io';

import 'package:logging/logging.dart';

import 'package:woomera/woomera.dart';

//================================================================
// Constants

/// Path component for the exception name in the exception generating page.
///
/// This is a constant to ensure the same value is used to register the handle
/// and to lookup the _pathParams_ inside the handler.
///
/// The code could have used the literal strings,
/// "~/first/throws/:nameOfException" as the path and "nameOfException" to look
/// up the path parameter, but the application would break if one was changed
/// and the other wasn't changed to match.

const String nameParam = 'nameOfException';

//================================================================
// Globals

/// Application logger.

Logger log = Logger('exception_example');

//================================================================
// Exceptions

/// Test exception
///
/// The exception generating page will throw this exception.

class TestException implements Exception {
  /// Create an exception.
  TestException(this.name,
      {this.ignoredByPipelineExceptionHandler = false,
      this.ignoredByServerExceptionHandler = false,
      this.ignoredByLowLevelExceptionHandler = false});

  final String name;
  final bool ignoredByPipelineExceptionHandler;
  final bool ignoredByServerExceptionHandler;
  final bool ignoredByLowLevelExceptionHandler;

  @override
  String toString() => 'MyException($name)';
}

//================================================================
// Exception handlers
//
// The main focus of this example is to demonstrate the different types of
// exception handlers that can be created, and when they get used.
//
// Woomera allows these custom exception handlers:
//
// - a high-level exception handler for each pipeline (in this
//   example, there are two pipelines, so there are two pipeline exception
//   handlers);
// - a high-level exception handler for the server; and
// - a low-level exception handler for the server.
//
// A high-level exception handler is passed a Woomera Request and produces a
// Woomera response -- just like a normal Woomera request handler.
//
// A low-level exception handler is passed the Dart HttpRequest. It is used to
// handle exceptions in special situations where a Woomera Request is not
// available.

//----------------------------------------------------------------
/// Exception handler for pipeline1.
///
/// This exception handler is attached to the first pipeline.

Future<Response> exceptionHandlerOnPipe1(
    Request req, Object exception, StackTrace st) async {
  // Simulate the absence of an exception handler, or what happens if this
  // exception handler doesn't handle the exception.

  if (exception is TestException) {
    if (exception.ignoredByPipelineExceptionHandler) {
      // not handled: let a higher-up exception handler handle it
      throw NoResponseProduced();
    }
  }

  // Produce the response

  final resp = ResponseBuffered(ContentType.html)
    ..status = HttpStatus.internalServerError
    ..write(_htmlShowingException('pipeline1', exception, st));

  return resp;
}

//----------------------------------------------------------------
/// Exception handler for pipeline2.
///
/// This exception handler is attached to the second pipeline.
///
/// In this example, it is exactly the same as [exceptionHandlerOnPipe1],
/// except the page prints out "pipeline2" instead of "pipeline1".
///
/// Different pipeline can be used for different purposes, so their exception
/// handlers can be customised for them. For example, maybe one pipeline is used
/// for HTML pages and another used for an API that returns JSON. Their separate
/// exception handlers could produce a HTML error page or a JSON
/// representation of the error, respectively.

Future<Response> exceptionHandlerOnPipe2(
    Request req, Object exception, StackTrace st) async {
  // Simulate the absence of an exception handler, or what happens if this
  // exception handler doesn't handle the exception.

  if (exception is TestException) {
    if (exception.ignoredByPipelineExceptionHandler) {
      // not handled: let a higher-up exception handler handle it
      throw NoResponseProduced();
    }
  }

  // Produce the response

  final resp = ResponseBuffered(ContentType.html)
    ..status = HttpStatus.internalServerError
    ..write(_htmlShowingException('pipeline2', exception, st));

  return resp;
}

//----------------------------------------------------------------
/// Exception handler for the server.
///
/// This exception handler is attached to the [Server] and will
/// be invoked if an exception is raised outside the context
/// of the pipelines (or the pipeline did not process any exceptions
/// raised inside their context).

Future<Response> exceptionHandlerOnServer(
    Request req, Object exception, StackTrace st) async {
  // Simulate the absence of an exception handler, or what happens if this
  // exception handler doesn't handle the exception.

  if (exception is TestException) {
    if (exception.ignoredByServerExceptionHandler) {
      // not handled: let a higher-up exception handler handle it
      throw NoResponseProduced();
    }
  }

  // Determine the HTTP status for the response
  //
  // Unlike the pipeline exception handlers, the server exception handler may
  // get called with the Woomera NotFoundException. That happens when a rule
  // cannot be found for the request. Always use the two special HTTP status
  // values for those situations. For all other exceptions, use a HTTP status
  // appropriate for the application (this example simply uses HTTP 500 for
  // all other exceptions).

  int errorPageStatus;

  if (exception is NotFoundException) {
    errorPageStatus = (exception.found == NotFoundException.foundNothing)
        ? HttpStatus.methodNotAllowed
        : HttpStatus.notFound;
  } else {
    errorPageStatus = HttpStatus.internalServerError;
  }

  // Produce the response

  final resp = ResponseBuffered(ContentType.html)
    ..status = errorPageStatus
    ..write(_htmlShowingException('server', exception, st));

  return resp;
}

//----------------------------------------------------------------

Future<void> lowLevelExceptionHandler(
    HttpRequest req, String requestId, Object exception, StackTrace st) async {
  req.response.statusCode = HttpStatus.internalServerError;
  req.response
      .write(_htmlShowingException('low-level [$requestId]', exception, st));
  // Note: do not close the response. Woomera will do that.
}

//----------------------------------------------------------------
// Common method used to generate the HTML contents of all error pages.

String _htmlShowingException(String who, Object exception, StackTrace st) {
  final buf = StringBuffer('''
<html lang="en">
<head>
  <title>Error</title>
</head>
<body>
<h1 style="color: red">Error</h1>

<p>An exception was thrown and was successfully handled by the
<strong>$who</strong> exception handler, which produced this error page.</p>

<h2>Details</h2>

<p>In a real applcation, these details of the exception should not be exposed
to the user.</p>

<h3>Exception</h3>

<p>Exception object type: <code>${exception.runtimeType}</code></p>
<p>String representation of object: <strong>$exception</strong></p>

<h3>Stack trace</h3>
<pre>
$st
</pre>

<p><a href="/">Home</a></p>

</body>
</html>
''');

  return buf.toString();
}

//================================================================
// Handlers
//
// These handlers are used in the rules that are registered in the pipelines.
//
// In this example, there are only two handlers.

//----------------------------------------------------------------
/// Page that throws an exception.

Future<Response> exceptionThrowingPage(Request req) async {
  final name = req.pathParams[nameParam];

  if (name.isNotEmpty) {
    // Throw an exception

    throw TestException(name, ignoredByLowLevelExceptionHandler: false);
  } else {
    // Show a page

    final resp = ResponseBuffered(ContentType.html)
      ..status = HttpStatus.ok
      ..write('''
<html lang="en">
<head>
<title>Exception thrower</title>
</head>
<body>
<h1>Exception throwing page</h1>
<p>If the path had ended with a value, an exception would have been thrown.</p>
</body>
</html>
  ''');
    return resp;
  }
}

//----------------------------------------------------------------

/// Method that throws an exception some time in the future.
///
Future<ResponseBuffered> oldStyleFuture({bool throwException = false}) {
  const duration = const Duration(seconds: 3);

  final c = Completer<ResponseBuffered>();

  final _ = Timer(duration, () {
    if (throwException) {
      // This exception is thrown from a function that is not using the new
      // async/await syntax. This means it won't be caught by the try/catch
      // mechanism. The framework will catch these using zones.
      throw StateError(DateTime.now().toString());
    }

    final resp = ResponseBuffered(ContentType.text)
      ..status = HttpStatus.notAcceptable
      ..write('This worked, but it should not have.');
    c.complete(resp);
  });

  return c.future;
}

//----------------------------------------------------------------
/// Home page

Future<Response> homePage(Request req) async {
  final resp = ResponseBuffered(ContentType.html)
    ..status = HttpStatus.ok
    ..write('''
<!doctype html>
<html>
<head>
  <title>Woomera Exception demo</title>
</head>

<body>
  <header>
    <h1>Woomera Exception handling demonstration</h1>
  </header>

  <div class="content">
  <h2>Examples</h2>
''');

  var index = 0; // to make each "id" unique

  for (final pageInfo in [
    ['Page on pipeline 1', 'GET', '/first/throw'],
    ['Page on pipeline 2', 'GET', '/second/throw'],
    ['No such page', 'GET', '/unknown']
  ]) {
    final title = pageInfo[0];
    final method = pageInfo[1];
    final path = pageInfo[2];
    index++;

    resp.write('''
  <div class="section">
<h3>$title</h3>

<form method="$method" action="$path">
<p>
<input type="checkbox" name="ignoreByPEH" id="PEH$index">
<label for="PEH$index">Ignored by any pipeline exception handler</label><br>

<input type="checkbox" name="ignoreBySEH" id="SEH$index">
<label for="SEH$index">Ignored by any server exception handler</label><br>

<input type="checkbox" name="ignoreByLOW" id="LOW$index">
<label for="PEH$index">Ignored by any low-level server exception handler</label><br>
</p>
<input type="submit" value="Visit page on pipeline 1">
</form>
</div>
''');
  }

  resp.write('''
  <footer>
    <p><a href="https://pub.dev/packages/woomera">Woomera Dart Package</a></p>
  </footer>
</body>
</html>
''');

  return resp;
}

//================================================================

//----------------------------------------------------------------

Server _serverSetup({int port = 80}) {
  //--------
  // Create a new Web server that listens on any IPv4 and any IPv6 address

  final webServer = Server(numberOfPipelines: 2)
    ..bindAddress = InternetAddress.anyIPv6
    ..v6Only = false // false = listen to any IPv4 and any IPv6 address
    ..bindPort = port;

  log.info('Web server running on port $port');

  webServer.exceptionHandler =
      exceptionHandlerOnServer; // set exception handler

  //--------
  // This example will use two pipelines.
  //
  // Since the number of pipelines was specified to the server's constructor,
  // they have both been created.

  final p1 = webServer.pipelines[0];
  final p2 = webServer.pipelines[1];

  // Setup the request handlers for the pipelines

  p1.get('~/', homePage);
  assert(p1.rules('GET').length == 1);

  p1.get('~/first/throw/:$nameParam', exceptionThrowingPage);

  p2.get('~/second/throw/:$nameParam', exceptionThrowingPage);

  //--------
  // Setup exception handlers
  //
  // This is the main focus of this example: demonstrating the effect of the
  // different custom exception handlers.

  p1.exceptionHandler = exceptionHandlerOnPipe1;

  p2.exceptionHandler = exceptionHandlerOnPipe2;

  //webServer.exceptionHandler = null;

  //webServer.rawExceptionHandler = null;

  return webServer;
}

//================================================================
// Simulated testing

//----------------------------------------------------------------

Future simulatedRun(Server server) async {
  log.fine('GET /test');

  final req = Request.simulated('GET', '~/test', id: 'simulated');

  final r = await server.simulate(req);
  print(r);
}

//================================================================
// Main program

//----------------------------------------------------------------
// Parse arguments

class Options {
  Options.parse(List<String> args) {
    var help = false;

    for (final arg in args) {
      switch (arg) {
        case '-q':
        case '--quiet':
          quietMode = true;
          break;
        case '-s':
        case '--simulate':
          simulateMode = true;
          break;
        case '-h':
        case '--help':
          help = true;
          break;
        default:
          stderr.write('Usage error: unknown option: $arg\n');
          exit(2);
      }
    }

    if (help) {
      print('Usage: exception_example [options]');
      exit(0);
    }
  }

  bool quietMode = false;
  bool simulateMode = false;
}

//----------------------------------------------------------------
// Set up logging
//
// Change this to the level and type of logging desired.

void _loggingSetup() {
  hierarchicalLoggingEnabled = true;
  Logger.root.onRecord.listen((rec) {
    print('${rec.time}: ${rec.loggerName}: ${rec.level.name}: ${rec.message}');
  });

  Logger.root.level = Level.OFF;

  final commonLevel = Level.INFO;

  Logger('main').level = commonLevel;
  Logger('woomera.server').level = commonLevel;
  Logger('woomera.request').level = Level.FINE;
  Logger('woomera.request.header').level = commonLevel;
  Logger('woomera.request.param').level = commonLevel;
  Logger('woomera.response').level = commonLevel;
  Logger('woomera.session').level = commonLevel;
}

//================================================================

Future<void> main(List<String> args) async {
  final options = Options.parse(args);

  if (!options.quietMode) {
    _loggingSetup();
  }

  // Create the Web server and run it

  final server = _serverSetup(port: 1024);

  log.fine('started');

  if (!options.simulateMode) {
    await server.run(); // run Web server
  } else {
    await simulatedRun(server); // run simulation for testing
  }

  // The Future returned by the [run] method never gets completed, unless the
  // server's [stop] method is invoked. Most applications leave the web server
  // running "forever", so normally the server's [stop] method never gets
  // invoked.

  log.fine('finished');
}
