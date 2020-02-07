/// Woomera demonstration Web Server.
///
/// This program runs a Web server to demonstrate the basic features of the
/// Woomera framework.
///
/// This program runs a single HTTP Web server (on port 1024).
///
/// Copyright (c) 2019, Hoylen Sue. All rights reserved. Use of this source code
/// is governed by a BSD-style license that can be found in the LICENSE file.
//----------------------------------------------------------------

import 'dart:async';
import 'dart:convert' show json;
import 'dart:io' show ContentType, HttpStatus, InternetAddress;

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

const String pathFormGet = '~/date-calculator/form';
const String pathFormPost = pathFormGet; // can be a different value too

// Names of the form parameters.
// Constants are used for these so the HTML form inputs uses the same value that
// the form processor expects.

const String _pParamTitle = 'title';
const String _pParamFromDate = 'fromDate';
const String _pParamToDate = 'toDate';

//================================================================
// Globals

/// Application logger.

Logger log = Logger('app');
Logger simLog = Logger('simulation');

//================================================================
// Exceptions

class DemoException1 implements Exception {
  @override
  String toString() => 'wrong order: no title';
}

class DemoException2 implements Exception {
  DemoException2(this.title);
  String title;
  @override
  String toString() => 'wrong order: with title "$title"';
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
<!doctype html>
<html>
<head>
  <title>Example</title>
</head>

<body>
  <header>
    <h1>Example</h1>
  </header>

  <ul>
    <li>
      Example with form parameters:
      <a href="${req.ura(pathFormGet)}">date calculator</a></li>
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
      No match:
      <a href="${req.ura('~/no/such/page')}">1</a>
      <a href="${req.ura('~/example/first/second/noMatch')}">2</a>
    </li>
    <li>
      Other:
      <ul>
        <li>Response from a stream:
          <a href="${req.ura('~/stream')}">no delay</a>,
          <a href="${req.ura('~/stream?milliseconds=200')}">with delay</a></li>
        <li><a href="${req.ura('~/json')}">Response is JSON</a></li>
      </ul>
    </li>

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
// Date calculator form page.
//
// This handles the GET request for the form.

@Handles.get(pathFormGet)
Future<Response> dateCalcGetHandler(Request req) async {
  assert(req.method == 'GET');

  final resp = ResponseBuffered(ContentType.html)..write('''
<!doctype html>
<html>
<head>
  <title>Date calculator</title>
</head>

<body>
  <header>
    <h1>Date calculator</h1>
  </header>

  <form method="POST" action="${req.ura(pathFormPost)}">
    <p>Title: <input name="${HEsc.attr(_pParamTitle)}"/></p>
    
    <p>From
      <input name="${HEsc.attr(_pParamFromDate)}" type="date"/>
      to
      <input name="${HEsc.attr(_pParamToDate)}" type="date"/>
      <input type="submit" value="Calculate number of days"/>
    </p>
  </form>
  
  <p style="font-size: small">Enter a "from" date that is after the "to" date
  to cause the handler to raise an exception. Different exceptions are raised
  if the title is blank or not.</p>
  
  <footer><p><a href="${req.ura('~/')}">Home</a></p></footer>
</body>
</html>
''');

  return resp;
}

//----------------------------------------------------------------
/// Date calculator results page.
///
/// This handles the POST request when the form is submitted.

@Handles.post(pathFormPost)
Future<Response> dateCalcPostHandler(Request req) async {
  assert(req.method == 'POST');

  // Get the form parameters

  // POST requests with MIME type of "application/x-www-form-urlencoded"
  // (e.g. from a normal HTML form) will populate the request's postParams
  assert(req.postParams != null);

  // The form parameters can be retrieved as strings from postParams.

  final title = req.postParams[_pParamTitle];
  final fromStr = req.postParams[_pParamFromDate];
  final toStr = req.postParams[_pParamToDate];

  // The list access operator on postParams (pathParams and queryParams too)
  // cleans up values by collapsing multiple whitespaces into a single space,
  // and trimming whitespace from both ends. It always returns a string value
  // (i.e. it never returns null), so it returns an empty string if the value
  // does not exist. To tell the difference between a missing value and a value
  // that is the empty string (or only contains whitespace), use the
  // [RequestParams.values] method instead of the list access operator.
  // That [RequestParams.values] method can also be used to obtain the actual
  // value without any whitespace processing.

  assert(req.postParams['noSuchParameter'] == '');
  assert(req.postParams.values('noSuchParameter', raw: true).isEmpty);

  try {
    // The form parameters are strings that may need to be converted

    // Note: a good Web application should validate all input, since the input
    // could be invalid or malicious. In this situation, the browser might not
    // support the HTML5 date input and the user could have typed in an invalid
    // value.

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day); // midnight

    final fromDate = (fromStr.isNotEmpty) ? DateTime.parse(fromStr) : today;

    final toDate = (toStr.isNotEmpty) ? DateTime.parse(toStr) : today;

    // Use the form parameters and produce the response

    if (fromDate.isAfter(toDate)) {
      // Normally a handler should deal with the error and produce an
      // appropriate response (e.g. a page with an error message).
      // But in this example, two different exceptions are thrown, to
      // demonstrate the exception handlers being used. Exception handlers
      // allow the Web application to always produce a user friendly response,
      // even if the handler didn't catch all the possible exceptions.
      if (title.isEmpty) {
        throw DemoException1();
      } else {
        throw DemoException2(title);
      }
    }

    final diff = toDate.difference(fromDate);

    // Produce the response

    // Note: values that cannot be trusted should be escaped, in case they
    // contain reserved characters or malicious text. Text in HTML content can
    // be escaped by calling `HEsc.text`. Text in attributes can be escaped by
    // calling `HEsc.attr` (e.g. "... <a title="${HEsc.attr(value)} href=...").

    final resp = ResponseBuffered(ContentType.html)..write('''
<!doctype html>
<html>
<head>
  <title>Date calculator</title>
</head>

<body>
  <header>
    <h1>Date calculator</h1>
  </header>
  
  <h2>${HEsc.text(title)}</h2>
  
  <p>From ${_formatDate(fromDate)} to ${_formatDate(toDate)}: ${diff.inDays} days.</p>

  <p><a href="${req.ura(pathFormGet)}">Back to form</a></p>
</body>
</html>
''');

    return resp;
  } on FormatException {
    // Produce an error response

    return ResponseBuffered(ContentType.html)
      ..status = HttpStatus.badRequest
      ..write('''
 <!doctype html>
<html>
<head>
  <title>Date calculator</title>
</head>

<body>
  <header>
    <h1>Date calculator</h1>
  </header>
  
  <p>Error: invalid date(s) entered</p>

  <p><a href="${req.ura(pathFormGet)}">Back to form</a></p>
</body>
</html>
    ''');
  }
}

