part of core;

//================================================================
/// Handler for returning static files and directory listings.
///
/// The [handler] expects a single wildcard path parameter, which it uses
/// to determine which file/directory under the base directory to return.
///
/// Example:
///
/// ```dart
/// var sf = StaticFiles("/var/www/myfiles",
///                          defaultFilenames: ["index.html", "index.htm"]);
///
/// srv.pipelines.first.get("~/myfiles/*", sf.handler);
/// ```
///
/// **Known issues**
///
/// - The encoding of text and HTML files (where the filenames end with .txt,
/// .html or .htm) must be UTF-8.

class StaticFiles {
  //----------------------------------------------------------------
  /// Constructor
  ///
  /// Requests for a directory (i.e. path ending in "/")
  /// returns one of the [defaultFilenames] in the directory (if it is set and
  /// a file exists), otherwise if [allowDirectoryListing] is true
  /// a listing of the directory is produced, otherwise an exception is thrown.
  ///
  /// The [defaultFilenames] default to [standardFilenames], if not specified.

  StaticFiles(String baseDir,
      {this.defaultFilenames = standardFilenames,
      this.allowFilePathsAsDirectories = true,
      this.allowDirectoryListing = false,
      this.publicServerUrl = ''})
      : _baseDir = _checkAndFixBaseDir(baseDir);

  static String _checkAndFixBaseDir(String baseDir) {
    var x = baseDir.trim();

    // Check if provided [baseDir] directory is usable and canonicalize it

    if (x.isEmpty) {
      throw ArgumentError.value(
          x, 'baseDir', 'empty string not permitted for StaticFiles');
    }

    // Remove all trailing slashes which are bad (and spaces which might be bad)

    while (x.endsWith('/')) {
      x = x.substring(0, x.length - 1).trim();
    }

    if (x.isEmpty) {
      throw ArgumentError.value(
          '/', 'baseDir', 'not permitted for StaticFiles');
    }

    // Prohibit certain top-level directories

    if (['/bin', '/etc', '/home', '/lib', '/tmp', '/var'].contains(x)) {
      throw ArgumentError.value(x, 'baseDir', 'not permitted for StaticFiles');
    }

    // Directory must exist

    if (!Directory(x).existsSync()) {
      throw ArgumentError.value(
          x, 'baseDir', 'directory does not exist for StaticFiles');
    }

    // Directory can be used

    return x;
  }

  //================================================================
  // Static constants

  /// Default MIME types.
  ///
  /// This is used for matching file extensions to MIME types. The file
  /// extensions are strings without the full stop (e.g. "png").
  ///
  /// This list is only examined if a match was not found in the
  /// local [mimeTypes]. If a match could not be found in this global map,
  /// the default of [ContentType.binary] is used.
  ///
  /// This list contains values for extensions such as: txt, html, htm, json,
  /// css, png, jpg, jpeg, gif, xml, js, dart. Note: only lowercase extensions
  /// will match.

  static Map<String, ContentType> defaultMimeTypes = {
    'txt': ContentType.text,
    'html': ContentType.html,
    'htm': ContentType.html,
    'json': ContentType.json,
    'css': ContentType('text', 'css'),
    'png': ContentType('image', 'png'),
    'jpg': ContentType('image', 'jpeg'),
    'jpeg': ContentType('image', 'jpeg'),
    'gif': ContentType('image', 'gif'),
    'xml': ContentType('application', 'xml'),
    'js': ContentType('application', 'javascript'),
    'dart': ContentType('application', 'dart'),
  };

  /// Standard directory files.
  ///
  /// The default values used for [defaultFilenames].

  static const List<String> standardFilenames = ['index.html', 'index.htm'];

  //================================================================

  // The directory to look under.
  //
  // Note: this is never an empty string.

  final String _baseDir;

  /// Names of files to try to find if a directory is requested.
  ///
  /// If a request arrives for a directory and this is not null, an attempt is
  /// made to return one of these files from the directory. If none of these
  /// files are found, [allowDirectoryListing] determines if a listing is
  /// generated or an error is raised.

