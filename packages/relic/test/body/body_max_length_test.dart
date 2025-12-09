import 'dart:io';
import 'dart:typed_data';

import 'package:relic/io_adapter.dart';
import 'package:relic/relic.dart';
import 'package:test/test.dart';

import '../headers/headers_test_utils.dart';

void main() {
  group('Given Body.read with maxLength', () {
    test('when contentLength is known and exceeds maxLength, '
        'then it throws MaxBodySizeExceeded immediately', () {
      final body = Body.fromDataStream(
        Stream.value(Uint8List.fromList([1, 2, 3, 4, 5])),
        contentLength: 100,
      );

      expect(
        () => body.read(maxLength: 50),
        throwsA(isA<MaxBodySizeExceeded>()),
      );
    });

    test('when contentLength is known and within maxLength, '
        'then it returns the stream normally', () async {
      final data = Uint8List.fromList([1, 2, 3, 4, 5]);
      final body = Body.fromDataStream(Stream.value(data), contentLength: 5);

      final result = await body.read(maxLength: 10).toList();
      expect(result, [data]);
    });

    test('when contentLength is unknown and total bytes exceed maxLength, '
        'then it throws MaxBodySizeExceeded during streaming', () async {
      // Simulate chunked encoding (no contentLength).
      final body = Body.fromDataStream(
        Stream.fromIterable([
          Uint8List.fromList([1, 2, 3]),
          Uint8List.fromList([4, 5, 6]),
          Uint8List.fromList([7, 8, 9]),
        ]),
      );

      expect(
        () async => await body.read(maxLength: 5).toList(),
        throwsA(isA<MaxBodySizeExceeded>()),
      );
    });

    test('when contentLength is unknown and total bytes are within maxLength, '
        'then it returns all chunks', () async {
      final body = Body.fromDataStream(
        Stream.fromIterable([
          Uint8List.fromList([1, 2, 3]),
          Uint8List.fromList([4, 5, 6]),
        ]),
      );

      final result = await body.read(maxLength: 10).toList();
      expect(result.length, 2);
      expect(result[0], Uint8List.fromList([1, 2, 3]));
      expect(result[1], Uint8List.fromList([4, 5, 6]));
    });

    test('when contentLength is unknown and total bytes equal maxLength, '
        'then it returns all chunks without throwing', () async {
      final body = Body.fromDataStream(
        Stream.fromIterable([
          Uint8List.fromList([1, 2, 3]),
          Uint8List.fromList([4, 5]),
        ]),
      );

      final result = await body.read(maxLength: 8).toList();
      expect(result.length, 2);
    });

    test('when maxLength is not provided, '
        'then it returns the stream without size limit', () async {
      final largeData = Uint8List(10000);
      final body = Body.fromDataStream(Stream.value(largeData));

      final result = await body.read().toList();
      expect(result.first.length, 10000);
    });

    test('when stream exceeds maxLength on first chunk, '
        'then it throws MaxBodySizeExceeded', () async {
      final body = Body.fromDataStream(
        Stream.value(Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9, 10])),
      );

      expect(
        () async => await body.read(maxLength: 5).toList(),
        throwsA(isA<MaxBodySizeExceeded>()),
      );
    });

    test('when MaxBodySizeExceeded is thrown, '
        'then it contains the maxLength value', () {
      final body = Body.fromDataStream(
        Stream.value(Uint8List.fromList([1, 2, 3])),
        contentLength: 100,
      );

      try {
        body.read(maxLength: 50);
        fail('Expected MaxBodySizeExceeded');
      } on MaxBodySizeExceeded catch (e) {
        expect(e.maxLength, 50);
        expect(e.toString(), contains('50'));
      }
    });
  });

  group('Given Body.read without maxLength', () {
    test('when called twice, '
        'then it throws StateError on second call', () {
      final body = Body.fromString('test');

      body.read();

      expect(() => body.read(), throwsA(isA<StateError>()));
    });

    test('when called with maxLength twice, '
        'then it throws StateError on second call', () {
      final body = Body.fromString('test');

      body.read(maxLength: 100);

      expect(() => body.read(maxLength: 100), throwsA(isA<StateError>()));
    });
  });

  group('Given maxLength on a keep-alive connection', () {
    late RelicServer server;
    late HttpClient client;

    setUp(() {
      client = HttpClient();
      client.idleTimeout = const Duration(seconds: 30);
      client.maxConnectionsPerHost = 1;
    });

    tearDown(() async {
      client.close();
      await server.close();
    });

    test('when the first request body exceeds maxLength, '
        'then subsequent requests succeed', () async {
      const maxLength = 10;
      var requestCount = 0;

      server = RelicServer(() => IOAdapter.bind(InternetAddress.loopbackIPv4));

      await server.mountAndStart((final req) async {
        requestCount++;
        final body = await req.readAsString(maxLength: maxLength);
        return Response.ok(body: Body.fromString('Received: $body'));
      });

      final url = server.url;

      // First request: Send body larger than maxLength.
      final request1 = await client.postUrl(url);
      request1.add(List.filled(50, 65)); // 50 bytes of 'A', exceeds maxLength.
      final response1 = await request1.close();

      expect(response1.statusCode, HttpStatus.requestEntityTooLarge);
      await response1.drain<void>(); // <-- important, otherwise client hang!

      // Second request should still work
      final request2 = await client.postUrl(url);
      request2.add(List.filled(5, 66)); // 5 bytes of 'B', within maxLength.
      final response2 = await request2.close();

      expect(response2.statusCode, HttpStatus.ok);
      expect(requestCount, 2);
    });

    test('when chunked request body exceeds maxLength mid-stream, '
        'then subsequent requests succeed', () async {
      const maxLength = 10;
      var requestCount = 0;

      server = RelicServer(() => IOAdapter.bind(InternetAddress.loopbackIPv4));

      await server.mountAndStart((final req) async {
        requestCount++;
        final body = await req.readAsString(maxLength: maxLength);
        return Response.ok(body: Body.fromString('Received: $body'));
      });

      final url = server.url;

      // First request: chunked encoding, exceeds maxLength.
      final request1 = await client.postUrl(url);
      request1.headers.chunkedTransferEncoding = true;
      request1.bufferOutput = false;
      // Send multiple chunks that together exceed maxLength.
      request1.add(List.filled(5, 65)); // First chunk: 5 bytes.
      request1.add(List.filled(5, 65)); // Second chunk: 5 bytes.
      request1.add(List.filled(5, 65)); // Third chunk: exceeds limit.
      final response1 = await request1.close();

      expect(response1.statusCode, HttpStatus.requestEntityTooLarge);
      await response1.drain<void>();

      // Second request should still work
      final request2 = await client.postUrl(url);
      request2.add(List.filled(5, 66)); // 5 bytes, within limit.
      final response2 = await request2.close();

      expect(response2.statusCode, HttpStatus.ok);
      expect(requestCount, 2);
    });
  });
}
