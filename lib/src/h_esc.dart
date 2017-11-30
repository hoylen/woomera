part of woomera;

//----------------------------------------------------------------
/// HTML escaping methods for escaping values for output in HTML.
///
/// These methods are provided to help generate HTML from arbitrary strings
/// and other objects.
///
/// Use [attr] to escape values to be used in attributes.
/// Use [text] to escape values to be used in CDATA content.
/// Use [lines] to escape values to be used in CDATA content, where
/// line breaks are to be indicated with <br/> tags.
///
/// Examples:
/// ```dart
/// var alpha = 'Don't use <blink>Flash</blink> & "stuff" in HTML.';
/// var beta = "1. First line\n2. second line\n3. third line";
///
/// resp.write("""
/// <div title="${HEsc.attr(alpha)}">
///   <p>${HEsc.text(alpha)}</p>
///   <p>${HEsc.text(123)}</p>
///   <p>${HEsc.lines(beta)}</p>
/// </div>
/// """);
/// ```
/// Writes out:
/// ```html
/// <div title="Don&apos;t use &lt;blink&gt;Flash&lt;/blink&gt; &amp; &quot;stuff&quot;.">
///   <p>Don't use &lt;blink&gt;Flash&lt;/blink&gt; &amp; other "stuff".</p>
///   <p>123</p>
///   <p>1. First line<br/>2. second line<br/>3. third line</p>
/// </div>
/// ```

abstract class HEsc {
  //----------------------------------------------------------------
  /// Escape values for placement inside a HTML or XML attribute.
  ///
  /// Returns a string where all characters &, <, >, ' and " in the string
  /// representation of [value] is replaced by its HTML entities.
  /// The string representation is produced by invoking `toString` on the value.
  ///
  /// If [value] is null, the empty string is returned.

  static String attr(Object value) {
    if (value != null) {
      var s = value.toString().replaceAll("&", "&amp;");
      s = s.replaceAll("<", "&lt;");
      s = s.replaceAll(">", "&gt;");
      s = s.replaceAll("'", "&apos;");
      s = s.replaceAll('"', "&quot;");
      return s;
    } else {
      return "";
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

  static String text(Object value) {

    if (value != null) {
      var s = value.toString().replaceAll("&", "&amp;");
      s = s.replaceAll("<", "&lt;");
      s = s.replaceAll(">", "&gt;");
      return s;
    } else {
      return "";
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

  static String lines(Object value) {
    if (value != null) {
      final buf = new StringBuffer();
      var started = false;

      for (var line in value.toString().split("\n")) {
        if (started) {
          buf.write("<br/>");
        } else {
          started = true;
        }
        buf.write(HEsc.text(line));
      }
      return buf.toString();
    } else {
      return "";
    }
  }

  //----------------------------------------------------------------
  // Implementation should have used something like this, but this doesn't
  // work as expected. It has/had an unusually interpretation of which characters
  // needed to be escaped and which didn't.

  // static HtmlEscape _escape_CDATA = new HtmlEscape(HtmlEscapeMode.ELEMENT);
  // static HtmlEscape _escape_PCDATA = new HtmlEscape(HtmlEscapeMode.ATTRIBUTE);
  //
  // return _escape_PCDATA.convert(obj.toString());
}
