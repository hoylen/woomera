// Tutorial: example with exception handler

import 'dart:async';
import 'dart:io';

import 'package:woomera/woomera.dart';

Future main() async {
  // Create and configure server

  final ws = Server()
    ..bindAddress = InternetAddress.anyIPv6
    ..bindPort = 1024
    ..exceptionHandler = _myExceptionHandler;

  // Register rules

  ws.pipelines.first..get('~/', _handleTopLevel);

  // Run the server

  await ws.run();
}

Future<Response> _handleTopLevel(Request req) async {
  var name = req.queryParams['name'];
  name = (name.isEmpty) ? 'world' : name;

  final resp = ResponseBuffered(ContentType.html)..write('''
<html>
  <head>
    <title>Woomera Tutorial</title>
  </head>
  <body>
    <h1>Hello ${HEsc.text(name)}!</h1>
  </body>
</html>
''');
  return resp;
}

Future<Response> _myExceptionHandler(
    Request req, Object ex, StackTrace? st) async {
  int status;
  String message;

  if (ex is NotFoundException) {
    status = (ex.found == NotFoundException.foundNothing)
        ? HttpStatus.methodNotAllowed
        : HttpStatus.notFound;
    message = 'Sorry, the page you were looking for could not be found.';
  } else {
    status = HttpStatus.internalServerError;
    message = 'Sorry, an internal error occured.';
    print('Exception: $ex');
  }

  final resp = ResponseBuffered(ContentType.html)
    ..status = status
    ..write('''
<html lang="en">
  <head>
    <title>Error</title>
  </head>
  <body>
    <h1>Error</h1>
    <p>$message</p>
  </body>
</html>
''');

  return resp;
}
