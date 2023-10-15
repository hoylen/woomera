/// Annotations

library annotations;

// Import from core the only two definitions this library needs:
//
// - RequestHandler; and
// - ServerPipeline (for its defaultPipeline constant).

import 'core.dart' show RequestHandler, ServerPipeline;

part 'src/annotations/base.dart';
part 'src/annotations/handles.dart';
part 'src/annotations/pipeline_exception_handler.dart';
part 'src/annotations/request_handler_wrapper.dart';
part 'src/annotations/server_exception_handler.dart';
part 'src/annotations/server_raw_exception_handler.dart';
