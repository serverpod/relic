/// A Relic adapter backed by a Zig HTTP server each isolate drives from its
/// own thread.
library;

export 'src/native_adapter.dart' show NativeAdapter, NativeExchange;
export 'src/native_serve.dart';
