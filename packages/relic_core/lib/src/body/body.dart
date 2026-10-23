import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:async/async.dart';
import 'package:mime/mime.dart';

import '../headers/typed/headers/content_type_header.dart';
import 'types/body_type.dart';
import 'types/mime_type.dart';

/// The body of a request or response.
///
/// This tracks whether the body has been read. It's separate from [Message]
/// because the message may be changed with [Message.copyWith], but each instance
/// should share a notion of whether the body was read.
///
/// ## Creating Response Bodies
///
/// ### Text Body
/// ```dart
/// Body.fromString('Hello, World!')
/// ```
///
/// ### JSON Body
/// ```dart
/// final data = {'name': 'Alice', 'age': 30};
/// Body.fromString(
///   jsonEncode(data),
///   mimeType: MimeType.json,
/// )
/// ```
///
/// ### HTML Body
/// ```dart
/// Body.fromString(
///   '<html><body><h1>Welcome!</h1></body></html>',
///   mimeType: MimeType.html,
/// )
/// ```
///
/// ### Binary Data
/// ```dart
/// final bytes = Uint8List.fromList([1, 2, 3, 4]);
/// Body.fromData(bytes)
/// ```
///
/// ### Streaming Data
/// ```dart
/// Stream<Uint8List> dataStream = getFileStream();
/// Body.fromDataStream(
///   dataStream,
///   contentLength: fileSize,
///   mimeType: MimeType.octetStream,
/// )
/// ```
///
/// ### Empty Body
/// ```dart
/// Body.empty()
/// ```
///
/// ## Reading Request Bodies
///
/// **Important**: The body can only be read once!
///
/// ```dart
/// // Read as string
/// final text = await request.readAsString();
///
/// // Parse JSON
/// final data = jsonDecode(await request.readAsString());
///
/// // Read as stream
/// final stream = request.read();
/// await for (final chunk in stream) {
///   // Process chunk
/// }
/// ```
class Body {
  /// The stream [read] hands out.
  ///
  /// Null for a body built from [bytes], or one that [_open] makes. [read]
  /// makes that stream on demand, and an adapter that writes the bytes
  /// itself, or sends no body, never asks for it.
  Stream<Uint8List>? _stream;

  /// What makes the stream on [read], for a body built without one.
  Stream<Uint8List> Function()? _open;
  var _isRead = false;

  /// Whether the body was read, by [read] or [BodyConsume.consume].
  ///
  /// A body is read once.
  bool get isRead => _isRead;

  /// The length of the stream returned by [read], or `null` if that can't be
  /// determined efficiently.
  final int? contentLength;

  /// The whole body, when it was built from bytes or a string.
  ///
  /// An adapter writes this in one call instead of draining [read]. Null
  /// for a streamed body. Reading it does not count as reading the body.
  final Uint8List? bytes;

  /// The media type, charset and parameters of this body, or null if it has
  /// no media type.
  ///
  /// For incoming requests, this is populated from the request content type
  /// header.
  ///
  /// For outgoing responses, this field is used to create the content type
  /// header.
  ///
  /// Example:
  /// ```dart
  /// var body = Body.fromString('hello', mimeType: MimeType.plainText);
  /// print(body.bodyType?.toHeaderValue()); // text/plain; charset=utf-8
  /// ```
  final BodyType? bodyType;

  Body._(
    this._stream,
    this.contentLength, {
    this.bytes,
    final Encoding? encoding,
    final MimeType? mimeType,
    final Map<String, String> parameters = const {},
  }) : bodyType = _bodyType(mimeType, encoding, parameters);

  Body._typed(this._stream, this.contentLength, {this.bytes, this.bodyType});

