import 'dart:convert';
import 'dart:io';

/// What one oha run measured.
///
/// Latencies are in milliseconds.
final class OhaResult {
  final double rps;
  final double p50;
  final double p99;
  final double p999;

  /// Responses of any status.
  final int responses;

  /// Requests that got no response, the deadline cut-off aside.
  final int failed;

  /// Responses with a status other than 200.
  final int nonOk;

  OhaResult({
    required this.rps,
    required this.p50,
    required this.p99,
    required this.p999,
    required this.responses,
    required this.failed,
    required this.nonOk,
  });
}

/// One oha run against [url] for [seconds].
///
/// A null [rate] is a closed loop at [connections] in flight, otherwise an
/// open loop at that many requests per second. Each of [headers] is a
/// `Name: value` line. An https [url] goes unverified, since the servers
/// here present test certificates. Needs `oha` on the PATH.
///
/// No `--latency-correction`. oha 1.16.0 charges pauses of about 300 ms in
/// its own scheduler to every request due during them, on any server and
/// at any rate, and a probe client beside it sees none of it. A server
/// that falls behind the offered rate shows in [OhaResult.rps] against the
/// rate.
Future<OhaResult> runOha(
  final String url, {
  required final int connections,
  required final int seconds,
  final int? rate,
  final List<String> headers = const [],
}) async {
  final result = await Process.run('oha', [
    '--no-tui',
    '--output-format',
    'json',
    '-c',
    '$connections',
    '-z',
    '${seconds}s',
    if (rate != null) ...['-q', '$rate'],
    if (url.startsWith('https:')) '--insecure',
    for (final header in headers) ...['-H', header],
    url,
  ]);
  if (result.exitCode != 0) {
    throw ProcessException('oha', const [], result.stderr as String);
  }
  final json = jsonDecode(result.stdout as String) as Map<String, dynamic>;
  final summary = json['summary'] as Map<String, dynamic>;
  final percentiles = json['latencyPercentiles'] as Map<String, dynamic>;
  final statuses = json['statusCodeDistribution'] as Map<String, dynamic>;
  final errors = json['errorDistribution'] as Map<String, dynamic>;
  double ms(final String key) => (percentiles[key] as num) * 1000;
  var responses = 0;
  var nonOk = 0;
  for (final MapEntry(:key, :value) in statuses.entries) {
    responses += value as int;
    if (key != '200') nonOk += value;
  }
  var failed = 0;
  for (final MapEntry(:key, :value) in errors.entries) {
    // The deadline cuts off whatever is in flight. That is not a failure.
    if (!key.contains('deadline')) failed += value as int;
  }
  return OhaResult(
    rps: (summary['requestsPerSec'] as num).toDouble(),
    p50: ms('p50'),
    p99: ms('p99'),
    p999: ms('p99.9'),
    responses: responses,
    failed: failed,
    nonOk: nonOk,
  );
}
