Woomera
=======

## Introduction

Woomera is a Dart package for implementing Web servers.

It is used to create server-side Dart programs that function as a Web
server. A Web server simply listens for HTTP requests and respond to
them with HTTP responses.  But it quickly gets complicated (and
difficult to maintain) when there are many different types of HTTP
requests to process, different errors to detect and state needs to be
maintained between HTTP requests. This package aims to reduce that
complexity.

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
  rewriting works even if cookies have been disabled in the browser.

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

- Can either use annotations to dynamically identify handler methods,
  or statically identify them without relying on annotations. Static
  identification does not require the _dart:mirrors_ package.  A
  _dumpServer_ function is available to make it easy to switch between
  dynamic and static methods.

This following is a tutorial which provides an overview the main
features of the package. For details about the package and its
advanced features, please see the API documentation.

## Tutorial

### 1. A basic Web server

#### 1.1. Overview

This is a basic Web server that serves up two HTML pages.

```dart
import 'dart:async';
import 'dart:io';
import 'package:woomera/woomera.dart';

Future<void> main() async {
  final ws = serverFromAnnotations()
    ..bindAddress = InternetAddress.anyIPv6
    ..bindPort = 1024;

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
```

#### 1.2. Importing the package

Any program that uses the framework must first import the package:

```dart
import 'package:woomera/woomera.dart';
```

#### 1.3. Creating the server

A _Server_ object must be created and configured for the TCP/IP
address and port it will listen for HTTP requests on.

```dart
final ws = serverFromAnnotations()
  ..bindAddress = InternetAddress.anyIPv6
  ..bindPort = 1024;
```

For this example, it sets it to `InternetAddress.ANY_IP_V6`, so the
service is listening to connections on any interface (i.e. both
loopback and public addresses).

When using `InternetAddress.ANY_IP_V6`, the optional `v6Only` member
controls whether IPv4 addresses are included or not. It defaults to
false, meaning it listens on both any IPv4 and any IPv6 address.  If
it is true, it only listens on any IPv6 addresses, and ignore all IPv4
addresses.  To make it easy to connect to, this example uses ANY_IP_V6
and leaves _v6Only_ set to false.

Often, when deployed in production, the service may be behind a
reverse Web proxy (e.g. Apache or Nginx). The default bind address is
`InternetAddress.LOOPBACK_IP_V4` can be used to for this: it means
only listens for connections on 127.0.0.1 (i.e.  only clients from the
same host can connect to it). Note: when configuring the reverse
proxy, use 127.0.0.1. Avoid configuring it with "localhost", because
on some systems that causes it to first try the IPv6 localhost address
(::1) before trying the IPv4 localhost address: it will work, but will
be less efficient.

A port number 1024 or greater should be used, because the lower port
numbers are require special permission to use.

#### 1.4 Annotating request handlers

When a server is created using `serverFromAnnotations`, it scans the
program for top-level functions and static methods. Those with
`Handles` annotations are used to create rules for handling HTTP
requests.  When processing a HTTP request, if the rule matches the
request, the request handler is invoked.

A `Server` can also be created using its constructor, but all the
request handlers and exception handers would need to be explicitly
registered with it. It is more tedious than automatically registering
them from the annotations, but is necessary when the Dart Mirrors
package can't be used. Scanning of the program for annotations
requires the Dart Mirrors package.

A request handler is a function with a _Request_ parameter and returns
a Future to a _Response_.

This example has two request handler functions. They have these two
annotations on them:

```dart
@Handles.get('~/')
...

@Handles.get('~/:greeting')
...
```

A `Handles` object indicates what HTTP method (e.g. GET, POST, PUT)
and the pattern that is matched against the request URL path.  The
request handlers in this example process HTTP GET requests.

The first pattern, "~/", corresponds to the root path. That is, this request handler
will match the HTTP request for "http://localhost:1024/".

The second pattern, "~/:greeting", has a segment with a variable
called "greeting".  For example, this request handler will match the
HTTP request for "http://localhost:1024/Hello" and set the path
variable named "greeting" to "Hello".

See the API documentation for more details about patterns. They
consist of segments separated by a slash ("/") and the first segment
must always be a tilde ("~"). There are several types of path
segments: the most commonly used are literal segments and variable
segments. Literal segments which must match exactly the path segment
from the request URL's path.  Variable segments match any path
segment, and the value is made available to the request handler to
use.

#### 1.5. Running the server

After configuring the _Server_, start it using its _run_ method and it
will start listening for HTTP requests.

The _run_ method returns a _Future_ that completes when/if the Web
server finishes running, but normally a Web server is designed to run
forever without stopping.

```dart
await ws.run();
```

When a HTTP request arrives, the request handler its method and path
matches will be invoked.

#### 1.6. Creating a Response

##### 1.6.1 Generating a buffered response

The _ResponseBuffered_ is commonly used to generate HTML pages_ for
the HTTP response. It acts as a buffer where the contents is appended
to it using the _write_ method.

