import 'dart:convert';
import 'dart:typed_data';

import 'package:relic_headers/relic_headers.dart';

import '../context/result.dart';
import '../headers/headers.dart';
import '../util/http_date.dart';
import 'response_framing.dart';

/// The status line and header block of a response, sized before it is
/// written so the caller can put it straight into the buffer the native
/// side takes over.
///
/// The response's headers go out except the ones a [ResponseFraming]
/// decides. The framing's own follow: the type, the date, the length or
/// the codings, and `Connection: close` when the connection closes after
/// the response and the response does not say so itself (RFC 9112 9.6).
final class ResponseHead {
  final Uint8List _statusLine;
  final Headers _headers;
  final ResponseFraming _framing;
  final String? _transferEncoding;

  /// The cached `date: <value>\r\n` line when the framing's date is the
  /// cached value. Null otherwise, and [writeTo] encodes the date from its
  /// string.
  final Uint8List? _dateLine;
  final bool _announceClose;

  /// An upper bound on the bytes [writeTo] produces.
  final int bound;

  factory ResponseHead(final Response response, final ResponseFraming framing) {
    final headers = response.headers;
    final statusLine = _statusLineFor(response.statusCode);
    final transferEncoding = framing.transferEncoding?.join(', ');
    var bound = statusLine.length + 2;
    for (final name in headers.names) {
      for (final value in headers.values(name)) {
        bound += name.lower.length + value.length + 4;
      }
    }
    if (framing.contentType case final contentType?) {
      bound += 'content-type: '.length + contentType.length + 2;
    }
    Uint8List? dateLine;
    if (framing.date case final date?) {
      if (identical(date, httpDate())) dateLine = httpDateLine();
      bound += 'date: '.length + date.length + 2;
    }
    if (transferEncoding != null) {
      bound += 'transfer-encoding: '.length + transferEncoding.length + 2;
    }
    bound += 'content-length: '.length + _maxContentLengthDigits + 2;
    // A handler that set Connection has said what it wants there.
    final announceClose =
        framing.closeAfter && !headers.contains(HeaderName.connection);
    if (announceClose) bound += 'connection: close'.length + 2;
    return ResponseHead._(
      statusLine,
      headers,
      framing,
      transferEncoding,
      dateLine,
      announceClose,
      bound,
    );
  }

  ResponseHead._(
    this._statusLine,
    this._headers,
    this._framing,
    this._transferEncoding,
    this._dateLine,
    this._announceClose,
    this.bound,
  );

  /// Writes the head into [out], which holds at least [bound] bytes, and
  /// returns how many bytes it took.
  int writeTo(final Uint8List out) {
    out.setRange(0, _statusLine.length, _statusLine);
    var off = _statusLine.length;
    for (final name in _headers.names) {
      if (ResponseFraming.isFramingHeader(name)) continue;
      for (final value in _headers.values(name)) {
        off = _field(out, off, name.lower, value);
      }
    }
    if (_framing.contentType case final contentType?) {
      off = _field(out, off, 'content-type', contentType);
    }
    if (_dateLine case final dateLine?) {
      out.setRange(off, off + dateLine.length, dateLine);
      off += dateLine.length;
    } else if (_framing.date case final date?) {
      off = _field(out, off, 'date', date);
    }
    if (_framing.contentLength case final contentLength?) {
      off = _latin1(out, off, 'content-length: ');
      off = _digits(out, off, contentLength);
      off = _crlf(out, off);
    }
    if (_transferEncoding case final transferEncoding?) {
      off = _field(out, off, 'transfer-encoding', transferEncoding);
    }
    if (_announceClose) off = _field(out, off, 'connection', 'close');
    return _crlf(out, off);
  }
}

/// The head of [response] as bytes, framed by [framing], for an adapter
/// that writes it from its own buffer.
Uint8List encodeResponseHead(
  final Response response,
  final ResponseFraming framing,
) {
  final head = ResponseHead(response, framing);
  final out = Uint8List(head.bound);
  return Uint8List.sublistView(out, 0, head.writeTo(out));
}

int _field(
  final Uint8List out,
  final int off,
  final String name,
  final String value,
) {
  var at = _latin1(out, off, name);
  out[at++] = 0x3a;
  out[at++] = 0x20;
  at = _latin1(out, at, value);
  return _crlf(out, at);
}

int _crlf(final Uint8List out, final int off) {
  out[off] = 0x0d;
  out[off + 1] = 0x0a;
  return off + 2;
}

/// One byte per character, as the Latin-1 encoder produces, and the same
/// rejection of anything beyond it.
int _latin1(final Uint8List out, final int off, final String s) {
  for (var i = 0; i < s.length; i++) {
    final c = s.codeUnitAt(i);
    if (c > 0xff) {
      throw ArgumentError.value(s, 'value', 'Contains a non-Latin-1 character');
    }
    out[off + i] = c;
  }
  return off + s.length;
}

int _digits(final Uint8List out, final int off, final int n) {
  if (n == 0) {
    out[off] = 0x30;
    return off + 1;
  }
  var digits = 0;
  for (var v = n; v > 0; v ~/= 10) {
    digits++;
  }
  var v = n;
  for (var i = off + digits - 1; i >= off; i--) {
    out[i] = 0x30 + v % 10;
    v ~/= 10;
  }
  return off + digits;
}

/// The digits of the largest content length, 2^63 - 1.
const _maxContentLengthDigits = 19;

/// The status lines by status, each built on first use.
final _statusLines = List<Uint8List?>.filled(600, null);

Uint8List _statusLineFor(final int status) {
  // Always answered as HTTP/1.1, as dart:io does. A 1.0 client understands
  // it, and keep-alive follows the request, not the version here.
  if (status < 100 || status >= 600) return _statusLine(status);
  return _statusLines[status] ??= _statusLine(status);
}

Uint8List _statusLine(final int status) =>
    latin1.encode('HTTP/1.1 $status ${_reason(status)}\r\n');

String _reason(final int status) => switch (status) {
  100 => 'Continue',
  101 => 'Switching Protocols',
  200 => 'OK',
  201 => 'Created',
  202 => 'Accepted',
  204 => 'No Content',
  206 => 'Partial Content',
  301 => 'Moved Permanently',
  302 => 'Found',
  303 => 'See Other',
  304 => 'Not Modified',
  307 => 'Temporary Redirect',
  308 => 'Permanent Redirect',
  400 => 'Bad Request',
  401 => 'Unauthorized',
  403 => 'Forbidden',
  404 => 'Not Found',
  405 => 'Method Not Allowed',
  406 => 'Not Acceptable',
  408 => 'Request Timeout',
  409 => 'Conflict',
  410 => 'Gone',
  411 => 'Length Required',
  412 => 'Precondition Failed',
  413 => 'Content Too Large',
  414 => 'URI Too Long',
  415 => 'Unsupported Media Type',
  416 => 'Range Not Satisfiable',
  417 => 'Expectation Failed',
  422 => 'Unprocessable Content',
  426 => 'Upgrade Required',
  429 => 'Too Many Requests',
  431 => 'Request Header Fields Too Large',
  500 => 'Internal Server Error',
  501 => 'Not Implemented',
  502 => 'Bad Gateway',
  503 => 'Service Unavailable',
  504 => 'Gateway Timeout',
  505 => 'HTTP Version Not Supported',
  _ => '',
};
