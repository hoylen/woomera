part of woomera;

//================================================================
/// Handler for returning a static files under a local directory.
///

class StaticFiles {
  /// Global MIME types.
  ///
  /// This is used for matching file extensions to MIME types. The file
  /// extensions are strings without the full stop (e.g. "png").
  ///
  /// This list is only examined if a match was not found in the
  /// local [mimeTypes]. If a match could not be found in this global map,
  /// the default of [ContentType.BINARY] is used.

  static Map<String, ContentType> globalMimeTypes = {
    "txt": ContentType.TEXT,
    "html": ContentType.HTML,
    "htm": ContentType.HTML,
    "json": ContentType.JSON,
    "css": new ContentType("text", "css"),
    "png": new ContentType("image", "png"),
    "jpg": new ContentType("image", "jpeg"),
    "jpeg": new ContentType("image", "jpeg"),
    "gif": new ContentType("image", "gif"),
    "xml": new ContentType("application", "xml"),
    "js": new ContentType("application", "javascript"),
    "dart": new ContentType("application", "dart"),
  };

  //================================================================
  /// The directory under which to look for files.

  String baseDir;

  /// Names of files to try to find if a directory is requested.
  ///
  /// If a request arrives for a directory and this is not null, an attempt is
  /// made to return one of these files from the directory. If none of these
  /// files are found, [allowDirectoryListing] determines if a listing is
  /// generated or an error is raised.

  List<String> defaultFilenames;

  /// Permit listing of directory contents.
  ///
  /// If a request arrives for a directory, the default file could not be
  /// used (i.e. [defaultFilename] is null or a file with that name could not
  /// be found in the directory), then this member indicates whether a
  /// listing of the directory is returned or [NotFoundException] is raised.

  bool allowDirectoryListing;

  /// Interpret paths that do not end in slash as directory if not a file.
  ///
  /// If a path does not end with a slash it is treated as a request for a
  /// file. But if a file does not exist with that name, this determines if
  /// it will then be treated as a path to a directory.

  bool allowFilePathsAsDirectories;

  /// Throws not found exceptions.
  ///
  /// If true, the handler will thrown a [StaticNotFoundException] if the
  /// file or directory could not produce a result.
  ///
  /// If false, the handler will return null.

  bool throwNotFoundExceptions;

  /// Local MIME types.
  ///
  /// This is used for matching file extensions to MIME types. The file
  /// extensions are strings without the full stop (e.g. "png").
  ///
  /// This list is examined in preference to the [globalMimeTypes] map.

  Map<String, ContentType> mimeTypes = new Map<String, ContentType>();

  //----------------------------------------------------------------
  /// Constructor
  ///
  /// Requests for a directory (i.e. path ending in "/")
  /// returns the [defaultFile] in the directory (if it is set and that file
  /// exists), otherwise if [allowDirectoryListing] is true
  /// a listing of the directory is produced, otherwise an exception is thrown.

  StaticFiles(String directory,
      {List<String> defaultFilenames,
      bool allowFilePathsAsDirectories: true,
      bool allowDirectoryListing: false,
      bool throwNotFoundExceptions: true}) {
    if (directory == null) {
      throw new ArgumentError.notNull("directory");
    }
    if (directory.isEmpty) {
      throw new ArgumentError.value(directory, "directory", "Empty string");
    }
    baseDir = directory;

    if (defaultFilenames != null) {
      this.defaultFilenames = defaultFilenames;
    } else {
      this.defaultFilenames = []; // empty list
    }
    this.allowDirectoryListing = allowDirectoryListing;
    this.allowFilePathsAsDirectories = allowFilePathsAsDirectories;
    this.throwNotFoundExceptions = throwNotFoundExceptions;
  }

  //----------------------------------------------------------------
  /// Handler

