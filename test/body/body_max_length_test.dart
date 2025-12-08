import 'dart:async';
import 'dart:typed_data';

import 'package:relic/src/body/body.dart';
import 'package:test/test.dart';

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
}
