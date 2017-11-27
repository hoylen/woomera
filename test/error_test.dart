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

//----------------------------------------------------------------
// Constants

//================================================================
// Globals

/// Port to listen on
const int portNumber = 1025;

/// Woomera Web server
Server webServer;

//================================================================
/// Test exception
///
/// This is the internal exception that will be raised for testing when
/// exceptions are raised inside handlers.

class MyException implements Exception {
  /// Name of exception
  String message;

  /// Constructor
  ///
  MyException(this.message);

  /// String representation
  @override
  String toString() => message;
}

//================================================================
// Handlers

/// Handler to test exception handling.
///
Future<Response> myExceptionHandler(
    Request req, Object exception, StackTrace st) async {
  final resp = new ResponseBuffered(ContentType.TEXT)
    ..write("Exception handler caught: $exception\n")
    ..write("Stack trace:\n$st");
  return resp;
}

//----------------------------------------------------------------
/// Request handler for /
///
Future<Response> handlerRoot(Request req) async {
  final resp = new ResponseBuffered(ContentType.TEXT)
    ..write("Error/Exception test\n");
  return resp;
}

//----------------------------------------------------------------
/// Request handler for /test1
///
/// This handler throws an exception, to show how the pipeline/server deals with
/// exceptions.
///
Future<Response> handler1(Request req) async {
  final _ = new ResponseBuffered(ContentType.TEXT)..write("Test 1");
  throw new MyException("test1");
}

//----------------------------------------------------------------
/// Request handler for /test2
///
/// This handler uses "completeError" to raise an error that is detected by
/// an "onError" callback, to show how the pipeline/server deals with them.
///
Future<Response> handler2(Request req) {
  final completer = new Completer<Response>();

  new Timer(const Duration(seconds: 1), () {
    completer.completeError("test2");
  });

  return completer.future;
}

//----------------------------------------------------------------
/// Request handler for /test3
///
/// This handler uses both "completeError" and throw to doubly raise an
/// exception and "onError" callback.
///
Future<Response> handler3(Request req) {
  final completer = new Completer<Response>();

  new Timer(const Duration(seconds: 1), () {
    completer.completeError("test3a");
    throw new MyException("test3b");
  });

  return completer.future;
}

//----------------------------------------------------------------
/// Request handler to stop the Web server.
///
Future<Response> handlerStop(Request req) async {
  await webServer.stop(); // async

  final resp = new ResponseBuffered(ContentType.TEXT)..write("stopping");
  return resp;
}

//----------------------------------------------------------------
// Create the test server.

Server _createTestServer() {
  // Create a test Web server that listens on localhost

  webServer = new Server(numberOfPipelines: 1)
    ..bindPort = portNumber
    ..exceptionHandler = myExceptionHandler;

  webServer.pipelines.first
    ..register("GET", "~/", handlerRoot)
    ..register("GET", "~/test1", handler1)
    ..register("GET", "~/test2", handler2)
    ..register("GET", "~/test3", handler3)
    ..register("GET", "~/stop", handlerStop);

  return webServer;
}

//================================================================
/// The tests
///
void runTests(Future<int> numProcessedFuture) {
  //----------------

  test("Exception caught", () async {
    final str = await getRequest("/test1");
    expect(str, startsWith("Exception handler caught: test1\n"));
  });

  //----------------

  test("onError caught", () async {
    final str = await getRequest("/test2");
    expect(str, startsWith("Exception handler caught: test2\n"));
  });

  //----------------

  test("Exception and onError caught", () async {
    final str = await getRequest("/test3");
    expect(str, startsWith("Exception handler caught: test3a\n"));
  });

  //----------------

  test("server still running", () async {
    final str = await getRequest("/");
    expect(str, startsWith("Error/Exception test\n"));
  });

  //----------------

  test("stopping server", () async {
    final str = await getRequest("/stop");
    expect(str, startsWith("stopping"));

    // Wait for server to stop
    final num = await numProcessedFuture;
    new Logger("main").info("server stopped: requests processed: $num");
  });
}

//================================================================

//----------------------------------------------------------------
/// GET
///
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

  runTests(numProcessedFuture);
}
