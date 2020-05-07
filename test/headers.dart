// Tests the SimulatedHttpHeaders class of the Woomera package.
//
// Copyright (c) 2015, Hoylen Sue. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.
//----------------------------------------------------------------

library main;

import 'dart:async';

import 'dart:io';
import 'package:test/test.dart';

import 'package:woomera/woomera.dart';

//================================================================

void httpHeaderTests(HttpHeaders h) {
  test('default', () {
    // Add
    h.add('Foo', 'Bar');

    expect(h['foo'], equals(['Bar']));
    expect(h['FOO'], equals(['Bar']));
    h.forEach((k, vs) {
      expect(k, equals('foo')); // converted to lowercase
      expect(vs.length, equals(1));
      expect(vs.first, equals('Bar'));
    });
    expect(h.value('FoO'), equals('Bar'));
    expect(h.value('fOo'), equals('Bar'));

    // Set
    h.set('fOO', 'Baz');

    expect(h['foo'], equals(['Baz']));
    expect(h['FOO'], equals(['Baz']));
    h.forEach((k, vs) {
      expect(k, equals('foo')); // converted to lowercase
      expect(vs.length, equals(1));
      expect(vs.first, equals('Baz'));
    });
    expect(h.value('FoO'), equals('Baz'));
    expect(h.value('fOo'), equals('Baz'));

    h.clear();
  });

  /* Test only works in Dart SDK >= 2.8

  test('preserveHeaderCase:true', () {
    // Add
    h.add('Foo', 'Bar', preserveHeaderCase: true); // Requires Dart >= 2.8

    expect(h['foo'], equals(['Bar']));
    expect(h['FOO'], equals(['Bar']));
    h.forEach((k, vs) {
      expect(k, equals('Foo')); // case is preserved
      expect(vs.length, equals(1));
      expect(vs.first, equals('Bar'));
    });
    expect(h.value('FoO'), equals('Bar'));
    expect(h.value('fOo'), equals('Bar'));

    // Set
    h.set('fOO', 'Baz', preserveHeaderCase: true); // Requires Dart >= 2.8

    expect(h['foo'], equals(['Baz']));
    expect(h['FOO'], equals(['Baz']));
    h.forEach((k, vs) {
      expect(k, equals('fOO')); // case is preserved
      expect(vs.length, equals(1));
      expect(vs.first, equals('Baz'));
    });
    expect(h.value('FoO'), equals('Baz'));
    expect(h.value('fOo'), equals('Baz'));

    h.clear();
  });
   */
}

Future main() async {
  group('headers', () {
    httpHeaderTests(SimulatedHttpHeaders());
  });
}
