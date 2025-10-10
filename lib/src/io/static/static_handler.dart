import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;

import '../../../relic.dart';
import '../../router/lru_cache.dart';

/// The default resolver for MIME types based on file extensions.
final _defaultMimeTypeResolver = MimeTypeResolver();

/// Cached file information including MIME type, file stats, and ETag.
class FileInfo {
  final File file;
  final MimeType? mimeType;
  final FileStat stat;
  final String etag;

  bool get isStale {
    final freshStat = file.statSync();
    return stat.size != freshStat.size ||
        stat.changed.isBefore(freshStat.changed);
  }

  const FileInfo(this.file, this.mimeType, this.stat, this.etag);
}

typedef CacheControlFactory = CacheControlHeader? Function(
  NewContext ctx,
  FileInfo fileInfo,
);

/// LRU cache for file information to avoid repeated file system operations.
final _fileInfoCache = LruCache<String, FileInfo>(10000);

/// Public accessor for retrieving [FileInfo] for a given [file].
///
/// Uses the same logic as the internal cache/population used by the static
/// file handler and respects MIME type detection.
Future<FileInfo> getStaticFileInfo(
  final File file, {
  final MimeTypeResolver? mimeResolver,
}) async =>
    _getFileInfo(file, mimeResolver ?? _defaultMimeTypeResolver);

/// Creates a Relic [Handler] that serves files from the provided [fileSystemPath].
///
/// When a file is requested, it is served with appropriate headers including
/// ETag, Last-Modified, and Cache-Control. The handler supports:
/// - Conditional requests (If-None-Match, If-Modified-Since, If-Range (for range request))
/// - Range requests for partial content (multi-range is supported, but ranges are not coalesced)
/// - Proper MIME type detection (from magic-bytes prefixes, or file extension)
///
/// If the requested path doesn't correspond to a file, the [defaultHandler] is called.
/// If no [defaultHandler] is provided, a 404 Not Found response is returned.
/// Directory listings are not supported for security reasons.
///
/// The handler requires the request method to be either GET, or HEAD.
/// Otherwise, a 405 Method Not Allowed response is returned with an
/// appropriate Allow header.
///
/// The [mimeResolver] can be provided to customize MIME type detection.
/// The [cacheControl] header can be customized using [cacheControl] callback.
///
/// If [cacheBustingConfig] is provided, the handler will strip cache-busting
/// hashes from the last path segment before looking up any file.
/// See [CacheBustingConfig] for details.
Handler createStaticHandler(
  final String fileSystemPath, {
  final Handler? defaultHandler,
  final MimeTypeResolver? mimeResolver,
  required final CacheControlFactory cacheControl,
  final CacheBustingConfig? cacheBustingConfig,
}) {
  final rootDir = Directory(fileSystemPath);
  if (!rootDir.existsSync()) {
    throw ArgumentError('A directory corresponding to fileSystemPath '
        '"$fileSystemPath" could not be found');
  }

  final resolvedRootPath = rootDir.resolveSymbolicLinksSync();
  final fallbackHandler =
      defaultHandler ?? respondWith((final _) => Response.notFound());

  final resolveFilePath = switch (cacheBustingConfig) {
    null =>
      (final String resolvedRootPath, final List<String> requestSegments) =>
          p.joinAll([resolvedRootPath, ...requestSegments]),
    final cfg =>
      (final String resolvedRootPath, final List<String> requestSegments) {
        if (requestSegments.isEmpty) {
          return resolvedRootPath;
        }

        final fileName = cfg.tryStripHashFromFilename(requestSegments.last);
        return p.joinAll([
          resolvedRootPath,
          ...requestSegments.sublist(0, requestSegments.length - 1),
          fileName,
        ]);
      }
  };

  return (final NewContext ctx) async {
    final filePath =
        resolveFilePath(resolvedRootPath, ctx.remainingPath.segments);

    // Ensure file exists and is not a directory
    final entityType = FileSystemEntity.typeSync(filePath, followLinks: false);
    if (entityType == FileSystemEntityType.notFound ||
        entityType == FileSystemEntityType.directory) {
      return fallbackHandler(ctx);
    }

    // Security check for symbolic links: ensure resolved path stays within root directory
    var file = File(filePath);
    final resolvedFilePath = file.resolveSymbolicLinksSync();
    if (!p.isWithin(resolvedRootPath, resolvedFilePath)) {
      return fallbackHandler(ctx);
    }
    file = File(resolvedFilePath);

    return await _serveFile(
      file,
      mimeResolver ?? _defaultMimeTypeResolver,
      cacheControl,
      ctx,
    );
  };
}

