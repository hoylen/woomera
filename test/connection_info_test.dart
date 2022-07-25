// Tests the SimulatedConnectionInfo for simulated requests.
//
// Copyright (c) 2022, Hoylen Sue. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.
//----------------------------------------------------------------

import 'dart:async';

import 'dart:io';
import 'package:test/test.dart';

import 'package:woomera/woomera.dart';

//================================================================

void noConnectionInfo() {
  test('default', () {
    final req = Request.simulatedGet('~/test', connectionInfo: null);

    final c = req.connectionInfo;
    expect(c, isNull);
  });
}

//----------------------------------------------------------------

void withConnectionInfo() {
  test('default', () {
    final req = Request.simulatedGet('~/test',
        connectionInfo:
            SimulatedHttpConnectionInfo(InternetAddress('192.168.0.1')));

    final c = req.connectionInfo;
    expect(c, isNotNull);
    expect(c!.remoteAddress.address, equals('192.168.0.1'));
  });
}

//================================================================

Future main() async {
  noConnectionInfo();
  withConnectionInfo();
}
