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
  """);

  if (req.session == null) {
    // Not logged in
    resp.write("""
<ul>
  <li><a href=\"${req.rewriteUrl("~/session/loginWithCookies")}\">Login using
      cookies to preserve the session</a> (if the browser uses them)</li>
  <li><a href=\"${req.rewriteUrl("~/session/login")}\">Login without cookies</a></li>
</ul>
""");
  } else {
    // Logged in
    resp.write("""
<ul>
  <li><a href=\"${req.rewriteUrl("~/session/info")}\">Session information page</a></li>
  <li><a href=\"${req.rewriteUrl("~/session/logout")}\">Logout</a></li>
</ul>
<p style="font-size: smaller">Logged in at: ${req.session["when"]}</p>
""");
  }

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
  var eh0 = req.postParams["eh0"] == "on";
  var eh1 = req.postParams["eh1"] == "on";
  var eh2 = req.postParams["eh2"] == "on";

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

  var type = req.pathParams["name"];

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
    resp.status = (exception.found == NotFoundException.foundNothing)
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
<a href="${req.rewriteUrl("~/session/login")}">login page</a>.</p>

</body>
</html>
""");

  return resp;
}

//----------------------------------------------------------------

Future<Response> handleLogin(Request req) async {
  var keepAlive = new Duration(minutes: 1);

  req.session = new Session(webServer, keepAlive);

  req.session["when"] = new DateTime.now();

  var resp = new ResponseBuffered(ContentType.HTML);

  resp.cookieDelete(testCookieName, req.server.basePath);

  resp.write("""
<html>
<head></head>
<body>
<h1>Session: logged in</h1>

<p>You have logged in.</p>

<p>The session will remain alive for ${keepAlive.inSeconds} seconds, after the
last HTTP request was received for the session.</p>

<p><a href="${req.rewriteUrl("~/session/info")}">Session information page</a></p>

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
    req.session.terminate(); // terminate the session (also removes the timer)
    req.session = null; // clear the session so it is no longer preserved

    resp.write("<p>You have been logged out.</p>");
  } else {
    resp.write("<p>Error: not logged in: you should not see this page.</p>");
  }

  resp.write("""
${homeButton(req)}
</body>
</html>
""");
  return resp;
}

//----------------------------------------------------------------

Future<Response> handleSessionInfoPage(Request req) async {
  var resp = new ResponseBuffered(ContentType.HTML);
  resp.write("""
<html>
<head></head>
<body>
<h1>Session information</h1>
""");

  if (req.session != null) {
    var duration = new DateTime.now().difference(req.session["when"]);

    var name = req.session["name"];
    if (name != null) {
      resp.write("<p>Welcome <strong>${HEsc.text(name)}</strong>.</p>");
    }
    resp.write("""
<p>Logged in at ${req.session["when"]}.
You have been logged in for over ${duration.inSeconds} seconds.</p>

<h2>Session preservation across GET requests</h2>

<p>If using cookies, the session is preserved using a session cookie.
Otherwise URL rewriting is used to preserve the session for GET requests,
and the following link (back to this page) will have a session query parameters</p>

<ul>
  <li><a href="${req.rewriteUrl("~/session/info")}">Session info page</a></li>
  <li><a href="${req.rewriteUrl("~/session/info?foo=bar&foo=baz&abc=xyz")}">With other query parameters</a></li>
</ul>

<p>Note: any session query parameters are stripped out so the application never
sees them. The handler that processed this request saw
""");
    if (req.queryParams.isEmpty) {
      resp.write("no query parameters.");
    } else {
      resp.write("these query parameters: ${req.queryParams}");
    }

    resp.write("""
<h2>Session preserved across POST requests</h2>

<p>If using cookies, the session is preserved using a session cookie.
Otherwise the session needs to be preserved using a parameter.</p>

<p>For a POST request, typically this is done by rewriting the form's action URL.
So the POST request actually has both query parameters and POST parameters
(though the application never sees this, because the session parameter is
stripped out after processing it).</p>

<form method="POST" action="${req.rewriteUrl("~/session/set-name")}">
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

""");
  } else {
    resp.write("<p>No session.</p>");
  }

  resp.write("""
${homeButton(req)}
</body>
</html>
""");
  return resp;
}

//----------------------------------------------------------------

Future<Response> handleSessionSetName(Request req) async {
  var resp = new ResponseBuffered(ContentType.HTML);
  resp.write("""
<html>
<head></head>
<body>
<h1>Session: name set</h1>
""");

  if (req.session != null) {
    var newName = req.postParams["name"];
    req.session["name"] = newName;

    if (newName.isNotEmpty) {
      resp.write("<p>Your name has been set to \"${HEsc.text(newName)}\".</p>");
    } else {
      resp.write("<p>Your name has been cleared.</p>");
    }
    resp.write(
        "<p>Return to the <a href=\"${req.rewriteUrl("~/session/info")}\">session info page</a>.</p>");
  } else {
    resp.write("<p>Error: not logged in: you should not see this page.</p>");
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
  p2.get("~/session/info", handleSessionInfoPage);
  p2.post("~/session/set-name", handleSessionSetName);
  p2.get("~/session/logout", handleLogout);

  // Serve static files

  var projectDir = FileSystemEntity
      .parentOf(FileSystemEntity.parentOf(Platform.script.path));

  p2.get(
      "~/file/*",
      new StaticFiles(projectDir + "/web",
              defaultFilenames: ["index.html", "index.htm"],
              allowDirectoryListing: true,
              allowFilePathsAsDirectories: true)
          .handler);

  // Special handlers for testing

  p2.post("~/system/exceptionHandler", handleExceptionHandlers);
  p2.post("~/system/stop", handleStop);

  //--------
  // Start the server

  await webServer.run(); // this returns a Future

  mainLog.fine("finished");
}
