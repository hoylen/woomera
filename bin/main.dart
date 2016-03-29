/// Woomera demonstration Web Server.
///
///
/// Copyright (c) 2015, Hoylen Sue. All rights reserved. Use of this source code
/// is governed by a BSD-style license that can be found in the LICENSE file.
//----------------------------------------------------------------

import 'dart:io'
    show
        ContentType,
        Cookie,
        HttpStatus,
        InternetAddress,
        FileSystemEntity,
        Platform;
import 'dart:async';

import 'dart:convert' show UTF8, JSON;

import 'package:logging/logging.dart';

import 'package:woomera/woomera.dart';

//================================================================
// Globals

// Application logger.

Logger mainLog = new Logger("main");

// The Web server and pipelines.
//
// Normally these can be local variables, but they are made global
// so some of the handler functions can access them. They are only
// manipulated for testing purposes: a normal Web application would
// not need to manipulate them after they have been setup.

Server webServer;
ServerPipeline p1;
ServerPipeline p2;

//================================================================
// Handlers

String homeButton(Request req) {
  return "<p><a href='${req.rewriteUrl(
      "~/")}' style='font-size: large; text-decoration: none;'>&#x21A9;</a></p>";
}

//----------------------------------------------------------------

Future<Response> homePage(Request req) async {
  var resp = new ResponseBuffered(ContentType.HTML);
  resp.write("""
<html>
<head>
 <title>Woomera demo</title>
 <style type="text/css">
table { border-collapse: collapse; }
td { vertical-align: top; padding: 1ex 0.5em; }
td p { margin: 0 0 0.5ex 0; }
 </style>
</head>
<body>
  <h1>Woomera demo</h1>

  <h2>URL pattern matching</h2>

  <table>
    <thead>
      <tr>
        <th>Pattern</th>
        <th>Examples</th>
        <th>Non-matches</th>
      <tr>
      </thead>
    <tbody>
      <tr>
        <td><code>/must/all/match</code></td>
        <td>
          <p><a href="/must/all/match">/must/all/match</a></p>
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

    </tbody>
  </table>

  <h2>Query parameters and POST parameters</h2>

  <table>
    <tbody>
      <tr>
        <td>Query parameters</td>
        <td>
          <p><a href="/test?foo=bar">?foo=bar</a></p>
          <p><a href="/test?foo=1&bar=baz">?foo=1&bar=baz</a></p>
        </td>
      </tr>
      <tr>
        <td>Query parameters can be repeated</td>
        <td>
          <p><a href="/test?m=first&m=second&n=안녕하세요+세계&m=third">?m=first&m=second&n=안녕하세요 세계&m=third</a></p>
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

  <h2>Stream test</h2>

  <p><a href="/streamTest">Stream test</a></p>

  <h2>Exception handling</h2>

  <p>If the handler throws an exception, Woomera passes it to an exception
  hander function that was registered with the Server object.</p>

  <ul>
    <li><a href="/throw/IntegerDivisionByZeroException">IntegerDivisionByZeroException</a></li>
    <li><a href="/throw/FormatException">FormatException</a> thrown.</li>
    <li><a href="/throw/StateError">StateError</a> thrown (after 3 seconds).</li>
  </ul>

  <h2>Sessions</h2>
  <ul>
  """);

  if (req.session == null) {
    resp.write(
        "<li><a href=\"${req.rewriteUrl("~/session/login")}\">Login without cookies</a></li>");
    resp.write(
        "<li><a href=\"${req.rewriteUrl("~/session/loginWithCookies")}\">Login with cookies</a></li>");
  } else {
    resp.write(
        "<li><a href=\"${req.rewriteUrl("~/session/logout")}\">Logout</a></li>");
  }
  resp.write("</ul>");

  var eh1checked =
      (webServer.exceptionHandler != null) ? "checked='checked'" : "";
  var eh2checked = (p1.exceptionHandler != null) ? "checked='checked'" : "";
  var eh3checked = (p2.exceptionHandler != null) ? "checked='checked'" : "";

  resp.write("""
  <h2>System control</h2>

  <form method="POST" action="/system/exceptionHandler">
    <input type="checkbox" id="eh0" name="eh0" value="on" $eh1checked/><label for="eh0">Server-level</label>
    <input type="checkbox" id="eh1" name="eh1" value="on" $eh2checked/><label for="eh1">Pipeline 1</label>
    <input type="checkbox" id="eh2" name="eh2" value="on" $eh3checked/><label for="eh2">Pipeline 2</label>
    &nbsp;
   <input type="submit" value="Set Exception Handlers"/>
   </form>

</body>
</html>
""");

  return resp;
}

