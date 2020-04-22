/// Annotations scanning library.
///
/// This library contains the annotations scanning functions, which allows
/// the `Server` and `ServerPipeline` from the core library to automatically
/// populated by scanning the application for `Handles` annotations.
/// To use the scanning functions, import `woomera.dart` which includes both
/// the core library and this scanning library. This scanning library requires
/// the Dart Mirrors package.
///
/// ## Usage
///
/// See the _core_ library for details on how to use Woomera.
///
/// This library defines two functions to create _Server_ and _ServerPipelines_
/// from annotations in the code: [serverFromAnnotations] and
/// [serverPipelineFromAnnotations]. It also defines extra exceptions that can
/// arise during the scanning operation.
///
/// ## Logging
///
/// The [Logger](https://pub.dartlang.org/packages/logging) package is used for
/// logging. The available logger from this library is named:
///
/// - woomera.handles - logs rules created via Handles annotations

library scan;

import 'dart:mirrors';

import 'package:logging/logging.dart';

import 'core.dart';

part 'src/scan/annotations_scanner.dart';
part 'src/scan/dump_server.dart';
part 'src/scan/scan_exceptions.dart';
part 'src/scan/scan_server.dart';
part 'src/scan/scan_server_pipeline.dart';

//----------------------------------------------------------------
// Logger used in the Woomera scanning package

Logger _logHandles = Logger('woomera.handles');
