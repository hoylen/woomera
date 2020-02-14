part of woomera;

//################################################################
/// Pattern that is used to match a path.
///
/// A pattern is used in a [ServerRule] to determine which HTTP requests the
/// rule will process. If the path of the HTTP request matches the pattern, the
/// rule will apply. Otherwise, the rule won't apply.
///
/// The string representation of a pattern always starts with a tilde ("~") to
/// indicate it is a pattern.
///
/// Like a path, a pattern consists of a sequence of segments separated by a
/// slash ("/") character. But there are four types of segments in a pattern:
///
/// - literal segments
/// - variable segments (value starts with a colon ":")
/// - optional segments (value ends with a question mark "?")
/// - wildcard segments (entire value is a single asterisk "*")
///
/// A pattern can have at most one wildcard segment. The behaviour is undefined
/// if there are two or more wildcard segments.
///
/// See the [match] method for how the different types of segments match a path.

class Pattern {
  //================================================================
  // Constructors

  /// Constructor from a string representation of a path pattern.

  Pattern(String pattern) : _segments = pattern.split(_pathSeparator) {
    if (_segments.length == 1 && _segments.first.isEmpty) {
      throw ArgumentError.value(pattern, 'pattern', 'empty string');
    }
    if (_segments.first != _prefix) {
      throw ArgumentError.value(
          pattern, 'pattern', 'does not start with "$_prefix/"');
    }

    _segments.removeAt(0); // remove the leading "~".

    while (_segments.isNotEmpty && _segments[0].isEmpty) {
      _segments.removeAt(0); // remove leading slashes "/", "//", "/////"
    }
  }

  //================================================================
  // Constants

  static const String _prefix = '~';

  static const String _pathSeparator = '/';

  static const String _variablePrefix = ':';

  static const String _optionalSuffix = '?';

  /// Segment name for the wildcard segment.
  ///
  /// This value is always the asterisk character.
  ///
  /// Pattern strings would be hard to read if this constant was used in them
  /// (e.g. "~/foo/${Pattern.wildcard}"), but it could be used as the name
  /// of the returned parameter.
  ///
  /// ```dart
  ///     final pattern = Pattern('~/foo/*');
  ///     ...
  ///     params = pattern.match(pathComponents);
  ///     if (params != null) {
  ///       final m = params[Pattern.wildcard]; // instead of params['*']
  ///       ...
  ///     }
  /// ```

  static const String wildcard = '*';

  //================================================================
  // Members

  /// Stores the segments that make up the pattern.
  ///
  /// The leading prefix is not included. For example, the pattern "~/foo/bar"
  /// is represented by [ "foo", "bar" ]. An empty list represents the pattern
  /// "~/".
  ///
  /// Empty segments (i.e. zero-length strings) are allowed and are significant.
  /// For example, the pattern "~/foo/bar" is represented by [ "foo", "bar" ],
  /// which is different from the pattern "~/foo/bar/" which is represented by
  /// [ "foo", "bar", "" ].

  final List<String> _segments;

  //================================================================
  // Methods used by [match] to identify the different pattern components

  static bool _isVariable(String s) => s.startsWith(_variablePrefix);

  static String _variableName(String str) {
    assert(_isVariable(str));
    return str.substring(_variablePrefix.length);
  }

  static bool _isOptional(String s) => s.endsWith(_optionalSuffix);

  static String _optionalName(String str) {
    assert(_isOptional(str));
    return str.substring(0, str.length - _optionalSuffix.length);
  }

  //================================================================
  // Methods

  //----------------------------------------------------------------

  @override
  bool operator ==(Object other) {
    if (other is Pattern) {
      if (_segments.length == other._segments.length) {
        for (var x = 0; x < _segments.length; x++) {
          if (_segments[x] != other._segments[x]) {
            return false;
          }
        }
        return true;
      }
    }
    return false;
  }

  //----------------------------------------------------------------

  @override
  int get hashCode => _segments.hashCode;

  //----------------------------------------------------------------
  /// Comparing two patterns.
  ///
  /// This is used for sorting [Handles] annotations, to define the order
  /// of the rules that are automatically registered with a pipeline (if the
  /// priority of the registrations are the same).
  ///
  /// For ordering, literals have priority over optionals, optionals over
  /// variables, and variables over wildcards. If there are multiple patterns
  /// that could match the same path, the more specific pattern will have
  /// priority over the less specific.
  ///
  /// For example, "~/foo/bar" is ordered before "~/foo/:a-variable". This
  /// is usually the desired order for rules: the path "/foo/bar" will
  /// match that first pattern and the path "/foo/xyz" will match the second
  /// pattern. If the order was reversed, the pattern with the variable segment
  /// will match both paths (i.e. the "~/foo/bar" pattern will be ignored if the
  /// handler for the other pattern processes the request).
  ///
  /// A more practical example are the patterns "~/abc/def/" and
  /// "~/abc/def/:variable".

