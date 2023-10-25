// Tutorial: example with parameters

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

  ws.pipelines.first
    ..get('~/', _handleTopLevel)
    ..get('~/foo/bar/baz', debugHandler)
    ..get('~/user/:name', debugHandler)
    ..get('~/user/:name/:orderNumber', debugHandler)
    ..get('~/product/*', debugHandler)
    ..get('~/form', _handleTestForm)
    ..post('~/formProcessor', debugHandler);

  // Run the server

  await ws.run();
}

Future<Response> _handleTopLevel(Request req) async {
  var name = req.queryParams['name'];
  name = (name.isEmpty) ? 'world' : name;

  final resp = ResponseBuffered(ContentType.html)..write('''
<html lang="en">
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

Future<Response> _handleTestForm(Request req) async {
  final resp = ResponseBuffered(ContentType.html)..write('''
<html lang="en">
  <head>
    <title>Woomera Tutorial</title>
  </head>
  <body>
    <h1>Example form</h1>

    <form method="POST" action="${req.rewriteUrl("~/formProcessor")}">
      <input type="radio" name="type" value="out" id="w"/> <label for="w">Withdraw</label>
      <input type="radio" name="type" value="in" id="d"/> <label for="d">Deposit</label>
      <input type="text" name="amount"/>
      <input type="submit"/>
    </form>

  </body>
</html>
''');
  return resp;
}

Future<Response> _myExceptionHandler(
    Request req, Object ex, StackTrace st) async {
  int status;
  String message;

  if (ex is NotFoundException) {
    status =
        ex.resourceExists ? HttpStatus.methodNotAllowed : HttpStatus.notFound;
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
