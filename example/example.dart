/// Woomera demonstration Web Server.
///
/// This program runs a Web server to demonstrate the basic features of the
/// Woomera framework.
///
/// This program runs a single HTTP Web server (on port 1024).
///
/// Copyright (c) 2019, 2021, Hoylen Sue. All rights reserved. Use of this
/// source code is governed by a BSD-style license that can be found in the
/// LICENSE file.
//----------------------------------------------------------------

import 'dart:async';
import 'dart:convert' show json;
import 'dart:io' show ContentType, HttpStatus, InternetAddress, HttpRequest;

import 'package:logging/logging.dart';

import 'package:woomera/woomera.dart';

//================================================================
// Global constants

// Port server will listen on

const int port = 1024;

// Internal paths for the different resources that process HTTP GET and POST
// requests.
//
// Woomera uses internal paths, which are strings that always start with "~/".
// They need to be converted into real URLs when they are served to clients
// (e.g. when included as hyperlinks on HTML pages), by calling "rewriteURL".
//
// Constants are used for these so that the same value is used throughout the
// application if the values are changed (i.e. so the link URL always matches
// the path to the handler).
//
// The various parameter names are also defined as constants, so the same value
// is used in both the URL/form and when it is processed.

// For the general example showing path parameters

const String testPattern = '~/example/:foo/:bar/baz';
//const String _uParamFoo = 'foo';
//const String _uParamBar = 'bar';
//const testPattern2 = '~/example/:$_uParamFoo/:$_uParamBar/baz';

// For the POST request example

const String iPathFormHandler = '~/welcome';
const String _pParamName = 'personName';

// For the exception throwing example

const String iPathExceptionGenerator = '~/throw-exception';
const String _qParamProcessedBy = 'for';

//================================================================
// Globals

/// Application logger.

Logger log = Logger('app');
Logger simLog = Logger('simulation');

//================================================================
// Exceptions

enum HandledBy {
  pipelineExceptionHandler,
  serverExceptionHandler,
  defaultServerExceptionHandler
}

/// Exception that is thrown by [requestHandlerThatAlwaysThrowsException].
///
/// This is used to demonstrate how exceptions are processed by the
/// _pipeline exception handler_ and _server exception handler_.

class DemoException implements Exception {
  DemoException(this.handledBy);

  final HandledBy handledBy;
}

//================================================================
// Handlers
//
// These handlers are used for processing HTTP requests. They are all methods
// that take a [Request] and produces a future to a [Response].
//
// When setting up the server (in [_serverSetup]), rules are created to
// associate these handler methods with paths. The server uses the rules to
// handle the HTTP requests.

//----------------------------------------------------------------
/// Home page

