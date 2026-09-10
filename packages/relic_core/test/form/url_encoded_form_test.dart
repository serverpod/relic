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

        expect(form.fields.get('name'), 'Gustavo');
        expect(form.fields.getAll('name'), ['Gustavo', 'Relic']);
        expect(form.fields.get('city'), 'Rome');
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
        final request = _request(
          body: 'name=Gustavo+Guzman&city=Napoli',
        );

        final form = await request.urlEncodedForm();

        expect(form.fields.get('name'), 'Gustavo Guzman');
        expect(form.fields.get('city'), 'Napoli');
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

      expect(form.fields.get('name'), 'André');
    });

    test(
      'when no charset is present, then the default encoding is used',
      () async {
        final request = _request(
          bodyBytes: Uint8List.fromList(latin1.encode('name=Andr%E9')),
        );

        final form = await request.urlEncodedForm(defaultEncoding: latin1);

        expect(form.fields.get('name'), 'André');
      },
    );
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
          request.urlEncodedForm(limits: _limits(maxBodySize: 4)),
          throwsA(isA<MaxBodySizeExceeded>()),
        );
      },
    );

    test(
      'when maxFieldCount is exceeded, then it throws FormLimitExceededException',
      () async {
        final request = _request(body: 'a=1&b=2');

        await expectLater(
          request.urlEncodedForm(limits: _limits(maxFieldCount: 1)),
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
          request.urlEncodedForm(limits: _limits(maxFieldSize: 3)),
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
}

Request _request({
  final String? body,
  final Uint8List? bodyBytes,
  final ContentTypeHeader? contentType,
}) {
  final headers = Headers.build(
    (final mh) => mh.contentType =
        contentType ?? ContentTypeHeader(mimeType: MimeType.urlEncoded),
  );

  return RequestInternal.create(
    Method.post,
    Uri.parse('http://localhost/form'),
    Object(),
    headers: headers,
    body: Body.fromData(
      bodyBytes ?? Uint8List.fromList(utf8.encode(body ?? '')),
      mimeType: contentType?.mimeType ?? MimeType.urlEncoded,
    ),
  );
}

FormLimits _limits({
  final int? maxBodySize,
  final int? maxFieldCount,
  final int? maxFieldSize,
}) {
  const defaults = FormLimits.defaults;
  return FormLimits(
    maxBodySize: maxBodySize ?? defaults.maxBodySize,
    maxFieldCount: maxFieldCount ?? defaults.maxFieldCount,
    maxFileCount: defaults.maxFileCount,
    maxPartCount: defaults.maxPartCount,
    maxFieldSize: maxFieldSize ?? defaults.maxFieldSize,
    maxFileSize: defaults.maxFileSize,
    maxTotalFileSize: defaults.maxTotalFileSize,
    maxPartHeaderSize: defaults.maxPartHeaderSize,
    maxBoundarySize: defaults.maxBoundarySize,
  );
}
