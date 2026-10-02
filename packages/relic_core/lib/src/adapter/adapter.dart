import 'dart:async';
import 'dart:typed_data';

import 'package:stream_channel/stream_channel.dart';

import '../context/result.dart';
import 'relic_web_socket.dart';

/// A callback function that handles a hijacked connection.
///
/// Hijacking allows low-level control of an HTTP connection, bypassing the normal
/// request-response lifecycle. This is often used for advanced use cases such as
/// upgrading the connection to WebSocket, custom streaming protocols, or raw data
/// processing.
///
/// Once a connection is hijacked, the server stops managing it, and the developer
/// gains direct access to the underlying socket or data stream.
typedef HijackCallback = void Function(StreamChannel<Uint8List>);

/// The function an [Adapter] hands every exchange to.
///
/// [Adapter.start] installs it once. The adapter calls it on the isolate
/// that called `start`. A non-Future return means the call handled the
/// exchange fully. The sink never throws and never returns a failed Future.
typedef ExchangeSink = FutureOr<void> Function(AdapterExchange exchange);

/// The HTTP version an exchange was received with.
enum HttpProtocol { http10, http11, h2, h3 }

/// The transport a [Listener] accepts connections on.
enum Transport { tcp, udp, unix }

/// One bound socket of an [Adapter].
///
/// An h1 plus h3 server has a TCP and a UDP listener.
final class Listener {
  final Transport transport;

  /// The bound address as text.
  ///
  /// Not an `InternetAddress`, so relic_core stays free of `dart:io`.
  final String host;
  final int port;
  final Set<HttpProtocol> protocols;

  const Listener(this.transport, this.host, this.port, this.protocols);
}

/// What an [Adapter] can do beyond a plain request and response.
final class AdapterCapabilities {
  /// Whether the adapter can hand a connection over as a raw byte stream.
  ///
  /// Only meaningful for h1. h2 and h3 have no socket per exchange.
  final bool hijack;

  /// Whether the adapter performs the WebSocket upgrade itself (h1 Upgrade,
  /// h2 RFC 8441, h3 RFC 9220).
  ///
  /// Otherwise the core frames over [hijack].
  final bool webSocket;

  const AdapterCapabilities({this.hijack = false, this.webSocket = false});
}

/// How an exchange finished.
enum ExchangeEnd { completed, upgraded, hijacked, aborted, cancelledByPeer }

/// An interface for adapters that bridge Relic to specific server implementations.
///
/// An adapter accepts connections from a source (an HTTP server, a message
/// queue), wraps each request in an [AdapterExchange] and hands it to the
/// [ExchangeSink] that [start] installed. The exchange carries the response
/// side too, so the adapter never sees a [Response] out of context.
abstract interface class Adapter {
  AdapterCapabilities get capabilities;

  /// The sockets this adapter is bound to.
  List<Listener> get listeners;

  /// Begins accepting connections.
  ///
  /// The server calls this exactly once. The adapter must call [sink] for
  /// every exchange, on the isolate that called [start], and never after
  /// [close] has completed.
  void start(ExchangeSink sink);

  /// Shuts down the adapter.
  ///
  /// This method should release any resources held by the adapter, such as
  /// closing server sockets or stopping listening for incoming requests.
  /// It ensures a clean termination of the adapter's operations.
  ///
  /// If [force] is `false` (the default), the adapter will wait for all
  /// in-flight requests to complete before closing. If [force] is `true`,
  /// the adapter will immediately close and forcefully terminate any
  /// remaining connections.
  ///
  /// For example, for an HTTP server adapter, this might close the underlying
  /// server socket.
  Future<void> close({bool force = false});

  ConnectionsInfo get connectionsInfo;
}

/// One request and its response.
///
/// An h1 request now, an h2 or h3 stream later. The core calls one of
/// [respond], [hijack], [upgradeWebSocket] and [abort]. When that call
/// fails it calls [respond] with an error response, and [abort] when that
/// fails too. The adapter may release everything it holds for the exchange
/// once [done] completes.
abstract interface class AdapterExchange {
  HttpProtocol get protocol;

  /// Converts the adapter's request into a [Request].
  ///
  /// May throw, for example on a malformed target. The core answers that
  /// with 400.
  Request toRequest();

  /// Sends [response].
  ///
  /// Returns synchronously when the call handed the whole response to the
  /// transport. Otherwise completes when the transport has accepted the
  /// body, which is not the same as the peer acknowledging it. See [done]
  /// for that. Fails when the connection is lost or the exchange is aborted
  /// while the body streams, where the transport reports it. dart:io does
  /// not, and completes.
  FutureOr<void> respond(Response response);

  /// Takes over the raw byte stream of the connection, from the end of
  /// the request on.
  ///
  /// Throws [UnsupportedError] unless [AdapterCapabilities.hijack]. Throws
  /// [StateError] when a request body the adapter decoded off the wire, a
  /// chunked one at the least, was not read to its end, since the decoded
  /// bytes cannot go back. The core answers the latter with 500.
  FutureOr<StreamChannel<Uint8List>> hijack();

  /// Performs the WebSocket handshake and hands back the socket.
  ///
  /// Throws [UnsupportedError] unless [AdapterCapabilities.webSocket].
  FutureOr<RelicWebSocket> upgradeWebSocket();

  /// Drops the exchange without a response.
  ///
  /// RST_STREAM or RESET_STREAM for h2 and h3, connection close for h1.
  /// Never throws.
  void abort();

  /// Completes when the peer went away or reset the stream before the
  /// response finished.
  ///
  /// Handlers can use this to cancel work. An adapter completes it when its
  /// transport reports the peer. dart:io does so only as a failed write, so
  /// there it is best effort.
  Future<void> get cancelled;

  /// Completes when the exchange has fully finished: body flushed, upgraded,
  /// hijacked, aborted, or cancelled by the peer.
  Future<ExchangeEnd> get done;
}

typedef ConnectionsInfo = ({int active, int closing, int idle});
