import 'dart:convert';
import 'dart:io';

import 'package:relic/relic.dart';

Future<void> main() async {
  final uploadDir = await Directory.systemTemp.createTemp(
    'relic_form_example_',
  );

  final app = RelicApp()
    ..get('/', _home)
    ..post('/simple', _simpleForm)
    ..post('/multiple-values', _multipleValues)
    ..post('/upload', (final req) => _upload(req, uploadDir))
    ..post('/limited-upload', (final req) => _limitedUpload(req, uploadDir))
    ..post('/stream-upload', _streamUpload);

  final server = await app.serve();
  stdout.writeln('Serving form example at http://localhost:${server.port}');
  stdout.writeln('Temp upload directory: ${uploadDir.path}');
}

Response _home(final Request req) {
  return _page(title: 'Relic form example');
}

Future<Response> _simpleForm(final Request req) async {
  try {
    final form = await req.urlEncodedForm();
    return _resultPage(req, _formResult(form));
  } on FormException catch (error) {
    return _formError(req, error);
  }
}

Future<Response> _multipleValues(final Request req) async {
  try {
    final form = await req.formData();
    return _resultPage(req, _formResult(form));
  } on FormException catch (error) {
    return _formError(req, error);
  }
}

Future<Response> _upload(final Request req, final Directory uploadDir) async {
  MultipartFormData? form;
  try {
    form = await req.multipartForm(
      uploadStorage: TempUploadStorage(directory: uploadDir),
    );
    return _resultPage(req, _formResult(form));
  } on FormException catch (error) {
    return _formError(req, error);
  } finally {
    await form?.dispose();
  }
}

Future<Response> _limitedUpload(
  final Request req,
  final Directory uploadDir,
) async {
  MultipartFormData? form;
  try {
    form = await req.multipartForm(
      limits: const FormLimits(
        maxBodySize: 32 * 1024,
        maxFieldCount: 8,
        maxFileCount: 1,
        maxPartCount: 8,
        maxFieldSize: 64,
        maxFileSize: 1024,
        maxTotalFileSize: 1024,
        maxPartHeaderSize: 8 * 1024,
        maxBoundarySize: 200,
      ),
      uploadStorage: TempUploadStorage(directory: uploadDir),
    );
    return _resultPage(req, _formResult(form));
  } on FormException catch (error) {
    return _formError(req, error);
  } finally {
    await form?.dispose();
  }
}

Future<Response> _streamUpload(final Request req) async {
  try {
    final lines = <String>[];

    await for (final part in req.multipart()) {
      if (part.isField) {
        lines.add('field ${part.name}: ${await part.readAsString()}');
        continue;
      }
      if (!part.isFile) {
        await part.discard();
        continue;
      }

      var bytes = 0;
      await for (final chunk in part.body.read()) {
        bytes += chunk.length;
      }
      lines.add(
        'file ${part.name}: filename=${part.filename ?? ''}, '
        'content-type=${part.contentType?.mimeType ?? ''}, bytes=$bytes',
      );
    }

    return _resultPage(req, lines.join('\n'));
  } on FormException catch (error) {
    return _formError(req, error);
  }
}

Response _formError(final Request req, final FormException error) {
  return _resultPage(
    req,
    'FormException\nstatus: ${error.statusCode}\nmessage: ${error.message}',
    statusCode: error.statusCode,
  );
}

Response _resultPage(
  final Request req,
  final String body, {
  final int statusCode = 200,
}) {
  final text =
      '''
method: ${req.method.name}
path: ${req.url.path}
content-type: ${req.headers.contentType?.mimeType ?? ''}

$body
''';
  return _page(title: 'What we got', result: text, statusCode: statusCode);
}

