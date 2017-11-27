// Tests the Woomera package.
//
// Copyright (c) 2015, Hoylen Sue. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.
//----------------------------------------------------------------

library main;

import 'dart:async';
import 'dart:convert' show UTF8;
import 'dart:io' show ContentType, HttpClient;

import 'package:test/test.dart';
import 'package:logging/logging.dart';

import 'package:woomera/woomera.dart';

// NOTE: currently these tests must be run as a Dart program:
//     dart woomera_test.dart
//
// Running them using "pub run test" does not work.

//----------------------------------------------------------------
// Constants

//================================================================
// Globals

/// Port to listen on
int portNumber = 1024;

/// The Web server
Server webServer;

/// A pipeline
ServerPipeline pipe1;

/// Another pipeline
ServerPipeline pipe2;

//================================================================
// Exception handlers

Future<Response> _exceptionHandlerOnServer(
    Request req, Object exception, StackTrace st) {
  assert(req != null);
  return _exceptionHandler(req, exception, st, "server");
}

//----------------------------------------------------------------

Future<Response> _exceptionHandlerOnPipe1(
    Request req, Object exception, StackTrace st) async {
  if (exception is StateError) {
    return null;
  }
  return _exceptionHandler(req, exception, st, "pipe1");
}

//----------------------------------------------------------------

Future<Response> _exceptionHandlerOnPipe2(
    Request req, Object exception, StackTrace st) async {
  if (exception is StateError) {
    return null;
  }
  return _exceptionHandler(req, exception, st, "pipe2");
}

//----------------------------------------------------------------

Future<Response> _exceptionHandler(
    Request req, Object exception, StackTrace st, String who) async {
  final resp = new ResponseBuffered(ContentType.HTML)..write("""
<html>
<head>
  <title>Exception</title>
</head>
<body>
<h1>Exception thrown</h1>

An exception was thrown and was handled by the <strong>$who</strong> exception handler.

<h2>Exception</h2>

<p>Exception object type: <code>${exception.runtimeType}</code></p>
<p>String representation of object: <strong>$exception</strong></p>
""");

  if (st != null) {
    resp.write("""
<h2>Stack trace</h2>
<pre>
$st
</pre>
    """);
  }
  resp.write("""
</body>
</html>
""");

  return resp;
}

//================================================================
// Test server

//----------------------------------------------------------------

Server _createTestServer() {
  webServer = new Server(numberOfPipelines: 2)
    // webServer.bindAddress = "127.0.0.1";
    // webServer.bindAddress = "localhost";
    ..bindPort = portNumber
    ..exceptionHandler = _exceptionHandlerOnServer;

  // Configure the first pipeline

  pipe1 = webServer.pipelines.first
    ..exceptionHandler = _exceptionHandlerOnPipe1
    ..register("GET", "~/", testHandler)
    ..register("GET", "~/test", testHandler)
    ..register("POST", "~/test", testHandler)
    ..register("GET", "~/two/:first/:second", testHandler)
    ..register("GET", "~/double/:name/:name", testHandler)
    ..register("GET", "~/wildcard1/*", testHandler)
    ..register("GET", "~/wildcard2/*/foo/bar", testHandler)
    ..register("GET", "~/wildcard3/*/*", testHandler)
    ..register("GET", "~/wildcard4/*/foo/bar/*/baz", testHandler)
    ..register("GET", "~/system/stop", handleStop);

  // Configure the second pipeline

  pipe2 = webServer.pipelines[1]..exceptionHandler = _exceptionHandlerOnPipe2;

  return webServer;
}

//----------------------------------------------------------------
/// Handler
///
Future<Response> testHandler(Request req) async {
  final buf = new StringBuffer("${req.request.method};");

  for (var key in req.pathParams.keys) {
    for (var value in req.pathParams.values(key, raw: true)) {
      buf.write("Path.$key=$value;");
    }
  }

  if (req.postParams != null) {
    for (var key in req.postParams.keys) {
      for (var value in req.postParams.values(key, raw: true)) {
        buf.write("Post.$key=$value;");
      }
    }
  }

  for (var key in req.queryParams.keys) {
    for (var value in req.queryParams.values(key, raw: true)) {
      buf.write("Query.$key=$value;");
    }
  }

  buf.write(".");

  final resp = new ResponseBuffered(ContentType.TEXT)..write(buf.toString());
  return resp;
}

