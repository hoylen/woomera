part of core;

//================================================================
/// Headers in a simulated request or response

class SimulatedHttpHeaders extends HttpHeaders {
  // Map from the lowercase value of the header name to the "current case" of
  // the header name. This is to support the `preserveHeaderCase` feature that
  // was introduced in Dart 2.8 for the [add] and [set] methods.

  final _originalHeaderNames = <String, String>{};

  // Map from the lowercase value of the header name to its values.

  final _data = <String, List<String>>{};

  //----------------------------------------------------------------

  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {
    // Dart 2.8 adds the preserveHeaderCase option
    final lcName = name.toLowerCase();

    var values = _data[lcName];
    if (values == null) {
      final createdList = <String>[];
      _data[lcName] = createdList;
      values = createdList;
    }
    values.add(value.toString());

    _originalHeaderNames[lcName] = preserveHeaderCase ? name : lcName;
  }

  //----------------------------------------------------------------

  @override
  List<String>? operator [](String name) => _data[name.toLowerCase()];

  //----------------------------------------------------------------

  @override
  String? value(String name) {
    final lcName = name.toLowerCase();

    final values = _data[lcName];
    if (values != null) {
      if (values.isEmpty) {
        return null;
      } else if (values.length == 1) {
        return values.first;
      } else {
        throw StateError('multiple values in header: $lcName');
      }
    } else {
      return null;
    }
  }

  //----------------------------------------------------------------

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    // Dart 2.8 adds the preserveHeaderCase option
    final lcName = name.toLowerCase();

    _data[lcName] = [value.toString()];

    _originalHeaderNames[lcName] = preserveHeaderCase ? name : lcName;
  }

  //----------------------------------------------------------------

  @override
  void remove(String name, Object value) {
    final lcName = name.toLowerCase();

    final values = _data[lcName];
    if (values != null) {
      values.remove(value);
      if (values.isEmpty) {
        _data.remove(lcName);
        _originalHeaderNames.remove(lcName);
      }
    }
  }

  //----------------------------------------------------------------

  @override
  void removeAll(String name) {
    final lcName = name.toLowerCase();

    _data.remove(lcName);
    _originalHeaderNames.remove(lcName);
  }

  //----------------------------------------------------------------

  @override
  void forEach(void Function(String name, List<String> values) f) {
    for (var key in _data.keys) {
      f(_originalHeaderNames[key]!, _data[key]!);
    }
  }

  //----------------------------------------------------------------

  @override
  void noFolding(String name) {}

  //----------------------------------------------------------------

  @override
  void clear() {
    _data.clear();
    _originalHeaderNames.clear();
  }
}
