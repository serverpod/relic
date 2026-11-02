import 'dart:io';

import 'package:config/config.dart';

/// Resolves [options] from [args] for a bin without subcommands.
///
/// `--help` prints [synopsis] and the options and exits. An unknown flag,
/// a bad value or a missing mandatory option goes to [usageError], so
/// main never runs on a bad command line.
Configuration<O> resolveOptions<O extends OptionDefinition<dynamic>>(
  List<O> options,
  List<String> args, {
  required String synopsis,
}) {
  // A `--help` after `--` belongs to the command that follows it.
  if (args.takeWhile((arg) => arg != '--').contains('--help')) {
    stdout
      ..writeln(synopsis)
      ..writeln()
      ..writeln(options.usage);
    exit(0);
  }
  try {
    return Configuration.resolve(options: options, args: args);
  } on UsageException catch (e) {
    usageError(e.message, options, synopsis: synopsis);
  }
}

/// Prints [message], [synopsis] and the usage of [options] to stderr and
/// exits with 64, the usage error status.
Never usageError(
  String message,
  List<OptionDefinition<dynamic>> options, {
  required String synopsis,
}) {
  stderr
    ..writeln(message)
    ..writeln()
    ..writeln(synopsis)
    ..writeln()
    ..writeln(options.usage);
  exit(64);
}
