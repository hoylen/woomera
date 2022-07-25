// Tests the SimulatedConnectionInfo for simulated requests.
//
// Copyright (c) 2022, Hoylen Sue. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.
//----------------------------------------------------------------

library main;

import 'dart:async';

import 'dart:io';
import 'package:test/test.dart';

import 'package:woomera/woomera.dart';

//================================================================

void noCertificate() {
  test('no certificate', () {
    final req = Request.simulatedGet('~/test', certificate: null);

    final c = req.certificate;
    expect(c, isNull);
  });
}

//----------------------------------------------------------------
/*
void withCertificate() {
  test('with certificate', () {
    final cert = X509Certificate();

    final req = Request.simulatedGet('~/test',
        certificate: cert);

    final c = req.certificate;
    expect(c, isNotNull);
  });
}
*/

//================================================================

Future main() async {
  noCertificate();
}
