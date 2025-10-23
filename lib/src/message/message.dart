import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import '../../relic.dart';

abstract class Message {
  /// The HTTP headers associated with this message.
  final Headers headers;

  /// The streaming body of the message.
  Body body;

  Message({required this.body, required this.headers});

  /// Returns the MIME type from the Body-Type (Content-Type header), if available.
  MimeType? get mimeType => body.bodyType?.mimeType;

  /// Returns the encoding specified in the Body-Type (Content-Type header), or null if not specified.
  Encoding? get encoding => body.bodyType?.encoding;

  /// Reads the body as a stream of bytes. Can only be called once.
  Stream<Uint8List> read() => body.read();

  /// Reads the body as a string, decoding it using the specified or detected encoding.
  /// Defaults to utf8 if no encoding is provided or detected.
  ///
  /// ## Example
  ///
  /// ```dart
  /// router.post('/api/data', (ctx) async {
  ///   final body = await ctx.request.readAsString();
  ///   final data = jsonDecode(body);
  ///   // Use data...
  /// });
  /// ```
  Future<String> readAsString([Encoding? encoding]) {
    encoding ??= body.bodyType?.encoding ?? utf8;
    return encoding.decodeStream(read());
  }

  /// Determines if the body is empty by checking the content length.
  bool get isEmpty => body.contentLength == 0;

  /// Creates a new message by copying existing values and applying specified changes.
  Message copyWith({final Headers headers, final Body? body});
}
