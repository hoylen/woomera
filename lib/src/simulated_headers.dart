part of woomera;

//================================================================
/// Headers in a simulated request or response

class SimulatedHttpHeaders extends HttpHeaders {
  final Map<String, List<String>> _data = <String, List<String>>{};

  //----------------------------------------------------------------

  @override
  void add(String name, Object value) {
    final lcName = name.toLowerCase();

    List<String> values;
    if (_data.containsKey(lcName)) {
      values = _data[lcName];
    } else {
      values = (_data[lcName] = <String>[]);
    }
    values.add(value.toString());
  }

  //----------------------------------------------------------------

  @override
  List<String> operator [](String name) => _data[name.toLowerCase()];

  //----------------------------------------------------------------

  @override
  String value(String name) {
    final lcName = name.toLowerCase();

    if (_data.containsKey(lcName)) {
      final values = _data[lcName];
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
  void set(String name, Object value) {
    _data[name.toLowerCase()] = [value.toString()];
  }

  //----------------------------------------------------------------

  @override
  void remove(String name, Object value) {
    final lcName = name.toLowerCase();

    if (_data.containsKey(lcName)) {
      _data[lcName].remove(value);
    }
  }

  //----------------------------------------------------------------

  @override
  void removeAll(String name) {
    _data.remove(name.toLowerCase());
  }

  //----------------------------------------------------------------

  @override
  void forEach(void f(String name, List<String> values)) {
    for (var key in _data.keys) {
      f(key.toLowerCase(), _data[key]);
    }
  }

  //----------------------------------------------------------------

  @override
  void noFolding(String name) {}

  //----------------------------------------------------------------

  @override
  void clear() {
    _data.clear();
  }
}
