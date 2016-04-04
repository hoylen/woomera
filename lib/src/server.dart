part of woomera;

//----------------------------------------------------------------

// not found return 404
// "/foo/?" to make trailing slash optional
// parameters exposed in params array
// params[:splat] -> array  *
// first sufficient match wins
// routes with regular expressions
// halt 500
// pass
// redirect 301 or 302
// public_folder
// views - templates
// filters: before after

//----------------------------------------------------------------
/// A Web server.
///
/// This class is used to implement a Web server.
///
/// When its [run] method is called, it listens for HTTP requests on the
/// [bindPort] on its [bindAddress], and responds to them with HTTP responses.
///
/// Each HTTP request is processed through the [pipelines]. A [ServerPipeline]
/// contains a sequence of rules (consisting of a pattern and a handler).  If
/// the request matches the pattern, the corresponding handler is invoked.  If
/// the handler returns a result it is used for the HTTP response, and
/// subsequent handlers and pipelines are not examined. But if the pipeline has
/// no matches or the matches do not return a result, then the next pipeline is
/// examined. If after the request has been through all the pipelines without
/// producing a result, a [NotFoundException] or [MethodNotFoundException]
/// is thrown.
///
/// If an exception is thrown during processing (either by the application's
/// callbacks or by the package's code) the exception handlers will be invoked.
/// Normally, an application will set the server's [exceptionHandler].
///
/// It is also possible to set exception handlers on each pipeline, to handle
/// exceptions raised within that pipeline. If there is no pipeline exception
/// handler, or it cannot handle the exception, the exception handler on the
/// server will be invoked.
///
/// The [urlMaxSize] and [postMaxSize] define limits on the valid requests which
/// can be processed. These are set to reasonable finite values to prevent some
/// types of errors and denial-of-service attacks. Their values can be changed
/// if the application needs to handle large HTTP requests.
///
/// A typical application will only have one instance of this class. But it is
/// possible to create multiple instances of this class for an application to
/// process HTTP requests from multiple ports/interfaces.

class Server {
  /// Maximum size of a URL path and query before it is rejected.
  ///
  /// Although HTTP (RFC 2616) does not specify any length limits for URLs,
  /// implementations usually do (e.g. Microsoft Internet Explorer limits URLS
  /// to 2083 characters and the path length to be 2048 characters).
  /// https://support.microsoft.com/en-us/kb/208427
  ///
  /// Currently, this is compared to the path and query string, so the complete
  /// URI might actually be a bit longer.

  int urlMaxSize = 2048;

  /// Maximum size of POST contents before it is rejected.
  ///
  /// The number of raw bytes in the contents of the request.

  int postMaxSize = 10 * 1024 * 1024;

  //----------------------------------------------------------------

  /// Bind address for the server.
  ///
  /// Can be a String containing a hostname or IP address, or one of these
  /// values from the [InternetAddress] class: [LOOPBACK_IP_V4],
  /// [LOOPBACK_IP_V6], [ANY_IP_V4] or [ANY_IP_V6].  The default value is
  /// LOOPBACK_IP_V6, which means it listens for either IPv4 or IPv6 protocol on
  /// the loopback address.  That is, the server can only be contacted from the
  /// same machine it is running on, which is the normal setup when deploying
  /// the Web server with a reverse proxy (e.g Nginx or Apache) in front of it.
  /// If deployed without a reverse proxy, this value needs to be change
  /// otherwise clients external to the machine will not be allowed to connect
  /// to the Web server.

  var bindAddress = InternetAddress.LOOPBACK_IP_V6;

  /// Port number for the server.
  ///
  /// Set this to the port the server will listen on. The default value of null
  /// means uses 80 for HTTP and 443 for HTTPS.
  ///
  /// Since port numbers below 1024 are reserved, normally the port will have to
  /// be set to a value of 1024 or larger before starting the server. Otherwise,
  /// a "permission denied" [SocketException] will be thrown when trying to
  /// start the server and it is not running with with root privileges.

  int bindPort = null;

  /// The handler pipeline.
  ///
  /// This is a [List] of [ServerPipeline] that the request is processed through.
  ///
  /// Normal [List] operations can be used on it. For example, to obtain the
  /// first pipeline (that the [Server] constructor creates by default):
  ///
  ///     var s = new Server();
  ///     var firstPipeline = s.pipelines.first;
  ///
  /// Or to add additional pipelines:
  ///
  ///     var p2 = new Pipeline();
  ///     s.pipelines.add(p2);

