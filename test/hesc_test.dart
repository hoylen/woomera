// Tests the Woomera package.
//
// Copyright (c) 2015, Hoylen Sue. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.
//----------------------------------------------------------------

library main;

import 'dart:async';

import 'package:test/test.dart';

import 'package:woomera/woomera.dart';

//================================================================
/// Class for testing
///
class TestThing {
  @override
  String toString() => 'begin\nend';
}
//================================================================

Future main() async {
  const alphaNumeric =
      "01234567890ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";
  const specials = "& < > \" '";

  group("text", () {
    test("normal", () {
      final escaped = HEsc.text(alphaNumeric);
      expect(escaped, equals(alphaNumeric));
    });
    test("specials", () {
      final escaped = HEsc.text(specials);
      expect(escaped, equals("&amp; &lt; &gt; \" '"));
    });
    test("null", () {
      final escaped = HEsc.text(null);
      expect(escaped, equals(""));
    });
    test("other values", () {
      expect(HEsc.text(42), equals("42"));
      expect(HEsc.text(new TestThing()), equals("begin\nend"));
    });
  });

  group("attr", () {
    test("normal", () {
      final escaped = HEsc.attr(alphaNumeric);
      expect(escaped, equals(alphaNumeric));
    });
    test("specials", () {
      final escaped = HEsc.attr(specials);
      expect(escaped, equals("&amp; &lt; &gt; &quot; &apos;"));
    });
    test("null", () {
      final escaped = HEsc.attr(null);
      expect(escaped, equals(""));
    });
    test("other values", () {
      expect(HEsc.attr(42), equals("42"));
      expect(HEsc.attr(new TestThing()), equals("begin\nend"));
    });
  });

  group("lines", () {
    test("normal", () {
      final escaped = HEsc.lines(alphaNumeric);
      expect(escaped, equals(alphaNumeric));
    });
    test("specials", () {
      final escaped = HEsc.lines(specials);
      expect(escaped, equals("&amp; &lt; &gt; \" '"));
    });
    test("lines", () {
      final escaped = HEsc.lines("a\nb\nc");
      expect(escaped, equals("a<br/>b<br/>c"));
    });
    test("lines ending with NL", () {
      final escaped = HEsc.lines("a\nb\n");
      expect(escaped, equals("a<br/>b<br/>"));
    });
    test("lines starting with NL", () {
      final escaped = HEsc.lines("\nb\nc");
      expect(escaped, equals("<br/>b<br/>c"));
    });
    test("null", () async {
      final escaped = HEsc.lines(null);
      expect(escaped, equals(""));
    });
    test("other values", () {
      expect(HEsc.lines(42), equals("42"));
      expect(HEsc.lines(new TestThing()), equals("begin<br/>end"));
    });

  });
}
