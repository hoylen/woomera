/// Woomera demonstration Web Server.
///
/// This program runs a Web server to demonstrate the features of the Woomera
/// framework.
///
/// This program runs a single HTTP Web server (on port 1024), and has defined
/// two pipelines for processing the HTTP requests.
///
/// Copyright (c) 2016, Hoylen Sue. All rights reserved. Use of this source code
/// is governed by a BSD-style license that can be found in the LICENSE file.
//----------------------------------------------------------------

import 'dart:async';
import 'dart:convert' show json;
import 'dart:io'
    show
        ContentType,
        Cookie,
        HttpStatus,
        InternetAddress,
        FileSystemEntity,
        Platform;

import 'package:logging/logging.dart';

import 'package:woomera/woomera.dart';

//================================================================
// Globals

/// Application logger.

Logger mainLog = Logger('main');

// The Web server and pipelines.
//
// Normally these can be local variables, but they are made global
// so some of the handler functions can access them. They are only
// manipulated for testing purposes: a normal Web application would
// usually not need to manipulate them after they have been setup.

/// Web server
///
late Server webServer;

/// First pipeline
///
late ServerPipeline p1;

/// Second pipeline
///
late ServerPipeline p2;

//================================================================
/// Session for login.
///
/// Extends the [Session] class with the time the login started
/// and the user name.
///
class LoginSession extends Session {
  /// Constructor for a login session.

  LoginSession(Server server, Duration timeout, this.when, [this.name])
      : super(server, timeout);

  /// When the login started

  DateTime when;

  /// The name of the user logged in.
  ///
  /// Can be null.

  String? name;
}

//================================================================
// Handlers
//
// These handlers are used in the rules that are registered in the pipelines
// (see the [main] method at the end this file).

//----------------------------------------------------------------
/// Common HTML code for the "home" button that appears on many pages.

String homeButton(Request req) =>
    "<p><a href='${req.rewriteUrl("~/")}' style='font-size: large; text-decoration: none;'>&#x21A9;</a></p>";

//----------------------------------------------------------------
/// Home page
///
/// Main page for the demonstration Web server.

