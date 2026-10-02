// Builds the prebuilt native library for every supported target into
// binary/. Run it before `dart pub publish`:
//
//   dart run tool/build_binaries.dart
//
// Needs the zig in build.zig.zon's minimum_zig_version. Every target
// cross-compiles from any host.
import 'dart:io';

import 'package:relic_native/src/native_target.dart';

Future<void> main() async {
  final packageRoot = File.fromUri(Platform.script).parent.parent.uri;
  final binary = Directory.fromUri(packageRoot.resolve('binary/'));
  final scratch = await Directory.systemTemp.createTemp('relic_native_');

  try {
    if (binary.existsSync()) await binary.delete(recursive: true);

    for (final target in NativeTarget.all) {
      stdout.writeln('Building ${target.directory} (${target.zigTriple})');
      final built = await target.build(
        packageRoot: packageRoot,
        outputDirectory: scratch.uri,
      );
      final destination = File.fromUri(
        binary.uri.resolve('${target.directory}/${target.libraryName}'),
      );
      await destination.parent.create(recursive: true);
      await built.copy(destination.path);
    }
  } finally {
    await scratch.delete(recursive: true);
  }

  stdout.writeln('Done. Prebuilt libraries are in ${binary.path}');
}