//----------------------------------------------------------------

Future<Response> handleTestPost(Request req) async {
  assert(req.method == "POST");

  mainLog.fine("Test POST");
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

  var resp = new ResponseBuffered(ContentType.TEXT);
  resp.write("Test post\n");
  return resp;
}

//----------------------------------------------------------------

Future<Response> handleExceptionHandlers(Request req) async {
  var eh0 = req.params["eh0"] == "on";
  var eh1 = req.params["eh1"] == "on";
  var eh2 = req.params["eh2"] == "on";

  webServer.exceptionHandler = (eh0) ? exceptionHandlerOnServer : null;
  p1.exceptionHandler = (eh1) ? exceptionHandlerOnPipe1 : null;
  p2.exceptionHandler = (eh2) ? exceptionHandlerOnPipe2 : null;

  mainLog.fine("setting exception handlers");
  var resp = new ResponseBuffered(ContentType.HTML);
  resp.write("""
<html>
<head></head>
<body>
<h1>System setup: Exception handlers</h1>

<ul>
  <li>Server exception handler: $eh0</li>
  <li>Pipe 1 exception handler: $eh1</li>
  <li>Pipe 2 exception handler: $eh2</li>
</ul>

${homeButton(req)}
""");
  return resp;
}

//----------------------------------------------------------------

Future<Response> handleStop(Request req) async {
  await webServer.stop();
  mainLog.fine("stopped");
  var resp = new ResponseBuffered(ContentType.TEXT);
  resp.write("Web server has been stopped\n");
  return resp;
}

//----------------------------------------------------------------

Future<Response> handleThrow(Request req) async {
  mainLog.fine("exception test");

  var type = req.params["name"];

  switch (type) {
    case "":
      break;
    case "0":
    case "IntegerDivisionByZeroException":
      var _ = 42 ~/ 0;
      break;

    case "1":
    case "FormatException":
      var _ = int.parse("16C");
      break;

    case "2":
    case "StateError":
      return await oldStyleFuture(throwException: true);

    default:
      throw type;
  }

  var resp = new ResponseBuffered(ContentType.HTML);
  resp.status = HttpStatus.NOT_ACCEPTABLE;
  resp.write("""
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
""");
  return resp;
}

Future<ResponseBuffered> oldStyleFuture({bool throwException: false}) {
  var duration = new Duration(seconds: 3);

  var c = new Completer<ResponseBuffered>();

  var _ = new Timer(duration, () {
    if (throwException) {
      // This exception is thrown from a function that is not using the new
      // async/await syntax. This means it won't be caught by the try/catch
      // mechanism. The framework will catch these using zones.
      throw new StateError(new DateTime.now().toString());
    }

    var resp = new ResponseBuffered(ContentType.TEXT);
    resp.status = HttpStatus.NOT_ACCEPTABLE;
    resp.write("""This worked, but it should not have.""");
    c.complete(resp);
  });

  return c.future;
}
//----------------------------------------------------------------

Future<Response> streamTest(Request req) async {
  var resp = new ResponseStream(ContentType.TEXT);
  resp.status = HttpStatus.OK;

  await resp.addStream(req, streamSource(req));

  return resp;
}