  static BodyType? _bodyType(
    final MimeType? mimeType,
    final Encoding? encoding,
    final Map<String, String> parameters,
  ) {
    if (mimeType == null) {
      if (parameters.isNotEmpty) {
        throw ArgumentError.value(
          parameters,
          'parameters',
          'Requires a mimeType',
        );
      }
      return null;
    }
    if (parameters.isNotEmpty) {
      return BodyType(
        mimeType: mimeType,
        encoding: encoding,
        parameters: parameters,
      );
    }
    // A BodyType is immutable and builds its header value once, so the
    // common pairs are shared. The map is keyed by identity, since the MIME
    // types and encodings in use are constants. The cap stops a caller that
    // makes a MIME type per request from growing it without bound.
    var byEncoding = _sharedBodyTypes[mimeType];
    if (byEncoding == null) {
      if (_sharedBodyTypes.length >= _sharedBodyTypesLimit) {
        return BodyType(mimeType: mimeType, encoding: encoding);
      }
      byEncoding = _sharedBodyTypes[mimeType] = HashMap.identity();
    }
    return byEncoding[encoding] ??= BodyType(
      mimeType: mimeType,
      encoding: encoding,
    );
  }

  static final _sharedBodyTypes =
      HashMap<MimeType, Map<Encoding?, BodyType>>.identity();
  static const _sharedBodyTypesLimit = 256;

  /// Creates an empty body.
  ///
  /// Example:
  /// ```dart
  /// final emptyBody = Body.empty();
  /// print(emptyBody.contentLength); // 0
  /// ```
  factory Body.empty() => Body._(null, 0).._open = _openEmpty;

  static Stream<Uint8List> _openEmpty() => const Stream.empty();

  /// Creates a body from a string.
  ///
  /// If [mimeType] is not provided, it will be inferred from the string.
  /// It is more performant to set it explicitly.
  ///
  /// Examples:
  /// ```dart
  /// // Simple text
  /// final body = Body.fromString('Hello, World!');
  ///
  /// // JSON with automatic detection
  /// final jsonBody = Body.fromString('{"message": "Hello"}');
  /// // Automatically detects application/json MIME type
  ///
  /// // HTML with automatic detection
  /// final htmlBody = Body.fromString('<!DOCTYPE html><html>...</html>');
  /// // Automatically detects text/html MIME type
  ///
  /// // With explicit MIME type and custom encoding
  /// final customBody = Body.fromString(
  ///   'Héllo world',
  ///   mimeType: MimeType.plainText,
  ///   encoding: latin1,
  /// );
  /// ```
  factory Body.fromString(
    final String body, {
    final Encoding encoding = utf8,
    MimeType? mimeType,
  }) {
    final encoded = encoding is Utf8Codec
        ? _encodeUtf8(body)
        : Uint8List.fromList(encoding.encode(body));

    mimeType ??= _tryInferTextMimeTypeFrom(body) ?? MimeType.plainText;

    return Body._(
      null,
      encoded.length,
      bytes: encoded,
      encoding: encoding,
      mimeType: mimeType,
    );
  }

  static MimeType? _tryInferTextMimeTypeFrom(final String content) {
    var firstNonWhiteSpace = 0;
    final end = content.length;
    while (firstNonWhiteSpace < end &&
        _isWhitespace(content[firstNonWhiteSpace])) {
      firstNonWhiteSpace++;
    }

    final prefix = content.substring(
      firstNonWhiteSpace,
      min(end, firstNonWhiteSpace + 14),
    ); // 14 max length needed

    if (prefix.startsWith('{') || prefix.startsWith('[')) {
      return MimeType.json;
    }

    if (prefix.startsWith('<?xml')) {
      return MimeType.xml;
    }

    if (prefix.startsWith('<!DOCTYPE html') ||
        prefix.startsWith('<!doctype html') ||
        prefix.startsWith('<html')) {
      return MimeType.html;
    }

    return null; // give up
  }

  /// Checks if a character is whitespace.
  static bool _isWhitespace(final String char) {
    return char == ' ' || char == '\t' || char == '\n' || char == '\r';
  }