  final List<String> defaultFilenames;

  /// Permit listing of directory contents.
  ///
  /// If a request arrives for a directory, the default file could not be
  /// used (i.e. [defaultFilenames] is null or a file with any of the names
  /// could not be found in the directory), then this member indicates whether a
  /// listing of the directory is returned or [NotFoundException] is raised.

  bool allowDirectoryListing;

  /// Interpret paths that do not end in slash as directory if not a file.
  ///
  /// If a path does not end with a slash it is treated as a request for a
  /// file. But if a file does not exist with that name, this determines if
  /// it will then be treated as a path to a directory.

  bool allowFilePathsAsDirectories;

  /// Controls whether "not found exceptions" are thrown or not.
  ///
  /// If true, the [handler] will thrown a [NotFoundException] if the
  /// file or directory could not produce a result.
  ///
  /// If false, the handler will return null.
  ///
  /// Its default value is true.
  ///
  /// Normally, the application will want these exceptions to be thrown, so it
  /// can handle the missing file/directory just like any other missing
  /// resource (i.e. process it in an exception handler and generate an error
  /// page back to the client).

  bool throwNotFoundExceptions = true;

  /// Local MIME types specific to this object.
  ///
  /// This is used for matching file extensions to MIME types. The file
  /// extensions are strings without the full stop.
  ///
  /// This list is examined in preference to the [defaultMimeTypes] map. If a
  /// match is found in this property, defaultMimeTypes is not examined.
  /// Otherwise it is examined.
  ///
  /// Example:
  /// ```dart
  /// var sf =   StaticFiles('/var/show/assets/publish');
  /// sf.mimeTypes['rss'] = ContentType('application', 'rss+xml');
  /// sf.mimeTypes['mp3'] = ContentType('audio', 'mpeg');
  ///
  /// pipeline.get('~/podcast/*', sf.handler);
  /// ```
  ///
  /// This map is initially empty.

  Map<String, ContentType> mimeTypes = {};

  /// Public URL used by browsers to send requests to the server.
  ///
  /// This value only needs to be set if using a reverse proxy on a non-standard
  /// port (i.e. not port 80 for HTTP or not port 443 for HTTPS), that forwards
  /// requests to the server for processing.
  ///
  /// If not using reverse proxy, this value should be set to the empty string.
  ///
  /// When a request arrives that matches a directory, and the requested URL
  /// did not end with a slash, the response is a HTTP redirection that adds
  /// a slash to the URL. This is necessary, because otherwise relative links
  /// in the returned document (either a generated directory listing or the
  /// contents of a default file from that directory) will not resolve properly.
  /// If a proxy is being used, the redirection URL must be for the proxy rather
  /// than the actual server, otherwise the browser will not be able to get to
  /// the new URL. This member contains the URL exposed by the proxy.
  ///
  /// For example, consider a server running on port 10000, which has been
  /// deployed behind a reverse proxy running on port 8080.
  /// The browser visits http://example.com:8080/foo/bar, and the reverse proxy
  /// forwards a request for "/foo/bar" to port 10000. The server find a
  /// directory called "bar" and would normally respond with a HTTP redirect to
  /// "/foo/bar/" (adding the extra slash). But in this situation, the browser
  /// would attempt to retrieve http://example.com/foo/bar/ which will
  /// fail (since the reverse proxy is on port 8080). The value of
  /// this member needs to be set to "http://example.com:8080" so that
  /// the HTTP redirect will be to "http://example.com:8080/foo/bar/".

  String publicServerUrl;

  //================================================================

  /// The directory under which to look for files.
  ///
  /// This is set by the constructor.

  String get baseDir => _baseDir;

  //----------------------------------------------------------------
  /// Request handler.
  ///
  /// Register this request handler with the server's pipeline using a pattern
  /// with a single wildcard pattern. That path parameter will be used
  /// as the relative path underneath the [baseDir] to find the file or
  /// directory.

