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
/// var alpha = "Don't use <blink>Flash</blink> & \"stuff\".";
/// var beta = "First line\nsecond line\nthird line";
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
///   <p>First line<br/>second line<br/>third line</p>
/// </div>
/// ```

abstract class HEsc {
  // Disable default constructor, since this class is not to be instantiated.
  HEsc._internal() {}

  //----------------------------------------------------------------
  /// Escape values for placement inside a HTML or XML attribute.
  ///
  /// The string value of [obj] is obtained (by invoking its toString method)
  /// and any &, <, >, ' and " in the string is replaced by its HTML entities.
  ///
  /// If [obj] is null, the empty string is returned.

  static String attr(var obj) {
    if (obj != null) {
      String s = obj.toString();
      s = s.replaceAll("&", "&amp;");
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
  /// The string value of [obj] is obtained (by invoking its toString method)
  /// and any &, < and > in the string is replaced by its HTML entities.
  ///
  /// If [obj] is null, the empty string is returned.

  static String text(var obj) {
    if (obj != null) {
      String s = obj.toString();
      s = s.replaceAll("&", "&amp;");
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
  /// The string value of [obj] is obtained (by invoking its toString method)
  /// and any line breaks in the string is replaced by a `<br/>` break element.
  /// Each line is escaped using [text]. If there is only one line (i.e.
  /// there is no new line) no break elements are added.
  ///
  /// If [obj] is null, the empty string is returned.

  static String lines(var obj) {
    if (obj != null) {
      StringBuffer buf = new StringBuffer();
      bool started = false;

      for (var line in obj.toString().split("\n")) {
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
  // work as expected. It has/had an unusualy interpretation of which characters
  // needed to be escaped and which didn't.

  // static HtmlEscape _escape_CDATA = new HtmlEscape(HtmlEscapeMode.ELEMENT);
  // static HtmlEscape _escape_PCDATA = new HtmlEscape(HtmlEscapeMode.ATTRIBUTE);
  //
  // return _escape_PCDATA.convert(obj.toString());
}
