// Tests the [Pattern] class from the Woomera package.
//
// Copyright (c) 2020, Hoylen Sue. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.
//----------------------------------------------------------------

library main;

import 'dart:async';

import 'package:test/test.dart';

import 'package:woomera/woomera.dart';

//----------------------------------------------------------------

void validPatterns() {
  group('valid patterns', () {
    // Tests pattern strings are parsed into pattern objects and the string
    // representation of those pattern objects are the expected value
    // (which may be a different the the input).

    for (final sample in <String, String>{
      '~': '~/',
      '~/': '~/',
      '~/foo': '~/foo',
      '~/foo/bar': '~/foo/bar',
      '~//foo': '~/foo',
      '~///foo': '~/foo',
      '~////foo': '~/foo',
    }.entries) {
      final input = sample.key;
      final canonical = sample.value;

      test(input, () {
        final p = Pattern(input);
        expect(p.toString(), equals(canonical));
      });
    }
  });
}

//----------------------------------------------------------------

void invalidPatterns() {
  group('invalid patterns', () {
    for (final sample in [
      '',
      'foo',
      '/',
      '/foo',
      'bar/',
      '~~/bar',
      '~/combined/component/:abc?',
      '~/combined/component/:*',
      '~/combined/component/*?',
      '~/combined/component/:*?',
    ]) {
      test(sample.isNotEmpty ? sample : '(blank string)', () {
        try {
          Pattern(sample);
          fail('did not throw an exception: $sample');
          // ignore: avoid_catching_errors
        } on ArgumentError catch (e) {
          assert(e.name == 'pattern');
        }
      });
    }
  });
}

//----------------------------------------------------------------

void matching() {
  group('match', () {
    test('variables', () {
      final pattern = Pattern('~/foo/:bar');

      final params1 = pattern.match(['foo', 'valueMatchingTheVariable']);
      expect(params1, isNotNull);
      expect(params1!['bar'], equals('valueMatchingTheVariable'));
      expect(params1.keys.length, equals(1));

      final params2 = pattern.match(['foo', 'differentValue']);
      expect(params2, isNotNull);
      expect(params2!['bar'], equals('differentValue'));
      expect(params2.keys.length, equals(1));

      expect(pattern.match([]), isNull);
      expect(pattern.match(['foo']), isNull);
      expect(pattern.match(['differentLiteralPreventsMatch', 'abc']), isNull);
      expect(
          pattern.match(['foo', 'abc', 'extraSegmentPreventsMatch']), isNull);
      expect(pattern.match(['foo', 'abc', '']), isNull);
    });

    test('optionals', () {
      final pattern = Pattern('~/foo/bar?/baz');

      final params1 = pattern.match(['foo', 'bar', 'baz']);
      expect(params1, isNotNull);
      expect(params1!.keys.length, equals(0));

      final params2 = pattern.match(['foo', 'baz']);
      expect(params2, isNotNull);
      expect(params2!.keys.length, equals(0));

      expect(pattern.match([]), isNull);
      expect(pattern.match(['foo']), isNull);
      expect(pattern.match(['foo', 'differntSegment', 'baz']), isNull);
      expect(pattern.match(['foo', '', 'baz']), isNull);
      expect(pattern.match(['foo', 'doesNotMatchBaz']), isNull);
    });

    group('wildcard', () {
      test('at the end of the pattern', () {
        // Wildcard at end of pattern (most common usage o)
        final pattern = Pattern('~/foo/*');

        final params0 = pattern.match(['foo']);
        expect(params0, isNotNull);
        expect(params0!['*'], equals(''));
        expect(params0.keys.length, equals(1));

        final params1 = pattern.match(['foo', 'bar']);
        expect(params1, isNotNull);
        expect(params1!['*'], equals('bar'));
        expect(params1.keys.length, equals(1));

        final params2 = pattern.match(['foo', 'bar', 'baz']);
        expect(params2, isNotNull);
        expect(params2!['*'], equals('bar/baz'));
        expect(params2.keys.length, equals(1));

        final params3 = pattern.match(['foo', 'bar', 'baz', 'abc']);
        expect(params3, isNotNull);
        expect(params3!['*'], equals('bar/baz/abc'));
        expect(params3.keys.length, equals(1));

        expect(pattern.match([]), isNull);
      });

      test('in the middle of the pattern', () {
        // Wildcard in middle of pattern (rare, but allowed)

        expect(Pattern.wildcard, equals('*'));

        final pattern = Pattern('~/foo/*/bar/:baz');

        final params1 = pattern.match(['foo', 'bar', 'xyz']);
        expect(params1, isNotNull);
        expect(params1![Pattern.wildcard], equals(''));
        expect(params1['baz'], equals('xyz'));
        expect(params1.keys.length, equals(2));

        final params2 = pattern.match(['foo', 'a', 'b', 'c', 'bar', 'XYZ']);
        expect(params2, isNotNull);
        expect(params2!['*'], equals('a/b/c'));
        expect(params2['baz'], equals('XYZ'));
        expect(params2.keys.length, equals(2));

        expect(pattern.match([]), isNull);
        expect(pattern.match(['foo']), isNull);
        expect(pattern.match(['foo', 'bar']), isNull);
        expect(pattern.match(['foo', 'a', 'b', 'c', 'bar']), isNull);
        expect(pattern.match(['foo', 'bar', 'xyz', 'extraSegment']), isNull);
      });
    });
  });
}

