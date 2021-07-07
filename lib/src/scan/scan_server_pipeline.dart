part of scan;

//----------------------------------------------------------------
/// Creates pipeline and populates it with rules from annotations.
///
/// Create a pipeline and automatically populates it with rules based from
/// [Handles] annotations that are found on request handler functions.
/// The _Handles_ annotations must have the same [pipelineName] for it to
/// be used.
///
/// **Important:** provide the correct values in _libraries_, otherwise the
/// annotations might not be found.
///
/// When scanning the program for annotations, it only looks in libraries
/// explicitly listed in [libraries]. Unless [scanAllFileLibraries] is true
/// (which is the default), in which case all libraries with a "file" scheme
/// are scanned, even if they don't appear in the list of _libraries_.
///
/// Every part of a Dart problem belongs to a library which is identified by
/// a URI. Libraries with a URI scheme of "dart" are never scanned (even
/// if they are listed in _libraries_). For example, "dart:io" is a library
/// that is never scanned. Libraries with a URI scheme of "package" are
/// also common, and the libraries that you want scanned must be listed.
/// If you find an annotated request handler is not getting invoked, check
/// if its library has been included in the list.
///
/// Libraries must be listed for them to be scanned. Firstly, because it is
/// inefficient to scan all the libraries of the program: third party packages
/// won't have any _Handles_ annotations. Secondly, for security, since you
/// don't want a third-party package from adding request handlers that you
/// don't know about.

ServerPipeline serverPipelineFromAnnotations(
    String pipelineName, Iterable<String>? libraries,
    {bool scanAllFileLibraries = true}) {
  ArgumentError.checkNotNull(pipelineName, 'no pipeline name'); // use default
  final pipeline = ServerPipeline(pipelineName);

  // Make sure annotations from the desired libraries have been scanned

  _annotations.scan(libraries ?? [],
      scanAllFileLibraries: scanAllFileLibraries);

  // Set the request handlers from annotations

  var haveRequestHandlers = false;
  for (final arh in _annotations.listRequestHandlers(pipeline.name)) {
    try {
      pipeline.registerPattern(arh.httpMethod, arh.pattern, arh.handler);
    } on DuplicateRule catch (e) {
      // Since Mirrors is available, use the enhanced exception that can
      // show where the existing handler came from
      throw DuplicateRuleWithExistingHandler(
          e.method, e.pattern, e.newHandler, e.existingHandler);
    }
    haveRequestHandlers = true;
  }

  if (!haveRequestHandlers) {
    // Usually a programming error, since there is no point in creating a
    // pipeline with no request handlers. Check the name is correct.

    throw ArgumentError.value(pipelineName, 'pipelineName',
        'no Handles annotations on request handlers exist for this pipeline');
  }

  // Set the pipeline exception handler from annotations

  final apeh = _annotations.findPipelineExceptionHandler(pipeline.name);
  if (apeh != null) {
    pipeline.exceptionHandler = apeh.handler;
  }

  // Record that annotations with the name have been used to create a pipeline

  _annotations.markAsUsed(pipeline.name);

  return pipeline;
}
