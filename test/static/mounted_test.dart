import 'dart:io';

import 'package:relic/relic.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import 'test_util.dart';

void main() {
  setUp(() async {
    await d.file('root.txt', 'root txt').create();
  });

  test(
      'Given a static handler mounted on a router under "/**" '
      'when retrieving the same file twice '
      'then it should return 200 Ok both times', () async {
    final router = Router<Handler>()
      ..get(
          '/**',
          createStaticHandler(
            cacheControl: (final _, final __) => null,
            d.sandbox,
          ));

    final handler = router.asHandler;

    // Repeat retrieveal. This test was added to expose issue:
    // [#173](https://github.com/serverpod/relic/issues/173)
    int repeat = 2;
    while (repeat-- > 0) {
      final response = await makeRequest(handler, '/root.txt');
      expect(response.statusCode, HttpStatus.ok);
    }
  });
}
