import 'package:relic/relic.dart';
import 'package:test/test.dart';
import 'package:test_utils/test_utils.dart';

import 'headers_test_utils.dart';

void main() {
  group('Given Headers class', () {
    test('when created with default values then it initializes correctly', () {
      final headers = Headers.empty();
      expect(headers, isEmpty);
      expect(headers.date, isNull);
    });

    test('when custom headers are added then they are included', () {
      final headers = Headers.fromMap({
        'X-Custom-Header': ['value'],
      });
      expect(headers['x-custom-header'], equals(['value']));
    });

    test('when custom headers are removed then they are no longer present', () {
      var headers = Headers.fromMap({
        'X-Custom-Header': ['value'],
      });
      headers = headers.transform((mh) => mh.remove('X-Custom-Header'));
      expect(headers['x-custom-header'], isNull);
    });

    test('when accessing headers then they are case insensitive', () {
      final headers = Headers.fromMap({
        'Case-Insensitive': ['value'],
      });
      expect(headers['case-insensitive'], contains('value'));
      expect(headers['CASE-INSENSITIVE'], contains('value'));
    });

    test(
      'when headers are copied then modifications are correctly applied',
      () {
        final headers = Headers.fromMap({
          'Initial-Header': ['initial'],
        });
        final copiedHeaders = headers.transform((mh) {
          mh.remove('Initial-Header');
          mh['Copied-Header'] = ['copied'];
        });
        expect(copiedHeaders['initial-header'], isNull);
        expect(copiedHeaders['copied-header'], equals(['copied']));
      },
    );

    test(
      'when headers are applied to a Response then they are set correctly',
      () {
        final headers = Headers.build((mh) {
          mh['Response-Header'] = ['response-value'];
        });
        final response = Response.ok(headers: headers);

        expect(response.headers['Response-Header'], equals(['response-value']));
      },
    );

    test('when handling large headers then they are processed correctly', () {
      final largeValue = List.filled(10000, 'a').join();
      final headers = Headers.build((mh) {
        mh['Large-Header'] = [largeValue];
      });
      expect(headers['large-header']?.first.length, equals(10000));
    });

    test('when a managed header is removed then it is no longer present', () {
      var headers = Headers.build((mh) => mh.date = DateTime.utc(2025, 9, 23));
      headers = headers.transform((mh) => mh.date = null);
      expect(headers.date, isNull);
    });

    test('when a managed header is updated then it is correctly replaced', () {
      var headers = Headers.build((mh) => mh.date = DateTime.utc(2025, 9, 23));
      final newDate = DateTime.utc(2025, 9, 23)
          .add(const Duration(days: 1))
          .toUtc()
          .copyWith(microsecond: 0, millisecond: 0);
      headers = headers.transform((mh) => mh.date = newDate);
      expect(headers.date, equals(newDate));
    });
  });

  parameterizedGroup(
    (v) => 'Given a "${v.key}" header when calling Headers.build',
    (v) {
      Headers.build((mh) {
        singleTest('then raw value not set', mh.contains(v.key), isFalse);
        singleTest(
          'then assign fails if type of value wrong',
          () => mh.assign(v, Object()),
          throwsA(isA<TypeError>()),
        );
        singleTest(
          'then assign to null succeeds',
          () => mh.assign(v, null),
          returnsNormally,
        );
        singleTest(
          'then assign succeeds if value is correct type',
          () => mh.assign(v, mh(v)),
          returnsNormally,
        );
      });
    },
    variants: Headers.all,
  );

  parameterizedGroup((v) => 'Given a "${v.key}" header with no raw value', (v) {
    late final headers = Headers.empty();

    singleTest('then raw value not set', headers.contains(v.key), isFalse);
    singleTest('then call is null', headers(v), isNull);
    singleTest('then tryGet is null', headers.tryGet(v), isNull);
    singleTest('then get throws', () => headers.get(v), throwsMissingHeader);
  }, variants: Headers.all);

  parameterizedGroup(
    (v) => 'Given a "${v.key}" header with an empty raw value',
    (v) {
      late final headers = Headers.fromMap({
        v.key.lower: [''],
      });

      singleTest('then raw value set', headers.contains(v.key), isTrue);
      singleTest('then call throws', () => headers(v), throwsInvalidHeader);
      singleTest('then tryGet is null', headers.tryGet(v), isNull);
      singleTest('then get throws', () => headers.get(v), throwsInvalidHeader);
    },
    variants: Headers.all,
  );

  parameterizedGroup(
    (v) => 'Given a "${v.key}" header with an invalid raw value',
    (v) {
      late final headers = Headers.fromMap({
        v.key.lower: ['invalid'],
      });

      singleTest('then raw value set', headers.contains(v.key), isTrue);
      singleTest('then call throws', () => headers(v), throwsInvalidHeader);
      singleTest('then tryGet is null', headers.tryGet(v), isNull);
      singleTest('then get throws', () => headers.get(v), throwsInvalidHeader);
    },
    variants: Headers.all.difference({
      // TODO(nielsenko): Go over these exceptions and find out if they are correct. Not all are for sure!
      Headers.acceptEncoding,
      Headers.acceptLanguage,
      Headers.acceptRanges,
      Headers.accessControlAllowHeaders,
      Headers.accessControlAllowOrigin,
      Headers.accessControlExposeHeaders,
      Headers.accessControlRequestHeaders,
      Headers.cacheControl,
      Headers.connection,
      Headers.contentDisposition,
      Headers.contentEncoding,
      Headers.contentLanguage,
      Headers.contentLocation,
      Headers.contentSecurityPolicy,
      Headers.expect,
      Headers.from,
      Headers.host,
      Headers.location,
      Headers.origin,
      Headers.permissionsPolicy,
      Headers.referer,
      Headers.server,
      Headers.setCookie,
      Headers.te,
      Headers.trailer,
      Headers.upgrade,
      Headers.userAgent,
      Headers.vary,
      Headers.via,
      Headers.xForwardedFor,
      Headers.xPoweredBy,
    }),
  );

  parameterizedTest(
    (v) =>
        'Given a "${v.key.key}" header '
        'when using the named extension property on an empty Headers instance '
        'then reading it succeeds and returns null',
    (v) {
      expect(() => v.value(Headers.empty()), returnsNormally);
      expect(v.value(Headers.empty()), isNull);
    },
    variants: <HeaderAccessor, dynamic Function(Headers)>{
      Headers.accept: (h) => h.accept,
      Headers.acceptEncoding: (h) => h.acceptEncoding,
      Headers.acceptLanguage: (h) => h.acceptLanguage,
      Headers.acceptRanges: (h) => h.acceptRanges,
      Headers.accessControlAllowCredentials: (h) =>
          h.accessControlAllowCredentials,
      Headers.accessControlAllowHeaders: (h) => h.accessControlAllowHeaders,
      Headers.accessControlAllowMethods: (h) => h.accessControlAllowMethods,
      Headers.accessControlAllowOrigin: (h) => h.accessControlAllowOrigin,
      Headers.accessControlExposeHeaders: (h) => h.accessControlExposeHeaders,
      Headers.accessControlMaxAge: (h) => h.accessControlMaxAge,
      Headers.accessControlRequestHeaders: (h) => h.accessControlRequestHeaders,
      Headers.accessControlRequestMethod: (h) => h.accessControlRequestMethod,
      Headers.age: (h) => h.age,
      Headers.allow: (h) => h.allow,
      Headers.authorization: (h) => h.authorization,
      Headers.cacheControl: (h) => h.cacheControl,
      Headers.clearSiteData: (h) => h.clearSiteData,
      Headers.connection: (h) => h.connection,
      Headers.contentDisposition: (h) => h.contentDisposition,
      Headers.contentEncoding: (h) => h.contentEncoding,
      Headers.contentLanguage: (h) => h.contentLanguage,
      Headers.contentLength: (h) => h.contentLength,
      Headers.contentLocation: (h) => h.contentLocation,
      Headers.contentRange: (h) => h.contentRange,
      Headers.contentSecurityPolicy: (h) => h.contentSecurityPolicy,
      Headers.cookie: (h) => h.cookie,
      Headers.crossOriginEmbedderPolicy: (h) => h.crossOriginEmbedderPolicy,
      Headers.crossOriginOpenerPolicy: (h) => h.crossOriginOpenerPolicy,
      Headers.crossOriginResourcePolicy: (h) => h.crossOriginResourcePolicy,
      Headers.date: (h) => h.date,
      Headers.etag: (h) => h.etag,
      Headers.expect: (h) => h.expect,
      Headers.expires: (h) => h.expires,
      Headers.from: (h) => h.from,
      Headers.host: (h) => h.host,
      Headers.ifMatch: (h) => h.ifMatch,
      Headers.ifModifiedSince: (h) => h.ifModifiedSince,
      Headers.ifNoneMatch: (h) => h.ifNoneMatch,
      Headers.ifRange: (h) => h.ifRange,
      Headers.ifUnmodifiedSince: (h) => h.ifUnmodifiedSince,
      Headers.lastModified: (h) => h.lastModified,
      Headers.location: (h) => h.location,
      Headers.maxForwards: (h) => h.maxForwards,
      Headers.origin: (h) => h.origin,
      Headers.permissionsPolicy: (h) => h.permissionsPolicy,
      Headers.proxyAuthenticate: (h) => h.proxyAuthenticate,
      Headers.proxyAuthorization: (h) => h.proxyAuthorization,
      Headers.range: (h) => h.range,
      Headers.referer: (h) => h.referer,
      Headers.referrerPolicy: (h) => h.referrerPolicy,
      Headers.retryAfter: (h) => h.retryAfter,
      Headers.secFetchDest: (h) => h.secFetchDest,
      Headers.secFetchMode: (h) => h.secFetchMode,
      Headers.secFetchSite: (h) => h.secFetchSite,
      Headers.server: (h) => h.server,
      Headers.setCookie: (h) => h.setCookie,
      Headers.strictTransportSecurity: (h) => h.strictTransportSecurity,
      Headers.te: (h) => h.te,
      Headers.trailer: (h) => h.trailer,
      Headers.transferEncoding: (h) => h.transferEncoding,
      Headers.upgrade: (h) => h.upgrade,
      Headers.userAgent: (h) => h.userAgent,
      Headers.vary: (h) => h.vary,
      Headers.via: (h) => h.via,
      Headers.wwwAuthenticate: (h) => h.wwwAuthenticate,
      Headers.xPoweredBy: (h) => h.xPoweredBy,
      Headers.forwarded: (h) => h.forwarded,
      Headers.xForwardedFor: (h) => h.xForwardedFor,
    }.entries,
  );

  parameterizedTest(
    (v) =>
        'Given a "${v.key.key}" header '
        'when using the named extension property on an empty MutableHeaders instance '
        'then reading it succeeds and returns null',
    (v) {
      expect(() => Headers.build((mh) => v.value(mh)), returnsNormally);
      Headers.build((mh) => expect(v.value(mh), isNull));
    },
    variants: <HeaderAccessor, dynamic Function(MutableHeaders)>{
      Headers.accept: (h) => h.accept,
      Headers.acceptEncoding: (h) => h.acceptEncoding,
      Headers.acceptLanguage: (h) => h.acceptLanguage,
      Headers.acceptRanges: (h) => h.acceptRanges,
      Headers.accessControlAllowCredentials: (h) =>
          h.accessControlAllowCredentials,
      Headers.accessControlAllowHeaders: (h) => h.accessControlAllowHeaders,
      Headers.accessControlAllowMethods: (h) => h.accessControlAllowMethods,
      Headers.accessControlAllowOrigin: (h) => h.accessControlAllowOrigin,
      Headers.accessControlExposeHeaders: (h) => h.accessControlExposeHeaders,
      Headers.accessControlMaxAge: (h) => h.accessControlMaxAge,
      Headers.accessControlRequestHeaders: (h) => h.accessControlRequestHeaders,
      Headers.accessControlRequestMethod: (h) => h.accessControlRequestMethod,
      Headers.age: (h) => h.age,
      Headers.allow: (h) => h.allow,
      Headers.authorization: (h) => h.authorization,
      Headers.cacheControl: (h) => h.cacheControl,
      Headers.clearSiteData: (h) => h.clearSiteData,
      Headers.connection: (h) => h.connection,
      Headers.contentDisposition: (h) => h.contentDisposition,
      Headers.contentEncoding: (h) => h.contentEncoding,
      Headers.contentLanguage: (h) => h.contentLanguage,
      Headers.contentLength: (h) => h.contentLength,
      Headers.contentLocation: (h) => h.contentLocation,
      Headers.contentRange: (h) => h.contentRange,
      Headers.contentSecurityPolicy: (h) => h.contentSecurityPolicy,
      Headers.cookie: (h) => h.cookie,
      Headers.crossOriginEmbedderPolicy: (h) => h.crossOriginEmbedderPolicy,
      Headers.crossOriginOpenerPolicy: (h) => h.crossOriginOpenerPolicy,
      Headers.crossOriginResourcePolicy: (h) => h.crossOriginResourcePolicy,
      Headers.date: (h) => h.date,
      Headers.etag: (h) => h.etag,
      Headers.expect: (h) => h.expect,
      Headers.expires: (h) => h.expires,
      Headers.from: (h) => h.from,
      Headers.host: (h) => h.host,
      Headers.ifMatch: (h) => h.ifMatch,
      Headers.ifModifiedSince: (h) => h.ifModifiedSince,
      Headers.ifNoneMatch: (h) => h.ifNoneMatch,
      Headers.ifRange: (h) => h.ifRange,
      Headers.ifUnmodifiedSince: (h) => h.ifUnmodifiedSince,
      Headers.lastModified: (h) => h.lastModified,
      Headers.location: (h) => h.location,
      Headers.maxForwards: (h) => h.maxForwards,
      Headers.origin: (h) => h.origin,
      Headers.permissionsPolicy: (h) => h.permissionsPolicy,
      Headers.proxyAuthenticate: (h) => h.proxyAuthenticate,
      Headers.proxyAuthorization: (h) => h.proxyAuthorization,
      Headers.range: (h) => h.range,
      Headers.referer: (h) => h.referer,
      Headers.referrerPolicy: (h) => h.referrerPolicy,
      Headers.retryAfter: (h) => h.retryAfter,
      Headers.secFetchDest: (h) => h.secFetchDest,
      Headers.secFetchMode: (h) => h.secFetchMode,
      Headers.secFetchSite: (h) => h.secFetchSite,
      Headers.server: (h) => h.server,
      Headers.setCookie: (h) => h.setCookie,
      Headers.strictTransportSecurity: (h) => h.strictTransportSecurity,
      Headers.te: (h) => h.te,
      Headers.trailer: (h) => h.trailer,
      Headers.transferEncoding: (h) => h.transferEncoding,
      Headers.upgrade: (h) => h.upgrade,
      Headers.userAgent: (h) => h.userAgent,
      Headers.vary: (h) => h.vary,
      Headers.via: (h) => h.via,
      Headers.wwwAuthenticate: (h) => h.wwwAuthenticate,
      Headers.xPoweredBy: (h) => h.xPoweredBy,
      Headers.forwarded: (h) => h.forwarded,
      Headers.xForwardedFor: (h) => h.xForwardedFor,
    }.entries,
  );

  parameterizedTest(
    (v) =>
        'Given a "${v.key.key}" header '
        'when using the named extension property on an empty MutableHeaders instance '
        'then setting to null succeeds',
    (v) {
      expect(() => Headers.build((mh) => v.value(mh)), returnsNormally);
    },
    variants: <HeaderAccessor, dynamic Function(MutableHeaders)>{
      Headers.accept: (h) => h.accept = null,
      Headers.acceptEncoding: (h) => h.acceptEncoding = null,
      Headers.acceptLanguage: (h) => h.acceptLanguage = null,
      Headers.acceptRanges: (h) => h.acceptRanges = null,
      Headers.accessControlAllowCredentials: (h) =>
          h.accessControlAllowCredentials = null,
      Headers.accessControlAllowHeaders: (h) =>
          h.accessControlAllowHeaders = null,
      Headers.accessControlAllowMethods: (h) =>
          h.accessControlAllowMethods = null,
      Headers.accessControlAllowOrigin: (h) =>
          h.accessControlAllowOrigin = null,
      Headers.accessControlExposeHeaders: (h) =>
          h.accessControlExposeHeaders = null,
      Headers.accessControlMaxAge: (h) => h.accessControlMaxAge = null,
      Headers.accessControlRequestHeaders: (h) =>
          h.accessControlRequestHeaders = null,
      Headers.accessControlRequestMethod: (h) =>
          h.accessControlRequestMethod = null,
      Headers.age: (h) => h.age = null,
      Headers.allow: (h) => h.allow = null,
      Headers.authorization: (h) => h.authorization = null,
      Headers.cacheControl: (h) => h.cacheControl = null,
      Headers.clearSiteData: (h) => h.clearSiteData = null,
      Headers.connection: (h) => h.connection = null,
      Headers.contentDisposition: (h) => h.contentDisposition = null,
      Headers.contentEncoding: (h) => h.contentEncoding = null,
      Headers.contentLanguage: (h) => h.contentLanguage = null,
      Headers.contentLength: (h) => h.contentLength = null,
      Headers.contentLocation: (h) => h.contentLocation = null,
      Headers.contentRange: (h) => h.contentRange = null,
      Headers.contentSecurityPolicy: (h) => h.contentSecurityPolicy = null,
      Headers.cookie: (h) => h.cookie = null,
      Headers.crossOriginEmbedderPolicy: (h) =>
          h.crossOriginEmbedderPolicy = null,
      Headers.crossOriginOpenerPolicy: (h) => h.crossOriginOpenerPolicy = null,
      Headers.crossOriginResourcePolicy: (h) =>
          h.crossOriginResourcePolicy = null,
      Headers.date: (h) => h.date = null,
      Headers.etag: (h) => h.etag = null,
      Headers.expect: (h) => h.expect = null,
      Headers.expires: (h) => h.expires = null,
      Headers.from: (h) => h.from = null,
      Headers.host: (h) => h.host = null,
      Headers.ifMatch: (h) => h.ifMatch = null,
      Headers.ifModifiedSince: (h) => h.ifModifiedSince = null,
      Headers.ifNoneMatch: (h) => h.ifNoneMatch = null,
      Headers.ifRange: (h) => h.ifRange = null,
      Headers.ifUnmodifiedSince: (h) => h.ifUnmodifiedSince = null,
      Headers.lastModified: (h) => h.lastModified = null,
      Headers.location: (h) => h.location = null,
      Headers.maxForwards: (h) => h.maxForwards = null,
      Headers.origin: (h) => h.origin = null,
      Headers.permissionsPolicy: (h) => h.permissionsPolicy = null,
      Headers.proxyAuthenticate: (h) => h.proxyAuthenticate = null,
      Headers.proxyAuthorization: (h) => h.proxyAuthorization = null,
      Headers.range: (h) => h.range = null,
      Headers.referer: (h) => h.referer = null,
      Headers.referrerPolicy: (h) => h.referrerPolicy = null,
      Headers.retryAfter: (h) => h.retryAfter = null,
      Headers.secFetchDest: (h) => h.secFetchDest = null,
      Headers.secFetchMode: (h) => h.secFetchMode = null,
      Headers.secFetchSite: (h) => h.secFetchSite = null,
      Headers.server: (h) => h.server = null,
      Headers.setCookie: (h) => h.setCookie = null,
      Headers.strictTransportSecurity: (h) => h.strictTransportSecurity = null,
      Headers.te: (h) => h.te = null,
      Headers.trailer: (h) => h.trailer = null,
      Headers.transferEncoding: (h) => h.transferEncoding = null,
      Headers.upgrade: (h) => h.upgrade = null,
      Headers.userAgent: (h) => h.userAgent = null,
      Headers.vary: (h) => h.vary = null,
      Headers.via: (h) => h.via = null,
      Headers.wwwAuthenticate: (h) => h.wwwAuthenticate = null,
      Headers.xPoweredBy: (h) => h.xPoweredBy = null,
      Headers.forwarded: (h) => h.forwarded = null,
      Headers.xForwardedFor: (h) => h.xForwardedFor = null,
    }.entries,
  );

  parameterizedGroup(
    (v) => 'Given a "${v.accessor.key}" header ',
    (v) {
      test(
        'when using the named extension property on an empty MutableHeaders instance '
        'then setting to value succeeds',
        () {
          expect(() => Headers.build(v.mutator), returnsNormally);
        },
      );

      test('when round-tripping', () {
        final headers1 = Headers.build(v.mutator);
        final header1 = headers1(v.accessor);

        final raw = v.accessor.codec.encode(header1!);
        final header3 = v.accessor.codec.decode(raw);
        if (header1 is! List && header1 is! Set) {
          // We don't control hashCode for pure List and Set.
          expect(header1, equals(header3));
          expect(header1.hashCode, equals(header3.hashCode));
        }
      });

      test('when comparing', () {
        final headers1 = Headers.build(v.mutator);
        final headers2 = Headers.build(v.mutator);
        expect(identical(headers1, headers2), isFalse);

        final header1 = headers1(v.accessor);
        final header2 = headers2(v.accessor);
        expect(header1, isNotNull);
        expect(header2, isNotNull);

        expect(header1, equals(header1));
        if (header1 is! List && header1 is! Set) {
          // We don't control hashCode for pure List and Set.
          expect(header1, equals(header2));
          expect(
            header1.hashCode,
            equals(header2.hashCode),
            reason: 'hashCode for: $header1',
          );
        }

        final raw = v.accessor.codec.encode(header1!);
        final header3 = v.accessor.codec.decode(raw);
        if (header1 is! List && header1 is! Set) {
          // We don't control hashCode for pure List and Set.
          expect(header1, equals(header3));
          expect(header1.hashCode, equals(header3.hashCode));
        }
        final headers4 = Headers.build((mh) => mh[v.accessor.key] = raw);
        expect(headers4.contains(v.accessor.key), isTrue);
        expect(headers4.tryGet(v.accessor), isNotNull);
        final header4 = headers4(v.accessor);
        if (header1 is! List && header1 is! Set) {
          // We don't control hashCode for pure List and Set.
          expect(header1, equals(header4));
          expect(header1.hashCode, equals(header4.hashCode));
        }
      });
    },
    variants: <(HeaderAccessor, void Function(MutableHeaders))>[
      (
        Headers.accept,
        (h) =>
            h.accept = AcceptHeader.parse(['application/vnd.example.api+json']),
      ),
      (
        Headers.acceptEncoding,
        (h) => h.acceptEncoding = const AcceptEncodingHeader.wildcard(),
      ),
      (
        Headers.acceptEncoding,
        (h) => h.acceptEncoding = AcceptEncodingHeader.encodings([
          EncodingQuality('jpeg', 0.5),
        ]),
      ),
      (
        Headers.acceptLanguage,
        (h) => h.acceptLanguage = const AcceptLanguageHeader.wildcard(),
      ),
      (
        Headers.acceptLanguage,
        (h) => h.acceptLanguage = AcceptLanguageHeader.languages([
          const LanguageQuality('en', 1.0),
        ]),
      ),
      (Headers.acceptRanges, (h) => h.acceptRanges = AcceptRangesHeader.none()),
      (
        Headers.accessControlAllowCredentials,
        (h) => h.accessControlAllowCredentials = true,
      ),
      (
        Headers.accessControlAllowHeaders,
        (h) => h.accessControlAllowHeaders =
            const AccessControlAllowHeadersHeader.wildcard(),
      ),
      (
        Headers.accessControlAllowHeaders,
        (h) => h.accessControlAllowHeaders =
            AccessControlAllowHeadersHeader.headers(['foo']),
      ),
      (
        Headers.accessControlAllowMethods,
        (h) => h.accessControlAllowMethods =
            const AccessControlAllowMethodsHeader.wildcard(),
      ),
      (
        Headers.accessControlAllowMethods,
        (h) => h.accessControlAllowMethods =
            AccessControlAllowMethodsHeader.methods(Method.values),
      ),
      (
        Headers.accessControlAllowOrigin,
        (h) =>
            h.accessControlAllowOrigin = AccessControlAllowOriginHeader.origin(
              origin: Origin.parse('https://example.com'),
            ),
      ),
      (
        Headers.accessControlExposeHeaders,
        (h) => h.accessControlExposeHeaders =
            AccessControlExposeHeadersHeader.headers(['foo']),
      ),
      (Headers.accessControlMaxAge, (h) => h.accessControlMaxAge = 42),
      (
        Headers.accessControlRequestHeaders,
        (h) => h.accessControlRequestHeaders = ['foo'],
      ),
      (
        Headers.accessControlRequestMethod,
        (h) => h.accessControlRequestMethod = Method.get,
      ),
      (Headers.age, (h) => h.age = 42),
      (Headers.allow, (h) => h.allow = {Method.get}),
      (
        Headers.authorization,
        (h) => h.authorization = BearerAuthorizationHeader(token: 'foobar'),
      ),
      (
        Headers.authorization,
        (h) => h.authorization = BasicAuthorizationHeader(
          username: 'foo',
          password: 'bar',
        ),
      ),
      (
        Headers.authorization,
        (h) => h.authorization = DigestAuthorizationHeader(
          username: 'foo',
          realm: 'bar',
          nonce: 'random',
          uri: 'https://example.com',
          response: 'modnar',
        ),
      ),
      (
        Headers.cacheControl,
        (h) => h.cacheControl = CacheControlHeader.parse(['max-age=3600']),
      ),
      (
        Headers.clearSiteData,
        (h) => h.clearSiteData = const ClearSiteDataHeader.wildcard(),
      ),
      (
        Headers.clearSiteData,
        (h) => h.clearSiteData = ClearSiteDataHeader.dataTypes([
          ClearSiteDataType.cache,
        ]),
      ),
      (
        Headers.connection,
        (h) => h.connection = const ConnectionHeader.directives([
          ConnectionHeaderType.keepAlive,
        ]),
      ),
      (
        Headers.contentDisposition,
        (h) => h.contentDisposition = ContentDispositionHeader.parse(
          'attachment; filename="report.pdf"',
        ),
      ),
      (
        Headers.contentDisposition,
        (h) {
          h.contentDisposition = const ContentDispositionHeader(
            type: 'attachment',
            parameters: [
              ContentDispositionParameter(
                name: 'filename',
                value: 'report.pdf',
                isExtended: true,
              ),
            ],
          );
        },
      ),
      (
        Headers.contentEncoding,
        (h) => h.contentEncoding = ContentEncodingHeader.encodings([
          ContentEncoding.gzip,
        ]),
      ),
      (
        Headers.contentLanguage,
        (h) => h.contentLanguage = ContentLanguageHeader.languages(['en']),
      ),
      (Headers.contentLength, (h) => h.contentLength = 1202),
      (
        Headers.contentLocation,
        (h) => h.contentLocation = Uri.parse('https://example.com'),
      ),
      (
        Headers.contentRange,
        (h) => h.contentRange = ContentRangeHeader(size: 1234),
      ),
      (
        Headers.contentSecurityPolicy,
        (h) => h.contentSecurityPolicy = ContentSecurityPolicyHeader.directives(
          [ContentSecurityPolicyDirective(name: 'foo', values: [])],
        ),
      ),
      (
        Headers.cookie,
        (h) => h.cookie = CookieHeader.cookies([
          Cookie(name: 'foo', value: 'bar'),
        ]),
      ),
      (
        Headers.crossOriginEmbedderPolicy,
        (h) => h.crossOriginEmbedderPolicy =
            CrossOriginEmbedderPolicyHeader.unsafeNone,
      ),
      (
        Headers.crossOriginOpenerPolicy,
        (h) => h.crossOriginOpenerPolicy =
            CrossOriginOpenerPolicyHeader.unsafeNone,
      ),
      (
        Headers.crossOriginResourcePolicy,
        (h) => h.crossOriginResourcePolicy =
            CrossOriginResourcePolicyHeader.sameSite,
      ),
      (Headers.date, (h) => h.date = DateTime.utc(2025, 9, 23)),
      (Headers.etag, (h) => h.etag = const ETagHeader(value: '')),
      (Headers.expect, (h) => h.expect = ExpectHeader.continue100),
      (Headers.expires, (h) => h.expires = DateTime.utc(2025, 9, 23)),
      (Headers.from, (h) => h.from = const FromHeader('info@serverpod.com')),
      (Headers.host, (h) => h.host = HostHeader('www.example.com', 80)),
      (Headers.ifMatch, (h) => h.ifMatch = const IfMatchHeader.wildcard()),
      (
        Headers.ifMatch,
        (h) => h.ifMatch = IfMatchHeader.etags([
          const ETagHeader(value: 'foobar'),
        ]),
      ),
      (
        Headers.ifModifiedSince,
        (h) => h.ifModifiedSince = DateTime.utc(2025, 9, 23),
      ),
      (
        Headers.ifNoneMatch,
        (h) => h.ifNoneMatch = const IfNoneMatchHeader.wildcard(),
      ),
      (
        Headers.ifRange,
        (h) =>
            h.ifRange = IfRangeHeader(lastModified: DateTime.utc(2025, 9, 23)),
      ),
      (
        Headers.ifUnmodifiedSince,
        (h) => h.ifUnmodifiedSince = DateTime.utc(2025, 9, 23),
      ),
      (Headers.lastModified, (h) => h.lastModified = DateTime.utc(2025, 9, 23)),
      (Headers.location, (h) => h.location = Uri.parse('https://example.com')),
      (Headers.maxForwards, (h) => h.maxForwards = 42),
      (Headers.origin, (h) => h.origin = Uri.parse('https://example.com')),
      (
        Headers.permissionsPolicy,
        (h) => h.permissionsPolicy = PermissionsPolicyHeader.directives([
          const PermissionsPolicyDirective(name: 'foo', values: []),
        ]),
      ),
      (
        Headers.proxyAuthenticate,
        (h) => h.proxyAuthenticate = AuthenticationHeader(
          scheme: 'Bearer',
          parameters: [const AuthenticationParameter('foo', 'bar')],
        ),
      ),
      (
        Headers.proxyAuthorization,
        (h) =>
            h.proxyAuthorization = BearerAuthorizationHeader(token: 'foobar'),
      ),
      (Headers.range, (h) => h.range = RangeHeader(ranges: [Range(start: 1)])),
      (Headers.referer, (h) => h.referer = Uri.parse('https://example.com')),
      (
        Headers.referrerPolicy,
        (h) => h.referrerPolicy = ReferrerPolicyHeader.origin,
      ),
      (Headers.retryAfter, (h) => h.retryAfter = RetryAfterHeader(delay: 1)),
      (Headers.secFetchDest, (h) => h.secFetchDest = SecFetchDestHeader.audio),
      (Headers.secFetchMode, (h) => h.secFetchMode = SecFetchModeHeader.cors),
      (
        Headers.secFetchSite,
        (h) => h.secFetchSite = SecFetchSiteHeader.crossSite,
      ),
      (Headers.server, (h) => h.server = 'localhost'),
      (
        Headers.setCookie,
        (h) => h.setCookie = SetCookieHeader([
          SetCookie(name: 'foo', value: 'bar'),
        ]),
      ),
      (
        Headers.strictTransportSecurity,
        (h) => h.strictTransportSecurity = StrictTransportSecurityHeader(
          maxAge: 42,
        ),
      ),
      (Headers.te, (h) => h.te = TEHeader.encodings([TeQuality('foo')])),
      (Headers.trailer, (h) => h.trailer = ['foo']),
      (
        Headers.transferEncoding,
        (h) => h.transferEncoding = TransferEncodingHeader.encodings([
          TransferEncoding.gzip,
        ]),
      ),
      (
        Headers.upgrade,
        (h) => h.upgrade = UpgradeHeader.protocols([
          UpgradeProtocol(protocol: 'foo'),
        ]),
      ),
      (Headers.userAgent, (h) => h.userAgent = 'null'),
      (Headers.vary, (h) => h.vary = VaryHeader.wildcard()),
      (Headers.via, (h) => h.via = ['foo']),
      (
        Headers.wwwAuthenticate,
        (h) => h.wwwAuthenticate = AuthenticationHeader(
          scheme: 'Bearer',
          parameters: [const AuthenticationParameter('foo', 'bar')],
        ),
      ),
      (Headers.xPoweredBy, (h) => h.xPoweredBy = 'null'),
      (
        Headers.forwarded,
        (h) => h.forwarded = ForwardedHeader([
          ForwardedElement(
            forwardedFor: const ForwardedIdentifier('192.1.0.1'),
          ),
        ]),
      ),
      (
        Headers.xForwardedFor,
        (h) => h.xForwardedFor = XForwardedForHeader(['192.1.0.1']),
      ),
    ].map((r) => (accessor: r.$1, mutator: r.$2)),
  );
}
