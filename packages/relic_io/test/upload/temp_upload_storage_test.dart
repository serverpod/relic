import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:relic_core/relic_core.dart';
import 'package:relic_io/relic_io.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('relic_io_upload_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Given TempUploadStorage with a configured directory', () {
    test(
      'when content is stored, then it returns a temp uploaded file with metadata',
      () async {
        final storage = TempUploadStorage(directory: tempDir);
        final headers = Headers.build(
          (final mh) => mh.contentType = ContentTypeHeader(
            mimeType: MimeType.plainText,
            parameters: const {'charset': 'utf-8'},
          ),
        );

        final uploaded = await storage.store(
          fieldName: 'upload',
          filename: 'hello.txt',
          contentType: headers.contentType,
          headers: headers,
          content: Stream.value(Uint8List.fromList(utf8.encode('hello'))),
        );

        expect(uploaded, isA<TempUploadedFile>());
        expect(uploaded.fieldName, 'upload');
        expect(uploaded.filename, 'hello.txt');
        expect(uploaded.contentType?.mimeType, MimeType.plainText);
        expect(uploaded.headers, headers);
        expect(uploaded.size, 5);
        expect((uploaded as TempUploadedFile).path, startsWith(tempDir.path));
        expect(await File(uploaded.path).exists(), isTrue);
      },
    );

    test(
      'when the uploaded file is opened, then it streams the stored content',
      () async {
        final storage = TempUploadStorage(directory: tempDir);
        final uploaded = await storage.store(
          fieldName: 'upload',
          filename: 'hello.txt',
          contentType: null,
          headers: Headers.empty(),
          content: Stream.value(Uint8List.fromList(utf8.encode('hello'))),
        );

        expect(await utf8.decodeStream(uploaded.openRead()), 'hello');
      },
    );

    test('when disposed, then it deletes the temp file', () async {
      final storage = TempUploadStorage(directory: tempDir);
      final uploaded =
          await storage.store(
                fieldName: 'upload',
                filename: 'hello.txt',
                contentType: null,
                headers: Headers.empty(),
                content: Stream.value(Uint8List.fromList(utf8.encode('hello'))),
              )
              as TempUploadedFile;

      await uploaded.dispose();

      expect(uploaded.size, isNull);
      expect(await File(uploaded.path).exists(), isFalse);
      expect(() => uploaded.openRead(), throwsStateError);
    });
  });

  group('Given TempUploadStorage without a configured directory', () {
    test(
      'when content is stored, then it creates a system temp file',
      () async {
        final storage = TempUploadStorage(directoryPrefix: 'relic_io_default_');
        final uploaded =
            await storage.store(
                  fieldName: 'upload',
                  filename: 'hello.txt',
                  contentType: null,
                  headers: Headers.empty(),
                  content: Stream.value(
                    Uint8List.fromList(utf8.encode('hello')),
                  ),
                )
                as TempUploadedFile;

        try {
          expect(uploaded.path, contains('relic_io_default_'));
          expect(await File(uploaded.path).exists(), isTrue);
        } finally {
          await uploaded.dispose();
          final parent = File(uploaded.path).parent;
          if (await parent.exists()) {
            await parent.delete(recursive: true);
          }
        }
      },
    );
  });

  group('Given TempUploadStorage used by multipartForm', () {
    test(
      'when a multipart upload is parsed, then uploaded files are backed by temp files',
      () async {
        final request = _multipartRequest(
          boundary: 'upload',
          body: _multipartBody('upload', [
            _Part(
              headers: const {
                Headers.contentDispositionHeader:
                    'form-data; name="file"; filename="hello.txt"',
                Headers.contentTypeHeader: 'text/plain; charset=utf-8',
              },
              body: 'hello',
            ),
          ]),
        );

        final form = await request.multipartForm(
          uploadStorage: TempUploadStorage(directory: tempDir),
        );
        final uploaded = form.files.getRequired('file') as TempUploadedFile;

        expect(uploaded.path, startsWith(tempDir.path));
        expect(await utf8.decodeStream(uploaded.openRead()), 'hello');

        await form.dispose();

        expect(await File(uploaded.path).exists(), isFalse);
      },
    );
  });

  group('Given TempUploadStorage receives a failing stream', () {
    test('when storing fails, then the partial file is deleted', () async {
      final storage = TempUploadStorage(directory: tempDir);
      final controller = StreamController<Uint8List>();
      final storing = storage.store(
        fieldName: 'upload',
        filename: 'hello.txt',
        contentType: null,
        headers: Headers.empty(),
        content: controller.stream,
      );

      controller.add(Uint8List.fromList(utf8.encode('partial')));
      controller.addError(Exception('boom'));
      await controller.close();

      await expectLater(storing, throwsA(isA<Exception>()));
      expect(await tempDir.list().toList(), isEmpty);
    });
  });
}

Request _multipartRequest({
  required final String boundary,
  required final String body,
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
    body: Body.fromData(
      Uint8List.fromList(utf8.encode(body)),
      mimeType: MimeType.multipartFormData,
    ),
  );
}

String _multipartBody(final String boundary, final List<_Part> parts) {
  final buffer = StringBuffer();
  for (final part in parts) {
    buffer.write('--$boundary\r\n');
    for (final header in part.headers.entries) {
      buffer.write('${header.key}: ${header.value}\r\n');
    }
    buffer.write('\r\n');
    buffer.write(part.body);
    buffer.write('\r\n');
  }
  buffer.write('--$boundary--\r\n');
  return buffer.toString();
}

final class _Part {
  final Map<String, String> headers;
  final String body;

  const _Part({required this.headers, required this.body});
}