The different _Response_ classes will be described later.

##### 1.6.2 Escaping HTML attribute values

The _handleTopLevel_ request handler simply generates a static HTML page.

The `HEsc.attr` static method is used to escape values used inside
HTML attributes. It will ensure any ampersands, less than signs,
greater than signs, single quotes and double quotes are escaped.

##### 1.6.3 Rewriting internal paths to produce external paths

The two URLs are produced using the `rewriteUrl` method of the Request
object. That takes an _internal path_ and produces an _external path_
suitable for the Web browser to use. The distinction between these
will be described later, but for now the _rewriteUrl_ method coverts
an _internal path_ to an _external path_.

This code:

```dart
final gDayUrl = req.rewriteUrl("~/G'day");

resp.write('<li><a href="${HEsc.attr(gDayUrl)}">Good day</a></li>');
```

Results in the HTML response containing:

```html
<li><a href="/G&apos;day">Good day</a></li>
```

#### 1.7 Parameter handling

The _handleGreeting_ request handler shows how parameters from the HTTP request
are passed into the request handler via the _Request_.

The _pathParams_ member contains the parameters from the HTTP request's
URL's path, according to the pattern. Since the pattern was
"~/:greeting", the path parameter named "greeting" will be set to the
first segment in the path.

The _queryParams_ member contains the parameters from the HTTP
request's URL's query parameters.

For example, if the request URL was
"http://localhost/foo?abc=def&xyz=uvw", then the path parameter named
"greeting" will be set to "foo"; and the query parameters will contain
a parameter named "abc" with the value of "def" and a parameter named
"xyz" with the value of "def".

For retrieving parameters, the `[]` operator is a high-level method
that always returns a single string whose value is trimmed of any
leading and trailing whitespace.  If the parameter does not exist, it
returns the empty string.  The _values_ method provides a lower-level
access to the parameters.

#### 1.8 Escaping HTML text

The response produced by _handleGreeting_ uses `HEsc.text` 
 to escape values used inside HTML text. It is similar to the
_HEsc.attr_, but does not escape single quotes and double quotes.

If the value wasn't escaped, then this URL would produce the wrong HTML:
"http://localhost:1024/Hello%20%26%20Goodbye".

There is also `HEsc.lines`, which is similar to _HEsc.text_ but
also converts any new-lines into `<br>` tags.

#### 1.9 Exception handler

Visiting a URL like "http://localhost:1024/nosuchpage/foo" and the
basic built-in error page appears. To customize the error page, a
custom exception handler is used.

An _exception handler_ processes any exceptions that are raised: either
by one of the request handlers or by the framework.

It is similar to a request handler, because it is a method that
returns a _Response_ object. But it is different, because it is also
passed the exception and sometimes a stack trace.

Here is an example of a server exception handler:

```dart
@Handles.exceptions()
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
```

This exception handler customizes the error page when the
`NotFoundException` is encountered: which is raised by the framework
when none of the rules matched the request. Notice that it reports a
different HTTP status code if no rules for the HTTP request method
could be found (405 method not allowed), versus when some rules for
the method exist but their pattern did not match the requested path
(404 not found).

### 2. Patterns vs internal paths vs external paths

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

#### 2.1 Why use internal paths?

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

### 3. Parameters

#### 3.1 Types of parameters

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


#### 3.2. Retrieving parameters

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

#### 3.3 Raw vs processed values

The methods described above for retrieving value(s) returns a cleaned up
version of the value which:

- removes all leading whitespaces;
- removes all trailing whitespace;
- collapses multiple consecutive whitespaces one whitespace; and
- convert all whitespace characters into the space character.

To obtain the unprocessed value, set _raw_ to true with the _values_ method:

    req.queryParams.values('category', raw: true);

#### 3.4 Expect the unexpected

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


### 4. Pipelines

#### 4.1 The default pipeline

A server has a collection of rules. If a rule matches the HTTP request
(i.e. matches the HTTP method and the request path), then its response
handler is invoked.  The order in which rules are examined, to see if
they match the HTTP request, is determined by pipelines.

Web applications do not have to deal with pipelines if they don't want
to.  Applications only need to deal with pipelines if they want more
control over how and when rules are matched (and consequently which
request handlers are invoked).

In the above example, the default pipeline was used. The default
pipeline is created if the _serverFromAnnotations` constructor is
used with no parameters. The annotations define rules for the default
pipeline, if no _pipeline_ parameter is passed to the _Handles_
constructor.

``` dart
@Handles.get('~/foo/bar')
...