@Handles.get('~/')
Future<Response> homePage(Request req) async {
  assert(req.method == 'GET');

  // The response can be built up by calling [write] multiple times on the
  // ResponseBuffered object. But for this simple page, the whole page is
  // produced with a single write.

  // Note the use of "req.ura" to convert an internal path (a string that starts
  // with "~/") into a URL, and to encode that URL so it is suitable for
  // inclusion in a HTML attribute. The method "ura" is a short way of using
  // `HEsc.attr(req.rewriteUrl(...))`.

  final resp = ResponseBuffered(ContentType.html)..write('''
<!DOCTYPE html>
<html lang="en">
<head>
      <title>Example</title>
</head>

<body>
      <header>
        <h1>Example</h1>
      </header>

      <h2>Request handlers</h2>
      
      <p>The framework finds a <em>request handler</em> to process the HTTP
      request. A match is found if the HTTP method is the same and the request
      URL's path matches the pattern.
      When a match is found, any path parameters (as defined by the pattern),
      query parameters and POST parameters are passed to the request handler.</p>
      
      <p>In the first two sets of links, this pattern will be matched:
       <code>${HEsc.text(testPattern)}</code></p>
       
      <ul>
        <li>
          Examples with path parameters:    
          <a href="${req.ura('~/example/first/second/baz')}">1</a>
          <a href="${req.ura('~/example/alpha/beta/baz')}">2</a>
          <a href="${req.ura('~/example/barComponentIsEmpty//baz')}">3</a>
        </li>
        <li>
          Example with query parameters:
          <a href="${req.ura('~/example/a/b/baz?alpha=1&beta=two&gamma=three')}">1</a>
          <a href="${req.ura('~/example/a/b/baz?delta=query++parameters&delta=are&delta=repeatable')}">2</a>
          <a href="${req.ura('~/example/a/b/baz?emptyString=')}">3</a>
        </li>
        <li>
          Example with form parameters:
          <form method="POST" action="${req.ura(iPathFormHandler)}">
            <input type="text" name="${HEsc.attr(_pParamName)}">
            <input type="submit">
          </form>
        </li>
      </ul>
    
      
      <h2>Exception handling</h2>
      
      <h3>Not found exceptions</h3>
      
      <p>If a <em>request handler</em> cannot be found, the framework throws a
      <em>NotFoundException</em>, which triggers the
      <em>server exception handler</em>.</p>
    
      <ul>
        <li><a href="${req.ura('~/no/such/page')}">
           Does not match any pattern</a></li>
         <li><a href="${req.ura('~/example/first/second/noMatch')}">
           A partial match is still not a match</a></li>
      </ul>
        
      <p>A <em>server exception handler</em> is defined using the
      <code>@Handles.serverException()</code>
      annotation on an <code>ExceptionHandler</code> function.</p>
      
      <h3>Other exceptions</h3>
      
      <p>If the <em>request handler</em> throws an exception, it triggers the
      <em>pipeline exception handler</em> from the pipeline the request
      handler was on. If there is no pipeline exception handler, or it also
      throws an exception, the <em>server exception handler</em> is
      triggered.</p>
      
      <ul>
        <li>
          <a href="${req.ura(iPathExceptionGenerator)}">Case 1</a>:
          Exception thrown by the request handler. It is processed by the
          pipeline exception handler.
        </li>
       <li>
          <a href="${req.ura('$iPathExceptionGenerator?$_qParamProcessedBy=server')}">
          Case 2</a>:
          Exception thrown by the request handler. It is processed by the
          pipeline exception handler, but it throws an exception. That second
          exception is processed by the server pipeline exception handler.
        </li>
        <li>
          <a href="${req.ura('$iPathExceptionGenerator?$_qParamProcessedBy=defaultServer')}">
          Case 3</a>:
          Exception thrown by the request handler. It is processed by the
          pipeline exception handler, but it throws an exception. That second
          exception is processed by the server exception handler, but it
          throws an exception. That third exception causes the built-in
          default server exception handler to run.
        </li>
      </ul>
      
      <p>A <em>pipeline exception handler</em> is defined using the
      <code>@Handles.exception()</code> annotation on an
      <code>ExceptionHandler</code> function. A <em>server exception handler</em>
      is defined using a <code>@Handles.serverException()</code> annotation
      on an <code>ExceptionHandler()</code> function.
      
      <p>There is also a <em>server raw exception handler</em> which is
      triggered in edge-case situations, when the normal server or
      pipeline exception handlers cannot be used. It is defined
      using the <code>@Handles.rawServerException()</code> annotation on an
      <code>ExceptionHandlerRaw</code> function. This example does not
      demonstrate the raw exception handler, since it is not easy to
      trigger it.</p>
      
      <h2>Other features</h2>

          <ul>
            <li>Request handler that produces a response from a stream:
              <a href="${req.ura('~/stream')}">no delay</a>,
              <a href="${req.ura('~/stream?milliseconds=200')}">with delay</a></li>
            <li><a href="${req.ura('~/json')}">JSON response instead of HTML</a></li>
          </ul>
      

      <footer>
        <p style="font-size: small">Demo of the
        <a style="text-decoration: none; color: inherit;"
           href="https://pub.dartlang.org/packages/woomera">Woomera Dart Package</a>
        </p>
      </footer>
</body>
</html>
''');

  // Note: the default status is HTTP 200 "OK", so it doesn't need to be changed

  return resp;
}

//----------------------------------------------------------------
/// Request handler that displays the parameters.
///
/// The [debugHandler] is a request handler that simply displays out all the
/// request parameters on the HTML page that is returned.

