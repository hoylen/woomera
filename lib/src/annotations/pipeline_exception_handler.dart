part of annotations;

//################################################################
/// Annotation for a server exception handler function.

class PipelineExceptionHandler extends WoomeraAnnotation {
  /// Constructor for pipeline exception handler annotations.
  ///
  /// The optional [pipeline] name identifies the pipeline the exception handler
  /// is for. If it is not provided, the exception handler is for the default
  /// pipeline.
  ///
  /// Note: page not found exceptions are not processed by the pipeline
  /// exception handlers, but by the server exception handlers. You should
  /// have a `@Handles.exceptions()` annotation before annotating additional
  /// exception handlers with this pipeline exception annotation.

  const PipelineExceptionHandler({String? pipeline})
      : pipeline = pipeline ?? ServerPipeline.defaultName;

  /// Name of the pipeline for the exception handler.

  final String pipeline;
}