Response _page({
  required final String title,
  final String result = '',
  final int statusCode = 200,
}) {
  return Response(
    statusCode,
    body: Body.fromString('''<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>${_escape(title)}</title>
  <style>${_css()}</style>
</head>
<body>
  <h1>${_escape(title)}</h1>
  ${result.isEmpty ? '' : '<h2>Request result</h2><pre>${_escape(result)}</pre><p><a href="/">Back</a></p>'}
  ${result.isEmpty ? _forms() : ''}
</body>
</html>''', mimeType: MimeType.html),
  );
}

String _forms() {
  return '''
<section>
  <form method="post" action="/simple">
    <h2>Simple urlencoded form</h2>
    <p>Uses <code>request.urlEncodedForm()</code>.</p>
    <label>Name <input name="name" value="Nova"></label>
    <label>Email <input type="email" name="email" value="nova@example.com"></label>
    <label>Message <textarea name="message">Hello from a normal HTML form.</textarea></label>
    <button>Submit simple form</button>
  </form>

  <form method="post" action="/multiple-values">
    <h2>Repeated values</h2>
    <p>Uses <code>request.formData()</code>.</p>
    <label><input type="checkbox" name="color" value="red" checked> Red</label>
    <label><input type="checkbox" name="color" value="green" checked> Green</label>
    <label><input type="checkbox" name="color" value="blue"> Blue</label>
    <label><input type="checkbox" name="newsletter" value="yes" checked> Newsletter</label>
    <button>Submit repeated values</button>
  </form>

  <form method="post" action="/upload" enctype="multipart/form-data">
    <h2>Multipart upload</h2>
    <p>Uses <code>request.multipartForm(uploadStorage: TempUploadStorage(...))</code>.</p>
    <label>Display name <input name="displayName" value="Nova"></label>
    <label>Bio <textarea name="bio">I like small server-rendered apps.</textarea></label>
    <label>Avatar/text file <input type="file" name="avatar"></label>
    <button>Upload with temp storage</button>
  </form>

  <form method="post" action="/limited-upload" enctype="multipart/form-data">
    <h2>Intentional limit errors</h2>
    <p>The file limit is 1 KiB and field limit is 64 bytes. Upload a larger file to see a 413 form error.</p>
    <label>Small note <textarea name="note">Keep this short.</textarea></label>
    <label>Limited file <input type="file" name="limitedFile"></label>
    <button>Test limits</button>
  </form>

  <form method="post" action="/stream-upload" enctype="multipart/form-data">
    <h2>Streaming upload</h2>
    <p>Uses <code>request.multipart()</code> and counts bytes without aggregating files.</p>
    <label>Any file <input type="file" name="streamedFile"></label>
    <button>Stream file</button>
  </form>

  <form method="post" action="/upload">
    <h2>Wrong content type error</h2>
    <p>This posts urlencoded data to a route expecting multipart, producing a 415 error.</p>
    <label>Value <input name="value" value="not multipart"></label>
    <button>Trigger 415</button>
  </form>
</section>
''';
}

String _formResult(final FormData form) {
  final lines = <String>[];
  for (final entry in form.entries) {
    switch (entry) {
      case FormFieldEntry():
        lines.add('field ${entry.name}: ${entry.value}');
      case FileFieldEntry():
        final file = entry.file;
        lines.add(
          'file ${entry.name}: filename=${file.filename ?? ''}, '
          'content-type=${file.contentType?.mimeType ?? ''}, '
          'size=${file.size ?? ''}',
        );
    }
  }
  return lines.isEmpty ? '(no fields or files)' : lines.join('\n');
}

String _escape(final Object? value) {
  return const HtmlEscape().convert(value?.toString() ?? '');
}

String _css() {
  return '''
body { font-family: sans-serif; max-width: 900px; margin: 2rem auto; padding: 0 1rem; }
form, pre { border: 1px solid #ccc; padding: 1rem; margin: 1rem 0; }
label { display: block; margin: .5rem 0; }
textarea { width: 100%; min-height: 5rem; }
input[type="text"], input[type="email"] { width: 100%; }
''';
}
