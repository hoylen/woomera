Woomera
=======

## Introduction

Woomera is a Dart package for implementing Web servers.

Server-side Dart programs can be created to listen for HTTP requests
and to respond to them. It can be used to create a Web server that
serves static files and dynamically generated content.

Main features include:

- URL pattern matching inspired by the Sinatra Web framework;
- Pipelines of patterns to allow sophisticated processing, if needed;
- Robust exception handling to ensure error pages are reliably generated;
- Session management using cookies or URL rewriting;
- Response can be produced by a stream or as a buffered response.

## Example

```dart
import 'package:woomera/woomera.dart';

Future main() async {
  var ws = new Server();
  ws.bindAddress = InternetAddress.ANY_IP_V6;
  ws.bindPort = 1024;
  ws.exceptionHandler = myExceptionHandler;

  var p = ws.pipelines.first;
  p.get("/", handlerTopLevel);

  await ws.run();
}

Future<Response> handleTopLevel(Request req) async {
  var resp = new ResponseBuffered(ContentType.HTML);
  resp.write("""
<html>
<body>
<p>Hello world!</p>
<form method="POST" action="${req.rewriteURL("~/square")}">
</body>
</html>""");
  return resp;
}

Future<Response> myExceptionHandler(Request req, Object ex, StackTrace st) async {
  var resp = new ResponseBuffered(ContentType.HTML);

  resp.write("<html><body>");

  if (ex is NotFoundException) {
    resp.status = (ex.methodNotFound) ? HttpStatus.METHOD_NOT_ALLOWED : HttpStatus.NOT_FOUND;
    resp.write("<h1>Not found</h1><p>Sorry, the page you were looking for could not be found."");
  } else {
    resp.status = HttpStatus.INTERNAL_SERVER_ERROR;
    resp.write("<h1>Error</h1><p>Sorry, something went wrong."");
  }

  resp.write("</body></html>");
  return resp;
}
```

## Tutorial

### Basic Web server

```dart
import 'package:woomera/woomera.dart';

Future main() async {
  var ws = new Server();
  ws.bindAddress = InternetAddress.ANY_IP_V6;
  ws.bindPort = 1024;

  var p = ws.pipelines.first;
  p.get("/", handlerRoot);

  await ws.run();
}

Future<Response> handleTopLevel(Request req) async {
  var resp = new ResponseBuffered(ContentType.HTML);
  resp.write("""
<html>
  <head><title>Example 1</title></head>
  <body>
    <p>Hello world!</p>
  </body>
</html>
""");
  return resp;
}

```

### Parameters

#### Path parameters

TBD

#### Query parameters

#### Post parameters



### Exceptions


### Responses

#### Common features

- Status
- Headers
- Cookies

#### Buffered response

#### Redirect response

#### Stream response





### Sessions

### Advanced use of pipelines


## References

- Dart tutorial on Writing HTTP clients and servers <https://www.dartlang.org/docs/tutorials/httpserver/>
- Shelf <https://pub.dartlang.org/packages/shelf>
