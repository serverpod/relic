/// HTTP header names and stores.
///
/// [HeaderName] interns the standard header names. [HeaderStore] is what a
/// server adapter hands the framework for a request, and
/// [MutableHeaderStore] is what a response is built in. [MapHeaderStore] is
/// the plain map implementation of both, and [ByteHeaderStore] a read-only
/// one over the bytes of a request head.
///
/// The typed headers and their codecs live in `relic_core`. This package
/// carries only what another package needs to read or produce headers.
library;

export 'src/byte_header_store.dart';
export 'src/header_name.dart';
export 'src/header_store.dart';
export 'src/map_header_store.dart';