  /// Creates a body from a [Stream] of [Uint8List].
  ///
  /// This is useful for large files or streaming data where you don't want
  /// to load everything into memory at once.
  ///
  /// Examples:
  /// ```dart
  /// // Stream with known length (recommended for better HTTP performance)
  /// final streamBody = Body.fromDataStream(
  ///   fileStream,
  ///   mimeType: MimeType.pdf,
  ///   contentLength: fileSize,
  /// );
  ///
  /// // Stream with unknown length (uses chunked encoding)
  /// final dynamicBody = Body.fromDataStream(
  ///   dynamicStream,
  ///   mimeType: MimeType.json,
  ///   // contentLength omitted for chunked encoding
  /// );
  ///
  /// // Multipart stream with its boundary
  /// final multipartBody = Body.fromDataStream(
  ///   partsStream,
  ///   mimeType: MimeType.multipartFormData,
  ///   parameters: {'boundary': boundary},
  /// );
  /// ```
  ///
  /// [parameters] holds media type parameters other than `charset`, which
  /// [encoding] sets. Throws [ArgumentError] if [parameters] has a `charset`,
  /// or is not empty while [mimeType] is null.
  ///
  /// The framing takes Content-Length from [contentLength]. A response that
  /// sends no body, such as the answer to a HEAD request, cancels the stream
  /// without reading it. Use [Body.lazy] for a stream that opens a file or a
  /// connection when listened to.
  factory Body.fromDataStream(
    final Stream<Uint8List> body, {
    final Encoding? encoding,
    final MimeType? mimeType = MimeType.octetStream,
    final Map<String, String> parameters = const {},
    final int? contentLength,
  }) {
    return Body._(
      body,
      contentLength,
      encoding: encoding ?? (mimeType?.isText == true ? utf8 : null),
      mimeType: mimeType,
      parameters: parameters,
    );
  }

  /// Creates a body whose stream [open] makes when the body is read.
  ///
  /// A body that is not sent, such as the answer to a HEAD request, is
  /// never read, so [open] never runs and a file or connection behind the
  /// stream is never opened. [open] runs at most once.
  ///
  /// ```dart
  /// final fileBody = Body.lazy(
  ///   () => file.openRead().cast(),
  ///   mimeType: MimeType.pdf,
  ///   contentLength: fileSize,
  /// );
  /// ```
  ///
  /// The other parameters are those of [Body.fromDataStream].
  factory Body.lazy(
    final Stream<Uint8List> Function() open, {
    final Encoding? encoding,
    final MimeType? mimeType = MimeType.octetStream,
    final Map<String, String> parameters = const {},
    final int? contentLength,
  }) {
    return Body._(
      null,
      contentLength,
      encoding: encoding ?? (mimeType?.isText == true ? utf8 : null),
      mimeType: mimeType,
      parameters: parameters,
    ).._open = open;
  }

  static final _resolver = MimeTypeResolver();

  /// Creates a body from a [Uint8List].
  ///
  /// Will try to infer the [mimeType] if it is not provided.
  /// This will only work for some binary formats, and falls
  /// back to [MimeType.octetStream].
  ///
  /// Examples:
  /// ```dart
  /// // Binary data with automatic format detection
  /// final imageData = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, ...]);
  /// final imageBody = Body.fromData(imageData);
  /// // Automatically detects image/png from magic bytes
  ///
  /// // Binary data with explicit MIME type
  /// final binaryBody = Body.fromData(
  ///   data,
  ///   mimeType: MimeType.octetStream,
  /// );
  ///
  /// // PDF document detection
  /// final pdfBytes = utf8.encode('%PDF-1.4...');
  /// final pdfBody = Body.fromData(pdfBytes);
  /// // Automatically detects application/pdf
  /// ```
  ///
  /// [parameters] holds media type parameters other than `charset`, which
  /// [encoding] sets. Throws [ArgumentError] if [parameters] has a `charset`.
  factory Body.fromData(
    final Uint8List body, {
    final Encoding? encoding,
    MimeType? mimeType,
    final Map<String, String> parameters = const {},
  }) {
    if (mimeType == null) {
      final mimeString = _resolver.lookup('', headerBytes: body);
      mimeType = mimeString == null ? null : MimeType.parse(mimeString);
    }
    return Body._(
      null,
      body.length,
      bytes: body,
      encoding: encoding ?? (mimeType?.isText == true ? utf8 : null),
      mimeType: mimeType ?? MimeType.octetStream,
      parameters: parameters,
    );
  }

