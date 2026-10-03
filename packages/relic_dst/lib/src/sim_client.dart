import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:relic_core/relic_core.dart';

import 'http1.dart';
import 'sim_network.dart';
import 'simulation.dart';

/// A response as a client read it off the wire.
final class SimResponse {
  final StatusHead head;
  final Uint8List bodyBytes;

  SimResponse(this.head, this.bodyBytes);

  int get statusCode => head.status;
  String get reason => head.reason;
  Map<String, List<String>> get headers => head.headers;
  String? header(final String name) => head.header(name);
  String get body => utf8.decode(bodyBytes);

  @override
  String toString() => 'SimResponse($statusCode, ${bodyBytes.length} bytes)';
}

/// The server answered a WebSocket handshake with something other than
/// 101.
final class WebSocketUpgradeRefused implements Exception {
  final SimResponse response;

  WebSocketUpgradeRefused(this.response);

  @override
  String toString() => 'WebSocket upgrade refused with ${response.statusCode}';
}

/// Bytes off a socket, read on demand.
final class ByteReader {
  final SimSocket socket;
  late final StreamSubscription<Uint8List> _subscription;
  var _buffer = Uint8List(4096);
  var _length = 0;
  var _eof = false;
  Object? _error;
  Completer<void>? _waiting;

  ByteReader(this.socket) {
    _subscription = socket.stream.listen(
      _onData,
      onError: _onError,
      onDone: _onDone,
    );
  }

  /// Bytes received and not yet taken.
  int get buffered => _length;

  /// Whether the peer closed its side, with or without an error.
  bool get isEof => _eof;

  /// The bytes received and not yet taken, as a view.
  Uint8List get buffer => Uint8List.sublistView(_buffer, 0, _length);

  /// Waits for more bytes. True when some arrived, false when the peer
  /// closed. Throws [SimConnectionReset] when it reset.
  Future<bool> more() async {
    if (_eof) {
      if (_error case final error?) throw error;
      return false;
    }
    final before = _length;
    await (_waiting ??= Completer<void>()).future;
    if (_length > before) return true;
    if (_error case final error?) throw error;
    return false;
  }

  /// Takes the first [n] buffered bytes.
  Uint8List take(final int n) {
    final out = _buffer.sublist(0, n);
    consume(n);
    return out;
  }

  /// Drops the first [n] buffered bytes.
  void consume(final int n) {
    if (n == 0) return;
    _buffer.setRange(0, _length - n, _buffer, n);
    _length -= n;
  }

  /// Exactly [n] bytes, or [HttpParseException] when the peer closed first.
  Future<Uint8List> readExactly(final int n) async {
    while (_length < n) {
      if (!await more()) {
        throw HttpParseException(
          0,
          'The connection closed with $_length of $n bytes',
        );
      }
    }
    return take(n);
  }

  /// Everything until the peer closes.
  Future<Uint8List> readToEnd() async {
    while (await more()) {}
    return take(_length);
  }

  /// Waits until [parse] makes something of the buffer. Nothing is
  /// consumed.
  Future<T> readHead<T>(
    final T? Function(Uint8List buffer, int length) parse,
  ) async {
    while (true) {
      final head = parse(_buffer, _length);
      if (head != null) return head;
      if (!await more()) {
        throw const HttpParseException(
          0,
          'The connection closed before the head was complete',
        );
      }
    }
  }

  void _onData(final Uint8List data) {
    final needed = _length + data.length;
    if (needed > _buffer.length) {
      var size = _buffer.length * 2;
      while (size < needed) {
        size *= 2;
      }
      final grown = Uint8List(size);
      grown.setRange(0, _length, _buffer);
      _buffer = grown;
    }
    _buffer.setRange(_length, needed, data);
    _length = needed;
    _wake();
  }

  void _onError(final Object error) {
    _error = error;
    _eof = true;
    _wake();
  }

  void _onDone() {
    _eof = true;
    _wake();
  }

  void _wake() {
    final waiting = _waiting;
    _waiting = null;
    waiting?.complete();
  }

  Future<void> cancel() => _subscription.cancel();
}

/// An HTTP/1.1 client on one connection to a port of a [SimNetwork].
///
/// Requests are written as bytes and responses parsed off the wire, so a
/// scenario sees what a real client would, including a server that
/// closes, rejects or stalls. The connection opens on the first write and
/// stays for keep-alive and pipelining.
final class SimHttpClient {
  final SimNetwork network;
  final int port;
  SimSocket? _socket;
  Future<SimSocket>? _connecting;
  ByteReader? _reader;

  SimHttpClient(this.network, this.port);

  Simulation get sim => network.sim;

  /// The Host sent by default.
  String get host => '${SimNetwork.address}:$port';

  /// The connection, opened on first use. Writes before it opens share
  /// the one being opened.
  Future<SimSocket> get socket {
    if (_socket case final socket?) return Future.value(socket);
    return _connecting ??= network.connect(port).then((final socket) {
      _socket = socket;
      _reader = ByteReader(socket);
      return socket;
    });
  }

