part of core;

//################################################################
/// Modes for processing parameter values.
///
/// Used to determine the behaviour of the [RequestParams.values] and
/// [RequestParamsMutable.remove] methods.
///
/// Typically, [ParamsMode.standard] is used for parameters that do not
/// have multiple lines, and [ParamsMode.rawLines] is used for parameters
/// that can have multiple lines. The [ParamsMode.raw] is used to obtain
/// the values without any changes.
///
/// For example, if the request contained the value of
/// "`\t a  b \t\t c \r\n d \t`":
///
/// - the _standard_ value will be "`a b c d`";
/// - the _rawLines_ value will be "`a  b \t\t c \n d`"; and
/// - the _raw_ value will be "`\t a  b \t\t c \r\n d \t`".
///
/// Be aware that values can contain any Unicode code point. In particular,
/// the _rawLines_ mode can return values containing
/// horizontal tabs (U+0009), non-breaking spaces (U+00A0),
/// zero width no-break space (U+FEFF) and other Unicode whitespaces.
/// The _raw_ mode may also return values containing carriage return (U+000D),
/// vertical tabs (U+000B), line separators (U+2028) and
/// paragraph separators (U+2029).
///
/// Line terminators are defined as the _ECMA script line
/// terminator code points_
/// ([line terminator](https://ecma-international.org/ecma-262/9.0/#table-33))
/// and
/// whitespace defined as the _ECMA script whitespace code points_
/// ([whitespace](https://ecma-international.org/ecma-262/9.0/#table-32)).

enum ParamsMode {
  /// Whitespace and line terminators are sanitized.
  ///
  ///   - line terminators are converted into spaces (U+0020);
  ///   - all other whitespaces are also converted into spaces (U+0020);
  ///   - multiple spaces are collapsed into a single space; and
  ///   - spaces at either end of the string are trimmed away.

  standard,

  /// Line terminators are converted into a line feed.
  ///
  /// This means:
  ///   - line terminators are converted into a line feed (U+000A);
  ///   - whitespace at either end of the string are trimmed away.
  ///
  /// Note: multiple line terminators are converted into the same number
  /// of line feeds. They are not collapsed together (except if they are trimmed
  /// from the ends).

  rawLines,

  /// Values are unchanged.
  ///
  /// This mode is the same as setting the deprecated `raw` parameter  to true.
  ///
  /// Most applications will probably want to use the [rawLines] mode,
  /// unless they really want to preserve the different types of
  /// line terminators and/or keep leading and trailing whitespace.

  raw
}