/// Creates a Relic [Handler] that serves a single file at [filePath].
///
/// The file must exist at the specified path or an [ArgumentError] is thrown.
/// Supports the same features as [createStaticHandler] but for a single file.
///
/// The handler requires the request method to be either GET or HEAD.
/// Otherwise, a 405 Method Not Allowed response is returned with an
/// appropriate Allow header.
///
/// The [mimeResolver] can be provided to customize MIME type detection.
/// The [cacheControl] header can be customized using [cacheControl] callback.
Handler createFileHandler(
  final String filePath, {
  final MimeTypeResolver? mimeResolver,
  required final CacheControlFactory cacheControl,
}) {
  final file = File(filePath);
  if (!file.existsSync()) {
    throw ArgumentError(
        'A file corresponding to filePath "$filePath" could not be found');
  }

  return (final NewContext ctx) async {
    return await _serveFile(
      file,
      mimeResolver ?? _defaultMimeTypeResolver,
      cacheControl,
      ctx,
    );
  };
}

/// Serves a file with full HTTP semantics including conditional requests and ranges.
Future<ResponseContext> _serveFile(
  final File file,
  final MimeTypeResolver mimeResolver,
  final CacheControlFactory cacheControl,
  final NewContext ctx,
) async {
  // Validate HTTP method
  final method = ctx.request.method;
  if (!_isMethodAllowed(method)) return _methodNotAllowedResponse(ctx);

  // Get or update cached file information
  final fileInfo = await _getFileInfo(file, mimeResolver);
  final headers = _buildBaseHeaders(fileInfo, cacheControl(ctx, fileInfo));

  // Handle conditional requests
  final conditionalResponse = _checkConditionalHeaders(ctx, fileInfo, headers);
  if (conditionalResponse != null) return ctx.respond(conditionalResponse);

  // Handle range requests
  final rangeHeader = ctx.request.headers.range;
  if (rangeHeader != null) {
    return await _handleRangeRequest(ctx, fileInfo, headers, rangeHeader);
  }

  // Serve full file
  return _serveFullFile(ctx, fileInfo, headers, method);
}

/// Checks if the HTTP method is allowed for file serving.
bool _isMethodAllowed(final Method method) {
  return method == Method.get || method == Method.head;
}

/// Returns a 405 Method Not Allowed response.
ResponseContext _methodNotAllowedResponse(final NewContext ctx) {
  return ctx.respond(Response(
    HttpStatus.methodNotAllowed,
    headers: Headers.build((final mh) => mh.allow = {
          Method.get,
          Method.head,
        }),
  ));
}

/// Gets file information from cache or creates new cache entry.
Future<FileInfo> _getFileInfo(
  final File file,
  final MimeTypeResolver mimeResolver,
) async {
  final stat = file.statSync();
  final cachedInfo = _fileInfoCache[file.path];

  // Check if cache is valid
  if (cachedInfo != null && !cachedInfo.isStale) return cachedInfo;

  // Generate new file info
  final etag = Isolate.run(() => _generateETag(file));
  final mimeType = await _detectMimeType(file, mimeResolver);

  final fileInfo = FileInfo(file, mimeType, stat, await etag);
  _fileInfoCache[file.path] = fileInfo;
  return fileInfo;
}

/// Generates an ETag for the file using SHA-1 hash.
Future<String> _generateETag(final File file) async {
  final hash = await sha1.bind(file.openRead()).last;
  return hash.toString();
}

