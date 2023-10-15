/// **DEPRECATED**
///
/// **This library is now deprecated. It will be removed in a future release.**
///
/// The problem with dynamically creating pipelines and servers from
/// annotations is it relies on the `dart:mirror` package. Using that
/// package prevents a program from being compiled into a native binary.
///
/// This library also contains the experimental `dumpServer` function that
/// takes a _Server_ and generates Dart code to create the same _Server_
/// without using annotations. Unfortunately,
/// a complicated build process is required to properly use it.
///
/// Therefore, this library has now been deprecated.
///
/// It is being replaced by a separate
/// [woomera_server_gen](https://pub.dev/packages/woomera_server_gen)
/// package.
///
/// If there is value in retaining this _scan_ library, please submit
/// an [issue](https://github.com/hoylen/woomera_server_gen/issues)
/// and we'll consider moving it to its own package instead of entirely
/// deleting it.
///
/// ## Description
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

@Deprecated('Create a program using woomera_server_gen Dart package instead.')
library scan;

import 'dart:mirrors';

import 'package:logging/logging.dart';

import 'annotations.dart';
import 'core.dart';

part 'src/scan/annotations_scanner.dart';
part 'src/scan/dump_server.dart';
part 'src/scan/scan_exceptions.dart';
part 'src/scan/scan_server.dart';
part 'src/scan/scan_server_pipeline.dart';

//----------------------------------------------------------------
// Logger used in the Woomera scanning package

Logger _logHandles = Logger('woomera.handles');
