// Example used in the README file.

import 'dart:async';
import 'dart:io';

import 'package:woomera/woomera.dart';

Future<void> main() async {
  // Create and configure server

  final ws = serverFromAnnotations()
    ..bindAddress = InternetAddress.anyIPv6
    ..bindPort = 1024;

  // ignore: cascade_invocations
  ws.exceptionHandler = myExceptionHandler;

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

  return resp;
}

@Handles.get('~/demo/variable/:foo/bar/:baz')
@Handles.get('~/demo/wildcard/*')
Future<Response> handleParams(Request req) async {
  final resp = ResponseBuffered(ContentType.html)..write('''
<!DOCTYPE html>
<html>
  <head>
    <meta charset="UTF-8">
    <title>Woomera Tutorial</title>
  </head>
  <body>
    <h1>Parameters</h1>
''');

  // ignore: cascade_invocations
  resp.write('<h2>Path parameters</h2>');
  _dumpParam(req.pathParams, resp);

  resp.write('<h2>Query parameters</h2>');
  _dumpParam(req.queryParams, resp);

  resp.write('<h2>POST parameters</h2>');
  _dumpParam(req.postParams, resp);

  resp.write('''
  </body>
</html>
''');

  return resp;
}

void _dumpParam(RequestParams p, ResponseBuffered resp) {
  if (p != null) {
    final keys = p.keys;

    if (keys.isNotEmpty) {
      resp.write('<p>Number of keys: ${keys.length}</p>\n<dl>');

      for (var k in keys) {
        resp.write('<dt><code>${HEsc.text(k)}</code></dt><dd><ul>');
        for (var v in p.values(k, mode: ParamsMode.raw)) {
          resp.write('<li><code>${HEsc.text(v)}</code></li>');
        }
        resp.write('</ul></dd>');
      }

      resp.write('</dl>');
    } else {
      resp.write('<p>No parameters.</p>');
    }
  } else {
    resp.write('<p>Not available.</p>');
  }
}
