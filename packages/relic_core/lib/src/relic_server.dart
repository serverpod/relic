import 'dart:async';
import 'dart:typed_data';

import 'package:stream_channel/stream_channel.dart';

import 'adapter/adapter.dart';
import 'adapter/relic_web_socket.dart';
import 'body/body.dart';
import 'context/result.dart';
import 'form/form_data.dart';
import 'handler/handler.dart';
import 'headers/exception/header_exception.dart';
import 'headers/headers.dart';
import 'headers/standard_headers_extensions.dart';
import 'headers/typed/headers/connection_header.dart';
import 'isolated_object.dart';
import 'logger/logger.dart';
import 'util/util.dart';

sealed class RelicServer {
  /// Mounts a [handler] to the server and starts listening for requests.
  ///
  /// Only one [handler] can be mounted at a time, but it will be replaced
  /// on each call.
  Future<void> mountAndStart(final Handler handler);

  /// Shuts down the server.
  ///
  /// If [force] is `false` (the default), the server will wait for all
  /// in-flight requests to complete before closing. If [force] is `true`,
  /// the server will immediately close and forcefully terminate any
  /// remaining connections.
  Future<void> close({final bool force = false});

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
      < 1 => throw RangeError.value(
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
  final FutureOr<Adapter> _pendingAdapter;

  /// Resolved once, in [mountAndStart]. Every request after that reads the
  /// field, so the dispatch path never awaits the adapter.
  Adapter? _adapter;
  Handler? _handler;
  bool _started = false;

  /// Creates a server with the given parameters.
  _RelicServer(final Factory<Adapter> adapterFactory)
    : _pendingAdapter = adapterFactory();

  /// Mounts a handler to the server and starts listening for requests.
  ///
  /// Only one handler can be mounted at a time.
  @override
  Future<void> mountAndStart(final Handler handler) async {
    final adapter = _adapter ??= await _pendingAdapter;
    _handler = handler;
    if (_started) return;
    _started = true;
    // One guarded zone for the errors that escape from `unawaited` work in
    // handlers. Per-request zones would put every dispatch through a zone
    // hop, and the sync path must stay free of that.
    catchTopLevelErrors(() => adapter.start(_handle), (
      final error,
      final stackTrace,
    ) {
      logMessage(
        'Asynchronous error\n$error',
        stackTrace: stackTrace,
        type: LoggerType.error,
      );
    });
  }

  @override
  Future<void> close({final bool force = false}) async {
    _handler = null;
    await (_adapter ?? await _pendingAdapter).close(force: force);
  }

  @override
  Future<ConnectionsInfo> connectionsInfo() async {
    final adapter = _adapter ?? await _pendingAdapter;
    return adapter.connectionsInfo;
  }

  @override
  int get port =>
      _adapter?.listeners.first.port ?? (throw StateError('Not bound'));

  /// Never throws synchronously and never returns a failed Future. The
  /// caller is the adapter, and for a native adapter that is an FFI-driven
  /// drain loop with nowhere to put an exception.
  ///
  /// A sync handler with a sync `respond` completes without a single
  /// await. `await` always suspends, even on a non-Future, so the sync path
  /// branches on `is Future` instead.
  FutureOr<void> _handle(final AdapterExchange exchange) {
    final handler = _handler;
    if (handler == null) {
      // Closing. The adapter stops calling once its own close completes.
      exchange.abort();
      return null;
    }

    final Request request;
    try {
      request = exchange.toRequest();
    } catch (error, stackTrace) {
      logMessage(
        'Error reading request.\n$error',
        stackTrace: stackTrace,
        type: LoggerType.error,
      );
      return _respondOrAbort(exchange, Response.badRequest());
    }

    final FutureOr<Result> result;
    try {
      result = handler(request);
    } catch (error, stackTrace) {
      return _fail(exchange, request, error, stackTrace);
    }
    if (result is Future<Result>) {
      return _handleAsync(exchange, request, result);
    }
    try {
      return _guard(exchange, request, _dispatch(exchange, request, result));
    } catch (error, stackTrace) {
      return _fail(exchange, request, error, stackTrace);
    }
  }

  Future<void> _handleAsync(
    final AdapterExchange exchange,
    final Request request,
    final Future<Result> pending,
  ) async {
    try {
      await _dispatch(exchange, request, await pending);
    } catch (error, stackTrace) {
      await _fail(exchange, request, error, stackTrace);
    }
  }

  /// Routes a failure from a Future returned by `_dispatch` into `_fail`.
  FutureOr<void> _guard(
    final AdapterExchange exchange,
    final Request request,
    final FutureOr<void> pending,
  ) {
    if (pending is Future<void>) {
      return pending.catchError(
        (final Object error, final StackTrace stackTrace) =>
            _fail(exchange, request, error, stackTrace),
      );
    }
    return pending;
  }

  FutureOr<void> _dispatch(
    final AdapterExchange exchange,
    final Request request,
    final Result result,
  ) {
    switch (result) {
      case final Response response:
        return exchange.respond(response);
      case final Hijack hijack:
        final channel = exchange.hijack();
        if (channel is Future<StreamChannel<Uint8List>>) {
          return channel.then(hijack.callback);
        }
        hijack.callback(channel);
        return null;
      case final WebSocketUpgrade upgrade:
        if (!_isOriginAllowed(request, upgrade)) {
          return exchange.respond(Response.forbidden());
        }
        final socket = exchange.upgradeWebSocket();
        if (socket is Future<RelicWebSocket>) {
          return socket.then(upgrade.callback);
        }
        upgrade.callback(socket);
        return null;
    }
  }

  /// The last line of defence. Maps the exceptions handlers are allowed to
  /// let through to their status, logs the rest as a 500, and falls back to
  /// [AdapterExchange.abort] when even the error response cannot be sent,
  /// for example because a streaming response already sent its headers.
  /// Must not throw.
  FutureOr<void> _fail(
    final AdapterExchange exchange,
    final Request request,
    final Object error,
    final StackTrace stackTrace,
  ) {
    final Response response;
    switch (error) {
      case final HeaderException e:
        _logError(request, 'Error parsing request headers.\n$e', stackTrace);
        response = Response.badRequest(
          body: Body.fromString(e.httpResponseBody),
        );
      case final FormException e:
        _logError(request, 'Error handling form data.\n$e', stackTrace);
        response = Response(
          e.statusCode,
          headers: switch (e) {
            UnsupportedFormMediaTypeException() ||
            MalformedFormDataException() ||
            FormLimitExceededException() => Headers.build(
              (final mh) => mh.connection = const ConnectionHeader.directives([
                ConnectionHeaderType.close,
              ]),
            ),
            // Form accessors throw these after parsing has read the whole body.
            MissingFormFieldException() || InvalidFormFieldException() => null,
          },
          body: Body.fromString(e.message),
        );
      case final MaxBodySizeExceeded e:
        _logError(request, 'Error handling request.\n$e', stackTrace);
        response = Response.contentTooLarge();
      default:
        _logError(
          request,
          'Unhandled error in mounted handler.\n$error',
          stackTrace,
        );
        response = Response.internalServerError();
    }
    return _respondOrAbort(exchange, response);
  }

  static FutureOr<void> _respondOrAbort(
    final AdapterExchange exchange,
    final Response response,
  ) {
    try {
      final pending = exchange.respond(response);
      if (pending is Future<void>) {
        return pending.catchError((final Object _) => exchange.abort());
      }
      return pending;
    } catch (_) {
      exchange.abort();
      return null;
    }
  }

  /// Whether [upgrade] may proceed for [request].
  ///
  /// Compares the host of `Origin` against the host the request was addressed
  /// to. Only the host is compared: a proxy terminating TLS changes both the
  /// scheme and the port the server observes, so comparing those would refuse
  /// ordinary same-site traffic. The host is what differs in the attack.
  ///
  /// A request without `Origin` is allowed, since non-browser clients do not
  /// send one.
  static bool _isOriginAllowed(
    final Request request,
    final WebSocketUpgrade upgrade,
  ) {
    if (upgrade.allowAnyOrigin) return true;
    final Uri? origin;
    try {
      origin = request.headers.origin;
    } on Exception {
      return false;
    }
    if (origin == null) return true;
    return origin.host.toLowerCase() == request.url.host.toLowerCase();
  }
}

void _logError(
  final Request request,
  final String message,
  final StackTrace stackTrace,
) {
  final buffer = StringBuffer();
  buffer.write('${request.method} ${request.url.path}');
  if (request.url.query.isNotEmpty) {
    buffer.write('?${request.url.query}');
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
  Future<void> close({final bool force = false}) async {
    await evaluate((final r) => r.close(force: force));
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
  Future<void> close({final bool force = false}) async {
    final children = List.of(_children);
    _children.clear();
    await children.map((final c) => c.close(force: force)).wait;
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
