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
  /// Constructor

  MyException(this.message);

  /// Name of exception

  String message;

  /// String representation

  @override
  String toString() => message;
}

//================================================================
// Handlers

const String _caseExceptionHandlerToFail = 'please throw an exception';

/// Handler to test exception handling.
///
Future<Response> serverExceptionHandler(
    Request req, Object exception, StackTrace st) async {
  if (exception is MyException) {
    if (exception.message == _caseExceptionHandlerToFail) {
      throw new StateError("exception inside exception handler");
    }
  }
  final resp = new ResponseBuffered(ContentType.text)
    ..write("Server caught: $exception\n")
    ..write("Stack trace:\n$st");
  return resp;
}

/// Handler to test exception handling.
///
Future<Response> pipelineExceptionHandler(
    Request req, Object exception, StackTrace st) async {
  if (exception is MyException) {
    if (exception.message == _caseExceptionHandlerToFail) {
      throw new StateError("exception inside exception handler");
    }
  }
  final resp = new ResponseBuffered(ContentType.text)
    ..write("Pipeline caught: $exception\n")
    ..write("Stack trace:\n$st");
  return resp;
}

//----------------------------------------------------------------
/// Request handler for /
///
Future<Response> handlerRoot(Request req) async {
  final resp = new ResponseBuffered(ContentType.text)
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
  final _ = new ResponseBuffered(ContentType.text)..write("Test 1");
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
/// Request handler for /test4
///
/// This handler raises an exception which causes the exception handler
/// to raise an exception.
///
Future<Response> handler4(Request req) {
  throw new MyException(_caseExceptionHandlerToFail);
}

//----------------------------------------------------------------
/// Request handler to stop the Web server.
///
/// This is to stop the server after the tests have completed.
/// Normally, servers should not have such an operation.

Future<Response> handlerStop(Request req) async {
  await webServer.stop(); // async

  final resp = new ResponseBuffered(ContentType.text)..write("stopping");
  return resp;
}

//----------------------------------------------------------------
// Create the test server.

Server _createTestServer() {
  // Create a test Web server that listens on localhost

  webServer = new Server(numberOfPipelines: 1)
    ..bindPort = portNumber
    ..exceptionHandler = serverExceptionHandler;

  webServer.pipelines.first
    ..exceptionHandler = pipelineExceptionHandler
    ..register("GET", "~/", handlerRoot)
    ..register("GET", "~/test1", handler1)
    ..register("GET", "~/test2", handler2)
    ..register("GET", "~/test3", handler3)
    ..register("GET", "~/test4", handler4)
    ..register("GET", "~/stop", handlerStop);

  return webServer;
}

//================================================================
/// The tests
///
void runTests(Future<int> numProcessedFuture) {
  //----------------

  test("Handler Exception", () async {
    final str = await getRequest("/test1");
    expect(str, startsWith("Pipeline caught: test1\n"));
  });

  //----------------

  test("Handler onError", () async {
    final str = await getRequest("/test2");
    expect(str, startsWith("Pipeline caught: test2\n"));
  });

  //----------------

  test("Handler Exception and onError", () async {
    final str = await getRequest("/test3");
    expect(str, startsWith("Pipeline caught: test3a\n"));
  });

  //----------------

  test("Exception handler throws an Exception", () async {
    final str = await getRequest("/test4");
    expect(str,
        startsWith("Server caught: Instance of 'ExceptionHandlerException'\n"));
  });

  //----------------

  test("server still running", () async {
    final str = await getRequest("/");
    expect(str, startsWith("Error/Exception test\n"));
  });

  //----------------
  // Important: this must be the last test, to stop the server.
  //
  // If the server is not stopped, this program will not halt when run as a
  // Dart program, but does halt when run using "pub run test".

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

  //request.headers.contentType = ContentType.html;

  final response = await request.close();

  final contents = new StringBuffer();
  // ignore: prefer_foreach
  await for (var chunk in response.cast<List<int>>().transform(utf8.decoder)) {
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