Future<Response> homePage(Request req) async {
  final resp = ResponseBuffered(ContentType.html)
    ..write("""
<!doctype html>
<html>
<head>
  <title>Woomera demo</title>
  <link rel="stylesheet" href="diskfiles/style/site.css">
</head>

<body>
  <header>
    <h1>Woomera demonstration</h1>
  </header>

  <div class="content">

  <div class="section">
    <h2>Request parameters</h2>

    <p>Three types of parameters can be passed to handlers.</p>

    <table class="main">
      <tbody>
        <tr>
          <td>Path parameters</td>
          <td>
            <p>Matching to pattern with <a href="/must/all/match">no path parameters</a></p>
            <p>Matching <a href="/two/hello/world">/two/hello/world</a> to <code>/two/:first/:second</code></p>
            <p>Matching <a href="/wildcard1/a/b/c">/wildcard1/a/b/c</a> to <code>/wildcard1/*</code></p>
          </td>
        <tr>
          <td>Query parameters</td>
          <td>
            <p><a href="/test?foo=bar">?foo=bar</a></p>
            <p><a href="/test?greeting=hello&name=world">?greeting=hello&name=world</a></p>
            <p><a href="/test?p=query&p=parameters&p=can+be&p=repeated">?p=query&p=parameters&p=can+be&p=repeated</a></p>
            <p><a href="/test?note=Unicode+is+supported&value=안녕하세요+세계&value=hello+world">?note=Unicode+is+supported&value=안녕하세요+세계&value=hello+world</a></p>
          </td>
        </tr>
        <tr>
          <td>POST parameters</td>
          <td>
            <p>
            <form method="POST" action="/test">
            <input type="text" name="foo"/>
            &nbsp;
            <input type="radio" name="r" id="r-A" value="A"/><label for="r-A">A</label>
            <input type="radio" name="r" id="r-B" value="B"/><label for="r-B">B</label>
            <input type="radio" name="r" id="r-C" value="C"/><label for="r-C">C</label>
            &nbsp;
            <input type="checkbox" id="chk-a" name="chk-a" value="α"/><label for="chk-a">α</label>
            <input type="checkbox" id="chk-b" name="chk-b" value="β"/><label for="chk-b">β</label>
            <input type="checkbox" id="chk-c" name="chk-c" value="γ"/><label for="chk-c">γ</label>
            &nbsp;
            <input type="submit" value="Submit"/>
            </form>
            </p>
          </td>
        </tr>
      </tbody>
    </table>
  </div>

  <div class="section">
    <h2>Pattern matching of path parameters</h2>
  
    <p>More examples of path parameter matching.</p>
  
    <table class="main">
      <thead>
        <tr>
          <th>Pattern</th>
          <th>Example matches</th>
          <th>Example non-matches</th>
        <tr>
        </thead>
      <tbody>
        <tr>
          <td><code>/must/all/match</code></td>
          <td>
            <p><a href="${req.rewriteUrl("~/must/all/match")}">/must/all/match</a></p>
          </td>
          <td>
            <p><a href="/must">/must</a> missing a component</p>
            <p><a href="/must/all">/must/all</a> missing a component</p>
            <p><a href="/must/match">/must/match</a> missing a component</p>
            <p><a href="/all/match">/all/match</a> missing a component</p>
            <p><a href="/doesnt/all/match">/doesnt/all/match</a> component does not match</p>
            <p><a href="/must/some/match">/must/some/match</a> component does not match</p>
            <p><a href="/must/all/Match">/must/all/Match</a> component does not match (case sensitivity matters)</p>
            <p><a href="/must/all/match/exactly">/must/all/match/exactly</a> too many components</p>
            <p><a href="/must/all/match/">/must/all/match/</a> too many components (trailing slash produces another component)</p>
          </td>
        </tr>
        <tr>
          <td><code>/one/:first</code></td>
          <td>
            <p><a href="/one/alpha">/one/alpha</a></p>
            <p><a href="/one/">/one/</a></p>
          </td>
          <td>
            <p><a href="/one">/one</a> missing parameter</p>
            <p><a href="/one/alpha/beta">/one/alpha/beta</a> too many parameters</p>
          </td>
        </tr>
        <tr>
          <td><code>/one/:first/:second</code></td>
          <td>
            <p><a href="/two/alpha/beta">/two/alpha/beta</a></p>
            <p><a href="/two/alpha/">/two/alpha/</a></p>
            <p><a href="/two//">/two//</a></p>
            <p><a href="/two/你好/世界">/two/你好/世界</a></p>
          </td>
          <td>
            <p><a href="/two/alpha">/two/alpha</a> insufficient parameters</p>
            <p><a href="/two/alpha/beta/gamma">/two/alpha/beta/gamma</a> too many parameters</p>
          </td>
        </tr>
        <tr>
          <td><code>/one/:first/:second/:third</code></td>
          <td>
            <p><a href="/three/alpha/beta/gamma">/three/alpha/beta/gamma</a></p>
            <p><a href="/three/alpha/beta/">/three/alpha/beta/</a></p>
            <p><a href="/three/alpha//">/three/alpha//</a></p>
            <p><a href="/three///">/three///</a></p>
            <p><a href="/three//beta/gamma">/three//beta/gamma</a></p>
            <p><a href="/three/alpha//gamma">/three/alpha//gamma</a></p>
            <p><a href="/three//beta/">/three//beta/</a></p>
            <p><a href="/three///gamma">/three///gamma</a></p>
          </td>
        </tr>
        <tr>
          <td><code>/double/:name/:name</code></td>
          <td><a href="/double/alpha/beta">/double/alpha/beta</a></td>
        </tr>
        <tr>
          <td><code>/triple/:name/:name/:name</code></td>
          <td><a href="/triple/alpha/beta/gamma">/triple/alpha/beta/gamma</a></td>
        </tr>
        <tr>
          <td><code>/wildcard1/*</code></td>
          <td>
            <p><a href="/wildcard1/">/wildcard1/</a></p>
            <p><a href="/wildcard1/alpha">/wildcard1/alpha</a></p>
            <p><a href="/wildcard1/alpha/beta">/wildcard1/alpha/beta</a></p>
            <p><a href="/wildcard1/alpha/beta/gamma">/wildcard1/alpha/beta/gamma</a></p>
          </td>
        </tr>
  
        <tr>
          <td><code>/wildcard2/*/foo/bar</code></td>
          <td>
            <p><a href="/wildcard2/alpha/beta/gamma/foo/bar">/wildcard2/alpha/beta/gamma/foo/bar</a></p>
          </td>
          <td>
            <p><a href="/wildcard2/">/wildcard2/</a></p>
            <p><a href="/wildcard2/alpha">/wildcard2/foo/bar</a></p>
          </td>
        </tr>
  
        <tr>
          <td><code>/wildcard3/*/*</code></td>
          <td>
            <p><a href="/wildcard3/alpha/beta">/wildcard3/alpha/beta</a></p>
            <p><a href="/wildcard3/alpha/beta/gamma">/wildcard3/alpha/beta/gamma</a></p>
            <p><a href="/wildcard3/alpha/beta/gamma/delta">/wildcard3/alpha/beta/gamma/delta</a></p>
          </td>
        </tr>
  
        <tr>
          <td><code>/wildcard4/*/foo/bar/*/baz</code></td>
          <td>
            <p><a href="/wildcard4/alpha/beta/gamma//foo/bar/delta/baz">/wildcard4/alpha/beta/gamma/foo/bar/delta/baz</a></p>
          </td>
        </tr>
  """)

    // Static files and directories

    ..write('''
        <tr>
          <td colspan="3"><a name="staticFiles"><h3>Static files and directories from disk</h3></a></td>
        </tr>

        <tr>
          <td>No end-slash could be directory: yes;<br/>Directory listing allowed: yes</td>
          <td>
            <p><a href="/diskfiles/dir-with-index/">/dir-with-index/index.html</a></p>
            <p><a href="/diskfiles/dir-with-index/">/dir-with-index/</a></p>
            <p><a href="/diskfiles/dir-with-index">/dir-with-index</a></p>
            <p><a href="/diskfiles/dir-no-index/">/dir-no-index/</a></p>
            <p><a href="/diskfiles/dir-no-index">/dir-no-index</a></p>
          </td>
          <td>
            <p><a href="/diskfiles/no-such-file.html">/no-such-file.html</a></p>
          </td>
        </tr>

        <tr>
          <td>No end-slash could be directory: yes;<br/>Directory listing allowed: no</td>
          <td>
             <p><a href="/diskfilesDir1List0/dir-with-index/">/dir-with-index/index.html</a></p>
             <p><a href="/diskfilesDir1List0/dir-with-index/">/dir-with-index/</a></p>
             <p><a href="/diskfilesDir1List0/dir-with-index">/dir-with-index</a></p>
          </td>
          <td>
            <p><a href="/diskfilesDir1List0/no-such-file.html">/no-such-file.html</a></p>
            <p><a href="/diskfilesDir1List0/dir-no-index">/dir-no-index</a></p>
            <p><a href="/diskfilesDir1List0/dir-no-index/">/dir-no-index/</a></p>
          </td>
        </tr>

        <tr>
          <td>No end-slash could be directory: no;<br/>Directory listing allowed: yes</td>
          <td>
            <p><a href="/diskfilesDir0List1/dir-with-index/">/dir-with-index/index.html</a></p>
            <p><a href="/diskfilesDir0List1/dir-with-index/">/dir-with-index/</a></p>
            <p><a href="/diskfilesDir0List1/dir-no-index/">/dir-no-index/</a></p>
          </td>
          <td>
            <p><a href="/diskfilesDir0List1/no-such-file.html">/no-such-file.html</a></p>
            <p><a href="/diskfilesDir0List1/dir-with-index">/dir-with-index</a></p>
            <p><a href="/diskfilesDir0List1/dir-no-index">/dir-no-index</a></p>
          </td>
        </tr>

        <tr>
          <td>No end-slash could be directory: no;<br/>Directory listing allowed: no</td>
          <td>
            <p><a href="/diskfilesDir0List0/dir-with-index/">/dir-with-index/index.html</a></p>
            <p><a href="/diskfilesDir1List0/dir-with-index/">/dir-with-index/</a></p>
          </td>
          <td>
            <p><a href="/diskfilesDir0List0/no-such-file.html">/no-such-file.html</a></p>
            <p><a href="/diskfilesDir0List0/dir-with-index">/dir-with-index</a></p>
            <p><a href="/diskfilesDir0List0/dir-no-index/">/dir-no-index/</a></p>
            <p><a href="/diskfilesDir0List0/dir-no-index">/dir-no-index</a></p>
          </td>
        </tr>

        <tr>
          <td>Different MIME types</td>
          <td>
            <p><a href="/diskfiles/test.html">/test.html</a></p>
            <p><a href="/diskfiles/test.jpg">/test.jpg</a></p>
            <p><a href="/diskfiles/test.png">/test.png</a></p>
            <p><a href="/diskfiles/test.txt">/test.txt</a></p>
            <p><a href="/diskfiles/test.xml">/test.xml</a></p>
            <p><a href="/diskfiles/test.dat">/test.dat</a></p>
          </td>
        </tr>

      </tbody>
    </table>
  </div>
''');

  // Exception handling

  final eh1checked =
      (webServer.exceptionHandler != null) ? 'checked="checked"' : '';
  final eh2checked = (p1.exceptionHandler != null) ? 'checked="checked"' : '';
  final eh3checked = (p2.exceptionHandler != null) ? 'checked="checked"' : '';

  resp
    ..write('''
  <div class="section">
    <h2>Exception handling</h2>

    <p>If a handler throws an exception, the exception is passed to an exception
    hander that was registered (either registered with the pipeline or with the
    server).</p>

    <ul>
      <li><a href="/throw/IntegerDivisionByZeroException">IntegerDivisionByZeroException</a></li>
      <li><a href="/throw/FormatException">FormatException</a> thrown.</li>
      <li><a href="/throw/StateError">StateError</a> thrown (after 3 seconds).</li>
    </ul>

    <p>Change which exception handlers have been set:</p>

    <form method="POST" action="/system/exceptionHandler">
      <input type="checkbox" id="eh0" name="eh0" value="on" $eh1checked/><label for="eh0">Server-level</label>
      <input type="checkbox" id="eh1" name="eh1" value="on" $eh2checked/><label for="eh1">Pipeline 1</label>
      <input type="checkbox" id="eh2" name="eh2" value="on" $eh3checked/><label for="eh2">Pipeline 2</label>
      &nbsp;
      <input type="submit" value="Set Exception Handlers"/>
    </form>
  </div>
''')

    // Sessions

    ..write('''
  <div class="section">
    <h2>Sessions</h2>
    <p>Sessions can be used to maintain state between HTTP requests. It can use
    either session cookies or URL rewriting to remember the current session.</p>
    ''');

  final requestSession = req.session;
  if (requestSession == null) {
    // Not logged in
    resp.write('''
  <ul>
    <li><a href=\"${req.rewriteUrl("~/session/loginWithCookies")}\">Login using
        cookies to preserve the session</a> (if the browser uses them)</li>
    <li><a href=\"${req.rewriteUrl("~/session/login")}\">Login without cookies</a></li>
  </ul>
  ''');
  } else if (requestSession is LoginSession) {
    // Logged in
    resp.write('''
  <ul>
    <li><a href="${req.rewriteUrl("~/session/info")}">Session information page</a></li>
    <li><a href="${req.rewriteUrl("~/session/logout")}">Logout</a></li>
  </ul>
  <p style="font-size: smaller">Logged in at: ${requestSession.when}</p>
  ''');
  }

  resp
    ..write('</div>')

    // Stream response

    ..write('''
    <div class="section">
    <h2>Stream test</h2>

    <p>Responses can be buffered and the HTTP response produced after the
    handler has completed, or progressively produced in the handler
    as a stream.</p>

    <ul>
      <li><a href="/streamTest">Basic stream response</a></li>
      <li><a href="/streamTest?seconds=1">Stream response with delays</a></li>
    </ul>

  </div>
  ''')

    // End of content div, and footer

    ..write('''</div>

  </div>

  <footer>
    <p><a href="https://pub.dartlang.org/packages/woomera">Woomera Dart Package</a></p>
  </footer>
</body>
</html>
''');

  return resp;
}

