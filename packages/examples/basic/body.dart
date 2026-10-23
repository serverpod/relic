import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:relic/relic.dart';

// doctag<body-streaming-chunked>
Response countdown(Request req) {
  Stream<Uint8List> lines() async* {
    for (var i = 3; i > 0; i--) {
      yield utf8.encode('$i...\n');
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    yield utf8.encode('Liftoff!\n');
  }

  return Response.ok(
    body: Body.fromDataStream(lines(), mimeType: MimeType.plainText),
  );
}
// end:doctag<body-streaming-chunked>

// doctag<body-lazy-file>
Future<Response> greeting(Request req) async {
  final file = File('_static_files/hello.txt');
  return Response.ok(
    body: Body.lazy(
      () {
        stdout.writeln('opening ${file.path}');
        return file.openRead().cast<Uint8List>();
      },
      contentLength: await file.length(),
      mimeType: MimeType.plainText,
    ),
  );
}
// end:doctag<body-lazy-file>

// doctag<body-upload-limit>
Future<Response> upload(Request req) async {
  const maxSize = 1024 * 1024;
  var received = 0;
  try {
    await for (final chunk in req.read(maxLength: maxSize)) {
      received += chunk.length;
    }
  } on MaxBodySizeExceeded {
    return Response.contentTooLarge(body: Body.fromString('Over 1 MB\n'));
  }
  return Response.ok(body: Body.fromString('Received $received bytes\n'));
}
// end:doctag<body-upload-limit>

// doctag<body-inspect-middleware>
Handler logBodySize(Handler next) {
  return (req) async {
    final type = req.body.bodyType;
    final bytes = await req.body.readAll();
    stdout.writeln(
      'a body of ${bytes.length} bytes, ${type?.mimeType.toHeaderValue()}',
    );
    req.body = Body.fromBytes(
      bytes,
      mimeType: type?.mimeType,
      encoding: type?.encoding,
      parameters: type?.parameters ?? const {},
    );
    return next(req);
  };
}
// end:doctag<body-inspect-middleware>

const nameField = StringFormField('name');

Future<Response> signup(Request req) async {
  final form = await req.formData();
  return Response.ok(
    body: Body.fromString('Hello, ${form.fields.get(nameField)}\n'),
  );
}

Future<void> main() async {
  // doctag<body-routes>
  final app = RelicApp()
    ..get('/countdown', countdown)
    ..get('/greeting', greeting)
    ..post('/upload', upload)
    ..use('/signup', logBodySize)
    ..post('/signup', signup);
  // end:doctag<body-routes>

  await app.serve();
}
