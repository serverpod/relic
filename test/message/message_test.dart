import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:relic/relic.dart';
import 'package:relic/src/message/message.dart';
import 'package:test/test.dart';

import '../util/test_util.dart';

class _TestMessage extends Message {
  _TestMessage(
    final Headers? headers,
    final Map<String, Object>? context, {
    final Body? body,
  }) : super(headers: headers ?? Headers.empty(), body: body ?? Body.empty());

  @override
  Message copyWith({
    final Headers? headers,
    final Map<String, Object>? context,
    final Body? body,
  }) {
    throw UnimplementedError();
  }
}

Message _createMessage({
  final Headers? headers,
  final Map<String, Object>? context,
  final Body? body,
}) {
  return _TestMessage(headers, context, body: body);
}

void main() {
  group('Given message headers', () {
    test('when accessed then they are case insensitive', () {
      final message = _createMessage(
        headers: Headers.build((final mh) => mh['foo'] = ['bar']),
      );

      expect(message.headers, containsPair('foo', ['bar']));
      expect(message.headers, containsPair('Foo', ['bar']));
      expect(message.headers, containsPair('FOO', ['bar']));
    });

    test('when modified then they are immutable', () {
      final message = _createMessage(
        headers: Headers.build((final mh) => mh['foo'] = ['bar']),
      );
      expect(() => message.headers['h1'] = ['value1'], throwsUnsupportedError);
      expect(() => message.headers['h1'] = ['value2'], throwsUnsupportedError);
      expect(() => message.headers['h2'] = ['value2'], throwsUnsupportedError);
    });

    test('when containing multiple values then they are handled correctly', () {
      final message = _createMessage(
        headers: Headers.build((final mh) {
          mh['a'] = ['A'];
          mh['b'] = ['B1', 'B2'];
        }),
      );

      expect(message.headers, {
        'a': ['A'],
        'b': ['B1', 'B2'],
      });
    });
  });

  group('Given readAsString', () {
    test('when the body is null then it returns an empty string', () {
      final request = _createMessage();
      expect(request.readAsString(), completion(equals('')));
    });

    test('when the body is a Stream<Uint8List> then it reads correctly', () {
      final controller = StreamController<Uint8List>();
      final request = _createMessage(
        body: Body.fromDataStream(controller.stream),
      );
      expect(request.readAsString(), completion(equals('hello, world')));

      controller.add(helloBytes);
      return Future(() {
        controller
          ..add(worldBytes)
          ..close();
      });
    });

    test('when no encoding is specified then it defaults to UTF-8', () {
      final request = _createMessage(
        body: Body.fromData(Uint8List.fromList([195, 168])),
      );
      expect(request.readAsString(), completion(equals('è')));
    });
  });

  group('Given read', () {
    test('when the body is null then it returns an empty list', () {
      final request = _createMessage();
      expect(request.read().toList(), completion(isEmpty));
    });

    test('when the body is a Stream<Uint8List> then it reads correctly', () {
      final controller = StreamController<Uint8List>();
      final request = _createMessage(
        body: Body.fromDataStream(controller.stream),
      );
      expect(
        request.read().toList(),
        completion(equals([helloBytes, worldBytes])),
      );

      controller.add(helloBytes);
      return Future(() {
        controller
          ..add(worldBytes)
          ..close();
      });
    });

    test('when the body is a List<int> then it reads correctly', () {
      final request = _createMessage(body: Body.fromData(helloBytes));
      expect(request.read().toList(), completion(equals([helloBytes])));
    });

    test(
      'when read()/readAsString() is called multiple times then it throws a StateError',
      () {
        Message request;

        request = _createMessage();
        expect(request.read().toList(), completion(isEmpty));
        expect(() => request.read(), throwsStateError);

        request = _createMessage();
        expect(request.readAsString(), completion(isEmpty));
        expect(() => request.readAsString(), throwsStateError);

        request = _createMessage();
        expect(request.readAsString(), completion(isEmpty));
        expect(() => request.read(), throwsStateError);

        request = _createMessage();
        expect(request.read().toList(), completion(isEmpty));
        expect(() => request.readAsString(), throwsStateError);
      },
    );
  });

  group('Given content-length', () {
    test(
      'when the body is default and no content-length header is present then it is 0',
      () {
        final request = _createMessage();
        expect(request.body.contentLength, 0);
      },
    );

    test('when the body is a byte body then it is set correctly', () {
      final request = _createMessage(
        body: Body.fromData(Uint8List.fromList([1, 2, 3])),
      );
      expect(request.body.contentLength, 3);
    });

    test('when the body is a string then it is set correctly', () {
      final request = _createMessage(body: Body.fromString('foobar'));
      expect(request.body.contentLength, 6);
    });

    test('when the body is a string then it is set based on byte length', () {
      var request = _createMessage(body: Body.fromString('fööbär'));
      expect(request.body.contentLength, 9);

      request = _createMessage(
        body: Body.fromString('fööbär', encoding: latin1),
      );
      expect(request.body.contentLength, 6);
    });

    test('when the body is a stream then it is null', () {
      final request = _createMessage(
        body: Body.fromDataStream(const Stream.empty()),
      );
      expect(request.body.contentLength, isNull);
    });

    test('when identity transfer encoding is set then it is set correctly', () {
      final request = _createMessage(
        body: Body.fromString('1\r\na0\r\n\r\n'),
        headers: Headers.build(
          (final mh) =>
              mh.transferEncoding = TransferEncodingHeader(
                encodings: [TransferEncoding.identity],
              ),
        ),
      );
      expect(request.body.contentLength, equals(9));
    });
  });

  group('Given encoding', () {
    test('when no content-type header is present then it defaults to utf8', () {
      expect(_createMessage(body: Body.fromString('')).encoding, utf8);
    });

    test('when encoding a String then it defaults to UTF-8', () {
      expect(
        _createMessage(body: Body.fromString('è')).read().toList(),
        completion(
          equals([
            [195, 168],
          ]),
        ),
      );
    });

    test('when an explicit encoding is available then it uses it', () {
      expect(
        _createMessage(
          body: Body.fromString('è', encoding: latin1),
        ).read().toList(),
        completion(
          equals([
            [232],
          ]),
        ),
      );
    });
  });
}