//----------------------------------------------------------------
/// Handler for post operation
///
Future<Response> handleTestPost(Request req) async {
  assert(req.method == 'POST');

  mainLog.fine('[${req.id}] Test POST');
/*
  for (var key in req.params.keys()) {
    var values = req.params.mvalues(key, raw: true);
    if (values.length == 1) {
      // Single value
      print("${key}=\"${values[0]}\"");
    } else {
      // Multi-valued
      print("${key}= [");
      var index = 0;
      for (var value in values) {
        print("[${++index}]=\"${value}\"");
      }
      print("]");
    }
  }
*/

  final resp = ResponseBuffered(ContentType.text)..write('Test post\n');
  return resp;
}

//----------------------------------------------------------------
/// Exception handler
///
Future<Response> handleExceptionHandlers(Request req) async {
  var eh0 = true;
  var eh1 = true;
  var eh2 = true;

  final _postParams = req.postParams;
  if (_postParams != null) {
    eh0 = _postParams['eh0'] == 'on';
    eh1 = _postParams['eh1'] == 'on';
    eh2 = _postParams['eh2'] == 'on';
  }

  if (eh0) {
    webServer.exceptionHandler = exceptionHandlerOnServer;
  }
  if (eh1) {
    p1.exceptionHandler = exceptionHandlerOnPipe1;
  }
  if (eh2) {
    p2.exceptionHandler = exceptionHandlerOnPipe2;
  }

  mainLog.fine('[${req.id}] setting exception handlers');
  final resp = ResponseBuffered(ContentType.html)..write('''
<html lang="en">
<head>
  <title>Setup</title>
</head>
<body>
<h1>System setup: Exception handlers</h1>

<ul>
  <li>Server exception handler: $eh0</li>
  <li>Pipe 1 exception handler: $eh1</li>
  <li>Pipe 2 exception handler: $eh2</li>
</ul>

${homeButton(req)}
''');
  return resp;
}