//----------------------------------------------------------------
/// Handler for stopping the server
///
Future<Response> handleStop(Request req) async {
  await webServer.stop(); // async

  final resp = new ResponseBuffered(ContentType.TEXT)..write("stopping");
  return resp;
}

//================================================================
// Client functions used by tests

//----------------------------------------------------------------
/// GET

Future<String> getRequest(String path) async {
  // Note: must use "localhost" because "127.0.0.1" does not work: strange!

  final request = await new HttpClient().get("localhost", portNumber, path);

  //request.headers.contentType = ContentType.HTML;

  final response = await request.close();

  final contents = new StringBuffer();
  await for (var chunk in response.transform(UTF8.decoder)) {
    contents.write(chunk);
  }

  return contents.toString();
}

//----------------------------------------------------------------
/// POST

Future<String> postRequest(String path, String data) async {
  // Note: must use "localhost" becaues "127.0.0.1" does not work: strange!

  final request = await new HttpClient().post("localhost", portNumber, path);

  request.headers.contentType =
      new ContentType("application", "x-www-form-urlencoded", charset: "utf-8");
  request.write(data);

  final response = await request.close();

  final contents = new StringBuffer();
  await for (var chunk in response.transform(UTF8.decoder)) {
    contents.write(chunk);
  }

  return contents.toString();
}

//================================================================
/// The tests

