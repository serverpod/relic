import 'dart:convert';
import 'dart:typed_data';

import 'package:relic_core/relic_core.dart';
import 'package:test/test.dart';

void main() {
  group('Given FormLimits defaults', () {
    test('when accessed, '
        'then they expose conservative positive limits', () {
      const limits = FormLimits.defaults;

      expect(limits.maxBodySize, 10 * 1024 * 1024);
      expect(limits.maxFieldCount, 100);
      expect(limits.maxFileCount, 8);
      expect(limits.maxPartCount, 128);
      expect(limits.maxFieldSize, 64 * 1024);
      expect(limits.maxFileSize, 10 * 1024 * 1024);
      expect(limits.maxTotalFileSize, 10 * 1024 * 1024);
      expect(limits.maxPartHeaderSize, 8 * 1024);
      expect(limits.maxBoundarySize, 200);
    });
  });

  group('Given form exceptions', () {
    test('when created, '
        'then they expose messages and status codes', () {
      const unsupported = UnsupportedFormMediaTypeException('unsupported');
      const malformed = MalformedFormDataException('malformed');
      const limitExceeded = FormLimitExceededException(
        limit: 'maxFieldSize',
        message: 'too large',
      );

      expect(unsupported.message, 'unsupported');
      expect(unsupported.statusCode, 415);
      expect(unsupported.toString(), 'unsupported');

      expect(malformed.message, 'malformed');
      expect(malformed.statusCode, 400);
      expect(malformed.toString(), 'malformed');

      expect(limitExceeded.message, 'too large');
      expect(limitExceeded.limit, 'maxFieldSize');
      expect(limitExceeded.statusCode, 413);
      expect(limitExceeded.toString(), 'too large');
    });
  });

  group('Given FormFields with duplicate names', () {
    test('when queried, '
        'then order and duplicate values are preserved', () {
      final fields = FormFields([
        const FormFieldEntry(name: 'name', value: 'first'),
        const FormFieldEntry(name: 'role', value: 'admin'),
        const FormFieldEntry(name: 'name', value: 'second'),
      ]);

      expect(fields.entries.map((final e) => e.name), ['name', 'role', 'name']);
      expect(fields.get('name'), 'first');
      expect(fields.getRequired('role'), 'admin');
      expect(fields.getAll('name'), ['first', 'second']);
      expect(fields.contains('name'), isTrue);
      expect(fields.contains('missing'), isFalse);
      expect(() => fields.getRequired('missing'), throwsStateError);
    });

    test('when the source list changes after construction, '
        'then entries are unchanged', () {
      final source = [const FormFieldEntry(name: 'name', value: 'first')];
      final fields = FormFields(source);

      source.add(const FormFieldEntry(name: 'name', value: 'second'));

      expect(fields.getAll('name'), ['first']);
    });

    test('when the entries list is mutated, '
        'then it throws UnsupportedError', () {
      final fields = FormFields([
        const FormFieldEntry(name: 'name', value: 'first'),
      ]);

      expect(
        () => fields.entries.add(const FormFieldEntry(name: 'x', value: 'y')),
        throwsUnsupportedError,
      );
    });
  });

  group('Given UrlEncodedFormData', () {
    test('when created, '
        'then files are empty and entries mirror fields', () {
      final field = const FormFieldEntry(name: 'name', value: 'Gustavo');
      final form = UrlEncodedFormData(fields: FormFields([field]));

      expect(form.fields.get('name'), 'Gustavo');
      expect(form.files.entries, isEmpty);
      expect(form.entries, [field]);
    });
  });

  group('Given UploadedFiles with duplicate names', () {
    test('when queried, '
        'then order and duplicate files are preserved', () {
      final file1 = _file(fieldName: 'avatar', bytes: 'one');
      final file2 = _file(fieldName: 'attachment', bytes: 'two');
      final file3 = _file(fieldName: 'avatar', bytes: 'three');
      final files = UploadedFiles([
        FileFieldEntry(name: 'avatar', file: file1),
        FileFieldEntry(name: 'attachment', file: file2),
        FileFieldEntry(name: 'avatar', file: file3),
      ]);

      expect(files.entries.map((final e) => e.name), [
        'avatar',
        'attachment',
        'avatar',
      ]);
      expect(files.get('avatar'), same(file1));
      expect(files.getRequired('attachment'), same(file2));
      expect(files.getAll('avatar'), [file1, file3]);
      expect(files.contains('avatar'), isTrue);
      expect(files.contains('missing'), isFalse);
      expect(() => files.getRequired('missing'), throwsStateError);
    });
  });

  group('Given MultipartFormData', () {
    test('when created, '
        'then it preserves mixed entry order', () {
      final field = const FormFieldEntry(name: 'title', value: 'Report');
      final file = _file(fieldName: 'upload', bytes: 'file-body');
      final fileEntry = FileFieldEntry(name: 'upload', file: file);
      final form = MultipartFormData(
        fields: FormFields([field]),
        files: UploadedFiles([fileEntry]),
        entries: [field, fileEntry],
      );

      expect(form.entries, [field, fileEntry]);
      expect(form.fields.get('title'), 'Report');
      expect(form.files.get('upload'), same(file));
    });

    test('when disposed, '
        'then uploaded files are disposed', () async {
      final file = _file(fieldName: 'upload', bytes: 'file-body');
      final form = MultipartFormData(
        fields: FormFields.empty,
        files: UploadedFiles([FileFieldEntry(name: 'upload', file: file)]),
        entries: [FileFieldEntry(name: 'upload', file: file)],
      );

      await form.dispose();

      expect(file.size, isNull);
      expect(() => file.openRead(), throwsStateError);
    });
  });

  group('Given MemoryUploadStorage', () {
    test('when storing content, '
        'then it returns an uploaded file with metadata', () async {
      final stored = await _storeMemoryUpload();

      expect(stored.file.fieldName, 'upload');
      expect(stored.file.filename, 'hello.txt');
      expect(stored.file.contentType, stored.contentType);
      expect(stored.file.headers, stored.headers);
      expect(stored.file.size, 5);
    });

    test('when opening the stored upload, '
        'then it streams the stored bytes', () async {
      final stored = await _storeMemoryUpload();

      expect(await utf8.decodeStream(stored.file.openRead()), 'hello');
    });

    test('when the stored upload is disposed, '
        'then it releases the bytes', () async {
      final stored = await _storeMemoryUpload();

      await stored.file.dispose();

      expect(stored.file.size, isNull);
      expect(() => stored.file.openRead(), throwsStateError);
    });
  });
}

MemoryUploadedFile _file({
  required final String fieldName,
  required final String bytes,
}) {
  return MemoryUploadedFile(
    fieldName: fieldName,
    filename: '$fieldName.txt',
    contentType: null,
    headers: Headers.empty(),
    bytes: Uint8List.fromList(utf8.encode(bytes)),
  );
}

Future<
  ({ContentTypeHeader? contentType, MemoryUploadedFile file, Headers headers})
>
_storeMemoryUpload() async {
  const storage = MemoryUploadStorage();
  final headers = Headers.build(
    (final mh) => mh.contentType = ContentTypeHeader(
      mimeType: MimeType.plainText,
      parameters: const {'charset': 'utf-8'},
    ),
  );
  final contentType = headers.contentType;

  final file = await storage.store(
    fieldName: 'upload',
    filename: 'hello.txt',
    contentType: contentType,
    headers: headers,
    content: Stream.value(Uint8List.fromList(utf8.encode('hello'))),
  );

  return (
    contentType: contentType,
    file: file as MemoryUploadedFile,
    headers: headers,
  );
}