  int compareTo(Pattern other) {
    var varNameOrder = 0;

    for (var x = 0; x < _segments.length; x++) {
      if (other._segments.length <= x) {
        // No corresponding segment in the other pattern
        return -1; // the longer pattern (this) has priority
      }

      final seg1 = _segments[x];
      final seg2 = other._segments[x];

      if (wildcard == seg1) {
        if (wildcard == seg2) {
          // both wildcards
        } else if (_isVariable(seg2)) {
          return 1; // wildcard <=> variable
        } else if (_isOptional(seg2)) {
          return 1; // wildcard <=> optional
        } else {
          return 1; // wildcard <=> literal
        }
      } else if (_isVariable(seg1)) {
        if (wildcard == seg2) {
          return -1; // variable <=> wildcard
        } else if (_isVariable(seg2)) {
          // both variables
          // These are not yet significant
          if (varNameOrder == 0) {
            varNameOrder = _variableName(seg1).compareTo(_variableName(seg2));
          }
        } else if (_isOptional(seg2)) {
          return 1; // variable <=> optional
        } else {
          return 1; // variable <=> literal
        }
      } else if (_isOptional(seg1)) {
        if (wildcard == seg2) {
          return -1; // optional <=> wildcard
        } else if (_isVariable(seg2)) {
          return -1; // optional <=> variable
        } else if (_isOptional(seg2)) {
          final cmp = _optionalName(seg1).compareTo(_optionalName(seg2));
          if (cmp != 0) {
            return cmp;
          }
        } else {
          return 1; // optional <=> literal
        }
      } else {
        if (wildcard == seg2) {
          return -1; // literal <=> wildcard
        } else if (_isVariable(seg2)) {
          return -1; // literal <=> variable
        } else if (_isOptional(seg2)) {
          return -1; // literal <=> optional
        } else {
          final cmp = seg1.compareTo(seg2); // both literal
          if (cmp != 0) {
            return cmp;
          }
        }
      }
    }

    // At this point, all the segments in this pattern are the same as in the
    // other pattern.

    if (_segments.length == other._segments.length) {
      // Both patterns are semantically the same, so consider the syntax (i.e.
      // the variable names) to determine the order.
      return varNameOrder;
    } else {
      // The other pattern has more segments
      return 1; // the longer pattern (other) has priority
    }
  }

  //----------------------------------------------------------------
  /// Matches a path to the pattern.
  ///
  /// Returns the path parameters if the path (from the [components]) matches.
  /// Returns null if the path does not match the pattern.
  ///
  /// For a path to match:
  ///
  /// - literal segments must be present in the path and have the same value
  /// - variable segments must be present in the path, but can have any value
  /// - optional segments must have the exact same value or be absent
  /// - wildcard segments match zero or more segments in the rest of the path.
  ///
  /// If the pattern has variable segments or wildcard segments, the segment(s)
  /// from the path that matches them are returned in the result.
  ///
  /// For example, a pattern that consists solely of literal segments must
  /// match the path exactly. The pattern "~/foo/bar" will only match the
  /// path "/foo/bar".
  ///
  /// The pattern "~/foo/:xyz" will match the path "/foo/bar" and the result
  /// will contain "bar" as the value for the key "xyz". It will
  /// also match the path "/foo/baz" and the result will contain "baz" as
  /// the value for "xyz".
  ///
  /// The pattern "~/foo/bar?/baz" has an optional segment. It will match the
  /// paths "/foo/bar/baz" or "/foo/baz".
  ///
  /// The pattern `~/foo/*` has a wildcard segment. If the path is "/foo/bar",
  /// "bar" is the value of the key `*`. If the path is "/foo/abc/def", the
  /// value of the key `*` is "abc/def". If the path is "/foo/x/y/z", the
  /// value of the key `*` is "x/y/z".

  RequestParams match(List<String> components) {
    final result = RequestParams._internalConstructor();

    var componentIndex = 0;
    var segmentIndex = 0;
    for (var segment in _segments) {
      String component;
      if (components.length <= componentIndex) {
        if (wildcard == segment) {
          component = null; // wildcard can match no components
        } else {
          return null; // no component(s) to match this segment
        }
      } else {
        component = components[componentIndex];
      }

      if (_isVariable(segment)) {
        // Variable segment
        result._add(_variableName(segment), component);
        componentIndex++;
      } else if (wildcard == segment) {
        // Wildcard segment
        final numSegmentsLeft = _segments.length - segmentIndex - 1;
        final numConsumed =
            components.length - componentIndex - numSegmentsLeft;
        if (numConsumed < 0) {
          return null; // insufficient components to satisfy rest of pattern
        }
        result._add(
            wildcard,
            components
                .getRange(componentIndex, componentIndex + numConsumed)
                .join(_pathSeparator));
        componentIndex += numConsumed;
      } else if (_isOptional(segment)) {
        // Optional segment
        if (component == _optionalName(segment)) {
          // path component matches the optional segment: skip over it
          componentIndex++;
        } else {
          // assume the optional segment is not present
        }
      } else if (segment == component) {
        // Literal segment
        componentIndex++;
      } else {
        // No match
        return null;
      }

      segmentIndex++;
    }

    if (componentIndex != components.length) {
      return null; // some components did not match
    }

    return result;
  }

  //----------------------------------------------------------------

  @override
  String toString() => '~/${_segments.join(_pathSeparator)}';
}