String _formatDate(DateTime dt) => dt.toIso8601String().substring(0, 10);

//----------------------------------------------------------------
/// Stream handler
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

@Handles.get('~/example/:foo/:bar/baz')
Future<Response> myDebugHandler(Request req) async => debugHandler(req);

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

Future<Response> pipelineExceptionHandler(
    Request req, Object exception, StackTrace st) async {
  log
    ..warning(
        'pipeline exception handler: ${exception.runtimeType}: $exception')
    ..finest('stack trace: $st');

  if (exception is DemoException1) {
    final h = ResponseBuffered(ContentType.html)
      ..status = HttpStatus.badRequest;

    final message = 'Dates are in the wrong order';
    _produceErrorPage(h, exception, message, 'pipeline', req.rewriteUrl('~/'));

    return h;
  } else {
    // If this pipeline exception handler raises an exception, the server
    // exception handler will get an [ExceptionHandlerException] containing
    // the original exception and the exception that is raised.
    throw StateError('pipeline exception hander raised exception');
  }
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

Future<Response> serverExceptionHandler(
    Request req, Object exception, StackTrace st) async {
  log
    ..warning('server exception handler: ${exception.runtimeType}: $exception')
    ..finest('stack trace: $st');

  // Create a response

  final resp = ResponseBuffered(ContentType.html);

  // Set the status depending on the type of exception

  String message;
  if (exception is NotFoundException) {
    resp.status = (exception.found == NotFoundException.foundNothing)
        ? HttpStatus.methodNotAllowed
        : HttpStatus.notFound;
    message = 'Page not found';
  } else if (exception is ExceptionHandlerException) {
    resp.status = HttpStatus.badRequest;
    message = 'Pipeline exception handler threw an exception';
  } else {
    // Catch all
    resp.status = HttpStatus.internalServerError;
    message = 'Internal error: unexpected exception';
  }

  _produceErrorPage(resp, exception, message, 'server', req.rewriteUrl('~/'));

  return resp;

  // If the server error handler raises an exception, a very basic error
  // response is sent back to the client. This situation should be avoided
  // (because that error page is very ugly and not user friendly) by making sure
  // the application's server exception handler never raises an exception.
}

//----------------------------------------------------------------

void _produceErrorPage(ResponseBuffered resp, Object exception, String message,
    String whichExceptionHandler, String homePageUrl) {
  // Internal information should never be revealed to the client.

  resp.write('''
<!doctype html>
<html>
<head>
  <title>Exception</title>
</head>
<body>
  <h1 style="color: red">${HEsc.text(message)}</h1>

  <p style='font-size: small'>This error page was produced by the
  <strong>${HEsc.text(whichExceptionHandler)}</strong> exception handler.
  See logs for details.</p>

  <a href="${HEsc.attr(homePageUrl)}">Home</a>
</body>
</html>
''');
}

//================================================================
// Simulated testing

//----------------------------------------------------------------
/// Uses the simulation features in Woomera to invoke the request handlers.
///
/// This is used for testing the server.
///
/// Try running this for coverage testing.

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
    // Simulate a GET request to retrieve the form

    simLog.info('GET form');

    var req = Request.simulatedGet(pathFormGet);
    var resp = await server.simulate(req);
    assert(resp.status == HttpStatus.ok);
    simLog.finer('form page body:\n${resp.bodyStr}');
    assert(resp.bodyStr.contains('<form '));
    assert(resp.bodyStr.contains('<input '));

    // Simulate a POST request from submitting the form

    simLog.info('POST form');

    final postParams = RequestParamsMutable()
      ..add(_pParamTitle, 'Testing')
      ..add(_pParamFromDate, '2019-01-01')
      ..add(_pParamToDate, '2019-02-28');

    req = Request.simulatedPost(pathFormPost, postParams);
    resp = await server.simulate(req);
    assert(resp.status == HttpStatus.ok);
    simLog.finer('form response body:\n${resp.bodyStr}');
    assert(resp.bodyStr.contains('58 days'));

    // Simulate a POST request from submitting the form with invalid dates
    // This causes an error that the handler takes care of.

    simLog.info('POST form: exception 0');

    req = Request.simulatedPost(
        pathFormPost,
        RequestParamsMutable()
          ..add(_pParamTitle, 'Testing')
          ..add(_pParamFromDate, 'yesterday')
          ..add(_pParamToDate, 'tomorrow')); // dates that can't be parsed

    resp = await server.simulate(req);
    assert(resp.status == HttpStatus.badRequest);
    simLog.finer('form error body 0:\n${resp.bodyStr}');
    assert(resp.bodyStr.contains('invalid date(s) entered'));

    // Simulate a POST request from submitting the form with invalid values
    // This raises an exception for the pipeline exception handler.

    simLog.info('POST form: exception 1');

    req = Request.simulatedPost(
        pathFormPost,
        RequestParamsMutable()
          ..add(_pParamTitle, '') // no title
          ..add(_pParamFromDate, '2019-12-31')
          ..add(_pParamToDate, '1970-01-01')); // to date before from date error

    resp = await server.simulate(req);
    assert(resp.status == HttpStatus.badRequest);
    simLog.finer('form error body 1:\n${resp.bodyStr}');
    assert(resp.bodyStr.contains('<strong>pipeline</strong>'));

    // Simulate a POST request from submitting the form with invalid values
    // This raises an exception for the server exception handler.

    simLog.info('POST form: exception 2');

    req = Request.simulatedPost(
        pathFormPost,
        RequestParamsMutable()
          ..add(_pParamTitle, 'Testing') // title present
          ..add(_pParamFromDate, '2019-12-31')
          ..add(_pParamToDate, '1970-01-01')); // to date before from date error

    resp = await server.simulate(req);
    assert(resp.status == HttpStatus.badRequest);
    simLog.finer('form error body 2:\n${resp.bodyStr}');
    assert(resp.bodyStr.contains('<strong>server</strong>'));
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
    simLog.fine('stream body:\n${resp.bodyStr}');
    assert(resp.bodyStr.contains('Started:'));
    assert(resp.bodyStr.contains('Finished:'));
  }

  {
    // Simulate a GET where the response is JSON

    simLog.info('GET json');

    final req = Request.simulatedGet('~/json');
    final resp = await server.simulate(req);
    assert(resp.status == HttpStatus.ok);
    assert(resp.contentType == ContentType.json);
    simLog.finer('JSON body:\n${resp.bodyStr}');
    // ignore: avoid_as
    final j = json.decode(resp.bodyStr) as Object;
    assert(j is Map<String, Object>);
    if (j is Map<String, Object>) {
      assert(j.containsKey('name'));
      assert(j.containsKey('number'));
      assert(j['name'] is String);
      assert(j['number'] is int);
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
  // it creates one pipeline with the default name and it automatically
  // registers request handlers that have been annotated with Registration
  // objects.

  final webServer = Server.fromAnnotations()
    ..bindAddress = InternetAddress.anyIPv6
    ..v6Only = false // false = listen to any IPv4 and any IPv6 address
    ..bindPort = port
    ..exceptionHandler = serverExceptionHandler;

  log.info('Web server running on port $port');

  //--------
  // Setup the exception handler for the default pipeline.

  webServer.pipeline(ServerPipeline.defaultName).exceptionHandler =
      pipelineExceptionHandler;

  // The debugHandler is a handler that is provided by Woomera. It prints
  // out all the parameters it receives, and can be used for debugging.

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

  // To see the Registration annotations that have been found, set this to
  // FINE. Set it to FINER for more details. Set it to FINEST to see what
  // files and/or libraries were scanned for Registration annotations.
  Logger('woomera.registration').level = commonLevel;
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
    // forever, listening for requests, so normally execution never gets past
    // this line.
  }
}
