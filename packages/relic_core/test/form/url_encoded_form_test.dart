import 'dart:convert';
import 'dart:typed_data';

import 'package:relic_core/relic_core.dart';
import 'package:test/test.dart';

void main() {
  group('Given a urlencoded form request', () {
    test(
      'when parsed, then fields are decoded in request body order',
      () async {
        final request = _request(body: 'name=Gustavo&city=Rome&name=Relic');

        final form = await request.urlEncodedForm();

        expect(form.fields.raw['name'], 'Gustavo');
        expect(form.fields.getAll(const StringFormField('name')), [
          'Gustavo',
          'Relic',
        ]);
        expect(form.fields.raw['city'], 'Rome');
        expect(form.entries, [
          const FormFieldEntry(name: 'name', value: 'Gustavo'),
          const FormFieldEntry(name: 'city', value: 'Rome'),
          const FormFieldEntry(name: 'name', value: 'Relic'),
        ]);
      },
    );

    test(
      'when values contain plus and percent escapes, then they are decoded',
      () async {
        final request = _request(body: 'name=Gustavo+Guzman&city=Napoli');

        final form = await request.urlEncodedForm();

        expect(form.fields.raw['name'], 'Gustavo Guzman');
        expect(form.fields.raw['city'], 'Napoli');
      },
    );

    test(
      'when values are empty or missing equals, then empty strings are used',
      () async {
        final request = _request(body: 'empty=&flag&=unnamed');

        final form = await request.urlEncodedForm();

        expect(form.entries, [
          const FormFieldEntry(name: 'empty', value: ''),
          const FormFieldEntry(name: 'flag', value: ''),
          const FormFieldEntry(name: '', value: 'unnamed'),
        ]);
      },
    );

    test('when the body is empty, then it returns no fields', () async {
      final request = _request(body: '');

      final form = await request.urlEncodedForm();

      expect(form.fields.entries, isEmpty);
      expect(form.entries, isEmpty);
    });
  });

  group('Given a latin1 urlencoded form request', () {
    test('when parsed, then the Content-Type charset is used', () async {
      final request = _request(
        bodyBytes: Uint8List.fromList(latin1.encode('name=Andr%E9')),
        contentType: ContentTypeHeader(
          mimeType: MimeType.urlEncoded,
          parameters: const {'charset': 'latin1'},
        ),
      );

      final form = await request.urlEncodedForm();

      expect(form.fields.raw['name'], 'André');
    });
  });

  test('Given a urlencoded form request without a charset, '
      'when parsed, '
      'then it decodes percent escapes as UTF-8.', () async {
    final request = _request(body: 'name=Andr%C3%A9');

    final form = await request.urlEncodedForm();

    expect(form.fields.raw['name'], 'André');
  });

  group('Given a request with an unsupported Content-Type', () {
    test(
      'when parsed as urlencoded form, then it throws UnsupportedFormMediaTypeException',
      () async {
        final request = _request(
          body: 'name=Gustavo',
          contentType: ContentTypeHeader(mimeType: MimeType.plainText),
        );

        await expectLater(
          request.urlEncodedForm(),
          throwsA(isA<UnsupportedFormMediaTypeException>()),
        );
      },
    );
  });

  group('Given a malformed urlencoded form request', () {
    test('when parsed, then it throws MalformedFormDataException', () async {
      final request = _request(body: 'name=%zz');

      await expectLater(
        request.urlEncodedForm(),
        throwsA(isA<MalformedFormDataException>()),
      );
    });
  });

  group('Given urlencoded form limits', () {
    test(
      'when maxBodySize is exceeded, then it throws MaxBodySizeExceeded',
      () async {
        final request = _request(body: 'name=Gustavo');

        await expectLater(
          request.urlEncodedForm(limits: FormLimits(maxBodySize: 4)),
          throwsA(isA<MaxBodySizeExceeded>()),
        );
      },
    );

    test(
      'when maxFieldCount is exceeded, then it throws FormLimitExceededException',
      () async {
        final request = _request(body: 'a=1&b=2');

        await expectLater(
          request.urlEncodedForm(limits: FormLimits(maxFieldCount: 1)),
          throwsA(
            isA<FormLimitExceededException>().having(
              (final error) => error.limit,
              'limit',
              'maxFieldCount',
            ),
          ),
        );
      },
    );

    test(
      'when maxFieldSize is exceeded, then it throws FormLimitExceededException',
      () async {
        final request = _request(body: 'name=Gustavo');

        await expectLater(
          request.urlEncodedForm(limits: FormLimits(maxFieldSize: 3)),
          throwsA(
            isA<FormLimitExceededException>().having(
              (final error) => error.limit,
              'limit',
              'maxFieldSize',
            ),
          ),
        );
      },
    );
  });

  group('Given a urlencoded form request body', () {
    test('when parsed, then the request body cannot be read again', () async {
      final request = _request(body: 'name=Gustavo');

      await request.urlEncodedForm();

      expect(() => request.readAsString(), throwsStateError);
      expect(() => request.read(), throwsStateError);
    });
  });

  test(
    'Given a urlencoded form request whose body has bytes that are not valid UTF-8, '
    'when parsed, '
    'then it throws MalformedFormDataException.',
    () async {
      final request = _request(
        bodyBytes: Uint8List.fromList([...utf8.encode('name='), 0xff, 0xfe]),
      );

      await expectLater(
        request.urlEncodedForm(),
        throwsA(isA<MalformedFormDataException>()),
      );
    },
  );

  test(
    'Given a US-ASCII urlencoded form request whose body has a non-ASCII byte, '
    'when parsed, '
    'then it throws MalformedFormDataException.',
    () async {
      final request = _request(
        bodyBytes: Uint8List.fromList([...ascii.encode('name='), 0xe9]),
        contentType: ContentTypeHeader(
          mimeType: MimeType.urlEncoded,
          parameters: const {'charset': 'us-ascii'},
        ),
      );

      await expectLater(
        request.urlEncodedForm(),
        throwsA(isA<MalformedFormDataException>()),
      );
    },
  );

  test(
    'Given a urlencoded form request whose body stream fails with a FormatException, '
    'when parsed, '
    'then it rethrows that FormatException unchanged.',
    () async {
      const upstream = FormatException('upstream');
      final request = RequestInternal.create(
        Method.post,
        Uri.parse('http://localhost/form'),
        Object(),
        body: Body.fromDataStream(
          Stream.error(upstream),
          mimeType: MimeType.urlEncoded,
        ),
      );

      await expectLater(request.urlEncodedForm(), throwsA(same(upstream)));
    },
  );

  test('Given a request with a urlencoded body and no Content-Type header, '
      'when parsed, '
      'then it returns the fields.', () async {
    final request = RequestInternal.create(
      Method.post,
      Uri.parse('http://localhost/form'),
      Object(),
      body: Body.fromString('name=Gustavo', mimeType: MimeType.urlEncoded),
    );

    final form = await request.urlEncodedForm();

    expect(form.fields.raw['name'], 'Gustavo');
  });
}

Request _request({
  final String? body,
  final Uint8List? bodyBytes,
  final ContentTypeHeader? contentType,
}) {
  return RequestInternal.create(
    Method.post,
    Uri.parse('http://localhost/form'),
    Object(),
    body: _bodyFromContentType(
      bodyBytes ?? Uint8List.fromList(utf8.encode(body ?? '')),
      contentType ?? ContentTypeHeader(mimeType: MimeType.urlEncoded),
    ),
  );
}

Body _bodyFromContentType(
  final Uint8List bytes,
  final ContentTypeHeader contentType,
) {
  return Body.fromData(
    bytes,
    mimeType: contentType.mimeType,
    encoding: Encoding.getByName(contentType.charset ?? ''),
    parameters: {
      for (final MapEntry(:key, :value) in contentType.parameters.entries)
        if (key != 'charset') key: value,
    },
  );
}