Stream<List<int>> streamSource(Request req) async* {
  int iterations = 10;

  for (var x = 0; x < iterations; x++) {
    yield "Item $x\n".codeUnits;
  }
}

//----------------------------------------------------------------

Future<Response> handleJson(Request req) async {
  Map data = {'name': "John Citizen", 'address': "foo"};

  // response.headers.contentType = ContentType.JSON
  print(JSON.encode(data));
  // JSON.decode(str);

  var resp = new ResponseBuffered(ContentType.TEXT);
  resp.write("JSON test");
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
    Request req, Object exception, StackTrace st) {
  return _exceptionHandler(req, exception, st, "server");
}

//----------------------------------------------------------------
/// Exception handler for pipeline1.
///
/// This exception handler is attached to the first pipeline.

Future<Response> exceptionHandlerOnPipe1(
    Request req, Object exception, StackTrace st) async {
  if (exception is StateError) {
    return null;
  }
  return _exceptionHandler(req, exception, st, "pipeline1");
}

//----------------------------------------------------------------
/// Exception handler for pipeline2.
///
/// This exception handler is attached to the second pipeline.

Future<Response> exceptionHandlerOnPipe2(
    Request req, Object exception, StackTrace st) async {
  if (exception is StateError) {
    return null;
  }
  return _exceptionHandler(req, exception, st, "pipeline2");
}

//----------------------------------------------------------------
// Common method used to implement the above exception handlers.

Future<Response> _exceptionHandler(
    Request req, Object exception, StackTrace st, String who) async {
  // Create a response

  var resp = new ResponseBuffered(ContentType.HTML);

  // Set the status depending on the type of exception

  if (exception is NotFoundException) {
    resp.status = (exception.methodNotFound)
        ? HttpStatus.METHOD_NOT_ALLOWED
        : HttpStatus.NOT_FOUND;
  } else {
    resp.status = HttpStatus.INTERNAL_SERVER_ERROR;
  }

  // The body of the response

  resp.write("""
<html>
<head>
  <title>Exception</title>
</head>
<body>
<h1 style="color: red">Exception thrown</h1>

An exception was thrown and was handled by the <strong>${who}</strong> exception handler.

<h2>Exception</h2>

<p>Exception object type: <code>${exception.runtimeType}</code></p>
<p>String representation of object: <strong>${exception}</strong></p>
""");

  if (st != null) {
    resp.write("""
<h2>Stack trace</h2>
<pre>
${st}
</pre>
    """);
  }
  resp.write("""
${homeButton(req)}
</body>
</html>
""");

  return resp;
}

//================================================================
// Session

const String testCookieName = "browser-test";

Future<Response> handleLoginWithCookies(Request req) async {
  var resp = new ResponseBuffered(ContentType.HTML);

  var testCookie = new Cookie(testCookieName, "cookies_work!");
  testCookie.path = req.server.basePath;
  testCookie.httpOnly = true;
  resp.cookieAdd(testCookie);

  resp.write("""
<html>
<head></head>
<body>
<h1>Setting test cookie</h1>

<p>An attempt has been done to set a test cookie. Now go to the
<a href="${req.rewriteUrl("~/session/login")}">login</a> page.
If the browser supports cookies, the
login page will detect that cookie and then use cookies to preserve
the session. If it doesn't detect the cookie, then it will fall
back to using URL rewriting to preserve the session.</p>

${homeButton(req)}
</body>
</html>
""");

  return resp;
}

//----------------------------------------------------------------

Future<Response> handleLogin(Request req) async {
  req.session = new Session(webServer);
  req.session["name"] = "fred";

  var resp = new ResponseBuffered(ContentType.HTML);

  resp.cookieDelete(testCookieName, req.server.basePath);

  resp.write("""
<html>
<head></head>
<body>
<h1>Session: logged in</h1>

<p>You have logged in.</p>

${homeButton(req)}
</body>
</html>
""");
  return resp;
}

//----------------------------------------------------------------