@Handles.get(testPattern)
Future<Response> myDebugHandler(Request req) async => debugHandler(req);

//----------------------------------------------------------------
/// Example request handler for a POST request
///
/// This handles the POST request when the form is submitted.

@Handles.post(iPathFormHandler)
Future<Response> dateCalcPostHandler(Request req) async {
  assert(req.method == 'POST');

  // Get the input values from the form
  //
  // HTTP requests with MIME type of "application/x-www-form-urlencoded"
  // (e.g. from a HTTP POST request for a HTML form) will populate the request's
  // postParams member.

  final pParams = req.postParams;

  if (pParams != null) {
    // The input values can be retrieved as strings from postParams.

    var name = pParams[_pParamName];

    // The list access operator on postParams (pathParams and queryParams too)
    // cleans up values by collapsing multiple whitespaces into a single space,
    // and trimming whitespace from both ends. It always returns a string value
    // (i.e. it never returns null), so it returns an empty string if the value
    // does not exist. To tell the difference between a missing value and a value
    // that is the empty string (or only contains whitespace), use the
    // [RequestParams.values] method instead of the list access operator.
    // That [RequestParams.values] method can also be used to obtain the actual
    // value without any whitespace processing.

    assert(pParams['np'] == '');
    assert(pParams.values('np', mode: ParamsMode.standard).isEmpty);
    assert(pParams.values('np', mode: ParamsMode.rawLines).isEmpty);
    assert(pParams.values('np', mode: ParamsMode.raw).isEmpty);

    // Produce the response

    if (name.isEmpty) {
      name = 'world'; // default value if no name was provided
    }

    // Produce the response

    // Note: values that cannot be trusted should be escaped, in case they
    // contain reserved characters or malicious text. Text in HTML content can
    // be escaped by calling `HEsc.text`. Text in attributes can be escaped by
    // calling `HEsc.attr` (e.g. "... <a title="${HEsc.attr(value)} href=...").

    final resp = ResponseBuffered(ContentType.html)..write('''
<!DOCTYPE html>
<html lang="en">
<head>
  <title>Welcome</title>
</head>

<body>
  <header>
    <h1>Welcome</h1>
  </header>
    
  <p>Hello ${HEsc.text(name)}</p>

  <p><a href="${req.ura('~/')}">Home</a></p>
</body>
</html>
''');

    return resp;
  } else {
    // POST request did not contain POST parameters
    throw const FormatException('Invalid request');
  }
}

//----------------------------------------------------------------
/// Request handler that generates an exception.
///
/// This is used to demonstrate the different exception handlers.

@Handles.get(iPathExceptionGenerator)
Future<Response> requestHandlerThatAlwaysThrowsException(Request req) async {
  final value = req.queryParams[_qParamProcessedBy];

  switch (value) {
    case '':
    case 'pipeline':
      throw DemoException(HandledBy.pipelineExceptionHandler);
    case 'server':
      throw DemoException(HandledBy.serverExceptionHandler);
    case 'defaultServer':
      throw DemoException(HandledBy.defaultServerExceptionHandler);
    default:
      throw FormatException('unsupported value: $value');
  }
}

//----------------------------------------------------------------
/// Example of a request handler that uses a stream to generate the response.
///
/// This is an example of using a [ResponseStream] to progressively
/// create the response, instead of using [ResponseBuffered]. The other class
/// used to create a [Response] is [ResponseRedirect] when the response is
/// a HTTP redirection.

@Handles.get('~/stream')
Future<Response> streamTest(Request req) async {
  // Get parameters

  final numIterations = 10;

  var secs = 0;
  if (req.queryParams['milliseconds'].isNotEmpty) {
    secs = int.parse(req.queryParams['milliseconds']);
  }

  // Produce the stream response

  final resp = ResponseStream(ContentType.text)..status = HttpStatus.ok;
  await resp.addStream(req, _streamSource(req, numIterations, secs));

  return resp;
}

//----------------
// The stream that produces the data making up the response.
//
// It produces a stream of bytes (List<int>) that make up the contents of
// the response.
//
// The content produces [iterations] lines of output, each waiting [ms]
// milliseconds before outputting it.

