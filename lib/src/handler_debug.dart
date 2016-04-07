part of woomera;

//================================================================
/// Handler which dumps out the request to the requestor as text.
///
/// This handler is useful for debugging.
///
Future<Response> debugHandler(Request req) async {
  var str = "HTTP method: ${req.request.method}\n";
  str += "\n";

  var hasParams = false;
  for (var key in req.pathParams.keys) {
    for (var value in req.pathParams.values(key, raw: true)) {
      str += "Path parameter: ${key} = \"${value}\"\n";
      hasParams = true;
    }
  }
  if (hasParams) {
    str += "\n";
  }

  hasParams = false;
  if (req.postParams != null) {
    for (var key in req.postParams.keys) {
      for (var value in req.postParams.values(key, raw: true)) {
        str += "POST parameter: ${key} = \"${value}\"\n";
        hasParams = true;
      }
    }
  }
  if (hasParams) {
    str += "\n";
  }

  hasParams = false;
  for (var key in req.queryParams.keys) {
    for (var value in req.queryParams.values(key, raw: true)) {
      str += "Query parameter: ${key} = \"${value}\"\n";
      hasParams = true;
    }
  }
  if (hasParams) {
    str += "\n";
  }

  str += "Time: " + new DateTime.now().toString();

  var resp = new ResponseBuffered(ContentType.TEXT);
  resp.write(str);
  return resp;
}
