part of scan;

//----------------------------------------------------------------
/// Experimental function to dump a server that was created from annotations
///
/// Warning: there is no guarantee this function will be available, or behave
/// the same, in future versions.
///
/// The aim is to allow a program to be developed using annotations, and then
/// using this function to produce code with explicit registrations for use in
/// production. That way, the convenience of annotations can be used during
/// development, but the production code doesn't need to use those annotations
/// This allows the production code to be compiled using _dart compile_, which
/// cannot be used with the mirrors package (which is needed to find the
/// annotations).
///
/// The generated code has a single function called [functionName].
///
/// If [libraryName] has a value, a "part of" statement for it is generated.
///
/// The library names in [importedLibraries] (along with _libraryName_, if it
/// is provided) are suppressed from the function names in the generated code.
///
/// If [timestamp] is false, no created timestamp comment is generated. The
/// default is true.
///
/// If [locations] is false, no "from" comments are generated. The default
/// is true.
///
/// To support the use of non-null safe Dart code, set
/// [includeDartVersionComment] to true, so a "@dart=2.9" version comment
/// is generated. This is needed for code that runs with a version of Dart
/// that is 2.12 or greater, but it has not been updated for null safety.
///
/// By default, a stub for _dumpServer_ is included in the generated code.
/// It is needed because that function is defined when "woomera/woomera.dart" is
/// imported, but is not defined in "woomera/core.dart". To not include the
/// stub, set [includeDumpServerStub] to false.
///
/// **Suggested usage**
///
/// During development, have a separate source file that contains a
/// single function to build a _Server_ by invoking the `serverFromAnnotations`
/// function.
///
/// This will be referred to as the _dynamic code_, since it dynamically
/// sets up the handlers at runtime by scanning the program for annotations.
///
/// For example:
///
/// ```
/// part of foobar;  // pass 'foobar' to `dumpServer` as `libraryName`
///
/// Server serverBuilder(
///    {Iterable<String> pipelines = const <String>[ServerPipeline.defaultName],
///      Iterable<String> libraries = const <String>[],
///      bool scanAllFileLibraries = true,
///      bool ignoreUnusedAnnotations = false}) =>
///   serverFromAnnotations(pipelines:pipelines,
///      libraries: libraries,
///      scanAllFileLibraries: scanAllFileLibraries,
///      ignoreUnusedAnnotations: ignoreUnusedAnnotations);
///
/// // EOF
/// ```
///
/// The programs needs a special mode where it:
///
/// 1. Invokes that function to set up the server dynamically from annotations.
/// 2. Invoke [dumpServer] to generate the static code.
/// 3. Save the static code to a new source file.
/// 4. Exit the program.
///
/// The _static code_ sets up the handlers using explicit method
/// calls instead of using the annotations.
///
/// 1. Invoke the program in that special mode to produce the static code.
///
/// 2. Replace the dynamic code file with the generated static code file
///    (saving the dynamic code file so it can be later restored).
///
/// 3. Change the program's import from `package:woomera/woomera.dart` to
///    `package:woomera/core.dart`.
///
/// The program can then be compiled with _dart comiple_, because it no longer
/// needs the Dart Mirrors package.
///
/// To return to development mode, restore the program to the way it was:
///
/// 1. Change the import from `package:woomera/core.dart` to import
///    `package:woomera/woomera.dart`.
///
/// 2. Restore the original dynamic code file.
///
/// **Example**
///
/// On Unix-like systems, the process could look something like this:
///
/// ```sh
/// # Generate static code and replace the dynamic code with it
///
/// bin/my_program.dart --dump-server > static_code.tmp
/// mv lib/src/server_setup.dart lib/src/server_setup.bak
/// mv static_code.tmp lib/src/server_setup.dart
///
/// # Change import for woomera.dart to core.dart
///
/// mv bin/my_program.dart bin/my_program.bak
/// sed 's/woomera\.dart/core\.dart/' bin/my_program.bak > bin/my_program.dart
///
/// # Run dart2compile
///
/// dart2compile  -o build/bin/my_program  bin/my_program.dart
///
/// # Restore import back to woomera.dart
///
/// mv bin/my_program.bak bin/my_program.dart
///
/// # Restore dynamic code
///
/// mv lib/src/server_setup.bak lib/src/server_setup.dart
/// ```
/// **Known limitations**
///
/// If a _handlerWrapper_ is used to convert the annotated function into a
/// _RequestHandler_ function, the first argument to the _handlerWrapper_ is
/// not preserved. When creating servers/pipelines using annotations, the first
/// argument passed to the _handlerWrapper_ is the annotation itself
/// (i.e. the `Handler` object). So it is not available when the annotations
/// are not being used.

