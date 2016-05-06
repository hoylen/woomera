// Tutorial: example with exception handler

import 'dart:async';
import 'dart:io';

import 'package:woomera/woomera.dart';

Future main() async {
  // Create and configure server

  var ws = new Server();
  ws.bindAddress = InternetAddress.ANY_IP_V6;
  ws.bindPort = 1024;

  ws.exceptionHandler = myExceptionHandler;

  // Register rules

  var p = ws.pipelines.first;
  p.get("~/", handleTopLevel);

  // Run the server

  await ws.run();
}

Future<Response> handleTopLevel(Request req) async {
  var name = req.queryParams["name"];
  name = (name.isEmpty) ? "world" : name;

  var resp = new ResponseBuffered(ContentType.HTML);
  resp.write("""
<html>
  <head>
    <title>Woomera Tutorial</title>
  </head>
  <body>
    <h1>Hello ${HEsc.text(name)}!</h1>
  </body>
</html>
""");
  return resp;
}

Future<Response> myExceptionHandler(Request req, Object ex, StackTrace st) async {
  var status;
  var message;

  if (ex is NotFoundException) {
    status = (ex.found == NotFoundException.foundNothing) ? HttpStatus.METHOD_NOT_ALLOWED : HttpStatus.NOT_FOUND;
    message = "Sorry, the page you were looking for could not be found.";
  } else {
    status = HttpStatus.INTERNAL_SERVER_ERROR;
    message = "Sorry, an internal error occured.";
    print("Exception: $ex");
  }

  var resp = new ResponseBuffered(ContentType.HTML);
  resp.status = status;

  resp.write("""
<html>
  <head>
    <title>Error</title>
  </head>
  <body>
    <h1>Error</h1>
    <p>$message</p>
  </body>
</html>
""");

  return resp;
}