  Future<Response?> handler(Request req) async {
    assert(_baseDir.isNotEmpty);

    // Get the relative path

    final values = req.pathParams.values('*');
    if (values.isEmpty) {
      throw ArgumentError('Static file handler registered with no *');
    } else if (1 < values.length) {
      throw ArgumentError('Static file handler registered with multiple *');
    }

    final components = values[0].split('/');
    var depth = 0;
    while (0 <= depth && depth < components.length) {
      final c = components[depth];
      if (c == '..') {
        components.removeAt(depth);
        depth--;
        if (depth < 0) {
          if (throwNotFoundExceptions) {
            // tried to climb above base directory
            throw NotFoundException(NotFoundException.foundStaticHandler);
          } else {
            return null;
          }
        }
      } else if (c == '.') {
        components.removeAt(depth);
      } else if (c.isEmpty && depth != components.length - 1) {
        components.removeAt(depth); // keep last '' to indicate dir listing
      } else {
        depth++;
      }
    }

    final path = '$_baseDir/${components.join('/')}';
    _logStaticFiles.finer('[${req.id}] static file/directory requested: $path');

    if (!path.endsWith('/')) {
      // Probably a file

      final file = File(path);
      if (file.existsSync()) {
        _logStaticFiles.finest('[${req.id}] static file found: $path');
        return await _serveFile(req, file);
      } else if (allowFilePathsAsDirectories && Directory(path).existsSync()) {
        // A directory exists with the same name

        if (allowDirectoryListing || await _findDefaultFile('$path/') != null) {
          // Can tell the browser to treat it as a directory
          // Note: must change URL in browser to have a '/' at the end,
          // otherwise any relative links would break.
          _logStaticFiles.finest('[${req.id}] treating as static directory');

          // Determine the actual URL that was requested, taking into account
          // any proxying (indicated by [publicUrlPrefix]). If the proxying
          // is not taken into account, the browser won't be able to resolve
          // the URL in the redirect response.
          //
          // In the following, remember `req.requestPath()` is an internal URL
          // that always starts with '~/'.
          //
          // See [publicUrlPrefix] for details.

          String requestedUrl;
          if (publicServerUrl.isEmpty) {
            // No proxying
            requestedUrl = req.requestPath();
          } else if (publicServerUrl.endsWith('/')) {
            // Public URL prefix already ends in a slash, so don't use the
            // slash at the beginning of the requestPath when concatenating.
            requestedUrl = publicServerUrl + req.requestPath().substring(2);
          } else {
            // Public URL prefix does not end in a slash, so use the slash at
            // the beginning of the requestPath
            requestedUrl = publicServerUrl + req.requestPath().substring(1);
          }

          return ResponseRedirect('$requestedUrl/'); // append a slash
        }
      } else {
        _logStaticFiles.finest('[${req.id}] static file not found');
      }
    } else {
      // Request for a directory

      final dir = Directory(path);

      if (dir.existsSync()) {
        // Try to find one of the default files in that directory

        final defaultFile = await _findDefaultFile(path);

        if (defaultFile != null) {
          _logStaticFiles.finest(
              '[${req.id}] static directory: default file found: $defaultFile');
          return await _serveFile(req, defaultFile);
        }

        if (allowDirectoryListing) {
          // List the contents of the directory
          _logStaticFiles.finest('[${req.id}] returning directory listing');
          final notTop = (1 < components.length);
          return await directoryListing(req, dir, linkToParent: notTop);
        } else {
          _logStaticFiles
              .finest('[${req.id}] static directory listing not allowed');
        }
      } else {
        _logStaticFiles.finest('[${req.id}] static directory not found');
      }
    }

    // Not found (or directory listing not allowed)

    if (throwNotFoundExceptions) {
      throw NotFoundException(NotFoundException.foundStaticHandler);
    } else {
      return null;
    }
  }

