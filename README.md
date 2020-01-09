Woomera
=======

## Introduction

Woomera is a Dart package for implementing Web servers.

It is used to create server-side Dart programs that function as a Web
server. A Web server listens for HTTP requests and respond to them
with HTTP responses: a simple task, but one that can get complicated
(and difficult to maintain) when the program has many different pages
to display, handle errors and maintain state. This package aims to
reduce that complexity.

Main features include:

- URL pattern matching inspired by the
  [Sinatra](http://www.sinatrab.com/) Web framework - allows easy
  parsing of URL path components as parameters;
  
- Exception handling framework - ensures error pages are reliably
  generated and unexpected exceptions are always "caught" to generate
  an error page response;

- Session management using cookies or URL rewriting;

- Responses can be generated into a buffer - allows response to
  contain a complete error page instead of an incompletely generated
  result page.

- Responses can be read from a stream of data.

- Ability to test a Web server without needing a Web browser.

- Pipelines of patterns for matching against URLs to allow
  sophisticated processing, if needed - allows requests to be processed
  by multiple handlers (e.g. to log/audit requests before handling them)
  and different exception handlers to be set for different resources;

**Note:** This version **requires Dart 2**.  Please use version
"<3.0.0" if running **Dart 1**.

This following is a tutorial which provides an overview the main
features of the package. For details about the package and its
advanced features, please see the API documentation.

## Tutorial

### 1. A basic Web server

#### 1.1. Overview

This is a basic Web server that serves up one page. It creates a
server with one response handler.

```dart
import 'dart:async';
import 'dart:io';

import 'package:woomera/woomera.dart';

Future main() async {
  // Create and configure server

  var ws = Server();
  ws.bindAddress = InternetAddress.anyIPv6;
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

  var resp = ResponseBuffered(ContentType.HTML);
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
```

The most important feature of the package is to organise response
handlers, so that HTTP requests can be matched to Dart code to process
them and to generate a HTTP response.

A _Server_ has of a sequence of pipelines, and each pipeline has a
sequence of rules. Each rule consists of the HTTP method (e.g. GET or
POST), a path pattern, and a request handler method.

When a HTTP request arrives, the pipelines are search (in order) for a
rule that matches the request. A match is when the HTTP method is the
same and the pattern matches the request URL's path.  If found, the
corresponding handler is invoked to produce the HTTP response. If no
rule is found (after searching through all the rules in all the
pipelines), the resource is treated as not found.

#### 1.2. Importing the package

Any program that uses the framework must first import the package:

```dart
import 'package:woomera/woomera.dart';
```

#### 1.3. The server

For the Web server, a _Server_ object is created and configured for
the TCP/IP address and port it will listen for HTTP requests on.

```dart
var ws = Server();
ws.bindAddress = InternetAddress.ANY_IP_V6;
ws.bindPort = 1024;
```

For testing, the above example sets it to `InternetAddress.ANY_IP_V6`,
so the service is listening to connections on any interface (i.e. both
loopback and public). When using `InternetAddress.ANY_IP_V6`, the
`v6Only` member controls whether IPv4 addresses are included or not
(it defaults to false, meaning it listens on any IPv4 and any IPv6).
To make it easy to connect to, this examples uses ANY_IP_V6 and leaves
_v6Only_ set to false.

Often, when deployed in production, the service should only be
accessed via a reverse Web proxy (e.g. Apache or Nginx). The default
bind address is `InternetAddress.LOOPBACK_IP_V4` can be used to for
this: it means only listens for connections on 127.0.0.1 (i.e.  only
clients from the same host can connect to it). Note: when configuring
the reverse proxy, use 127.0.0.1. Do not use "localhost" because on
some systems that first tries the IPv6 localhost address (::1) before
trying the IPv4 localhost address.

A port number 1024 or greater should be used, because the lower port
numbers are require special permission to use.

#### 1.4. The pipeline

The _Server_ (by default) automatically creates one pipeline, since
that is the most common scenario. The _pipelines_ member is a _List_
of _ServerPipeline_ objects, so retrieve it from the server using
something like:

```dart
var p = ws.pipelines.first;
```

#### 1.5. The rules

Rules are registered with the pipeline. The _get_ method on the
_ServerPipeline_ object will register a rule for the HTTP GET method,
and the _post_ method will register a rule for the HTTP POST
method. The first parameter is the pattern. The second parameter is
the handler method: the method that gets invoked when the rule matches
the HTTP request.

```dart
p.get("~/", handlerTopLevel);
```

The tilde ("`~`") indicates this is relative to the _base path_ of the
server.  The default base path is "/". See the API documentation for
information about changing the base path. For now, all paths should
begin with "~/".

#### 1.6. Running the server

After configuring the [Server], start it using its _run_ method. The
_run_ method returns a _Future_ that completes when the Web server
finishes running; but normally a Web server runs forever without
stopping.

```dart
await ws.run();
```

#### 1.7. Request handlers

A request handler method is used to process the HTTP request to
produce a HTTP response. It is passed the HTTP request as a _Request_
object; and it returns a HTTP response as represented by a _Response_
object.

There are different types of _Response_ objects. The commonly used one
for generating HTML pages is the _ResponseBuffered_. It acts as a
buffer where the contents is appended to it using the _write_
method. After the response is returned from the request handler, the
framework uses it to generate the HTTP response that is sent back to
the client.

This first example request handler returns a simple HTML page.

```
Future<Response> handleTopLevel(Request req) async {
  var name = req.queryParams["name"];
  name = (name.isEmpty) ? "world" : name;

  var resp = ResponseBuffered(ContentType.HTML);
  resp.write("""
<html>
  <head><title>Example 1</title></head>
  <body>
    <h1>Hello ${HEsc.text(name)}!</h1>
  </body>
</html>
""");
  return resp;
}
```

The "name" query parameter is retrieved from the request. If it is the
empty string, a default constant value is used instead.  The square
bracket operator returns the empty string if the parameter does not
exist.

The name is used in the HTML heading. The `HEsc.text` method is used
to escape any special characters, to prevent accidential or malicious
HTML injection.

When a Web browser sends a request to the site's URL the HTML page is
returned. In this document, the example URLs will show the hostname of
the server as "localhost"; if necessary, change it to the hostname or
IP address of the machine running your server.

Run the server and try visiting:

- <http://localhost:1024/>
- <http://localhost:1024/?name=friend>
- <http://localhost:1024/?name=me,+%3Cbr%3Emyself+%26+I>

The last example demonstrates the importance of using `HEsc.text`
to escape values.

Also visit something like <http://localhost:1024/nosuchpage> and the
basic built-in error page appears. To customize the error page, a
custom exception handler is used.

#### 1.8. Exception handler

An _exception handler_ processes any exceptions that are raised: either
by one of the request handlers or by the framework.

It is similar to a request handler, because it is a method that
returns a _Response_ object. But it is different, because it is also
passed the exception and sometimes a stack trace.

When setting up the server, set its exception handler in _main_
(anywhere before the server is run):

```dart
ws.exceptionHandler = myExceptionHandler;
```

And define the exception handler method as:

```dart
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

  var resp = ResponseBuffered(ContentType.HTML);
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
```

This exception handler customizes the error page when the
`NotFoundException` is encountered: it is raised when none of the
rules matched the request. Notice that it reports a different status
code if no rules for the method could be found (405
method not allowed), versus when some rules for the method exist but
their pattern did not match the requested path (404 not found).

Other exceptions can be detected and handled differently. But in this
example, they all produce the same error page.

Run this server and visit <http://localhost:1024/nosuchpage> to see
the custom error page.

### 2. HTML escaping methods

The `HEsc` class defines three static methods which are useful for
converting objects into Strings that are then escaped for embedded
into HTML.

- `attr` for escaping values to be inserted into attributes.
- `text` for escaping values to be inserted into element content.
- `lines` which is the same as `text`, but adds line breaks elements
   (i.e. `<br/>`) where newlines exist in the original value.

These methods will be used to escape values which might contain
characters with special meaning in HTML.

### 3. Parameters

The request handler methods can receive three different types of
parameters:

- path parametrs;
- query parameters; and
- post parameters.

#### 3.1. Path parameters

The path parameters are extracted from the path of the URL being
requested.

The path parameters are defined by the rule's pattern, which is made
up of components separated by a slash ("/").  Path parameters are
represented by a component starting with a colon (":") followed by the
name of the parameter.

The path parameters are made available to the handler via the
`pathParams` member of the _Request_ object.

This is an example of a rule with a fixed path, where each component
must match the requested URL exactly and there are no path
parameters.

    p.get("~/foo/bar/baz", handleParams);

This is an example with a single parameter:

    p.get("~/user/:name", handleParams);

This is an example with two parameters:

    p.get("~/user/:name/:orderNumber", handleParams);

The wildcard is a special path parameter that will match zero or more
segments in the URL path.

    p.get("~/product/*", handleParams);

Here is an example request handler that shows the parameters in
the request.

```dart
Future<Response> handleParams(Request req) async {
  var resp = ResponseBuffered(ContentType.HTML);
  resp.write("""
<html>
  <head>
    <title>Woomera Tutorial</title>
  </head>
  <body>
    <h1>Parameters</h1>
""");

  resp.write("<h2>Path parameters</h2>");
  _dumpParam(req.pathParams, resp);

  resp.write("<h2>Query parameters</h2>");
  _dumpParam(req.queryParams, resp);

  resp.write("<h2>POST parameters</h2>");
  _dumpParam(req.postParams, resp);

  resp.write("""
  </body>
</html>
""");
  return resp;
}

void _dumpParam(RequestParams p, ResponseBuffered resp) {
  if (p != null) {
    var keys = p.keys;

    if (keys.isNotEmpty) {
      resp.write("<p>Number of keys: ${keys.length}</p>");
      resp.write("<dl>");

      for (var k in keys) {
        resp.write("<dt>${HEsc.text(k)}</dt><dd><ul>");
        for (var v in p.values(k)) {
          resp.write("<li>${HEsc.text(v)}</li>");
        }
        resp.write("</ul></dd>");
      }

      resp.write("</dl>");
    } else {
      resp.write("<p>No parameters.</p>");
    }
  } else {
    resp.write("<p>Not available.</p>");
  }
}
```

Here are a few URLs to try:

- <http://localhost:1024/foo/bar/baz>
- <http://localhost:1024/user/jsmith>
- <http://localhost:1024/user/jsmith/123>
- <http://localhost:1024/product/widget>
- <http://localhost:1024/product/abc/def/ghi>

#### 3.2. Query parameters

The query parameters are the query parameters from the URL. That is,
the name-value pairs after the question mark ("?").

The path parameters are made available to the handler via the
`queryParams` member of the _Request_ object.  They are not (and
cannot) be specified in the rule.

Here are a few URLs to try:

- <http://localhost:1024/foo/bar/baz?a=b>
- <http://localhost:1024/foo/bar/baz?greeting=Hello&name=World>
- <http://localhost:1024/foo/bar/baz?item=a&item=b&item=c&code=123>

#### 3.3. Post parameters

The post parameters are extracted from the contents of a HTTP POST
request. Obviously, they are only available when processing a POST
request.

The path parameters are made available to the handler via the
`postParams` member of the _Request_ object, which is _null_ unless it
is a POST request.  They are not (and cannot) be specified in the
rule.

For example, try this form:



    <form method="POST" action="http://example.com/transaction">
      <input type="radio" name="type" value="out" id="w"/> <label for="w">Withdraw</label>
      <input type="radio" name="type" value="in" id="d"/> <label for="d">Deposit</label>
      <input type="text" name="amount"/>
    </form>

processed by the above handler prints out:

    "Hello World"

#### 3.4. Common aspects

The three parameter members are instances of the `RequestParams`
class.

It is important to remember that parameters can be repeated. For
example, checkboxes on a form will result in one instance of the named
parameter for every checkbox that is checked. This can apply to path
parameters, query parameters and post parameters.

##### 3.4.1. Retrieving parameters

The `RequestParams` class can be thought of as a _Map_, where the keys
are the names of the parameters which maps into a _List_ of values. If
there is only one value, there is still a list: a list containing only
one value.

The names of all the available parameters can be obtained using the
_keys_ method.

    for (var k in req.queryParams.keys) {
      print("Got a query parameter named: $k");
    }

All the values for a given key can be obtained using the _values_ method.

    for (var k in req.queryParams.keys) {
      var vList = req.queryParams.values(k);
      for (var v in vList) {
        print("$k = $v");
      }
    }
    
If your request handler is expecting only one value, the
square-bracket operator can be used to retrieve a single value instead
of a list.

     var t = req.queryParams["title"];

##### 3.4.2. Raw vs processed values

The methods described above for retrieving value(s) returns a cleaned up
processed version of the value. The processing:

- removes all leading whitespaces;
- removes all trailing whitespace;
- collapses multiple whitespaces in a row into a single whitespace; and
- convert all whitespace characters into the space character.

To obtain the unprocessed value, set _raw_ to true with the _values_ method:

    req.queryParams.values("category", raw: true);

##### 3.4.3. Expecting the unexpected

To make a robust application, do not make any assumptions about what
parameters may or may not be present: check everything and fail
gracefully. The parameters might be different from what is expected
because of programming errors, misuse or (worst case, but very
important to deal with) the application is under malicious attack.

If a parameter is missing, the square bracket operator returns an
empty string, and the _values_ method returns an empty list when it is
returning proceesed values. In raw mode, the _values_ method returns
null if the value does not exist: which is the only way to detect the
difference between the presence of a blank/empty parameter versus the
absence of the parameter.

An application might be designed to expect exactly one instance of a
parameter, but a malicious client might try to send two or more values
to break. The square bracket operator, which is used when only one
value is expected, will return the empty string if the multiple copies
of the parameter exist.

Both the names and values are always strings.

### 4. Exceptions

#### 4.1. Standard exceptions

All the exceptions thrown by the framework are subclasses
of the `WoomeraException` class.

- The `NotFoundException` is thrown when a matching rule is not found.
  The exception handler should produce a "page not found" error page
  with a HTTP response status of either `HttpStatus.NOT_FOUND` or
  `HttpStatus.METHOD_NOT_ALLOWED` depending on the value of its
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

#### 4.2 High-level exception handlers

High-level exception handlers are a type of handler used to process
exceptions that are raised. They are passed the request and the
exception, and are expected to generate a _Response_. The exception
handler should create a response that is as an error page for the
client.

```dart
Future<Response> myExceptionHandler(Request req
    Object exception, StackTrace st) async {
  var resp = ResponseBuffered(ContentType.HTML);
  resp.write("""
<html>
  <head><title>Error</title></head>
  <body>
    <h1>Error</h1>
    <p>Sorry, an error occured: ${HEsc.text(exception.toString())}</p>
  </body>
</html>
""");
  return resp;
}
```

Exception handlers can be associated with each pipelines and with the
server by setting the _exceptionHandler_ members.

Different exception handlers for different pipelines can be used to
handle exceptions differently. For example, one pipeline could be used
for a RESTful API and its exception handler produces a XML or JSON
error response; and other pipeline's exception handler could produce a
HTML error page.

#### 4.3 Low-level exception handling

In addition to the high-level exception handlers, a low-level
exception handler that can be associated with the server by setting
the _exceptionHandlerRaw_ member.

It is called a "low-level" or "raw" exception handler, because it
needs to process a Dart HttpRequest and generate a HTTP response
without the aid of the Woomera classes.

#### 4.4 Exception handling process

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

- If no high-level exception handler was attached to the server, the
  low-level exeption handler on the server is used.

- If there is no custom low-level exception handler, a default
  exception handler is used.

If one of those exception handlers throws an exception, the exception
it was processing is wrapped in an _ExceptionHandlerException_, which
is then passed to the next handler in the process.

It is recommended to provide at least one custom exception handler,
since the default exception handler just produces a plain text
response that purely functional and not pretty. It is common to just
provide a high-level server exception handler; and only provide the
others if there is a special need for them.

### 5. Responses

The request handlers and exception handlers must return a _Future_
that returns a _Response_ object. The _Response_ class is an abstract
class and three subclasses of it have been defined in the package:

- ResponseBuffered
- ResponseStream
- ResponseRedirect

#### 5.1. ResponseBuffered

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

#### 5.2. ResponseRedirect

This is used to generate a HTTP redirect, which tells the client to go
to a different URL.

#### 5.3. ResponseStream

This is used to produce the contents of the response from a stream.

#### 5.4. Common features

With all three types of responses, the application can:

- Set the HTTP status code;
- Create HTTP headers; and/or
- Create or delete cookies.

#### 5.5 Common handlers provided

##### 5.5.1. Static file handler

The package includes a request handler for serving up files and
directories from the local disk. It can be used to serve static files
for all or some of the Web server (for example, the images and
stylesheets).

See the API documentation for the _StaticFiles_ class.

##### 5.5.2. Proxy handler

The package includes a request handler for proxying requests to
a different server. A request for one URI is converted into a
target URI and the request is forward to it. The response from
the target URI is used as the response.

See the API documentation for the _Proxy_ class.

### 6. Sessions

The framework provides a mechanism to manage sessions. HTTP is a
stateless protocol, but sessions have been added to support the
tracking of state.

A session can be created and attached to a HTTP request.  That session
will be attached to subsequent _Request_ objects.  The framework
handles the preserving and restoration of the session using either
session cookies or URL rewriting. The application can terminate a
session, or they will automatically terminate after a nominated
timeout period after they were last used.

### 7. Logging

Woomera uses the [Logging](https://pub.dartlang.org/packages/logging) package
for logging.

Please see the woomera library API documentation for the logger names.

In general, a logging level of "INFO" should produce no logging unless there is
a problem.  Setting the "woomera.request" logger to "FINE" logs the URL
of every HTTP request, which might be useful for testing.

### 8. References

- Dart tutorial on Writing HTTP clients and servers
<https://www.dartlang.org/docs/tutorials/httpserver/> (the package
Woomera is built on top of).

- Open Web Application Security Project
  <https://www.owasp.org/index.php/Guide_Table_of_Contents>
