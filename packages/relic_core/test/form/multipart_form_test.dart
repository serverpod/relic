import 'dart:convert';
import 'dart:typed_data';

import 'package:relic_core/relic_core.dart';
import 'package:test/test.dart';

void main() {
  group('Given a urlencoded form request', () {
    test(
      'when formData is parsed, then it returns UrlEncodedFormData',
      () async {
        final request = _urlEncodedRequest('name=Gustavo');

        final form = await request.formData();

        expect(form, isA<UrlEncodedFormData>());
        expect(form.fields.get('name'), 'Gustavo');
        expect(form.files.entries, isEmpty);
      },
    );
  });

  group('Given a multipart form request', () {
    test(
      'when formData is parsed, then it returns MultipartFormData',
      () async {
        final request = _multipartRequest(
          boundary: 'dispatch',
          body: _multipartBody('dispatch', [
            _Part(
              headers: const {
                Headers.contentDispositionHeader: 'form-data; name="name"',
              },
              body: 'Gustavo',
            ),
          ]),
        );

        final form = await request.formData();

        expect(form, isA<MultipartFormData>());
        expect(form.fields.get('name'), 'Gustavo');
      },
    );

    test(
      'when multipartForm is parsed, then fields and files are aggregated in order',
      () async {
        final request = _multipartRequest(
          boundary: 'aggregate',
          body: _multipartBody('aggregate', [
            _Part(
              headers: const {
                Headers.contentDispositionHeader: 'form-data; name="title"',
              },
              body: 'Report',
            ),
            _Part(
              headers: const {
                Headers.contentDispositionHeader:
                    'form-data; name="upload"; filename="report.txt"',
                Headers.contentTypeHeader: 'text/plain; charset=utf-8',
              },
              body: 'file-body',
            ),
            _Part(
              headers: const {
                Headers.contentDispositionHeader: 'form-data; name="tag"',
              },
              body: 'draft',
            ),
          ]),
        );

        final form = await request.multipartForm();
        final file = form.files.getRequired('upload') as MemoryUploadedFile;

        expect(form.fields.get('title'), 'Report');
        expect(form.fields.get('tag'), 'draft');
        expect(file.fieldName, 'upload');
        expect(file.filename, 'report.txt');
        expect(file.contentType?.mimeType, MimeType.plainText);
        expect(file.size, 9);
        expect(await utf8.decodeStream(file.openRead()), 'file-body');
        expect(form.entries.map((final entry) => entry.name), [
          'title',
          'upload',
          'tag',
        ]);
      },
    );

    test(
      'when duplicate files are parsed, then UploadedFiles preserves all values',
      () async {
        final request = _multipartRequest(
          boundary: 'dupe-files',
          body: _multipartBody('dupe-files', [
            _Part(
              headers: const {
                Headers.contentDispositionHeader:
                    'form-data; name="photo"; filename="one.txt"',
              },
              body: 'one',
            ),
            _Part(
              headers: const {
                Headers.contentDispositionHeader:
                    'form-data; name="photo"; filename="two.txt"',
              },
              body: 'two',
            ),
          ]),
        );

        final form = await request.multipartForm();

        expect(form.files.getAll('photo').map((final file) => file.filename), [
          'one.txt',
          'two.txt',
        ]);
      },
    );

    test('when a part has no name, then it is ignored', () async {
      final request = _multipartRequest(
        boundary: 'nameless',
        body: _multipartBody('nameless', [
          _Part(
            headers: const {
              Headers.contentDispositionHeader:
                  'form-data; filename="ignored.txt"',
            },
            body: 'ignored',
          ),
          _Part(
            headers: const {
              Headers.contentDispositionHeader: 'form-data; name="actual"',
            },
            body: 'value',
          ),
        ]),
      );

      final form = await request.multipartForm();

      expect(form.fields.get('actual'), 'value');
      expect(form.files.entries, isEmpty);
      expect(form.entries.map((final entry) => entry.name), ['actual']);
    });

    test('when a part is not form-data, then it is ignored', () async {
      final request = _multipartRequest(
        boundary: 'not-form-data',
        body: _multipartBody('not-form-data', [
          _Part(
            headers: const {
              Headers.contentDispositionHeader: 'attachment; name="ignored"',
            },
            body: 'ignored',
          ),
          _field('actual', 'value'),
        ]),
      );

      final form = await request.multipartForm();

      expect(form.fields.get('actual'), 'value');
      expect(form.fields.contains('ignored'), isFalse);
      expect(form.entries.map((final entry) => entry.name), ['actual']);
    });

    test(
      'when uploaded filename includes a path, then only basename is exposed',
      () async {
        final request = _multipartRequest(
          boundary: 'basename',
          body: _multipartBody('basename', [
            _Part(
              headers: const {
                Headers.contentDispositionHeader:
                    'form-data; name="upload"; filename="../../report.txt"',
              },
              body: 'file-body',
            ),
          ]),
        );

        final form = await request.multipartForm();

        expect(form.files.getRequired('upload').filename, 'report.txt');
      },
    );

    test(
      'when multipart filename is empty, then it is aggregated as a field',
      () async {
        final request = _multipartRequest(
          boundary: 'empty-file',
          body: _multipartBody('empty-file', [
            _Part(
              headers: const {
                Headers.contentDispositionHeader:
                    'form-data; name="upload"; filename=""',
              },
              body: '',
            ),
          ]),
        );

        final form = await request.multipartForm();

        expect(form.fields.get('upload'), '');
        expect(form.files.entries, isEmpty);
        expect(form.entries, [const FormFieldEntry(name: 'upload', value: '')]);
      },
    );
  });

  group('Given a multipart form request with latin1 field data', () {
    test(
      'when no part charset is present, then the default encoding is used',
      () async {
        final request = _multipartRequestBytes(
          boundary: 'latin-default',
          bodyBytes: _multipartBodyBytes('latin-default', [
            _PartBytes(
              headers: const {
                Headers.contentDispositionHeader: 'form-data; name="name"',
              },
              body: latin1.encode('André'),
            ),
          ]),
        );

        final form = await request.multipartForm(defaultEncoding: latin1);

        expect(form.fields.get('name'), 'André');
      },
    );
  });

  group('Given a multipart form with uploaded files', () {
    test('when disposed, then every uploaded file is disposed', () async {
      final request = _multipartRequest(
        boundary: 'dispose',
        body: _multipartBody('dispose', [
          _Part(
            headers: const {
              Headers.contentDispositionHeader:
                  'form-data; name="file"; filename="one.txt"',
            },
            body: 'one',
          ),
        ]),
      );

      final form = await request.multipartForm();
      final file = form.files.getRequired('file');

      await form.dispose();

      expect(file.size, isNull);
      expect(() => file.openRead(), throwsStateError);
    });
  });

  group('Given a request with an unsupported Content-Type', () {
    test(
      'when formData is parsed, then it throws UnsupportedFormMediaTypeException',
      () async {
        final request = RequestInternal.create(
          Method.post,
          Uri.parse('http://localhost/form'),
          Object(),
          headers: Headers.build(
            (final mh) => mh.contentType = ContentTypeHeader(
              mimeType: MimeType.plainText,
            ),
          ),
          body: Body.fromString('plain', mimeType: MimeType.plainText),
        );

        await expectLater(
          request.formData(),
          throwsA(isA<UnsupportedFormMediaTypeException>()),
        );
      },
    );

    test(
      'when multipartForm is parsed, then it throws UnsupportedFormMediaTypeException',
      () async {
        final request = RequestInternal.create(
          Method.post,
          Uri.parse('http://localhost/form'),
          Object(),
          headers: Headers.build(
            (final mh) => mh.contentType = ContentTypeHeader(
              mimeType: MimeType.plainText,
            ),
          ),
          body: Body.fromString('plain', mimeType: MimeType.plainText),
        );

        await expectLater(
          request.multipartForm(),
          throwsA(isA<UnsupportedFormMediaTypeException>()),
        );
      },
    );
  });

  group('Given multipart form limits', () {
    test(
      'when maxBodySize is exceeded, then it throws MaxBodySizeExceeded',
      () async {
        final request = _multipartRequest(
          boundary: 'body-size',
          body: _multipartBody('body-size', [_field('name', 'value')]),
        );

        await expectLater(
          request.multipartForm(limits: _limits(maxBodySize: 4)),
          throwsA(isA<MaxBodySizeExceeded>()),
        );
      },
    );

    test(
      'when maxPartCount is exceeded, then it throws FormLimitExceededException',
      () async {
        final request = _multipartRequest(
          boundary: 'parts',
          body: _multipartBody('parts', [
            _field('a', 'one'),
            _field('b', 'two'),
          ]),
        );

        await expectLater(
          request.multipartForm(limits: _limits(maxPartCount: 1)),
          throwsA(_limitExceeded('maxPartCount')),
        );
      },
    );

    test(
      'when maxFieldCount is exceeded, then it throws FormLimitExceededException',
      () async {
        final request = _multipartRequest(
          boundary: 'fields',
          body: _multipartBody('fields', [
            _field('a', 'one'),
            _field('b', 'two'),
          ]),
        );

        await expectLater(
          request.multipartForm(limits: _limits(maxFieldCount: 1)),
          throwsA(_limitExceeded('maxFieldCount')),
        );
      },
    );

    test(
      'when maxFileCount is exceeded, then it throws FormLimitExceededException',
      () async {
        final request = _multipartRequest(
          boundary: 'files',
          body: _multipartBody('files', [
            _file('upload', 'one.txt', 'one'),
            _file('upload', 'two.txt', 'two'),
          ]),
        );

        await expectLater(
          request.multipartForm(limits: _limits(maxFileCount: 1)),
          throwsA(_limitExceeded('maxFileCount')),
        );
      },
    );

    test(
      'when maxFieldSize is exceeded, then it throws FormLimitExceededException',
      () async {
        final request = _multipartRequest(
          boundary: 'field-size',
          body: _multipartBody('field-size', [_field('name', 'abcdef')]),
        );

        await expectLater(
          request.multipartForm(limits: _limits(maxFieldSize: 3)),
          throwsA(_limitExceeded('maxFieldSize')),
        );
      },
    );

    test(
      'when maxFileSize is exceeded, then it throws FormLimitExceededException',
      () async {
        final request = _multipartRequest(
          boundary: 'file-size',
          body: _multipartBody('file-size', [
            _file('upload', 'file.txt', 'abcdef'),
          ]),
        );

        await expectLater(
          request.multipartForm(limits: _limits(maxFileSize: 3)),
          throwsA(_limitExceeded('maxFileSize')),
        );
      },
    );

    test(
      'when maxTotalFileSize is exceeded, then it throws FormLimitExceededException',
      () async {
        final request = _multipartRequest(
          boundary: 'total-file-size',
          body: _multipartBody('total-file-size', [
            _file('upload', 'one.txt', '123'),
            _file('upload', 'two.txt', '456'),
          ]),
        );

        await expectLater(
          request.multipartForm(limits: _limits(maxTotalFileSize: 5)),
          throwsA(_limitExceeded('maxTotalFileSize')),
        );
      },
    );
  });

  group('Given multipart parsing fails after storing a file', () {
    test(
      'when parsing fails, then already stored files are disposed',
      () async {
        final storage = _RecordingUploadStorage();
        final request = _multipartRequest(
          boundary: 'cleanup',
          body: _multipartBody('cleanup', [
            _file('upload', 'one.txt', 'one'),
            _file('upload', 'two.txt', 'two'),
          ]),
        );

        await expectLater(
          request.multipartForm(
            limits: _limits(maxFileCount: 1),
            uploadStorage: storage,
          ),
          throwsA(_limitExceeded('maxFileCount')),
        );

        expect(storage.files, hasLength(1));
        expect(storage.files.single.disposed, isTrue);
      },
    );
  });

  group('Given a multipart form request body', () {
    test(
      'when multipartForm is parsed, then the request body cannot be read again',
      () async {
        final request = _multipartRequest(
          boundary: 'single-read',
          body: _multipartBody('single-read', [_field('name', 'value')]),
        );

        await request.multipartForm();

        expect(() => request.readAsString(), throwsStateError);
        expect(() => request.read(), throwsStateError);
      },
    );
  });
}