  final List<ServerPipeline> pipelines = new List<ServerPipeline>();

  /// Server level exception handler.
  ///
  /// If an exception occurs outside of a pipeline, or is not handled by
  /// the pipeline's exception handler, the exception is passed to
  /// this exception handler to process.
  ///
  /// If this exception handler is not set (i.e. null), an internal default
  /// exception handler will be used. Its output is very plain and basic, so
  /// most applications should provide their own server-level exception handler.
  ///
  /// Ideally, an application's server-level exception handler should not thrown
  /// an exception.  But if it did throw an exception, the internal default
  /// exception handler will also be used to handle it.

  ExceptionHandler exceptionHandler;

  /// Indicates if the Web server is running secured HTTPS or unsecured HTTP.
  ///
  /// True means it is listening for requests over HTTPS. False means it is
  /// listening for requests over HTTP. Null means it is not running.

  bool get isSecure => _isSecure;

  bool _isSecure;

  // Set when the server is running (i.e. is listening for requests).

  HttpServer _svr = null;

  //----------------------------------------------------------------
  /// Constructor
  ///
  /// Creates a new [Server].
  ///
  /// After creation, a typical application should:
  ///
  /// - change the [bindPort];
  /// - optionally change the [bindAddress] (when not deployed with a reverse proxy);
  /// - configure the first pipeline with handlers;
  /// - optional create and configure additional pipelines;
  /// - define a server-level [exceptionHandler];
  ///
  /// and then invoke the [run] method to start the Web server.
  ///
  /// By default this constructor creates the first pipeline in [pipelines].
  /// Since all Web servers would need at least one pipeline; and simple
  /// applications usually don't need more than one pipeline.  But
  /// [numberOfPipelines] can be set to zero or a number greater than one, to
  /// create that number of pipelines.
  ///
  /// There is nothing special about these initial pipelines. The application
  /// can also create them and add them to the [pipelines] list.

  Server({int numberOfPipelines: 1}) {
    for (var x = 0; x < numberOfPipelines; x++) {
      pipelines.add(new ServerPipeline());
    }
  }

  //----------------------------------------------------------------
  /// Starts the Web server.
  ///
  /// By default a HTTP server is started.
  ///
  ///     s.run();
  ///
  /// To create a secure HTTPS server, initialize the [SecureSocket] database
  /// and invoke this method with [privateKeyFilename], [certificateName] and
  /// [certChainFilename].
  ///
  ///     var certDb = Platform.script.resolve('pkcert').toFilePath();
  ///     SecureSocket.initialize(databse: certDb, password: "p@ssw0rd");
  ///     s.run(privateKeyFilename: "a.pvt", certificateName: "mycert", certChainFilename: "a.crt");
  ///
  /// This method will return a Future whose value is the total number of
  /// requests processed by the server. This value is only available if/when the
  /// server is cleanly stopped. But normally a server listens for requests
  /// "forever" and never stops.
  ///
  /// Throws a [StateError] if the server is already running.