void _runTests(Future<int> numProcessedFuture) {
  //----------------------------------------------------------------
  // Check expected branches are present in the LDAP directory

  group("Setup", () {
    //----------------

    test("pipeline", () async {
      expect(webServer.pipelines.length, equals(2));
    });
  });

  //----------------------------------------------------------------

  group("Path parameters", () {
    //----------------

    test("basic match", () async {
      final str = await getRequest("/two/alpha/beta");
      expect(str, equals("GET;Path.first=alpha;Path.second=beta;."));
    });

    test("trailing slash", () async {
      final str = await getRequest("/two/alpha/");
      expect(str, equals("GET;Path.first=alpha;Path.second=;."));
    });

    test("empty segment", () async {
      final str = await getRequest("/two//beta");
      expect(str, equals("GET;Path.first=;Path.second=beta;."));
    });

    test("repeated", () async {
      final str = await getRequest("/double/alpha/beta");
      expect(str, equals("GET;Path.name=alpha;Path.name=beta;."));
    });

    test("wildcard /x/* matching /x/", () async {
      final str = await getRequest("/wildcard1/");
      expect(str, equals("GET;Path.*=;."));
    });
    test("wildcard /x/* matching /x/A", () async {
      final str = await getRequest("/wildcard1/alpha");
      expect(str, equals("GET;Path.*=alpha;."));
    });
    test("wildcard /x/* matching /x/A/B", () async {
      final str = await getRequest("/wildcard1/alpha/beta");
      expect(str, equals("GET;Path.*=alpha/beta;."));
    });
    test("wildcard /x/* matching /x/A/B/C", () async {
      final str = await getRequest("/wildcard1/alpha/beta/gamma");
      expect(str, equals("GET;Path.*=alpha/beta/gamma;."));
    });

    test("wildcard /x/*/x/x matching /x/A/x/x", () async {
      final str = await getRequest("/wildcard2/alpha/foo/bar");
      expect(str, equals("GET;Path.*=alpha;."));
    });
    test("wildcard /x/*/x/x matching /x/A/B/x/x", () async {
      final str = await getRequest("/wildcard2/alpha/beta/foo/bar");
      expect(str, equals("GET;Path.*=alpha/beta;."));
    });
    test("wildcard /x/*/x/x matching /x/A/B/C/x/x", () async {
      final str = await getRequest("/wildcard2/alpha/beta/gamma/foo/bar");
      expect(str, equals("GET;Path.*=alpha/beta/gamma;."));
    });

    test("wildcard /x/*/* matching /x/A/B", () async {
      final str = await getRequest("/wildcard3/alpha/beta");
      expect(str, equals("GET;Path.*=alpha;Path.*=beta;."));
    });
    test("wildcard /x/*/* matching /x/A/B/C", () async {
      final str = await getRequest("/wildcard3/alpha/beta/gamma");
      expect(str, equals("GET;Path.*=alpha/beta;Path.*=gamma;."));
    });
    test("wildcard /x/*/* matching /x/A/B/C/D", () async {
      final str = await getRequest("/wildcard3/alpha/beta/gamma/delta");
      expect(str, equals("GET;Path.*=alpha/beta/gamma;Path.*=delta;."));
    });

    test("wildcard /x/*/x/x/*/x matching /x/A/x/x/B/x", () async {
      final str = await getRequest("/wildcard4/alpha/foo/bar/beta/baz");
      expect(str, equals("GET;Path.*=alpha;Path.*=beta;."));
    });
    test("wildcard /x/*/x/x/*/x matching /x/A/B/x/x/C/x", () async {
      final str = await getRequest("/wildcard4/alpha/beta/foo/bar/gamma/baz");
      expect(str, equals("GET;Path.*=alpha/beta;Path.*=gamma;."));
    });
    test("wildcard /x/*/x/x/*/x matching /x/A/B/C/x/x/D/x", () async {
      final str =
          await getRequest("/wildcard4/alpha/beta/gamma/foo/bar/delta/baz");
      expect(str, equals("GET;Path.*=alpha/beta/gamma;Path.*=delta;."));
    });
  });

  //----------------------------------------------------------------

  group("Query parameters", () {
    //----------------

    test("zero", () async {
      final str = await getRequest("/test");
      expect(str, equals("GET;."));
    });

    test("one", () async {
      final str = await getRequest("/test?foo=bar");
      expect(str, equals("GET;Query.foo=bar;."));
    });
    test("two", () async {
      final str = await getRequest("/test?foo=bar&baz=1");
      expect(str, equals("GET;Query.foo=bar;Query.baz=1;."));
    });
    test("repeated", () async {
      final str = await getRequest("/test?foo=bar&foo=1");
      expect(str, equals("GET;Query.foo=bar;Query.foo=1;."));
    });
  });

  //----------------------------------------------------------------

  group("Post parameters", () {
    //----------------

    test("zero", () async {
      final str = await postRequest("/test", "");
      expect(str, equals("POST;."));
    });

    test("one", () async {
      final str = await postRequest("/test", "foo=bar");
      expect(str, equals("POST;Post.foo=bar;."));
    });

    test("two", () async {
      final str = await postRequest("/test", "foo=bar&baz=1");
      expect(str, equals("POST;Post.foo=bar;Post.baz=1;."));
    });

    test("repeated", () async {
      final str = await postRequest("/test", "foo=bar&foo=1");
      expect(str, equals("POST;Post.foo=bar;Post.foo=1;."));
    });
  });

  //----------------------------------------------------------------
  // Important: this must be the last test, to stop the server.
  //
  // If the server is not stopped, this program will not halt when run as a
  // Dart program, but will halt when run using "pub run test".

  group("End of tests", () {
    //----------------

    test("stopping server", () async {
      final str = await getRequest("/system/stop");
      expect(str, equals("stopping"));

      // Wait for server to stop
      final num = await numProcessedFuture;
      new Logger("main").info("server stopped: requests processed: $num");
    });
  });
}

//================================================================
/// Set up logging
///
void loggingSetup() {
  // Set up logging

  hierarchicalLoggingEnabled = true;
  Logger.root.onRecord.listen((rec) {
    print('${rec.time}: ${rec.loggerName}: ${rec.level.name}: ${rec.message}');
  });

  //Logger.root.level = Level.OFF;
  Logger.root.level = Level.ALL;

  new Logger("main").level = Level.ALL;
  new Logger("woomera.server").level = Level.ALL;
  new Logger("woomera.request").level = Level.ALL;
  new Logger("woomera.response").level = Level.ALL;
}

//----------------------------------------------------------------

Future main() async {
  // loggingSetup(); // TODO: Uncomment if you want logging

  // Start the server

  final numProcessedFuture = _createTestServer().run();

  // Run the tests

  _runTests(numProcessedFuture);
}
