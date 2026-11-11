// doctag<testing-serve>
import 'package:http/http.dart' as http;
import 'package:relic/relic.dart';
import 'package:test/test.dart';

RelicApp buildApp() =>
    RelicApp()
      ..get('/hello', (req) => Response.ok(body: Body.fromString('Hello!')));

void main() {
  group('Given the app served on a free port', () {
    late Uri baseUrl;

    setUp(() async {
      final app = buildApp();
      final server = await app.serve(port: 0);
      addTearDown(app.close);
      baseUrl = Uri.http('127.0.0.1:${server.port}');
    });

    test('when a client sends GET /hello, '
        'then it answers 200 with a greeting', () async {
      final response = await http.get(baseUrl.resolve('/hello'));

      expect(response.statusCode, 200);
      expect(response.body, 'Hello!');
    });

    test('when a client sends GET to a path with no route, '
        'then it answers 404', () async {
      final response = await http.get(baseUrl.resolve('/missing'));

      expect(response.statusCode, 404);
    });
  });
}

// end:doctag<testing-serve>