  Future<int> run(
      {String privateKeyFilename: null,
      String certificateName: null,
      String certChainFilename: null}) async {
    if (_svr != null) {
      throw new StateError("server already running");
    }

    // Start the server

    if (certificateName == null || certificateName.isEmpty) {
      // Normal HTTP bind
      _isSecure = false;
      _svr = await HttpServer.bind(bindAddress, bindPort ?? 80);
    } else {
      // Secure HTTPS bind
      //
      // Note: this uses the TLS libraries in Dart 1.13 or later.
      // https://dart-lang.github.io/server/tls-ssl.html
      _isSecure = true;
      var securityContext = new SecurityContext()
        ..useCertificateChain(certChainFilename)
        ..usePrivateKey(privateKeyFilename);
      _svr = await HttpServer.bindSecure(
          bindAddress, bindPort ?? 443, securityContext,
          backlog: 5);
    }

    // Log that it started

    var url = (_isSecure) ? "https://" : "http://";
    url += (_svr.address.isLoopback) ? "localhost" : _svr.address.host;
    if (_svr.port != null) {
      url += ":${_svr.port}";
    }

    _logServer.fine(
        "${(_isSecure) ? "HTTPS" : "HTTP"} server started: ${_svr.address} port ${_svr.port} <${url}>");

    // Listen for and process HTTP requests

    int numRequestsReceived = 0;

    var requestLoopCompleter = new Completer();

    runZoned(() async {
      // The request processing loop

      await for (var request in _svr) {
        await _handleRequest(request, ++numRequestsReceived);
      }

      requestLoopCompleter.complete();
    }, onError: (e, s) {
      // The event processing code uses async try/catch, so something very wrong
      // must have happened for an exception to have been thrown outside that.
      _logServer.shout("uncaught exception (${e.runtimeType}): ${e}", s);
      requestLoopCompleter.complete();
    });

    await requestLoopCompleter.future;

    // Finished: it only gets to here if the server stops running (see [stop] method)

    _logServer.fine(
        "${(_isSecure) ? "HTTPS" : "HTTP"} server stopped: ${numRequestsReceived} requests");
    _svr = null;
    _isSecure = null;

    return numRequestsReceived;
  }

  //----------------------------------------------------------------
  /// Stops the Web server.
  ///
  /// Stops this server from listing for new connections.
  ///
  /// This method is rarely used, since most Web servers are designed to
  /// run forever. But it can be used to implement a server shutdown feature.
  ///
  /// The returned future completes when the server is stopped.
  ///
  /// If [force] is true, active connections will be closed immediately.

  Future stop({bool force: false}) async {
    if (_svr != null) {
      await _svr.close(force: force);
    }
  }

  //----------------------------------------------------------------
  // Handles a HTTP request. This method processes the stream of HTTP requests.

  Future _handleRequest(HttpRequest request, int requestNo) async {
    try {
      // Create context

      var req = new Request._internal(request, requestNo, this);
      await req._postParmsInit(this.postMaxSize);
      req._sessionRestore(); // must do this after obtaining the post parameters

      // Handle the request in its context

      await _handleRequestWithContext(req);

      // The _handleRequestWithContext normally deals with any exceptions
      // that might be thrown, otherwise something very bad went wrong!
      // The following catch statements deal with that situation, or if the
      // context could not be created (which is also very bad).

    } catch (e, s) {
      var status;
      var message;

      _logRequest
          .shout("[$requestNo] exception raised outside context: $e\n$s");

      // Since there is no context, the exception handlers cannot be used
      // to generate the response, this will generate a simple HTTP response.

      if (e is FormatException ||
          e is PathTooLongException ||
          e is PostTooLongException) {
        status = HttpStatus.BAD_REQUEST;
        message = "Bad request";
      } else {
        status = HttpStatus.INTERNAL_SERVER_ERROR;
        message = "Internal error";
      }

      var resp = request.response;
      resp.statusCode = status;
      resp.write("$message\n");

      _logResponse.fine("[$requestNo] status=$status ($message)");
    } finally {
      request.response.close();
    }
  }

  //--------
  // Handles a HTTP request with its [Context]. Processes it through the
  // pipeline (and handling any exceptions raised).

