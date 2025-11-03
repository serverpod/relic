import 'package:relic/relic.dart';
import 'package:relic/src/context/context.dart';
import 'package:test/test.dart';

void main() {
  group(
    'Given a RequestContext, when withRequest is called with a new Request,',
    () {
      late RequestContext context;
      late Request originalRequest;
      late Request newRequest;
      late RequestContext newContext;
      late Object token;

      setUp(() {
        originalRequest = Request(
          Method.get,
          Uri.parse('http://test.com/path'),
        );
        context = originalRequest;
        token = context.token;
        newRequest = originalRequest.copyWith(
          requestedUri: Uri.parse('http://test.com/newpath'),
        );
        newContext = context.withRequest(newRequest);
      });

      test('then it returns a RequestContext instance', () {
        expect(newContext, isA<RequestContext>());
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
        final responseContext = newContext.respond(
          Response.ok(body: Body.fromString('test')),
        );

        expect(responseContext, isA<ResponseContext>());
        expect(responseContext.request, same(newRequest));
      });

      test('then the new context can transition to HijackedContext', () {
        final hijackedContext = newContext.hijack((final channel) {});

        expect(hijackedContext, isA<HijackedContext>());
        expect(hijackedContext.request, same(newRequest));
      });

      test('then the new context can transition to ConnectionContext', () {
        final connectionContext = newContext.connect((final webSocket) {});

        expect(connectionContext, isA<ConnectionContext>());
        expect(connectionContext.request, same(newRequest));
      });
    },
  );

  group(
    'Given a RequestContext, when withRequest is called with a request created using copyWith,',
    () {
      late RequestContext context;
      late Request originalRequest;
      late Object token;

      setUp(() {
        originalRequest = Request(
          Method.get,
          Uri.parse('http://test.com/path'),
        );
        token = Object();
        context = originalRequest..setToken(token);
      });

      test('then it simplifies middleware request rewriting pattern', () {
        final rewrittenRequest = originalRequest.copyWith(
          requestedUri: Uri.parse('http://test.com/rewritten'),
        );
        final newContext = context.withRequest(rewrittenRequest);

        expect(newContext, isA<RequestContext>());
        expect(
          newContext.request.requestedUri,
          Uri.parse('http://test.com/rewritten'),
        );
        expect(newContext.token, same(token));
      });

      test(
        'then it maintains the same token across multiple transformations',
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
            context2.request.requestedUri,
            Uri.parse('http://test.com/step2'),
          );
        },
      );
    },
  );
}
