import 'package:relic/relic.dart';
import 'package:relic/src/headers/standard_headers_extensions.dart';
import 'package:test/test.dart';

void main() {
  group('Given Headers class', () {
    test('when created with default values then it initializes correctly', () {
      var headers = Headers.empty();
      expect(headers, isEmpty);
      expect(headers.date, isNull);
    });

    test('when custom headers are added then they are included', () {
      var headers = Headers.from({
        'X-Custom-Header': ['value']
      });
      expect(headers['x-custom-header'], equals(['value']));
    });

    test('when custom headers are removed then they are no longer present', () {
      var headers = Headers.from({
        'X-Custom-Header': ['value']
      });
      headers = headers.transform((mh) => mh.remove('X-Custom-Header'));
      expect(headers['x-custom-header'], isNull);
    });

    test('when accessing headers then they are case insensitive', () {
      var headers = Headers.from({
        'Case-Insensitive': ['value']
      });
      expect(headers['case-insensitive'], contains('value'));
      expect(headers['CASE-INSENSITIVE'], contains('value'));
    });

    test('when headers are copied then modifications are correctly applied',
        () {
      var headers = Headers.from({
        'Initial-Header': ['initial']
      });
      var copiedHeaders = headers.transform((mh) {
        mh.remove('Initial-Header');
        mh['Copied-Header'] = ['copied'];
      });
      expect(copiedHeaders['initial-header'], isNull);
      expect(copiedHeaders['copied-header'], equals(['copied']));
    });

    test('when headers are applied to a Response then they are set correctly',
        () {
      var headers = Headers.build((mh) {
        mh['Response-Header'] = ['response-value'];
      });
      var response = Response.ok(headers: headers);

      expect(response.headers['Response-Header'], equals(['response-value']));
    });

    test('when handling large headers then they are processed correctly', () {
      var largeValue = List.filled(10000, 'a').join();
      var headers = Headers.build((mh) {
        mh['Large-Header'] = [largeValue];
      });
      expect(headers['large-header']?.first.length, equals(10000));
    });

    test('when a managed header is removed then it is no longer present', () {
      var headers = Headers.build((mh) => mh.date = DateTime.now());
      headers = headers.transform((mh) => mh.date = null);
      expect(headers.date, isNull);
    });

    test('when a managed header is updated then it is correctly replaced', () {
      var headers = Headers.build((mh) => mh.date = DateTime.now());
      var newDate = DateTime.now()
          .add(Duration(days: 1))
          .toUtc()
          .copyWith(microsecond: 0, millisecond: 0);
      headers = headers.transform((mh) => mh.date = newDate);
      expect(headers.date, equals(newDate));
    });
  });
}