Request _urlEncodedRequest(final String body) {
  return RequestInternal.create(
    Method.post,
    Uri.parse('http://localhost/form'),
    Object(),
    headers: Headers.build(
      (final mh) =>
          mh.contentType = ContentTypeHeader(mimeType: MimeType.urlEncoded),
    ),
    body: Body.fromString(body, mimeType: MimeType.urlEncoded),
  );
}

Request _multipartRequest({
  required final String boundary,
  required final String body,
}) {
  return _multipartRequestBytes(
    boundary: boundary,
    bodyBytes: Uint8List.fromList(utf8.encode(body)),
  );
}

Request _multipartRequestBytes({
  required final String boundary,
  required final Uint8List bodyBytes,
}) {
  return RequestInternal.create(
    Method.post,
    Uri.parse('http://localhost/form'),
    Object(),
    headers: Headers.build(
      (final mh) => mh.contentType = ContentTypeHeader(
        mimeType: MimeType.multipartFormData,
        parameters: {'boundary': boundary},
      ),
    ),
    body: Body.fromData(bodyBytes, mimeType: MimeType.multipartFormData),
  );
}

String _multipartBody(final String boundary, final List<_Part> parts) {
  return utf8.decode(
    _multipartBodyBytes(boundary, [
      for (final part in parts)
        _PartBytes(headers: part.headers, body: utf8.encode(part.body)),
    ]),
  );
}