/// Detects MIME type using file path and content magic numbers.
Future<MimeType?> _detectMimeType(
    final File file, final MimeTypeResolver mimeResolver) async {
  final headerBytes = await file
      .openRead(0, mimeResolver.magicNumbersMaxLength)
      .cast<Uint8List>()
      .firstOrNull;

  final mimeString = mimeResolver.lookup(file.path, headerBytes: headerBytes);
  return mimeString != null ? MimeType.parse(mimeString) : null;
}

/// Builds base response headers common to all responses.
Headers _buildBaseHeaders(
    final FileInfo fileInfo, final CacheControlHeader? cacheControl) {
  return Headers.build((final mh) => mh
    ..acceptRanges = AcceptRangesHeader.bytes()
    ..etag = ETagHeader(value: fileInfo.etag)
    ..lastModified = fileInfo.stat.modified
    ..cacheControl = cacheControl);
}

/// Checks conditional request headers and returns 304 response if appropriate.
Response? _checkConditionalHeaders(
  final NewContext ctx,
  final FileInfo fileInfo,
  final Headers headers,
) {
  // Handle If-None-Match
  final ifNoneMatch = ctx.request.headers.ifNoneMatch;
  if (ifNoneMatch != null) {
    if (ifNoneMatch.isWildcard) return Response.notModified(headers: headers);
    for (final etag in ifNoneMatch.etags) {
      if (etag.value == fileInfo.etag) {
        return Response.notModified(headers: headers);
      }
    }
    return null;
  }

  // Handle If-Modified-Since
  final ifModifiedSince = ctx.request.headers.ifModifiedSince;
  if (ifModifiedSince != null &&
      !ifModifiedSince.isBefore(fileInfo.stat.modified)) {
    return Response.notModified(headers: headers);
  }

  return null;
}

/// Handles HTTP range requests for partial content.
Future<ResponseContext> _handleRangeRequest(
  final NewContext ctx,
  final FileInfo fileInfo,
  final Headers headers,
  final RangeHeader rangeHeader,
) async {
  // Check If-Range header
  if (!_isRangeRequestValid(ctx, fileInfo)) {
    return _serveFullFile(ctx, fileInfo, headers, ctx.request.method);
  }

  final ranges = rangeHeader.ranges;
  return switch (ranges.length) {
    0 => _serveFullFile(ctx, fileInfo, headers, ctx.request.method),
    1 => _serveSingleRange(ctx, fileInfo, headers, ranges.first),
    _ => await _serveMultipleRanges(ctx, fileInfo, headers, ranges),
  };
}

/// Validates If-Range header for range requests.
bool _isRangeRequestValid(final NewContext ctx, final FileInfo fileInfo) {
  final ifRange = ctx.request.headers.ifRange;
  if (ifRange == null) return true;

  // Check ETag match
  final etag = ifRange.etag;
  if (etag != null) return etag.value == fileInfo.etag;

  // Check Last-Modified match
  final lastModified = ifRange.lastModified;
  if (lastModified != null) {
    return !lastModified.isBefore(fileInfo.stat.modified);
  }

  // Unreachable, ifRange parser would throw on first access
  assert(false, 'Invalid If-Range header');
  return false;
}

/// Serves the complete file without ranges.
ResponseContext _serveFullFile(
  final NewContext ctx,
  final FileInfo fileInfo,
  final Headers headers,
  final Method method,
) {
  return ctx.respond(Response.ok(
    headers: headers,
    body: _createFileBody(fileInfo, isHeadRequest: method == Method.head),
  ));
}

/// Serves a single range of the file.
ResponseContext _serveSingleRange(
  final NewContext ctx,
  final FileInfo fileInfo,
  final Headers headers,
  final Range range,
) {
  final (start, end) = _calculateRangeBounds(range, fileInfo.stat.size);

  // If range is invalid
  if (start == end) {
    return ctx.respond(Response(416, headers: headers));
  }

  return ctx.respond(Response(
    HttpStatus.partialContent,
    headers: headers.transform((final mh) => mh
      ..contentRange = ContentRangeHeader(
        start: start,
        end: end - 1,
        size: fileInfo.stat.size,
      )),
    body: _createRangeBody(fileInfo, start, end),
  ));
}