  /// The connection's reader. The connection must be open.
  ByteReader get reader =>
      _reader ?? (throw StateError('The client has not connected'));

  /// Whether the connection has opened.
  bool get isConnected => _socket != null;

  /// Writes a request. Nothing is read. A body goes out with its length,
  /// or chunked in pieces of random size when [chunked].
  Future<void> write(
    final Method method,
    final String target, {
    final Map<String, String> headers = const {},
    final List<int>? body,
    final bool chunked = false,
    final bool close = false,
    final HttpProtocol protocol = HttpProtocol.http11,
    final bool omitHost = false,
  }) async {
    final version = protocol == HttpProtocol.http10 ? 'HTTP/1.0' : 'HTTP/1.1';
    final head = StringBuffer('${method.value} $target $version\r\n');
    final hasHost = headers.keys.any((final k) => k.toLowerCase() == 'host');
    if (!omitHost && !hasHost) head.write('host: $host\r\n');
    headers.forEach((final name, final value) {
      head.write('$name: $value\r\n');
    });
    if (body != null && !chunked) {
      head.write('content-length: ${body.length}\r\n');
    }
    if (chunked) head.write('transfer-encoding: chunked\r\n');
    if (close) head.write('connection: close\r\n');
    head.write('\r\n');
    final socket = await this.socket;
    socket.sink.add(Uint8List.fromList(latin1.encode(head.toString())));
    if (body == null) return;
    if (!chunked) {
      socket.sink.add(Uint8List.fromList(body));
      return;
    }
    var offset = 0;
    while (offset < body.length) {
      final size = 1 + sim.random.nextInt(body.length - offset);
      socket.sink.add(
        encodeChunk(Uint8List.fromList(body.sublist(offset, offset + size))),
      );
      offset += size;
    }
    socket.sink.add(lastChunk);
  }

  /// Writes [bytes] as they are, for a request the server should refuse.
  Future<void> writeRaw(final List<int> bytes) async {
    final socket = await this.socket;
    socket.sink.add(Uint8List.fromList(bytes));
  }

  /// Writes [text] as Latin-1, for a request spelled out by hand.
  Future<void> writeText(final String text) => writeRaw(latin1.encode(text));

  /// Sends a request and reads its response.
  Future<SimResponse> send(
    final Method method,
    final String target, {
    final Map<String, String> headers = const {},
    final List<int>? body,
    final bool chunked = false,
    final bool close = false,
    final HttpProtocol protocol = HttpProtocol.http11,
  }) async {
    await write(
      method,
      target,
      headers: headers,
      body: body,
      chunked: chunked,
      close: close,
      protocol: protocol,
    );
    return read(method: method);
  }

  Future<SimResponse> get(
    final String target, {
    final Map<String, String> headers = const {},
    final bool close = false,
  }) => send(Method.get, target, headers: headers, close: close);

  Future<SimResponse> post(
    final String target,
    final List<int> body, {
    final Map<String, String> headers = const {},
    final bool chunked = false,
  }) =>
      send(Method.post, target, headers: headers, body: body, chunked: chunked);

  /// Reads one response, for a request made with [method].
  Future<SimResponse> read({final Method method = Method.get}) async {
    final head = await reader.readHead(parseStatusHead);
    reader.consume(head.length);
    return SimResponse(head, await _readBody(head, method));
  }

  Future<Uint8List> _readBody(
    final StatusHead head,
    final Method method,
  ) async {
    if (!head.hasBody(method)) return Uint8List(0);
    if (head.chunked) {
      final out = BytesBuilder(copy: true);
      final decoder = ChunkedDecoder();
      while (!decoder.isDone) {
        if (reader.buffered == 0 && !await reader.more()) {
          throw const HttpParseException(
            0,
            'The connection closed inside a chunked body',
          );
        }
        final consumed = decoder.feed(
          reader.buffer,
          0,
          reader.buffered,
          out.add,
        );
        reader.consume(consumed);
      }
      return out.takeBytes();
    }
    if (head.contentLength case final length?) {
      return reader.readExactly(length);
    }
    return reader.readToEnd();
  }

  /// Closes the write side. The server sees the FIN after what was
  /// written.
  Future<void> close() => _socket?.sink.close() ?? Future.value();

  /// Resets the connection.
  void destroy() => _socket?.destroy();

  /// Opens a WebSocket on [target] with the RFC 6455 handshake. Throws
  /// [WebSocketUpgradeRefused] when the server answers with anything but
  /// a valid 101.
  Future<SimWebSocketClient> upgrade(
    final String target, {
    final Map<String, String> headers = const {},
    final String? origin,
  }) async {
    final nonce = Uint8List(16);
    for (var i = 0; i < nonce.length; i++) {
      nonce[i] = sim.random.nextInt(256);
    }
    final key = base64.encode(nonce);
    await write(
      Method.get,
      target,
      headers: {
        'upgrade': 'websocket',
        'connection': 'Upgrade',
        'sec-websocket-key': key,
        'sec-websocket-version': '13',
        'origin': ?origin,
        ...headers,
      },
    );
    final head = await reader.readHead(parseStatusHead);
    reader.consume(head.length);
    if (head.status != 101) {
      throw WebSocketUpgradeRefused(
        SimResponse(head, await _readBody(head, Method.get)),
      );
    }
    final expected = base64.encode(
      sha1.convert(utf8.encode('$key$_webSocketGuid')).bytes,
    );
    if (head.header('sec-websocket-accept') != expected) {
      throw const HttpParseException(0, 'A bad Sec-WebSocket-Accept');
    }
    return SimWebSocketClient._(this);
  }
}

