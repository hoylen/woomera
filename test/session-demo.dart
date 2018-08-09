// Session demo
//
// Interactive Web application at http://localhost:1024 to demonstrate the
// creation of sessions and their termination when the Web server is stopped.

import 'dart:async';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:woomera/woomera.dart';

//================================================================

/// The Web server.
Server ws;

/// Timeout to use.
const int defaultTimeout = 60; // seconds

final _log = new Logger("session_test");

//================================================================

Future main() async {
  //loggingSetup(level: Level.ALL);
  loggingSetup(levels: {'woomera.session': Level.ALL});
  //loggingSetup();

  // Create and configure server

  ws = new Server()
    ..bindAddress = InternetAddress.ANY_IP_V6
    ..bindPort = 1024
    ..sessionExpiry = const Duration(seconds: defaultTimeout);

  // Register rules

  ws.pipelines.first..get("~/", _handleTopLevel);
  ws.pipelines.first..post("~/new", _handleNewSession);
  ws.pipelines.first..post("~/stop", _handleStop);

  // Run the server

  await ws.run();
}

//================================================================
// Handlers

//----------------------------------------------------------------

Future<Response> _handleTopLevel(Request req) async {
  final newId = req.queryParams["new"];

  final resp = new ResponseBuffered(ContentType.HTML)..write("""
<html>
  <head>
    <title>Woomera: session demo</title>
    <style type='text/css'>
    td { padding: 0.5ex 0.5em; }
    a.refresh {}
    #currentTime {text-align: right; font-size: smaller;}
    .stop { margin-top: 8ex; }
    </style>
  </head>
  <body>
    <h1>Session Demo</h1>
    
    <form method='POST' action='${req.rewriteUrl("~/new")}'>
      <label for='timeout'>Timeout (seconds)</label>
      <input name='timeout' placeholder='$defaultTimeout' id='timeout'/>
      <input type='submit' value='Create session'/>
    </form>

    <p><a id='refresh' href='${req.rewriteUrl(req.requestPath())}'>Refresh</a></p>
""");

  if (0 < ws.numSessions) {
    resp.write(
        "<table><tr><th>Session ID</th><th>Created</th><th>Timeout</th><th>Expires</th></tr>\n");
    for (var s in ws.sessions) {
      final current =
          (req.session != null && req.session.id == s.id) ? "*" : "";
      final highlight = (s.id == newId) ? "style='color: green;'" : "";
      resp.write("""
      <tr $highlight>
        <td>${s.id}$current</td>
        <td>${s.created}</td>
        <td>${s.timeout}</td>
        <td>${s.expires}</td>
      </tr>
      """);
    }
    resp.write(
        "<tr><td colspan='3' id='currentTime'>Current time:</td><td>${new DateTime.now()}</td></tr></table>\n");
  } else {
    resp.write("<p>No sessions.</p>\n");
  }
  resp.write("""   
    <form method='POST' action='${req.rewriteUrl("~/stop")}'>
      <input id='stop' type='submit' value='Stop server'/>
    </form>
    
  </body>
</html>
  """);

  return resp;
}

//----------------------------------------------------------------

Future<Response> _handleNewSession(Request req) async {
  // Determine the timeout for the new session
  final tStr = req.postParams["timeout"];
  final secs = (tStr.isNotEmpty) ? int.parse(tStr) : defaultTimeout;

  // Create the session
  final session = new Session(ws, new Duration(seconds: secs));
  _log.fine("session created");

  req.session = session;

  return new ResponseRedirect("~/?new=${session.id}");
}

//----------------------------------------------------------------

Future<Response> _handleStop(Request req) async {
  final resp = new ResponseBuffered(ContentType.HTML)..write("""
<html>
  <head>
    <title>Woomera: server stopped</title>
  </head>
  <body>
    <h1>Server stopped</h1>
    
    <p><a href='${req.rewriteUrl("~/")}'>Home</a> (only works if server has been
    restarted)</p>
  </body>
</html>
""");

  new Timer(const Duration(seconds: 3), () async {
    //await LoginSession.abortAll(_server);
    _log.fine("stopping server");
    await ws.stop();
    _log.fine("server stopped");
  });

  return resp;
}

//================================================================
/// Logging

void loggingSetup(
    {Level level = Level.INFO,
    Map<String, Level> levels,
    int loggerNameWidth = 0}) {
  hierarchicalLoggingEnabled = true;
  Logger.root.level = Level.OFF;

  // Setup listener

  Logger.root.onRecord.listen((LogRecord r) {
    final timeStr = r.time.toString().padRight(26, '0');

    var name = r.loggerName;
    if (loggerNameWidth == null) {
      name = ''; // omit
    } else if (loggerNameWidth == 0) {
      name = ': $name'; // natural width
    } else if (loggerNameWidth < name.length) {
      name = ": ${name.substring((name.length - loggerNameWidth))}"; // truncate
    } else {
      name = ": ${name.padRight(loggerNameWidth)}"; // pad
    }

    print("$timeStr$name: ${r.message}");
  });

  // Set up logging levels

  Logger.root.level = level;

  if (levels != null) {
    levels.forEach((String name, Level lvl) => new Logger(name).level = lvl);
  }
}
