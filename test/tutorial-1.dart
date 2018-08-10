// Tutorial: first example

import 'dart:async';
import 'dart:io';

import 'package:woomera/woomera.dart';

Future main() async {
  // Create and configure server

  final ws = new Server()
    ..bindAddress = InternetAddress.anyIPv6
    ..bindPort = 1024;

  // Register rules

  ws.pipelines.first..get("~/", _handleTopLevel);

  // Run the server

  await ws.run();
}

Future<Response> _handleTopLevel(Request req) async {
  var name = req.queryParams["name"];
  name = (name.isEmpty) ? "world" : name;

  final resp = new ResponseBuffered(ContentType.html)..write("""
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
