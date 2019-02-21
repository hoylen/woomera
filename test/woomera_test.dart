// Tests the Woomera package.
//
// Copyright (c) 2015, Hoylen Sue. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.
//----------------------------------------------------------------

library main;

import 'dart:async';
import 'dart:convert' show utf8;
import 'dart:io' show ContentType, HttpClient;

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
int portNumber = 1024;

//----------------------------------------------------------------
// Internal

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
  final resp = new ResponseBuffered(ContentType.text)
    ..write("$who exception handler (${exception.runtimeType}) $exception\n");

  if (st != null) {
    resp.write("Stack trace:\n$st\n");
  }

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
    ..get("~/test", testHandler)
    ..post("~/test", testHandler)
    ..put("~/test", testHandler)
    ..patch("~/test", testHandler)
    ..delete("~/test", testHandler)
    ..register("GET", "~/two/:first/:second", testHandler)
    ..register("GET", "~/double/:name/:name", testHandler)
    ..register("GET", "~/wildcard1/*", testHandler)
    ..register("GET", "~/wildcard2/*/foo/bar", testHandler)
    ..register("GET", "~/wildcard3/*/*", testHandler)
    ..register("GET", "~/wildcard4/*/foo/bar/*/baz", testHandler)
    ..register("GET", "~/special/:mode", _specialHandler)
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

  final resp = new ResponseBuffered(ContentType.text)..write(buf.toString());
  return resp;
}

//--------

const _modeParams = 'param';

Future<Response> _specialHandler(Request req) async {
  var message = 'ok';

  final mode = req.pathParams['mode'];
  switch (mode) {
    case _modeParams:
      if (req.queryParams.isEmpty) {
        message = 'error: query parameters reported as empty';
      }
      if (req.queryParams.length != 5) {
        message = 'error: number of query parameters != 5';
      }

      final a = req.queryParams['a'];
      if (a != '1') {
        message = 'mismatch a';
      }
      var bChecked = false;
      try {
        final b = req.queryParams['b'];
        if (b != '') {
          // in production mode, multi-values returns empty string
          message = 'mismatch b: multivalue did not return empty string';
        }
        bChecked = true;
        // ignore: avoid_catching_errors
      } on AssertionError {
        bChecked = true; // in checked mode, an assertion will fail
      }
      if (!bChecked) {
        message = "b: did not detect multiple values";
      }
      final rawB = req.queryParams.values('b');
      if (rawB.length != 2) {
        message = 'b: did not get 2 values';
      }

      final blankValue = req.queryParams['blankValue'];
      if (blankValue != '') {
        message = 'mismatch blankValue: $blankValue';
      }

      final noValue = req.queryParams['novalue'];
      if (noValue != '') {
        message = 'mismatch noValue: $noValue';
      }

      final noKey = req.queryParams[''];
      if (noKey != 'noKey') {
        message = 'mismatched noKey: $noKey';
      }

      final str = req.queryParams.toString();
      if (str !=
          '=["noKey"], a=["1"], b=["x", "y"], blankValue=[""], noValue=[""]') {
        message = 'toString: $str';
      }
      break;
  }

  final resp = new ResponseBuffered(ContentType.text)..write(message);
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
/// GET

Future<String> getRequest(String path) async {
  // Note: must use "localhost" because "127.0.0.1" does not work: strange!

  final request = await new HttpClient().get("localhost", portNumber, path);

  //request.headers.contentType = ContentType.html;

  final response = await request.close();

  final contents = new StringBuffer();
  // ignore: prefer_foreach
  await for (var chunk in response.transform(utf8.decoder)) {
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
  // ignore: prefer_foreach
  await for (var chunk in response.transform(utf8.decoder)) {
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

    test("pipeline 1 has expected methods", () async {
      final methods = webServer.pipelines[0].methods();
      expect(methods.length, equals(5));
      expect(methods.contains("GET"), isTrue);
      expect(methods.contains("POST"), isTrue);
      expect(methods.contains("PUT"), isTrue);
      expect(methods.contains("PATCH"), isTrue);
      expect(methods.contains("DELETE"), isTrue);
    });

    test("pipeline 2 has expected methods", () async {
      final methods = webServer.pipelines[1].methods();
      expect(methods.length, equals(0));
      //expect(methods.contains("GET"), isTrue);
    });

    //----------------
    // Attempts to call register incorrectly

    final pipeline1 = webServer.pipelines.first;

    test("register with null for method", () {
      expect(
          () => pipeline1.register(null, "~/bad", testHandler),
          throwsA(predicate<dynamic>((Object e) =>
              e is ArgumentError && e.message == 'Must not be null')));
    });

    test("register with empty string for method", () {
      expect(
          () => pipeline1.register("", "~/bad", testHandler),
          throwsA(predicate<dynamic>((Object e) =>
              e is ArgumentError && e.message == 'Empty string')));
    });

    test("register with null handler", () {
      expect(
          () => pipeline1.register("GET", "~/bad", null),
          throwsA(predicate<dynamic>((Object e) =>
              e is ArgumentError && e.message == 'Must not be null')));
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

  group("Not found", () {
    //----------------

    test("no match", () async {
      final str = await postRequest("/unknown", "");
      expect(
          str,
          equals(
              "server exception handler (NotFoundException) path not supported\n"));
    });
  });

  //----------------------------------------------------------------

  group("Special:", () {
    //----------------

    test("$_modeParams", () async {
      final str = await getRequest(
          "/special/$_modeParams?=noKey&a=1&b=x&b=y&blankValue=&noValue");
      expect(str, equals("ok"));
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
