Woomera
=======

Woomera is a Dart package for implementing Web servers.

It is used to create server-side Dart programs that listens for HTTP
requests and respond to them with HTTP responses.

A Web server is simple in theory, but in practice it quickly gets
complicated and difficult to maintain. Especially when there are many
different types of HTTP requests to process, different errors to
detect and state needs to be maintained between the HTTP
requests. This package aims to reduce that complexity.

Main features include:

- URL pattern matching inspired by the
  [Sinatra](https://github.com/sinatra/sinatra) Web framework. This allows the
  HTTP request paths to be easily specified and different segments of
  the path to be used as parameters.

- Exception handling mechanism to handle all uncaught and unexpected
  exceptions.  This ensures the Web application can always generate a
  user-friendly error page, instead of sometimes producing unexpected
  results when an exception was not caught. This is especially useful
  when using third-party packages that might throw undocumented
  exceptions. Error handling is simplified and the Web application is
  more robust and reliable.

- Session management using cookies or URL rewriting. The HTTP protocol
  does not maintain state between HTTP requests. This framework
  includes a mechanism for maintaining state. For example, it can be
  used to remember the user's account after they have signed in.  URL
  rewriting works if cookies have been disabled in the browser (though
  this is rare these days).

- Responses can be buffered, and sent as the HTTP response only
  when it is complete.  Therefore, if an error occurs the user won't
  see a partially generated page.

- Responses can be generated from a stream of data.

- Pipelines allow request handlers to be invoked in the desired order.
  Multiple error handlers are supported.  Requests can be arranged to
  be handled by multiple request handlers.  For example, the first
  request handler can log the request and the second request handler
  perform the actual processing.

- Features for testing the Web application without using a Web
  browser. This does not replace testing with a real Web browser, but
  runs faster than controlling a Web browser using WebDriver or
  Selenium Remote Control.

- Can be statically compiled. Annotations are also defined
  if you want to dynamically identify the handler methods.

The following is a tutorial which provides an overview the main
features of the package. For details about the package and its
advanced features, please see the API documentation.

## Platform support

This package is supported on all platforms where "dart:io" is
supported.

# Tutorial

## 1. A basic Web server

### 1.1. Overview

This is a basic Web server that has two _request handlers_ for
handling two types of URI requests. And it defines one _server
exception handler_.

```dart
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

@ServerExceptionHandler()
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
```

### 1.2. Importing the package

Any program that uses the framework must first import the package:

```dart
import 'package:woomera/woomera.dart';
```

### 1.3. Creating the server

The Web server needs to create and configure a [Server] object. And
then invoke its asynchronous `run` method which causes it to listen
and process HTTP requests.

This is the smallest possible server. It listens on port 80 of the
IPv4 loopback address (127.0.0.1) for HTTP requests.  But will respond
to every HTTP request with a _HTTP 401 Not found_.

```dart
  final ws = Server();
  await ws.run();
```

The interface and port it listens on is configured by the _bindPort_
and _bindAddress_ properties.

This is a server that listens on port 1024 of all network interfaces
(i.e. any IP address, both IPv4 and IPv6) of the host machine.

```dart
  final ws = Server()
    ..bindAddress = InternetAddress.anyIPv6
    ..bindPort = 1024;
```

Typically the application Web server is deployed behind a reverse
proxy.  If the reverse proxy is running on the same host, restricting
access to only the IPv4 loopback address is desirable; but usually the
port number needs to be changed to avoid conflicts and issues with
permissions.

### 1.4. Pipelines

The code to process HTTP requests is implemented in _request handler_
functions.

A server is organised as an ordered list of _pipelines_. And each of
those pipelines has an ordered list of _rules_ and _request handlers_
pairs.

The pipelines are represented by instances of the [ServerPipeline]
class.  The class has methods for registering rules with _request
handlers_. Rules are made up of a HTTP method and a _pattern_.  The
_register_ method (which is passed the HTTP method as a string) can be
used, but there are convenient methods named after the standard HTTP
methods too.

For example, the following creates a pipeline and registers two rules
on it.

```dart
  ServerPipeline()
    ..get('~/', handleTopLevel)
    ..get('~/:greeting', handleGreeting)
```

Both rules are for the HTTP GET method.

The pattern is represented by a string starting with "~/" and has path
segments that will be matched against the request URI's path.

On the server object, the `pipelines` member is a list of
_ServerPipeline_ objects. So the standard Dart methods on lists can be
used to manage the pipelines.

In this example, the list _add_ method is used to add the pipeline to
the server.

```dart
  final ws = Server()
    ..bindAddress = InternetAddress.anyIPv6
    ..bindPort = 1024
    ..pipelines.add(ServerPipeline()
      ..get('~/', handleTopLevel)
      ..get('~/:greeting', handleGreeting));
```

### 1.5. Rule matching

A HTTP method and a pattern is referred to as a "rule".

When a HTTP request is received a request handler is found, by
searching for a rule that matches it.

The search is conducted in order. It examines the pipelines in order,
and for each pipeline it examines each of its rules in order. If a
rule matches, its _request handler_ is invoked and the returned value
used to produce the HTTP response.

Multiple pipelines is useful is some situations. They can be used to
control the order in which rule matching is performed. They can be
used to handle exceptions in different ways, which will be described
later. And they can be used to group _request handlers_.

Instead of returning the response, a _request handler_ could throw a
[NoResponseProduced] exception. This is a special exception that tells
the matching algorith to continue searching subsequent rules, and
subsequent pipelines, for another match. This feature can be used to
pre-preprocess requests; for example, to have a _request handler_ that
audits every HTTP request before letting a different _request handler_
produce the response.

A rule matches the HTTP request if its HTTP method is the same as the
request's HTTP method, and the pattern matches the path of the request
URI. The type of segment in the pattern determines how it is matched
to the segments in the URI. These are the types of segments found in a
pattern:

- A _literal segment_ matches the exact same value (i.e. string equality).

- A _path parameter_ starts with a colon followed by the parameter
  name (e.g. ":greeting" or ":foo"). It matches exactly one segment at
  that position, and its value is assigned to the path parameter with
  that name.

- A _wildcard paramter_ is represented by "`*`". It matches has one or
  more segments. Those segments are assigned to the value of the path
  parameter with the special name of "`*`".

The "~" in the pattern is a reminder that a pattern is treated as a
relative or "internal" path. Typically, the pattern refers to the root
of the Web server. For example, the pattern "~/foo/bar" will match the
URI _http://localhost/foo/bar_ by default.  This can be changed by
setting the server's `basepath` member. For example, setting the
_basepath_ to "/abc/def", will mean the pattern will match the URI
_http://localhost/abc/def/foo/bar_ instead.

The example has two patterns:

- The "~/" pattern matches the empty path (e.g. _http://localhost:1024_).

- The "~/:greeting" matches any URI path with exactly one segment,
  assigning that segment to the value of the _path parameter_ named
  "greeting". For example, it will match _http://localhost:1024/Hello_
  and sets _greeting_ to "Hello". But it will not match "/", "/a/b" or
  "/a/b/c", since they don't have one segment in their path.

The order is important when registering rules to a pipeline, since
they are searched for in that order. For example, if a rule with the
pattern "~/foo/:bar" is registered before "~/foo/new", a request with
the URI path of "/foo/new" will always match the first rule (assigning
the value of "new" to the _path parameter_ named "bar") and the second
rule will never be used (not unless the first _request handler_ throws
a _NoResponseProduced_ exception).

### 1.6. Request handler

A _request handler_ is a function (or static method) that is passed
the request as a [Request] object and returns a Future to a [Response]
object.

The example has two _request handlers_. The first one was registered
with a rule so it handles HTTP requests for the root URI
(e.g. http://localhost:1024). It generates a HTML page with hyperlinks
to the other page.

The [ResponseBuffered] class is used to produce the response. It has a
`write` method used to build up the body of the HTTP response. By
default, the status of the HTTP response is _HTTP 200 OK_.

```dart
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
```

This example _request handler_ shows the use of the
`Request.rewriteUrl` to convert a local path (i.e. one starting with
"~/") to the actual path the server will be using.  The full path of
the deployed Web server can be changed by just changing the
[Server.basePath] property: the behaviour of the patterns and the
values in the responses will both be changed.

This example also shows the use of the [HEsc] class to encode values
for HTML documents. Special characters (e.g. `<`, `>` and `&`) will be
replaced by HTML entities.

The `ResponseBufferd` is the commonly used type of _Response_.  Other
responses are: [ResponseRedirect] to produce a _HTTP 303 Redirect_,
[ResponseNoContent] to produce a _HTTP 204 No Content_ response
without a body and [ResponseStream] to produce the HTTP body from a
stream source.

### 1.7. Processing path parameters

The other _request handler_ shows how _path parameters_ can be used.

The [RequestParams.[]] operator on the request's `pathParams` property
obtains the value corresponding to a named _path parameter_.

The pattern was "~/:greeting", so the first segment will be assigned
to the _path parameter_ named "greeting".

```dart
Future<Response> handleGreeting(Request req) async {
  final greeting = req.pathParams['greeting'];
```

There are also _query parameters_ which are accessed through the
request's `queryParams` member.

```dart
  var name = req.queryParams['name'];
  name = (name.isEmpty) ? 'world' : name;
```

So if the request URI was _http://localhost:1024/Hello?name=Remi_ then
_greeting_ will be assigned "Hello" and _name_ will be assigned
"Remi".

### 1.8. Handling exceptions

If a _request handler_ throws an exception, it is passed to an
exception handler. The exception handler should produce the response
that gets sent back to the client.

There are three types of exception handlers a program can provide:

- _pipeline exception handlers_ can be registered per-pipeline.  These
  are useful for generating different error responses, depending on
  which pipeline the matching _request handler_ was registered to. For
  example, an API pipeline could have a _pipeline exception handler_
  that produces a JSON error response, while another pipeline has a
  _pipeline exception handler_ that produces a HTML error response.

- a _server exception handler_ can be registered on the server.  It
  handles exceptions thrown by a _pipeline exception handler_, or the
  original exception if there was no _pipeline exception handler_.

- a _server raw exception handler_ handles exceptions thrown by the
  _server exception handler_, when there is no _server exception
  handler_ and in some other special situations.

The example has a _server exception handler_.

The server is configured with it.

```dart
  final ws = Server()
    ..exceptionHandler = myExceptionHandler
```

The _server exception handler_ is passed the _Request_ as well as the
exception object that was thrown and the stack trace of where it was
thrown from.

Like a _request handler_ it is expected to return a Future to the
_Response_ that will be used to produce the HTML response.

```dart
Future<Response> myExceptionHandler(
    Request req, Object ex, StackTrace st) async {
  ...
}
```

The _server exception handler_ will be invoked when any _request
handler_ throws an exception.

It will also be invoked when the framework cannot obtain a _Response_
from any of the _request handlers_. The exception will be a
`NotFoundException` object and should result in the status of _HTTP
404 Not Found_.

This example treats all other exceptions as an internal error and
response with a status of _HTTP 500 Internal server error_.  A more
useful _server exception handler_ could generate different responses
depending on the exceptioin.

```dart
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
```

The HTTP status is a property of the _Response_. The default is _HTTP
200 OK_. Depending on the exception, the _server exception handler_ in
the example sets it to either 404, 405 or 500.

```dart
  return ResponseBuffered(ContentType.html)
    ..status = status
    ..write( ... );
}
```

## 2. Patterns vs internal paths vs external paths

- **Patterns** are used for specifying which HTTP requests a request
  handler will process. When represented as a string, they look like
  `~/foo/bar/baz` or `~/account/:varname/profile`.

- Paths are one component of a URL. There are two types of paths:

  - **External paths** which are values that can be used externally.
    For example, `/foo/bar/baz` and `/account/24601/profile`.

  - **Internal paths** are used internally in the code. They look
    similar to patterns, but every segment is a literal value.
	For example, `~/foo/bar/baz` and `~/account/24601/profile`.

These different items are used in different places:

- Patterns are used in specifying rules to match request handlers.
- External paths appear in HTML that is used by the Web browser.
- Internal paths should be used to identify resources that
  are implemented by a request handler. And they should be converted
  into an external path using the `rewriteUrl` method on the _Request_.

### 2.1. Why use internal paths?

You don't have to use _internal paths_. But it is recommended, because
it forces the application to always invoke _rewriteUrl_ before
inserting a path into the response. Ensuring _rewriteUrl_ is always
used is important for two reasons:

- when URL rewriting is used to preserve the state across different
  HTTP requests, _rewriteUrl_ adds the state preserving query parameter.
  This is needed when using the session feature and the browser has
  cookies disabled; and

- when the _basePath_ of the server is set, _rewriteUrl_ adds the base path
  to the external URL. For example, if the base path is set to "/api/v2",
  rewriting the internal path of "~/foo/bar" produces an external path
  of "/api/v2/foo/bar".

Since _internal paths_ cannot be used by Web browsers, places where
_rewriteUrl_ didn't get invoked will be easily discovered during
testing. Otherwise, the application could appear to be working
correctly during testing, but will fail if the browser has cookies
disabled.

## 3. Parameters

### 3.1. Types of parameters

The _Request_ passed to request handlers can include three different
types of parameters:

- path parameters;
- query parameters; and
- post parameters.

The post parameters is only populated if the HTTP request had a MIME
type of "application/x-www-form-urlencoded". This occurs when a Web
browser submits a HTTP POST request. If available, they are available
through the _postParams_ member of the _Request_. If they are not
available, it is null.

Query parameters, obviously, are the query parameters from the request
URL. They are available through the _queryParams_ member of the
_Request_.

The path parameters are extracted from the path of the URL being
requested and are available through the _pathParams_ member of the
_Request_. They match the variable segments in the pattern. For example:

- `~/foo/bar/baz` is a pattern with no variable segments

- `~/user/:id` is a pattern with one variable segment. The literal
  segments must match the corresponding path segment, and the path
  parameter named "id" will be set to the second segment from the
  path.

- `~/user/:id/order/:orderNumber` is a pattern with two variable segments,
  resulting in two path parameters.

- `~/product/*` contains a wildcard segment that will match zero or
  more segments in the URL path.

A pattern can also contain an optional segment. See the API
documentation for more information.

This request handler that can be used to demonstrate the different
types of parameters:

```dart
@Handles.get('~/demo/variable/:foo/bar/:baz')
@Handles.get('~/demo/wildcard/*')
Future<Response> handleParams(Request req) async {
  final resp = ResponseBuffered(ContentType.html)
  ..write('''
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

  final _postParams = req.postParams;
  if (_postParams != null) {
    resp.write('<h2>POST parameters</h2>');
    _dumpParam(_postParams, resp);
  }

  resp.write('''
  </body>
</html>
''');

  return resp;
}

void _dumpParam(RequestParams p, ResponseBuffered resp) {
  final keys = p.keys;

  if (keys.isNotEmpty) {
    resp.write('<p>Number of keys: ${keys.length}</p>\n<dl>');

    for (var k in keys) {
      resp.write('<dt><code>${HEsc.text(k)}</code></dt><dd><ul>');
      for (var v in p.values(k, raw: true)) {
        resp.write('<li><code>${HEsc.text(v)}</code></li>');
      }
      resp.write('</ul></dd>');
    }

    resp.write('</dl>');
  } else {
    resp.write('<p>No parameters.</p>');
  }
}
```

Here are a few URLs to try with the above example:

- `http://localhost:1024/demo/variable/aaa/bar/bbb`
- `http://localhost:1024/demo/variable/aaa/bar/`
- `http://localhost:1024/demo/variable/aaa/bar/ccc?x=ddd&y=eee&x=fff`
- `http://localhost:1024/demo/wildcard/a/b/c`


### 3.2. Retrieving parameters

Parameters can have multiple values.  For example, check boxes on a
form will result in one named parameter with zero or more values (one
for each checked check box). There can be multiple query parameters
with the same name. Patterns can also be written with multiple
variable segments with the same name.

The `RequestParams` class can be thought of as a _Map_, where the keys
are the names of the parameters which maps into a _List_ of values. If
there is only one value, there is still a list: a list containing only
one value.

The names of all the available parameters can be obtained using the
_keys_ method.

    for (final k in req.queryParams.keys) {
      print('Got a query parameter named: $k');
    }

All the values for a given key can be obtained using the _values_ method.

    for (final k in req.queryParams.keys) {
      final vList = req.queryParams.values(k);
      for (final v in vList) {
        print('$k = $v');
      }
    }

If your request handler is expecting only one value, the
square-bracket operator can be used to retrieve a single value instead
of a list.

     final t = req.queryParams['title'];

### 3.3. Raw vs processed values

The methods described above for retrieving value(s) returns a cleaned up
version of the value which:

- removes all leading whitespaces;
- removes all trailing whitespace;
- collapses multiple consecutive whitespaces one whitespace; and
- convert all whitespace characters into the space character.

To obtain the unprocessed value, set _raw_ to true with the _values_ method:

    req.queryParams.values('category', raw: true);

### 3.4. Expect the unexpected

To make a robust application, do not make any assumptions about what
parameters may or may not be present: check everything and fail
gracefully. The parameters might be different from what is expected
because of programming errors, misuse or (worst case, but very
important to deal with) the application is under malicious attack.

If a parameter is missing, the square bracket operator returns an
empty string, and the _values_ method returns an empty list when it is
returning processed values. In raw mode, the _values_ method returns
null if the value does not exist: which is the only way to detect the
difference between the presence of a blank/empty parameter versus the
absence of the parameter.

An application might be designed to expect exactly one instance of a
parameter, but a malicious client might try to send two or more values
to it. The square bracket operator, which is used when only one value
is expected, will return the empty string if the multiple copies of
the parameter exist (even if the values are not empty strings).


## 4. Pipelines

### 4.1. The default pipeline

A server has a collection of rules. If a rule matches the HTTP request
(i.e. matches the HTTP method and the request path), then its response
handler is invoked.  The order in which rules are examined, to see if
they match the HTTP request, is determined by pipelines.

Web applications do not have to deal with pipelines if they don't want
to.  Applications only need to deal with pipelines if they want more
control over how and when rules are matched (and consequently which
request handlers are invoked).

### 4.2. Behavour of pipelines

The rules in a server are organised by the pipelines. A server has an
ordered list of pipelines.  Each pipeline separates out its rules by
the HTTP method. Within each HTTP method, the rules are stored in an
ordered list.

When a HTTP request arrives, it is tested against each rule until a
match is found. Each pipeline is checked in order, and within the
pipeline the rules are checked in order. If no match is found, after
checking all the pipelines, then a _NotFoundException_ is thrown.

Therefore, rules in earlier pipelines are checked first and within a
pipeline earlier rules are checked first.

If a request handler returns null, the testing continues with the
subsequent rules. So it is possible to design an application where a
request is processed by multiple request handers, as long as the rules
appear in the correct order.

Using multiple pipelines is one way of controlling the order in which
rules are tested. The other way is to register the rules in a
particular order.

The other useful feature of pipelines is each pipeline can have its
own _pipeline exception handler_, in addition to the server's
exception handler.  This is useful if exceptions from different sets
of request handlers should be handled differently. For example, there
could be an exception handler that generates a HTML error page and
another that generates an error in JSON.

### 4.3. Naming pipelines

Every pipeline has a name. The default name is the emptty string, but
a different name can be provided to the _ServerPipeline_ constructor.

``` dart
final p1 = ServerPipeline('api');

final p2 = ServerPipeline('main');
```

Named pipelines are needed if using multiple pipelines with
annotations, since they identify which pipeline to associate a
_request handler_ with.

## 5. Exceptions

### 5.1. Standard exceptions

All the exceptions thrown by the framework are subclasses
of the `WoomeraException` class.

- The `NotFoundException` is thrown when a matching rule is not found.
  The exception handler should produce a "page not found" error page
  with a HTTP response status of either `HttpStatus.notFound` or
  `HttpStatus.methodNotAllowed` depending on the value of its
  "found" member.

- The `ExceptionHandlerException` is a wrapper that is thrown if an
  application provided exception handler throws an exception while it
  is processing another exception.

See the package's documentation for the other exceptions. Most of them
are in response to a malformed or potentially malicious HTTP request.

These exceptions, along with all exceptions thrown by the
application's handlers, are processed according to the exception
handling process. The application can provide its own high-level and
low-level exception handlers for customizing this process.

### 5.2. High-level exception handlers

High-level exception handlers are a type of handler used to process
exceptions that are raised. They are passed the request and the
exception, and are expected to generate a _Response_. The exception
handler should create a response that is as an error page for the
client.

#### 5.2.1. Server exception handler

There can be at most one _server exception handler_. Servers should
provide one, because it is used to indicate a page is not found.

```dart
@ServerExceptionHandler()
Future<Response> myExceptionHandler(Request req
    Object exception, StackTrace st) async {
  var resp = ResponseBuffered(ContentType.html);
  resp.write('''
<!DOCTYPE html>
<html>
  <head>
    <meta charset="UTF-8">
    <title>Error</title>
  </head>
  <body>
    <h1>Error</h1>
    <p>Sorry, an error occured: ${HEsc.text(exception.toString())}</p>
  </body>
</html>
''');
  return resp;
}
```

#### 5.2.2. Pipeline exception handler

Each pipeline can also have its own exception handler.

``` dart
final p1 = ServerPipeline()
  ..exceptionHandler = myExceptionHandler1;

final p2 = ServerPipeline('myCustomPipeline')
  ..exceptionHandler = myExceptionHandler2;


@Handles.pipelineExceptions()
Future<Response> myExceptionHandler1(Request req
    Object exception, StackTrace st) async {
	// for the default pipeline
}

@Handles.pipelineExceptions(pipeline: 'myCustomPipeline')
Future<Response> myExceptionHandler2(Request req
    Object exception, StackTrace st) async {
	// for the pipeline named "myCustomPipeline"
}
```

Different exception handlers for different pipelines can be used to
handle exceptions differently. For example, one pipeline could be used
for a RESTful API and its exception handler produces a XML or JSON
error response; and other pipeline's exception handler could produce a
HTML error page.

### 5.3. Low-level exception handling

In addition to the high-level exception handlers, a low-level
raw exception handler can be associated with the server.

It is called a "low-level" or "raw" exception handler, because it
needs to process a Dart HttpRequest and generate a HTTP response
without the aid of the Woomera classes.

``` dart
@ServerExceptionHandlerRaw()
Future<void> myLowLevelExceptionHandler(
    HttpRequest rawRequest, String requestId, Object ex, StackTrace st) async {

  final resp = rawRequest.response;

  resp
    ..statusCode = HttpStatus.internalServerError
    ..headers.contentType = ContentType.html
    ..write('''<!DOCTYPE html>
<html>
...
</html>
''');

  await resp.close();
}
```

It is triggered in rare situations where a high-level exception
handler cannot be used.

### 5.4. Exception handling process

The process of dealing with exceptions depends on where the initial
exception was thrown from, and what custom exception handlers the
application has provided.

- If an exception occurs inside a request handler method (and has not
  been caught and processed within the handler) it is passed to the
  exception handler attached to the pipeline: the pipeline with the
  rule that invoked the request handler method.

- If no exception handler was attached to the pipeline, the high-level
  exception handler on the server is used. Exceptions that occur
  outside of any handler or pipeline (commonly when a matching handler
  is not found) are also handled by the server's high-level exception
  handler.

- If no custom high-level exception handler was attached to the server,
  a built-in default high-level exception handler is used.

If one of those exception handlers throws an exception, the exception
it was processing is wrapped in an _ExceptionHandlerException_, which
is then passed to the next handler in the process.

It is recommended to provide at least the high-level server exception
handler, since the default exception handler just produces a plain
text response that purely functional and not pretty. It also handles
the page not found errors.



## 6. Responses

The request handlers and exception handlers must return a _Future_
that returns a _Response_ object. The _Response_ class is an abstract
class and three subclasses of it have been defined in the package:

- ResponseBuffered
- ResponseStream
- ResponseRedirect

### 6.1. ResponseBuffered

This is used to write the contents of the response into a buffer,
which is used to create the HTTP response after the request hander
returns.

The HTTP response is only created after the request handler finishes.
If an error occurs while generating the response, the partially
created ResponseBuffered object can be discarded and a new response
created. The new response can be created in the response handler or in
an exception handler. The new response can show an error page, instead
of trying to output an error message at the end of a partially
generated page.

### 6.2. ResponseRedirect

This is used to generate a HTTP redirect, which tells the client to go
to a different URL.

### 6.3. ResponseStream

This is used to produce the contents of the response from a stream.

### 6.4. Common features

With all three types of responses, the application can:

- Set the HTTP status code;
- Create HTTP headers; and/or
- Create or delete cookies.

### 6.5. Common handlers provided

#### 6.5.1. Static file handler

The package includes a request handler for serving up files and
directories from the local disk. It can be used to serve static files
for all or some of the Web server (for example, the images and
stylesheets).

See the API documentation for the _StaticFiles_ class.

#### 6.5.2. Proxy handler

The package includes a request handler for proxying requests to
a different server. A request for one URI is converted into a
target URI and the request is forward to it. The response from
the target URI is used as the response.

See the API documentation for the _Proxy_ class.

## 7. Sessions

The framework provides a mechanism to manage sessions. HTTP is a
stateless protocol, but sessions have been added to support the
tracking of state.

A session can be created and attached to a HTTP request.  That session
will be attached to subsequent _Request_ objects.  The framework
handles the preserving and restoration of the session using either
session cookies or URL rewriting. The application can terminate a
session, or they will automatically terminate after a nominated
timeout period after they were last used.

## 8. Logging

Woomera uses the [Logging](https://pub.dartlang.org/packages/logging)
package.  See the Woomera library API documentation for the logger
names.

In general, a logging level of "INFO" should produce no logging
entries, unless there is a problem.  Setting the "woomera.request"
logger to "FINE" logs the URL of every HTTP request, which might be
useful for testing.

## 9. Annotations

Maintaining the code for a large Web server gets more complicated as
the number of _pipelines_, _request handlers_ and exception handlers
grows. Code changes need to occur in two places: where the function is
defined and where it is registered with a pipeline or server. For
example, it is easy to accidentally create a _request handler_
function and forget to register it against a pipeline.

Annotations can be used to help manage the code. The server and
pipelines can be automatically generated from the annotations.

See the
[woomera_server_gen](https://pub.dev/packages/woomera_server_gen)
package for one way annotations can be used.

# Feedback

Please report bugs by opening an
[issue](https://github.com/hoylen/woomera/issues) in GitHub.
