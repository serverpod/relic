import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';

import 'package:relic_native/src/native_target.dart';

/// Bundles the native library for the target being built.
///
/// A published package carries a prebuilt library per target under
/// `binary/`, so consumers need no toolchain. A source checkout has no
/// `binary/` and compiles with zig instead.
///
/// A target the package does not support gets no asset and no error, so
/// `dart test` in the workspace stays green on such a host. The Dart side
/// reports the missing library on first use.
Future<void> main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets) return;

    final code = input.config.code;
    final target = NativeTarget.of(code);
    if (target == null) return;

    final packageRoot = input.packageRoot;
    final prebuilt = File.fromUri(
      packageRoot.resolve('binary/${target.directory}/${target.libraryName}'),
    );

    final File library;
    if (prebuilt.existsSync()) {
      library = prebuilt;
      output.dependencies.add(prebuilt.uri);
    } else {
      try {
        library = await target.build(
          packageRoot: packageRoot,
          outputDirectory: input.outputDirectory,
          cacheDirectory: input.outputDirectoryShared.resolve('zig-cache/'),
        );
      } on StateError catch (e, st) {
        throw BuildError(
          message: e.message,
          wrappedException: e,
          wrappedTrace: st,
        );
      } on ProcessException catch (e, st) {
        throw BuildError(
          message: e.message,
          wrappedException: e,
          wrappedTrace: st,
        );
      }
      output.dependencies.addAll([
        packageRoot.resolve('build.zig'),
        packageRoot.resolve('build.zig.zon'),
        packageRoot.resolve('src/relic_native.zig'),
        packageRoot.resolve('src/dart-dl/dart_api_dl.c'),
        ..._pathDependencySources(packageRoot),
      ]);
    }

    output.assets.code.add(
      CodeAsset(
        package: input.packageName,
        name: 'relic_native.dart',
        linkMode: DynamicLoadingBundled(),
        file: library.uri,
      ),
    );
  });
}

/// The Zig sources of every `.path` dependency in build.zig.zon, so an
/// edit in a checkout the package points at rebuilds the library. A
/// published package has none.
Iterable<Uri> _pathDependencySources(Uri packageRoot) sync* {
  final zon = File.fromUri(packageRoot.resolve('build.zig.zon'));
  if (!zon.existsSync()) return;
  for (final match in RegExp(
    r'\.path\s*=\s*"([^"]+)"',
  ).allMatches(zon.readAsStringSync())) {
    final dir = Directory.fromUri(packageRoot.resolve('${match[1]!}/src'));
    if (!dir.existsSync()) continue;
    for (final entry in dir.listSync(recursive: true)) {
      if (entry is File && entry.path.endsWith('.zig')) yield entry.uri;
    }
  }
}