Uint8List _multipartBodyBytes(
  final String boundary,
  final List<_PartBytes> parts,
) {
  final bytes = BytesBuilder(copy: false);
  for (final part in parts) {
    bytes.add(utf8.encode('--$boundary\r\n'));
    for (final header in part.headers.entries) {
      bytes.add(utf8.encode('${header.key}: ${header.value}\r\n'));
    }
    bytes.add(utf8.encode('\r\n'));
    bytes.add(part.body);
    bytes.add(utf8.encode('\r\n'));
  }
  bytes.add(utf8.encode('--$boundary--\r\n'));
  return bytes.takeBytes();
}

_Part _field(final String name, final String value) {
  return _Part(
    headers: {Headers.contentDispositionHeader: 'form-data; name="$name"'},
    body: value,
  );
}

_Part _file(final String name, final String filename, final String content) {
  return _Part(
    headers: {
      Headers.contentDispositionHeader:
          'form-data; name="$name"; filename="$filename"',
    },
    body: content,
  );
}

FormLimits _limits({
  final int? maxBodySize,
  final int? maxPartCount,
  final int? maxFieldCount,
  final int? maxFileCount,
  final int? maxFieldSize,
  final int? maxFileSize,
  final int? maxTotalFileSize,
}) {
  const defaults = FormLimits.defaults;
  return FormLimits(
    maxBodySize: maxBodySize ?? defaults.maxBodySize,
    maxFieldCount: maxFieldCount ?? defaults.maxFieldCount,
    maxFileCount: maxFileCount ?? defaults.maxFileCount,
    maxPartCount: maxPartCount ?? defaults.maxPartCount,
    maxFieldSize: maxFieldSize ?? defaults.maxFieldSize,
    maxFileSize: maxFileSize ?? defaults.maxFileSize,
    maxTotalFileSize: maxTotalFileSize ?? defaults.maxTotalFileSize,
    maxPartHeaderSize: defaults.maxPartHeaderSize,
    maxBoundarySize: defaults.maxBoundarySize,
  );
}

