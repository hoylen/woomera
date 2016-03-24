// Tests the Woomera package.
//
// Copyright (c) 2015, Hoylen Sue. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.
//----------------------------------------------------------------

library main;

import 'dart:async';
import 'dart:convert' show UTF8, JSON;
import 'dart:io'
    show
        ContentType,
        HttpStatus,
        HttpClient,
        HttpClientResponse,
        InternetAddress;

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

int PORT_NUMBER = 1024;

Server webServer;
ServerPipeline pipe1;
ServerPipeline pipe2;

//================================================================
// Exception handlers

Future<Response> exceptionHandlerOnServer(
    Request req, Object exception, StackTrace st) {
  return _exceptionHandler(req, exception, st, "server");
}

//----------------------------------------------------------------

Future<Response> exceptionHandlerOnPipe1(
    Request req, Object exception, StackTrace st) async {
  if (exception is StateError) {
    return null;
  }
  return _exceptionHandler(req, exception, st, "pipe1");
}

//----------------------------------------------------------------

Future<Response> exceptionHandlerOnPipe2(
    Request req, Object exception, StackTrace st) async {
  if (exception is StateError) {
    return null;
  }
  return _exceptionHandler(req, exception, st, "pipe2");
}

//----------------------------------------------------------------

Future<Response> _exceptionHandler(
    Request req, Object exception, StackTrace st, String who) async {
  var resp = new ResponseBuffered(ContentType.HTML);
  resp.write("""
<html>
<head>
  <title>Exception</title>
</head>
<body>
<h1>Exception thrown</h1>

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
</body>
</html>
""");

  return resp;
}

//================================================================
// Test server

//----------------------------------------------------------------
/// Create and run the test Web server.
///
Server createTestServer() {
  webServer = new Server(numberOfPipelines: 2);
  // webServer.bindAddress = "127.0.0.1";
  // webServer.bindAddress = "localhost";
  webServer.bindPort = PORT_NUMBER;
  webServer.exceptionHandler = exceptionHandlerOnServer;

  // Configure the first pipeline

  pipe1 = webServer.pipelines.first;
  pipe1.exceptionHandler = exceptionHandlerOnPipe1;

  pipe1.register("GET", "/", testHandler);

  pipe1.register("GET", "/test", testHandler);
  pipe1.register("POST", "/test", testHandler);

  pipe1.register("GET", "/two/:first/:second", testHandler);
  pipe1.register("GET", "/double/:name/:name", testHandler);
  pipe1.register("GET", "/wildcard1/*", testHandler);
  pipe1.register("GET", "/wildcard2/*/foo/bar", testHandler);
  pipe1.register("GET", "/wildcard3/*/*", testHandler);
  pipe1.register("GET", "/wildcard4/*/foo/bar/*/baz", testHandler);

  pipe1.register("GET", "/system/stop", handleStop);

  // Configure the second pipeline

  pipe2 = webServer.pipelines[1];
  pipe2.exceptionHandler = exceptionHandlerOnPipe2;

  return webServer;
}

//----------------------------------------------------------------

Future<Response> testHandler(Request req) async {
  var str = "${req.method};";

  var hasParams = false;
  for (var key in req.pathParams.keys) {
    for (var value in req.pathParams.values(key, raw: true)) {
      str += "Path.${key}=${value};";
      hasParams = true;
    }
  }

  hasParams = false;
  if (req.postParams != null) {
    for (var key in req.postParams.keys) {
      for (var value in req.postParams.values(key, raw: true)) {
        str += "Post.${key}=${value};";
        hasParams = true;
      }
    }
  }

  hasParams = false;
  for (var key in req.queryParams.keys) {
    for (var value in req.queryParams.values(key, raw: true)) {
      str += "Query.${key}=${value};";
      hasParams = true;
    }
  }

  str += ".";

  var resp = new ResponseBuffered(ContentType.TEXT);
  resp.write(str);
  return resp;
}

