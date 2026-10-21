// Runs the Zig tests in a Linux container, once with the io_uring
// syscalls allowed and once under Docker's default seccomp profile, which
// blocks them. zio's auto backend takes io_uring in the first run and
// falls back to epoll in the second. The repo is mounted read-only and
// the package copied out of it, since zig fetches zio into a zig-pkg
// directory next to build.zig.
//
//   dart run tool/linux_test.dart               # relic_native, both backends
//   dart run tool/linux_test.dart --zio=<path>  # and the suite of a zio checkout
//
// Needs Docker. Every run builds the image from tool/linux/Dockerfile,
// which the layer cache makes a no-op until the Dockerfile changes.
import 'dart:io';

import 'package:path/path.dart' as p;

const _image = 'relic-zig-linux';

Future<void> main(List<String> args) async {
  final package = p.dirname(p.dirname(p.fromUri(Platform.script)));
  final repo = p.dirname(p.dirname(package));
  final zio = _zioCheckout(args);
  await _ensureImage(package);

  var failed = false;
  for (final (name, options) in [
    ('io_uring', ['--security-opt', 'seccomp=unconfined']),
    ('epoll', <String>[]),
  ]) {
    stdout.writeln('== relic_native on $name');
    failed |= !await _run(
      [...options, '-v', '$repo:$repo:ro'],
      'cp -r $package /work && cd /work && '
      'zig build test --cache-dir /tmp/zc --summary all',
    );
  }
  if (zio != null) {
    for (final backend in ['epoll', 'io_uring']) {
      stdout.writeln('== zio on $backend');
      // Mounted writable. The test temp directories live under the
      // checkout's .zig-cache.
      failed |= !await _run(
        ['--security-opt', 'seccomp=unconfined', '-v', '$zio:$zio', '-w', zio],
        'zig build test --cache-dir /tmp/zc '
        '-Dbackend=$backend --summary all',
      );
    }
  }
  exitCode = failed ? 1 : 0;
}

/// The absolute path given with `--zio=`, or null without one.
String? _zioCheckout(List<String> args) {
  const flag = '--zio=';
  for (final arg in args) {
    if (arg.startsWith(flag)) return p.absolute(arg.substring(flag.length));
  }
  return null;
}

Future<void> _ensureImage(String package) async {
  final build = await Process.start('docker', [
    'build',
    '-t',
    _image,
    p.join(package, 'tool', 'linux'),
  ], mode: ProcessStartMode.inheritStdio);
  if (await build.exitCode != 0) throw StateError('docker build failed');
}

/// Runs [command] in the image and prints the summary lines. True on
/// success.
Future<bool> _run(List<String> dockerOptions, String command) async {
  final result = await Process.run('docker', [
    'run',
    '--rm',
    ...dockerOptions,
    _image,
    'sh',
    '-c',
    '$command 2>&1',
  ]);
  final lines = (result.stdout as String).split('\n');
  for (final line in lines) {
    if (line.contains('tests passed') ||
        line.contains('error') ||
        line.contains('panic') ||
        line.contains('crashed')) {
      stdout.writeln('  $line');
    }
  }
  return result.exitCode == 0;
}
