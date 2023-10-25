// Example used in the README file.

import 'dart:async';
import 'dart:io';

import 'package:woomera/woomera.dart';

Future<void> main() async {
  // Create the server with one pipeline

  final ws = Server()
    ..bindAddress = InternetAddress.anyIPv6
    ..bindPort = 1024
    ..exceptionHandler = myExceptionHandler
    ..pipelines.add(ServerPipeline()
      ..get('~/', handleTopLevel)
      ..get('~/:greeting', handleGreeting));

  // Run the server

  await ws.run();
}

@Handles.get('~/')
Future<Response> handleTopLevel(Request req) async {
  final resp = ResponseBuffered(ContentType.html);

  final helloUrl = req.rewriteUrl('~/Hello');
  final gDayUrl = req.rewriteUrl("~/G'day");

  resp.write('''
<!DOCTYPE html>
<html>
  <head>
    <meta charset="UTF-8">
    <title>Woomera Tutorial</title>
  </head>
  <body>
    <h1>Woomera Tutorial</h1>
    <ul>
      <li><a href="${HEsc.attr(helloUrl)}">Hello</a></li>
      <li><a href="${HEsc.attr(gDayUrl)}">Good day</a></li>
    </ul>
  </body>
</html>
''');
  return resp;
}

@Handles.get('~/:greeting')
Future<Response> handleGreeting(Request req) async {
  final greeting = req.pathParams['greeting'];

  var name = req.queryParams['name'];
  name = (name.isEmpty) ? 'world' : name;

  final resp = ResponseBuffered(ContentType.html);

  final homeUrl = req.rewriteUrl('~/');

  resp.write('''
<!DOCTYPE html>
<html>
  <head>
    <meta charset="UTF-8">
    <title>Woomera Tutorial</title>
  </head>
  <body>
    <h1>${HEsc.text(greeting)} ${HEsc.text(name)}!</h1>
    <p><a href="${HEsc.attr(homeUrl)}">Home</a></p>
  </body>
</html>
''');
  return resp;
}

Future<Response> myExceptionHandler(
    Request req, Object ex, StackTrace st) async {
  int status;
  String message;

  if (ex is NotFoundException) {
    status =
        ex.resourceExists ? HttpStatus.methodNotAllowed : HttpStatus.notFound;
    message = 'Sorry, the page you were looking for could not be found.';
  } else {
    status = HttpStatus.internalServerError;
    message = 'Sorry, an internal error occurred.';
    print('Exception: $ex');
  }

  return ResponseBuffered(ContentType.html)
    ..status = status
    ..write('''
<!DOCTYPE html>
<html>
  <head>
    <meta charset="UTF-8">
    <title>Error</title>
  </head>
  <body>
    <h1>Woomera Tutorial: Error</h1>
    <p>${HEsc.text(message)}</p>
  </body>
</html>
''');
}