  Future<File?> _findDefaultFile(String path) async {
    for (var defaultFilename in defaultFilenames) {
      final dfName = '$path$defaultFilename';
      final df = File(dfName);
      if (df.existsSync()) {
        return df;
      }
    }
    return null;
  }

  //----------------------------------------------------------------
  /// Method used to generate a directory listing.
  ///
  /// This method is invoked by the [handler] if the request is for a
  /// directory, the directory exists, the directory does not have any of the
  /// default files, and [allowDirectoryListing] is true.
  ///
  /// It is passed the [Request], [Directory]. If [linkToParent] is true,
  /// if a link to the parent directory is permitted (i.e. this is not the
  /// directory registered with the [StaticFiles]).
  ///
  /// Applications can create a subclass of [StaticFiles] and implement their
  /// own directory listing method, if they want to create a custom directory
  /// listings.
  ///
  /// **Null-safety breaking change:** _linkToParent_ is required.

  Future<Response> directoryListing(Request req, Directory dir,
      {required bool linkToParent}) async {
    final components = dir.path.split('/');
    String title;
    if (2 <= components.length &&
        components[components.length - 2].isNotEmpty &&
        components.last.isEmpty) {
      title = components[components.length - 2];
    } else {
      title = 'Listing';
    }

    final buf = StringBuffer('''
<!doctype html>
<html>
  <head>
    <title>${HEsc.text(title)}</title>
    <style type="text/css">
    body { font-family: sans-serif; }
    ul { font-family: monospace; font-size: larger; list-style-type: none; }
    a { text-decoration: none; display: inline-block; padding: 0.5ex 0.75em; }
    a.parent { border-radius: 0 0 2ex 2ex; }
    a.dir { border-radius: 2ex 2ex 0 0; }
    a.file { border-radius: 2ex; }
    a:hover { text-decoration: underline; }
    a.parent:hover { background: #ddd; }
    a.dir:hover { background: #ddd; }
    a.file:hover { background: #eee; }
    </style>
  </head>
<body>
  <h1>${HEsc.text(title)}</h1>
  <ul>
''');

    if (linkToParent) {
      buf.write(
          '<li><a href=".." title="Parent" class="parent">&#x2191;</a></li>\n');
    }

    await for (var entity in dir.list()) {
      String n;
      String cl;
      if (entity is Directory) {
        n = '${entity.uri.pathSegments[entity.uri.pathSegments.length - 2]}/';
        cl = 'class="dir"';
      } else {
        n = entity.uri.pathSegments.last;
        cl = 'class="file"';
      }
      buf.write('<li><a href="${HEsc.attr(n)}" $cl>${HEsc.text(n)}</a></li>\n');
    }

    buf.write('''
  </ul>
</body>
</html>
''');

    final resp = ResponseBuffered(ContentType.html)
      ..headerAddDate('Date', DateTime.now())
      ..write(buf.toString());
    return resp;
  }

  //----------------------------------------------------------------

  Future<Response> _serveFile(Request req, File file) async {
    // Determine content type

    var contentType = ContentType.binary; // default if no suffix

    final p = file.path;
    final dotIndex = p.lastIndexOf('.');
    if (0 < dotIndex) {
      final slashIndex = p.lastIndexOf('/');
      if (slashIndex < dotIndex) {
        // Dot is in the last segment (i.e. has a file suffix)
        var suffix = p.substring(dotIndex + 1);
        suffix = suffix.toLowerCase();
        contentType =
            mimeTypes[suffix] ?? defaultMimeTypes[suffix] ?? ContentType.binary;
      }
    }

    // Return contents of file
    // Last-Modified, Date and Content-Length helps browsers cache the contents.

    final resp = ResponseStream(contentType)
      ..headerAddDate('Date', DateTime.now())
      ..headerAddDate('Last-Modified', file.lastModifiedSync())
      ..headerAdd('Content-Length', (await file.length()).toString());

    return await resp.addStream(req, file.openRead());
  }
}