  /// Creates a body from [bytes] with the media type the sender declared.
  ///
  /// Unlike [Body.fromData], nothing is inferred when [mimeType] is null.
  /// The body then has no type, as a request without a Content-Type has.
  /// For an adapter handing over a request body.
  factory Body.fromBytes(
    final Uint8List bytes, {
    final MimeType? mimeType,
    final Encoding? encoding,
    final Map<String, String> parameters = const {},
  }) => Body._(
    null,
    bytes.length,
    bytes: bytes,
    encoding: encoding,
    mimeType: mimeType,
    parameters: parameters,
  );

  /// The body an adapter hands over, typed by [contentType].
  ///
  /// Pass [bytes] when the adapter has read the body, [stream] when it
  /// arrives as the handler reads, with [contentLength] when declared, and
  /// neither for a message without a body. [BodyType.fromContentType] does
  /// the typing, so a request's Content-Type and an upstream response's
  /// work alike. Read the header with `tryGet`, so one that does not parse
  /// counts as none.
  factory Body.of(
    final ContentTypeHeader? contentType, {
    final Uint8List? bytes,
    final Stream<Uint8List>? stream,
    final int? contentLength,
  }) {
    if (bytes == null && stream == null) return Body.empty();
    final bodyType = contentType == null
        ? null
        : BodyType.fromContentType(contentType);
    if (bytes != null) {
      return Body._typed(null, bytes.length, bytes: bytes, bodyType: bodyType);
    }
    return Body._typed(stream, contentLength, bodyType: bodyType);
  }

  /// The whole body as one buffer.
  ///
  /// Synchronous when the body was built from bytes or a string. Counts as
  /// reading the body, like [read].
  FutureOr<Uint8List> readAll({final int? maxLength}) {
    final bytes = this.bytes;
    if (bytes != null) {
      consume();
      if (maxLength != null && bytes.length > maxLength) {
        throw MaxBodySizeExceeded(maxLength);
      }
      return bytes;
    }
    return collectBytes(read(maxLength: maxLength));
  }

  /// Returns a [Stream] representing the body.
  ///
  /// Can only be called once to prevent accidental double-consumption
  /// and ensure predictable behavior.
  ///
  /// If [maxLength] is provided, the stream will throw a [MaxBodySizeExceeded]
  /// exception if the total bytes exceed the limit. This is useful for
  /// preventing denial-of-service attacks from unbounded body reads.
  ///
  /// **Note**: When [contentLength] is known and exceeds [maxLength], the
  /// exception is thrown immediately without consuming any data. When
  /// [contentLength] is unknown (chunked encoding), the exception is thrown
  /// as soon as the cumulative size exceeds the limit.
  ///
  /// Examples:
  /// ```dart
  /// final body = Body.fromString('test');
  ///
  /// // First read - OK
  /// final stream1 = body.read();
  ///
  /// // Second read - throws StateError
  /// try {
  ///   final stream2 = body.read(); // ❌ Error!
  /// } catch (e) {
  ///   print(e); // "The 'read' method can only be called once"
  /// }
  ///
  /// // For processing large uploads chunk by chunk:
  /// final uploadStream = request.body.read();
  /// await for (final chunk in uploadStream) {
  ///   // Process chunk by chunk
  ///   await processChunk(chunk);
  /// }
  ///
  /// // With size limit (10 MB):
  /// try {
  ///   final limitedStream = request.body.read(maxLength: 10 * 1024 * 1024);
  ///   await for (final chunk in limitedStream) {
  ///     // Process chunk
  ///   }
  /// } on MaxBodySizeExceeded {
  ///   // Handle oversized body
  /// }
  /// ```
  Stream<Uint8List> read({final int? maxLength}) {
    // A known length over maxLength fails before the stream is made. A lazy
    // open then never runs, and consume() cancels a stream the body holds.
    final knownLength = contentLength;
    if (maxLength != null && knownLength != null && knownLength > maxLength) {
      consume();
      throw MaxBodySizeExceeded(maxLength);
    }
    _markRead();
    final stream = _stream ?? _open?.call() ?? Stream.value(bytes!);
    _stream = null;
    _open = null;

    if (maxLength == null) {
      return stream;
    }

    // Wrap stream to track cumulative size.
    return _limitedStream(stream, maxLength);
  }

