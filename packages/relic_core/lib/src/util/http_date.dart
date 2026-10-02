import 'dart:convert';
import 'dart:typed_data';

import 'package:http_parser/http_parser.dart' as parser;

final _clock = Stopwatch()..start();
var _refreshAtMs = -1;
var _value = '';
var _line = Uint8List(0);

/// The Date header value for now, an RFC 9110 5.6.7 IMF-fixdate.
///
/// A stopwatch decides when to read the wall clock, once per second at the
/// second boundary. A response pays a stopwatch read, not a clock read and
/// a format.
String httpDate() {
  _refresh();
  return _value;
}

/// The whole Date field line for now, `date: <value>\r\n`, as bytes.
///
/// Refreshed together with [httpDate]. The caller copies it and does not
/// write into it.
Uint8List httpDateLine() {
  _refresh();
  return _line;
}

void _refresh() {
  final ms = _clock.elapsedMilliseconds;
  if (ms >= _refreshAtMs) {
    final now = DateTime.now().toUtc();
    _value = parser.formatHttpDate(now);
    _line = latin1.encode('date: $_value\r\n');
    _refreshAtMs = ms + 1000 - now.millisecond;
  }
}
