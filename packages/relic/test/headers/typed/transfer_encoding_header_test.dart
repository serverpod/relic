import 'package:relic/relic.dart';
import 'package:test/test.dart';

import '../docs/strict_validation_docs.dart';
import '../headers_test_utils.dart';

/// Reference: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Transfer-Encoding
/// For more details on header validation behavior, see the [HeaderValidationDocs] class.
void main() {
  group('Given a Transfer-Encoding header with validation', () {
    late RelicServer server;

    setUp(() async {
      server = await createServer();
    });

    tearDown(() => server.close());

    // Note: validation and parse/encode behavior (empty value, unknown coding,
    // chunked-not-last, multi-coding ordering, duplicate removal, isChunked) is
    // covered by direct unit tests in
    // packages/relic_core/test/headers/typed/transfer_encoding_header_test.dart.
    // These cannot run as server round-trips: dart:io owns Transfer-Encoding
    // framing. On a bodyless GET it waits for a chunked body the client never
    // sends, and on Dart 3.13+ HttpServer rejects an empty or unknown coding at
    // the protocol layer (closing the connection before the handler runs). See
    // the dart-io-transfer-encoding-close-hang reproduction.

    test(
      'when no Transfer-Encoding header is passed then it should return null',
      () async {
        final headers = await getServerRequestHeaders(
          server: server,
          touchHeaders: (final h) => h.transferEncoding,
          headers: {},
        );

        expect(headers.transferEncoding, isNull);
      },
    );
  });
}