Matcher _limitExceeded(final String limit) {
  return isA<FormLimitExceededException>().having(
    (final error) => error.limit,
    'limit',
    limit,
  );
}

final class _Part {
  final Map<String, String> headers;
  final String body;

  const _Part({required this.headers, required this.body});
}

final class _PartBytes {
  final Map<String, String> headers;
  final List<int> body;

  const _PartBytes({required this.headers, required this.body});
}

final class _RecordingUploadStorage implements UploadStorage {
  final files = <_RecordingUploadedFile>[];

  @override
  Future<UploadedFile> store({
    required final String fieldName,
    required final String? filename,
    required final ContentTypeHeader? contentType,
    required final Headers headers,
    required final Stream<Uint8List> content,
  }) async {
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in content) {
      bytes.add(chunk);
    }
    final file = _RecordingUploadedFile(
      fieldName: fieldName,
      filename: filename,
      contentType: contentType,
      headers: headers,
      bytes: bytes.takeBytes(),
    );
    files.add(file);
    return file;
  }
}

final class _RecordingUploadedFile implements UploadedFile {
  @override
  final String fieldName;

  @override
  final String? filename;

  @override
  final ContentTypeHeader? contentType;

  @override
  final Headers headers;

  final Uint8List bytes;

  bool disposed = false;

  _RecordingUploadedFile({
    required this.fieldName,
    required this.filename,
    required this.contentType,
    required this.headers,
    required this.bytes,
  });

  @override
  int? get size => disposed ? null : bytes.length;

  @override
  Stream<Uint8List> openRead() {
    if (disposed) throw StateError('Uploaded file has been disposed.');
    return Stream.value(bytes);
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}
