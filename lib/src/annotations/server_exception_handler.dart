part of annotations;

//################################################################
/// Annotation for a _server exception handler_ function.
///
/// A program does not have more than one _server exception handler_.
/// Therefore, a program must not have more than one annotation using
/// this class.

class ServerExceptionHandler extends WoomeraAnnotation {
  /// Constructor for a _server exception handler_ annotation.

  const ServerExceptionHandler();
}
