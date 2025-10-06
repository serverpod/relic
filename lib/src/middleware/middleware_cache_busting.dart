import 'dart:io';

import '../../relic.dart';
import '../adapter/context.dart';

/// Middleware and helpers for cache-busted asset URLs in the form
/// "/path/name@`hash`.ext".
///
/// Typical flow:
/// - Outgoing URLs are generated with [withCacheBusting] using a known mount
///   prefix (e.g. "/static") and a filesystem root directory to compute the
///   file's ETag hash. This returns "/static/name@hash.ext".
/// - Incoming requests are passed through [stripCacheBusting] so that
///   downstream handlers (e.g. static handler) receive a path without the
///   embedded hash.

/// Returns a middleware that strips an inline cache-busting hash in the last
/// path segment under the provided [mountPrefix].
///
/// For a request like "/static/images/logo@abc123.png" and mountPrefix
/// "/static", this rewrites the request URL to "/static/images/logo.png"
/// before calling the next handler.
Middleware stripCacheBusting(final String mountPrefix) {
  final normalizedMount = _normalizeMount(mountPrefix);

  return (final inner) {
    return (final ctx) async {
      final req = ctx.request;
      final fullPath = Uri.decodeFull(req.requestedUri.path);

      if (!fullPath.startsWith(normalizedMount)) {
        return await inner(ctx);
      }

      // Extract the portion after mount prefix
      final relative = fullPath.substring(normalizedMount.length);
      final segments = relative.split('/');
      if (segments.isEmpty || segments.last.isEmpty) {
        return await inner(ctx);
      }

      final last = segments.last;
      final strippedLast = _stripHashFromFilename(last);
      if (identical(strippedLast, last)) {
        return await inner(ctx);
      }

      segments[segments.length - 1] = strippedLast;
      final rewrittenRelative = segments.join('/');

      // Rebuild a new Request only by updating requestedUri path; do not touch
      // handlerPath so that routers and mounts continue to work as configured.
      final newRequested = req.requestedUri.replace(
        path: '$normalizedMount$rewrittenRelative',
      );
      final rewrittenRequest = req.copyWith(requestedUri: newRequested);
      return await inner(rewrittenRequest.toContext(ctx.token));
    };
  };
}

/// Produces a cache-busted path by appending `@etag` before the file
/// extension, if any. Example: "/static/img/logo.png" ->
/// "/static/img/logo@etag.png".
///
/// - [mountPrefix]: the URL prefix under which static assets are served
///   (e.g., "/static"). Must start with "/".
/// - [fileSystemRoot]: absolute or relative path to the directory used by the
///   static handler to serve files. The path after [mountPrefix] is mapped onto
///   this filesystem root to locate the actual file and its ETag.
Future<String> withCacheBusting({
  required final String mountPrefix,
  required final String fileSystemRoot,
  required final String staticPath,
}) async {
  final normalizedMount = _normalizeMount(mountPrefix);
  if (!staticPath.startsWith(normalizedMount)) return staticPath;

  // Determine relative path after the mount prefix
  final relative = staticPath.substring(normalizedMount.length);
  final filePath = File(_joinPaths(fileSystemRoot, relative));

  final info = await getStaticFileInfo(filePath);

  // Insert @etag before extension
  final lastSlash = staticPath.lastIndexOf('/');
  final dir = lastSlash >= 0 ? staticPath.substring(0, lastSlash + 1) : '';
  final fileName =
      lastSlash >= 0 ? staticPath.substring(lastSlash + 1) : staticPath;

  final dot = fileName.lastIndexOf('.');
  if (dot <= 0 || dot == fileName.length - 1) {
    return '$dir${_appendHashToBasename(fileName, info.etag)}';
  }

  final base = fileName.substring(0, dot);
  final ext = fileName.substring(dot); // includes dot
  return '$dir${_appendHashToBasename(base, info.etag)}$ext';
}

String _appendHashToBasename(final String base, final String etag) =>
    '$base@$etag';

String _normalizeMount(final String mountPrefix) {
  if (!mountPrefix.startsWith('/')) {
    throw ArgumentError('mountPrefix must start with "/"');
  }
  return mountPrefix.endsWith('/') ? mountPrefix : '$mountPrefix/';
}

String _stripHashFromFilename(final String fileName) {
  // Match name@hash.ext or name@hash (no extension)
  final dot = fileName.lastIndexOf('.');
  final main = dot > 0 ? fileName.substring(0, dot) : fileName;
  final ext = dot > 0 ? fileName.substring(dot) : '';

  final at = main.lastIndexOf('@');
  if (at <= 0) return fileName; // no hash or starts with '@'

  final base = main.substring(0, at);
  return '$base$ext';
}

String _joinPaths(final String a, final String b) {
  if (a.endsWith('/')) return '$a$b';
  return '$a/$b';
}
