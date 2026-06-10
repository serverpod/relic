import '../../../../relic_core.dart';
import '../../extension/string_list_extensions.dart';

/// A class representing the HTTP Cache-Control header.
///
/// This class manages cache directives like `no-cache`, `no-store`, `max-age`,
/// `must-revalidate`, etc. It supports parsing header values and generating
/// the appropriate header string.
final class CacheControlHeader {
  static const codec = HeaderCodec(CacheControlHeader.parse, __encode);
  static List<String> __encode(final CacheControlHeader value) => [
    value._encode(),
  ];
  // Cache-Control directive constants
  static const String _noCacheDirective = 'no-cache';
  static const String _noStoreDirective = 'no-store';
  static const String _mustRevalidateDirective = 'must-revalidate';
  static const String _proxyRevalidateDirective = 'proxy-revalidate';
  static const String _noTransformDirective = 'no-transform';
  static const String _onlyIfCachedDirective = 'only-if-cached';
  static const String _immutableDirective = 'immutable';
  static const String _mustUnderstandDirective = 'must-understand';
  static const String _publicDirective = 'public';
  static const String _privateDirective = 'private';
  static const String _maxAgeDirective = 'max-age';
  static const String _staleWhileRevalidateDirective = 'stale-while-revalidate';
  static const String _sMaxAgeDirective = 's-maxage';
  static const String _staleIfErrorDirective = 'stale-if-error';
  static const String _maxStaleDirective = 'max-stale';
  static const String _minFreshDirective = 'min-fresh';

  static const Iterable<String> _validDirectives = [
    _noCacheDirective,
    _noStoreDirective,
    _mustRevalidateDirective,
    _proxyRevalidateDirective,
    _noTransformDirective,
    _onlyIfCachedDirective,
    _immutableDirective,
    _mustUnderstandDirective,
    _publicDirective,
    _privateDirective,
    _maxAgeDirective,
    _staleWhileRevalidateDirective,
    _sMaxAgeDirective,
    _staleIfErrorDirective,
    _maxStaleDirective,
    _minFreshDirective,
  ];

  /// Specifies that the response should not be cached.
  final bool noCache;

  /// Specifies that the cache should not store the response.
  final bool noStore;

  /// Specifies the maximum amount of time (in seconds) a resource is considered fresh.
  final int? maxAge;

  /// Specifies the maximum amount of time (in seconds) a stale resource can be used.
  final int? staleWhileRevalidate;

  /// Specifies whether the cache can be shared by different users (public caching).
  final bool? publicCache;

  /// Specifies that the resource is only for private use (specific to a single user).
  final bool? privateCache;

  /// Specifies that the response must be revalidated with the origin server before use.
  final bool mustRevalidate;

  /// Specifies that the shared cache must revalidate with the origin server before use.
  final bool proxyRevalidate;

  /// Specifies the maximum amount of time (in seconds) a resource is considered fresh for shared caches.
  final int? sMaxAge;

  /// Indicates that the response is allowed to be transformed by intermediaries.
  final bool noTransform;

  /// Indicates that the response should only be returned from cache and not fetch from origin.
  final bool onlyIfCached;

  /// Specifies the maximum amount of time (in seconds) a stale resource can be used while the cache is being refreshed.
  final int? staleIfError;

  /// Specifies the maximum amount of time (in seconds) a stale resource can be used.
  final int? maxStale;

  /// Specifies the minimum amount of time (in seconds) a resource is considered fresh.
  final int? minFresh;

  /// Indicates that the response is immutable.
  final bool immutable;

  /// Indicates that the response must be understood by the cache.
  final bool mustUnderstand;

  /// Constructs a [CacheControlHeader] instance with the specified directives.
  CacheControlHeader({
    this.noCache = false,
    this.noStore = false,
    this.maxAge,
    this.staleWhileRevalidate,
    this.publicCache,
    this.privateCache,
    this.mustRevalidate = false,
    this.proxyRevalidate = false,
    this.sMaxAge,
    this.noTransform = false,
    this.onlyIfCached = false,
    this.staleIfError,
    this.maxStale,
    this.minFresh,
    this.immutable = false,
    this.mustUnderstand = false,
  }) {
    if (publicCache == true && privateCache == true) {
      throw const FormatException('Must be either public or private');
    }
  }

  static final Set<String> _validDirectiveSet = _validDirectives.toSet();

  /// Parses a `delta-seconds` directive value, returning `null` for an absent
  /// or non-numeric value (lenient) but rejecting a negative value.
  static int? _delta(final String? raw, final String name) {
    if (raw == null || raw.isEmpty) return null;
    final n = int.tryParse(raw);
    if (n == null) return null;
    if (n < 0) {
      throw FormatException('$name must be non-negative');
    }
    return n;
  }

