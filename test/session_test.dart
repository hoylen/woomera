// Tests sessions in the Woomera package.
//
// Copyright (c) 2017, Hoylen Sue. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.
//----------------------------------------------------------------

library main;

import 'dart:async';
import 'dart:convert' show utf8;
import 'dart:io' show ContentType, HttpClient, HttpStatus;

import 'package:test/test.dart';
import 'package:logging/logging.dart';

import 'package:woomera/woomera.dart';

//================================================================
// Globals

//----------------------------------------------------------------
// Configuration

/// Set to true to use this Web server with a Web browser. False runs tests.
const bool interactiveMode = false;

/// Enable or disable logging
const bool doLogging = false;

/// Port to listen on
const int portNumber = 1026;

/// How long sessions stay active
const Duration defaultSessionTimeout = const Duration(minutes: 1);

//----------------------------------------------------------------
// Internal

/// The Web server
Server webServer;

Logger _log = new Logger("main");

//================================================================
// Test server

const _htmlHeader = """
<html>
<head>
  <title>Woomera: session test</title>
  <style type='text/css'>
  body {
    background: lightblue;
    font-family: sans-serif;
  }
  </style>
</head>
<body>
<h1>Session test</h1>
""";

const _pathHome = "~/session";
const _pathLogin = "~/session/login";
const _pathLogout = "~/session/logout";

//----------------------------------------------------------------

Server _createTestServer() {
  webServer = new Server()..bindPort = portNumber;

  // Configure the pipeline

  webServer.pipelines.first
    ..get(_pathHome, _sessionStatus)
    ..post(_pathLogin, _sessionStart)
    ..post(_pathLogout, _sessionStop)
    ..register("GET", "~/system/stop", handleStop);

  return webServer;
}

//----------------------------------------------------------------
/// Handler for home page
///
Future<Response> _sessionStatus(Request req) async {
  final resp = new ResponseBuffered(ContentType.html)..write(_htmlHeader);
  final session = req.session;

  if (session == null) {
    resp.write("""<p>No session</p>
    <form method="POST" action="${req.ura(_pathLogin)}">
      <input type='submit' value='Login'>
    </form>""");
  } else {
    resp.write("""<p>Session: ${session.id}</p>
    <p>Session will timeout at: ${new DateTime.now().add(session.timeout)}</p>
    <form method="POST" action="${req.ura(_pathLogout)}">
      <input type='submit' value='Logout'>
    </form>""");
  }

  resp.write("\n</body>\n</html>\n");

  return resp;
}

//----------------------------------------------------------------
/// Handler for starting a session

Future<Response> _sessionStart(Request req) async {
  final resp = new ResponseBuffered(ContentType.html)..write(_htmlHeader);

  if (req.session == null) {
    // Create a new sesson object and associate it with the user's browser.
    // This is done by setting the `req.session` member on the Request
    // even though the actual mechanism of maintaining the session is done
    // by the HTTP response (either with cookies or URL rewriting of links
    // in its HTML content).
    req.session = new Session(req.server, defaultSessionTimeout);
    resp.write("<p>OK</p>");
  } else {
    resp
      ..status = HttpStatus.badRequest // 400
      ..write("<p>Error: already logged in.</p>");
  }

  // Note: is is important to create the HREF URL by calling `req.ura`
  // or `req.rewriteURL` so that sessions are preserved by URL rewriting if
  // cookies cannot be used.

  resp.write("<a href='${req.ura(_pathHome)}'>Home</a>\n</body>\n</html>\n");

  return resp;
}

//----------------------------------------------------------------
/// Handler for stopping a session

Future<Response> _sessionStop(Request req) async {
  final resp = new ResponseBuffered(ContentType.html)..write(_htmlHeader);

  if (req.session != null) {
    // Terminate the session
    await req.session.terminate();
    req.session = null;
    resp.write("<p>Done</p>");
  } else {
    resp
      ..status = HttpStatus.badRequest // 400
      ..write("<p>Error: not logged in.</p>");
  }

  // Note: rewriting the URL does nothing in this situation, since we are
  // terminating the session. But for consistency, we call `req.ura` on all
  // URLs without worrying about which ones are needed or not.

  resp.write("<a href='${req.ura(_pathHome)}'>Home</a>\n</body>\n</html>\n");

  return resp;
}

//----------------------------------------------------------------
/// Handler for stopping the server
///
/// This is to stop the server after the tests have completed.
/// Normally, servers should not have such an operation.

Future<Response> handleStop(Request req) async {
  await webServer.stop(); // async

  final resp = new ResponseBuffered(ContentType.text)..write("stopping");
  return resp;
}

//================================================================
// Client functions used by tests

