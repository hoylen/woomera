part of core;

/// Simulated HTTP connection information.
///
/// Represents the connection information for a simulated request
/// An instance of this
///
/// An instance of this class can be passed to [Request.simulated],
/// [Request.simulatedGet] or [Request.simulatedPost], to set the
/// connection information the request handler will have access to.
/// Each of those _Request_ constructors has an optional _connectionInfo_ named
/// parameter.

class SimulatedHttpConnectionInfo implements HttpConnectionInfo {
  /// Constructor for a simulated HTTP connection information.

  SimulatedHttpConnectionInfo(this.remoteAddress,
      {this.remotePort = -1, this.localPort = -1});

  // The remote address

  @override
  InternetAddress remoteAddress;

  @override
  int remotePort;

  @override
  int localPort;
}

/*
/// Simulated Internet address.

class SimulatedInternetAddress implements InternetAddress {
  /// Constructor for a simulated Internet address.

  SimulatedInternetAddress({this.address = '127.0.0.1', String? host})
      : _host = host;

  String address;

  String? _host;

  /// Sets the value returned by the [host] getter.
  ///
  /// Setting the _host_ is only possible on a simulated Internet address.
  /// This setter is not available on the [InternetAddress].
  set host(String? s) => _host = s;

  // As per the definition in [InternetAddress.host], if there is no host
  // this returns the [address].
  @override
  String get host => _host ?? address;

  @override
  Uint8List get rawAddress {
    // Convert the string address into 4-bytes

    if (RegExp(r'^\d+\.\d+\.\d+\.\d+$').hasMatch(address)) {
      // Appears to be an IPv4 address (four integers separated by dots)

      final components = address.split('.');
      assert(components.length == 4, 'RegExp for IPv4 was incorrect');

      final v4address = Uint8List(4);

      var n = 0;
      for (final str in components) {
        try {
          final c = int.parse(str);
          if (c < 0 || 255 < c) {
            throw const FormatException('internal'); // caught below and ignored
          }
          v4address[n++] = c;
        } on FormatException {
          // When str is not an integer or (from above) is out of range
          throw FormatException('address is not a valid IPv4: $address');
        }
      }

      return v4address;
    } else {
      if (address == '::0') {
        return Uint8List(16); // all zero IPv6 address
      } else if (address == '::1') {
        final result = Uint8List(16);
        result[15] = 1;
        return result;
      } else if (address.contains(':')) {
        throw FormatException(
            'rawAddress: most IPv6 addresses not yet supported: $address');
      } else {
        throw FormatException('rawAddress: not IPv4 or IPv6: $address');
      }
    }
  }
}
 */
