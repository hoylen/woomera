part of scan;

//----------------------------------------------------------------
/// Creates a Server and populates pipelines with rules from annotations.
///
/// By default (if no _pipelines_ are specified), it creates a server with
/// a single default pipeline. And that pipeline is automatically populated
/// with rules based from [Handles] annotations that are found on request
/// handler functions.
///
/// If a list of pipeline names is provided in [pipelines], those pipelines
/// are created and automatically populated with rules. Those [Handles]
/// annotations must specify the name of the pipeline they are for.
/// Note: when a list of pipeline names is provided, the default pipeline is
/// not created unless the [ServerPipeline.defaultName] explicitly appears as
/// one of the names in the list.
///
/// **Important:** the list of [libraries] must be correct, otherwise it
/// may not find all the annotations. Please see the documentation on
/// [serverPipelineFromAnnotations] for details about the _libraries_ and
/// _scanAllFileLibraries_ parameters.
///
/// Throws a [LibraryNotFound] if one or more of the explicitly identified
/// libraries does not exist.
///
/// Throws an [ArgumentError] if there are _Handles_ annotations that have
/// not been used (i.e. their pipeline names don't appear in _pipelines_)
/// and [ignoreUnusedAnnotations] is false (which is the default). This
/// usually indicates a error in the code, since the function the annotation
/// is on will probably never get invoked. Remove the offending annotation(s),
/// or set _ignoreUnusedAnnotations_ to true.

Server serverFromAnnotations(
    {Iterable<String>? pipelines,
    Iterable<String>? libraries,
    bool scanAllFileLibraries = true,
    bool ignoreUnusedAnnotations = false}) {
  final server = Server();

  // Make sure annotations from the desired libraries have been scanned
  // This step is important, since the pipelines could be an empty list and
  // the libraries do need to be scanned before attempting to retrieve a
  // server exception handler.

  try {
    _annotations.scan(libraries ?? [],
        scanAllFileLibraries: scanAllFileLibraries);
  } on LibraryNotFound catch (e) {
    // Throw this exception from here, to avoid confusing programmers with a
    // stack trace that includes internal details that are irrelevant to
    // debugging their code.
    //
    // This exception means one or more of the values in [libraries] does
    // not exist in the program. Solution: remove or fix the offending value.
    //
    // Don't know what library values to use? Set the logging level for
    // "woomera.handles" to FINEST to log the URIs for the libraries that
    // are scanned or skipped.

    // ignore: use_rethrow_when_possible
    throw e;
  }

  // Remove the initial pipeline that the Server constructor creates

  server.pipelines.removeAt(0);
  assert(server.pipelines.isEmpty);

  // Create all the requested pipelines

  for (final name in pipelines ?? [ServerPipeline.defaultName]) {
    // Note: this won't need to scan the libraries, because they have already
    // been scanned above.
    final newPipeline = serverPipelineFromAnnotations(name, libraries,
        scanAllFileLibraries: scanAllFileLibraries);

    server.pipelines.add(newPipeline);
  }

  // Set the server exception handler from annotations

  final seh = _annotations.findServerExceptionHandler();
  if (seh != null) {
    server.exceptionHandler = seh.handler;
  }

  // Set the server raw exception handler from annotations

  final sreh = _annotations.findServerRawExceptionHandler();
  if (sreh != null) {
    server.exceptionHandlerRaw = sreh.handler;
  }

  // Check if all the _Handles_ annotations have been used.
  //
  // If they haven't, throw an exception. That is less confusing than having
  // the program run, but some things mysteriously not working as expected.

  if (!ignoreUnusedAnnotations) {
    final notUsed = _annotations.checkForUnusedAnnotations();
    if (notUsed.isNotEmpty) {
      // Solution: fix the program by removing the unused annotations.
      //
      // If the program deliberately has unused annotations, invoke this
      // constructor with [ignoreUnusedAnnotations]=true to skip this check.

      final noun = notUsed.length == 1 ? 'annotation' : 'annotations';

      throw ArgumentError('Handles $noun not used by the pipelines:\n'
          '  ${notUsed.join('\n  ')}\n'
          '  [${notUsed.length} unused $noun]');
    }
  }

  return server;
}
