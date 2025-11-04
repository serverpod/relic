import 'package:relic/relic.dart';
import 'package:relic/src/context/context.dart';
import 'package:test/test.dart';

void main() {
  group('Given a Request, when withRequest is called with a new Request,', () {
    late Request originalRequest;
    late Request newRequest;
    late Object token;

    setUp(() {
      originalRequest = RequestInternal.create(
        Method.get,
        Uri.parse('http://test.com/path'),
        Object(),
      );
      token = originalRequest.token;
      newRequest = originalRequest.copyWith(
        requestedUri: Uri.parse('http://test.com/newpath'),
      );
    });

    test('then it returns a Request instance', () {
      expect(newRequest, isA<Request>());
    });

    test('then the new request preserves the same token', () {
      expect(newRequest.token, same(token));
    });

    test('then the new request is not the same instance as the original', () {
      expect(newRequest, isNot(same(originalRequest)));
    });

    test('then a Response can be created from the request', () {
      final responseContext = Response.ok(body: Body.fromString('test'));

      expect(responseContext, isA<Response>());
    });

    test('then a Hijack result can be created', () {
      final result = Hijack((final channel) {});

      expect(result, isA<Hijack>());
    });

    test('then a WebSocketUpgrade result can be created', () {
      final result = WebSocketUpgrade((final webSocket) {});

      expect(result, isA<WebSocketUpgrade>());
    });
  });

  group(
    'Given a Request, when withRequest is called with a request created using copyWith,',
    () {
      late Request originalRequest;
      late Object token;

      setUp(() {
        token = Object();
        originalRequest = RequestInternal.create(
          Method.get,
          Uri.parse('http://test.com/path'),
          token,
        );
      });

      test('then it simplifies middleware request rewriting pattern', () {
        final rewrittenRequest = originalRequest.copyWith(
          requestedUri: Uri.parse('http://test.com/rewritten'),
        );
        expect(rewrittenRequest, isA<Request>());
        expect(
          rewrittenRequest.requestedUri,
          Uri.parse('http://test.com/rewritten'),
        );
        expect(rewrittenRequest.token, same(token));
      });

      test(
        'then it maintains the same token across multiple transformations',
        () {
          final request1 = originalRequest.copyWith(
            requestedUri: Uri.parse('http://test.com/step1'),
          );

          final request2 = request1.copyWith(
            requestedUri: Uri.parse('http://test.com/step2'),
          );

          expect(originalRequest.token, same(token));
          expect(request1.token, same(token));
          expect(request2.token, same(token));
          expect(request2.requestedUri, Uri.parse('http://test.com/step2'));
        },
      );
    },
  );
}
