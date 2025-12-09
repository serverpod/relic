/// Relic web server framework.
///
/// This package re-exports [relic_core] and adds dart:io specific functionality.
library;

// Re-export all of relic_core
export 'package:relic_core/relic_core.dart';

// dart:io specific exports
export 'src/io/static/cache_busting_config.dart';
export 'src/io/static/extension/datetime_extension.dart';
export 'src/io/static/static_handler.dart';
