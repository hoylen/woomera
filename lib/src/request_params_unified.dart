part of woomera;

//================================================================
/// Provides a unified set of parameters for a context.
///
/// Provides a single way to look up parameters from a context, regardless
/// of whether the parameter comes from the matched path, query parameters
/// or POST parameters.

class RequestParamsUnified {
  static const int pathParameters = 1;
  static const int queryParameters = 2;
  static const int postParameters = 4;

  static const int anyParameters =
      pathParameters | queryParameters | postParameters;

  Request _req;

  //----------------------------------------------------------------
  /// Constructor

  RequestParamsUnified._internalConstructor(this._req);

  //----------------------------------------------------------------

  /// Retrieve a single sanitized parameter.
  ///
  /// This operator never returns null. If the parameter does not exist, the
  /// empty string is returned. If multiple values exist, the empty string
  /// is returned.

  String operator [](String key) {
    var list = values(key);
    if (list.isEmpty) {
      return "";
    } else if (list.length == 1) {
      assert(list[0] != null);
      return list[0];
    } else {
      assert(false);
      return "";
    }
  }

  //----------------------------------------------------------------
  /// Retrieve a parameter.
  ///
  /// If [raw] is true, null is returned if the parameter is not set. If the
  /// value is set, the unsanitized value is returned. That is, any leading
  /// or trailing whitespace is included in the return value and single or
  /// multiple whitespace characters are not modified.
  ///
  /// If [raw] is false, null is never returned. If the parameter is not set,
  /// the empty string is returned. If the value is set, any leading and
  /// trailing whitespace are trimmed from the value. Single or multiple
  /// whitespaces are replaced by a single space.
  ///
  /// The [source] determines which the parameter can come from. It should be
  /// set to either [pathParameters], [queryParameters],
  /// [postParameters], or a bitwise OR combination of one or more of those
  /// values. The default is to examine them all.
  ///
  /// The sources are examined in order. If the path parameters is a source and
  /// the parameter exists in it, the other sources are not examined. If the
  /// query parameters is a source and the parameter exists in it, the POST
  /// parameters are not examined.
  ///
  List<String> values(String key,
      {bool raw: false, int source: anyParameters}) {
    List<String> x = new List<String>();

    if ((source & pathParameters) != 0 && _req.pathParams != null) {
      x.addAll(_req.pathParams.values(key, raw: raw));
    }
    if ((source & postParameters) != 0 && _req.postParams != null) {
      x.addAll(_req.postParams.values(key, raw: raw));
    }
    if ((source & queryParameters) != 0 && _req.queryParams != null) {
      x.addAll(_req.queryParams.values(key, raw: raw));
    }

    return x;
  }

  //----------------------------------------------------------------
  /// Returns the keys for parameters which have been set.
  ///
  Set<String> keys({int source: anyParameters}) {
    var result = new Set<String>();

    if ((source & pathParameters) != 0 && _req.pathParams != null) {
      result.addAll(_req.pathParams.keys);
    }
    if ((source & postParameters) != 0 && _req.postParams != null) {
      result.addAll(_req.postParams.keys);
    }
    if ((source & queryParameters) != 0 && _req.queryParams != null) {
      result.addAll(_req.queryParams.keys);
    }

    return result;
  }
}