Stream<List<int>> _streamSource(Request req, int iterations, int ms) async* {
  final delay = Duration(milliseconds: ms);

  yield 'Stream of $iterations items (delay: $ms milliseconds)\n'.codeUnits;

  yield 'Started: ${DateTime.now()}\n'.codeUnits;

  for (var x = 1; x <= iterations; x++) {
    final completer = Completer<int>();
    Timer(delay, () => completer.complete(0));
    await completer.future;

    yield 'Item $x\n'.codeUnits;
  }
  yield 'Finished: ${DateTime.now()}\n'.codeUnits;
}

//----------------------------------------------------------------
/// Handler that returns JSON in the response.

@Handles.get('~/json')
Future<Response> handleJson(Request req) async {
  final data = {'name': 'John Citizen', 'number': 6};

  final resp = ResponseBuffered(ContentType.json)..write(json.encode(data));
  return resp;
}

//================================================================
// Exception handlers
//
// Woomera will invoke these methods if an exception was raised when processing
// a HTTP request.

//----------------------------------------------------------------
/// Exception handler used on the pipeline.
///
/// This will handle all exceptions raised by the application's request
/// handlers.

@Handles.pipelineExceptions()
Future<Response> pipelineExceptionHandler(
    Request req, Object exception, StackTrace? st) async {
  log
    ..warning(
        'pipeline exception handler: ${exception.runtimeType}: $exception')
    ..finest('stack trace: $st');

  if (exception is DemoException) {
    if (exception.handledBy != HandledBy.pipelineExceptionHandler) {
      // Throw an exception. This will trigger the server exception handler
      // (if there is one) to process it.
      throw StateError('throw something');
    }
  }

  final resp = ResponseBuffered(ContentType.html)
    ..status = HttpStatus.internalServerError
    ..write('''
<!DOCTYPE html>
<html lang="en">
<head>
  <title>Error</title>
</head>
<body>
  <h1 style="color: red">Exception thrown</h1>

  <p style='font-size: small'>This error page was produced by the
  <strong>pipeline</strong> exception handler.
  See logs for details.</p>

  <a href="${req.ura('~/')}">Home</a>
</body>
</html>
''');

  return resp;
}

//----------------------------------------------------------------
/// Exception handler used on the server.
///
/// This will handle all exceptions raised outside the application's request
/// handlers, as well as if exceptions raised by the pipeline exception
/// handler.
///
/// Note: if there is no match a [NotFoundException] exception is raised for
/// this exception handler to process (i.e. generate a 404/405 error page for
/// the client).

@Handles.exceptions()
Future<Response> serverExceptionHandler(
    Request req, Object exception, StackTrace? st) async {
  log
    ..warning('server exception handler: ${exception.runtimeType}: $exception')
    ..finest('stack trace: $st');

  if (exception is ExceptionHandlerException) {
    final originalException = exception.previousException;

    assert(exception.exception is StateError);

    if (originalException is DemoException) {
      if (originalException.handledBy != HandledBy.serverExceptionHandler) {
        // Throw an exception. This will trigger the server raw exception handler
        // (if there is one) to process it.
        throw originalException;
      }
    }
  }

  // Create a response

  final resp = ResponseBuffered(ContentType.html);

  // Set the status depending on the type of exception

  String message;
  if (exception is NotFoundException) {
    // A server exception handler gets this exception when no request handler
    // was found to process the request. HTTP has two different status codes
    // for this, depending on if the server supports the HTTP method or not.
    resp.status = (exception.found == NotFoundException.foundNothing)
        ? HttpStatus.methodNotAllowed
        : HttpStatus.notFound;
    message = 'Page not found';
  } else if (exception is ExceptionHandlerException) {
    // A server exception handler gets this exception if a pipeline exception
    // handler threw an exception (while it was trying to handle an exception
    // thrown by a request handler).
    resp.status = HttpStatus.badRequest;
    message = 'Pipeline exception handler threw an exception';
  } else {
    // A server exception handler gets all the exceptions thrown by a request
    // handler, if there was no pipeline exception handler.
    resp.status = HttpStatus.internalServerError;
    message = 'Internal error: unexpected exception';
  }

  resp.write('''
<!DOCTYPE html>
<html lang="en">
<head>
  <title>Exception</title>
</head>
<body>
  <h1 style="color: red">${HEsc.text(message)}</h1>

  <p style='font-size: small'>This error page was produced by the
  <strong>server</strong> exception handler.
  See logs for details.</p>

  <a href="${req.ura('~/')}">Home</a>
</body>
</html>
''');

  return resp;

  // If the server error handler raises an exception, a very basic error
  // response is sent back to the client. This situation should be avoided
  // (because that error page is very ugly and not user friendly) by making sure
  // the application's server exception handler never raises an exception.
}