String dumpServer(Server server,
    {String functionName = 'serverBuilder',
    String libraryName = '',
    Iterable<String> importedLibraries = const <String>[],
    bool includeDartVersionComment = false,
    bool timestamp = true,
    bool locations = true,
    bool includeDumpServerStub = true}) {
  final buf = StringBuffer('''
// Generated by the "dumpServer" function from the Woomera Dart package.
// <https://pub.dev/documentation/woomera/latest/scan/dumpServer.html>
//
// WARNING: DO NOT EDIT
''');

  if (timestamp) {
    buf.write('//\n// Generated: ${DateTime.now().toUtc()}\n\n');
  }

  if (includeDartVersionComment) {
    buf.write('// @dart=2.9\n\n');
  }

  if (libraryName.isNotEmpty) {
    buf.write('part of $libraryName;\n\n');
  }

  final libraryPrefixes = <String>[];
  if (libraryName.isNotEmpty) {
    libraryPrefixes.add(libraryName);
  }
  for (var name in importedLibraries) {
    if (name.isNotEmpty) {
      libraryPrefixes.addAll(importedLibraries);
    }
  }

  buf.write('''
/// Creates a [Server] with all the [ServerPipelines] and handlers registered.

Server $functionName(
    {Iterable<String> pipelines = const <String>[ServerPipeline.defaultName],
    Iterable<String> libraries = const <String>[],
    bool scanAllFileLibraries = true,
    bool ignoreUnusedAnnotations = false}) {
''');

  // Wrapper

  String wName;

  final _hw = Handles.handlerWrapper;
  if (_hw != null) {
    wName = _functionName(_hw, libraryPrefixes);
    final wLoc = _functionLocation(_hw);
    buf.write('\n  // Handles.handlerWrapper\n'
        '\n'
        '  const _wrap = $wName;');
    if (locations) {
      buf.write(' // from $wLoc');
    }
    buf.write('\n\n');
  } else {
    wName = ''; // no wrapper function
  }

  buf.write('  // The pipelines with their handlers\n\n');

  final pipelineVariables = <String>[];

  var num = 0;

  for (final p in server.pipelines) {
    final pipelineVariable = 'p${++num}';
    pipelineVariables.add(pipelineVariable);

    // This is the string displayed to represent the default pipeline name
    // value. It is actually the name of the constant itself, from the
    // [ServerPipeline] class, since this is generating code to reference it.

    const _def = 'ServerPipeline.defaultName';

    final nameStr = p.name != ServerPipeline.defaultName ? "'${p.name}'" : _def;

    buf.write('  final $pipelineVariable = ServerPipeline($nameStr)');

    // Pipeline's exception handler

    final _eh = p.exceptionHandler;
    if (_eh != null) {
      final loc = _functionLocation(_eh);
      final fName = _functionName(_eh, libraryPrefixes);

      buf.write('\n    ..exceptionHandler = $fName');
      if (locations) {
        buf.write(' // from $loc');
      }
    }

    // Pipeline's request handlers

    for (final method in p.methods()) {
      for (final rule in p.rules(method)) {
        // Find the annotation that created it (before any handlerWrapper)

        final e = _annotations._found[p.name];
        final entry = e != null
            ? e.singleWhere(
                (a) => a.httpMethod == method && a.pattern == rule.pattern)
            : null;

        // If an entry was found, use the function it was annotating.
        // Otherwise, the handler didn't come from an annotation (i.e. it was
        // explicitly registered), so use the rule's handler function.

        final func = entry?.annotatedFunction ?? rule.handler;

        var fName = _functionName(func, libraryPrefixes); // the function

        if (entry != null && wName.isNotEmpty) {
          // Wrapper exists: wrap the function name

          final handlesArgs = <String>[
            "'${entry.httpMethod}'",
            "'${entry.pattern}'"
          ];

          if (entry.priority != 0) {
            handlesArgs.add('priority: ${entry.priority}');
          }
          if (entry.pipelineName != ServerPipeline.defaultName) {
            handlesArgs.add("pipeline: '${entry.pipelineName}'");
          }

          // Code that wraps the function
          fName =
              '_wrap(const Handles.request(${handlesArgs.join(', ')}), $fName)';
        }

        final convenience = {'GET': 'get', 'POST': 'post'}[method];
        if (convenience != null) {
          buf.write("\n    ..$convenience('${rule.pattern}', $fName)");
        } else {
          buf.write("\n    ..register('$method', '${rule.pattern}', $fName)");
        }
        if (locations) {
          final loc = _functionLocation(func);
          buf.write(' // from $loc');
        }
      }
    }

    buf.write('\n    ;\n\n');
  }

  // Code to create the server and register the request handlers

  buf.write('  // Creating a server with the pipelines\n\n'
      '  return Server(numberOfPipelines: 0)');

  // Server exception handler

  if (server.isCustomExceptionHandler) {
    // Dump code to set the server exception handler

    final loc = _functionLocation(server.exceptionHandler);
    final fName = _functionName(server.exceptionHandler, libraryPrefixes);

    buf.write('\n    ..exceptionHandler = $fName');
    if (locations) {
      buf.write(' // from $loc');
    }
  }

  // Server raw exception handler

  if (server.isCustomRawExceptionHandler) {
    // Dump code to set the raw exception handler

    final loc = _functionLocation(server.exceptionHandlerRaw);
    final fName = _functionName(server.exceptionHandlerRaw, libraryPrefixes);

    buf.write('\n    ..exceptionHandlerRaw = $fName');
    if (locations) {
      buf.write(' // from $loc');
    }
  }

  buf.write(' \n    ..pipelines.addAll([${pipelineVariables.join(', ')}]);\n'
      '}\n');

  // Stub for dump_server

  if (includeDumpServerStub) {
    buf.write('''

/// Dump server stub
///
/// This code is generated by `dumpServer` and should not be invoked.
///
/// This is included in this generated static code because the
/// 'woomera/core.dart' library does not implement the `dumpServer`.
///
/// To use the real `dumpServer`, remove this file and import
/// 'woomera/woomera.dart' instead of 'woomera/core.dart'.

String dumpServer(Server server,
        {String functionName = 'serverBuilder',
        String libraryName = '',
        Iterable<String> importedLibraries = const <String>[],
        bool includeDartVersionComment = false,
        bool timestamp = true,
        bool locations = true,
        bool includeDumpServerStub = true}) =>
    throw StateError('dumpServer in dumpServer generated code cannot be used');

// EOF
''');
  }

  return buf.toString();
}

//----------------

String _functionName(Function f, Iterable<String> libraryPrefixes) {
  final r1 = reflect(f);
  if (r1 is ClosureMirror) {
    var fName = MirrorSystem.getName(r1.function.qualifiedName);
    if (fName.startsWith('.')) {
      fName = fName.substring(1); // remove leading '.'
    }

    for (final prefix in libraryPrefixes) {
      if (fName.startsWith('$prefix.')) {
        fName = fName.substring(prefix.length + 1);
      }
    }

    return fName;
  } else {
    throw StateError('not a function');
  }
}

//----------------

SourceLocation _functionLocation(Function f) {
  final r1 = reflect(f);
  if (r1 is ClosureMirror) {
    final loc = r1.function.location;
    if (loc != null) {
      return loc;
    } else {
      throw StateError('no location');
    }
  } else {
    throw StateError('not a function');
  }
}
