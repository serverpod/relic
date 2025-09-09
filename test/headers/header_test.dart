import 'package:relic/relic.dart';
import 'package:test/test.dart';

import '../util/test_util.dart';
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
        'X-Custom-Header': ['value']
      });
      expect(headers['x-custom-header'], equals(['value']));
    });

    test('when custom headers are removed then they are no longer present', () {
      var headers = Headers.fromMap({
        'X-Custom-Header': ['value']
      });
      headers = headers.transform((final mh) => mh.remove('X-Custom-Header'));
      expect(headers['x-custom-header'], isNull);
    });

    test('when accessing headers then they are case insensitive', () {
      final headers = Headers.fromMap({
        'Case-Insensitive': ['value']
      });
      expect(headers['case-insensitive'], contains('value'));
      expect(headers['CASE-INSENSITIVE'], contains('value'));
    });

    test('when headers are copied then modifications are correctly applied',
        () {
      final headers = Headers.fromMap({
        'Initial-Header': ['initial']
      });
      final copiedHeaders = headers.transform((final mh) {
        mh.remove('Initial-Header');
        mh['Copied-Header'] = ['copied'];
      });
      expect(copiedHeaders['initial-header'], isNull);
      expect(copiedHeaders['copied-header'], equals(['copied']));
    });

    test('when headers are applied to a Response then they are set correctly',
        () {
      final headers = Headers.build((final mh) {
        mh['Response-Header'] = ['response-value'];
      });
      final response = Response.ok(headers: headers);

      expect(response.headers['Response-Header'], equals(['response-value']));
    });

    test('when handling large headers then they are processed correctly', () {
      final largeValue = List.filled(10000, 'a').join();
      final headers = Headers.build((final mh) {
        mh['Large-Header'] = [largeValue];
      });
      expect(headers['large-header']?.first.length, equals(10000));
    });

    test('when a managed header is removed then it is no longer present', () {
      var headers =
          Headers.build((final mh) => mh.date = DateTime.utc(2025, 9, 23));
      headers = headers.transform((final mh) => mh.date = null);
      expect(headers.date, isNull);
    });

    test('when a managed header is updated then it is correctly replaced', () {
      var headers =
          Headers.build((final mh) => mh.date = DateTime.utc(2025, 9, 23));
      final newDate = DateTime.utc(2025, 9, 23)
          .add(const Duration(days: 1))
          .toUtc()
          .copyWith(microsecond: 0, millisecond: 0);
      headers = headers.transform((final mh) => mh.date = newDate);
      expect(headers.date, equals(newDate));
    });
  });

  parameterizedGroup(
    (final v) => 'Given a "${v.key}" header when calling Headers.build',
    (final v) {
      Headers.build((final mh) {
        final header = v[mh];
        singleTest('then raw value not set', mh, isNot(contains(v.key)));
        singleTest('then not isSet', header.isSet, isFalse);
        singleTest('then set fails if type of value wrong',
            () => header.set(Object()), throwsA(isA<TypeError>()));
        singleTest('then set to null succeeds', () => header.set(null),
            returnsNormally);
        singleTest('then set succeeds if value is correct type',
            () => header.set(header.valueOrNull), returnsNormally);
      });
    },
    variants: Headers.all,
  );

  parameterizedGroup(
    (final v) => 'Given a "${v.key}" header with no raw value',
    (final v) {
      late final headers = Headers.empty();
      late final header = v[headers];

      singleTest('then raw value not set', headers, isNot(contains(v.key)));
      singleTest('then isSet is false', header.isSet, isFalse);
      singleTest('then isValid is false', header.isValid, isFalse);
      singleTest('then valueOrNull is null', header.valueOrNull, isNull);
      singleTest('then valueOrNullIfInvalid is null',
          header.valueOrNullIfInvalid, isNull);
      singleTest('then value throws', () => header.value, throwsMissingHeader);
    },
    variants: Headers.all,
  );

  parameterizedGroup(
    (final v) => 'Given a "${v.key}" header with an empty raw value',
    (final v) {
      late final headers = Headers.fromMap({
        v.key: ['']
      });
      late final header = v[headers];

      singleTest('then raw value set', headers, contains(v.key));
      singleTest('then isSet is true', header.isSet, isTrue);
      singleTest('then isValid is false', header.isValid, isFalse);
      singleTest('then valueOrNull throws', () => header.valueOrNull,
          throwsInvalidHeader);
      singleTest('then valueOrNullIfInvalid is null',
          header.valueOrNullIfInvalid, isNull);
      singleTest('then value throws', () => header.value, throwsInvalidHeader);
    },
    variants: Headers.all,
  );

  parameterizedGroup(
    (final v) => 'Given a "${v.key}" header with an invalid raw value',
    (final v) {
      late final header = v[Headers.fromMap({
        v.key: ['invalid']
      })];

      singleTest('then isSet is true', header.isSet, isTrue);
      singleTest('then isValid is false', header.isValid, isFalse);
      singleTest('then valueOrNull throws', () => header.valueOrNull,
          throwsInvalidHeader);
      singleTest('then value throws', () => header.value, throwsInvalidHeader);
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
      Headers.contentDisposition,
      Headers.contentLanguage,
      Headers.contentLocation,
      Headers.contentSecurityPolicy,
      Headers.host,
      Headers.location,
      Headers.origin,
      Headers.permissionsPolicy,
      Headers.referer,
      Headers.server,
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
    (final v) => 'Given a "${v.key.key}" header '
        'when using the named extension property on an empty Headers instance '
        'then reading it succeeds and returns null',
    (final v) {
      expect(() => v.value(Headers.empty()), returnsNormally);
      expect(v.value(Headers.empty()), isNull);
    },
    variants: <HeaderAccessor, dynamic Function(Headers)>{
      Headers.accept: (final h) => h.accept,
      Headers.acceptEncoding: (final h) => h.acceptEncoding,
      Headers.acceptLanguage: (final h) => h.acceptLanguage,
      Headers.acceptRanges: (final h) => h.acceptRanges,
      Headers.accessControlAllowCredentials: (final h) =>
          h.accessControlAllowCredentials,
      Headers.accessControlAllowHeaders: (final h) =>
          h.accessControlAllowHeaders,
      Headers.accessControlAllowMethods: (final h) =>
          h.accessControlAllowMethods,
      Headers.accessControlAllowOrigin: (final h) => h.accessControlAllowOrigin,
      Headers.accessControlExposeHeaders: (final h) =>
          h.accessControlExposeHeaders,
      Headers.accessControlMaxAge: (final h) => h.accessControlMaxAge,
      Headers.accessControlRequestHeaders: (final h) =>
          h.accessControlRequestHeaders,
      Headers.accessControlRequestMethod: (final h) =>
          h.accessControlRequestMethod,
      Headers.age: (final h) => h.age,
      Headers.allow: (final h) => h.allow,
      Headers.authorization: (final h) => h.authorization,
      Headers.cacheControl: (final h) => h.cacheControl,
      Headers.clearSiteData: (final h) => h.clearSiteData,
      Headers.connection: (final h) => h.connection,
      Headers.contentDisposition: (final h) => h.contentDisposition,
      Headers.contentEncoding: (final h) => h.contentEncoding,
      Headers.contentLanguage: (final h) => h.contentLanguage,
      Headers.contentLength: (final h) => h.contentLength,
      Headers.contentLocation: (final h) => h.contentLocation,
      Headers.contentRange: (final h) => h.contentRange,
      Headers.contentSecurityPolicy: (final h) => h.contentSecurityPolicy,
      Headers.cookie: (final h) => h.cookie,
      Headers.crossOriginEmbedderPolicy: (final h) =>
          h.crossOriginEmbedderPolicy,
      Headers.crossOriginOpenerPolicy: (final h) => h.crossOriginOpenerPolicy,
      Headers.crossOriginResourcePolicy: (final h) =>
          h.crossOriginResourcePolicy,
      Headers.date: (final h) => h.date,
      Headers.etag: (final h) => h.etag,
      Headers.expect: (final h) => h.expect,
      Headers.expires: (final h) => h.expires,
      Headers.from: (final h) => h.from,
      Headers.host: (final h) => h.host,
      Headers.ifMatch: (final h) => h.ifMatch,
      Headers.ifModifiedSince: (final h) => h.ifModifiedSince,
      Headers.ifNoneMatch: (final h) => h.ifNoneMatch,
      Headers.ifRange: (final h) => h.ifRange,
      Headers.ifUnmodifiedSince: (final h) => h.ifUnmodifiedSince,
      Headers.lastModified: (final h) => h.lastModified,
      Headers.location: (final h) => h.location,
      Headers.maxForwards: (final h) => h.maxForwards,
      Headers.origin: (final h) => h.origin,
      Headers.permissionsPolicy: (final h) => h.permissionsPolicy,
      Headers.proxyAuthenticate: (final h) => h.proxyAuthenticate,
      Headers.proxyAuthorization: (final h) => h.proxyAuthorization,
      Headers.range: (final h) => h.range,
      Headers.referer: (final h) => h.referer,
      Headers.referrerPolicy: (final h) => h.referrerPolicy,
      Headers.retryAfter: (final h) => h.retryAfter,
      Headers.secFetchDest: (final h) => h.secFetchDest,
      Headers.secFetchMode: (final h) => h.secFetchMode,
      Headers.secFetchSite: (final h) => h.secFetchSite,
      Headers.server: (final h) => h.server,
      Headers.setCookie: (final h) => h.setCookie,
      Headers.strictTransportSecurity: (final h) => h.strictTransportSecurity,
      Headers.te: (final h) => h.te,
      Headers.trailer: (final h) => h.trailer,
      Headers.transferEncoding: (final h) => h.transferEncoding,
      Headers.upgrade: (final h) => h.upgrade,
      Headers.userAgent: (final h) => h.userAgent,
      Headers.vary: (final h) => h.vary,
      Headers.via: (final h) => h.via,
      Headers.wwwAuthenticate: (final h) => h.wwwAuthenticate,
      Headers.xPoweredBy: (final h) => h.xPoweredBy,
      Headers.forwarded: (final h) => h.forwarded,
      Headers.xForwardedFor: (final h) => h.xForwardedFor,
    }.entries,
  );

  parameterizedTest(
    (final v) => 'Given a "${v.key.key}" header '
        'when using the named extension property on an empty MutableHeaders instance '
        'then reading it succeeds and returns null',
    (final v) {
      expect(() => Headers.build((final mh) => v.value(mh)), returnsNormally);
      Headers.build((final mh) => expect(v.value(mh), isNull));
    },
    variants: <HeaderAccessor, dynamic Function(MutableHeaders)>{
      Headers.accept: (final h) => h.accept,
      Headers.acceptEncoding: (final h) => h.acceptEncoding,
      Headers.acceptLanguage: (final h) => h.acceptLanguage,
      Headers.acceptRanges: (final h) => h.acceptRanges,
      Headers.accessControlAllowCredentials: (final h) =>
          h.accessControlAllowCredentials,
      Headers.accessControlAllowHeaders: (final h) =>
          h.accessControlAllowHeaders,
      Headers.accessControlAllowMethods: (final h) =>
          h.accessControlAllowMethods,
      Headers.accessControlAllowOrigin: (final h) => h.accessControlAllowOrigin,
      Headers.accessControlExposeHeaders: (final h) =>
          h.accessControlExposeHeaders,
      Headers.accessControlMaxAge: (final h) => h.accessControlMaxAge,
      Headers.accessControlRequestHeaders: (final h) =>
          h.accessControlRequestHeaders,
      Headers.accessControlRequestMethod: (final h) =>
          h.accessControlRequestMethod,
      Headers.age: (final h) => h.age,
      Headers.allow: (final h) => h.allow,
      Headers.authorization: (final h) => h.authorization,
      Headers.cacheControl: (final h) => h.cacheControl,
      Headers.clearSiteData: (final h) => h.clearSiteData,
      Headers.connection: (final h) => h.connection,
      Headers.contentDisposition: (final h) => h.contentDisposition,
      Headers.contentEncoding: (final h) => h.contentEncoding,
      Headers.contentLanguage: (final h) => h.contentLanguage,
      Headers.contentLength: (final h) => h.contentLength,
      Headers.contentLocation: (final h) => h.contentLocation,
      Headers.contentRange: (final h) => h.contentRange,
      Headers.contentSecurityPolicy: (final h) => h.contentSecurityPolicy,
      Headers.cookie: (final h) => h.cookie,
      Headers.crossOriginEmbedderPolicy: (final h) =>
          h.crossOriginEmbedderPolicy,
      Headers.crossOriginOpenerPolicy: (final h) => h.crossOriginOpenerPolicy,
      Headers.crossOriginResourcePolicy: (final h) =>
          h.crossOriginResourcePolicy,
      Headers.date: (final h) => h.date,
      Headers.etag: (final h) => h.etag,
      Headers.expect: (final h) => h.expect,
      Headers.expires: (final h) => h.expires,
      Headers.from: (final h) => h.from,
      Headers.host: (final h) => h.host,
      Headers.ifMatch: (final h) => h.ifMatch,
      Headers.ifModifiedSince: (final h) => h.ifModifiedSince,
      Headers.ifNoneMatch: (final h) => h.ifNoneMatch,
      Headers.ifRange: (final h) => h.ifRange,
      Headers.ifUnmodifiedSince: (final h) => h.ifUnmodifiedSince,
      Headers.lastModified: (final h) => h.lastModified,
      Headers.location: (final h) => h.location,
      Headers.maxForwards: (final h) => h.maxForwards,
      Headers.origin: (final h) => h.origin,
      Headers.permissionsPolicy: (final h) => h.permissionsPolicy,
      Headers.proxyAuthenticate: (final h) => h.proxyAuthenticate,
      Headers.proxyAuthorization: (final h) => h.proxyAuthorization,
      Headers.range: (final h) => h.range,
      Headers.referer: (final h) => h.referer,
      Headers.referrerPolicy: (final h) => h.referrerPolicy,
      Headers.retryAfter: (final h) => h.retryAfter,
      Headers.secFetchDest: (final h) => h.secFetchDest,
      Headers.secFetchMode: (final h) => h.secFetchMode,
      Headers.secFetchSite: (final h) => h.secFetchSite,
      Headers.server: (final h) => h.server,
      Headers.setCookie: (final h) => h.setCookie,
      Headers.strictTransportSecurity: (final h) => h.strictTransportSecurity,
      Headers.te: (final h) => h.te,
      Headers.trailer: (final h) => h.trailer,
      Headers.transferEncoding: (final h) => h.transferEncoding,
      Headers.upgrade: (final h) => h.upgrade,
      Headers.userAgent: (final h) => h.userAgent,
      Headers.vary: (final h) => h.vary,
      Headers.via: (final h) => h.via,
      Headers.wwwAuthenticate: (final h) => h.wwwAuthenticate,
      Headers.xPoweredBy: (final h) => h.xPoweredBy,
      Headers.forwarded: (final h) => h.forwarded,
      Headers.xForwardedFor: (final h) => h.xForwardedFor,
    }.entries,
  );

  parameterizedTest(
    (final v) => 'Given a "${v.key.key}" header '
        'when using the named extension property on an empty MutableHeaders instance '
        'then setting to null succeeds',
    (final v) {
      expect(() => Headers.build((final mh) => v.value(mh)), returnsNormally);
    },
    variants: <HeaderAccessor, dynamic Function(MutableHeaders)>{
      Headers.accept: (final h) => h.accept = null,
      Headers.acceptEncoding: (final h) => h.acceptEncoding = null,
      Headers.acceptLanguage: (final h) => h.acceptLanguage = null,
      Headers.acceptRanges: (final h) => h.acceptRanges = null,
      Headers.accessControlAllowCredentials: (final h) =>
          h.accessControlAllowCredentials = null,
      Headers.accessControlAllowHeaders: (final h) =>
          h.accessControlAllowHeaders = null,
      Headers.accessControlAllowMethods: (final h) =>
          h.accessControlAllowMethods = null,
      Headers.accessControlAllowOrigin: (final h) =>
          h.accessControlAllowOrigin = null,
      Headers.accessControlExposeHeaders: (final h) =>
          h.accessControlExposeHeaders = null,
      Headers.accessControlMaxAge: (final h) => h.accessControlMaxAge = null,
      Headers.accessControlRequestHeaders: (final h) =>
          h.accessControlRequestHeaders = null,
      Headers.accessControlRequestMethod: (final h) =>
          h.accessControlRequestMethod = null,
      Headers.age: (final h) => h.age = null,
      Headers.allow: (final h) => h.allow = null,
      Headers.authorization: (final h) => h.authorization = null,
      Headers.cacheControl: (final h) => h.cacheControl = null,
      Headers.clearSiteData: (final h) => h.clearSiteData = null,
      Headers.connection: (final h) => h.connection = null,
      Headers.contentDisposition: (final h) => h.contentDisposition = null,
      Headers.contentEncoding: (final h) => h.contentEncoding = null,
      Headers.contentLanguage: (final h) => h.contentLanguage = null,
      Headers.contentLength: (final h) => h.contentLength = null,
      Headers.contentLocation: (final h) => h.contentLocation = null,
      Headers.contentRange: (final h) => h.contentRange = null,
      Headers.contentSecurityPolicy: (final h) =>
          h.contentSecurityPolicy = null,
      Headers.cookie: (final h) => h.cookie = null,
      Headers.crossOriginEmbedderPolicy: (final h) =>
          h.crossOriginEmbedderPolicy = null,
      Headers.crossOriginOpenerPolicy: (final h) =>
          h.crossOriginOpenerPolicy = null,
      Headers.crossOriginResourcePolicy: (final h) =>
          h.crossOriginResourcePolicy = null,
      Headers.date: (final h) => h.date = null,
      Headers.etag: (final h) => h.etag = null,
      Headers.expect: (final h) => h.expect = null,
      Headers.expires: (final h) => h.expires = null,
      Headers.from: (final h) => h.from = null,
      Headers.host: (final h) => h.host = null,
      Headers.ifMatch: (final h) => h.ifMatch = null,
      Headers.ifModifiedSince: (final h) => h.ifModifiedSince = null,
      Headers.ifNoneMatch: (final h) => h.ifNoneMatch = null,
      Headers.ifRange: (final h) => h.ifRange = null,
      Headers.ifUnmodifiedSince: (final h) => h.ifUnmodifiedSince = null,
      Headers.lastModified: (final h) => h.lastModified = null,
      Headers.location: (final h) => h.location = null,
      Headers.maxForwards: (final h) => h.maxForwards = null,
      Headers.origin: (final h) => h.origin = null,
      Headers.permissionsPolicy: (final h) => h.permissionsPolicy = null,
      Headers.proxyAuthenticate: (final h) => h.proxyAuthenticate = null,
      Headers.proxyAuthorization: (final h) => h.proxyAuthorization = null,
      Headers.range: (final h) => h.range = null,
      Headers.referer: (final h) => h.referer = null,
      Headers.referrerPolicy: (final h) => h.referrerPolicy = null,
      Headers.retryAfter: (final h) => h.retryAfter = null,
      Headers.secFetchDest: (final h) => h.secFetchDest = null,
      Headers.secFetchMode: (final h) => h.secFetchMode = null,
      Headers.secFetchSite: (final h) => h.secFetchSite = null,
      Headers.server: (final h) => h.server = null,
      Headers.setCookie: (final h) => h.setCookie = null,
      Headers.strictTransportSecurity: (final h) =>
          h.strictTransportSecurity = null,
      Headers.te: (final h) => h.te = null,
      Headers.trailer: (final h) => h.trailer = null,
      Headers.transferEncoding: (final h) => h.transferEncoding = null,
      Headers.upgrade: (final h) => h.upgrade = null,
      Headers.userAgent: (final h) => h.userAgent = null,
      Headers.vary: (final h) => h.vary = null,
      Headers.via: (final h) => h.via = null,
      Headers.wwwAuthenticate: (final h) => h.wwwAuthenticate = null,
      Headers.xPoweredBy: (final h) => h.xPoweredBy = null,
      Headers.forwarded: (final h) => h.forwarded = null,
      Headers.xForwardedFor: (final h) => h.xForwardedFor = null,
    }.entries,
  );

  parameterizedGroup(
    (final v) => 'Given a "${v.accessor.key}" header ',
    (final v) {
      test(
          'when using the named extension property on an empty MutableHeaders instance '
          'then setting to value succeeds', () {
        expect(() => Headers.build(v.mutator), returnsNormally);
      });

      test('when round-tripping', () {
        final headers1 = Headers.build(v.mutator);
        final header1 = v.accessor.getValueFrom(headers1);

        final raw = v.accessor.codec.encode(header1!);
        final header3 = v.accessor.codec.decode(raw);
        if (header1 is! List) {
          expect(header1, equals(header3));
          expect(header1.hashCode, equals(header3.hashCode));
        }
      });

      test('when comparing', () {
        final headers1 = Headers.build(v.mutator);
        final headers2 = Headers.build(v.mutator);
        expect(identical(headers1, headers2), isFalse);

        final header1 = v.accessor.getValueFrom(headers1);
        final header2 = v.accessor.getValueFrom(headers2);
        expect(header1, isNotNull);
        expect(header2, isNotNull);

        expect(header1, equals(header1));
        if (header1 is! List) {
          expect(header1, equals(header2));
          expect(header1.hashCode, equals(header2.hashCode),
              reason: 'hashCode for: $header1');
        }

        final raw = v.accessor.codec.encode(header1!);
        final header3 = v.accessor.codec.decode(raw);
        if (header1 is! List) {
          expect(header1, equals(header3));
          expect(header1.hashCode, equals(header3.hashCode));
        }
        final headers4 = Headers.build((final mh) => mh[v.accessor.key] = raw);
        expect(v.accessor.isSetIn(headers4), isTrue);
        expect(v.accessor.isValidIn(headers4), isTrue);
        final header4 = v.accessor.getValueFrom(headers4);
        if (header1 is! List) {
          expect(header1, equals(header4));
          expect(header1.hashCode, equals(header4.hashCode));
        }
      });
    },
    variants: <(HeaderAccessor, void Function(MutableHeaders))>[
      (
        Headers.accept,
        (final h) =>
            h.accept = AcceptHeader.parse(['application/vnd.example.api+json'])
      ),
      (
        Headers.acceptEncoding,
        (final h) => h.acceptEncoding = const AcceptEncodingHeader.wildcard()
      ),
      (
        Headers.acceptEncoding,
        (final h) => h.acceptEncoding = AcceptEncodingHeader.encodings(
            encodings: [EncodingQuality('jpeg', 0.5)])
      ),
      (
        Headers.acceptLanguage,
        (final h) => h.acceptLanguage = const AcceptLanguageHeader.wildcard()
      ),
      (
        Headers.acceptLanguage,
        (final h) => h.acceptLanguage = AcceptLanguageHeader.languages(
            languages: [const LanguageQuality('en', 1.0)])
      ),
      (
        Headers.acceptRanges,
        (final h) => h.acceptRanges = AcceptRangesHeader.none()
      ),
      (
        Headers.accessControlAllowCredentials,
        (final h) => h.accessControlAllowCredentials = true
      ),
      (
        Headers.accessControlAllowHeaders,
        (final h) => h.accessControlAllowHeaders =
            const AccessControlAllowHeadersHeader.wildcard()
      ),
      (
        Headers.accessControlAllowHeaders,
        (final h) => h.accessControlAllowHeaders =
            AccessControlAllowHeadersHeader.headers(headers: ['foo'])
      ),
      (
        Headers.accessControlAllowMethods,
        (final h) => h.accessControlAllowMethods =
            const AccessControlAllowMethodsHeader.wildcard()
      ),
      (
        Headers.accessControlAllowMethods,
        (final h) => h.accessControlAllowMethods =
            AccessControlAllowMethodsHeader.methods(
                methods: RequestMethod.values)
      ),
      (
        Headers.accessControlAllowOrigin,
        (final h) => h.accessControlAllowOrigin =
            AccessControlAllowOriginHeader.origin(
                origin: Uri.parse('https://example.com'))
      ),
      (
        Headers.accessControlExposeHeaders,
        (final h) => h.accessControlExposeHeaders =
            AccessControlExposeHeadersHeader.headers(headers: ['foo'])
      ),
      (Headers.accessControlMaxAge, (final h) => h.accessControlMaxAge = 42),
      (
        Headers.accessControlRequestHeaders,
        (final h) => h.accessControlRequestHeaders = ['foo']
      ),
      (
        Headers.accessControlRequestMethod,
        (final h) => h.accessControlRequestMethod = RequestMethod.get
      ),
      (Headers.age, (final h) => h.age = 42),
      (Headers.allow, (final h) => h.allow = [RequestMethod.get]),
      (
        Headers.authorization,
        (final h) =>
            h.authorization = BearerAuthorizationHeader(token: 'foobar')
      ),
      (
        Headers.authorization,
        (final h) => h.authorization =
            BasicAuthorizationHeader(username: 'foo', password: 'bar')
      ),
      (
        Headers.authorization,
        (final h) => h.authorization = DigestAuthorizationHeader(
            username: 'foo',
            realm: 'bar',
            nonce: 'random',
            uri: 'https://example.com',
            response: 'modnar')
      ),
      (
        Headers.cacheControl,
        (final h) => h.cacheControl = CacheControlHeader.parse(['max-age=3600'])
      ),
      (
        Headers.clearSiteData,
        (final h) => h.clearSiteData = const ClearSiteDataHeader.wildcard()
      ),
      (
        Headers.clearSiteData,
        (final h) => h.clearSiteData =
            ClearSiteDataHeader.dataTypes(dataTypes: [ClearSiteDataType.cache])
      ),
      (
        Headers.connection,
        (final h) => h.connection =
            const ConnectionHeader(directives: [ConnectionHeaderType.keepAlive])
      ),
      (
        Headers.contentDisposition,
        (final h) => h.contentDisposition =
            ContentDispositionHeader.parse('attachment; filename="report.pdf"')
      ),
      (
        Headers.contentDisposition,
        (final h) {
          h.contentDisposition = const ContentDispositionHeader(
            type: 'attachment',
            parameters: [
              ContentDispositionParameter(
                  name: 'filename', value: 'report.pdf', isExtended: true)
            ],
          );
        }
      ),
      (
        Headers.contentEncoding,
        (final h) => h.contentEncoding =
            ContentEncodingHeader(encodings: [ContentEncoding.gzip])
      ),
      (
        Headers.contentLanguage,
        (final h) =>
            h.contentLanguage = ContentLanguageHeader(languages: ['en'])
      ),
      (Headers.contentLength, (final h) => h.contentLength = 1202),
      (
        Headers.contentLocation,
        (final h) => h.contentLocation = Uri.parse('https://example.com')
      ),
      (
        Headers.contentRange,
        (final h) => h.contentRange = ContentRangeHeader()
      ),
      (
        Headers.contentSecurityPolicy,
        (final h) => h.contentSecurityPolicy = ContentSecurityPolicyHeader(
                directives: [
                  ContentSecurityPolicyDirective(name: 'foo', values: [])
                ])
      ),
      (
        Headers.cookie,
        (final h) => h.cookie =
            CookieHeader(cookies: [Cookie(name: 'foo', value: 'bar')])
      ),
      (
        Headers.crossOriginEmbedderPolicy,
        (final h) => h.crossOriginEmbedderPolicy =
            CrossOriginEmbedderPolicyHeader.unsafeNone
      ),
      (
        Headers.crossOriginOpenerPolicy,
        (final h) =>
            h.crossOriginOpenerPolicy = CrossOriginOpenerPolicyHeader.unsafeNone
      ),
      (
        Headers.crossOriginResourcePolicy,
        (final h) => h.crossOriginResourcePolicy =
            CrossOriginResourcePolicyHeader.sameSite
      ),
      (Headers.date, (final h) => h.date = DateTime.utc(2025, 9, 23)),
      (Headers.etag, (final h) => h.etag = const ETagHeader(value: '')),
      (Headers.expect, (final h) => h.expect = ExpectHeader.continue100),
      (Headers.expires, (final h) => h.expires = DateTime.utc(2025, 9, 23)),
      (
        Headers.from,
        (final h) => h.from = FromHeader(emails: ['info@serverpod.com'])
      ),
      (Headers.host, (final h) => h.host = HostHeader('www.example.com', 80)),
      (
        Headers.ifMatch,
        (final h) => h.ifMatch = const IfMatchHeader.wildcard()
      ),
      (
        Headers.ifMatch,
        (final h) =>
            h.ifMatch = IfMatchHeader.etags([const ETagHeader(value: 'foobar')])
      ),
      (
        Headers.ifModifiedSince,
        (final h) => h.ifModifiedSince = DateTime.utc(2025, 9, 23)
      ),
      (
        Headers.ifNoneMatch,
        (final h) => h.ifNoneMatch = const IfNoneMatchHeader.wildcard()
      ),
      (
        Headers.ifRange,
        (final h) =>
            h.ifRange = IfRangeHeader(lastModified: DateTime.utc(2025, 9, 23))
      ),
      (
        Headers.ifUnmodifiedSince,
        (final h) => h.ifUnmodifiedSince = DateTime.utc(2025, 9, 23)
      ),
      (
        Headers.lastModified,
        (final h) => h.lastModified = DateTime.utc(2025, 9, 23)
      ),
      (
        Headers.location,
        (final h) => h.location = Uri.parse('https://example.com')
      ),
      (Headers.maxForwards, (final h) => h.maxForwards = 42),
      (
        Headers.origin,
        (final h) => h.origin = Uri.parse('https://example.com')
      ),
      (
        Headers.permissionsPolicy,
        (final h) => h.permissionsPolicy = PermissionsPolicyHeader(directives: [
              const PermissionsPolicyDirective(name: 'foo', values: [])
            ])
      ),
      (
        Headers.proxyAuthenticate,
        (final h) => h.proxyAuthenticate = AuthenticationHeader(
            scheme: 'Bearer',
            parameters: [const AuthenticationParameter('foo', 'bar')])
      ),
      (
        Headers.proxyAuthorization,
        (final h) =>
            h.proxyAuthorization = BearerAuthorizationHeader(token: 'foobar')
      ),
      (
        Headers.range,
        (final h) => h.range = RangeHeader(ranges: [Range(start: 1)])
      ),
      (
        Headers.referer,
        (final h) => h.referer = Uri.parse('https://example.com')
      ),
      (
        Headers.referrerPolicy,
        (final h) => h.referrerPolicy = ReferrerPolicyHeader.origin
      ),
      (
        Headers.retryAfter,
        (final h) => h.retryAfter = RetryAfterHeader(delay: 1)
      ),
      (
        Headers.secFetchDest,
        (final h) => h.secFetchDest = SecFetchDestHeader.audio
      ),
      (
        Headers.secFetchMode,
        (final h) => h.secFetchMode = SecFetchModeHeader.cors
      ),
      (
        Headers.secFetchSite,
        (final h) => h.secFetchSite = SecFetchSiteHeader.crossSite
      ),
      (Headers.server, (final h) => h.server = 'localhost'),
      (
        Headers.setCookie,
        (final h) => h.setCookie = SetCookieHeader(name: 'foo', value: 'bar')
      ),
      (
        Headers.strictTransportSecurity,
        (final h) => h.strictTransportSecurity =
            StrictTransportSecurityHeader(maxAge: 42)
      ),
      (Headers.te, (final h) => h.te = TEHeader(encodings: [TeQuality('foo')])),
      (Headers.trailer, (final h) => h.trailer = ['foo']),
      (
        Headers.transferEncoding,
        (final h) => h.transferEncoding =
            TransferEncodingHeader(encodings: [TransferEncoding.gzip])
      ),
      (
        Headers.upgrade,
        (final h) => h.upgrade =
            UpgradeHeader(protocols: [UpgradeProtocol(protocol: 'foo')])
      ),
      (Headers.userAgent, (final h) => h.userAgent = 'null'),
      (Headers.vary, (final h) => h.vary = VaryHeader.wildcard()),
      (Headers.via, (final h) => h.via = ['foo']),
      (
        Headers.wwwAuthenticate,
        (final h) => h.wwwAuthenticate = AuthenticationHeader(
            scheme: 'Bearer',
            parameters: [const AuthenticationParameter('foo', 'bar')])
      ),
      (Headers.xPoweredBy, (final h) => h.xPoweredBy = 'null'),
      (
        Headers.forwarded,
        (final h) => h.forwarded = ForwardedHeader([
              ForwardedElement(
                  forwardedFor: const ForwardedIdentifier('192.1.0.1'))
            ])
      ),
      (
        Headers.xForwardedFor,
        (final h) => h.xForwardedFor = XForwardedForHeader(['192.1.0.1'])
      ),
    ].map((final r) => (accessor: r.$1, mutator: r.$2)),
  );
}