  Future<Response> handler(Request req) async {
    if (baseDir == null) {
      throw new ArgumentError.notNull("baseDir");
    }
    if (baseDir.isEmpty) {
      throw new ArgumentError.value(baseDir, "baseDir", "Empty string");
    }

    // Get the relative path

    var values = req.pathParams.values("*");
    if (values.length < 1) {
      throw new ArgumentError("Static file handler registered with no *");
    } else if (1 < values.length) {
      throw new ArgumentError("Static file handler registered with multiple *");
    }

    var components = values[0].split("/");
    var depth = 0;
    while (0 <= depth && depth < components.length) {
      var c = components[depth];
      if (c == "..") {
        components.removeAt(depth);
        depth--;
        if (depth < 0) {
          if (throwNotFoundExceptions) {
            // tried to climb above base directory
            throw new NotFoundException(NotFoundException.foundStaticHandler);
          } else {
            return null;
          }
        }
      } else if (c == ".") {
        components.removeAt(depth);
      } else if (c.isEmpty && depth != components.length - 1) {
        components.removeAt(depth); // keep last "" to indicate dir listing
      } else {
        depth++;
      }
    }

    var path = baseDir + "/" + components.join("/");
    _logRequest.finer("[${req.id}] static file/directory requested: $path");

    if (!path.endsWith("/")) {
      // Probably a file

      var file = new File(path);
      if (await file.exists()) {
        _logRequest.finest("[${req.id}] static file found: $path");
        return await _serveFile(req, file);
      } else if (allowFilePathsAsDirectories &&
          await new Directory(path).exists()) {
        // A directory exists with the same name

        if (allowDirectoryListing ||
            await _findDefaultFile(path + "/") != null) {
          // Can tell the browser to treat it as a directory
          // Note: must change URL in browser, otherwise relative links break
          _logRequest.finest("[${req.id}] treating as static directory");
          return new ResponseRedirect(req.requestPath() + "/");
        }
      } else {
        _logRequest.finest("[${req.id}] static file not found");
      }
    } else {
      // Request for a directory

      if (await new Directory(path).exists()) {
        // Try to find one of the default files in that directory

        var defaultFile = await _findDefaultFile(path);

        if (defaultFile != null) {
          _logRequest.finest("[${req
                .id}] static directory: default file found: $defaultFile");
          return await _serveFile(req, defaultFile);
        }

        if (allowDirectoryListing) {
          // List the contents of the directory
          _logRequest.finest("[${req.id}] returning directory listing");
          return await _serveDirectoryListing(
              req, path, (1 < components.length));
        } else {
          _logRequest
              .finest("[${req.id}] static directory listing not allowed");
        }
      } else {
        _logRequest.finest("[${req.id}] static directory not found");
      }
    }

    // Not found (or directory listing not allowed)

    if (throwNotFoundExceptions) {
      throw new NotFoundException(NotFoundException.foundStaticHandler);
    } else {
      return null;
    }
  }

  Future<File> _findDefaultFile(String path) async {
    for (var defaultFilename in defaultFilenames) {
      var dfName = path + defaultFilename;
      var df = new File(dfName);
      if (await df.exists()) {
        return df;
      }
    }
    return null;
  }
  //----------------------------------------------------------------

  Future<Response> _serveDirectoryListing(
      Request req, String path, bool allowLinkToParent) async {
    var dir = new Directory(path);
    if (!await dir.exists()) {
      if (throwNotFoundExceptions) {
        throw new NotFoundException(NotFoundException.foundStaticHandler);
      } else {
        return null;
      }
    }

    var components = path.split("/");
    var title;
    if (2 <= components.length &&
        components[components.length - 2].isNotEmpty &&
        components.last.isEmpty) {
      title = components[components.length - 2];
    } else {
      title = "Listing";
    }

    var str = """
<!doctype html>
<html>
  <head>
    <meta charset="utf-8"/>
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
""";

    if (allowLinkToParent) {
      str +=
          "<li><a href=\"..\" title=\"Parent\" class=\"parent\">&#x2191;</a></li>\n";
    }

    await for (var entity in dir.list()) {
      var n;
      var cl;
      if (entity is Directory) {
        n = entity.uri.pathSegments[entity.uri.pathSegments.length - 2] + "/";
        cl = "class=\"dir\"";
      } else {
        n = entity.uri.pathSegments.last;
        cl = "class=\"file\"";
      }
      str += "<li><a href=\"${HEsc.attr(n)}\"$cl>${HEsc.text(n)}</a></li>\n";
    }

    str += """
  </ul>
</body>
</html>
""";

    var resp = new ResponseBuffered(ContentType.HTML);
    resp.write(str);
    return resp;
  }

  //----------------------------------------------------------------

  Future<Response> _serveFile(Request req, File file) async {
    // Determine content type

    var contentType;

    var p = file.path;
    var dotIndex = p.lastIndexOf(".");
    if (0 < dotIndex) {
      var slashIndex = p.lastIndexOf("/");
      if (slashIndex < dotIndex) {
        // Dot is in the last segment
        var suffix = p.substring(dotIndex + 1);
        suffix = suffix.toLowerCase();
        contentType = mimeTypes[suffix] ?? globalMimeTypes[suffix];
      }
    }

    contentType = contentType ?? ContentType.BINARY; // default if not known

    // Return contents of file

    var resp = new ResponseStream(contentType);
    return await resp.addStream(req, file.openRead());
  }
}
