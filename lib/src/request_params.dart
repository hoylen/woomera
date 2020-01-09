part of woomera;

//----------------------------------------------------------------

/// Represents a collection of parameters.
///
/// Parameters are name-value pairs. But there can be multiple values for the
/// same name. This class provides convenient methods to access the values when
/// the caller expects at-most-one value, as well as methods to access
/// multi-valued parameters. Multi-valued parameters usually occur when
/// processing sets of checkboxes or radio buttons.
///
/// The [RequestParams] is intended to be immutable, since it is normally
/// created by the framework when it receives a HTTP request to process, and
/// passes it to the application's request handlers (which should have no reason
/// to modify them).
///
/// There is one situation where an application might want to modify
/// _RequestParams_, and that is during testing: when the test program wants
/// to build up and modify parameters to simulate different requests. For that
/// purpose, test programs should use instances of the [RequestParamsMutable]
/// class.

class RequestParams {
  //================================================================
  // Constructors

  //----------------------------------------------------------------
  /// Default constructor (for internal use only)
  ///
  RequestParams._internalConstructor();

  //----------------------------------------------------------------

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
  /// [HTML 4.01 specification section 17.13.4]
  /// (http://www.w3.org/TR/REC-html40/interact/forms.html#h-17.13.4
  /// "HTML 4.01 section 17.13.4"). Each key and value in the returned
  /// map has been decoded. If the [queryStr]
  /// is the empty string an empty map is returned.
  ///
  /// Keys in the query string with no value are mapped to the empty string.
  ///
  /// Each query component will be decoded using [encoding]. The default encoding
  /// is UTF-8.
  ///
  RequestParams._fromQueryString(String queryStr, {Encoding encoding = utf8}) {
    _populateFromQueryString(queryStr, encoding: encoding);
  }

  //----------------------------------------------------------------
  /// Populate parameters from a query string.
  ///
  /// Parses [queryStr] for parameters and adds them to the request parameters.
  /// Any existing parameters are retained.

  void _populateFromQueryString(String queryStr, {Encoding encoding = utf8}) {
    assert(!queryStr.contains('?'));

    for (var pair in queryStr.split('&')) {
      if (pair.isNotEmpty) {
        final index = pair.indexOf('=');
        if (index == -1) {
          // no "=": use whole string as key and the value is empty string
          final key = Uri.decodeQueryComponent(pair, encoding: encoding);
          _add(key, ''); // no "=" found, treat value as empty string
        } else if (index != 0) {
          final key = pair.substring(0, index);
          final value = pair.substring(index + 1);
          _add(Uri.decodeQueryComponent(key, encoding: encoding),
              Uri.decodeQueryComponent(value, encoding: encoding));
        } else {
          // Has "=", but is first character: key is empty string
          _add('',
              Uri.decodeQueryComponent(pair.substring(1), encoding: encoding));
        }
      }
    }
  }

  //================================================================

  // Stores the parameter keys and values.
  //
  // This implementation does not reuse a generic multi-map class
  // because we want to add the sanitization of values feature,
  // and to avoid having a dependency on a third-party multi-map
  // implementation. If a multi-map implementation is added to the
  // standard Dart packages, this can be reconsidered.

  final Map<String, List<String>> _data = {};

  //================================================================
  // Getters and setters

  /// Returns true if there are no keys.
  bool get isEmpty => _data.isEmpty;

  /// Returns true if there is at least one key.
  bool get isNotEmpty => _data.isNotEmpty;

  /// The number of keys.
  int get length => _data.length;

  /// All the keys.
  Iterable<String> get keys => _data.keys;

  //================================================================

  //----------------------------------------------------------------
  /// Adds a value to the parameters.
  ///
  /// Note: if the value already exists for that key, an additional
  /// copy of it is added.

  void _add(String key, String value) {
    var values = _data[key];
    if (values == null) {
      values = [];
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

  //----------------------------------------------------------------
  /// Remove a particular value associated with a key.
  ///
  /// For the [key] all values that match [value] are removed.
  ///
  /// If [raw] is true, the [value] must match exactly for it to be removed.
  /// Otherwise (the default), the value is removed if its sanitized value
  /// is the same as the sanitized [value]: where all leading and trailing
  /// whitespace are removed and multiple whitespaces are treated as a single
  /// space.

  void _remove(String key, String value, {bool raw = false}) {
    final values = _data[key];
    if (values != null) {
      values.removeWhere((raw)
          ? ((e) => e == value)
          : ((e) => _sanitize(e) == _sanitize(value)));
    }
  }

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
    final values = _data[key];
    if (values == null) {
      return ''; // no value for key
    } else if (values.length == 1) {
      return _sanitize(values[0] ?? ''); // returns sanitized single value
    } else {
      assert(values.length == 1, 'multi-valued: do not use [] with "$key"');
      return ''; // error value
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

  List<String> values(String key, {bool raw = false}) {
    assert(key != null);

    final values = _data[key];

    if (values == null) {
      // Return empty list
      return <String>[];
    } else if (raw) {
      // Return list of raw values
      return values;
    } else {
      // Return list of trimmed values
      final x = values.map(_sanitize);
      return List<String>.from(x);
    }
  }

  //================================================================
  // Sanitize section

  static final _whitespacesRegex = RegExp(r'\s+');

  static String _sanitize(String str) {
    assert(str != null);

    final s = str.trim();
    return s.replaceAll(_whitespacesRegex, ' ');
  }

  //================================================================

  @override
  String toString() {
    final buf = StringBuffer();

    for (var key in _data.keys) {
      if (buf.isNotEmpty) {
        buf.write(', ');
      }
      buf.write('$key=[');

      var first = true;
      for (var value in _data[key]) {
        if (first) {
          first = false;
        } else {
          buf.write(', ');
        }
        buf.write('"$value"');
      }
      buf.write(']');
    }

    return buf.toString();
  }
}

//================================================================
/// A mutable [RequestParams].
///
/// This class is not normally used.
///
/// It is only needed for testing, when a test program wants to build up and/or
/// modify a set of parameters which are then used to simulate different
/// HTTP requests.

class RequestParamsMutable extends RequestParams {
  /// Constructor
  ///
  /// Creates a new mutable [RequestParams] that is initially empty.

  RequestParamsMutable() : super._internalConstructor();

  //----------------------------------------------------------------
  /// Parse the query parameters from a URI.
  ///
  /// All the other parts of the URI are ignored.

  RequestParamsMutable.fromUrl(String uri) : super._internalConstructor() {
    final q = uri.indexOf('?');
    final queryString = (0 <= q) ? uri.substring(q + 1) : uri;

    _populateFromQueryString(queryString);
  }

  //----------------------------------------------------------------
  /// Adds a key:value to the parameters.
  ///
  /// Note: if the value already exists for that key, an additional
  /// copy of it is added.

  void add(String key, String value) => _add(key, value);

  //----------------------------------------------------------------
  /// Removes all the values associated with a particular key.

  void removeAll(String key) => _removeAll(key);

  //----------------------------------------------------------------
  /// Remove a particular value associated with a key.
  ///
  /// For the [key] all values that match [value] are removed.
  ///
  /// If [raw] is true, the [value] must match exactly for it to be removed.
  /// Otherwise (the default), the value is removed if its sanitized value
  /// is the same as the sanitized [value]: where all leading and trailing
  /// whitespace are removed and multiple whitespaces are treated as a single
  /// space.

  void remove(String key, String value, {bool raw = false}) =>
      _remove(key, value, raw: raw);

  //----------------------------------------------------------------
  /// Removes all values.

  void clear() => _data.clear();
}