Future<Response> handleLogout(Request req) async {
  var resp = new ResponseBuffered(ContentType.HTML);
  resp.write("""
<html>
<head></head>
<body>
<h1>Session: logout</h1>
""");

  if (req.session != null) {
    req.session = null;
    resp.write("You have been logged out.");
  } else {
    resp.write("<p>You were not logged in.</p>");
  }

  resp.write("""
${homeButton(req)}
</body>
</html>
""");
  return resp;
}

//================================================================

Future main(List<String> args) async {
  // Set up logging

  hierarchicalLoggingEnabled = true;
  Logger.root.onRecord.listen((LogRecord rec) {
    print('${rec.time}: ${rec.loggerName}: ${rec.level.name}: ${rec.message}');
  });

  Logger.root.level = Level.OFF;
  // Logger.root.level = Level.ALL;

  var level = Level.INFO;
  if (true) {
    new Logger("main").level = level;
    new Logger("woomera.server").level = level;
    new Logger("woomera.request").level = level;
    new Logger("woomera.response").level = level;
    new Logger("woomera.session").level = level;
  }

  mainLog.fine("started");

  //--------
  // Create a new Web server

  webServer = new Server();
  webServer.bindAddress = InternetAddress.ANY_IP_V6;
  webServer.bindPort = 1024;
  webServer.exceptionHandler = exceptionHandlerOnServer;

  //--------
  // Get the first pipe (which was automatically created by the Server)

  p1 = webServer.pipelines.first;
  //pipe1.exceptionHandler = exceptionHandlerOnPipe1;

  //--------
  // Create the second pipe

  // A typical server usually only needs one pipeline, but to demonstrate
  // the use of multiple pipelines, this application will create a second
  // pipleline where most of the filters will be defined.

  p2 = new ServerPipeline();
  webServer.pipelines.add(p2);

  // Set up an exception handler on the second pipeline
  // When an exception occurs in this pipeline, this exception handler
  // will be passed the exception.

  p2.exceptionHandler = exceptionHandlerOnPipe2;

  // Set up the handlers for the second pipeline

  p2.register("GET", "~/", homePage);

  p2.get("~/must/all/match", debugHandler);
  p2.post("~/must/all/match", debugHandler);

  p2.get("~/one/:first", debugHandler);
  p2.get("~/two/:first/:second", debugHandler);
  p2.get("~/three/:first/:second/:third", debugHandler);
  p2.post("~/one/:first", debugHandler);
  p2.post("~/two/:first/:second", debugHandler);
  p2.post("~/three/:first/:second/:third", debugHandler);

  p2.get("~/double/:name/:name", debugHandler);
  p2.get("~/triple/:name/:name/:name", debugHandler);
  p2.post("~/double/:name/:name", debugHandler);
  p2.post("~/triple/:name/:name/:name", debugHandler);

  p2.get("~/wildcard1/*", debugHandler);
  p2.get("~/wildcard2/*/foo/bar", debugHandler);
  p2.get("~/wildcard3/*/*", debugHandler);
  p2.get("~/wildcard4/*/foo/bar/*/baz", debugHandler);

  p2.get("~/throw/:name", handleThrow); // tests exception handling

  p2.get("~/test", debugHandler);
  p2.post("~/test", debugHandler);

  p2.get("~/streamTest", streamTest);

  p2.get("~/session/login", handleLogin);
  p2.get("~/session/loginWithCookies", handleLoginWithCookies);
  p2.get("~/session/logout", handleLogout);

  // Serve static files

  var projectDir = FileSystemEntity
      .parentOf(FileSystemEntity.parentOf(Platform.script.path));

  p2.get(
      "~/file/*",
      new StaticFiles(projectDir + "/web",
              defaultFilename: "index.html", allowDirectoryListing: true)
          .handler);

  // Special handlers for testing

  p2.post("~/system/exceptionHandler", handleExceptionHandlers);
  p2.post("~/system/stop", handleStop);

  //--------
  // Start the server

  await webServer.run(); // this returns a Future

  mainLog.fine("finished");
}
