/// Main library: includes both core and scan libraries.
///
/// This is the library that is normally imported when using Woomera. It
/// includes features from both the `core` library and the `scan` library.
///
/// If the Dart Mirrors package is not usable (e.g. if compiling with
/// _dart2native_), then use the _core_ library instead.
///
/// ## Usage
///
/// Annotate requests handlers and exception handlers using instances of the
/// `Handles` class (which is defined in the _core_ library).
///
/// ```dart
/// import 'package:woomera/woomera.dart';
///
/// @Handles.get('~/')
/// Future<Response> homePage(Request req) async {
///   final resp = ResponseBuffered(ContentType.html)..write('''
/// <!DOCTYPE html>
/// <head>
///   <title>Example</title>
/// </head>
/// <html>
///   <body>
///   <p>Hello world!</p>
///   </body>
/// </html>
/// ''');
///   return resp;
/// }
/// ```
///
/// Then create a `Server` using the `serverFromAnnotations` function, which
/// will automatically populate the server using the _Handles_ annotations.
/// Then run the server.
///
/// ```dart
/// Future main() async {
///   final server = serverFromAnnotations()
///     ..bindAddress = InternetAddress.anyIPv6
///     ..v6Only = false // false = listen to any IPv4 and any IPv6 address
///     ..bindPort = port;
///
///   await server.run();
/// }
/// ```

library woomera;

export 'core.dart';
export 'scan.dart';
