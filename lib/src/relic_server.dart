import 'dart:async';

import 'adapter/adapter.dart';
import 'adapter/context.dart';
import 'body/body.dart';
import 'handler/handler.dart';
import 'headers/exception/header_exception.dart';
import 'headers/standard_headers_extensions.dart';
import 'logger/logger.dart';
import 'message/request.dart';
import 'message/response.dart';
import 'util/util.dart';

/// A server that uses a [Adapter] to handle HTTP requests.
class RelicServer {
  /// The default powered by header to use for responses.
  static const String defaultPoweredByHeader = 'Relic';

  /// The underlying adapter.
  final Adapter adapter;

  /// Whether to enforce strict header parsing.
  final bool strictHeaders;

  /// Whether [mountAndStart] has been called.
  Handler? _handler;

  StreamSubscription<AdapterRequest>? _subscription;

  /// The powered by header to use for responses.
  final String? poweredByHeader;

  /// Creates a server with the given parameters.
  RelicServer(
    this.adapter, {
    this.strictHeaders = false,
    this.poweredByHeader = defaultPoweredByHeader,
  });

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
  Future<void> close() async {
    await _stopListening();
    await adapter.close();
  }

  Future<void> _stopListening() async {
    await _subscription?.cancel();
    _handler = null;
  }

  /// Starts listening for requests.
  Future<void> _startListening() async {
    catchTopLevelErrors(() {
      _subscription = adapter.requests.listen(_handleRequest);
    }, (final error, final stackTrace) {
      logMessage(
        'Asynchronous error\n$error',
        stackTrace: stackTrace,
        type: LoggerType.error,
      );
    });
  }

  Future<void> _handleRequest(final AdapterRequest adapterRequest) async {
    final handler = _handler;
    if (handler == null) return; // if close has been called

    // Wrap the handler with our middleware
    late Request request;
    try {
      request = adapterRequest.toRequest();
    } catch (error, stackTrace) {
      logMessage(
        'Error reading request.\n$error',
        stackTrace: stackTrace,
        type: LoggerType.error,
      );
      await adapter.respond(adapterRequest, Response.badRequest());
      return;
    }

    try {
      final ctx = request
          .toContext(adapterRequest); // adapter request will be the token
      final newCtx = await handler(ctx);
      return switch (newCtx) {
        final ResponseContext rc =>
          adapter.respond(adapterRequest, rc.response),
        final HijackContext hc => adapter.hijack(adapterRequest, hc.callback),
        final ConnectContext cc => adapter.connect(adapterRequest, cc.callback),
      };
    } catch (error, stackTrace) {
      _logError(
        request,
        'Unhandled error in mounted handler.\n$error',
        stackTrace,
      );
      await adapter.respond(adapterRequest, Response.internalServerError());
      return;
    }
  }

  /// Wraps a handler with middleware for error handling, header normalization, etc.
  Handler _wrapHandlerWithMiddleware(final Handler handler) {
    return (final ctx) async {
      try {
        final handledCtx = await handler(ctx);
        return switch (handledCtx) {
          final ResponseContext rc =>
            // If the response doesn't have a powered-by or date header, add the default ones
            rc.respond(
              rc.response.copyWith(headers: rc.response.headers.transform(
                (final mh) {
                  mh.xPoweredBy ??= poweredByHeader;
                  mh.date ??= DateTime.now();
                },
              )),
            ),
          _ => handledCtx,
        };
      } on HeaderException catch (error, stackTrace) {
        // If the request headers are invalid, respond with a 400 Bad Request status.
        _logError(
          ctx.request,
          'Error parsing request headers.\n$error',
          stackTrace,
        );
        return ctx.respond(Response.badRequest(
          body: Body.fromString('Bad Request'),
        ));
      } catch (error, stackTrace) {
        // Catch all other exceptions that might contain sensitive information
        _logError(
          ctx.request,
          'Error in request handler.\n$error',
          stackTrace,
        );
        
        // Check if this looks like a client error (4xx) based on common patterns
        final errorString = error.toString().toLowerCase();
        final isBadRequest = errorString.contains('invalid json') ||
            errorString.contains('json') ||
            errorString.contains('parse') ||
            errorString.contains('format') ||
            errorString.contains('syntax');
            
        if (isBadRequest) {
          return ctx.respond(Response.badRequest(
            body: Body.fromString('Bad Request'),
          ));
        } else {
          return ctx.respond(Response.internalServerError(
            body: Body.fromString('Internal Server Error'),
          ));
        }
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