//----------------------------------------------------------------

Future<Response> handleStop(Request req) async {
  webServer.stop(); // async

  var resp = new ResponseBuffered(ContentType.TEXT);
  resp.write("stopping");
  return resp;
}

//================================================================
// Client functions used by tests

//----------------------------------------------------------------
// GET

Future<String> getRequest(String path) async {
  // Note: must use "localhost" because "127.0.0.1" does not work: strange!

  var request = await new HttpClient().get("localhost", PORT_NUMBER, path);

  //request.headers.contentType = ContentType.HTML;

  HttpClientResponse response = await request.close();

  var contents = "";
  await for (var chunk in response.transform(UTF8.decoder)) {
    contents += chunk;
  }

  return contents;
}

//----------------------------------------------------------------
// POST

Future<String> postRequest(String path, String data) async {
  // Note: must use "localhost" becaues "127.0.0.1" does not work: strange!

  var request = await new HttpClient().post("localhost", PORT_NUMBER, path);

  request.headers.contentType = new ContentType("application", "x-www-form-urlencoded", charset: "utf-8");
  request.write(data);

  HttpClientResponse response = await request.close();

  var contents = "";
  await for (var chunk in response.transform(UTF8.decoder)) {
    contents += chunk;
  }

  return contents;
}

//================================================================
// The tests