  /// Parses the Cache-Control header value and returns a [CacheControlHeader] instance.
  ///
  /// This method splits the header value by commas, trims each directive, and processes
  /// common cache directives like `no-cache`, `no-store`, `max-age`, etc.
  factory CacheControlHeader.parse(final Iterable<String> values) {
    final directives = values.splitTrimAndFilterUnique();

    if (directives.isEmpty) {
      throw const FormatException('Directives cannot be empty');
    }

    bool noCache = false;
    bool noStore = false;
    bool mustRevalidate = false;
    bool proxyRevalidate = false;
    bool noTransform = false;
    bool onlyIfCached = false;
    bool immutable = false;
    bool mustUnderstand = false;
    bool publicCache = false;
    bool privateCache = false;
    int? maxAge;
    int? staleWhileRevalidate;
    int? sMaxAge;
    int? staleIfError;
    int? maxStale;
    int? minFresh;

    for (final directive in directives) {
      // Directive names are matched exactly (so `max-age-extended` is not
      // mistaken for `max-age`) and case-insensitively (RFC 9111 5.2). The
      // optional `="..."` argument is split off here; `no-cache`/`private`
      // are recognized even when carrying a field-list.
      final eq = directive.indexOf('=');
      final name = (eq < 0 ? directive : directive.substring(0, eq))
          .trim()
          .toLowerCase();
      final rawValue = eq < 0 ? null : directive.substring(eq + 1).trim();

      if (!_validDirectiveSet.contains(name)) {
        throw const FormatException('Invalid directive');
      }

      switch (name) {
        case _noCacheDirective:
          noCache = true;
        case _noStoreDirective:
          noStore = true;
        case _mustRevalidateDirective:
          mustRevalidate = true;
        case _proxyRevalidateDirective:
          proxyRevalidate = true;
        case _noTransformDirective:
          noTransform = true;
        case _onlyIfCachedDirective:
          onlyIfCached = true;
        case _immutableDirective:
          immutable = true;
        case _mustUnderstandDirective:
          mustUnderstand = true;
        case _publicDirective:
          publicCache = true;
        case _privateDirective:
          privateCache = true;
        case _maxAgeDirective:
          maxAge = _delta(rawValue, name);
        case _staleWhileRevalidateDirective:
          staleWhileRevalidate = _delta(rawValue, name);
        case _sMaxAgeDirective:
          sMaxAge = _delta(rawValue, name);
        case _staleIfErrorDirective:
          staleIfError = _delta(rawValue, name);
        case _maxStaleDirective:
          maxStale = _delta(rawValue, name);
        case _minFreshDirective:
          minFresh = _delta(rawValue, name);
      }
    }

    if (publicCache && privateCache) {
      throw const FormatException('Cannot be both public and private');
    }

    return CacheControlHeader(
      noCache: noCache,
      noStore: noStore,
      mustRevalidate: mustRevalidate,
      proxyRevalidate: proxyRevalidate,
      noTransform: noTransform,
      onlyIfCached: onlyIfCached,
      maxAge: maxAge,
      staleWhileRevalidate: staleWhileRevalidate,
      sMaxAge: sMaxAge,
      publicCache: publicCache,
      privateCache: privateCache,
      staleIfError: staleIfError,
      maxStale: maxStale,
      minFresh: minFresh,
      immutable: immutable,
      mustUnderstand: mustUnderstand,
    );
  }

  /// Converts the [CacheControlHeader] instance into a string representation suitable for HTTP headers.
  ///
  /// This method generates the header string by concatenating the set directives.
  String _encode() {
    final List<String> directives = [];
    if (noCache) directives.add(_noCacheDirective);
    if (noStore) directives.add(_noStoreDirective);
    if (mustRevalidate) directives.add(_mustRevalidateDirective);
    if (proxyRevalidate) directives.add(_proxyRevalidateDirective);
    if (noTransform) directives.add(_noTransformDirective);
    if (onlyIfCached) directives.add(_onlyIfCachedDirective);
    if (immutable) directives.add(_immutableDirective);
    if (mustUnderstand) directives.add(_mustUnderstandDirective);
    if (publicCache == true) directives.add(_publicDirective);
    if (privateCache == true) directives.add(_privateDirective);
    if (maxAge != null) directives.add('$_maxAgeDirective=$maxAge');
    if (staleWhileRevalidate != null) {
      directives.add('$_staleWhileRevalidateDirective=$staleWhileRevalidate');
    }
    if (sMaxAge != null) directives.add('$_sMaxAgeDirective=$sMaxAge');
    if (staleIfError != null) {
      directives.add('$_staleIfErrorDirective=$staleIfError');
    }
    if (maxStale != null) directives.add('$_maxStaleDirective=$maxStale');
    if (minFresh != null) directives.add('$_minFreshDirective=$minFresh');

    return directives.join(', ');
  }

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is CacheControlHeader &&
          noCache == other.noCache &&
          noStore == other.noStore &&
          maxAge == other.maxAge &&
          staleWhileRevalidate == other.staleWhileRevalidate &&
          publicCache == other.publicCache &&
          privateCache == other.privateCache &&
          mustRevalidate == other.mustRevalidate &&
          proxyRevalidate == other.proxyRevalidate &&
          sMaxAge == other.sMaxAge &&
          noTransform == other.noTransform &&
          onlyIfCached == other.onlyIfCached &&
          staleIfError == other.staleIfError &&
          maxStale == other.maxStale &&
          minFresh == other.minFresh &&
          immutable == other.immutable &&
          mustUnderstand == other.mustUnderstand;

  @override
  int get hashCode => Object.hashAll([
    noCache,
    noStore,
    maxAge,
    staleWhileRevalidate,
    publicCache,
    privateCache,
    mustRevalidate,
    proxyRevalidate,
    sMaxAge,
    noTransform,
    onlyIfCached,
    staleIfError,
    maxStale,
    minFresh,
    immutable,
    mustUnderstand,
  ]);

  @override
  String toString() {
    return 'CacheControlHeader('
        'noCache: $noCache, '
        'noStore: $noStore, '
        'maxAge: $maxAge, '
        'staleWhileRevalidate: $staleWhileRevalidate, '
        'publicCache: $publicCache, '
        'privateCache: $privateCache, '
        'mustRevalidate: $mustRevalidate, '
        'proxyRevalidate: $proxyRevalidate, '
        'sMaxAge: $sMaxAge, '
        'noTransform: $noTransform, '
        'onlyIfCached: $onlyIfCached, '
        'staleIfError: $staleIfError, '
        'maxStale: $maxStale, '
        'minFresh: $minFresh, '
        'immutable: $immutable, '
        'mustUnderstand: $mustUnderstand'
        ')';
  }
}
