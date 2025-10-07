import 'package:relic/relic.dart';
import 'package:relic/src/adapter/context.dart';
import 'package:test/test.dart';

void main() {
  group('Given a NewContext', () {
    late NewContext context;
    late Request originalRequest;
    late Object token;

    setUp(() {
      originalRequest = Request(Method.get, Uri.parse('http://test.com/path'));
      token = Object();
      context = originalRequest.toContext(token);
    });

    group('when withRequest is called', () {
      test(
          'then it returns a new NewContext with the new request and same token',
          () {
        final newRequest =
            Request(Method.post, Uri.parse('http://test.com/newpath'));
        final newContext = context.withRequest(newRequest);

        expect(newContext, isA<NewContext>());
        expect(newContext.request, same(newRequest));
        expect(newContext.token, same(token));
        expect(newContext, isNot(same(context)));
      });

      test(
          'then the original context remains unchanged with its original request',
          () {
        final newRequest =
            Request(Method.post, Uri.parse('http://test.com/newpath'));
        context.withRequest(newRequest);

        expect(context.request, same(originalRequest));
        expect(context.token, same(token));
      });

      test(
          'then the new context can transition to ResponseContext independently',
          () {
        final newRequest =
            Request(Method.post, Uri.parse('http://test.com/newpath'));
        final newContext = context.withRequest(newRequest);

        final responseContext =
            newContext.respond(Response.ok(body: Body.fromString('test')));

        expect(responseContext, isA<ResponseContext>());
        expect(responseContext.request, same(newRequest));
        expect(responseContext.token, same(token));
      });

      test('then the new context can transition to HijackContext independently',
          () {
        final newRequest =
            Request(Method.post, Uri.parse('http://test.com/newpath'));
        final newContext = context.withRequest(newRequest);

        final hijackContext = newContext.hijack((final channel) {});

        expect(hijackContext, isA<HijackContext>());
        expect(hijackContext.request, same(newRequest));
        expect(hijackContext.token, same(token));
      });

      test(
          'then the new context can transition to ConnectContext independently',
          () {
        final newRequest =
            Request(Method.post, Uri.parse('http://test.com/newpath'));
        final newContext = context.withRequest(newRequest);

        final connectContext = newContext.connect((final webSocket) {});

        expect(connectContext, isA<ConnectContext>());
        expect(connectContext.request, same(newRequest));
        expect(connectContext.token, same(token));
      });
    });

    group('when withRequest is used with request.copyWith', () {
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

      test(
          'then it maintains the same token across multiple request transformations',
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
        expect(
            context2.request.requestedUri, Uri.parse('http://test.com/step2'));
      });
    });
  });
}
