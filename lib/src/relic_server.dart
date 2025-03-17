import 'dart:async';
import 'dart:io';

import 'package:relic/src/body/body.dart';
import 'package:relic/src/headers/exception/invalid_header_exception.dart';
import 'package:relic/src/headers/standard_headers_extensions.dart';
import 'package:relic/src/hijack/exception/hijack_exception.dart';
import 'package:relic/src/logger/logger.dart';
import 'package:relic/src/message/request.dart';
import 'package:relic/src/message/response.dart';
import 'package:relic/src/util/util.dart';

import 'handler/handler.dart';

/// A [Server] backed by a `dart:io` [HttpServer].
class RelicServer {
  /// The default powered by header to use for responses.
  static const String defaultPoweredByHeader = 'Relic';

  /// The underlying [HttpServer].
  final HttpServer server;

  /// Whether to enforce strict header parsing.
  final bool strictHeaders;

  /// Whether [mountAndStart] has been called.
  Handler? _handler;

  /// The powered by header to use for responses.
  final String poweredByHeader;

  /// Creates a server with the given parameters.
  static Future<RelicServer> createServer(
    InternetAddress address,
    int port, {
    SecurityContext? securityContext,
    int? backlog,
    bool shared = false,
    bool strictHeaders = true,
    String? poweredByHeader,
  }) async {
    backlog ??= 0;
    var server = securityContext == null
        ? await HttpServer.bind(
            address.address,
            port,
            backlog: backlog,
            shared: shared,
          )
        : await HttpServer.bindSecure(
            address.address,
            port,
            securityContext,
            backlog: backlog,
            shared: shared,
          );

    return RelicServer._(
      server,
      strictHeaders: strictHeaders,
      poweredByHeader: poweredByHeader ?? defaultPoweredByHeader,
    );
  }

  /// Mounts a handler to the server. Only one handler can be mounted at a time,
  /// and starts listening for requests.
  void mountAndStart(
    Handler handler,
  ) {
    if (_handler != null) {
      throw StateError(
        "Relic server already has a handler mounted.",
      );
    }
    _handler = handler;
    _startListening();
  }

  Future<void> close() => server.close();

  /// Creates a server with the given parameters.
  RelicServer._(
    this.server, {
    required this.strictHeaders,
    required this.poweredByHeader,
  });

  /// Starts listening for requests.
  void _startListening() {
    catchTopLevelErrors(() {
      server.listen(_handleRequest);
    }, (error, stackTrace) {
      logMessage(
        'Asynchronous error\n$error',
        stackTrace: stackTrace,
        type: LoggerType.error,
      );
    });
  }

  /// Handles incoming HTTP requests, passing them to the handler.
  Future<void> _handleRequest(HttpRequest request) async {
    var handler = _handler;
    if (handler == null) {
      throw StateError(
        "No handler mounted. Ensure the server has a handler before handling requests.",
      );
    }

    // Parsing and converting the HTTP request to a relic request
    Request relicRequest;
    try {
      relicRequest = Request.fromHttpRequest(
        request,
        strictHeaders: strictHeaders,
        poweredByHeader: poweredByHeader,
      );
    } on InvalidHeaderException catch (error, stackTrace) {
      // If the request headers are invalid, respond with a 400 Bad Request status.
      logMessage(
        'Error parsing request headers.\n$error',
        stackTrace: stackTrace,
        type: LoggerType.error,
      );
      // Write the response to the HTTP response.
      return Response.badRequest(
        body: Body.fromString(error.httpResponseBody),
      ).writeHttpResponse(request.response);
    } catch (error, stackTrace) {
      // Catch any other errors.
      logMessage(
        'Error parsing request.\n$error',
        stackTrace: stackTrace,
        type: LoggerType.error,
      );

      // If the error is an [ArgumentError] with the name 'method' or 'requestedUri',
      // respond with a 400 Bad Request status.
      if (error is ArgumentError &&
          (error.name == 'method' || error.name == 'requestedUri')) {
        return Response.badRequest().writeHttpResponse(request.response);
      }

      // Write the response to the HTTP response.
      return Response.internalServerError().writeHttpResponse(
        request.response,
      );
    }

    // Handling the request with the handler
    Response? response;
    try {
      response = await handler(relicRequest);

      // If the response doesn't have a powered by header, add the default one.
      if (response.headers.xPoweredBy == null) {
        response = response.copyWith(
          headers: response.headers.copyWith(
            xPoweredBy: poweredByHeader,
          ),
        );
      }
    } on InvalidHeaderException catch (error, stackTrace) {
      // If the request headers are invalid, respond with a 400 Bad Request status.
      _logError(
        relicRequest,
        'Error parsing request headers.\n$error',
        stackTrace,
      );
      return Response.badRequest(
        body: Body.fromString(error.httpResponseBody),
      ).writeHttpResponse(request.response);
    } on HijackException catch (error, stackTrace) {
      // If the request is already hijacked, meaning it's being handled by
      // another handler, like a websocket, then don't respond with an error.
      if (relicRequest.isHijacked) return;

      _logError(
        relicRequest,
        "Caught HijackException, but the request wasn't hijacked.",
        stackTrace,
      );
      return Response.internalServerError().writeHttpResponse(
        request.response,
      );
    } catch (error, stackTrace) {
      _logError(
        relicRequest,
        'Error thrown by handler.\n$error',
        stackTrace,
      );
      return Response.internalServerError().writeHttpResponse(
        request.response,
      );
    }

    if (relicRequest.isHijacked) {
      throw StateError(
        'The request has been hijacked by another handler (e.g., a WebSocket) '
        'but the HijackException was never thrown. If a request is hijacked '
        'then a HijackException is expected to be thrown.',
      );
    }

    // When writing the response to the HTTP response, if the response headers
    // are invalid, respond with a 400 Bad Request status.
    try {
      return await response.writeHttpResponse(request.response);
    } on InvalidHeaderException catch (error) {
      return Response.badRequest(
        body: Body.fromString(error.toString()),
      ).writeHttpResponse(request.response);
    } catch (error, stackTrace) {
      _logError(
        relicRequest,
        'Error thrown by handler.\n$error',
        stackTrace,
      );
      return Response.internalServerError().writeHttpResponse(
        request.response,
      );
    }
  }
}

void _logError(Request request, String message, StackTrace stackTrace) {
  var buffer = StringBuffer();
  buffer.write('${request.method} ${request.requestedUri.path}');
  if (request.requestedUri.query.isNotEmpty) {
    buffer.write('?${request.requestedUri.query}');
  }
  buffer.writeln();
  buffer.write(message);

  logMessage(
    buffer.toString(),
    stackTrace: stackTrace,
    type: LoggerType.error,
  );
}
