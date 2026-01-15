import 'package:stack_trace/stack_trace.dart';

typedef Logger =
    void Function(String message, {StackTrace? stackTrace, LoggerType type});

enum LoggerType { error, warn, info }

/// Logs a message using [print].
///
/// If [stackTrace] is passed, it will be used to create a chain of frames
/// that excludes core Dart frames and frames from the 'relic' package.
///
/// If [type] is not passed, it defaults to [LoggerType.info].
void logMessage(
  final String message, {
  final StackTrace? stackTrace,
  final LoggerType type = LoggerType.info,
}) {
  var chain = Chain.current();

  if (stackTrace != null) {
    chain = Chain.forTrace(stackTrace)
        .foldFrames((final frame) => frame.isCore || frame.package == 'relic')
        .terse;
  }

  final prefix = switch (type) {
    LoggerType.error => 'ERROR',
    LoggerType.warn => 'WARN',
    LoggerType.info => 'INFO',
  };

  // ignore: avoid_print
  print('$prefix - ${DateTime.now()}');
  // ignore: avoid_print
  print(message);
  if (type != LoggerType.info) {
    // ignore: avoid_print
    print(chain);
  }
}