void runTests() {
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
      var str = await getRequest("/two/alpha/beta");
      expect(str, equals("GET;Path.first=alpha;Path.second=beta;."));
    });

    test("trailing slash", () async {
      var str = await getRequest("/two/alpha/");
      expect(str, equals("GET;Path.first=alpha;Path.second=;."));
    });

    test("empty segment", () async {
      var str = await getRequest("/two//beta");
      expect(str, equals("GET;Path.first=;Path.second=beta;."));
    });

    test("repeated", () async {
      var str = await getRequest("/double/alpha/beta");
      expect(str, equals("GET;Path.name=alpha;Path.name=beta;."));
    });

    test("wildcard /x/* matching /x/", () async {
      var str = await getRequest("/wildcard1/");
      expect(str, equals("GET;Path.*=;."));
    });
    test("wildcard /x/* matching /x/A", () async {
      var str = await getRequest("/wildcard1/alpha");
      expect(str, equals("GET;Path.*=alpha;."));
    });
    test("wildcard /x/* matching /x/A/B", () async {
      var str = await getRequest("/wildcard1/alpha/beta");
      expect(str, equals("GET;Path.*=alpha/beta;."));
    });
    test("wildcard /x/* matching /x/A/B/C", () async {
      var str = await getRequest("/wildcard1/alpha/beta/gamma");
      expect(str, equals("GET;Path.*=alpha/beta/gamma;."));
    });

    test("wildcard /x/*/x/x matching /x/A/x/x", () async {
      var str = await getRequest("/wildcard2/alpha/foo/bar");
      expect(str, equals("GET;Path.*=alpha;."));
    });
    test("wildcard /x/*/x/x matching /x/A/B/x/x", () async {
      var str = await getRequest("/wildcard2/alpha/beta/foo/bar");
      expect(str, equals("GET;Path.*=alpha/beta;."));
    });
    test("wildcard /x/*/x/x matching /x/A/B/C/x/x", () async {
      var str = await getRequest("/wildcard2/alpha/beta/gamma/foo/bar");
      expect(str, equals("GET;Path.*=alpha/beta/gamma;."));
    });

    test("wildcard /x/*/* matching /x/A/B", () async {
      var str = await getRequest("/wildcard3/alpha/beta");
      expect(str, equals("GET;Path.*=alpha;Path.*=beta;."));
    });
    test("wildcard /x/*/* matching /x/A/B/C", () async {
      var str = await getRequest("/wildcard3/alpha/beta/gamma");
      expect(str, equals("GET;Path.*=alpha/beta;Path.*=gamma;."));
    });
    test("wildcard /x/*/* matching /x/A/B/C/D", () async {
      var str = await getRequest("/wildcard3/alpha/beta/gamma/delta");
      expect(str, equals("GET;Path.*=alpha/beta/gamma;Path.*=delta;."));
    });

    test("wildcard /x/*/x/x/*/x matching /x/A/x/x/B/x", () async {
      var str = await getRequest("/wildcard4/alpha/foo/bar/beta/baz");
      expect(str, equals("GET;Path.*=alpha;Path.*=beta;."));
    });
    test("wildcard /x/*/x/x/*/x matching /x/A/B/x/x/C/x", () async {
      var str = await getRequest("/wildcard4/alpha/beta/foo/bar/gamma/baz");
      expect(str, equals("GET;Path.*=alpha/beta;Path.*=gamma;."));
    });
    test("wildcard /x/*/x/x/*/x matching /x/A/B/C/x/x/D/x", () async {
      var str = await getRequest("/wildcard4/alpha/beta/gamma/foo/bar/delta/baz");
      expect(str, equals("GET;Path.*=alpha/beta/gamma;Path.*=delta;."));
    });

  });


  //----------------------------------------------------------------

  group("Query parameters", () {
    //----------------

    test("zero", () async {
      var str = await getRequest("/test");
      expect(str, equals("GET;."));
    });


    test("one", () async {
      var str = await getRequest("/test?foo=bar");
      expect(str, equals("GET;Query.foo=bar;."));
    });
    test("two", () async {
      var str = await getRequest("/test?foo=bar&baz=1");
      expect(str, equals("GET;Query.foo=bar;Query.baz=1;."));
    });
    test("repeated", () async {
      var str = await getRequest("/test?foo=bar&foo=1");
      expect(str, equals("GET;Query.foo=bar;Query.foo=1;."));
    });
  });

  //----------------------------------------------------------------

  group("Post parameters", () {
    //----------------

    test("zero", () async {
      var str = await postRequest("/test", "");
      expect(str, equals("POST;."));
    });

    test("one", () async {
      var str = await postRequest("/test", "foo=bar");
      expect(str, equals("POST;Post.foo=bar;."));
    });

    test("two", () async {
      var str = await postRequest("/test", "foo=bar&baz=1");
      expect(str, equals("POST;Post.foo=bar;Post.baz=1;."));
    });

    test("repeated", () async {
      var str = await postRequest("/test", "foo=bar&foo=1");
      expect(str, equals("POST;Post.foo=bar;Post.foo=1;."));
    });
  });

  //----------------------------------------------------------------
  // Important: this must be the last test, to stop the server.

  group("End of tests", () {
    //----------------

    test("stopping server", () async {
      var str = await getRequest("/system/stop");
      expect(str, equals("stopping"));
    });
  });
}

//================================================================

void loggingSetup() {
  // Set up logging

  hierarchicalLoggingEnabled = true;
  Logger.root.onRecord.listen((LogRecord rec) {
    print('${rec.time}: ${rec.loggerName}: ${rec.level.name}: ${rec.message}');
  });

  Logger.root.level = Level.OFF;
  Logger.root.level = Level.ALL;

  new Logger("main").level = Level.ALL;
  new Logger("woomera.server").level = Level.ALL;
  new Logger("woomera.request").level = Level.ALL;
  new Logger("woomera.response").level = Level.ALL;
}

//----------------------------------------------------------------

Future main() async {
  //loggingSetup();

  var server = createTestServer();
  var numProcessedFuture = server.run();

  var _expiryTimer = new Timer(new Duration(seconds: 1), () {
    new Logger("main").info("running tests: started");
    runTests();
    new Logger("main").info("running tests: finished");
  });

  new Logger("main").info("waiting for server to stop");
  var _ = await numProcessedFuture;
}
