import 'package:relic/relic.dart';
import 'package:relic/src/headers/standard_headers_extensions.dart';
import 'package:test/test.dart';

void main() {
  group('Given Headers class', () {
    test('when created with default values then it initializes correctly', () {
      var headers = Headers.request();
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

    test('when headers are serialized then they are correctly formatted', () {
      var headers = Headers.from({
        'Serialized-Header': ['value']
      });
      var serialized = headers.toMap();
      expect(serialized['Serialized-Header'], equals(['value']));
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

    test('when converting headers to map then it includes all headers', () {
      var headers = Headers.from({
        'Map-Header': ['map-value']
      });
      var map = headers.toMap();
      expect(map['Map-Header'], equals(['map-value']));
    });

    test('when headers are applied to a Response then they are set correctly',
        () {
      var headers = Headers.response(
        custom: CustomHeaders({
          'Response-Header': ['response-value']
        }),
      );
      var response = Response.ok(headers: headers);

      expect(response.headers['Response-Header'], equals(['response-value']));
    });

    test('when handling large headers then they are processed correctly', () {
      var largeValue = List.filled(10000, 'a').join();
      var headers = Headers.request(
          custom: CustomHeaders({
        'Large-Header': [largeValue]
      }));
      expect(headers['large-header']?.first.length, equals(10000));
    });

    test('when a managed header is removed then it is no longer present', () {
      var headers = Headers.request(date: DateTime.now());
      headers = headers.transform((mh) => mh.date = null);
      expect(headers.date, isNull);
    });

    test('when a managed header is updated then it is correctly replaced', () {
      var headers = Headers.request(date: DateTime.now());
      var newDate = DateTime.now()
          .add(Duration(days: 1))
          .toUtc()
          .copyWith(microsecond: 0, millisecond: 0);
      headers = headers.transform((mh) => mh.date = newDate);
      expect(headers.date, equals(newDate));
    });
  });
}