//----------------------------------------------------------------
/// This is an example of a server raw exception handler.
///
/// But in this simple example, there is no way to invoke it. Raw exception
/// handlers are triggered in very rare situations.

@Handles.rawExceptions()
Future<void> myLowLevelExceptionHandler(
    HttpRequest rawRequest, String requestId, Object ex, StackTrace st) async {
  simLog.severe('[$requestId] raw exception (${ex.runtimeType}): $ex\n$st');

  final resp = rawRequest.response
    ..statusCode = HttpStatus.internalServerError
    ..headers.contentType = ContentType.html
    ..write('''<!DOCTYPE html>
<html lang="en">
<head><title>Error</title></head>
<body>
  <h1>Error</h1>
  <p>Something went wrong.</p>
  
  <p style='font-size: small'>This error page was produced by the
  server <strong>raw</strong> exception handler.
  See logs for details.</p>
</body>
</html>
''');

  await resp.close();
}

//================================================================
// Simulated testing

//----------------------------------------------------------------
/// Uses the simulation features in Woomera to invoke the request handlers.
///
/// This is used for testing the server.
///
/// Run this program with the "-t" option to use this function, instead of
/// running a real server.
///
/// This function has been designed to exercise all the features of this
/// example program. So it can be used to perform coverage testing.

Future simulatedRun(Server server) async {
  simLog.info('started');

  {
    // Simulate a GET request to retrieve the home page

    simLog.info('GET home page');

    final req = Request.simulatedGet('~/');
    final resp = await server.simulate(req);
    simLog.info('home page content-type: ${resp.contentType}');
    assert(resp.status == HttpStatus.ok);
    assert(resp.contentType == ContentType.html);
    simLog.finer('home page body:\n${resp.bodyStr}');
  }

  {
    // Simulate a GET request to retrieve the example pattern page

    simLog.info('GET example page');

    final req = Request.simulatedGet('~/example/foo/bar/baz');
    final resp = await server.simulate(req);
    simLog.info('example page content-type: ${resp.contentType}');
    assert(resp.status == HttpStatus.ok);
    assert(resp.contentType == ContentType.text);
    simLog.finer('example page body:\n${resp.bodyStr}');
  }

  {
    // Simulate a POST request from submitting the form

    simLog.info('POST form');

    final postParams = RequestParamsMutable()..add(_pParamName, 'test process');

    final req = Request.simulatedPost(iPathFormHandler, postParams);
    final resp = await server.simulate(req);
    assert(resp.status == HttpStatus.ok);

    final str = resp.bodyStr;
    simLog.finer('form response body:\n$str');
    assert(str.contains('Hello test process'));
  }

  {
    // Simulate a GET request that triggers the pipeline exception handler.

    simLog.info('GET: pipeline exception handler');

    final req = Request.simulatedGet(iPathExceptionGenerator);

    final resp = await server.simulate(req);
    assert(resp.status == HttpStatus.internalServerError);

    final str = resp.bodyStr;
    simLog.finer('exception body:\n$str');
    assert(str.contains('<strong>pipeline</strong> exception handler'));
  }

  {
    // Simulate a GET request that triggers the server exception handler.

    simLog.info('GET: server exception handler');

    final req = Request.simulatedGet(iPathExceptionGenerator,
        queryParams: RequestParamsMutable()..add(_qParamProcessedBy, 'server'));

    final resp = await server.simulate(req);
    assert(resp.status == HttpStatus.badRequest);

    final str = resp.bodyStr;
    simLog.finer('exception body:\n$str');
    assert(str.contains('<strong>server</strong> exception handler'));
  }

  {
    // Simulate a GET request that triggers the default server exception handler

    simLog.info('GET: default server exception handler');

    final req = Request.simulatedGet(iPathExceptionGenerator,
        queryParams: RequestParamsMutable()
          ..add(_qParamProcessedBy, 'defaultServer'));

    final resp = await server.simulate(req);
    assert(resp.status == HttpStatus.internalServerError);
    simLog.finer('exception body:\n${resp.bodyStr}');
  }

  {
    // Simulate a GET request for a page that doesn't exist

    simLog.info('GET non-existent page');

    final req = Request.simulatedGet('~/no/such/page', id: 'noSuchUrl');
    final resp = await server.simulate(req);
    assert(resp.status == HttpStatus.notFound); // 404
  }

  {
    // Simulate a GET where the response is produced as a stream

    simLog.info('GET stream');

    final req = Request.simulatedGet('~/stream',
        queryParams: RequestParamsMutable()..add('milliseconds', '100'));
    final resp = await server.simulate(req);
    assert(resp.status == HttpStatus.ok);
    assert(resp.contentType == ContentType.text);

    final str = resp.bodyStr;
    simLog.fine('stream body:\n$str');
    assert(str.contains('Started:'));
    assert(str.contains('Finished:'));
  }

  {
    // Simulate a GET where the response is JSON

    simLog.info('GET json');

    final req = Request.simulatedGet('~/json');
    final resp = await server.simulate(req);
    assert(resp.status == HttpStatus.ok);
    assert(resp.contentType == ContentType.json);

    final str = resp.bodyStr;
    simLog.finer('JSON body:\n$str');
    // ignore: avoid_as
    final j = json.decode(str) as Object;
    if (j is Map<String, dynamic>) {
      assert(j.containsKey('name'));
      assert(j.containsKey('number'));
      assert(j['name'] is String);
      assert(j['number'] is int);
    } else {
      simLog.severe('JSON body: type is ${j.runtimeType}');
      assert(false);
    }
  }

  simLog.info('finished');
}

