part of woomera;

//----------------------------------------------------------------
/// HTML escaping methods for escaping values for output in HTML.
///
/// Since most Web Server applications generate HTML, these methods are
/// provided to help generate HTML from arbitrary text strings.
///
/// Use [attr] to escape values to be used in attributes.
/// Use [text] to escape values to be used in CDATA content.
/// Use [lines] to escape values to be used in CDATA content, where
/// line breaks are to be indicated with <br/> tags.
///
/// Examples:
///     <p class="${HEsc.attr(alpha)">HEsc.text(beta)</p>
///     <p>HEsc.lines(gamma)</p>

class HEsc {

  // static HtmlEscape _escape_CDATA = new HtmlEscape(HtmlEscapeMode.ELEMENT);
  // static HtmlEscape _escape_PCDATA = new HtmlEscape(HtmlEscapeMode.ATTRIBUTE);
  //
  // The above Dart class does not work properly, otherwise this class can
  // be implemented using them. They have/had an unusual interpretation of what
  // characters need to be escaped and which didn't.
  //
  // return _escape_PCDATA.convert(obj.toString());

  //----------------------------------------------------------------
  /// Escape values for placement inside a HTML or XML attribute.
  ///
  /// Converts &, <, >, ' and " into HTML entities.
  ///
  /// If obj is null, the empty string is returned.

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
  /// Converts &, < and > into HTML entities.
  ///
  /// If obj is null, the empty string is returned.

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
  /// Between each line a <br/> break element is added. If there
  /// is only one line, no break elements are added. Each line is escaped
  /// according to the [text] method.
  ///
  /// If obj is null, the empty string is returned.

  static String lines(var obj) {
    if (obj != null) {
      StringBuffer buf = new StringBuffer();

      for (var line in obj.toString().split("\n")) {
        if (buf.isNotEmpty) {
          buf.write("<br/>");
        }
        buf.write(HEsc.text(line));
      }
      return buf.toString();
    } else {
      return "";
    }
  }
}
