part of core;

//----------------------------------------------------------------
// Loggers used in the Woomera package.

Logger _logServer = Logger('woomera.server');

Logger _logRequest = Logger('woomera.request');
Logger _logRequestHeader = Logger('woomera.request.header');
Logger _logRequestParam = Logger('woomera.request.param');

Logger _logResponse = Logger('woomera.response');
Logger _logResponseCookie = Logger('woomera.response.cookie');

Logger _logSession = Logger('woomera.session');

Logger _logStaticFiles = Logger('woomera.static_file');

Logger _logProxy = Logger('woomera.proxy');
Logger _logProxyRequest = Logger('woomera.proxy.request');
Logger _logProxyResponse = Logger('woomera.proxy.response');

//----------------------------------------------------------------
/// List of all the loggers used by this library.
///
/// The Loggers are not in any particular order.

final loggers = [
  _logServer,
  _logRequest,
  _logRequestHeader,
  _logRequestParam,
  _logResponse,
  _logResponseCookie,
  _logSession,
  _logStaticFiles,
  _logProxy,
  _logProxyRequest,
  _logProxyResponse
];
