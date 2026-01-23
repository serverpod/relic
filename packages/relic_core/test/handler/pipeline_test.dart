import 'package:relic_core/relic_core.dart';
import 'package:relic_core/src/test/test_util.dart';
import 'package:test/test.dart';

void main() {
  var accessLocation = 0;

  setUp(() {
    accessLocation = 0;
  });

  Handler middlewareA(final Handler next) => (final request) {
    expect(accessLocation, 0);
    accessLocation = 1;
    final response = next(request);
    expect(accessLocation, 4);
    accessLocation = 5;
    return response;
  };

  Handler middlewareB(final Handler next) => (final request) {
    expect(accessLocation, 1);
    accessLocation = 2;
    final response = next(request);
    expect(accessLocation, 3);
    accessLocation = 4;
    return response;
  };

  Result next(final Request request) {
    expect(accessLocation, 2);
    accessLocation = 3;
    return syncHandler(request);
  }

  test(
    'Given a pipeline with middlewareA and middlewareB when a request is processed then it completes with accessLocation 5',
    () async {
      final handler = const Pipeline()
          .addMiddleware(middlewareA)
          .addMiddleware(middlewareB)
          .addHandler(next);

      final response = await makeSimpleRequest(handler);
      expect(response, isNotNull);
      expect(accessLocation, 5);
    },
  );

  test(
    'Given middlewareA and middlewareB when composed using extensions then a request completes with accessLocation 5',
    () async {
      final handler = middlewareA.addMiddleware(middlewareB).addHandler(next);

      final response = await makeSimpleRequest(handler);
      expect(response, isNotNull);
      expect(accessLocation, 5);
    },
  );

  test(
    'Given a pipeline used as middleware when a request is processed then it completes with accessLocation 5',
    () async {
      final innerPipeline = const Pipeline()
          .addMiddleware(middlewareA)
          .addMiddleware(middlewareB);

      final handler = const Pipeline()
          .addMiddleware(innerPipeline.middleware)
          .addHandler(next);

      final response = await makeSimpleRequest(handler);
      expect(response, isNotNull);
      expect(accessLocation, 5);
    },
  );
}
