import 'dart:convert';
import 'dart:typed_data';

import 'package:async/async.dart';
import 'package:relic_core/relic_core.dart';
import 'package:test/test.dart';

void main() {
  group('Given a multipart form request', () {
    test(
      'when streamed, then field and file parts are exposed in order',
      () async {
        final request = _request(
          boundary: 'abc123',
          body: _multipartBody('abc123', [
            _Part(
              headers: const {
                Headers.contentDispositionHeader: 'form-data; name="text"',
              },
              body: 'hello',
            ),
            _Part(
              headers: const {
                Headers.contentDispositionHeader:
                    'form-data; name="upload"; filename="file.txt"',
                Headers.contentTypeHeader: 'text/plain; charset=utf-8',
              },
              body: 'file-body',
            ),
          ]),
        );

        final parts = <MultipartPart>[];
        final bodies = <String>[];
        await for (final part in request.multipart()) {
          parts.add(part);
          bodies.add(await part.readAsString());
        }

        expect(parts, [
          isA<MultipartFieldPart>()
              .having((final p) => p.name, 'name', 'text')
              .having((final p) => p.contentType, 'contentType', isNull),
          isA<MultipartFilePart>()
              .having((final p) => p.name, 'name', 'upload')
              .having((final p) => p.filename, 'filename', 'file.txt')
              .having(
                (final p) => p.contentType?.mimeType,
                'contentType.mimeType',
                MimeType.plainText,
              ),
        ]);
        expect(bodies, ['hello', 'file-body']);
      },
    );

    test(
      'when duplicate names are streamed, then names are preserved',
      () async {
        final request = _request(
          boundary: 'dupes',
          body: _multipartBody('dupes', [
            _Part(
              headers: const {
                Headers.contentDispositionHeader: 'form-data; name="tag"',
              },
              body: 'one',
            ),
            _Part(
              headers: const {
                Headers.contentDispositionHeader: 'form-data; name="tag"',
              },
              body: 'two',
            ),
          ]),
        );

        final names = <String>[];
        final values = <String>[];
        await for (final part in request.multipart()) {
          names.add((part as MultipartFieldPart).name);
          values.add(await part.readAsString());
        }

        expect(names, ['tag', 'tag']);
        expect(values, ['one', 'two']);
      },
    );

    test('when a part has no name, then it can be discarded', () async {
      final request = _request(
        boundary: 'unnamed',
        body: _multipartBody('unnamed', [
          _Part(
            headers: const {
              Headers.contentDispositionHeader:
                  'form-data; filename="file.txt"',
            },
            body: 'ignored',
          ),
        ]),
      );

      await for (final part in request.multipart()) {
        expect(part, isA<MultipartOtherPart>());
        await part.discard();
      }
    });

    test(
      'when a file name contains path separators, then only basename is used',
      () async {
        final request = _request(
          boundary: 'filename-path',
          body: _multipartBody('filename-path', [
            _Part(
              headers: const {
                Headers.contentDispositionHeader:
                    'form-data; name="upload"; filename="..\\\\..\\\\evil.txt"',
              },
              body: 'file-body',
            ),
            _Part(
              headers: const {
                Headers.contentDispositionHeader:
                    'form-data; name="upload"; filename="../../other.txt"',
              },
              body: 'file-body',
            ),
          ]),
        );

        final filenames = <String?>[];
        await for (final part in request.multipart()) {
          filenames.add((part as MultipartFilePart).filename);
          await part.discard();
        }

        expect(filenames, ['evil.txt', 'other.txt']);
      },
    );

    test(
      'when regular and extended file names are present, then extended wins',
      () async {
        final request = _request(
          boundary: 'extended-filename',
          body: _multipartBody('extended-filename', [
            _Part(
              headers: const {
                Headers.contentDispositionHeader:
                    "form-data; name=\"upload\"; filename=\"plain.txt\"; filename*=UTF-8''extended%20name.txt",
              },
              body: 'file-body',
            ),
          ]),
        );

        await for (final part in request.multipart()) {
          expect(
            part,
            isA<MultipartFilePart>().having(
              (final p) => p.filename,
              'filename',
              'extended name.txt',
            ),
          );
          await part.discard();
        }
      },
    );
  });

  test('Given a multipart file part with an empty filename, '
      'when the request is streamed, '
      'then the part is a file part without a filename.', () async {
    final request = _request(
      boundary: 'empty-filename',
      body: _multipartBody('empty-filename', [
        _Part(
          headers: const {
            Headers.contentDispositionHeader:
                'form-data; name="upload"; filename=""',
          },
          body: '',
        ),
      ]),
    );

    final parts = await request.multipart().toList();

    expect(parts, [
      isA<MultipartFilePart>().having(
        (final p) => p.filename,
        'filename',
        isNull,
      ),
    ]);
  });

  test('Given a multipart file part with an empty filename, '
      'when the request is streamed, '
      'then hasEmptyFilename is true.', () async {
    final request = _request(
      boundary: 'empty-filename-flag',
      body: _multipartBody('empty-filename-flag', [
        _Part(
          headers: const {
            Headers.contentDispositionHeader:
                'form-data; name="upload"; filename=""',
          },
          body: '',
        ),
      ]),
    );

    final parts = await request.multipart().toList();

    expect(parts, [
      isA<MultipartFilePart>().having(
        (final p) => p.hasEmptyFilename,
        'hasEmptyFilename',
        isTrue,
      ),
    ]);
  });

  test('Given a multipart file part with the filename "..", '
      'when the request is streamed, '
      'then hasEmptyFilename is false.', () async {
    final request = _request(
      boundary: 'dotdot-filename-flag',
      body: _multipartBody('dotdot-filename-flag', [
        _Part(
          headers: const {
            Headers.contentDispositionHeader:
                'form-data; name="upload"; filename=".."',
          },
          body: '',
        ),
      ]),
    );

    final parts = await request.multipart().toList();

    expect(parts, [
      isA<MultipartFilePart>().having(
        (final p) => p.hasEmptyFilename,
        'hasEmptyFilename',
        isFalse,
      ),
    ]);
  });

  group('Given a multipart request with a latin1 text part', () {
    test('when the part is read as text, then its charset is used', () async {
      final request = _request(
        boundary: 'latin',
        bodyBytes: _multipartBodyBytes('latin', [
          _PartBytes(
            headers: const {
              Headers.contentDispositionHeader: 'form-data; name="name"',
              Headers.contentTypeHeader: 'text/plain; charset=latin1',
            },
            body: latin1.encode('André'),
          ),
        ]),
      );

      await for (final part in request.multipart()) {
        expect(await part.readAsString(), 'André');
      }
    });
  });

  group('Given a non-multipart request', () {
    test(
      'when streamed as multipart, then it throws UnsupportedFormMediaTypeException',
      () async {
        final request = _request(
          boundary: 'abc123',
          body: 'plain',
          contentType: ContentTypeHeader(mimeType: MimeType.plainText),
        );

        await expectLater(
          request.multipart().drain<void>(),
          throwsA(isA<UnsupportedFormMediaTypeException>()),
        );
      },
    );
  });

  group('Given a multipart request without a boundary', () {
    test('when streamed, then it throws MalformedFormDataException', () async {
      final request = _request(boundary: null, body: '--abc123--\r\n');

      await expectLater(
        request.multipart().drain<void>(),
        throwsA(isA<MalformedFormDataException>()),
      );
    });
  });

  group('Given a malformed multipart request', () {
    test('when streamed, then it throws MalformedFormDataException', () async {
      final request = _request(
        boundary: 'abc123',
        body: '--abc123\r\nContent-Disposition: form-data; name="a"\r\n',
      );

      await expectLater(
        request.multipart().drain<void>(),
        throwsA(isA<MalformedFormDataException>()),
      );
    });

    test(
      'when a disposition header is invalid, then it throws MalformedFormDataException',
      () async {
        final request = _request(
          boundary: 'bad-disposition',
          body: _multipartBody('bad-disposition', [
            _Part(
              headers: const {
                Headers.contentDispositionHeader: 'form-data; name="a" evil',
              },
              body: 'value',
            ),
          ]),
        );

        await expectLater(
          request.multipart().drain<void>(),
          throwsA(isA<MalformedFormDataException>()),
        );
      },
    );

    test(
      'when a part Content-Type is invalid, then it throws MalformedFormDataException',
      () async {
        final request = _request(
          boundary: 'bad-content-type',
          body: _multipartBody('bad-content-type', [
            _Part(
              headers: const {
                Headers.contentDispositionHeader: 'form-data; name="a"',
                Headers.contentTypeHeader: 'not-a-content-type',
              },
              body: 'value',
            ),
          ]),
        );

        await expectLater(
          request.multipart().drain<void>(),
          throwsA(isA<MalformedFormDataException>()),
        );
      },
    );
  });

  group('Given multipart limits', () {
    test(
      'when maxBodySize is exceeded, then it throws MaxBodySizeExceeded',
      () async {
        final request = _request(
          boundary: 'size',
          body: _multipartBody('size', [
            _Part(
              headers: const {
                Headers.contentDispositionHeader: 'form-data; name="a"',
              },
              body: 'value',
            ),
          ]),
        );

        await expectLater(
          request.multipart(limits: FormLimits(maxBodySize: 4)).drain<void>(),
          throwsA(isA<MaxBodySizeExceeded>()),
        );
      },
    );

    test(
      'when maxBoundarySize is exceeded, then it throws FormLimitExceededException',
      () async {
        final request = _request(boundary: 'abcdef', body: '');

        await expectLater(
          request
              .multipart(limits: FormLimits(maxBoundarySize: 3))
              .drain<void>(),
          throwsA(
            isA<FormLimitExceededException>().having(
              (final error) => error.limit,
              'limit',
              'maxBoundarySize',
            ),
          ),
        );
      },
    );

    test(
      'when maxPartCount is exceeded, then it throws FormLimitExceededException',
      () async {
        final request = _request(
          boundary: 'parts',
          body: _multipartBody('parts', [
            _Part(
              headers: const {
                Headers.contentDispositionHeader: 'form-data; name="a"',
              },
              body: 'one',
            ),
            _Part(
              headers: const {
                Headers.contentDispositionHeader: 'form-data; name="b"',
              },
              body: 'two',
            ),
          ]),
        );

        final queue = StreamQueue(
          request.multipart(limits: FormLimits(maxPartCount: 1)),
        );

        final first = await queue.next;
        await first.discard();
        await expectLater(
          queue.next,
          throwsA(
            isA<FormLimitExceededException>().having(
              (final error) => error.limit,
              'limit',
              'maxPartCount',
            ),
          ),
        );
      },
    );

    test(
      'when maxPartHeaderSize is exceeded, then it throws FormLimitExceededException',
      () async {
        final request = _request(
          boundary: 'headers',
          body: _multipartBody('headers', [
            _Part(
              headers: const {
                Headers.contentDispositionHeader: 'form-data; name="large"',
                'x-large-header': '123456789',
              },
              body: 'value',
            ),
          ]),
        );

        await expectLater(
          request
              .multipart(limits: FormLimits(maxPartHeaderSize: 8))
              .drain<void>(),
          throwsA(
            isA<FormLimitExceededException>().having(
              (final error) => error.limit,
              'limit',
              'maxPartHeaderSize',
            ),
          ),
        );
      },
    );

    test(
      'when a part read exceeds maxLength, then it throws MaxBodySizeExceeded',
      () async {
        final request = _request(
          boundary: 'field-size',
          body: _multipartBody('field-size', [
            _Part(
              headers: const {
                Headers.contentDispositionHeader: 'form-data; name="a"',
              },
              body: 'abcdef',
            ),
          ]),
        );

        await for (final part in request.multipart()) {
          await expectLater(
            part.readAsString(maxLength: 3),
            throwsA(isA<MaxBodySizeExceeded>()),
          );
        }
      },
    );
  });

  group('Given a streamed multipart part', () {
    test('when its body is read twice, then it throws StateError', () async {
      final request = _request(
        boundary: 'single',
        body: _multipartBody('single', [
          _Part(
            headers: const {
              Headers.contentDispositionHeader: 'form-data; name="a"',
            },
            body: 'value',
          ),
        ]),
      );

      await for (final part in request.multipart()) {
        expect(await part.readAsString(), 'value');
        expect(() => part.readAsString(), throwsStateError);
      }
    });
  });

  group('Given a multipart request body', () {
    test('when streamed, then the request body cannot be read again', () async {
      final request = _request(
        boundary: 'request-body',
        body: _multipartBody('request-body', [
          _Part(
            headers: const {
              Headers.contentDispositionHeader: 'form-data; name="a"',
            },
            body: 'value',
          ),
        ]),
      );

      await for (final part in request.multipart()) {
        await part.discard();
      }

      expect(() => request.readAsString(), throwsStateError);
      expect(() => request.read(), throwsStateError);
    });
  });

  test('Given a multipart part whose body has bytes that are not valid UTF-8, '
      'when the part is read as a string, '
      'then it throws MalformedFormDataException.', () async {
    final request = _request(
      boundary: 'bad-utf8',
      bodyBytes: _multipartBodyBytes('bad-utf8', [
        const _PartBytes(
          headers: {Headers.contentDispositionHeader: 'form-data; name="name"'},
          body: [0xff, 0xfe],
        ),
      ]),
    );
    final part = await request.multipart().first;

    await expectLater(
      part.readAsString(),
      throwsA(isA<MalformedFormDataException>()),
    );
  });

  test('Given a multipart part without a Content-Disposition header, '
      'when the request is streamed, '
      'then the part is a MultipartOtherPart.', () async {
    final request = _request(
      boundary: 'no-disposition',
      body: _multipartBody('no-disposition', [
        const _Part(
          headers: {Headers.contentTypeHeader: 'text/plain'},
          body: 'value',
        ),
      ]),
    );

    final parts = await request.multipart().toList();

    expect(parts, [isA<MultipartOtherPart>()]);
  });

  test('Given a named multipart part with an attachment disposition, '
      'when the request is streamed, '
      'then the part is a MultipartOtherPart.', () async {
    final request = _request(
      boundary: 'attachment',
      body: _multipartBody('attachment', [
        const _Part(
          headers: {
            Headers.contentDispositionHeader:
                'attachment; name="upload"; filename="file.txt"',
          },
          body: 'value',
        ),
      ]),
    );

    final parts = await request.multipart().toList();

    expect(parts, [isA<MultipartOtherPart>()]);
  });

  test('Given a named multipart part whose filename is only a directory path, '
      'when the request is streamed, '
      'then the part is a MultipartFilePart without a filename.', () async {
    final request = _request(
      boundary: 'directory-filename',
      body: _multipartBody('directory-filename', [
        const _Part(
          headers: {
            Headers.contentDispositionHeader:
                'form-data; name="upload"; filename="uploads/"',
          },
          body: 'value',
        ),
      ]),
    );

    final parts = await request.multipart().toList();

    expect(parts, [
      isA<MultipartFilePart>().having(
        (final p) => p.filename,
        'filename',
        isNull,
      ),
    ]);
  });
}

Request _request({
  required final String? boundary,
  final String? body,
  final Uint8List? bodyBytes,
  ContentTypeHeader? contentType,
}) {
  contentType ??= ContentTypeHeader(
    mimeType: MimeType.multipartFormData,
    parameters: {if (boundary != null) 'boundary': boundary},
  );

  return RequestInternal.create(
    Method.post,
    Uri.parse('http://localhost/form'),
    Object(),
    body: _bodyFromContentType(
      bodyBytes ?? Uint8List.fromList(utf8.encode(body ?? '')),
      contentType,
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
