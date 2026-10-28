import 'dart:convert';
import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:http_parser/http_parser.dart' as parser;

Clock? _source;
late Stopwatch _elapsed;
var _refreshAtMs = -1;
var _value = '';
var _line = Uint8List(0);

/// A stand-in for an IMF-fixdate that an adapter overwrites on the wire,
/// at send time. It has the 29 bytes every IMF-fixdate has, so the head
/// keeps its length, and it is a real date in case it ever gets out.
const stampedDate = 'Thu, 01 Jan 1970 00:00:00 GMT';

/// The Date header value for now, an RFC 9110 5.6.7 IMF-fixdate.
///
/// A stopwatch decides when to read the wall clock, once per second at the
/// second boundary. A response pays a stopwatch read, not a clock read and
/// a format.
///
/// Time comes from `package:clock`, so a test or a simulation that runs
/// under `withClock` gets its own dates. The cache is per clock. The system
/// clock gets a dart:core [Stopwatch], a monotonic counter read. A
/// substituted clock gets its own stopwatch, which reads that clock's
/// `now` on every elapsed read, so the cache follows the clock it is told.
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
  final source = clock;
  if (!identical(source, _source)) {
    _source = source;
    _elapsed = identical(source, const Clock())
        ? Stopwatch()
        : source.stopwatch();
    _elapsed.start();
    _refreshAtMs = -1;
  }
  final ms = _elapsed.elapsedMilliseconds;
  if (ms >= _refreshAtMs) {
    final now = source.now().toUtc();
    _value = parser.formatHttpDate(now);
    _line = latin1.encode('date: $_value\r\n');
    _refreshAtMs = ms + 1000 - now.millisecond;
  }
}
