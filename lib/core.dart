/// Used to implement a program that listens for HTTP requests and produces
/// HTTP responses.
///
/// # Overview
///
/// A Web server is represented by a [Server] object that has been configured
/// with an ordered list of
/// one or more [ServerPipeline] objects. Pipelines have a list of
/// _request handlers_, which process the
/// HTTP requests to generate
/// the HTTP responses.
///
/// When a _request handler_ is registered with a pipeline, it is associated
/// with a rule.
/// A rule has a HTTP method (e.g. GET or POST) and a pattern for matching
/// against the path of the request URI (e.g. "~/api/foo/:uuid").
///
/// When a HTTP request is received, the rules in the server's pipelines
/// are searched for a match.
/// When a match is found, the rule's _request handler_ is invoked.
///
/// # Request handlers
///
/// Request handlers are functions (or static methods) which must match
/// the [RequestHandler] function signature.
///
/// ## Requests
///
/// Request handlers are passed a [Request] object representing the HTTP
/// request.
///
/// The [RequestParams] class represents parameters from the HTTP request.
/// It is used to represent the URI query parameters, path parameters
/// (corresponding to segments defined by the pattern) and post parameters.
/// Post parameters are only present if the HTTP request has the content-type
/// of "application/x-www-form-urlencoded"—which is the HTTP request
/// produced by submitting a HTML form with the POST method.
///
/// If the request belongs to a session, the request includes a [Session]
/// object.
///
/// ## Responses
///
/// Request handlers must return a Future to a [Response] which is used to
/// generate the HTTP response.
///
/// There are four concrete _Request_ classes:
///
/// - [ResponseBuffered] - where the body is buffered before it is sent;
/// - [ResponseStream] - where the body comes from a stream
/// - [ResponseRedirect] - which produces a _HTTP 303 Redirect_ response;
/// - [ResponseNoContent] - which produces a _HTTP 204 No Content_ response
///   with no body;
///
/// ### Generating HTML
///
/// HTML response is usually produced by writing HTML into a
/// _ResponseBuffered_.
///
/// The [HEsc] class contains static methods to escape string values for use
/// in HTML formatted responses (e.g. converting `<` to `&lt;`).
///
/// ### Static files
///
/// The [StaticFiles] class can be used to create a _request handler_ that
/// produces a response from files and directories.
///
/// # Testing
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
/// ## Logging
///
/// The [Logger](https://pub.dartlang.org/packages/logging) package is used for
/// logging.
///
/// Some of the available loggers are named:
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
///
/// See the [loggers] variable
/// for a comprehensive list of all the Loggers used in this library.

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

part 'src/core/core_request.dart';
part 'src/core/core_response.dart';
part 'src/core/exceptions.dart';
part 'src/core/h_esc.dart';
part 'src/core/handler.dart';
part 'src/core/handler_debug.dart';
part 'src/core/handler_proxy.dart';
part 'src/core/handler_static_files.dart';
part 'src/core/loggers.dart';
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
