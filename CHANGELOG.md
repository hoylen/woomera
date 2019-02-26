# Changelog

## 3.1.0

- Detects bug in Dart 2.1.x which prevents cookies from being deleted.
- Merged in changes from v2.2.2.
- Added proxy handler.

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