void sorting() {
  group('ordering', () {
    test('ordered equally', () {
      for (final pair in [
        ['~/literal', '~/literal'],
        ['~/:variable', '~/:variable'],
        ['~/optional?', '~/optional?'],
        ['~/*', '~/*'],
        ['~/a/b/c/d', '~/a/b/c/d'],
        ['~/a/:b/c/d', '~/a/:b/c/d'],
      ]) {
        final p1 = Pattern(pair[0]);
        final p2 = Pattern(pair[1]);

        expect(p1.compareTo(p2), equals(0), reason: '$p1 not ordered as $p2');
        expect(p2.compareTo(p1), equals(0), reason: '$p1 not ordered as $p2');
      }
    });

    test('ordered differently', () {
      for (final pair in [
        ['~/foo', '~/zzz'],
        ['~/foo', '~/:foo'],
        ['~/foo', '~/foo?'],
        ['~/foo', '~/*'],
        ['~/bar?', '~/zzz?'],
        ['~/bar?', '~/:bar'],
        ['~/bar?', '~/*'],
        ['~/:baz', '~/:zzz'],
        ['~/:baz', '~/*'],
        ['~/a/longerPath', '~/a'],
        ['~/a?/longerPath', '~/a?'],
        ['~/:a/longerPath', '~/:a'],
        ['~/*/longerPath', '~/*'],
        ['~/a/b/c/d', '~/a/b/c/zzz'],
        ['~/a/:zzzVarName/ccc', '~/a/:aaaVarName/zzz'],
        ['~/a/:aaaVarName/same', '~/a/:zzzVarName/same'],
      ]) {
        final p1 = Pattern(pair[0]);
        final p2 = Pattern(pair[1]);

        expect(p1.compareTo(p2), lessThan(0), reason: '$p1 versus $p2');
        expect(p2.compareTo(p1), greaterThan(0), reason: '$p2 versus $p1');
      }
    });
  });
}

void sameness() {
  group('same', () {
    test('same patterns', () {
      for (final pair in [
        ['~/literal', '~/literal'],
        ['~/:variable', '~/:variable'],
        ['~/:variable', '~/:differentVariableName'],
        ['~/optional?', '~/optional?'],
        ['~/*', '~/*'],
        ['~/a/b/c/d', '~/a/b/c/d'],
        ['~/a/:b/c/d', '~/a/:B/c/d'],
        ['~/a/:aaaVarName/same', '~/a/:zzzVarName/same'],
      ]) {
        final p1 = Pattern(pair[0]);
        final p2 = Pattern(pair[1]);

        expect(p1.matchesSamePaths(p2), isTrue,
            reason: '$p1 not the same as $p2');
        expect(p2.matchesSamePaths(p1), isTrue,
            reason: '$p1 not the same as $p2');
      }
    });

    test('not same patterns', () {
      for (final pair in [
        ['~/foo', '~/zzz'],
        ['~/foo', '~/:foo'],
        ['~/foo', '~/foo?'],
        ['~/foo', '~/*'],
        ['~/optional?', '~/differentOptionalName?'],
        ['~/bar?', '~/:bar'],
        ['~/bar?', '~/*'],
        ['~/:baz', '~/*'],
        ['~/a/longerPath', '~/a'],
        ['~/a?/longerPath', '~/a?'],
        ['~/:a/longerPath', '~/:a'],
        ['~/*/longerPath', '~/*'],
        ['~/a/b/c/d', '~/a/b/c/zzz'],
        ['~/a/:zzzVarName/ccc', '~/a/:aaaVarName/zzz'],
      ]) {
        final p1 = Pattern(pair[0]);
        final p2 = Pattern(pair[1]);

        expect(p1.matchesSamePaths(p2), isFalse,
            reason: 'same: $p1 versus $p2');
        expect(p2.matchesSamePaths(p1), isFalse,
            reason: 'same: $p2 versus $p1');
      }
    });
  });
}

//================================================================

Future main() async {
  validPatterns();
  invalidPatterns();
  matching();
  sorting();
  sameness();
}
