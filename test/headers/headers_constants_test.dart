import 'package:relic/relic.dart';
import 'package:test/test.dart';

void main() {
  group('Headers constants', () {
    test(
        'Headers.request contains request headers and excludes response only headers',
        () {
      expect(Headers.request, contains(Headers.host));
      expect(Headers.request, isNot(contains(Headers.etag)));
    });

    test(
        'Headers.response contains response headers and excludes request only headers',
        () {
      expect(Headers.response, contains(Headers.etag));
      expect(Headers.response, isNot(contains(Headers.host)));
    });
  });
}
