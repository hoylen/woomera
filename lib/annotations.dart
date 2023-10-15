/// Used to annotate functions used to configure _Server_ and _ServerPipeline_.
///
/// # Overview
///
/// The [WoomeraAnnotation] is the base class for:
///
/// - [Handles] - annotation for request handlers;
/// - [RequestHandlerWrapper] - annotation for the wrapper;
/// - [PipelineExceptionHandler] - annotation for pipeline exception handlers;
/// - [ServerExceptionHandler] - annotation for the server exception handler; and
/// - [ServerExceptionHandlerRaw] - annotation for the
///   server raw exception handler.
///
/// # Examples
///
/// ## Request handlers
///
/// ```dart
/// @Handles.get('~/form')
/// Future<Response> myRequestHandler(Request req) async {
///   ...
/// }
///
/// @Handles.post('~/form/submit')
/// Future<Response> myFormRequestHandler(Request req) async {
///   ...
/// }
///
/// @Handles.put('~/api/foo', pipeline: 'api')
/// Future<Response> myApiRequestHandler(Request req) async {
///   ...
/// }
/// ```
///
/// ## Pipeline exception handlers
///
/// A program can have at most one per pipeline.
///
/// ```dart
/// @PipelineExceptionHandler()
/// Future<Response> exceptionHandlerForDefaultPipeline(
///   Request req, Object exception, StackTrace st) async {
///   ...
/// }
///
/// @PipelineExceptionHandler(pipeline: 'api')
/// Future<Response> exceptionHandlerForApiPipeline(
///   Request req, Object exception, StackTrace st) async {
///   ...
/// }
/// ```
///
/// ## Server exception handler and server raw exception handler.
///
/// A program can have at most one of each of these.
///
/// ```dart
/// @ServerExceptionHandler()
/// Future<Response> myServerEH(
///   Request req, Object exception, StackTrace st) async {
///   ...
/// }
///
/// @ServerRawExceptionHandler()
/// Future<void> myServerRawEH(
///   HttpRequest r, String requestId, Object exception, StackTrace st) async {
///   ...
/// }
/// ```
///
/// Note: this library defines classes for creating annotations, but does
/// not use them.

library annotations;

// Import from core the only two definitions this library needs:
//
// - ServerPipeline (for its defaultPipeline constant).
// - RequestHandler (only for deprecated typedef)

import 'core.dart' show ServerPipeline;
import 'core.dart' show RequestHandler; // TODO(any): remove in a future release

// Parts

part 'src/annotations/base.dart';
part 'src/annotations/handles.dart';
part 'src/annotations/pipeline_exception_handler.dart';
part 'src/annotations/request_handler_wrapper.dart';
part 'src/annotations/server_exception_handler.dart';
part 'src/annotations/server_exception_handler_raw.dart';