//----------------------------------------------------------------
/// Result of a HTTP request
///
class TestResponse {
  /// Constructor
  TestResponse(this.status, this.contents);

  /// HTTP status code
  int status;

  /// Contents of HTTP response
  String contents;
}
//----------------------------------------------------------------
/// GET

Future<TestResponse> getRequest(String path) async {
  // Note: must use "localhost" because "127.0.0.1" does not work: strange!

  final request = await new HttpClient().get("localhost", portNumber, path);

  //request.headers.contentType = ContentType.html;

  final response = await request.close();

  final contents = new StringBuffer();
  // ignore: prefer_foreach
  await for (var chunk in utf8.decoder.bind(response)) {
    contents.write(chunk);
  }

  return new TestResponse(response.statusCode, contents.toString());
}

//----------------------------------------------------------------
/// POST

Future<TestResponse> postRequest(String path, String data) async {
  // Note: must use "localhost" becaues "127.0.0.1" does not work: strange!

  final request = await new HttpClient().post("localhost", portNumber, path);

  request.headers.contentType =
      new ContentType("application", "x-www-form-urlencoded", charset: "utf-8");
  request.write(data);

  final response = await request.close();

  final contents = new StringBuffer();
  // ignore: prefer_foreach
  await for (var chunk in utf8.decoder.bind(response)) {
    contents.write(chunk);
  }

  return new TestResponse(response.statusCode, contents.toString());
}

//================================================================
/// The tests

void _runTests(Future<int> numProcessedFuture) {
  //----------------------------------------------------------------
  // Check expected branches are present in the LDAP directory

  group("Login and logout", () {
    //----------------

    test("URL rewriting", () async {
      // Status page OK
      var r = await getRequest("/session");
      expect(r.status, equals(HttpStatus.ok));

      // Logout without a session should fail
      r = await postRequest("/session/logout", "");
      expect(r.status, equals(HttpStatus.badRequest));

      // Login
      r = await postRequest("/session/login", "");
      expect(r.status, equals(HttpStatus.ok));

      // Extract the URL rewritten home link
      const homePrefix = "<a href='";
      const homeSuffix = "'>Home</a>";
      final h1 = r.contents.substring(
          r.contents.indexOf(homePrefix) + homePrefix.length,
          r.contents.indexOf(homeSuffix));
      _log.info("Home URL after login: $h1");
      expect(h1, startsWith("/session?wSession="));

      // Get the status page
      r = await getRequest(h1);
      expect(r.status, equals(HttpStatus.ok));
      expect(r.contents.contains("<p>Session: "), isTrue);

      // Extract the URL rewritten logout link
      const logoutPrefix = 'action="';
      const logoutSuffix = '">';
      final a = r.contents
          .substring(r.contents.indexOf(logoutPrefix) + logoutPrefix.length);
      final b = a.substring(0, a.indexOf(logoutSuffix));
      _log.info("Logout URL: $b");

      // Logout
      r = await postRequest(b, "");
      expect(r.status, equals(HttpStatus.ok));

      // Extract the URL rewritten home link (after logout)
      final h2 = r.contents.substring(
          r.contents.indexOf(homePrefix) + homePrefix.length,
          r.contents.indexOf(homeSuffix));
      _log.info("Home URL after logout: $h2");
      expect(h2, equals("/session"));
    });
  });

  //----------------------------------------------------------------
  // Important: this must be the last test, to stop the server.
  //
  // If the server is not stopped, this program will not halt when run as a
  // Dart program, but does halt when run using "pub run test".

  group("End of tests", () {
    //----------------

    test("stopping server", () async {
      final r = await getRequest("/system/stop");
      expect(r.status, equals(HttpStatus.ok));

      // Wait for server to stop
      final num = await numProcessedFuture;
      _log.info("server stopped: requests processed: $num");
    });
  });
}

//================================================================
/// Set up logging
///
void loggingSetup() {
  hierarchicalLoggingEnabled = true;
  Logger.root.onRecord.listen((rec) {
    print('${rec.time}: ${rec.loggerName}: ${rec.level.name}: ${rec.message}');
  });

  //Logger.root.level = Level.OFF;
  Logger.root.level = Level.ALL;

  new Logger("main").level = Level.ALL;
  new Logger("woomera").level = Level.INFO;
  //new Logger("woomera.server").level = Level.ALL;
  //new Logger("woomera.request").level = Level.ALL;
  //new Logger("woomera.response").level = Level.ALL;
}

//----------------------------------------------------------------

Future main() async {
  if (doLogging) {
    loggingSetup();
  }

  final numProcessedFuture = _createTestServer().run();

  if (!interactiveMode) {
    _runTests(numProcessedFuture);
  } else {
    print("Service running at http://localhost:$portNumber/session");
  }
}
