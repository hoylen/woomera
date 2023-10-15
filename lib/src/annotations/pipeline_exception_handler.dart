part of annotations;

//################################################################
/// Annotation for a _pipeline exception handler_ function.

class PipelineExceptionHandler extends WoomeraAnnotation {
  /// Constructor for pipeline exception handler annotations.
  ///
  /// The optional [pipeline] name identifies the pipeline the exception handler
  /// is for. If it is not provided, the exception handler is for the default
  /// pipeline.
  ///
  /// Note: page not found exceptions are not processed by _pipeline
  /// exception handlers_, but by the _server exception handler_. That
  /// exception handler should be annotated with the
  /// [ServerExceptionHandler] class.

  const PipelineExceptionHandler({String? pipeline})
      : pipeline = pipeline ?? ServerPipeline.defaultName;

  /// Name of the pipeline for the exception handler.

  final String pipeline;
}
