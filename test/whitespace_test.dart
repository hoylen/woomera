// Tests the whitespace behaviour for parameters from the Woomera package.
//
// Copyright (c) 2015, Hoylen Sue. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.
//----------------------------------------------------------------

library main;

import 'dart:async';
import 'dart:convert' show utf8;
import 'dart:io' show ContentType, HttpClient;

import 'package:logging/logging.dart';
import 'package:test/test.dart';
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
int portNumber = 2049;

//----------------------------------------------------------------
// Internal

/// The Web server
late final Server webServer;

//================================================================
// Test server

//----------------------------------------------------------------

Server _createTestServer() {
  webServer = Server(numberOfPipelines: 2)
    // webServer.bindAddress = '127.0.0.1';
    // webServer.bindAddress = 'localhost';
    ..bindPort = portNumber;

  // Configure the first pipeline

  webServer.pipelines.first
    ..get('~/sanitized', sanitizedValuesHandler)
    ..post('~/sanitized', sanitizedValuesHandler)
    ..get('~/trimmedRawLines', trimmedRawLinesValuesHandler)
    ..post('~/trimmedRawLines', trimmedRawLinesValuesHandler)
    ..get('~/raw', rawValuesHandler)
    ..post('~/raw', rawValuesHandler)
    ..get('~/system/stop', handleStop);

  return webServer;
}

//----------------------------------------------------------------
/// Handlers

Future<Response> sanitizedValuesHandler(Request req) =>
    _valuesHandler(req, ParamsMode.standard);

Future<Response> trimmedRawLinesValuesHandler(Request req) =>
    _valuesHandler(req, ParamsMode.rawLines);

Future<Response> rawValuesHandler(Request req) =>
    _valuesHandler(req, ParamsMode.raw);

//----------------

Future<Response> _valuesHandler(Request req, ParamsMode mode) async {
  final buf = StringBuffer('${req.method};');

  for (var key in req.pathParams.keys) {
    for (var value in req.pathParams.values(key, mode: mode)) {
      buf.write('Path.$key=$value;');
    }
  }

  final _postParams = req.postParams;
  if (_postParams != null) {
    for (var key in _postParams.keys) {
      for (var value in _postParams.values(key, mode: mode)) {
        buf.write('Post.$key=$value;');
      }
    }
  }

  for (var key in req.queryParams.keys) {
    for (var value in req.queryParams.values(key, mode: mode)) {
      buf.write('Query.$key=$value;');
    }
  }

  buf.write('.');

  final resp = ResponseBuffered(ContentType.text)..write(buf.toString());
  return resp;
}

//----------------------------------------------------------------
/// Handler for stopping the server
///
/// This is to stop the server after the tests have completed.
/// Normally, servers should not have such an operation.

Future<Response> handleStop(Request req) async {
  await webServer.stop(); // async

  final resp = ResponseBuffered(ContentType.text)..write('stopping');
  return resp;
}

//================================================================
// Client functions used by tests

//----------------------------------------------------------------
/// GET

Future<String> getRequest(String path) async {
  // Note: must use "localhost" because "127.0.0.1" does not work: strange!

  final request = await HttpClient().get('localhost', portNumber, path);

  //request.headers.contentType = ContentType.html;

  final response = await request.close();

  final contents = StringBuffer();
  // ignore: prefer_foreach
  await for (var chunk in utf8.decoder.bind(response)) {
    contents.write(chunk);
  }

  return contents.toString();
}

//----------------------------------------------------------------
/// POST

Future<String> postRequest(String path, String data) async {
  // Note: must use "localhost" because "127.0.0.1" does not work: strange!

  final request = await HttpClient().post('localhost', portNumber, path);

  request.headers.contentType =
      ContentType('application', 'x-www-form-urlencoded', charset: 'utf-8');
  request.write(data);

  final response = await request.close();

  final contents = StringBuffer();
  // ignore: prefer_foreach
  await for (var chunk in utf8.decoder.bind(response)) {
    contents.write(chunk);
  }

  return contents.toString();
}

//================================================================
/// The tests

void _runTests(Future<int> numProcessedFuture) {
  //----------------------------------------------------------------

  group('Post parameters raw', () {
    //----------------

    for (final entry in [
      [
        'LF',
        ' a b\tc\nd  e \t f\n\n\tghi\n ', // input and raw
        'a b c d e f ghi', // sanitized
        'a b\tc\nd  e \t f\n\n\tghi' // trimmedRawLines
      ],
      [
        'CR-LF',
        ' a b\tc\r\nd  e \t f\r\n\r\n\tghi\n ',
        'a b c d e f ghi',
        'a b\tc\nd  e \t f\n\n\tghi'
      ],
      [
        'CR',
        ' a b\tc\rd  e \t f\r\r\tghi\r ',
        'a b c d e f ghi',
        'a b\tc\nd  e \t f\n\n\tghi' // trimmedRawLines: \r converted into \n
      ],
      [
        'LS and PS',
        ' a b c\u2028d e f \u2028\u2029\n\r x\u2029 ',
        'a b c d e f x',
        'a b c\nd e f \n\n\n\n x', // trimmedRawLines
      ],
      [
        'Mixed LF, CR, CR-LF',
        '\n a\nb\rc\r\nd\n\re\n\t\n \r',
        'a b c d e',
        'a\nb\nc\nd\n\ne' // trimmedRawLines: CR-LF -> LF; but LF-CR -> two LFs
      ],
    ]) {
      final name = entry[0];
      final value = entry[1];
      final expectedSanitized = entry[2];
      final expectedTrimmedRawLines = entry[3];

      final encodedValue = Uri.encodeQueryComponent(value);

      test('$name: fullySanitized', () async {
        final str = await postRequest('/sanitized', 'foo=$encodedValue');
        expect(str, equals('POST;Post.foo=$expectedSanitized;.'));
      });

      test('$name: trimmedRawLines', () async {
        final str = await postRequest('/trimmedRawLines', 'foo=$encodedValue');
        expect(str, equals('POST;Post.foo=$expectedTrimmedRawLines;.'));
      });

      test('$name: raw', () async {
        final str = await postRequest('/raw', 'foo=$encodedValue');
        expect(str, equals('POST;Post.foo=$value;.'));
      });
    }
  });

  //----------------------------------------------------------------
  // Important: this must be the last test, to stop the server.
  //
  // If the server is not stopped, this program will not halt when run as a
  // Dart program, but does halt when run using 'pub run test'.

  group('End of tests', () {
    //----------------

    test('stopping server', () async {
      final str = await getRequest('/system/stop');
      expect(str, equals('stopping'));

      // Wait for server to stop
      final num = await numProcessedFuture;
      Logger('main').info('server stopped: requests processed: $num');
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

  Logger('main').level = Level.ALL;
  Logger('woomera.server').level = Level.ALL;
  Logger('woomera.request').level = Level.ALL;
  Logger('woomera.response').level = Level.ALL;
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
    print('Service running at http://localhost:$portNumber/session');
  }
}