/// Serves multiple ranges as multipart response.
Future<ResponseContext> _serveMultipleRanges(
  final NewContext ctx,
  final FileInfo fileInfo,
  final Headers headers,
  final List<Range> ranges,
) async {
  final boundary = 'RelicMultipartBoundary-${Random().nextInt(1000000)}';
  final controller = StreamController<Uint8List>();
  int totalLength = 0;

  for (final range in ranges) {
    final (start, end) = _calculateRangeBounds(range, fileInfo.stat.size);
    totalLength += await _writeMultipartSection(
      controller,
      fileInfo,
      boundary,
      start,
      end,
    );
  }

  // Write final boundary
  final footerBytes = utf8.encode('\r\n--$boundary--\r\n');
  controller.add(footerBytes);
  totalLength += footerBytes.length;

  unawaited(controller.close());

  return ctx.respond(Response(
    HttpStatus.partialContent,
    headers: headers.transform((final mh) => mh
      ..[Headers.contentTypeHeader] = [
        '${MimeType.multipartByteranges.toHeaderValue()}; boundary=$boundary'
      ]),
    body: Body.fromDataStream(
      controller.stream,
      contentLength: totalLength,
      mimeType: MimeType.multipartByteranges,
      encoding: fileInfo.mimeType?.isText == true ? utf8 : null,
    ),
  ));
}

/// Calculates actual start and end positions for a range.
/// Returns the original range bounds (not clamped to file size) for Content-Range headers,
/// but file.openRead() will naturally clamp the actual reading.
(int start, int end) _calculateRangeBounds(
  final Range range,
  final int fileSize,
) {
  int start;
  int end;
  if (range.start != null) {
    start = range.start!;
    end = range.end == null ? fileSize : range.end! + 1;
  } else {
    start = fileSize - (range.end ?? 0);
    end = fileSize;
  }
  // Ensure start is within bounds
  start = start.clamp(0, fileSize);
  end = end.clamp(start, fileSize);
  return (start, end);
}

/// Writes a single multipart section to the controller.
Future<int> _writeMultipartSection(
  final StreamController<Uint8List> controller,
  final FileInfo fileInfo,
  final String boundary,
  final int start,
  final int end,
) async {
  int totalBytes = 0;

  // Write part header
  final mimeType = fileInfo.mimeType ?? MimeType.octetStream;
  final partHeader = '\r\n--$boundary\r\n'
      'Content-Type: ${mimeType.toHeaderValue()}\r\n'
      'Content-Range: bytes $start-${end - 1}/${fileInfo.stat.size}\r\n\r\n';

  final partHeaderBytes = utf8.encode(partHeader);
  controller.add(partHeaderBytes);
  totalBytes += partHeaderBytes.length;

  // Write file content
  await for (final chunk
      in fileInfo.file.openRead(start, end).cast<Uint8List>()) {
    controller.add(chunk);
    totalBytes += chunk.length;
  }

  return totalBytes;
}

/// Creates a Body for the full file.
Body _createFileBody(
  final FileInfo fileInfo, {
  final bool isHeadRequest = false,
}) {
  return Body.fromDataStream(
    isHeadRequest ? const Stream.empty() : fileInfo.file.openRead().cast(),
    contentLength: fileInfo.stat.size,
    mimeType: fileInfo.mimeType ?? MimeType.octetStream,
    encoding: fileInfo.mimeType?.isText == true ? utf8 : null,
  );
}

/// Creates a Body for a specific range of the file.
Body _createRangeBody(final FileInfo fileInfo, final int start, final int end) {
  return Body.fromDataStream(
    fileInfo.file.openRead(start, end).cast(),
    contentLength: end - start,
    mimeType: fileInfo.mimeType,
    encoding: fileInfo.mimeType?.isText == true ? utf8 : null,
  );
}

extension<T> on Stream<T> {
  Future<T?> get firstOrNull async {
    await for (final value in this) {
      return value;
    }
    return null;
  }
}
