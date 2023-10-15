part of core;

//----------------------------------------------------------------
// ignore: avoid_classes_with_only_static_members
/// Escaping arbitrary values for use in HTML documents.
///
/// - Use [attr] to escape values to be used in attribute values.
/// - Use [text] to escape values to be used in CDATA content.
/// - Use [lines] to escape values to be used in CDATA content, where
///   line breaks are to be indicated with `<br/>` tags.
///
/// These methods can be passed any Object. If they are not Strings, the
/// _toString_ method is invoked on it to obtain it string representation to
/// escape.
///
/// # Example
///
/// ```dart
/// const alpha = 'Don\'t use <blink> & "bad" tags.';
/// const beta = "1. First line\n2. second line\n3. third line";
///
/// resp.write('''
/// <p>${HEsc.text(alpha)}</p>
/// <p title="${HEsc.attr(alpha)}">attr</p>
/// <p>${HEsc.text(123)}</p>
/// <p>${HEsc.text(DateTime.now())}</p>
/// <p>${HEsc.lines(beta)}</p>
/// ''');
/// ```
///
/// Writes out:
///
/// ```html
/// <p>Don't use &lt;blink&gt; &amp; "bad" tags.</p>
/// <p title="Don&apos;t use &lt;blink&gt; &amp; &quot;bad&quot; tags.">attr</p>
/// <p>123</p>
/// <p>2023-10-18 17:00:00.000000</p>
/// <p>1. First line<br/>2. second line<br/>3. third line</p>
/// ```
///
/// # Alternatives
///
/// The standard `dart:convert` library defines a `HtmlEscape` class which can
/// be used to perform a similar function.
/// But it only converts Strings, is harder and is more verbose to use.
/// It also encodes single quotes as `&#39;` instead of the more human readable
/// `&apos;`.

abstract class HEsc {
  //----------------------------------------------------------------

  // Programs should never create this object.

  HEsc._noConstructor();

  //----------------------------------------------------------------
  /// Escape values for placement inside a HTML or XML attribute.
  ///
  /// Returns a string where all characters &, <, >, ' and " in the string
  /// representation of [value] is replaced by its HTML entities.
  /// The string representation is produced by invoking `toString` on the value.
  ///
  /// If [value] is null, the empty string is returned.

  static String attr(Object? value) {
    if (value != null) {
      var s = value.toString().replaceAll('&', '&amp;');
      s = s.replaceAll('<', '&lt;');
      s = s.replaceAll('>', '&gt;');
      s = s.replaceAll("'", '&apos;');
      s = s.replaceAll('"', '&quot;');
      return s;
    } else {
      return '';
    }
  }

  //----------------------------------------------------------------
  /// Escape values for placement inside the contents of a HTML or XML element.
  ///
  /// Returns a string where all characters &, < and > in the string
  /// representation of [value] is replaced by its HTML entities.
  /// The string representation is produced by invoking `toString` on the value.
  ///
  /// If [value] is null, the empty string is returned.

  static String text(Object? value) {
    if (value != null) {
      var s = value.toString().replaceAll('&', '&amp;');
      s = s.replaceAll('<', '&lt;');
      s = s.replaceAll('>', '&gt;');
      return s;
    } else {
      return '';
    }
  }

  //----------------------------------------------------------------
  /// Format multi-line text for placement inside a HTML element.
  ///
  /// Any line breaks in the string is replaced by a `<br/>` break element.
  /// Each line is escaped using [text]. If there is only one line (i.e.
  /// there is no new line) no break elements are added.
  ///
  /// The string representation is produced by invoking `toString` on the value.
  ///
  /// If [value] is null, the empty string is returned.

  static String lines(Object? value) {
    if (value != null) {
      final buf = StringBuffer();
      var started = false;

      for (var line in value.toString().split('\n')) {
        if (started) {
          buf.write('<br/>');
        } else {
          started = true;
        }
        buf.write(HEsc.text(line));
      }
      return buf.toString();
    } else {
      return '';
    }
  }

/*
One problem with HtmlEscape in dart:convert is it makes encoding arbitrary
values in arbitrary attributes (i.e. the program doesn't need to worry about
if the attribute puts the value in single or double quotes) difficult.
You either have to know how it is quoted, to choose between
HtmlEscapeMode.attribute and HtmlEscapeMode.sqAttribute modes, or use
HTMLEscapeMode.unknown.

//----------------------------------------------------------------
// Demo program

import 'dart:convert';
import 'package:woomera/woomera.dart';

void main() {
  print('Example:');

  // Example in above documentation

  const alpha = 'Don\'t use <blink> & "bad" tags.';
  const beta = '1. First line\n2. second line\n3. third line';

  print('''
  <p>${HEsc.text(alpha)}</p>
  <p title="${HEsc.attr(alpha)}">attr</p>
  <p>${HEsc.text(123)}</p>
  <p>${HEsc.text(DateTime.now())}</p>
  <p>${HEsc.lines(beta)}</p>
''');

  // Showing what the dart:convert HtmlEscape class does

  for (final mode in [
    HtmlEscapeMode.element,
    HtmlEscapeMode.attribute,
    HtmlEscapeMode.sqAttribute,
    HtmlEscapeMode.unknown,
  ]) {
    final dt = HtmlEscape(mode);

    print('''

HTMLEscapeMode ${dt.mode}:
  ${dt.convert(alpha)}
''');
  }
}
*/
}