//################################################################
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

    try {
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
            _add(
                '',
                Uri.decodeQueryComponent(pair.substring(1),
                    encoding: encoding));
          }
        }
      }

      // ignore: avoid_catching_errors
    } on ArgumentError catch (e) {
      if (e.message == 'Illegal percent encoding in URI') {
        throw MalformedPathException();
      } else {
        rethrow;
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
  /// The [mode] determines how the value is processed before comparing it
  /// with the actual value.

  void _remove(String key, String value, ParamsMode mode) {
    final values = _data[key];
    if (values != null) {
      values.removeWhere((e) => _sanitize(e, mode) == _sanitize(value, mode));
    }
  }

  //----------------------------------------------------------------
  /// Retrieves a single fully sanitized value for the key.
  ///
  /// Values are always processed according to the [ParamsMode.standard]
  /// mode. That is, all whitespaces (including line terminators) are converted
  /// into spaces (U+0020); multiple spaces are collapsed into a single space;
  /// and spaces at either ends are trimmed. To use other modes, use the
  /// [values] method.
  ///
  /// The empty string will be returned if:
  ///
  /// - there is no value matching the [key];
  /// - there is a value but it only contains whitespace; or
  /// - there is a value that contains zero characters.
  ///
  /// If there is a need to distinguish between these different values, use
  /// the _values_ method instead.
  ///
  /// This operator must only be used for parameters which are single valued.
  /// If the key matches multiple values: in production mode,
  /// the empty string is returned; in checked mode, an assertion error is
  /// raised. Use the [values] method for keys with multiple values.

  String operator [](String key) {
    final values = _data[key];
    if (values == null) {
      return ''; // no value for key
    } else if (values.length == 1) {
      // Single value
      return _sanitize(values[0], ParamsMode.standard);
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
  /// The values are processed according to the [mode], which defaults to
  /// [ParamsMode.standard]. In the default mode, this method is like
  /// the `[]` operator except it supports zero or more values matching the
  /// same key.
  ///
  /// Unlike the `[]` operator, this method allows different modes to be used.
  /// In particular, the [ParamsMode.rawLines] is useful for input that
  /// can contains multiple lines (e.g. from a _textarea_ element).
  ///
  /// If the deprecated `raw` parameter is set to true, it is the same as using
  /// the [ParamsMode.raw] mode. It is being replaced by the _mode_
  /// parameter which gives greater flexibility to this method.
  /// Do not use both _raw_ and _mode_.

  List<String> values(String key,
      {@deprecated bool raw = false, ParamsMode mode = ParamsMode.standard}) {
    // When the deprecated "raw" parameter is removed, delete the next few lines
    // and just use the "mode".
    assert(
        !raw || raw && mode == ParamsMode.standard, 'do not mix raw with mode');
    final _realMode = raw ? ParamsMode.raw : mode;

    final values = _data[key];

    if (values == null) {
      // Return empty list
      return <String>[];
    } else if (_realMode == ParamsMode.raw) {
      // Don't need to apply _sanitize, since it won't change the values
      return values;
    } else {
      // Apply _sanitize to all the values and return a list
      return List<String>.from(
          values.map<String>((x) => _sanitize(x, _realMode)));
    }
  }

  //================================================================
  // Sanitize section

  // Matches a **single** ECMAScript line terminator code point
  // https://ecma-international.org/ecma-262/9.0/#table-33

  static final _lineTerminatorRegex = RegExp(r'[\u000A\u000D\u2028\u2029]');

  // Matches **one or more** ECMAScript whitespace code points
  // https://ecma-international.org/ecma-262/9.0/#table-32
  // Note: the line terminators are a subset of these code points.

  static final _whitespacesRegex = RegExp(r'\s+');

  /// Processes the [str] according to the [mode]
  ///
  /// See the documentation of [ParamsMode] for details.

  static String _sanitize(String str, ParamsMode mode) {
    String x;

    switch (mode) {
      case ParamsMode.standard:
        x = str
            .replaceAll('\r\n', ' ')
            .replaceAll(_lineTerminatorRegex, ' ')
            .replaceAll(_whitespacesRegex, ' ')
            .trim();
        break;
      case ParamsMode.rawLines:
        x = str
            .replaceAll('\r\n', '\n') // CR-LF pair is treated as one
            .replaceAll(_lineTerminatorRegex, '\n')
            .trim();
        break;
      case ParamsMode.raw:
        x = str;
        break;
    }

    return x;
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

      final allValues = _data[key];
      if (allValues != null) {
        var first = true;
        for (var value in allValues) {
          if (first) {
            first = false;
          } else {
            buf.write(', ');
          }
          buf.write('"$value"');
        }
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
  /// The [mode] determines how values are processed before it is compared
  /// for a match. It defaults to [ParamsMode.standard].
  ///
  /// For example, if values for the _key_ are
  /// `[ "a b", "a b ", "a\nb" ]`,
  /// the _value_ being removed is `"a b"` and the _mode_ is:
  ///
  /// - [ParamsMode.standard], all values are removed;
  /// - [ParamsMode.rawLines], the first and second values are removed;
  /// - [ParamsMode.raw], only the first value is removed.
  ///
  /// If the deprecated `raw` parameter is set to true, it is the same as using
  /// the [ParamsMode.raw] mode. It is being replaced by the _mode_
  /// parameter, which gives greater flexibility to this method.
  /// Do not use both _raw_ and _mode_.

  void remove(String key, String value,
      {@deprecated bool raw = false, ParamsMode mode = ParamsMode.standard}) {
    // When the deprecated "raw" parameter is removed, delete the next few lines
    // and just use the "mode".
    assert(
        !raw || raw && mode == ParamsMode.standard, 'do not mix raw with mode');
    final _realMode = raw ? ParamsMode.raw : mode;

    _remove(key, value, _realMode);
  }

  //----------------------------------------------------------------
  /// Removes all values.

  void clear() => _data.clear();
}