  Future _handleRequestWithContext(Request req) async {
    var methodFound = false;
    Response response;

    var pathSegments = req._request.uri.pathSegments;

    // Process the request through the pipeline.

    // This section of code guarantees to set the "response" (even if exceptions
    // are thrown while it is being processed), otherwise it means no matching
    // handlers were found (or they did not preduce a response) in any of the
    // pipelines. If the "response" is null, the "unsupportedMethod" indicates
    // whether there were at least one rule for the request.method, even though
    // none of the patterns matched it.

    for (var pipe in pipelines) {
      var rules = pipe.rules(req._request.method);
      if (rules == null) {
        // This pipe does not support the method
        continue; // skip to next pipe in the pipeline
      }
      methodFound = true;

      for (var rule in rules) {
        var params = rule._matches(pathSegments);

        if (params != null) {
          // A matching rule was found

          req._pathParams = params; // set matched path parameters

          if (_logRequest.level <= Level.FINE) {
            // Log path parameters
            var str = "[${req._requestNo}] path parameters:";
            if (params.isNotEmpty) {
              str += " ${params.length} key(s)";
              str += params.toString();
            } else {
              str += " none";
            }
            _logRequest.fine(str);
          }

          _logRequest.fine("[${req._requestNo}] matched rule: ${rule}");

          // Invoke the rule's handler

          try {
            response = await _invokeRequestHandler(rule.handler, req);
          } catch (initialException, initialStackTrace) {
            // The request handler threw an exception (or returned null which
            // caused the InvalidUsage exception to be thrown above).

            assert(response == null);

            var e = initialException;
            var st = initialStackTrace;

            // Try the pipe's exception handler

            if (pipe.exceptionHandler != null) {
              // This pipe has an exception handler: pass exception to it
              try {
                response = await _invokeExceptionHandler(
                    pipe.exceptionHandler, req, e, st);
              } catch (pipeEx, pipeSt) {
                // The pipe exception handler threw an exception
                e = new ExceptionHandlerException(e, pipeEx);
                st = pipeSt;
              }
            }

            if (response == null) {
              // The exception was not handled by the pipe exception.
              // Either there was no exception handler for the pipe, or it
              // returned null, or it threw another exception.

              // Try the server's exception handler

              if (this.exceptionHandler != null) {
                // The server has an exception handler: pass exception to it
                try {
                  //response = await this.exceptionHandler(req, e, st);
                  response = await _invokeExceptionHandler(
                      this.exceptionHandler, req, e, st);
                } catch (es) {
                  e = new ExceptionHandlerException(e, es);
                }
              }
            }

            if (response == null) {
              // The exception was not handled by the pipe exception handler
              // nor the server exception handler.
              //
              // Either the pipe exception handler did not handle it (see
              // above for reasons), there was no exception handler for the
              // server, the server handler returned null, or the server
              // handler threw an exception.

              // Resort to using the built-in default exception handler.

              // response = await _defaultExceptionHandler(req, e, st);
              response = await _invokeExceptionHandler(
                  _defaultExceptionHandler, req, e, st);
            }

            assert(response != null);
          }

          // At this point a response has been produced (either by the
          // request handler or one of the exception handlers) or the
          // handler returned null.

          if (response != null) {
            // handler produced a result
            break; // stop looking for further matches in this pipe
          } else {
            // handler indicated that processing is to continue processing with
            // the next match in the rule/pipeline.
          }
        } // pattern match found in this pipeline

      } // for all rules in the pipeline

      if (response != null) {
        break; // stop looking for further matches in subsequent pipelines
      }
    } // for all pipes in pipeline

    // Handle no match

    if (response == null) {
      // No rule matched or the ones that did match all returned null

      var e;

      if (methodFound) {
        _logRequest.fine("handler not found");
        e = new NotFoundException(methodNotFound: false);
      } else {
        _logRequest.fine("handler not found for method");
        e = new NotFoundException(methodNotFound: true);
      }

      // Try reporting this through the server's exception handler

      if (this.exceptionHandler != null) {
        try {
          response = await this.exceptionHandler(req, e, null);
        } catch (es) {
          e = new ExceptionHandlerException(e, es);
        }
      }

      if (response == null) {
        // Resort to using the internal default exception handler.
        response = await _defaultExceptionHandler(req, e, null);
        assert(response != null);
      }
    }

    assert(response != null);

    // Finish the HTTP response from the "response" by invoking its
    // application-visible finish method.

    await response.finish();

    // Really finish the HTTP response from the "response" by invoking its
    // internal finish method.

    response._finish(req);
  }

// contentLength -1
  // cookies
  // encoding
  // headers
  //resp.encoding = ContentType.UTF8;

  //----------------------------------------------------------------
  // Internal default exception handler.
  //
  // This is the exception handler that is invoked if the application did not
  // provide a server-level exception handler, or its server-level exception
  // handler threw an exception. It generates a "last resort" error page.

