/// This is the library that is normally imported when using Woomera. It
/// exports both the `core` library and the `annotations` library.
///
/// **Note: this library no longer exports the (now deprecated) `scan` library.
/// If legacy code requires the _scan_ library, it must be explicitly
/// imported.**
///
/// ## Usage
///
/// To create a Web server (a program that listens for HTTP requests
/// and produces HTTP responses), create a `Server` object and
/// invoke its _run_ method.
///
/// ```dart
/// final ws = Server();
/// ...
/// await server.run();
/// ```
///
/// The server only listens for requests on port 80 of the IPv4 loopback address
/// (i.e. 127.0.0.1). This can be changed by properties on the Server object.
///
/// ```dart
/// final ws = Server()
///   ..bindAddress = InternetAddress.anyIPv6
///   ..bindPort = 8080;
/// ```
///
/// The server should be assigned one or more `ServerPipeline` objects
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

export 'annotations.dart';
export 'core.dart';
