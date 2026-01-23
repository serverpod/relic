import 'package:relic_core/relic_core.dart';
import 'package:test/test.dart';
import 'package:test_utils/test_utils.dart';

/// Tests for QueryParam and QueryParameters.
///
/// Note: Core AccessorState behavior ([], call, get, tryGet, caching, error
/// handling) is tested in test/accessor/accessor_test.dart. These tests focus
/// on QueryParam-specific behavior: integration with Request.queryParameters
/// and the typed param classes.
void main() {
  group('Given a request with query parameters,', () {
    test('when queryParameters is accessed, '
        'then it returns the extracted values', () {
      final request = _request('name=john&age=25');

      const nameParam = QueryParam<String>('name', _identity);
      const ageParam = IntQueryParam('age');

      expect(request.queryParameters.get(nameParam), equals('john'));
      expect(request.queryParameters.get(ageParam), equals(25));
    });

    test('when queryParameters is accessed multiple times, '
        'then it returns the same instance', () {
      final request = _request('foo=bar');

      final params1 = request.queryParameters;
      final params2 = request.queryParameters;

      expect(identical(params1, params2), isTrue);
    });
  });

  group('Given a request without query parameters,', () {
    test('when queryParameters is accessed, '
        'then it returns an empty state', () {
      final request = _request(null);

      const param = QueryParam<String>('any', _identity);
      expect(request.queryParameters[param], isNull);
    });
  });

  group('Given a query parameter with a valid numeric value,', () {
    parameterizedTest(
      (final v) =>
          'when decoded with ${v.name}, '
          'then it returns ${v.expected}',
      (final v) {
        final request = _request('value=${v.input}');

        final result = request.queryParameters.get(v.param);
        expect(result, equals(v.expected));
      },
      variants: const [
        _ParamTestCase('IntQueryParam', '42', IntQueryParam('value'), 42),
        _ParamTestCase('IntQueryParam', '-100', IntQueryParam('value'), -100),
        _ParamTestCase('IntQueryParam', '0', IntQueryParam('value'), 0),
        _ParamTestCase(
          'DoubleQueryParam',
          '3.14',
          DoubleQueryParam('value'),
          3.14,
        ),
        _ParamTestCase(
          'DoubleQueryParam',
          '42',
          DoubleQueryParam('value'),
          42.0,
        ),
        _ParamTestCase(
          'DoubleQueryParam',
          '-99.99',
          DoubleQueryParam('value'),
          -99.99,
        ),
        _ParamTestCase('NumQueryParam', '42', NumQueryParam('value'), 42),
        _ParamTestCase('NumQueryParam', '3.14', NumQueryParam('value'), 3.14),
        _ParamTestCase('NumQueryParam', '-42', NumQueryParam('value'), -42),
      ],
    );
  });

  group('Given a query parameter with an invalid numeric value,', () {
    parameterizedTest(
      (final v) =>
          'when decoded with ${v.name}, '
          'then it throws FormatException',
      (final v) {
        final request = _request('value=${v.input}');

        expect(
          () => request.queryParameters.get(v.param),
          throwsFormatException,
        );
      },
      variants: const [
        _ParamTestCase('IntQueryParam', 'abc', IntQueryParam('value'), null),
        _ParamTestCase('IntQueryParam', '3.14', IntQueryParam('value'), null),
        _ParamTestCase(
          'DoubleQueryParam',
          'xyz',
          DoubleQueryParam('value'),
          null,
        ),
        _ParamTestCase('NumQueryParam', 'notnum', NumQueryParam('value'), null),
      ],
    );
  });

  group('Given a custom QueryParam decoder,', () {
    test('when the parameter is accessed, '
        'then the custom transformation is applied', () {
      final request = _request('tags=a,b,c');

      // Custom decoder that splits comma-separated values
      const tagsParam = QueryParam<List<String>>('tags', _splitCommas);

      expect(request.queryParameters.get(tagsParam), equals(['a', 'b', 'c']));
    });
  });
}

/// Creates a request with the given query string.
Request _request(final String? query) {
  final url = query != null
      ? 'http://localhost/test?$query'
      : 'http://localhost/test';
  return RequestInternal.create(Method.get, Uri.parse(url), Object());
}

String _identity(final String value) => value;

List<String> _splitCommas(final String s) => s.split(',');

class _ParamTestCase {
  final String name;
  final String input;
  final QueryParam<num> param;
  final num? expected;

  const _ParamTestCase(this.name, this.input, this.param, this.expected);
}
