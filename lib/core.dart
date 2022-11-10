/// Core library.
///
/// This library contains the core features of Woomera, but without the
/// scanning for annotation functions.
///
/// Normally, use the full `woomera` library instead. But if Dart Mirrors
/// cannot be used (e.g. when the program is compiled using _dart compile_),
/// then this `core` library can be used by itself.
///
/// Listens for HTTP requests and invokes the appropriate request handler,
/// based on rules that are matched against the request. Supports features such
/// as session management and exception handling.
///
/// ## Usage
///
/// Define request handler and exception handler functions. Annotations can
/// be placed on them, but will be ignored if the scanner is not used.
///
/// ```dart
/// import 'package:woomera/core.dart';
///
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
/// Then create a `Server` and explicitly register all the handler functions
/// with it. Then run the server.
///
/// ```dart
/// Future main() async {
///   final server = serverFromAnnotations()
///     ..bindAddress = InternetAddress.anyIPv6
///     ..v6Only = false // false = listen to any IPv4 and any IPv6 address
///     ..bindPort = port;
///
///   server.pipelines.first.get('~/', homePage);
///
///   await server.run();
/// }
/// ```
///
/// Explicitly registering all the handlers can be tedious. Therefore,
/// automatically populating the server from annotations on the handler
/// functions is usually a better approach. The functions for automatically
/// populating a server is defined in the _scan_ library, and can be imported
/// by importing the main `woomera` library.
///
/// ## Simulated HTTP requests for testing
///
/// Instead of invoking `run` on the server, the [Server.simulate] method
/// can be used to test the server.
///
/// Create a simulated HTTP request using [Request.simulatedGet],
/// [Request.simulatedPost] or [Request.simulated] and then pass it to the
/// server's _simulate_ method. The response can then be tested for the
/// expected HTTP response.
///
/// This type of testing can be used to supplement testing with a Web browser.
/// It has the advantage of running faster than automating the actions of a
/// Web browser, but it also has the disadvantge that it cannot execute any
/// client-side JavaScript.
///
/// ## Multiple pipelines
///
/// Usually, the default [ServerPipeline] automatically created by the server is
/// sufficient.
///
/// For some situations, multiple pipelines can be useful. For example, when
/// it is useful to have a different exception handler for different sets of
/// rules, or to better control the order in which rules are used.
///
/// ## Logging
///
/// The [Logger](https://pub.dartlang.org/packages/logging) package is used for
/// logging. The available loggers are named:
///
/// - woomera.server - logs general server behaviour
/// - woomera.handles - logs rules created via Handles annotations
/// - woomera.request - logs HTTP requests
/// - woomera.request.header - details about the headers in the HTTP requests
/// - woomera.request.param - details about the parameters extracted from HTTP requests
/// - woomera.response - logs responses produced
/// - woomera.session - logs information related to state management
/// - woomera.static_file - logs static file handler
/// - woomera.proxy - logs proxy handler

library core;

//----------------------------------------------------------------

import 'dart:async';
import 'dart:convert' show Encoding, utf8;
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:uuid/uuid.dart';

//----------------------------------------------------------------
// export 'src/...dart';

part 'src/core/annotations.dart';
part 'src/core/core_request.dart';
part 'src/core/core_response.dart';
part 'src/core/exceptions.dart';
part 'src/core/h_esc.dart';
part 'src/core/handler.dart';
part 'src/core/handler_debug.dart';
part 'src/core/handler_proxy.dart';
part 'src/core/handler_static_files.dart';
part 'src/core/pattern.dart';
part 'src/core/request.dart';
part 'src/core/request_params.dart';
part 'src/core/response.dart';
part 'src/core/server.dart';
part 'src/core/server_pipeline.dart';
part 'src/core/server_rule.dart';
part 'src/core/session.dart';
part 'src/core/simulated_connection.dart';
part 'src/core/simulated_core_request.dart';
part 'src/core/simulated_headers.dart';
part 'src/core/simulated_response.dart';

//----------------------------------------------------------------
// Loggers used in the Woomera package.

Logger _logServer = Logger('woomera.server');

Logger _logRequest = Logger('woomera.request');
Logger _logRequestHeader = Logger('woomera.request.header');
Logger _logRequestParam = Logger('woomera.request.param');

Logger _logResponse = Logger('woomera.response');
Logger _logResponseCookie = Logger('woomera.response.cookie');

Logger _logSession = Logger('woomera.session');

Logger _logStaticFiles = Logger('woomera.static_file');

Logger _logProxy = Logger('woomera.proxy');
Logger _logProxyRequest = Logger('woomera.proxy.request');
Logger _logProxyResponse = Logger('woomera.proxy.response');
