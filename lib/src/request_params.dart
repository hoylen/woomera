part of woomera;

//----------------------------------------------------------------

/// Represents a collection of parameters.
///
/// Parameters are name-value pairs. But there can be multiple values for the
/// same name. This class provides convenient methods to access the values when
/// the caller expects at-most-one value, as well as methods to access
/// multi-valued parameters. Multi-valued parameters usually occur when
/// processing sets of checkboxes or radio buttons.

class RequestParams {
  //================================================================

  // Stores the parameter keys and values.
  //
  // This implementation does not reuse a generic multi-map class
  // because we want to add the sanitization of values feature,
  // and to avoid having a dependency on a third-party multi-map
  // implementation. If a multi-map implementation is added to the
  // core Dart packages, this can be reconsidered.

  Map<String, List<String>> _data = new Map<String, List<String>>();

  //================================================================

  // Returns true if there are no keys.
  bool get isEmpty => _data.isEmpty;

  // Returns true if there is at least one key.
  bool get isNotEmpty => _data.isNotEmpty;

  // The number of keys.
  int get length => _data.length;

  /// All the keys.
  Iterable<String> get keys => _data.keys;

  //================================================================

  /// Default constructor
  ///
  RequestParams._internalConstructor() {}

  /// Constructor from a query string.
  ///
  /// Constructs parameters from parsing a query string, as specified by
  /// ...
  /// For example, foo=123&bar=test&baz=123
  ///
  /// Note: this implementation allows for repeating keys in the query string
  /// (e.g. foo=123,foo=456) which the Dart Uri.splitQueryString implementation
  /// does not handle.
  ///
  /**
   *
   * [HTML 4.01 specification section 17.13.4]
   * (http://www.w3.org/TR/REC-html40/interact/forms.html#h-17.13.4
   * "HTML 4.01 section 17.13.4"). Each key and value in the returned
   * map has been decoded. If the [query]
   * is the empty string an empty map is returned.
   *
   * Keys in the query string that have no value are mapped to the
   * empty string.
   *
   * Each query component will be decoded using [encoding]. The default encoding
   * is UTF-8.
   */
  RequestParams._fromQueryString(String query, {Encoding encoding: UTF8}) {
    for (var pair in query.split("&")) {
      if (pair.isNotEmpty) {
        int index = pair.indexOf("=");
        if (index == -1) {
          // no "=": use whole string as key and the value is empty string
          var key = Uri.decodeQueryComponent(pair, encoding: encoding);
          this._add(key, ""); // no "=" found, treat value as empty string
        } else if (index != 0) {
          var key = pair.substring(0, index);
          var value = pair.substring(index + 1);
          this._add(Uri.decodeQueryComponent(key, encoding: encoding),
              Uri.decodeQueryComponent(value, encoding: encoding));
        } else {
          // Has "=", but is first character: key is empty string
          this._add("", Uri.decodeQueryComponent(pair, encoding: encoding));
        }
      }
    }
  }

  //----------------------------------------------------------------
  /// Adds a value to the parameters.
  ///
  /// Note: if the value already exists for that key, an additional
  /// copy of it is added.

  void _add(String key, String value) {
    var values = _data[key];
    if (values == null) {
      values = new List<String>();
      _data[key] = values;
    }
    values.add(value);
  }

  //----------------------------------------------------------------
  /// Removes the association for the given [key].
  ///
  void _removeAll(String key) {
    _data.remove(key);
  }

  /*
  //----------------------------------------------------------------
  /// Remove a particular value from a key.

  void remove(String key, String value, {bool raw: false}) {
    var values = _data[key];
    if (values != null) {
      values.removeWhere((raw)
          ? ((e) => e == value)
          : ((e) => _sanitize(e) == _sanitize(value)));
    }
  }
  */

  //----------------------------------------------------------------
  /// Retrieves a single sanitized value for the key.
  ///
  /// Values are sanitized by trimming whitespace from both ends
  /// of the string. The empty string is returned if there is no value
  /// matching the [key] or there is a value but it only contains
  /// nothing except whitespace (includes the case when it is the empty string).
  ///
  /// This operator must only be used for parameters which are single valued.
  /// If the key matches multiple values: in production mode,
  /// the empty string is returned; in checked mode, an assertion error is
  /// raised. Use the [values] method for keys with multiple values.
  ///
  /// This operator never returns null.
  ///
  /// It is not possible to distinguish between a value that does not
  /// exist and a value that is a blank or empty string. If that distinction
  /// is important, use the [values] method instead. The [values] method
  /// should be used if the raw values (i.e. without whitespace trimming)
  /// are required.

  String operator [](String key) {
    var values = _data[key];
    if (values == null) {
      return ""; // no value for key
    } else if (values.length == 1) {
      return _sanitize(values[0]); // returns sanitized single value
    } else {
      assert(values.length == 1); // do not use this operator with multiples
      return ""; // error value
    }
  }

  //----------------------------------------------------------------
  /// Retrieves the values for a key, possibly multiple values.
  ///
  /// Returns a list of values for the key. If there are no values
  /// an empty list is returned.
  ///
  /// By default, all values (if any) are trimmed of whitespace from both ends.
  /// If [raw] is true, the values are not trimmed.

  List<String> values(String key, {bool raw: false}) {
    assert(key != null);

    var values = _data[key];

    if (values == null) {
      // Return empty list
      return new List<String>();
    } else if (raw) {
      // Return list of raw values
      return values;
    } else {
      // Return list of trimmed values
      return new List.from(values.map((e) => _sanitize(e)));
    }
  }

  //================================================================
  // Sanitize section

  static final _WHITESPACES_REGEX = new RegExp(r"\s+");

  static String _sanitize(String str) {
    assert(str != null);

    str = str.trim();
    str = str.replaceAll(_WHITESPACES_REGEX, " ");
    return str;
  }

  //================================================================

  String toString() {
    var str = "";

    for (var key in _data.keys) {
      if (str.isNotEmpty) {
        str += ",  ";
      }
      str += "$key=[";

      var first = true;
      for (var value in _data[key]) {
        if (first) {
          first = false;
        } else {
          str += ", ";
        }
        str += "\"${value}\"";
      }
      str += "]";
    }

    return str;
  }
}
