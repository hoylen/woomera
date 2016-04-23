// Tutorial: first example

import 'dart:async';
import 'dart:io';

import 'package:woomera/woomera.dart';

Future main() async {
  // Create and configure server

  var ws = new Server();
  ws.bindAddress = InternetAddress.ANY_IP_V6;
  ws.bindPort = 1024;

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
