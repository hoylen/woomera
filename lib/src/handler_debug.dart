part of woomera;

//================================================================
/// Request handler which shows out the request parameters to the client.
///
/// This request handler is useful for debugging. It generates a response that
/// shows what path, query and POST parameters were in the request.
///
/// Note: the HTTP response is text, rather than HTML. This makes it easier
/// to read/parse when testing without a Web browser (e.g. from the command line
/// using _curl_).

Future<Response> debugHandler(Request req) async {
  final buf = new StringBuffer("HTTP method: ${req.request.method}\n\n");

  var hasParams = false;
  for (var key in req.pathParams.keys) {
    for (var value in req.pathParams.values(key, raw: true)) {
      buf.write('Path parameter: key = "$value"\n');
      hasParams = true;
    }
  }
  if (hasParams) {
    buf.write("\n");
  }

  hasParams = false;
  for (var key in req.queryParams.keys) {
    for (var value in req.queryParams.values(key, raw: true)) {
      buf.write('Query parameter: key = "$value"\n');
      hasParams = true;
    }
  }
  if (hasParams) {
    buf.write("\n");
  }

  hasParams = false;
  if (req.postParams != null) {
    for (var key in req.postParams.keys) {
      for (var value in req.postParams.values(key, raw: true)) {
        buf.write('POST parameter: $key = "$value"\n');
        hasParams = true;
      }
    }
  }
  if (hasParams) {
    buf.write("\n");
  }

  buf.write("Time: ${new DateTime.now().toString()}");

  final resp = new ResponseBuffered(ContentType.text)..write(buf.toString());
  return resp;
}
