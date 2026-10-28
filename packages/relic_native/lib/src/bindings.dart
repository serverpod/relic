@DefaultAsset('package:relic_native/relic_native.dart')
library;

import 'dart:ffi';

/// Mirrors `Options` in src/relic_native.zig.
final class Options extends Struct {
  @Uint32()
  external int reactorCapacity;
  @Uint32()
  external int backlog;
  @Uint32()
  external int maxConnections;
  @Uint64()
  external int maxInlineBody;
  @Uint32()
  external int idleTimeoutMs;
  @Uint32()
  external int headerTimeoutMs;
  @Uint32()
  external int bodyTimeoutMs;
  @Uint32()
  external int writeTimeoutMs;
}

/// Mirrors `TlsPem` in src/relic_native.zig.
final class TlsPem extends Struct {
  external Pointer<Uint8> certificateChain;
  @Size()
  external int certificateChainLen;
  external Pointer<Uint8> privateKey;
  @Size()
  external int privateKeyLen;
}

/// Mirrors `HeaderSlot` in src/relic_native.zig.
final class HeaderSlot extends Struct {
  @Uint32()
  external int nameOff;
  @Int32()
  external int nameId;
  @Uint32()
  external int valueOff;
  @Uint32()
  external int valueLen;
}

/// Mirrors `ExchangeView` in src/relic_native.zig.
///
/// Field order and types must match. The layout test checks the sizes.
final class ExchangeView extends Struct {
  @Uint8()
  external int method;
  @Uint8()
  external int version;
  @Uint8()
  external int keepAlive;
  @Uint8()
  external int remoteFamily;
  @Uint16()
  external int remotePort;
  @Uint16()
  external int localPort;
  @Array(16)
  external Array<Uint8> remoteAddr;
  external Pointer<Uint8> head;
  @Uint32()
  external int headLen;
  @Uint32()
  external int targetOff;
  @Uint32()
  external int targetLen;
  @Uint32()
  external int headerCount;
  external Pointer<HeaderSlot> headers;
  external Pointer<Uint8> body;
  @Uint64()
  external int bodyLen;

  /// Nonzero when the peer went away while the exchange was parked.
  @Uint8()
  external int peerGone;
  @Uint8()
  external int bodyStreamed;

  /// Nonzero when a write of the streamed response failed.
  @Uint8()
  external int writeFailed;
  @Uint32()
  external int chunksWritten;

  /// The connection's write buffer, while it is empty, for a response that
  /// fits in [scratchCap] bytes.
  external Pointer<Uint8> scratch;
  @Uint32()
  external int scratchCap;

  /// The pong frames the native side has received.
  @Uint32()
  external int wsPongs;

  /// Where in the response head the native side stamps the Date value at
  /// send time, 0 when the response carries its own.
  @Uint32()
  external int dateOff;
}

/// Mirrors `Stats` in src/relic_native.zig.
final class Stats extends Struct {
  @Uint32()
  external int active;
  @Uint32()
  external int idle;
  @Uint32()
  external int firstAttached;
}

@Native<IntPtr Function(Pointer<Void>)>(symbol: 'relic_init_dart_api')
external int initDartApi(Pointer<Void> data);

/// The server for [group], bound now or by another isolate before. Null
/// with the reason in [failure], a `BindFailure`, when binding fails.
/// [pem] is null for plain HTTP.
@Native<
  Pointer<Void> Function(
    Pointer<Char>,
    Pointer<Char>,
    Uint16,
    Pointer<Options>,
    Pointer<TlsPem>,
    Pointer<Uint8>,
  )
>(symbol: 'relic_server_bind')
external Pointer<Void> serverBind(
  Pointer<Char> group,
  Pointer<Char> ip,
  int port,
  Pointer<Options> options,
  Pointer<TlsPem> pem,
  Pointer<Uint8> failure,
);

@Native<Uint16 Function(Pointer<Void>)>(symbol: 'relic_server_port')
external int serverPort(Pointer<Void> server);

@Native<Bool Function(Pointer<Void>)>(symbol: 'relic_server_secure')
external bool serverSecure(Pointer<Void> server);

/// The reactor for this isolate, on the calling thread. [port] receives
/// the wake messages. Null when every slot is taken.
@Native<Pointer<Void> Function(Pointer<Void>, Int64)>(
  symbol: 'relic_reactor_create',
)
external Pointer<Void> reactorCreate(Pointer<Void> server, int port);

/// Takes the reactor out of service. It accepts no new connections,
/// closes the idle ones, and closes the rest after their current
/// response. The listener closes with the last accepting reactor of the
/// server.
@Native<Void Function(Pointer<Void>)>(symbol: 'relic_reactor_stop')
external void reactorStop(Pointer<Void> reactor);

/// Cancels the reactor's connections and frees it. The last one of a
/// server stops the server too. Blocks while the connections unwind.
@Native<Void Function(Pointer<Void>)>(symbol: 'relic_reactor_destroy')
external void reactorDestroy(Pointer<Void> reactor);

@Native<Uint32 Function(Pointer<Void>)>(
  symbol: 'relic_reactor_slot',
  isLeaf: true,
)
external int reactorSlot(Pointer<Void> reactor);

/// Runs one pass of the reactor on the calling thread. Its tasks run, its
/// loop polls for at most [waitMs], and up to [max] exchanges ready for a
/// handler land in [out].
@Native<
  Uint32 Function(Pointer<Void>, Uint32, Pointer<Pointer<ExchangeView>>, Uint32)
