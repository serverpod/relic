import 'package:relic/relic.dart';
import 'package:relic/src/context/result.dart';
import 'package:test/test.dart';

import '../util/test_util.dart';

/// Tests for PathParam and PathParameters.
///
/// Note: Core AccessorState behavior ([], call, get, tryGet, caching, error
/// handling) is tested in test/accessor/accessor_test.dart. These tests focus
/// on PathParam-specific behavior: integration with routing and the typed
/// param classes.
void main() {
  group('Given a router with parameterized routes,', () {
    test('when a request matches a route with path parameters, '
        'then pathParameters returns the extracted values', () async {
      final request = await _routeRequest(
        '/users/:name/posts/:id',
        'http://localhost/users/john/posts/42',
      );

      const nameParam = PathParam<String>(#name, _identity);
      const idParam = IntPathParam(#id);

      expect(request.pathParameters(nameParam), equals('john'));
      expect(request.pathParameters(idParam), equals(42));
    });

    test('when pathParameters is accessed multiple times, '
        'then it returns the same instance', () async {
      final request = await _routeRequest(
        '/users/:id',
        'http://localhost/users/123',
      );

      final params1 = request.pathParameters;
      final params2 = request.pathParameters;

      expect(identical(params1, params2), isTrue);
    });
  });

  group('Given a router with a non-parameterized route,', () {
    test('when a request matches the route, '
        'then pathParameters returns an empty state', () async {
      final request = await _routeRequest('/static', 'http://localhost/static');

      const param = PathParam<String>(#any, _identity);
      expect(request.pathParameters[param], isNull);
      expect(request.pathParameters.get(param), isNull);
      expect(() => request.pathParameters(param), throwsA(isA<StateError>()));
    });
  });

  group('Given a path parameter with a valid numeric value,', () {
    parameterizedTest(
      (final v) =>
          'when decoded with ${v.name}, '
          'then it returns ${v.expected}',
      (final v) async {
        final request = await _routeRequest(
          '/v/:value',
          'http://localhost/v/${v.input}',
        );

        final result = request.pathParameters(v.param);
        expect(result, equals(v.expected));
      },
      variants: const [
        _ParamTestCase('IntPathParam', '42', IntPathParam(#value), 42),
        _ParamTestCase('IntPathParam', '-100', IntPathParam(#value), -100),
        _ParamTestCase('IntPathParam', '0', IntPathParam(#value), 0),
        _ParamTestCase(
          'DoublePathParam',
          '3.14',
          DoublePathParam(#value),
          3.14,
        ),
        _ParamTestCase('DoublePathParam', '42', DoublePathParam(#value), 42.0),
        _ParamTestCase(
          'DoublePathParam',
          '-99.99',
          DoublePathParam(#value),
          -99.99,
        ),
        _ParamTestCase('NumPathParam', '42', NumPathParam(#value), 42),
        _ParamTestCase('NumPathParam', '3.14', NumPathParam(#value), 3.14),
        _ParamTestCase('NumPathParam', '-42', NumPathParam(#value), -42),
      ],
    );
  });

  group('Given a path parameter with an invalid numeric value,', () {
    parameterizedTest(
      (final v) =>
          'when decoded with ${v.name}, '
          'then it throws FormatException',
      (final v) async {
        final request = await _routeRequest(
          '/v/:value',
          'http://localhost/v/${v.input}',
        );

        expect(() => request.pathParameters(v.param), throwsFormatException);
      },
      variants: const [
        _ParamTestCase('IntPathParam', 'abc', IntPathParam(#value), null),
        _ParamTestCase('IntPathParam', '3.14', IntPathParam(#value), null),
        _ParamTestCase('DoublePathParam', 'xyz', DoublePathParam(#value), null),
        _ParamTestCase('NumPathParam', 'notnum', NumPathParam(#value), null),
      ],
    );
  });

  group('Given a custom PathParam decoder,', () {
    test('when the parameter is accessed, '
        'then the custom transformation is applied', () async {
      final request = await _routeRequest(
        '/users/:slug',
        'http://localhost/users/hello-world',
      );

      // Custom decoder that converts slug to title case
      const slugParam = PathParam<String>(#slug, _toTitleCase);

      expect(request.pathParameters(slugParam), equals('Hello World'));
    });
  });
}

/// Routes a request through a router and returns the captured request.
Future<Request> _routeRequest(final String pattern, final String url) async {
  final router = RelicRouter();
  late Request captured;
  router.get(pattern, (final req) {
    captured = req;
    return Response.ok();
  });

  final req = RequestInternal.create(Method.get, Uri.parse(url), Object());
  await router.asHandler(req);
  return captured;
}

String _identity(final String value) => value;

String _toTitleCase(final String s) => s
    .split('-')
    .map((final w) => w[0].toUpperCase() + w.substring(1))
    .join(' ');

class _ParamTestCase {
  final String name;
  final String input;
  final PathParam<num> param;
  final num? expected;

  const _ParamTestCase(this.name, this.input, this.param, this.expected);
}