const _webSocketGuid = '258EAFA5-E914-47DA-95CA-C5AB0DC85B11';

/// The client end of a WebSocket, frame by frame.
///
/// Frames out are masked, as RFC 6455 5.3 requires of a client, with mask
/// keys from the simulation's random. Frames in are the server's, read
/// off the connection's [ByteReader].
final class SimWebSocketClient {
  final SimHttpClient _client;

  SimWebSocketClient._(this._client);

  ByteReader get _reader => _client.reader;

  /// The server's frames until the connection ends.
  Stream<WebSocketFrame> get frames async* {
    while (true) {
      final frame = await readFrame();
      if (frame == null) return;
      yield frame;
    }
  }

  /// The next frame, or null when the server closed the connection.
  Future<WebSocketFrame?> readFrame() async {
    final reader = _reader;
    while (true) {
      final parsed = _parseFrame(reader.buffer);
      if (parsed case (final frame, final length)) {
        reader.consume(length);
        return frame;
      }
      if (!await reader.more()) {
        if (reader.buffered > 0) {
          throw const HttpParseException(0, 'A partial frame at the end');
        }
        return null;
      }
    }
  }

  void send(
    final WebSocketOpcode opcode,
    final List<int> payload, {
    final bool fin = true,
  }) {
    final socket = _client._socket!;
    if (!socket.isOpen) return;
    socket.sink.add(_maskedFrame(opcode, payload, fin));
  }

  void sendText(final String text) =>
      send(WebSocketOpcode.text, utf8.encode(text));

  void sendBytes(final Uint8List bytes) => send(WebSocketOpcode.binary, bytes);

  void ping([final List<int> payload = const []]) =>
      send(WebSocketOpcode.ping, payload);

  void pong([final List<int> payload = const []]) =>
      send(WebSocketOpcode.pong, payload);

  /// Sends a close frame. The server answers with its own and closes.
  void close([final int? code, final String reason = '']) =>
      send(WebSocketOpcode.close, encodeClosePayload(code, reason));

  /// Closes the connection's write side without a close frame.
  Future<void> closeSocket() => _client.close();

  /// Resets the connection.
  void destroy() => _client.destroy();

  Uint8List _maskedFrame(
    final WebSocketOpcode opcode,
    final List<int> payload,
    final bool fin,
  ) {
    final length = payload.length;
    final extra = length < 126
        ? 0
        : length <= 0xffff
        ? 2
        : 8;
    final frame = Uint8List(2 + extra + 4 + length);
    frame[0] = (fin ? 0x80 : 0) | opcode.code;
    frame[1] =
        0x80 |
        (extra == 0
            ? length
            : extra == 2
            ? 126
            : 127);
    if (extra == 2) {
      frame[2] = length >> 8;
      frame[3] = length & 0xff;
    } else if (extra == 8) {
      var n = length;
      for (var i = 9; i >= 2; i--) {
        frame[i] = n & 0xff;
        n >>= 8;
      }
    }
    final maskAt = 2 + extra;
    for (var k = 0; k < 4; k++) {
      frame[maskAt + k] = _client.sim.random.nextInt(256);
    }
    for (var i = 0; i < length; i++) {
      frame[maskAt + 4 + i] = payload[i] ^ frame[maskAt + (i & 3)];
    }
    return frame;
  }

  /// A server frame at the start of [bytes] and its length, or null when
  /// it is not all there.
  static (WebSocketFrame, int)? _parseFrame(final Uint8List bytes) {
    if (bytes.length < 2) return null;
    final fin = bytes[0] & 0x80 != 0;
    final opcode = WebSocketOpcode.fromCode(bytes[0] & 0x0f);
    if (opcode == null || bytes[0] & 0x70 != 0) {
      throw const HttpParseException(0, 'A bad frame header');
    }
    if (bytes[1] & 0x80 != 0) {
      throw const HttpParseException(0, 'A server frame is not masked');
    }
    var length = bytes[1] & 0x7f;
    var at = 2;
    if (length == 126) {
      if (bytes.length < 4) return null;
      length = (bytes[2] << 8) | bytes[3];
      at = 4;
    } else if (length == 127) {
      if (bytes.length < 10) return null;
      length = 0;
      for (var i = 2; i < 10; i++) {
        length = (length << 8) | bytes[i];
      }
      at = 10;
    }
    if (bytes.length < at + length) return null;
    return (
      WebSocketFrame(opcode, bytes.sublist(at, at + length), fin: fin),
      at + length,
    );
  }
}