  static Future<Response> _defaultExceptionHandler(
      Request req, Object e, StackTrace st) async {
    var resp = new ResponseBuffered(ContentType.HTML);

    if (e is NotFoundException) {
      // Report these as "not found" to the requestor.

      _logRequest.severe(
          "[${req._requestNo}] not found: ${req._request.method} ${req._request.uri.path}");
      assert(st == null);

      resp.status = (e.methodNotFound)
          ? HttpStatus.METHOD_NOT_ALLOWED
          : HttpStatus.NOT_FOUND;
      resp.write("""
<html>
<head>
<title>Error: not found</title>
<style type="text/css">body { background: #333; color: #fff; }</style>
</head>
<body>
<h1>Not found</h1>
<p>The requested page was not found.</p>
</body>
</html>
""");
    } else {
      // Everything else is reported to the requester as an internal error
      // since the problem can only be fixed by the developer and we don't
      // want to expose any internal information.

      if (e is! ExceptionHandlerException) {
        _logResponse.severe(
            "[${req._requestNo}] exception thrown (${e.runtimeType}): ${e}");
      } else {
        ExceptionHandlerException wrapper = e;
        _logResponse.severe(
            "[${req._requestNo}] exception handler threw an exception (${wrapper.exception.runtimeType}): ${wrapper.exception}");
      }
      if (st != null) {
        _logResponse.finest("[${req._requestNo}] stack trace:\n${st}");
      }

      resp.status = HttpStatus.INTERNAL_SERVER_ERROR;
      resp.write("""
<html>
<head>
<title>Error: server error</title>
<style type="text/css">body { background: #333; color: #c00; }</style>
</head>
<body>
<h1>Server error</h1>
<p>An error occured while trying to process the request.</p>
</body>
</html>
""");
    }

    return resp;
  }

  //================================================================

  /// The base path under which all patterns are under.

  String get basePath => _basePath;

  String _basePath = "/";

  /// Sets the base path.
  ///
  /// The base path is prepended to all patterns and is a simple
  /// way to "move" all the URLs to a different root.

  void set basePath(String value) {
    if (value == null || value.isEmpty) {
      _basePath = "/";
    } else if (value.startsWith("/")) {
      _basePath = value;
    } else {
      throw new ArgumentError.value(
          value, "value", "basePath: does not start with a '/' and is not null/blank");
    }
  }

  //================================================================
  // Session management

  /// The default expiry time for sessions in this server.
  ///
  /// The [Session.refresh] method refreshes the session to expire in this
  /// amount of time, if no explicit value was passed to it. If this value
  /// is not set (null), an internal default expiry time is used.
  ///
  /// When a [Server] is created this is initially not set.

  Duration sessionExpiry;

  /// The name of the cookie used to track sessions.
  ///
  /// Applications should normally not need to worry about this value.
  /// It only needs changing if it clashes with a cookie used by the
  /// application.

  String sessionCookieName = "wSession";

  /// Force the use of secure cookies for the session cookie.
  ///
  /// If session cookies are used, they are created with their secure flag set
  /// if this is set to true. That indicated to the browser to only send the
  /// cookie over a secure connection (HTTPS).
  ///
  /// The default value is false. This allows the cookies to be used over HTTPS
  /// and unsecured HTTP, which is necessary when testing over HTTP.
  ///
  /// Note: if the server is run over HTTPS (i.e. the [run] method is invoked
  /// with credentials) secure cookies are automatically used. Therefore,
  /// setting this member to true is only important if running the Web server
  /// in unsecured mode, but with a HTTPS reverse proxy providing a secured
  /// connection to the Web server.

  bool sessionCookieForceSecure = false;

  /// The name of the URL query parameter used to track sessions (if cookies
  /// are not used).
  ///
  /// Applications should normally not need to worry about this value.
  /// It only needs changing if it clashes with a query parameter used by the
  /// application.
  ///
  /// This is used for both URL rewriting (i.e. as the name of a query parameter
  /// as well as a hidden form parameter.

  String sessionParamName = "wSession";

  // Tracks all active sessions

  Map<String, Session> _allSessions = new Map<String, Session>();

  //----------------------------------------------------------------

  void _sessionRegister(Session s) {
    _allSessions[s.id] = s;
  }

  //----------------------------------------------------------------
  /// Finds the session with the given [id].
  ///
  /// Returns the session.
  /// Returns null if the session does not exist. This would be the case if
  /// a session with that id never existed, was terminated or timed-out.

  Session _sessionFind(String id) {
    return _allSessions[id];
  }

  //----------------------------------------------------------------
  // When a session is stopped (either terminated or by timeout) this
  // method is called.

  void _monitorSessionStop(Session session, bool byTimeOut) {
    // TODO
  }
}