//================================================================
// Top level methods

//----------------------------------------------------------------
/// Setup the server.
///
/// Creates a server and registers request and exception handlers for it.

Server _serverSetup() {
  //--------
  // Create a new Web server
  //
  // The bind address is setup to listen to any incoming connection from any IP
  // address (IPv4 or IPv6). If this is not done, by default it only listens
  // on the IPv4 loopback interface, which is good for deployment behind a
  // reverse Web proxy, but might be restrictive for testing.
  //
  // Since the Server constructor is not passed any pipeline names, by default
  // it creates one pipeline with the default name. Request handlers and
  // exception handlers are set up via the [Handles] annotations.

  final webServer = serverFromAnnotations()
    ..bindAddress = InternetAddress.anyIPv6
    ..v6Only = false // false = listen to any IPv4 and any IPv6 address
    ..bindPort = port;

  log.info('Web server running on port $port');

  return webServer;
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

  Logger('app').level = commonLevel;
  Logger('simulation').level = commonLevel;

  Logger('woomera.server').level = commonLevel;
  Logger('woomera.request').level = Level.FINE; // FINE prints each URL
  Logger('woomera.request.header').level = commonLevel;
  Logger('woomera.request.param').level = commonLevel;
  Logger('woomera.response').level = commonLevel;
  Logger('woomera.session').level = commonLevel;

  // To see the Handles annotations that have been found, set this to
  // FINE. Set it to FINER for more details. Set it to FINEST to see what
  // files and/or libraries were scanned and not scanned for annotations.
  Logger('woomera.handles').level = commonLevel;
}

//----------------------------------------------------------------
/// Main

Future main(List<String> args) async {
  final testMode = args.contains('-t'); // test mode
  final quietMode = args.contains('-q'); // quiet mode

  if (!quietMode) {
    _loggingSetup();
  }

  // Create the server and either test it or run it

  final server = _serverSetup();

  if (testMode) {
    await simulatedRun(server); // run simulation for testing
  } else {
    await server.run(); // run Web server
    // Unless the server's [stop] method is invoked, the server will run
    // forever, listening for requests, so normally execution never gets here.
  }
}
