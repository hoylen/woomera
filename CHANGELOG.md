## 7.1.1

- Fixed bug in isCustomExceptionHandler and isCustomRawExceptionHandler.

## 7.1.0

- Added NoResponseFromHandler exception.
  A future release is planning to change the handler return type from
  Future<Response?> to Future<Response>, and this exception must be
  thrown instead of the Future completing with null.
- Fixed _dumpServer_ generated code to work with null safety.
- Stack trace passed to exception handlers now indicates the correct source.

## 7.0.2

- Fixed bug that forces session query parameters to always be used.

## 7.0.1

- Added optional message to MalformedPathException.
- Fixed bug preventing query strings from containing question marks in values.

## 7.0.0

- Null safety release.
- Added additional body methods to the SimulatedResponse class.
- Reverted StackTrace parameter to be mandatory in exception handlers.
- Added use of includeDartVersionComment in dump_server.dart.

## 6.0.0

- Breaking change: Proxy constructor no longer has HTTP method parameter.
- Added session ID to log message when multiple session IDs are encountered.
- Fixed Proxy work when client requests keep-alive connections.

## 5.4.0

- Added mode for handling parameter whitespace and line terminators.
- Deprecated the "raw" parameter: use the new mode parameter instead.
- Upgraded to uuid 2.1.0, since earlier versions generated non-unique UUIDs.

## 5.3.0

- Enhancements to dumpServer to generate code that doesn't need dart:mirrors.

## 5.2.0

- Added support for Dart 2.8: preserveHeaderCase for SimulatedHttpHeaders.

## 5.1.0

- Merged ServerPipeline.registerInternal into the register method.
- Request.pathSegments now works with server base paths.
- Improved detection of redundant rules with patterns that match the same paths.
- Expanded dumpServer code to take the same arguments as serverFromAnnotations.

## 5.0.0

- Fixed annotation scanner to work when there are Dart extensions.
- Separated annotation scanning code into a separate library.
- Breaking change: Server.fromAnnotations becomes serverFromAnnotations.
- Breaking change: ServerPipeline.fromAnnotations serverPipelineFromAnnotations.
- Removed deprecated Response.header method (use headerAdd, headerAddDate).
- Removed deprecated Response.headers (use headerExists, headerNames, etc).
- Removed deprecated RequestFactory (use RequestCreator).
- Removed deprecated Server.requestFactory (use Server.requestCreator).
- Removed deprecated Handles.Handles (use Handles.request).
- Removed deprecated Request.hasSession (use session != null).

## 4.5.0

- Added the use of annotations to create exception handlers.

## 4.4.0

- Added the use of annotations to create rules on pipelines.

## 4.3.1

- Code clean up to satisfy pana 0.13.2 health checks.

## 4.3.0

- Include query parameters in URL of proxy requests.
- Added support for a low-level exception handler.
- Added headerAddDate method for adding headers with dates.
- Automatically add Content-Length header when using ResponseBuffered.
- Made settings headers in the Response case-independent.

## 4.2.0

- Removed warning when redirecting to an absolute path/URL.
- Updated dependencies to allow uuid v2.0.1 and test v1.6.3 to be used.

## 4.1.0

- Support for using static file handler with reverse proxies on non-standard ports.

## 4.0.1

- Fixed content-type for redirections.
- Fixed bug with redirection URL for directories with static files.

## 4.0.0

- Workaround for bug in Dart 2.1.x which prevents cookies from being deleted.
- Merged in changes from v2.2.2.
- Added proxy handler.
- Simulation mechanism for testing servers.
- Added external path to internal path conversion method.

## 3.0.1

- Fixed problem with publishing documentation on pub.dartlang.org.

## 3.0.0

- Updated the upper bound of the SDK constraint to <3.0.0.
- Changed names to use new Dart 2 names.

## 2.2.2

- Responds with HTTP 400 Bad Request if URL has malformed percent encodings.
- Change logging level for FormatExceptions when parsing query/POST params.

## 2.2.1

- This version runs under Dart 1.
- Updated dependencies to allow for Dart 2 compatible versions to be used.

## 2.2.0

- Changed RequestFactory to return FutureOr<Request> instead of Request.
- Added release method on Request class to perform cleanup operations.
- Deprecated requestFactory: renamed to requestCreator.

## 2.1.1

- Included Length, Last-Modified, and Date HTTP headers for StaticFiles.

## 2.1.0

- Added ability to retrieve the number of active sessions.
- Added access to creation time for sessions.
- Added expiry time for sessions.
- Stopping a server also terminates any sessions.

## 2.0.0

- Code made sound to support Dart strong mode.
- Removed arbitrary properties from Request and Session: use subtypes instead.
- Changed default bindAddress from LOOPBACK_IP_V6 to LOOPBACK_IP_V4.
- Added convenience methods for registering PUT, PATCH, DELETE and HEAD handlers.
- Added coverage tests.

## 1.0.5

- Upgraded version dependency on uuid package.

## 1.0.4

2016-09-29

- Fixed bug with parallel processing of HTTP requests.

## 1.0.3

2016-05-11

- Fixed potential issue with URL rewriting in Chrome with GET forms.

## 1.0.2

2016-05-06

- Improved exception catching in request processing loop.

## 1.0.1

2016-04-28

- Fixed homepage URL.

## 1.0.0

2016-04-23

- Initial release.
