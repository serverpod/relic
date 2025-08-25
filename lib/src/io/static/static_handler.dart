import 'dart:async';
import 'dart:convert';
import 'dart:io';
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
class _FileInfo {
  final MimeType? mimeType;
  final FileStat stat;
  final String etag;

  const _FileInfo(this.mimeType, this.stat, this.etag);
}

/// LRU cache for file information to avoid repeated file system operations.
final _fileInfoCache = LruCache<String, _FileInfo>(10000);

/// Creates a Relic [Handler] that serves files from the provided [fileSystemPath].
///
/// When a file is requested, it is served with appropriate headers including
/// ETag, Last-Modified, and Cache-Control. The handler supports:
/// - Conditional requests (If-None-Match, If-Modified-Since)
/// - Range requests for partial content
/// - Proper MIME type detection
///
/// If the requested path doesn't correspond to a file, returns [defaultResponse].
/// Directory listings are not supported for security reasons.
///
/// The [mimeResolver] can be provided to customize MIME type detection.
/// The [cacheControl] header can be customized; defaults to no-cache with private cache.
Handler createStaticHandler(
  final String fileSystemPath, {
  Handler? defaultHandler,
  final MimeTypeResolver? mimeResolver,
  final CacheControlHeader? cacheControl,
}) {
  final rootDir = Directory(fileSystemPath);
  if (!rootDir.existsSync()) {
    throw ArgumentError('A directory corresponding to fileSystemPath '
        '"$fileSystemPath" could not be found');
  }

  final resolvedRootPath = rootDir.resolveSymbolicLinksSync();
  defaultHandler ??= respondWith((final _) => Response.notFound());

  return (final NewContext ctx) async {
    final requestPath = ctx.remainingPath.path;
    final filePath = p.join(resolvedRootPath, requestPath.substring(1));

    // Ensure file exists and is not a directory
    final entityType = FileSystemEntity.typeSync(filePath, followLinks: false);
    if (entityType == FileSystemEntityType.notFound ||
        entityType == FileSystemEntityType.directory) {
      return defaultHandler!(ctx);
    }

    // Security check for symbolic links: ensure resolved path stays within root directory
    var file = File(filePath);
    final resolvedFilePath = file.resolveSymbolicLinksSync();
    if (!p.isWithin(resolvedRootPath, resolvedFilePath)) {
      return defaultHandler!(ctx);
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
/// The [mimeResolver] can be provided to customize MIME type detection.
/// The [cacheControl] header can be customized; defaults to no-cache with private cache.
Handler createFileHandler(
  final String filePath, {
  final MimeTypeResolver? mimeResolver,
  final CacheControlHeader? cacheControl,
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
      cacheControl ?? CacheControlHeader(noCache: true, privateCache: true),
      ctx,
    );
  };
}

/// Serves a file with full HTTP semantics including conditional requests and ranges.
Future<ResponseContext> _serveFile(
  final File file,
  final MimeTypeResolver mimeResolver,
  final CacheControlHeader? cacheControl,
  final NewContext ctx,
) async {
  // Validate HTTP method
  final method = ctx.request.method;
  if (!_isMethodAllowed(method)) return _methodNotAllowedResponse(ctx);

  // Get or update cached file information
  final fileInfo = await _getFileInfo(file, mimeResolver);
  final headers = _buildBaseHeaders(fileInfo, cacheControl);

  // Handle conditional requests
  final conditionalResponse = _checkConditionalHeaders(ctx, fileInfo, headers);
  if (conditionalResponse != null) return ctx.withResponse(conditionalResponse);

  // Handle range requests
  final rangeHeader = ctx.request.headers.range;
  if (rangeHeader != null) {
    return await _handleRangeRequest(ctx, file, fileInfo, headers, rangeHeader);
  }

  // Serve full file
  return _serveFullFile(ctx, file, fileInfo, headers, method);
}

/// Checks if the HTTP method is allowed for file serving.
bool _isMethodAllowed(final RequestMethod method) {
  return method == RequestMethod.get || method == RequestMethod.head;
}

/// Returns a 405 Method Not Allowed response.
ResponseContext _methodNotAllowedResponse(final NewContext ctx) {
  return ctx.withResponse(Response(
    HttpStatus.methodNotAllowed,
    headers: Headers.build((final mh) => mh.allow = [
          RequestMethod.get,
          RequestMethod.head,
        ]),
  ));
}

/// Gets file information from cache or creates new cache entry.
Future<_FileInfo> _getFileInfo(
  final File file,
  final MimeTypeResolver mimeResolver,
) async {
  final stat = file.statSync();
  final cachedInfo = _fileInfoCache[file.path];

  // Check if cache is valid
  if (cachedInfo != null &&
      stat.size == cachedInfo.stat.size &&
      !stat.changed.isAfter(cachedInfo.stat.changed)) {
    return cachedInfo;
  }

  // Generate new file info
  final etag = await _generateETag(file);
  final mimeType = await _detectMimeType(file, mimeResolver);

  final fileInfo = _FileInfo(mimeType, stat, etag);
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
      .first;

  final mimeString = mimeResolver.lookup(file.path, headerBytes: headerBytes);
  return mimeString != null ? MimeType.parse(mimeString) : null;
}

/// Builds base response headers common to all responses.
Headers _buildBaseHeaders(
    final _FileInfo fileInfo, final CacheControlHeader? cacheControl) {
  return Headers.build((final mh) => mh
    ..acceptRanges = AcceptRangesHeader.bytes()
    ..contentLength = fileInfo.stat.size
    ..etag = ETagHeader(value: fileInfo.etag)
    ..lastModified = fileInfo.stat.modified
    ..cacheControl = cacheControl);
}

/// Checks conditional request headers and returns 304 response if appropriate.
Response? _checkConditionalHeaders(
  final NewContext ctx,
  final _FileInfo fileInfo,
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
  final File file,
  final _FileInfo fileInfo,
  final Headers headers,
  final RangeHeader rangeHeader,
) async {
  // Check If-Range header
  if (!_isRangeRequestValid(ctx, fileInfo)) {
    return _serveFullFile(ctx, file, fileInfo, headers, ctx.request.method);
  }

  final ranges = rangeHeader.ranges;
  return switch (ranges.length) {
    0 => _serveFullFile(ctx, file, fileInfo, headers, ctx.request.method),
    1 => _serveSingleRange(ctx, file, fileInfo, headers, ranges.first),
    _ => await _serveMultipleRanges(ctx, file, fileInfo, headers, ranges),
  };
}

/// Validates If-Range header for range requests.
bool _isRangeRequestValid(final NewContext ctx, final _FileInfo fileInfo) {
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
  final File file,
  final _FileInfo fileInfo,
  final Headers headers,
  final RequestMethod method,
) {
  return ctx.withResponse(Response.ok(
    headers: headers,
    body: method == RequestMethod.head
        ? null
        : _createFileBody(file, fileInfo, fileInfo.stat.size),
  ));
}

/// Serves a single range of the file.
ResponseContext _serveSingleRange(
  final NewContext ctx,
  final File file,
  final _FileInfo fileInfo,
  final Headers headers,
  final Range range,
) {
  final (start, end) = _calculateRangeBounds(range, fileInfo.stat.size);

  // If range is invalid
  if (start == end) {
    return ctx.withResponse(Response(416, headers: headers));
  }

  final length = end - start;

  return ctx.withResponse(Response(
    HttpStatus.partialContent,
    headers: headers.transform((final mh) => mh
      ..contentRange = ContentRangeHeader(
        start: start,
        end: end - 1,
        size: fileInfo.stat.size,
      )
      ..contentLength = length),
    body: _createRangeBody(file, fileInfo, start, end),
  ));
}

/// Serves multiple ranges as multipart response.
Future<ResponseContext> _serveMultipleRanges(
  final NewContext ctx,
  final File file,
  final _FileInfo fileInfo,
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
      file,
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

  return ctx.withResponse(Response(
    HttpStatus.partialContent,
    headers: headers.transform((final mh) => mh
      ..contentLength = totalLength
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
  final File file,
  final _FileInfo fileInfo,
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
  await for (final chunk in file.openRead(start, end).cast<Uint8List>()) {
    controller.add(chunk);
    totalBytes += chunk.length;
  }

  return totalBytes;
}

/// Creates a Body for the full file or range.
Body _createFileBody(
    final File file, final _FileInfo fileInfo, final int contentLength) {
  return Body.fromDataStream(
    file.openRead().cast(),
    contentLength: contentLength,
    mimeType: fileInfo.mimeType ?? MimeType.octetStream,
    encoding: fileInfo.mimeType?.isText == true ? utf8 : null,
  );
}

/// Creates a Body for a specific range of the file.
Body _createRangeBody(
    final File file, final _FileInfo fileInfo, final int start, final int end) {
  return Body.fromDataStream(
    file.openRead(start, end).cast(),
    contentLength: end - start,
    mimeType: fileInfo.mimeType,
    encoding: fileInfo.mimeType?.isText == true ? utf8 : null,
  );
}
