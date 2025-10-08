import 'package:relic/relic.dart';
import 'package:relic/src/adapter/context.dart';
import 'package:test/test.dart';

void main() {
  group('Given a NewContext, when withRequest is called with a new Request,',
      () {
    late NewContext context;
    late Request originalRequest;
    late Request newRequest;
    late NewContext newContext;
    late Object token;

    setUp(() {
      originalRequest = Request(Method.get, Uri.parse('http://test.com/path'));
      token = Object();
      context = originalRequest.toContext(token);
      newRequest = Request(Method.post, Uri.parse('http://test.com/newpath'));
      newContext = context.withRequest(newRequest);
    });

    test('then it returns a NewContext instance', () {
      expect(newContext, isA<NewContext>());
    });

    test('then the new context contains the new request', () {
      expect(newContext.request, same(newRequest));
    });

    test('then the new context preserves the same token', () {
      expect(newContext.token, same(token));
    });

    test('then the new context is not the same instance as the original', () {
      expect(newContext, isNot(same(context)));
    });

    test('then the original context remains unchanged', () {
      expect(context.request, same(originalRequest));
      expect(context.token, same(token));
    });

    test('then the new context can transition to ResponseContext', () {
      final responseContext =
          newContext.respond(Response.ok(body: Body.fromString('test')));

      expect(responseContext, isA<ResponseContext>());
      expect(responseContext.request, same(newRequest));
      expect(responseContext.token, same(token));
    });

    test('then the new context can transition to HijackContext', () {
      final hijackContext = newContext.hijack((final channel) {});

      expect(hijackContext, isA<HijackContext>());
      expect(hijackContext.request, same(newRequest));
      expect(hijackContext.token, same(token));
    });

    test('then the new context can transition to ConnectContext', () {
      final connectContext = newContext.connect((final webSocket) {});

      expect(connectContext, isA<ConnectContext>());
      expect(connectContext.request, same(newRequest));
      expect(connectContext.token, same(token));
    });
  });

  group(
      'Given a NewContext, when withRequest is called with a request created using copyWith,',
      () {
    late NewContext context;
    late Request originalRequest;
    late Object token;

    setUp(() {
      originalRequest = Request(Method.get, Uri.parse('http://test.com/path'));
      token = Object();
      context = originalRequest.toContext(token);
    });

    test('then it simplifies middleware request rewriting pattern', () {
      final rewrittenRequest = originalRequest.copyWith(
        requestedUri: Uri.parse('http://test.com/rewritten'),
      );
      final newContext = context.withRequest(rewrittenRequest);

      expect(newContext, isA<NewContext>());
      expect(newContext.request.requestedUri,
          Uri.parse('http://test.com/rewritten'));
      expect(newContext.token, same(token));
    });

    test('then it maintains the same token across multiple transformations',
        () {
      final request1 = originalRequest.copyWith(
        requestedUri: Uri.parse('http://test.com/step1'),
      );
      final context1 = context.withRequest(request1);

      final request2 = request1.copyWith(
        requestedUri: Uri.parse('http://test.com/step2'),
      );
      final context2 = context1.withRequest(request2);

      expect(context.token, same(token));
      expect(context1.token, same(token));
      expect(context2.token, same(token));
      expect(context2.request.requestedUri, Uri.parse('http://test.com/step2'));
    });
  });
}
