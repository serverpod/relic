import 'dart:convert';
import 'dart:typed_data';

import 'form_data.dart';

/// Collects [chunks] and decodes them with [encoding].
///
/// Throws [MalformedFormDataException] with a message that starts with
/// [context] if the bytes do not decode. It collects every chunk before it
/// decodes, so an error from [chunks], even a [FormatException], passes
/// through unchanged.
Future<String> decodeFormText(
  Stream<Uint8List> chunks,
  Encoding encoding,
  String context,
) async {
  final bytes = await chunks.fold(
    BytesBuilder(copy: false),
    (builder, chunk) => builder..add(chunk),
  );
  try {
    return encoding.decode(bytes.takeBytes());
  } on FormatException catch (error) {
    throw MalformedFormDataException('$context: ${error.message}');
  }
}
