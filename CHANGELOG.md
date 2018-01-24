# Changelog

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
