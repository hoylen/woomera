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

/// Type for a request factory.
///
/// Note: despite the name, this has nothing to do with the Dart factory keyword.

typedef FutureOr<Request> RequestCreator(
    HttpRequest request, String id, Server server);

/// Use [RequestCreator] typedef instead.
///
/// This name can be confused with the `factory` feature in Dart.

@deprecated
typedef FutureOr<Request> RequestFactory(
    HttpRequest request, String id, Server server);

//----------------------------------------------------------------
/// A Web server.
///
/// When its [run] method is called, it listens for HTTP requests on the
/// [bindPort] on its [bindAddress], and responds to them with HTTP responses.
///
/// Each HTTP request is processed through the [pipelines], which is a [List] of
/// [ServerPipeline] objects. A ServerPipeline
/// contains a sequence of rules (consisting of a pattern and a handler).  If
/// the request matches the pattern, the corresponding handler is invoked.  If
/// the handler returns a result it is used for the HTTP response, and
/// subsequent handlers and pipelines are not examined. But if the pipeline has
/// no matches or the matches do not return a result, then the next pipeline is
/// examined. If after the request has been through all the pipelines without
/// producing a result, a [NotFoundException] is thrown.
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
  //================================================================
  // Constructors

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

  Server({int numberOfPipelines = 1}) {
    for (var x = 0; x < numberOfPipelines; x++) {
      pipelines.add(new ServerPipeline());
    }
  }

  //================================================================
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

  /// Identity of the server.
  ///
  /// This is used as a prefix to the request number to form the [Request.id] to
  /// identify the [Request]. This is commonly used in log messages:
  ///
  ///     mylog.info("[${req.id}] something happened");
  ///
  /// The default value of the empty string is usually fine for most
  /// applications, since most applications are only running one [Server].  But
  /// if multiple servers are running, give them each a unique [id] so the
  /// requests can be uniquely identified.

  String id = "";

  //----------------------------------------------------------------

  /// Bind address for the server.
  ///
  /// Can be a String containing a hostname or IP address, or one of these
  /// values from the [InternetAddress] class: [InternetAddress.loopbackIPv4],
  /// [InternetAddress.loopbackIPv6], [InternetAddress.anyIPv4] or
  /// [InternetAddress.anyIPv6].
  ///
  /// The default value is loopbackIPv4, which means it only listens on the
  /// IPv4 loopback address of 127.0.0.1. This option is usually used when
  /// the service is run behind a reverse proxy server (e.g. Apache or Nginx).
  /// The server can only be contacted over IPv4 from the same machine.
  ///
  /// If deployed without a reverse proxy, this value needs to be change
  /// otherwise clients external to the machine will not be allowed to connect
  /// to the Web server.
  ///
  /// If it is set to [InternetAddress.anyIPv6], it listens on any IPv4 or
  /// IPv6 address (including the loop-back addresses),
  /// unless [v6Only] is set to true (in which case it only listens on any IPv6
  /// address and the IPv6 loopback address).

  InternetAddress bindAddress = InternetAddress.loopbackIPv4;

  /// Indicates how a [bindAddress] value of [InternetAddress.anyIPv6] treats IPv4 addresses.
  ///
  /// The default is false, which means it listens to any IPv4 and any IPv6
  /// addresses.
  ///
  /// If set to true, it only listens on any IPv6 address. That is, it will not
  /// listen on any IPv4 address.
  ///
  /// This value has no effect if the [bindAddress] is not
  /// [InternetAddress.anyIPv6]. Therefore, it is not possible to listen on
  /// both IPv4 and IPv6 loop-back addresses at the same time (not without also
  /// listening on every IPv4 and IPv6 address too).

  bool v6Only = false;

  /// Port number for the server.
  ///
  /// Set this to the port the server will listen on. The default value of null
  /// means uses 80 for HTTP and 443 for HTTPS. HTTPS or HTTP is used depending
  /// on if [run] is invoked with a private key and certificate, or not.
  ///
  /// Since port numbers below 1024 are reserved, normally the port will have to
  /// be set to a value of 1024 or larger before starting the server. Otherwise,
  /// a "permission denied" [SocketException] will be thrown when trying to
  /// start the server and it is not running with with root privileges.

  int bindPort;

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

  final List<ServerPipeline> pipelines = <ServerPipeline>[];

  /// Server level exception/error handler.
  ///
  /// If an exception occurs outside of a pipeline, or is not handled by
  /// the pipeline's exception handler, the exception is passed to
  /// this exception handler to process.
  ///
  /// If this exception/exception handler is not set (i.e. null), an internal
  /// default exception/error handler will be used. Its output is very plain and
  /// basic, so most applications should provide their own server-level
  /// exception/error handler.
  ///
  /// Ideally, an application's server-level exception/error handler should not
  /// thrown an exception.  But if it did throw an exception, the internal
  /// default exception/error handler will also be used to handle it.

  ExceptionHandler exceptionHandler;

  bool _isSecure;

  /// Function used to create a [Request] object for each HTTP request.
  ///
  /// Applications can set this to a [RequestCreator] function that returns
  /// a subclass of [Request] or a Future that produces one. This allows them
  /// to pass custom information to handlers in the request object and to
  /// perform custom cleanup at the end of request processing (by overriding the
  /// the [Request.release] method).
  ///
  /// The default is null, which means the server will create a normal [Request]
  /// object.

  RequestCreator requestCreator;

  // Set when the server is running (i.e. is listening for requests).

  HttpServer _svr;

  //================================================================
  // Getters and setters

  /// Indicates if the Web server is running secured HTTPS or unsecured HTTP.
  ///
  /// True means it is listening for requests over HTTPS. False means it is
  /// listening for requests over HTTP. Null means it is not running.

  bool get isSecure => _isSecure;

  //================================================================
  // For backward compatibility
  // TODO: remove in a future release.

  /// Use [requestCreator] instead.
  ///
  /// This name can be confused with the `factory` feature in Dart.

  @deprecated
  RequestCreator get requestFactory => requestCreator;

  /// Use [requestCreator] instead.
  ///
  /// This name can be confused with the `factory` feature in Dart.

  @deprecated
  set requestFactory(RequestCreator c) {
    requestCreator = c;
  }

  //================================================================
  // Methods

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
      {String privateKeyFilename,
      String certificateName,
      String certChainFilename}) async {
    if (_svr != null) {
      throw new StateError("server already running");
    }

    // Start the server

    if (certificateName == null || certificateName.isEmpty) {
      // Normal HTTP bind
      _isSecure = false;
      _svr = await HttpServer.bind(bindAddress, bindPort ?? 80, v6Only: v6Only);
    } else {
      // Secure HTTPS bind
      //
      // Note: this uses the TLS libraries in Dart 1.13 or later.
      // https://dart-lang.github.io/server/tls-ssl.html
      _isSecure = true;
      final securityContext = new SecurityContext()
        ..useCertificateChain(certChainFilename)
        ..usePrivateKey(privateKeyFilename);
      _svr = await HttpServer.bindSecure(
          bindAddress, bindPort ?? 443, securityContext,
          v6Only: v6Only, backlog: 5);
    }

    // Log that it started

    final buf = new StringBuffer()
      ..write((_isSecure) ? "https://" : "http://")
      ..write((_svr.address.isLoopback) ? "localhost" : _svr.address.host);
    if (_svr.port != null) {
      buf.write(":${_svr.port}");
    }
    final url = buf.toString();

    _logServer.fine(
        "${(_isSecure) ? "HTTPS" : "HTTP"} server started: ${_svr.address} port ${_svr.port} <$url>");

    // Listen for and process HTTP requests

    var requestNo = 0;

    final requestLoopCompleter = new Completer<int>();

    // ignore: UNUSED_LOCAL_VARIABLE
    final doNotWaitOnThis = runZoned(() async {
      // The request processing loop

      await for (var request in _svr) {
        try {
          // Note: although _handleRequest returns a Future that completes when
          // the request is fully processed, this does NOT wait for it to
          // complete, so that multiple requests can be handled in parallel.

          //_logServer.info("HTTP Request: [$id${requestNo + 1}] starting handler");

          final doNotWait = _handleRawRequest(request, "$id${++requestNo}");
          assert(doNotWait != null);

          //_logServer.info("HTTP Request: [$id$requestNo] handler started");

        } catch (e, s) {
          _logServer.shout(
              "uncaught try/catch exception (${e.runtimeType}): $e", e, s);
        }
      }

      requestLoopCompleter.complete(0);
    }, onError: (Object e, StackTrace s) {
      // The event processing code uses async try/catch, so something very wrong
      // must have happened for an exception to have been thrown outside that.
      _logServer.shout("uncaught onError (${e.runtimeType}): $e", e, s);

      // Note: this can happen in situations where a handler uses both
      // completeError() to set an error and also throws an exception.
      // Will get a Bad state: Future already completed.

      // Abort server?
      //if (!requestLoopCompleter.isCompleted) {
      //  requestLoopCompleter.complete(0);
      //}
    });

    await requestLoopCompleter.future;

    // Finished: it only gets to here if the server stops running (see [stop] method)

    _logServer.fine(
        "${(_isSecure) ? "HTTPS" : "HTTP"} server stopped: $requestNo requests");
    _svr = null;
    _isSecure = null;

    return requestNo;
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
  /// Any sessions are terminated.
  ///
  /// If [force] is true, active connections will be closed immediately.

  Future stop({bool force = false}) async {
    _logServer.finer("stop: ${_allSessions.length} sessions, force=$force");

    if (_allSessions.isNotEmpty) {
      // Terminate all sessions
      // First copy values to a list, because calling [terminate] will change
      // the Map so simply iterating over [_allSessions.values] will not work.
      final sList = _allSessions.values.toList(growable: false);
      for (var s in sList) {
        await s.terminate();
      }
    }

    if (_svr != null) {
      // Stop the HTTP server
      await _svr.close(force: force);
    }

    _logServer.finer("stop: closed");
  }

  //----------------------------------------------------------------
  // Handles a HTTP request. This method processes the stream of HTTP requests.

  Future _handleRawRequest(HttpRequest httpRequest, String requestId) async {
    try {
      // Create context

      Request req;

      if (requestCreator != null) {
        // Application uses a custom request: invoke it for the request object
        _logRequest.finest("_handleRequest: creating custom request object");

        final x = requestCreator(httpRequest, requestId, this);
        req = (x is Request) ? x : await x; // await if it is a Future
      } else {
        // No custom request: create a [Request] object
        _logRequest.finest("_handleRequest: creating standard request object");

        req = new Request(httpRequest, requestId, this);
      }
      assert(req != null);

      await _processRequest(req);

      // The _handleRequestWithContext normally deals with any exceptions
      // that might be thrown, otherwise something very bad went wrong!
      // The following catch statements deal with that situation, or if the
      // context could not be created (which is also very bad).

    } catch (e, s) {
      int status;
      String message;

      _logRequest
        ..finer("[$requestId] exception raised outside context: $e")
        ..finest("[$requestId] exception stack trace:\n$s");

      // Since there is no context, the exception handlers cannot be used
      // to generate the response, this will generate a simple HTTP response.

      if (e is StateError && e.message == "Header already sent") {
        // Cannot generate error page, since a page has already been started
        status = null;
      } else if (e is FormatException ||
          e is PathTooLongException ||
          e is PostTooLongException) {
        status = HttpStatus.badRequest;
        message = "Bad request";
      } else {
        status = HttpStatus.internalServerError;
        message = "Internal error";
      }

      if (status != null) {
        // Can generate error page as a response
        httpRequest.response
          ..statusCode = status
          ..write("$message\n");
        _logResponse.fine("[$requestId] status=$status ($message)");
      }
    } finally {
      await httpRequest.response.close(); // always close the response
    }

    _logRequest.finest("_handleRequest: done");
  }

  //--------
  /// Processes a Woomera request.

  Future _processRequest(Request req) async {
    try {
      await req._postParamsInit(postMaxSize);

      await req._sessionRestore(); // must be after POST parameters gotten

      // Handle the request in its context

      await _handleRequestWithContext(req);
    } finally {
      // The release method on the [Request] (or its subclass) is always
      // invoked so it can clean up. For example, when a request subtype
      // has a transaction that needs to be released.
      await req.release();
    }
  }

  //--------
  // Handles a HTTP request with its [Context]. Processes it through the
  // pipeline (and handling any exceptions raised).

  Future _handleRequestWithContext(Request req) async {
    var methodFound = false;
    var handlerFound = false;
    Response response;

    final pathSegments = req._pathSegments; // can be null

    if (pathSegments != null) {
      // Good request
      // Process the request through the pipeline.

      // This section of code guarantees to set the "response" (even if exceptions
      // are thrown while it is being processed), otherwise it means no matching
      // handlers were found (or they did not preduce a response) in any of the
      // pipelines. If the "response" is null, the "unsupportedMethod" indicates
      // whether there were at least one rule for the request.method, even though
      // none of the patterns matched it.

      for (var pipe in pipelines) {
        final rules = pipe.rules(req.method);
        if (rules == null) {
          // This pipe does not support the method
          continue; // skip to next pipe in the pipeline
        }
        methodFound = true;

        for (var rule in rules) {
          final params = rule._matches(pathSegments);

          if (params != null) {
            // A matching rule was found

            handlerFound = true;

            _logRequest.finer("[${req.id}] matched rule: $rule");

            req.pathParams = params; // set matched path parameters

            if (params.isNotEmpty && _logRequestParam.level <= Level.FINER) {
              // Log path parameters
              final str =
                  "[${req.id}] path: ${params.length} key(s): ${params.toString()}";
              _logRequestParam.finer(str);
            }

            // Invoke the rule's handler

            try {
              response = await _invokeRequestHandler(rule.handler, req);
            } catch (initialObjectThrown, initialStackTrace) {
              // The request handler threw an exception (or returned null which
              // caused the InvalidUsage exception to be thrown above).

              assert(response == null);

              Object e = initialObjectThrown; // not necessarily an Exception
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

                if (exceptionHandler != null) {
                  // The server has an exception handler: pass exception to it
                  try {
                    //response = await this.exceptionHandler(req, e, st);
                    response = await _invokeExceptionHandler(
                        exceptionHandler, req, e, st);
                  } catch (es) {
                    e = new ExceptionHandlerException(e, es);
                  }
                }
              }

              // If null, the exception was not handled by the pipe exception
              // handler nor the server exception handler.
              //
              // Either the pipe exception handler did not handle it (see
              // above for reasons), there was no exception handler for the
              // server, the server handler returned null, or the server
              // handler threw an exception.

              // Resort to using the built-in default exception handler.

              // response = await _defaultExceptionHandler(req, e, st);
              response ??= await _invokeExceptionHandler(
                  _defaultExceptionHandler, req, e, st);
            }

            // At this point a response has been produced (either by the
            // request handler or one of the exception handlers) or the
            // handler returned null.

            if (response != null) {
              // handler produced a result
              break; // stop looking for further matches in this pipe
            } else {
              _logRequest.fine(
                  "[${req.id}] handler returned no response, continue matching");
              // handler indicated that processing is to continue processing with
              // the next match in the rule/pipeline.
            }
          } // pattern match found in this pipeline

        }
        // for all rules in the pipeline

        if (response != null) {
          break; // stop looking for further matches in subsequent pipelines
        }
      }
      // for all pipes in pipeline

      // Handle no match

      if (response == null) {
        // No rule matched or the ones that did match all returned null

        int found;
        if (handlerFound) {
          assert(methodFound);
          found = NotFoundException.foundHandler;
          _logRequest
              .fine("[${req.id}] not found: all handler(s) returned null");
        } else if (methodFound) {
          found = NotFoundException.foundMethod;
          _logRequest.fine("[${req.id}] not found: found method but no rule");
        } else {
          found = NotFoundException.foundNothing;
          _logRequest.fine("[${req.id}] not found: method not supported");
        }

        Exception e = new NotFoundException(found);

        // Try reporting this through the server's exception handler

        if (exceptionHandler != null) {
          try {
            response = await this.exceptionHandler(req, e, null);
          } catch (es) {
            e = new ExceptionHandlerException(e, es);
          }
        }

        if (response == null) {
          // Server exception handler returned null, or it threw an exception
          // Resort to using the internal default exception handler.
          response = await _defaultExceptionHandler(req, e, null);
          assert(response != null);
        }
      }
    } else {
      // Path segments raised FormatException: malformed request
      response = await _defaultExceptionHandler(
          req, new MalformedPathException(), null);
    }

    assert(response != null);

    // Finish the HTTP response from the "response" by invoking its
    // application-visible finish method.

    await response.finish(req);

    // Really finish the HTTP response from the "response" by invoking its
    // internal finish method.

    response._finish(req);

    // Suspend the session (if there is one after the handler has processed the request)

    await req._sessionSuspend();
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
      Request req, Object thrownObject, StackTrace st) async {
    var status = HttpStatus.internalServerError;
    String title;
    String message;

    if (thrownObject is NotFoundException) {
      // Report these as "not found" to the requester.

      _logRequest
          .severe("[${req.id}] not found: ${req.method} ${req.requestPath()}");
      assert(st == null);

      status = (thrownObject.found == NotFoundException.foundNothing)
          ? HttpStatus.methodNotAllowed
          : HttpStatus.notFound;
      title = "Error: Not found";
      message = "The page you were looking for was not found.";
    } else if (thrownObject is MalformedPathException) {
      // Report as bad request

      _logRequest.finest(
          "[${req.id}] bad request: ${req.method} ${req.requestPath()}");
      assert(st == null);

      status = HttpStatus.badRequest;
      title = "Error: bad request";
      message = "Your request was invalid.";
    } else {
      // Everything else is reported to the requester as an internal error
      // since the problem can only be fixed by the developer and we don't
      // want to expose any internal information.

      if (thrownObject is ExceptionHandlerException) {
        final ex = thrownObject.exception;
        _logResponse.severe(
            "[${req.id}] exception handler threw (${ex.runtimeType}): $ex");
      } else {
        _logResponse.severe(
            "[${req.id}] exception thrown (${thrownObject.runtimeType}): $thrownObject");
      }
      if (st != null) {
        _logResponse.finest("[${req.id}] stack trace:\n$st");
      }

      status = HttpStatus.internalServerError;
      title = "Error";
      message = "An error occured while processing the request.";
    }

    final resp = new ResponseBuffered(ContentType.html)
      ..status = status
      ..write("""
<!doctype html>
<html>
  <head>
    <title>$title</title>
    <style type="text/css">h1 { color: #c00; }</style>
  </head>
  <body>
    <h1>$title</h1>
    <p>$message</p>
  </body>
</html>
""");
    return resp;
  }

  //================================================================
  /// Simulate the processing of a HTTP request.
  ///
  /// This is used for testing a server.
  ///
  /// Pass in a [Request] for the server to process. This will be a _Request_
  /// created using one of these constructors:
  /// [Request.simulated], [Request.simulatedGet] or [Request.simulatedPost].
  ///
  /// The response returned can then be examined to determine if the server
  /// produced the expected HTTP response.

  Future<SimulatedResponse> simulate(Request req) async {
    // Set the server for the request. This is done here, so a simulated
    // request doesn't need to have its server set when it is constructed.

    req._serverSet(this);

    // Get the server to process the request

    _logRequest.fine("[${req.id}] ${req.method} ${req.requestPath()}");

    await _processRequest(req);

    // Return the response

    final result = req._simulatedResponse;

    // Clear server in the simulated request, so it can be set in the future
    req._serverSet(null); // must do this AFTER calling req._simulatedResponse.

    return result;
  }

  //================================================================

  /// The base path under which all patterns are under.
  ///
  /// Paths and patterns in this framework are always considered to be
  /// relative to this _base path_. All paths and patterns used internally must
  /// start with "~/". This is a visual reminder it is relative to the base
  /// path; and the APIs will reject paths and patterns without it.
  ///
  /// The main purpose of these relative paths, is to ensure all paths are
  /// processed through the [Request.rewriteUrl] method before presenting it
  /// to the client. This mechanism ensure that all URLs get rewritten, so the
  /// sessions are preserved (if cookies are not being used to preserve
  /// sessions).
  ///
  /// Another benefit is to change the URLs for all the pages in the server by
  /// simply changing the base path.
  ///
  /// For example, if the base path is "/site/version/1", then the page
  /// "~/index.html" might be mapped to http:example.com:1024/site/version/1/index.html.
  ///
  /// The default value is "/".

  String get basePath => _basePath;

  String _basePath = "/";

  /// Sets the base path.
  ///
  /// The base path is prepended to all patterns and is a simple
  /// way to "move" all the URLs to a different root.

  set basePath(String value) {
    if (value == null || value.isEmpty) {
      _basePath = "/";
    } else if (value.startsWith("/")) {
      if (value == '/' || !value.endsWith('/')) {
        _basePath = value;
      } else {
        throw new ArgumentError.value(value, "value",
            'basePath: cannot end with "/" (unless it is just "/")');
      }
    } else {
      throw new ArgumentError.value(value, "value",
          "basePath: does not start with a '/' and is not null/blank");
    }
  }

  //----------------------------------------------------------------
  /// Convert an external path to an internal path.
  ///
  /// This is the inverse of [Request.rewriteUrl], converting a string like
  /// "/foo/bar/baz" into "~/foo/bar/baz" (if the server's base path is "/").
  /// Or converting "/abc/def/foo/bar/baz" to "~/foo/bar/baz" (if the server's
  /// base path is "/abc/def").
  ///
  /// If the external path contains query parameters, they are removed.

  String internalPath(String externalPath) {
    if (externalPath != null && externalPath.startsWith(_basePath)) {
      // Strip off any query parameters
      final q = externalPath.indexOf('?');
      final noQueryParams =
          (0 < q) ? externalPath.substring(0, q) : externalPath;

      return '~/${noQueryParams.substring(_basePath.length)}';
    } else {
      throw new ArgumentError.value(
          externalPath, "externalPath", 'does not start with "$_basePath"');
    }
  }

  //================================================================
  // Session management

  /// The default expiry time for sessions in this server.
  ///
  /// The [Session._refresh] method refreshes the session to expire in
  /// this amount of time, if no explicit value was passed to it. If this value
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

  /// All active sessions
  ///
  /// An [Iterable] of all the currently active sessions.

  Iterable<Session> get sessions => _allSessions.values;

  /// Number of active sessions.

  int get numSessions => _allSessions.length;

  // Internal Map to track all active sessions.

  final Map<String, Session> _allSessions = {};

  //----------------------------------------------------------------

  void _sessionRegister(Session s) {
    _allSessions[s.id] = s;
  }

  //----------------------------------------------------------------

  void _sessionUnregister(Session s) {
    _allSessions.remove(s.id);
  }
  //----------------------------------------------------------------
  /// Finds the session with the given [id].
  ///
  /// Returns the session.
  /// Returns null if the session does not exist. This would be the case if
  /// a session with that id never existed, was terminated or timed-out.

  Session _sessionFind(String id) => _allSessions[id];
}
