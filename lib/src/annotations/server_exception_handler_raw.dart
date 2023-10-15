part of annotations;

//################################################################
/// Annotation for a _server raw exception handler_ function.
///
/// A program does not have more than one _server raw exception handler_.
/// Therefore, a program must not have more than one annotation using
/// this class.

class ServerExceptionHandlerRaw extends WoomeraAnnotation {
  /// Constructor for a _server raw exception handler_ annotation.

  const ServerExceptionHandlerRaw();
}
