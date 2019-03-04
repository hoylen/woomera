/// Package for implementing Web servers.
///
/// HTTP request dispatcher with session management.
///
/// ## Usage
///
/// A Web server can be created by:
///
/// 1. Create an instance of [Server].
/// 2. Getting the [ServerPipeline] that was created by the server.
/// 3. Define handlers for HTTP requests and exception handlers for the pipeline.
/// 4. Call the [Server.run] method on the server.
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
/// Usually, the one [ServerPipeline] automatically created by the server is
/// sufficient.
///
/// For some situations, multiple pipelines can be useful. For example, when
/// it is useful to have a different exception handler for some rules.
///
/// ## Logging
///
/// The [Logger](https://pub.dartlang.org/packages/logging) package is used for
/// logging. The available loggers are named:
///
/// - woomera.server
/// - woomera.request
/// - woomera.request.header
/// - woomera.request.param
/// - woomera.response
/// - woomera.session
/// - woomera.static_file - static file handler
/// - woomera.proxy - proxy handler

library woomera;

//----------------------------------------------------------------

import 'dart:async';
import 'dart:convert' show Encoding, utf8;
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:uuid/uuid.dart';

//----------------------------------------------------------------
// export 'src/...dart';

part 'src/exceptions.dart';
part 'src/h_esc.dart';
part 'src/handler_debug.dart';
part 'src/handler_proxy.dart';
part 'src/handler_static_files.dart';
part 'src/request.dart';
part 'src/core_request.dart';
part 'src/request_params.dart';
part 'src/server_rule.dart';
part 'src/server_pipeline.dart';
part 'src/handler.dart';
part 'src/response.dart';
part 'src/core_response.dart';
part 'src/server.dart';
part 'src/session.dart';
part 'src/simulated_headers.dart';
part 'src/simulated_response.dart';

//----------------------------------------------------------------
// Loggers used in the Woomera package.

Logger _logServer = new Logger("woomera.server");
Logger _logRequest = new Logger("woomera.request");
Logger _logRequestHeader = new Logger("woomera.request.header");
Logger _logRequestParam = new Logger("woomera.request.param");

Logger _logResponse = new Logger("woomera.response");
Logger _logSession = new Logger("woomera.session");

Logger _logStaticFiles = new Logger("woomera.static_file");
Logger _logProxy = new Logger("woomera.proxy");
