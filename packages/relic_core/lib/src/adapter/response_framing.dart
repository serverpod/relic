import 'dart:typed_data';

import 'package:relic_headers/relic_headers.dart';

import '../body/types/body_type.dart';
import '../body/types/mime_type.dart';
import '../context/result.dart';
import '../headers/exception/header_exception.dart';
import '../headers/standard_headers_extensions.dart';
import '../headers/typed/headers/connection_header.dart';
import '../headers/typed/headers/transfer_encoding_header.dart';
import '../util/http_date.dart';
import '../util/util.dart';
import 'adapter.dart';

/// What goes on the wire for a [Response], decided once so every adapter
/// frames the same bytes for the same response.
///
/// An adapter writes the response's headers except [HeaderName.contentLength],
/// [HeaderName.contentType] and [HeaderName.transferEncoding], then what
/// is here. The body decides the length and the type, the server the date.
final class ResponseFraming {
  /// Whether body bytes follow the head.
  ///
  /// Not for a HEAD request, and not for a 1xx, 204 or 304.
  final bool sendBody;

  /// The Content-Length to announce, or null.
  final int? contentLength;

  /// The Transfer-Encoding codings to announce, or null.
  ///
  /// `chunked` is last when [chunked].
  final List<String>? transferEncoding;

  /// The Content-Type from the body, or null for a body without one.
  final String? contentType;

  /// The Date to add, or null when the response has one.
  final String? date;

  /// The Date field line, `date: <value>\r\n`, as bytes for a head writer
  /// to copy, or null when [date] is null or the stand-in an adapter
  /// stamps.
  final Uint8List? dateLine;

  /// Whether the connection closes after this response.
  ///
  /// True when the request or the response asked for it, or when nothing
  /// else frames the body, so its end must.
  final bool closeAfter;

  /// The Connection option to add, or null when the response sets the
  /// header itself or needs none. [ConnectionHeaderType.close] when
  /// [closeAfter] (RFC 9112 9.6). [ConnectionHeaderType.keepAlive] to an
  /// HTTP/1.0 request whose connection stays open, which such a client
  /// takes as closed unless told (RFC 9112 C.2.2).
  final ConnectionHeaderType? connection;

  const ResponseFraming._({
    required this.sendBody,
    required this.contentLength,
    required this.transferEncoding,
    required this.contentType,
    required this.date,
    required this.dateLine,
    required this.closeAfter,
    required this.connection,
  });

  /// The framing of [response] over [protocol], for a HEAD request when
  /// [head], on a connection kept alive when [keepAlive].
  ///
  /// With [stampDate] the Date is [stampedDate], for an adapter that
  /// writes the date itself at send time, at [ResponseHead.dateOffset].
  ///
  /// Throws [FormatException] when the body's type does not validate or a
  /// response header the framing reads does not parse, so a response that
  /// cannot be written fails before anything goes out.
  factory ResponseFraming.of(
    Response response, {
    required bool head,
    required HttpProtocol protocol,
    required bool keepAlive,
    bool stampDate = false,
  }) {
    final headers = response.headers;
    final body = response.body;
    final hasBody = statusMayHaveBody(response.statusCode);

    final bodyType = body.bodyType;
    String? contentType;
    if (bodyType != null) {
      bodyType.validate();
      contentType = bodyType.toHeaderValue();
    }
    String? date;
    Uint8List? dateLine;
    if (!headers.contains(HeaderName.date)) {
      if (stampDate) {
        date = stampedDate;
      } else {
        // The value and its line come from one cache refresh.
        date = httpDate();
        dateLine = httpDateLineOf(date);
      }
    }
    // Most responses set neither Connection nor Transfer-Encoding, so the
    // parse runs only when the header is there.
    final setsConnection = headers.contains(HeaderName.connection);
    final own = setsConnection
        ? _own(() => headers.connection, HeaderName.connection)
        : null;
    // An HTTP/1.0 client keeps the connection only when the response says
    // keep-alive, so a Connection value of the handler's without it ends
    // the connection here too.
    var closeAfter =
        !keepAlive ||
        (own?.isClose ?? false) ||
        (setsConnection &&
            protocol == HttpProtocol.http10 &&
            !(own?.isKeepAlive ?? false));

    int? contentLength;
    List<String>? transferEncoding;
    if (hasBody) {
      // A handler's codings stay, except chunked. The body's length decides
      // that here.
      List<String>? codings;
      if (headers.contains(HeaderName.transferEncoding)) {
        codings = [
          for (final coding
              in _own(
                    () => headers.transferEncoding,
                    HeaderName.transferEncoding,
                  )?.encodings ??
                  const <TransferEncoding>[])
            if (coding.name != TransferEncoding.chunked.name) coding.name,
        ];
        if (codings.isEmpty) codings = null;
      }
      final length = body.contentLength;
      if (length != null && codings == null) {
        // A message with Transfer-Encoding has no Content-Length (RFC 9112
        // 6.1), so its coding frames a coded body even when the length is
        // known.
        contentLength = length;
      } else if (protocol == HttpProtocol.http10 ||
          (codings?.contains(TransferEncoding.identity.name) ?? false) ||
          _isMultipartByteranges(bodyType)) {
        // Nothing frames the body, so the connection's end does.
        closeAfter = true;
      } else {
        (codings ??= []).add(TransferEncoding.chunked.name);
      }
      transferEncoding = codings;
    }
    return ResponseFraming._(
      sendBody: hasBody && !head,
      contentLength: contentLength,
      transferEncoding: transferEncoding,
      contentType: contentType,
      date: date,
      dateLine: dateLine,
      closeAfter: closeAfter,
      connection: setsConnection ? null : _option(closeAfter, protocol),
    );
  }

  /// The Connection option for a response that sets no Connection value
  /// of its own.
  static ConnectionHeaderType? _option(bool closeAfter, HttpProtocol protocol) {
    if (closeAfter) return ConnectionHeaderType.close;
    if (protocol == HttpProtocol.http10) return ConnectionHeaderType.keepAlive;
    return null;
  }

  /// A header of the response, read as typed.
  ///
  /// A value the handler set that does not parse is the handler's error,
  /// not the client's, so it is a [FormatException] and not the
  /// [HeaderException] the core answers with 400.
  static T _own<T>(T Function() read, HeaderName name) {
    try {
      return read();
    } on HeaderException catch (e) {
      throw FormatException(
        "The response's ${e.headerType} header does not parse: "
        '${e.description}',
      );
    }
  }

  /// Whether the body goes out in chunked coding.
  bool get chunked => transferEncoding?.last == TransferEncoding.chunked.name;

  /// Whether the framing, not the headers, supplies [name].
  static bool isFramingHeader(HeaderName name) =>
      name == HeaderName.contentLength ||
      name == HeaderName.contentType ||
      name == HeaderName.transferEncoding;

  /// Whether [type] is multipart/byteranges, which frames itself with
  /// Content-Range (RFC 7233 4.1) and so is not chunked.
  static bool _isMultipartByteranges(BodyType? type) =>
      type != null &&
      type.mimeType.primaryType == MimeType.multipartByteranges.primaryType &&
      type.mimeType.subType == MimeType.multipartByteranges.subType;
}
