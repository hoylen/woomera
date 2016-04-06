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
/// 4. Add the pipe to the server.
/// 5. Call the [Server.run] method on the server.
///
/// ## Multiple pipelines
///
/// Usually, the one [ServerPipeline] automatically created by the server is
/// sufficient.
///
/// For some situations, multiple pipelines can be useful. For example, when
/// it is useful to have a different exception handler for some rules
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

library woomera;

//----------------------------------------------------------------

import 'dart:io';
import 'dart:async';
import 'dart:convert' show Encoding, UTF8;

import 'package:logging/logging.dart';
import 'package:uuid/uuid.dart';

//----------------------------------------------------------------
// export 'src/...dart';

part 'src/request.dart';
part 'src/exceptions.dart';
part 'src/h_esc.dart';
part 'src/handler_debug.dart';
part 'src/handler_static_files.dart';
part 'src/request_params.dart';
part 'src/server_rule.dart';
part 'src/server_pipeline.dart';
part 'src/handler.dart';
part 'src/response.dart';
part 'src/server.dart';
part 'src/session.dart';

//----------------------------------------------------------------

/// Loggers used in the Woomera package.
///
Logger _logServer = new Logger("woomera.server");
Logger _logRequest = new Logger("woomera.request");
Logger _logRequestHeader = new Logger("woomera.request.header");
Logger _logRequestParam = new Logger("woomera.request.param");

Logger _logResponse = new Logger("woomera.response");
Logger _logSession = new Logger("woomera.session");


// Some documents:
// HttpServer: https://www.dartlang.org/docs/tutorials/httpserver/
// Shelf: https://pub.dartlang.org/packages/shelf

// https://www.owasp.org/index.php/Guide_Table_of_Contents
