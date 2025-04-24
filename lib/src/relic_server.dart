import 'dart:async';

import 'adaptor/adaptor.dart';
import 'body/body.dart';
import 'handler/handler.dart';
import 'headers/exception/header_exception.dart';
import 'headers/standard_headers_extensions.dart';
import 'logger/logger.dart';
import 'message/request.dart';
import 'message/response.dart';
import 'util/util.dart';

/// A server that uses a [Adaptor] to handle HTTP requests.
class RelicServer {
  /// The default powered by header to use for responses.
  static const String defaultPoweredByHeader = 'Relic';

  /// The underlying adaptor.
  final Adaptor adaptor;

  /// Whether to enforce strict header parsing.
  final bool strictHeaders;

  /// Whether [mountAndStart] has been called.
  Handler? _handler;

  StreamSubscription<RequestContext>? _subscription;

  /// The powered by header to use for responses.
  final String poweredByHeader;

  /// Creates a server with the given parameters.
  RelicServer(
    this.adaptor, {
    this.strictHeaders = false,
    final String? poweredByHeader,
  }) : poweredByHeader = poweredByHeader ?? defaultPoweredByHeader;

  /// Mounts a handler to the server and starts listening for requests.
  ///
  /// Only one handler can be mounted at a time.
  Future<void> mountAndStart(final Handler handler) async {
    if (_handler != null) {
      throw StateError(
        'Relic server already has a handler mounted.',
      );
    }
    _handler = _wrapHandlerWithMiddleware(handler);
    await _startListening();
  }

  /// Close the server
  Future<void> close() async => await _subscription?.cancel();

  /// Starts listening for requests.
  Future<void> _startListening() async {
    catchTopLevelErrors(() {
      _subscription = adaptor.requests.listen(_handleRequest);
    }, (final error, final stackTrace) {
      logMessage(
        'Asynchronous error\n$error',
        stackTrace: stackTrace,
        type: LoggerType.error,
      );
    });
  }

  Future<void> _handleRequest(final RequestContext requestContext) async {
    // Wrap the handler with our middleware
    late Request request;
    try {
      request = requestContext.request;
    } catch (_) {
      await requestContext.respond(Response.badRequest());
      return;
    }

    Response? response;
    try {
      response = await _handler!(request);
    } on HijackException {
      // If the request is already hijacked, meaning it's being handled by
      // another handler, like a websocket, then don't respond with an error.
      if (request.isHijacked) return;
    } catch (_) {} // squash all an report internal error

    if (response == null) {
      await requestContext.respond(Response.internalServerError());
      return;
    }

    if (request.isHijacked) {
      throw StateError(
        'The request has been hijacked by another handler (e.g., a WebSocket) '
        'but the HijackException was never thrown. If a request is hijacked '
        'then a HijackException is expected to be thrown.',
      );
    }

    await requestContext.respond(response);
  }

  /// Wraps a handler with middleware for error handling, header normalization, etc.
  Handler _wrapHandlerWithMiddleware(final Handler handler) {
    return (final request) async {
      Response? response;
      try {
        response = await handler(request);

        // If the response doesn't have a powered-by or date header, add the default ones
        response = response.copyWith(
          headers: response.headers.transform((final mh) {
            mh.xPoweredBy ??= poweredByHeader;
            mh.date ??= DateTime.now();
          }),
        );

        return response;
      } on HijackException {
        rethrow;
      } on HeaderException catch (error, stackTrace) {
        // If the request headers are invalid, respond with a 400 Bad Request status.
        _logError(
          request,
          'Error parsing request headers.\n$error',
          stackTrace,
        );
        return Response.badRequest(
          body: Body.fromString(error.httpResponseBody),
        );
      } catch (error, stackTrace) {
        _logError(
          request,
          'Error thrown by handler.\n$error',
          stackTrace,
        );
        return Response.internalServerError();
      }
    };
  }
}

void _logError(
    final Request request, final String message, final StackTrace stackTrace) {
  final buffer = StringBuffer();
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
