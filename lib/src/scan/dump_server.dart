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
/// (so it loads faster and can be compiled using _dart2native_).
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
///
/// **Suggested usage**
///
/// During development, have a separate development source file that contains a
/// single function to build a _Server_ from annotations by invoking the
/// `serverFromAnnotations` function. For example:
///
/// ```
/// Server serverBuilder(
///    {Iterable<String> pipelines,
///      Iterable<String> libraries,
///      bool scanAllFileLibraries = true,
///      bool ignoreUnusedAnnotations = false}) =>
///   serverFromAnnotations(pipelines:pipelines,
///      libraries: libraries,
///      scanAllFileLibraries: scanAllFileLibraries,
///      ignoreUnusedAnnotations: ignoreUnusedAnnotations);
/// ```
///
/// When it is ready for production release, after invoking that function
/// run [dumpServer] and save the output to a generated source file. Then:
///
/// 1. Replace the development source file with the generated source file
///    (saving a copy of the development source file for later use).
/// 2. Change the `import 'package:woomera/woomera.dart'` in the program to
///    `import 'package:woomera/core.dart'`.
///
/// The program can then be compiled with _dart2native_, because it no longer
/// needs the Dart Mirrors package.
///
/// To continue further development using the convenient annotations,
/// put back the original development source file.
///
/// **Known limitations**
///
/// If a _handlerWrapper_ is used to convert the annotated function into a
/// _RequestHandler_ function, the first argument to the _handlerWrapper_ is
/// not preserved. When creating servers/pipelines using annotations, the first
/// argument passed to the _handlerWrapper_ is the annotation itself
/// (i.e. the `Handler` object).

String dumpServer(Server server,
    {String functionName = 'serverBuilder',
    String libraryName,
    Iterable<String> importedLibraries,
    bool timestamp = true,
    bool locations = true}) {
  final buf = StringBuffer();

  if (timestamp) {
    buf.write('// Generated: ${DateTime.now().toUtc()}\n\n');
  }

  if (libraryName != null) {
    buf.write('part of $libraryName;\n\n');
  }

  final libraryPrefixes = [libraryName];
  if (importedLibraries != null) {
    libraryPrefixes.addAll(importedLibraries);
  }

  buf.write('''
Server $functionName({Iterable<String> pipelines,
      Iterable<String> libraries,
      bool scanAllFileLibraries,
      bool ignoreUnusedAnnotations}) {
''');

  // Wrapper

  String wName;
  if (Handles.handlerWrapper != null) {
    wName = _functionName(Handles.handlerWrapper, libraryPrefixes);
    final wLoc = _functionLocation(Handles.handlerWrapper);
    buf.write('  // Handles.handlerWrapper\n'
        '  // Warning: annotations are not preserved for the wrapper.\n'
        '  //          The first argument to the handlerWrapper is null\n'
        '  //          in the code below.\n'
        '\n'
        '  const _wrap = $wName;');
    if (locations) {
      buf.write(' // from $wLoc');
    }
    buf.write('\n\n');
  }

  final pipelineVariables = <String>[];

  var num = 0;

  for (final p in server.pipelines) {
    final pipelineVariable = 'p${++num}';
    pipelineVariables.add(pipelineVariable);

    final nameStr = p.name != null
        ? p.name == ServerPipeline.defaultName
            ? 'ServerPipeline.defaultName'
            : "'${p.name}'"
        : '';
    buf.write('  final $pipelineVariable = ServerPipeline($nameStr)');

    // Pipeline's exception handler

    if (p.exceptionHandler != null) {
      final loc = _functionLocation(p.exceptionHandler);
      final fName = _functionName(p.exceptionHandler, libraryPrefixes);

      buf.write('\n    ..exceptionHandler = $fName');
      if (locations) {
        buf.write(' // from $loc');
      }
    }

    // Pipeline's request handlers

    for (final method in p.methods()) {
      for (final rule in p.rules(method)) {
        // Find the annotation that created it (before any handlerWrapper)

        final entry = _annotations._found.containsKey(p.name)
            ? _annotations._found[p.name].singleWhere(
                (a) => a.httpMethod == method && a.pattern == rule.pattern)
            : null;

        // If an entry was found, use the function it was annotating.
        // Otherwise, the handler didn't come from an annotation (i.e. it was
        // explicitly registered), so use the rule's handler function.

        final func = entry?.annotatedFunction ?? rule.handler;

        var fName = _functionName(func, libraryPrefixes);

        if (entry != null && wName != null) {
          fName = '_wrap(null, $fName)'; // wrap the function
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

  buf.write('  return Server(numberOfPipelines: 0)');

  // Server exception handler

  if (server.exceptionHandler != null) {
    final loc = _functionLocation(server.exceptionHandler);
    final fName = _functionName(server.exceptionHandler, libraryPrefixes);

    buf.write('\n    ..exceptionHandler = $fName');
    if (locations) {
      buf.write(' // from $loc');
    }
  }

  // Server raw exception handler

  if (server.exceptionHandlerRaw != null) {
    final loc = _functionLocation(server.exceptionHandlerRaw);
    final fName = _functionName(server.exceptionHandlerRaw, libraryPrefixes);

    buf.write('\n    ..exceptionHandlerRaw = $fName');
    if (locations) {
      buf.write(' // from $loc');
    }
  }

  buf.write(' \n    ..pipelines.addAll([${pipelineVariables.join(', ')}]);\n'
      '}\n');

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
    return r1.function.location;
  } else {
    throw StateError('not a function');
  }
}