>(symbol: 'relic_reactor_tick')
external int reactorTick(
  Pointer<Void> reactor,
  int waitMs,
  Pointer<Pointer<ExchangeView>> out,
  int max,
);

/// Whether the last tick left work that the next tick should take at once.
@Native<Bool Function(Pointer<Void>)>(
  symbol: 'relic_reactor_pending',
  isLeaf: true,
)
external bool reactorPending(Pointer<Void> reactor);

/// Up to [max] addresses, in [out], of exchanges with an event since the
/// last call. The low bit marks the last event of a raw connection, whose
/// view must not be read.
@Native<Uint32 Function(Pointer<Void>, Pointer<Size>, Uint32)>(
  symbol: 'relic_reactor_events',
  isLeaf: true,
)
external int reactorEvents(Pointer<Void> reactor, Pointer<Size> out, int max);

/// Arms one wake message for when the loop has events or a timer is due.
@Native<Void Function(Pointer<Void>)>(symbol: 'relic_reactor_wait')
external void reactorWait(Pointer<Void> reactor);

@Native<
  Void Function(
    Pointer<ExchangeView>,
    Pointer<Uint8>,
    Uint32,
    Pointer<Uint8>,
    Uint64,
    Bool,
  )
>(symbol: 'relic_respond', isLeaf: true)
external void respond(
  Pointer<ExchangeView> view,
  Pointer<Uint8> head,
  int headLen,
  Pointer<Uint8> body,
  int bodyLen,
  bool closeAfter,
);

@Native<Void Function(Pointer<ExchangeView>, Uint32, Bool)>(
  symbol: 'relic_respond_inline',
  isLeaf: true,
)
external void respondInline(
  Pointer<ExchangeView> view,
  int length,
  bool closeAfter,
);

@Native<
  Void Function(Pointer<ExchangeView>, Pointer<Uint8>, Uint32, Bool, Bool)
>(symbol: 'relic_respond_stream', isLeaf: true)
external void respondStream(
  Pointer<ExchangeView> view,
  Pointer<Uint8> head,
  int headLen,
  bool closeAfter,
  bool chunked,
);

@Native<Bool Function(Pointer<ExchangeView>, Pointer<Uint8>, Size)>(
  symbol: 'relic_write_chunk',
  isLeaf: true,
)
external bool writeChunk(
  Pointer<ExchangeView> view,
  Pointer<Uint8> data,
  int length,
);

@Native<Void Function(Pointer<ExchangeView>, Bool)>(
  symbol: 'relic_finish_stream',
  isLeaf: true,
)
external void finishStream(Pointer<ExchangeView> view, bool ok);

@Native<
  Uint8 Function(
    Pointer<ExchangeView>,
    Pointer<Pointer<Uint8>>,
    Pointer<Size>,
    Pointer<Uint8>,
  )
>(symbol: 'relic_read_chunk', isLeaf: true)
external int readChunk(
  Pointer<ExchangeView> view,
  Pointer<Pointer<Uint8>> data,
  Pointer<Size> length,
  Pointer<Uint8> status,
);

@Native<Void Function(Pointer<ExchangeView>)>(
  symbol: 'relic_abort',
  isLeaf: true,
)
external void abort(Pointer<ExchangeView> view);

@Native<Void Function(Pointer<ExchangeView>)>(
  symbol: 'relic_watch',
  isLeaf: true,
)
external void watch(Pointer<ExchangeView> view);

/// Takes the connection as a raw byte channel. Bytes from the peer come
/// through [readChunk], bytes to the peer go through [writeChunk], and
/// [finishStream] closes the connection once they are written.
@Native<Void Function(Pointer<ExchangeView>)>(
  symbol: 'relic_hijack',
  isLeaf: true,
)
external void hijack(Pointer<ExchangeView> view);

/// Answers with the 101 [head] and makes the connection a WebSocket. A
/// message over [maxMessage] bytes closes it with 1009.
@Native<Void Function(Pointer<ExchangeView>, Pointer<Uint8>, Uint32, Uint32)>(
  symbol: 'relic_ws_upgrade',
  isLeaf: true,
)
external void wsUpgrade(
  Pointer<ExchangeView> view,
  Pointer<Uint8> head,
  int headLen,
  int maxMessage,
);

/// Queues a frame for the peer, with [data] as its payload. False when
/// the node could not be allocated, and [data] is then still Dart's.
@Native<Bool Function(Pointer<ExchangeView>, Pointer<Uint8>, Size, Uint8)>(
  symbol: 'relic_ws_send',
  isLeaf: true,
)
external bool wsSend(
  Pointer<ExchangeView> view,
  Pointer<Uint8> data,
  int length,
  int opcode,
);

/// Takes the next message from the peer. Returns 0 when none is queued.
@Native<
  Uint8 Function(
    Pointer<ExchangeView>,
    Pointer<Pointer<Uint8>>,
    Pointer<Size>,
    Pointer<Uint8>,
  )
>(symbol: 'relic_ws_read', isLeaf: true)
external int wsRead(
  Pointer<ExchangeView> view,
  Pointer<Pointer<Uint8>> data,
  Pointer<Size> length,
  Pointer<Uint8> kind,
);

@Native<Pointer<Uint8> Function(Size)>(symbol: 'relic_alloc', isLeaf: true)
external Pointer<Uint8> alloc(int length);

@Native<Void Function(Pointer<Uint8>)>(symbol: 'relic_free', isLeaf: true)
external void free(Pointer<Uint8> pointer);

@Native<Void Function(Pointer<Void>, Pointer<Stats>)>(
  symbol: 'relic_server_stats',
)
external void serverStats(Pointer<Void> server, Pointer<Stats> out);
