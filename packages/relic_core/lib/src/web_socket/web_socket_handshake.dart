import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:relic_headers/relic_headers.dart';

import '../context/result.dart';
import '../headers/exception/header_exception.dart';
import '../headers/standard_headers_extensions.dart';
import '../router/method.dart';
import '../util/http_date.dart';

/// The string RFC 6455 1.3 derives the accept key with.
const _guid = '258EAFA5-E914-47DA-95CA-C5AB0DC85B11';

/// The `Sec-WebSocket-Accept` value for [request], or null when the
/// request is not a WebSocket opening handshake a server can accept
/// (RFC 6455 4.2.1).
///
/// That is a GET with `Upgrade: websocket`, `Connection: Upgrade`, version
/// 13 and a key of 16 base64 bytes.
///
/// `RelicServer` answers a non-GET upgrade with 405 before calling this, so
/// the method check here serves direct callers.
String? webSocketAcceptKey(final Request request) {
  if (request.method != Method.get) return null;
  final headers = request.headers;
  try {
    final upgrade = headers.upgrade;
    if (upgrade == null ||
        !upgrade.protocols.any(
          (final p) => p.protocol.toLowerCase() == 'websocket',
        )) {
      return null;
    }
    final connection = headers.connection;
    if (connection == null || !connection.isUpgrade) return null;
  } on HeaderException {
    return null;
  }
  if (headers.value(HeaderName.secWebsocketVersion)?.trim() != '13') {
    return null;
  }
  final key = headers.value(HeaderName.secWebsocketKey)?.trim();
  if (key == null) return null;
  final Uint8List raw;
  try {
    raw = base64.decode(key);
  } on FormatException {
    return null;
  }
  if (raw.length != 16) return null;
  return base64.encode(sha1.convert(utf8.encode('$key$_guid')).bytes);
}

/// The 101 response that completes the handshake, as bytes for the wire.
Uint8List webSocketHandshakeResponse(final String acceptKey) => utf8.encode(
  'HTTP/1.1 101 Switching Protocols\r\n'
  'Upgrade: websocket\r\n'
  'Connection: Upgrade\r\n'
  'Sec-WebSocket-Accept: $acceptKey\r\n'
  'Date: ${httpDate()}\r\n'
  '\r\n',
);