  static Stream<Uint8List> _limitedStream(
    final Stream<Uint8List> source,
    final int maxLength,
  ) async* {
    var totalBytes = 0;
    await for (final chunk in source) {
      totalBytes += chunk.length;
      if (totalBytes > maxLength) {
        // Windows TCP behavior:
        // When you close a socket with unread data in the receive buffer,
        // Windows sends RST instead of FIN. This nukes the connection before
        // send buffer flushes.
        //
        // To avoid this causing missed responses on a client we keep draining
        // the socket, but discard the content, before throwing.
        if (Platform.isWindows) continue;
        break; // other platforms send FIN, so just raise immediately
      } else {
        yield chunk;
      }
    }
    // check again to not throw on success
    if (totalBytes > maxLength) throw MaxBodySizeExceeded(maxLength);
  }
}

/// What an adapter does with a body it does not stream.
extension BodyConsume on Body {
  /// Marks the body as read, as [Body.read] does, and cancels its stream
  /// without reading it.
  ///
  /// An adapter that sends [Body.bytes] itself, or sends no body at all,
  /// has no use for the stream, and [Body.read] would allocate one for a
  /// body held as bytes. The cancel lets the producer of the stream release
  /// what it holds. A body from [Body.lazy] has no stream until it is read.
  ///
  /// Errors the stream delivers are discarded.
  ///
  /// Throws a [StateError] when the body was already read.
  void consume() {
    _markRead();
    _stream?.listen(null).cancel().ignore();
    _stream = null;
    _open = null;
  }

  void _markRead() {
    if (_isRead) {
      throw StateError(
        "The 'read' method can only be called once on a "
        'Request/Response object.',
      );
    }
    _isRead = true;
  }
}

/// Internal extension methods for [Body], not exported from relic_core.dart.
extension BodyInternal on Body {
  /// The private `Body._` constructor.
  static const create = Body._;
}

/// Exception thrown when the body size exceeds the maximum allowed length.
class MaxBodySizeExceeded implements Exception {
  /// The maximum allowed body size in bytes.
  final int maxLength;

  /// Creates a new [MaxBodySizeExceeded] exception.
  MaxBodySizeExceeded(this.maxLength);

  @override
  String toString() => 'MaxBodySizeExceeded: Body exceeded $maxLength bytes';
}

/// The UTF-8 bytes of [text].
///
/// `utf8.encode` takes 3.7 us over a 1.3 KB ASCII string and this loop
/// 1.6 us, so the encoder only runs from the first non-ASCII code unit on.
Uint8List _encodeUtf8(final String text) {
  final out = Uint8List(text.length);
  for (var i = 0; i < text.length; i++) {
    final unit = text.codeUnitAt(i);
    if (unit >= 0x80) return _encodeUtf8Tail(text, out, i);
    out[i] = unit;
  }
  return out;
}

/// The UTF-8 bytes of [text], given [prefix] holds its first [from] code
/// units, all ASCII.
Uint8List _encodeUtf8Tail(
  final String text,
  final Uint8List prefix,
  final int from,
) {
  final rest = utf8.encoder.convert(text, from);
  return Uint8List(from + rest.length)
    ..setRange(0, from, prefix)
    ..setRange(from, from + rest.length, rest);
}