final server = serverFromAnnotations();
```

#### 4.2 Behavour of pipelines

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
rules are tested. The other way is to specify a _priority_ in the
_Handles_ annotations, or to manually create rules and append them to
the pipeline. Rules created from annotations are sorted by their
priority first and then by their pattern.

The other useful feature of pipelines is each pipeline can have its
own exception handler, in addition to the server's exception handler.
This is useful if exceptions from different sets of request handlers
should be handled differently. For example, there could be an exception
handler that generates a HTML error page and another that generates an
error in JSON.

#### 4.3 Creating multiple pipelines

Multiple pipelines can be created by providing a list of pipeline
names to the _serverFromAnnotations_ constructor. To associate an
annotation to a pipeline, specify the pipeline name as a parameter to
the _Handles_ constructor.

``` dart
@Handles.get('~/v1/account', pipeline: 'api')
...

@Handles.get('~/welcome') // for the default pipeline
...

@Handles.get('~/foo, pipeline: 'third')
...


final server = serverFromAnnotations(['api', Pipeline.defaultName, 'third']);
```

Note: if a list of names is provided to the _serverFromAnnotations_
constructor, the default pipeline is not created unless its name is
explicitly one of the names in the list.

#### 4.4 Manually creating pipelines and rules

Pipelines and rules manually, without using annotations.  In version
4.3.0 and earlier, that was the only way.

This approach is still possible, but using annotations leads to more
easily managed code. The manual method may be deprecated in a future
version.

### 5. Exceptions

#### 5.1. Standard exceptions

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

#### 5.2 High-level exception handlers

High-level exception handlers are a type of handler used to process
exceptions that are raised. They are passed the request and the
exception, and are expected to generate a _Response_. The exception
handler should create a response that is as an error page for the
client.

##### 5.2.1 Server exception handler

There can be at most one _server exception handler_. Servers should
provide one, because it is used to indicate a page is not found.

```dart
@Handles.exceptions()
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

##### 5.2.2 Pipeline exception handler

Each pipeline can also have its own exception handler.

``` dart
@Handles.pipelineExceptions()
Future<Response> myExceptionHandler(Request req
    Object exception, StackTrace st) async {
	// for the default pipeline
}

@Handles.pipelineExceptions(pipeline: 'myCustomPipeline')
Future<Response> myExceptionHandler(Request req
    Object exception, StackTrace st) async {
	// for the pipeline named "myCustomPipeline"
}
```

Different exception handlers for different pipelines can be used to
handle exceptions differently. For example, one pipeline could be used
for a RESTful API and its exception handler produces a XML or JSON
error response; and other pipeline's exception handler could produce a
HTML error page.

#### 5.3 Low-level exception handling

In addition to the high-level exception handlers, a low-level
raw exception handler can be associated with the server.

It is called a "low-level" or "raw" exception handler, because it
needs to process a Dart HttpRequest and generate a HTTP response
without the aid of the Woomera classes.

``` dart
@Handles.rawExceptions()
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

#### 5.4 Exception handling process

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



### 6. Responses

The request handlers and exception handlers must return a _Future_
that returns a _Response_ object. The _Response_ class is an abstract
class and three subclasses of it have been defined in the package:

- ResponseBuffered
- ResponseStream
- ResponseRedirect

#### 6.1. ResponseBuffered

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

#### 6.2. ResponseRedirect

This is used to generate a HTTP redirect, which tells the client to go
to a different URL.

#### 6.3. ResponseStream

This is used to produce the contents of the response from a stream.

#### 6.4. Common features

With all three types of responses, the application can:

- Set the HTTP status code;
- Create HTTP headers; and/or
- Create or delete cookies.

#### 6.5 Common handlers provided

##### 6.5.1. Static file handler

The package includes a request handler for serving up files and
directories from the local disk. It can be used to serve static files
for all or some of the Web server (for example, the images and
stylesheets).

See the API documentation for the _StaticFiles_ class.

##### 6.5.2. Proxy handler

The package includes a request handler for proxying requests to
a different server. A request for one URI is converted into a
target URI and the request is forward to it. The response from
the target URI is used as the response.

See the API documentation for the _Proxy_ class.

### 7. Sessions

The framework provides a mechanism to manage sessions. HTTP is a
stateless protocol, but sessions have been added to support the
tracking of state.

A session can be created and attached to a HTTP request.  That session
will be attached to subsequent _Request_ objects.  The framework
handles the preserving and restoration of the session using either
session cookies or URL rewriting. The application can terminate a
session, or they will automatically terminate after a nominated
timeout period after they were last used.

### 8. Logging

Woomera uses the [Logging](https://pub.dartlang.org/packages/logging)
package.  See the Woomera library API documentation for the logger
names.

In general, a logging level of "INFO" should produce no logging
entries, unless there is a problem.  Setting the "woomera.request"
logger to "FINE" logs the URL of every HTTP request, which might be
useful for testing.

### 9. References

- Dart tutorial on Writing HTTP clients and servers
<https://www.dartlang.org/docs/tutorials/httpserver/> (the package
Woomera is built on top of).

- Open Web Application Security Project
  <https://www.owasp.org/index.php/Guide_Table_of_Contents>
