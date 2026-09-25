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

  test('Given only maxFileSize, '
      'when FormLimits is constructed, '
      'then every other limit has its default value.', () {
    const defaults = FormLimits.defaults;

    const limits = FormLimits(maxFileSize: 1024);

    expect(limits.maxBodySize, defaults.maxBodySize);
    expect(limits.maxFieldCount, defaults.maxFieldCount);
    expect(limits.maxFileCount, defaults.maxFileCount);
    expect(limits.maxPartCount, defaults.maxPartCount);
    expect(limits.maxFieldSize, defaults.maxFieldSize);
    expect(limits.maxFileSize, 1024);
    expect(limits.maxTotalFileSize, defaults.maxTotalFileSize);
    expect(limits.maxPartHeaderSize, defaults.maxPartHeaderSize);
    expect(limits.maxBoundarySize, defaults.maxBoundarySize);
  });

  test('Given FormLimits.defaults, '
      'when copyWith replaces maxFieldCount, '
      'then every other limit keeps its default value.', () {
    const defaults = FormLimits.defaults;

    final limits = defaults.copyWith(maxFieldCount: 3);

    expect(limits.maxBodySize, defaults.maxBodySize);
    expect(limits.maxFieldCount, 3);
    expect(limits.maxFileCount, defaults.maxFileCount);
    expect(limits.maxPartCount, defaults.maxPartCount);
    expect(limits.maxFieldSize, defaults.maxFieldSize);
    expect(limits.maxFileSize, defaults.maxFileSize);
    expect(limits.maxTotalFileSize, defaults.maxTotalFileSize);
    expect(limits.maxPartHeaderSize, defaults.maxPartHeaderSize);
    expect(limits.maxBoundarySize, defaults.maxBoundarySize);
  });

  group('Given form exceptions', () {
    test('when created, '
        'then they expose messages and status codes', () {
      const unsupported = UnsupportedFormMediaTypeException('unsupported');
      const malformed = MalformedFormDataException('malformed');
      const limitExceeded = FormLimitExceededException(
        limit: FormLimit.maxFieldSize,
        message: 'too large',
      );

      expect(unsupported.message, 'unsupported');
      expect(unsupported.statusCode, 415);
      expect(unsupported.toString(), 'unsupported');

      expect(malformed.message, 'malformed');
      expect(malformed.statusCode, 400);
      expect(malformed.toString(), 'malformed');

      expect(limitExceeded.message, 'too large');
      expect(limitExceeded.limit, FormLimit.maxFieldSize);
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
      expect(fields.raw['name'], 'first');
      expect(fields.get(const StringFormField('role')), 'admin');
      expect(fields.getAll(const StringFormField('name')), ['first', 'second']);
      expect(fields.raw.containsKey('name'), isTrue);
      expect(fields.raw.containsKey('missing'), isFalse);
      expect(
        () => fields.get(const StringFormField('missing')),
        throwsA(isA<MissingFormFieldException>()),
      );
    });

    test('when the source list changes after construction, '
        'then entries are unchanged', () {
      final source = [const FormFieldEntry(name: 'name', value: 'first')];
      final fields = FormFields(source);

      source.add(const FormFieldEntry(name: 'name', value: 'second'));

      expect(fields.getAll(const StringFormField('name')), ['first']);
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

  test('Given FormFields with one field, '
      'when its raw map is mutated, '
      'then it throws UnsupportedError.', () {
    final fields = FormFields([
      const FormFieldEntry(name: 'name', value: 'first'),
    ]);

    expect(() => fields.raw['name'] = 'second', throwsUnsupportedError);
  });

  group('Given UrlEncodedFormData', () {
    test('when the raw map of its files is mutated, '
        'then it throws UnsupportedError.', () {
      final form = UrlEncodedFormData(fields: FormFields(const []));

      expect(
        () => form.files.raw['file'] = _file(filename: 'a.txt', bytes: 'a'),
        throwsUnsupportedError,
      );
    });

    test('when created, '
        'then files are empty and entries mirror fields', () {
      final field = const FormFieldEntry(name: 'name', value: 'Gustavo');
      final form = UrlEncodedFormData(fields: FormFields([field]));

      expect(form.fields.raw['name'], 'Gustavo');
      expect(form.files.entries, isEmpty);
      expect(form.entries, [field]);
    });
  });

  group('Given UploadedFiles with duplicate names', () {
    test('when queried, '
        'then order and duplicate files are preserved', () {
      final file1 = _file(filename: 'one.png', bytes: 'one');
      final file2 = _file(filename: 'two.pdf', bytes: 'two');
      final file3 = _file(filename: 'three.png', bytes: 'three');
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
      expect(files(const FormFile('avatar')), same(file1));
      expect(files.get(const FormFile('attachment')), same(file2));
      expect(files.getAll(const FormFile('avatar')), [file1, file3]);
      expect(files.raw.containsKey('avatar'), isTrue);
      expect(files.raw.containsKey('missing'), isFalse);
      expect(
        () => files.get(const FormFile('missing')),
        throwsA(isA<MissingFormFieldException>()),
      );
    });
  });

  group('Given MultipartFormData', () {
    test('when created, '
        'then it preserves mixed entry order', () {
      final field = const FormFieldEntry(name: 'title', value: 'Report');
      final file = _file(filename: 'report.txt', bytes: 'file-body');
      final fileEntry = FileFieldEntry(name: 'upload', file: file);
      final form = MultipartFormData(
        fields: FormFields([field]),
        files: UploadedFiles([fileEntry]),
        entries: [field, fileEntry],
      );

      expect(form.entries, [field, fileEntry]);
      expect(form.fields.raw['title'], 'Report');
      expect(form.files(const FormFile('upload')), same(file));
    });

    test('when disposed, '
        'then uploaded files are disposed', () async {
      final file = _file(filename: 'report.txt', bytes: 'file-body');
      final form = MultipartFormData(
        fields: FormFields(const []),
        files: UploadedFiles([FileFieldEntry(name: 'upload', file: file)]),
        entries: [FileFieldEntry(name: 'upload', file: file)],
      );

      await form.dispose();

      expect(file.size, isNull);
      expect(() => file.read(), throwsStateError);
    });
  });

  group('Given MemoryUploadStorage', () {
    test('when storing content, '
        'then it returns an uploaded file with metadata', () async {
      final stored = await _storeMemoryUpload();

      expect(stored.file.filename, 'hello.txt');
      expect(stored.file.bodyType, stored.bodyType);
      expect(stored.file.headers, stored.headers);
      expect(stored.file.size, 5);
    });

    test('when opening the stored upload, '
        'then it streams the stored bytes', () async {
      final stored = await _storeMemoryUpload();

      expect(await utf8.decodeStream(stored.file.read()), 'hello');
    });

    test('when the stored upload is disposed, '
        'then it releases the bytes', () async {
      final stored = await _storeMemoryUpload();

      await stored.file.dispose();

      expect(stored.file.size, isNull);
      expect(() => stored.file.read(), throwsStateError);
    });
  });

  test('Given form fields with age "42", '
      'when age is read with an IntFormField, '
      'then it returns 42.', () {
    final fields = FormFields([const FormFieldEntry(name: 'age', value: '42')]);

    expect(fields.get(const IntFormField('age')), 42);
  });

  test('Given form fields without age, '
      'when age is read by calling the fields with an IntFormField, '
      'then it returns null.', () {
    final fields = FormFields([
      const FormFieldEntry(name: 'name', value: 'Relic'),
    ]);

    expect(fields(const IntFormField('age')), isNull);
  });

  test('Given form fields with age "abc", '
      'when age is read with an IntFormField, '
      'then it throws InvalidFormFieldException naming the field.', () {
    final fields = FormFields([
      const FormFieldEntry(name: 'age', value: 'abc'),
    ]);

    expect(
      () => fields.get(const IntFormField('age')),
      throwsA(
        isA<InvalidFormFieldException>().having(
          (final e) => e.name,
          'name',
          'age',
        ),
      ),
    );
  });

  test('Given a form field whose decoder throws an Error, '
      'when the field is read, '
      'then it throws that Error.', () {
    final fields = FormFields([
      const FormFieldEntry(name: 'color', value: 'purple'),
    ]);
    final colorField = FormField<String>(
      'color',
      (final value) => throw ArgumentError.value(value),
    );

    expect(() => fields.get(colorField), throwsArgumentError);
  });

  test('Given form fields with age "abc", '
      'when age is read with tryGet, '
      'then it returns null.', () {
    final fields = FormFields([
      const FormFieldEntry(name: 'age', value: 'abc'),
    ]);

    expect(fields.tryGet(const IntFormField('age')), isNull);
  });

  test('Given form fields with ids "1" and "x", '
      'when ids are read with getAll and an IntFormField, '
      'then it throws InvalidFormFieldException.', () {
    final fields = FormFields([
      const FormFieldEntry(name: 'id', value: '1'),
      const FormFieldEntry(name: 'id', value: 'x'),
    ]);

    expect(
      () => fields.getAll(const IntFormField('id')),
      throwsA(isA<InvalidFormFieldException>()),
    );
  });

  test('Given uploaded files without avatar, '
      'when avatar is read by calling the files with a FormFile, '
      'then it returns null.', () {
    final files = UploadedFiles([]);

    expect(files(const FormFile('avatar')), isNull);
  });

  test(
    'Given a missing form field exception and an invalid form field exception, '
    'when their status codes are read, '
    'then both are 400.',
    () {
      const missing = MissingFormFieldException('name');
      const invalid = InvalidFormFieldException('age', FormatException('x'));

      expect(missing.statusCode, 400);
      expect(invalid.statusCode, 400);
    },
  );
}

MemoryUploadedFile _file({
  required final String filename,
  required final String bytes,
}) {
  return MemoryUploadedFile(
    filename: filename,
    bodyType: null,
    headers: Headers.empty(),
    bytes: Uint8List.fromList(utf8.encode(bytes)),
  );
}

Future<({BodyType? bodyType, MemoryUploadedFile file, Headers headers})>
_storeMemoryUpload() async {
  const storage = MemoryUploadStorage();
  final bodyType = BodyType(mimeType: MimeType.plainText, encoding: utf8);
  final headers = Headers.build(
    (final mh) => mh[Headers.contentTypeHeader] = [bodyType.toHeaderValue()],
  );

  final file = await storage.store(
    fieldName: 'upload',
    filename: 'hello.txt',
    bodyType: bodyType,
    headers: headers,
    content: Stream.value(Uint8List.fromList(utf8.encode('hello'))),
  );

  return (
    bodyType: bodyType,
    file: file as MemoryUploadedFile,
    headers: headers,
  );
}
