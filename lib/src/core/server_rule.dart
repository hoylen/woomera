part of core;

//################################################################
/// Represents a rule for processing HTTP requests.
///
/// A rule consists of a pattern and a handler. If the pattern
/// matches the path of the HTTP request, then the handler is invoked to process
/// the request.
///
/// Rules are registered with instances of a [ServerPipeline] (for a particular
/// HTTP method). Rules can be explicitly created and added to a pipeline using
/// the [ServerPipeline.register] method. Or they can be identified
/// by annotating request handlers (functions or static methods) with
/// _Handles_ objects and then processed using a program that uses the
/// [woomera_server_gen](https://github.com/hoylen/woomera_server_gen) package.

class ServerRule {
  //================================================================
  // Constructors

  //----------------------------------------------------------------
  /// Constructor.
  ///
  /// The [pathPattern] is the string representation of a [Pattern] and it
  /// determines if a HTTP request matches this rule or not.

  ServerRule(String pathPattern, this.handler) : pattern = Pattern(pathPattern);

  //================================================================
  // Members

  /// Pattern that the HTTP request's path must match for the rule to be used.

  final Pattern pattern;

  /// The request handler callback method.

  final RequestHandler handler;

  //================================================================
  // Methods

  //----------------------------------------------------------------

  @override
  bool operator ==(Object other) {
    if (other is ServerRule) {
      return handler == other.handler && pattern == other.pattern;
    }
    return false;
  }

  //----------------------------------------------------------------

  @override
  int get hashCode => handler.hashCode;

  //----------------------------------------------------------------

  @override
  String toString() => pattern.toString();
}
