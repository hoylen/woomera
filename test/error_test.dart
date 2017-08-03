// Tests the Woomera package.
//
// Copyright (c) 2015, Hoylen Sue. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.
//----------------------------------------------------------------

library main;

import 'dart:async';
import 'dart:convert' show UTF8;
import 'dart:io' show ContentType, HttpClient, HttpClientResponse, stderr, exit;

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

//================================================================
// Test server

//----------------------------------------------------------------
/// Create and run the test Web server.
///
Server createTestServer() {
  webServer = new Server(numberOfPipelines: 1);
  // webServer.bindAddress = "127.0.0.1";
  // webServer.bindAddress = "localhost";
  webServer.bindPort = PORT_NUMBER;
  webServer.exceptionHandler = myExceptionHandler;

  // Configure the first pipeline

  var pipeline = webServer.pipelines.first;

  pipeline.register("GET", "~/", handlerRoot);

  pipeline.register("GET", "~/test1", handler1);
  pipeline.register("GET", "~/test2", handler2);

  pipeline.register("GET", "~/stop", handlerStop);

  return webServer;
}

//================================================================
// Handlers

Future<Response> myExceptionHandler(
    Request req, Object exception, StackTrace st) {
  var resp = new ResponseBuffered(ContentType.TEXT);
  resp.write("Exception handler caught: $exception\n$st");
  return resp;
}
//----------------------------------------------------------------

Future<Response> handlerRoot(Request req) async {
  var resp = new ResponseBuffered(ContentType.TEXT);
  resp.write("Error/Exception test");
  return resp;
}

//----------------------------------------------------------------

Future<Response> handler1(Request req) async {
  var resp = new ResponseBuffered(ContentType.TEXT);
  resp.write("Test 1");
  throw "test1";
}

//----------------------------------------------------------------

Future<Response> handler2(Request req) {
  var completer = new Completer();

  new Timer(new Duration(seconds: 0), () {
    completer.completeError("test2");
    throw new StateError("bar");
  });

  return completer.future;
}

//----------------------------------------------------------------

Future<Response> handlerStop(Request req) async {
  webServer.stop(); // async

  var resp = new ResponseBuffered(ContentType.TEXT);
  resp.write("stopping");
  return resp;
}

//================================================================
// The tests

void runTests() {
  //----------------

  test("Exception caught", () async {
    var str = await getRequest("/test1");
    expect(str, startsWith("Exception handler caught: test1\n"));
  });

  //----------------

  test("onError caught", () async {
    var str = await getRequest("/test2");
    expect(str, startsWith("Exception handler caught: test2\n"));
  });

  //----------------

  test("stopping server", () async {
    var str = await getRequest("/stop");
    expect(str, equals("stopping"));
  });
}

//================================================================

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

//================================================================

void loggingSetup() {
  // Set up logging

  hierarchicalLoggingEnabled = true;
  Logger.root.onRecord.listen((LogRecord rec) {
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

  var mainLogger = new Logger("main");

  // Start the test server

  var server = createTestServer();
  var numProcessedFuture = server.run();

  // Run the tests

  new Timer(new Duration(seconds: 1), () {
    // Run the tests, after waiting a short time for the server to get started
    mainLogger.info("running tests: started");
    runTests();
    mainLogger.info("running tests: finished");
  });

  // Stop the test server

  var num = await numProcessedFuture;
  mainLogger.info("server to stopped: number of requests processed: $num");
}
