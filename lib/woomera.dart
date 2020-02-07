/// Package for implementing Web servers.
///
/// Listens for HTTP requests and invokes the appropriate request handler,
/// based on rules that are matched against the request. Supports features such
/// as session management and exception handling.
///
/// ## Usage
///
/// A Web server can be created by:
///
/// 1. Define functions to act as request handlers and annotate them with
/// [Handles] objects.
/// 2. Create an instance of [Server].
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

library woomera;

//----------------------------------------------------------------

import 'dart:async';
import 'dart:convert' show Encoding, utf8;
import 'dart:io';
import 'dart:mirrors';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:uuid/uuid.dart';

//----------------------------------------------------------------
// export 'src/...dart';

part 'src/annotations.dart';
part 'src/core_request.dart';
part 'src/core_response.dart';
part 'src/exceptions.dart';
part 'src/h_esc.dart';
part 'src/handler.dart';
part 'src/handler_debug.dart';
part 'src/handler_proxy.dart';
part 'src/handler_static_files.dart';
part 'src/pattern.dart';
part 'src/request.dart';
part 'src/request_params.dart';
part 'src/response.dart';
part 'src/server.dart';
part 'src/server_pipeline.dart';
part 'src/server_rule.dart';
part 'src/session.dart';
part 'src/simulated_headers.dart';
part 'src/simulated_response.dart';

//----------------------------------------------------------------
// Loggers used in the Woomera package.

Logger _logServer = Logger('woomera.server');

Logger _logHandles = Logger('woomera.handles');

Logger _logRequest = Logger('woomera.request');
Logger _logRequestHeader = Logger('woomera.request.header');
Logger _logRequestParam = Logger('woomera.request.param');

Logger _logResponse = Logger('woomera.response');

Logger _logSession = Logger('woomera.session');

Logger _logStaticFiles = Logger('woomera.static_file');

Logger _logProxy = Logger('woomera.proxy');
