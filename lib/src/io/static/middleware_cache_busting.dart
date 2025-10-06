import 'dart:io';
import 'package:path/path.dart' as p;

import '../../../relic.dart';
import '../../adapter/context.dart';

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
Middleware cacheBusting(final CacheBustingConfig config) {
  return (final inner) {
    return (final ctx) async {
      final req = ctx.request;
      final fullPath = req.requestedUri.path;

      if (!fullPath.startsWith(config.mountPrefix)) {
        return await inner(ctx);
      }

      // Extract the portion after mount prefix
      final relative = fullPath.substring(config.mountPrefix.length);
      final last = p.url.basename(relative);
      if (last.isEmpty) {
        return await inner(ctx);
      }

      final strippedLast = _stripHashFromFilename(last);
      if (strippedLast == last) {
        return await inner(ctx);
      }

      final directory = p.url.dirname(relative);
      final rewrittenRelative =
          directory == '.' ? strippedLast : p.url.join(directory, strippedLast);

      // Rebuild a new Request only by updating requestedUri path; do not touch
      // handlerPath so that routers and mounts continue to work as configured.
      final newRequested = req.requestedUri.replace(
        path: '${config.mountPrefix}$rewrittenRelative',
      );
      final rewrittenRequest = req.copyWith(requestedUri: newRequested);
      return await inner(rewrittenRequest.toContext(ctx.token));
    };
  };
}

String _stripHashFromFilename(final String fileName) {
  // Match name@hash.ext or name@hash (no extension)
  final ext = p.url.extension(fileName);
  final base = p.url.basenameWithoutExtension(fileName);

  final at = base.lastIndexOf('@');
  if (at <= 0) return fileName; // no hash or starts with '@'

  final cleanBase = base.substring(0, at);
  return p.url.setExtension(cleanBase, ext);
}

/// Holds configuration for generating cache-busted asset URLs.
class CacheBustingConfig {
  /// The URL prefix under which static assets are served (e.g., "/static").
  final String mountPrefix;

  /// Filesystem root corresponding to [mountPrefix].
  final Directory fileSystemRoot;

  CacheBustingConfig({
    required final String mountPrefix,
    required final Directory fileSystemRoot,
  })  : mountPrefix = _normalizeMount(mountPrefix),
        fileSystemRoot = fileSystemRoot.absolute;

  /// Returns the cache-busted URL for the given [staticPath].
  ///
  /// Example: '/static/logo.svg' -> '/static/logo@etag.svg'
  Future<String> bust(final String staticPath) async {
    if (!staticPath.startsWith(mountPrefix)) return staticPath;

    final relative = staticPath.substring(mountPrefix.length);
    final filePath = File(p.join(fileSystemRoot.path, relative));

    // Fail fast with a consistent exception type for non-existent files
    if (!filePath.existsSync()) {
      throw PathNotFoundException(
        filePath.path,
        const OSError('No such file or directory', 2),
      );
    }

    final info = await getStaticFileInfo(filePath);

    // Build the busted URL using URL path helpers for readability/portability
    final directory = p.url.dirname(staticPath);
    final baseName = p.url.basenameWithoutExtension(staticPath);
    final ext = p.url.extension(staticPath); // includes leading dot or ''

    final bustedName = '$baseName@${info.etag}$ext';
    return directory == '.'
        ? '/$bustedName'
        : p.url.join(directory, bustedName);
  }

  /// Attempts to generate a cache-busted URL. If the underlying file cannot be
  /// found or read, it returns [staticPath] unchanged.
  Future<String> tryBust(final String staticPath) async {
    try {
      return await bust(staticPath);
    } catch (_) {
      return staticPath;
    }
  }
}

// removed helper for inlining

String _normalizeMount(final String mountPrefix) {
  if (!mountPrefix.startsWith('/')) {
    throw ArgumentError('mountPrefix must start with "/"');
  }
  return mountPrefix.endsWith('/') ? mountPrefix : '$mountPrefix/';
}

// path joining handled by package:path's p.join
