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
  final Stream<Uint8List> chunks,
  final Encoding encoding,
  final String context,
) async {
  final bytes = await chunks.fold(
    BytesBuilder(copy: false),
    (final builder, final chunk) => builder..add(chunk),
  );
  try {
    return encoding.decode(bytes.takeBytes());
  } on FormatException catch (error) {
    throw MalformedFormDataException('$context: ${error.message}');
  }
}
