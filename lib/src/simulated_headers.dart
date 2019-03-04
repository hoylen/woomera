part of woomera;

//================================================================
/// Headers in a simulated request or response

class SimulatedHttpHeaders extends HttpHeaders {
  // TODO: case insensitive keys

  final Map<String, List<String>> _data = <String, List<String>>{};

  @override
  void add(String name, Object value) {
    List<String> values;
    if (_data.containsKey(name)) {
      values = _data[name];
    } else {
      values = (_data[name] = <String>[]);
    }
    values.add(value.toString());
  }

  @override
  List<String> operator [](String name) => _data[name];

  @override
  String value(String name) {
    if (_data.containsKey(name)) {
      final values = _data[name];
      if (values.isEmpty) {
        return null;
      } else if (values.length == 1) {
        return values.first;
      } else {
        throw StateError('multiple values in header: $name');
      }
    } else {
      return null;
    }
  }

  @override
  void set(String name, Object value) {
    _data[name] = [value.toString()];
  }

  @override
  void remove(String name, Object value) {
    if (_data.containsKey(name)) {
      _data[name].remove(value);
    }
  }

  @override
  void removeAll(String name) {
    _data.remove(name);
  }

  @override
  void forEach(void f(String name, List<String> values)) {
    for (var key in _data.keys) {
      f(key.toLowerCase(), _data[key]);
    }
  }

  @override
  void noFolding(String name) {}

  @override
  void clear() {
    _data.clear();
  }
}
