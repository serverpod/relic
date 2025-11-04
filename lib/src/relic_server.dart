import 'dart:async';

import 'adapter/adapter.dart';
import 'body/body.dart';
import 'context/context.dart';
import 'handler/handler.dart';
import 'headers/exception/header_exception.dart';
import 'headers/standard_headers_extensions.dart';
import 'isolated_object.dart';
import 'logger/logger.dart';
import 'util/util.dart';

sealed class RelicServer {
  /// Mounts a [handler] to the server and starts listening for requests.
  ///
  /// Only one [handler] can be mounted at a time, but it will be replaced
  /// on each call.
  Future<void> mountAndStart(final Handler handler);

  /// Close the server
  Future<void> close();

  /// Returns information about the current connections.
  Future<ConnectionsInfo> connectionsInfo();

  /// The port this server is bound to.
  ///
  /// This will throw a [LateInitializationError], if called before [mountAndStart].
  int get port;

  factory RelicServer(
    final Factory<Adapter> adapterFactory, {
    final int noOfIsolates = 1,
  }) {
    return switch (noOfIsolates) {
      < 1 =>
        throw RangeError.value(
          noOfIsolates,
          'noOfIsolates',
          'Must be larger than 0',
        ),
      == 1 => _RelicServer(adapterFactory),
      _ => _MultiIsolateRelicServer(adapterFactory, noOfIsolates),
    };
  }
}

/// A server that uses a [Adapter] to handle HTTP requests.
final class _RelicServer implements RelicServer {
  final FutureOr<Adapter> _adapter;
  Handler? _handler;
  StreamSubscription<AdapterRequest>? _subscription;

  /// Creates a server with the given parameters.
  _RelicServer(final Factory<Adapter> adapterFactory)
    : _adapter = adapterFactory();

  /// Mounts a handler to the server and starts listening for requests.
  ///
  /// Only one handler can be mounted at a time.
  @override
  Future<void> mountAndStart(final Handler handler) async {
    _port ??= (await _adapter).port;
    _handler = _wrapHandlerWithMiddleware(handler);
    if (_subscription == null) await _startListening();
  }

  @override
  Future<void> close() async {
    await _stopListening();
    await (await _adapter).close();
    _port = null;
  }

  @override
  Future<ConnectionsInfo> connectionsInfo() async {
    final adapter = await _adapter;
    return adapter.connectionsInfo;
  }

  int? _port;
  @override
  int get port => _port ?? (throw StateError('Not bound'));

  Future<void> _stopListening() async {
    await _subscription?.cancel();
    _handler = null;
  }

  /// Starts listening for requests.
  Future<void> _startListening() async {
    final adapter = await _adapter;
    catchTopLevelErrors(
      () {
        _subscription = adapter.requests.listen(_handleRequest);
      },
      (final error, final stackTrace) {
        logMessage(
          'Asynchronous error\n$error',
          stackTrace: stackTrace,
          type: LoggerType.error,
        );
      },
    );
  }

  Future<void> _handleRequest(final AdapterRequest adapterRequest) async {
    final handler = _handler;
    if (handler == null) return; // if close has been called

    final adapter = await _adapter;

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
      final result = await handler(request);
      return switch (result) {
        final Response rc => adapter.respond(adapterRequest, rc),
        final Hijack hc => adapter.hijack(adapterRequest, hc.callback),
        final WebSocketUpgrade cc => adapter.connect(
          adapterRequest,
          cc.callback,
        ),
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
    return (final req) async {
      try {
        final result = await handler(req);
        return switch (result) {
          final Response rc =>
          // If the response doesn't have a date header, add the default one
          rc.copyWith(
            headers: rc.headers.transform((final mh) {
              mh.date ??= DateTime.now();
            }),
          ),
          _ => result,
        };
      } on HeaderException catch (error, stackTrace) {
        // If the request headers are invalid, respond with a 400 Bad Request status.
        _logError(req, 'Error parsing request headers.\n$error', stackTrace);
        return Response.badRequest(
          body: Body.fromString(error.httpResponseBody),
        );
      }
    };
  }
}

void _logError(
  final Request request,
  final String message,
  final StackTrace stackTrace,
) {
  final buffer = StringBuffer();
  buffer.write('${request.method} ${request.requestedUri.path}');
  if (request.requestedUri.query.isNotEmpty) {
    buffer.write('?${request.requestedUri.query}');
  }
  buffer.writeln();
  buffer.write(message);

  logMessage(buffer.toString(), stackTrace: stackTrace, type: LoggerType.error);
}

final class _IsolatedRelicServer extends IsolatedObject<RelicServer>
    implements RelicServer {
  _IsolatedRelicServer(final Factory<Adapter> adapterFactory)
    : super(() => RelicServer(adapterFactory));

  @override
  Future<void> close() async {
    await evaluate((final r) => r.close());
    await super.close();
    _port = null;
  }

  @override
  Future<void> mountAndStart(final Handler handler) async {
    await evaluate((final r) => r.mountAndStart(handler));
    _port ??= await evaluate((final r) => r.port);
  }

  @override
  Future<ConnectionsInfo> connectionsInfo() =>
      evaluate((final r) => r.connectionsInfo());

  int? _port;
  @override
  int get port => _port ?? (throw StateError('Not bound'));
}

final class _MultiIsolateRelicServer implements RelicServer {
  final List<RelicServer> _children;

  _MultiIsolateRelicServer(
    final Factory<Adapter> adapterFactory,
    final int noOfIsolates,
  ) : assert(noOfIsolates > 1),
      _children = List.generate(
        noOfIsolates,
        (_) => _IsolatedRelicServer(adapterFactory),
      );

  @override
  Future<void> close() async {
    await _children.map((final c) => c.close()).wait;
  }

  @override
  Future<void> mountAndStart(final Handler handler) async {
    await _children.map((final c) => c.mountAndStart(handler)).wait;
  }

  @override
  Future<ConnectionsInfo> connectionsInfo() async {
    // fold sum over children
    var acc = (active: 0, closing: 0, idle: 0);
    for (final c in _children) {
      final i = await c.connectionsInfo();
      acc = (
        active: acc.active + i.active,
        closing: acc.closing + i.closing,
        idle: acc.idle + i.idle,
      );
    }
    return acc;
  }

  @override
  int get port => _children.first.port;
}