//----------------------------------------------------------------
/// Handler to stop the Web server.
///
Future<Response> handleStop(Request req) async {
  await webServer.stop();
  mainLog.fine('[${req.id}] stopped');
  final resp = ResponseBuffered(ContentType.text)
    ..write('Web server has been stopped\n');
  return resp;
}

//----------------------------------------------------------------
/// Handler that throws exceptions.
///
Future<Response> handleThrow(Request req) async {
  mainLog.fine('[${req.id}] exception test');

  final type = req.pathParams['name'];

  switch (type) {
    case '':
      break;
    case '0':
    case 'IntegerDivisionByZeroException':
      final _ = 42 ~/ 0;
      break;

    case '1':
    case 'FormatException':
      final _ = int.parse('16C');
      break;

    case '2':
    case 'StateError':
      return await oldStyleFuture(throwException: true);

    default:
      throw ArgumentError('Unknown name: $type');
  }

  final resp = ResponseBuffered(ContentType.html)
    ..status = HttpStatus.notAcceptable
    ..write('''
<html>
<head><title>Exception test</title></head>
<body>
<h1>Exception test</h1>
<p>The handler for this page can throw different exceptions, depending on
what the path parameter is:</p>
<dl>
  <dt>blank</dt>
    <dd>No exception is thrown. Shows this page.</dd>
  <dt>0</dt>
    <dd>Throws an <code>IntegerDivisionByZeroException</code></dd>
  <dt>2</dt>
    <dd>Throws a <code>FormatError</code></dt>
  <dt>1</dt>
    <dd>Throws a <code>StateError</code></dt>
  <dt>Other values</dt>
    <dd>Throws a <code>String</code> of that value.</dd>
</dl>

<p>If no exception handlers have been provided, the exception is logged
(with "SEVERE" logging level) and an uninformative error page is
returned. It is deliberately uninformative so no internal information
can be accidently leaked.</body>
</html>
''');
  return resp;
}

