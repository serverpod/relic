import 'dart:async';

import 'adapter/adapter.dart';
import 'adapter/context.dart';
import 'body/body.dart';
import 'handler/handler.dart';
import 'headers/exception/header_exception.dart';
import 'headers/standard_headers_extensions.dart';
import 'isolated_object.dart';
import 'logger/logger.dart';
import 'message/request.dart';
import 'message/response.dart';
import 'util/util.dart';

sealed class RelicServer {
  Adapter get adapter;

  Future<void> mountAndStart(final Handler handler);
  Future<void> close();

  factory RelicServer(final Adapter adapter) = _RelicServer;
}

/// A server that uses a [Adapter] to handle HTTP requests.
final class _RelicServer implements RelicServer {
  /// The underlying adapter.
  @override
  final Adapter adapter;

  /// Whether [mountAndStart] has been called.
  Handler? _handler;

  StreamSubscription<AdapterRequest>? _subscription;

  /// Creates a server with the given parameters.
  _RelicServer(this.adapter);

  /// Mounts a handler to the server and starts listening for requests.
  ///
  /// Only one handler can be mounted at a time.
  @override
  Future<void> mountAndStart(final Handler handler) async {
    _handler = _wrapHandlerWithMiddleware(handler);
    if (_subscription == null) await _startListening();
  }

  /// Close the server
  @override
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
            // If the response doesn't have a date header, add the default one
            rc.respond(
              rc.response.copyWith(headers: rc.response.headers.transform(
                (final mh) {
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
          body: Body.fromString(error.httpResponseBody),
        ));
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

final class IsolatedRelicServer extends IsolatedObject<RelicServer>
    implements RelicServer {
  IsolatedRelicServer(final Factory<Adapter> adaptorFactory)
      : super(() async => RelicServer(await adaptorFactory()));

  @override
  Adapter get adapter => throw UnimplementedError();

  @override
  Future<void> close() async {
    await evaluateVoid((final r) => r.close());
    await super.close();
  }

  @override
  Future<void> mountAndStart(final Handler handler) =>
      evaluateVoid((final r) => r.mountAndStart(handler));
}

final class MultiIsolateRelicServer implements RelicServer {
  @override
  Adapter get adapter => throw UnimplementedError();

  final List<RelicServer> _children;

  MultiIsolateRelicServer(final Factory<Adapter> adapterFactory,
      [final int noOfIsolates = 1])
      : _children = List.generate(
            noOfIsolates, (final _) => IsolatedRelicServer(adapterFactory));

  @override
  Future<void> close() async {
    await _children.map((final c) => c.close()).wait;
  }

  @override
  Future<void> mountAndStart(final Handler handler) async {
    await _children.map((final c) => c.mountAndStart(handler)).wait;
  }
}
