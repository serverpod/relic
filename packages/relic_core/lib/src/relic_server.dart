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
import 'middleware/routing_middleware.dart';
import 'router/method.dart';
import 'util/util.dart';
import 'web_socket/framed_web_socket.dart';
import 'web_socket/web_socket_handshake.dart';

sealed class RelicServer {
  /// Mounts a [handler] to the server and starts listening for requests.
  ///
  /// Only one [handler] can be mounted at a time, but it will be replaced
  /// on each call.
  Future<void> mountAndStart(final Handler handler);

  /// Shuts down the server.
  ///
  /// A graceful close, the default, stops accepting, tells every WebSocket
  /// peer the server is going away, and waits for the exchanges in flight,
  /// the hijacked channels and those close handshakes to end. The handshakes
  /// are bounded by their protocol implementations, the rest is the
  /// handlers' own work, so the wait has no deadline of its own. Bound it
  /// with a timeout and a forced close:
  ///
  /// ```dart
  /// await server.close().timeout(grace, onTimeout: () => server.close(force: true));
  /// ```
  ///
  /// A forced close drops every connection at once and ends a graceful
  /// close that is still waiting.
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

  /// The WebSockets handed to handlers, framed here or by the adapter.
  /// The going-away close on shutdown is this server's job for all of them.
  final _sockets = <RelicWebSocket>{};

  /// The raw channels handed to handlers, to close on shutdown.
  final _channels = <StreamChannel<Uint8List>>{};

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
    final adapter = _adapter ?? await _pendingAdapter;
    final closing = [
      for (final socket in _sockets.toList())
        if (!socket.isClosed) socket.closeGoingAway(),
    ];
    // A graceful close waits for the peers' answers to the going-away
    // close, for every hijacked channel to flush what its handler wrote,
    // and for the exchanges in flight. A forced close queues the frames and
    // drops the channels at once, so a frame reaches a peer only when its
    // adapter flushes before it drops.
    if (!force) {
      closing.addAll([
        for (final channel in _channels.toList())
          Future.sync(channel.sink.close),
        adapter.close(),
      ]);
      await _settled(closing);
    }
    await adapter.close(force: true);
  }

  /// Completes when every future in [futures] has, however it did.
  static Future<void> _settled(final List<Future<void>> futures) async {
    await Future.wait([
      for (final future in futures) future.then((_) {}, onError: (_) {}),
    ]);
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
        // A hijacked channel bypasses the server, which then cannot hold
        // the no-content rule for HEAD (RFC 9110 9.3.2). A HEAD route of
        // its own may hijack.
        if (request.isHeadFallback) {
          return exchange.respond(
            Response(
              405,
              headers: Headers.build((final mh) => mh.allow = {Method.get}),
            ),
          );
        }
        return _withChannel(exchange, (final channel) {
          _keep(channel);
          return hijack.callback(channel);
        });
      case final WebSocketUpgrade upgrade:
        // The opening handshake is a GET (RFC 6455 4.1).
        if (request.method != Method.get) {
          return exchange.respond(
            Response(
              405,
              headers: Headers.build((final mh) => mh.allow = {Method.get}),
            ),
          );
        }
        if (!_isOriginAllowed(request, upgrade)) {
          return exchange.respond(Response.forbidden());
        }
        // A request that is not a valid opening handshake (RFC 6455 4.2.1)
        // gets 400 here, so an adapter's upgradeWebSocket never sees one.
        final acceptKey = webSocketAcceptKey(request);
        if (acceptKey == null) {
          return exchange.respond(
            Response.badRequest(
              body: Body.fromString('Not a WebSocket upgrade request'),
            ),
          );
        }
        final capabilities = _adapter!.capabilities;
        if (capabilities.webSocket) {
          final socket = exchange.upgradeWebSocket(acceptKey);
          if (socket is Future<RelicWebSocket>) {
            return socket.then((final socket) => _handOver(socket, upgrade));
          }
          _handOver(socket, upgrade);
          return null;
        }
        if (!capabilities.hijack) {
          return exchange.respond(Response.notImplemented());
        }
        // The RFC 6455 opening handshake on a raw channel, for an adapter
        // with no framer of its own.
        return _withChannel(
          exchange,
          (final channel) => _frame(channel, acceptKey, upgrade),
        );
    }
  }

  /// Hijacks the connection and hands the channel to [use], now or when
  /// the adapter has it.
  static FutureOr<void> _withChannel(
    final AdapterExchange exchange,
    final FutureOr<void> Function(StreamChannel<Uint8List>) use,
  ) {
    final channel = exchange.hijack();
    if (channel is Future<StreamChannel<Uint8List>>) return channel.then(use);
    use(channel);
    return null;
  }

  void _frame(
    final StreamChannel<Uint8List> channel,
    final String acceptKey,
    final WebSocketUpgrade upgrade,
  ) {
    channel.sink.add(webSocketHandshakeResponse(acceptKey));
    _handOver(FramedWebSocket(channel), upgrade);
  }

  /// Keeps [channel] for the close on shutdown until its sink is done.
  void _keep(final StreamChannel<Uint8List> channel) {
    _channels.add(channel);
    unawaited(
      channel.sink.done
          .then((_) {}, onError: (_) {})
          .whenComplete(() => _channels.remove(channel)),
    );
  }

  /// Keeps [socket] for the going-away close until it is done, and gives
  /// it to the handler.
  void _handOver(final RelicWebSocket socket, final WebSocketUpgrade upgrade) {
    _sockets.add(socket);
    unawaited(socket.done.whenComplete(() => _sockets.remove(socket)));
    upgrade.callback(socket);
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