/// Method that throws an exception some time in the future.
///
Future<ResponseBuffered> oldStyleFuture({bool throwException: false}) {
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
      ..write('''This worked, but it should not have.''');
    c.complete(resp);
  });

  return c.future;
}

//----------------------------------------------------------------
/// Stream handler
///
/// This is an example of using a [ResponseStream] to progressively
/// create the response.

Future<Response> streamTest(Request req) async {
  // Get parameters

  final numIterations = 10;

  var secs = 0;
  if (req.queryParams['seconds'].isNotEmpty) {
    secs = int.parse(req.queryParams['seconds']);
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

Stream<List<int>> _streamSource(Request req, int iterations, int secs) async* {
  final delay = Duration(seconds: secs);

  yield 'Stream of $iterations items (delay: $secs seconds)\n'.codeUnits;

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
///
Future<Response> handleJson(Request req) async {
  final data = {'name': 'John Citizen', 'address': 'foo'};

  // response.headers.contentType = ContentType.json
  print(json.encode(data));
  // json.decode(str);

  final resp = ResponseBuffered(ContentType.text)..write('JSON test');
  return resp;
}

//================================================================
// Exception handlers

//----------------------------------------------------------------
/// Exception handler for the server.
///
/// This exception handler is attached to the [Server] and will
/// be invoked if an exception is raised outside the context
/// of the pipelines (or the pipeline did not process any exceptions
/// raised inside their context).

Future<Response> exceptionHandlerOnServer(
        Request req, Object exception, StackTrace? st) =>
    _exceptionHandler(req, exception, st, 'server');

//----------------------------------------------------------------
/// Exception handler for pipeline1.
///
/// This exception handler is attached to the first pipeline.

Future<Response> exceptionHandlerOnPipe1(
    Request req, Object exception, StackTrace? st) async {
  if (exception is StateError) {
    throw NoResponseProduced();
  }
  return _exceptionHandler(req, exception, st, 'pipeline1');
}

//----------------------------------------------------------------
/// Exception handler for pipeline2.
///
/// This exception handler is attached to the second pipeline.

Future<Response> exceptionHandlerOnPipe2(
    Request req, Object exception, StackTrace? st) async {
  if (exception is StateError) {
    throw NoResponseProduced();
  }
  return _exceptionHandler(req, exception, st, 'pipeline2');
}

//----------------------------------------------------------------
// Common method used to implement the above exception handlers.

Future<Response> _exceptionHandler(
    Request req, Object exception, StackTrace? st, String who) async {
  // Create a response

  final resp = ResponseBuffered(ContentType.html);

  // Set the status depending on the type of exception

  if (exception is NotFoundException) {
    resp.status = (exception.found == NotFoundException.foundNothing)
        ? HttpStatus.methodNotAllowed
        : HttpStatus.notFound;
  } else {
    resp.status = HttpStatus.internalServerError;
  }

  // The body of the response

  resp.write('''
<html lang="en">
<head>
  <title>Exception</title>
</head>
<body>
<h1 style="color: red">Exception thrown</h1>

An exception was thrown and was handled by the <strong>$who</strong> exception handler.

<h2>Exception</h2>

<p>Exception object type: <code>${exception.runtimeType}</code></p>
<p>String representation of object: <strong>$exception</strong></p>
''');

  if (st != null) {
    resp.write('''
<h2>Stack trace</h2>
<pre>
$st
</pre>
    ''');
  }
  resp.write('''
${homeButton(req)}
</body>
</html>
''');

  return resp;
}

//================================================================
// Session

const String _testCookieName = 'browser-test';

Future<Response> _handleLoginWithCookies(Request req) async {
  final testCookie = Cookie(_testCookieName, 'cookies_work!')
    ..path = req.server.basePath
    ..httpOnly = true;

  final resp = ResponseBuffered(ContentType.html)
    ..cookieAdd(testCookie)
    ..write('''
<html>
<head></head>
<body>
<h1>Determining if the browser uses cookies</h1>

<p>An attempt has been done to set a test cookie. If the browser
presents the cookie when when the login page is visited, it will know
the browser supports cookies and will automatically use cookies to
preserve the session. If no cookies are presented to the login page,
it will not use cookies and instead use URL rewriting to preserve the
session.  The login page will not be presented the cookie: if the
browser does not support cookies, if the browser supports cookies but
they have been disabled, or if the login page is visited directly
(without going via this page).</p>

<p>Now please visit the
<a href="${req.rewriteUrl('~/session/login')}">login page</a>.</p>

</body>
</html>
''');

  return resp;
}

//----------------------------------------------------------------

Future<Response> _handleLogin(Request req) async {
  const keepAlive = const Duration(minutes: 1);

  req.session = LoginSession(webServer, keepAlive, DateTime.now());

  final resp = ResponseBuffered(ContentType.html)
    ..cookieDelete(_testCookieName, req.server.basePath)
    ..write('''
<html>
<head></head>
<body>
<h1>Session: logged in</h1>

<p>You have logged in.</p>

<p>The session will remain alive for ${keepAlive.inSeconds} seconds, after the
last HTTP request was received for the session.</p>

<p><a href="${req.rewriteUrl('~/session/info')}">Session information page</a></p>

${homeButton(req)}
</body>
</html>
''');
  return resp;
}

//----------------------------------------------------------------

Future<Response> _handleLogout(Request req) async {
  final resp = ResponseBuffered(ContentType.html)..write('''
<html>
<head></head>
<body>
<h1>Session: logout</h1>
''');

  final _session = req.session;
  if (_session != null) {
    await _session
        .terminate(); // terminate the session (also removes the timer)
    req.session = null; // clear the session so it is no longer preserved

    resp.write('<p>You have been logged out.</p>');
  } else {
    resp.write('<p>Error: not logged in: you should not see this page.</p>');
  }

  resp.write('''
${homeButton(req)}
</body>
</html>
''');
  return resp;
}

//----------------------------------------------------------------

Future<Response> _handleSessionInfoPage(Request req) async {
  final resp = ResponseBuffered(ContentType.html)..write('''
<html>
<head></head>
<body>
<h1>Session information</h1>
''');

  final requestSession = req.session;
  if (requestSession is LoginSession) {
    final duration = DateTime.now().difference(requestSession.when);

    if (requestSession.name != null) {
      resp.write(
          '<p>Welcome <strong>${HEsc.text(requestSession.name)}</strong>.</p>');
    }
    resp.write('''
<p>Logged in at ${requestSession.when}.
You have been logged in for over ${duration.inSeconds} seconds.</p>

<h2>Session preservation across GET requests</h2>

<p>If using cookies, the session is preserved using a session cookie.
Otherwise URL rewriting is used to preserve the session for GET requests,
and the following link (back to this page) will have a session query parameters</p>

<ul>
  <li><a href="${req.rewriteUrl('~/session/info')}">Session info page</a></li>
  <li><a href="${req.rewriteUrl('~/session/info?foo=bar&foo=baz&abc=xyz')}">With other query parameters</a></li>
</ul>

<p>Note: any session query parameters are stripped out so the application never
sees them. The handler that processed this request saw
''');
    if (req.queryParams.isEmpty) {
      resp.write('no query parameters.');
    } else {
      resp.write('these query parameters: ${req.queryParams}');
    }

    resp.write('''
<h2>Session preserved across POST requests</h2>

<p>If using cookies, the session is preserved using a session cookie.
Otherwise the session needs to be preserved using a parameter.</p>

<p>For a POST request, typically this is done by rewriting the form's action URL.
So the POST request actually has both query parameters and POST parameters
(though the application never sees this, because the session parameter is
stripped out after processing it).</p>

<form method="POST" action="${req.rewriteUrl('~/session/set-name')}">
  <label for="n">Name:</label>
  <input type="text" name="name" id="n"/>
  <input type="submit" value="Set name"/>
</form>

<p>Although it is possible to preserve the session using a hidden form
parameter, that is not recommended because rewriting a URL also incorporates
the server's basePath in the URL. If the URL is not rewritten, there is a risk
that changes to the basePath are not incorporated in the URL and the application
breaks.</p>

<p>Do not both rewrite the form's action URL and include the hidden form field.
That will be detected as multiple session IDs (even though they are the
same value) and (for security and consistent behaviour) they will all be ignored
and the session will be lost.</p>

<p>The session can also be lost if the cookies are cleared from the browser
(when using cookies) or a link which has not been rewritten is followed
(when not using cookies). Any external link will not be rewritten, so the user
must stay within the application to preserve the session, when cookies are
not used. A session will also be lost if/when it times out.</p>

''');
  } else {
    resp.write('<p>No session.</p>');
  }

  resp.write('''
${homeButton(req)}
</body>
</html>
''');
  return resp;
}

//----------------------------------------------------------------

Future<Response> _handleSessionSetName(Request req) async {
  final resp = ResponseBuffered(ContentType.html)..write('''
<html lang="en">
<head>
  <title>Session: name set</title>
</head>
<body>
<h1>Session: name set</h1>
''');

  final requestSession = req.session;
  if (requestSession is LoginSession) {
    final newName = req.postParams!['name'];

    if (newName.isNotEmpty) {
      requestSession.name = newName;
      resp.write('<p>Your name has been set to "${HEsc.text(newName)}".</p>');
    } else {
      requestSession.name = '';
      resp.write('<p>Your name has been cleared.</p>');
    }
    resp.write(
        '<p>Return to the <a href="${req.rewriteUrl('~/session/info')}">session info page</a>.</p>');
  } else {
    resp.write('<p>Error: not logged in: you should not see this page.</p>');
  }

  resp.write('''
${homeButton(req)}
</body>
</html>
''');
  return resp;
}

//================================================================
// Main

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

//----------------------------------------------------------------

Server _serverSetup() {
  //--------
  // Create a new Web server
  //
  // The bind address is setup to listen to any incoming connection from any IP
  // address (IPv4 or IPv6). If this is not done, by default it only listens
  // on the IPv4 loopback interface, which is good for deployment behind a
  // reverse Web proxy, but might be restrictive for testing.
  //
  // Note: normally [webserver], [p1] and [p2] can be local variables. But in
  // this demo some of the HTTP requests will manipulate the server and
  // pipelines (which normally doesn't happen in ordinary applications) so
  // these are global variables so that the handler methods can access them.

  final port = 1024;

  webServer = Server()
    ..bindAddress = InternetAddress.anyIPv6
    ..v6Only = false // false = listen to any IPv4 and any IPv6 address
    ..bindPort = port
    ..exceptionHandler = exceptionHandlerOnServer; // set exception handler

  mainLog.info('Web server running on port $port');

  //--------
  // Setup the first pipeline
  //
  // Get the first pipeline and set the exception handler on it.

  p1 = webServer.pipelines.first

    // Set the first pipeline's exception handler
    //
    // If an exception is thrown, and is not processed by any pipeline's
    // exception

    ..exceptionHandler = exceptionHandlerOnPipe1;

  //--------
  // Setup the second pipeline
  //
  // A typical server usually only needs one pipeline, and all of the rules will
  // be defined in it. But to demonstrate the use of multiple pipelines, this
  // application has a second pipleline where most of the rules will be defined.
  //
  // Note: the other way to create multiple pipelines is to specify the number
  // of pipelines when the server is created:
  //     webServer = Server(numberOfPipelines: 2);

  p2 = ServerPipeline();
  webServer.pipelines.add(p2);

  // Set the second pipeline's exception handler
  //
  // If an exception is thrown by one of the handlers invoked from the second
  // pipeline, that exception will be passed to this exception handler.
  //
  // Applications can define exception handlers on the server, individual
  // pipelines, or a combination of both.

  p2
    ..exceptionHandler = exceptionHandlerOnPipe2

    // Set up the rules for the second pipeline. A rule consists of the HTTP
    // request method (e.g. GET or POST), a pattern to match against the request
    // path and the handler method.

    // This example was written before automatic annotations was available,
    // So it explicitly registers the request handlers by invoking the get/post
    // methods on the pipeline. A new program would probably use automatic
    // registration by annotating the request handlers with a Registration
    // object.

    ..get('~/', homePage)
    ..get('~/must/all/match', debugHandler)
    ..post('~/must/all/match', debugHandler)
    ..get('~/one/:first', debugHandler)
    ..get('~/two/:first/:second', debugHandler)
    ..get('~/three/:first/:second/:third', debugHandler)
    ..post('~/one/:first', debugHandler)
    ..post('~/two/:first/:second', debugHandler)
    ..post('~/three/:first/:second/:third', debugHandler)
    ..get('~/double/:name/:name', debugHandler)
    ..get('~/triple/:name/:name/:name', debugHandler)
    ..post('~/double/:name/:name', debugHandler)
    ..post('~/triple/:name/:name/:name', debugHandler)
    ..get('~/wildcard1/*', debugHandler)
    ..get('~/wildcard2/*/foo/bar', debugHandler)
    ..get('~/wildcard3/*/*', debugHandler)
    ..get('~/wildcard4/*/foo/bar/*/baz', debugHandler)
    ..get('~/throw/:name', handleThrow) // tests exception handling

    ..get('~/test', debugHandler)
    ..post('~/test', debugHandler)
    ..get('~/streamTest', streamTest)
    ..get('~/session/login', _handleLogin)
    ..get('~/session/loginWithCookies', _handleLoginWithCookies)
    ..get('~/session/info', _handleSessionInfoPage)
    ..post('~/session/set-name', _handleSessionSetName)
    ..get('~/session/logout', _handleLogout);

  // Serve static files
  //
  // This rule uses the [StaticFiles] class to create a handler that serves
  // files and directories from a local directory. In this case, the "web"
  // directory underneath this project's directory. This project's directory
  // is found as the parent of the directory containing this program file.
  //
  // For this demo, only paths under "diskfiles" (i.e. pattern "~/diskfiles/*")
  // try to match static files. The pattern "~/*" could be used -- if it is made
  // the very last rule -- so it acts as a catch-all rule to server up the
  // file/directory if it exists, or to return a not-found exception if there is
  // no such file/directory. Though, if possible, it is better to use a more
  // restrictive pattern (e.g. "~/style/*" or "~/images/*").

  final dirContainingThisFile = FileSystemEntity.parentOf(Platform.script.path);
  final projectDir = FileSystemEntity.parentOf(dirContainingThisFile);

  //mainLog.info('projectDir: $projectDir');

  // Map paths without an end slash to a directory, allow directory listing

  final staticFiles = StaticFiles('$projectDir/web',
      defaultFilenames: ['index.html', 'index.htm'],
      allowFilePathsAsDirectories: true,
      allowDirectoryListing: true);

  p2.get('~/diskfiles/*', staticFiles.handler);

  // Do not try to treat paths without an end slash as directories, no listing

  final staticDir0List0 = StaticFiles('$projectDir/web',
      defaultFilenames: ['index.html', 'index.htm'],
      allowFilePathsAsDirectories: false,
      allowDirectoryListing: false);

  p2.get('~/diskfilesDir0List0/*', staticDir0List0.handler);

  // Maps paths without an end slash to a directory, no directory listing

  final staticDir1List0 = StaticFiles('$projectDir/web',
      defaultFilenames: ['index.html', 'index.htm'],
      allowFilePathsAsDirectories: true,
      allowDirectoryListing: false);

  p2.get('~/diskfilesDir1List0/*', staticDir1List0.handler);

  // Do not try to treat paths without an end slash as directories, allow listing

  final staticDir0List1 = StaticFiles('$projectDir/web',
      defaultFilenames: ['index.html', 'index.htm'],
      allowFilePathsAsDirectories: false,
      allowDirectoryListing: true);

  p2
    ..get('~/diskfilesDir0List1/*', staticDir0List1.handler)

    // Special handlers for demonstrating Woomera features

    ..post('~/system/exceptionHandler', handleExceptionHandlers)
    ..post('~/system/stop', handleStop);

  return webServer;
}

//================================================================
// Simulated testing

//----------------------------------------------------------------

Future simulatedRun(Server server) async {
  mainLog.fine('GET /test');

  final req = Request.simulated('GET', '~/test', id: 'simulated');

  final r = await server.simulate(req);
  print(r);
}

//================================================================

Future main(List<String> args) async {
  final simulate = args.contains('-t');
  final quietMode = args.contains('-q'); // quiet mode
  if (args.contains('-h')) {
    print('Usage: complex-example.dart [-t] [-q] [-h]');
  }

  if (!quietMode) {
    _loggingSetup();
  }

  final server = _serverSetup();

  mainLog.fine('started');

  if (!simulate) {
    await server.run(); // run Web server
  } else {
    await simulatedRun(server); // run simulation for testing
  }

  // The Future returned by the [run] method never gets completed, unless the
  // server's [stop] method is invoked. Most applications leave the web server
  // running "forever", so normally the server's [stop] method never gets
  // invoked.

  mainLog.fine('finished');
}
