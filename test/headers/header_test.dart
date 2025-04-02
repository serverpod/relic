import 'package:relic/relic.dart';
import 'package:relic/src/headers/standard_headers_extensions.dart';
import 'package:relic/src/method/request_method.dart';
import 'package:test/test.dart';

import '../util/test_util.dart';
import 'headers_test_utils.dart';

void main() {
  group('Given Headers class', () {
    test('when created with default values then it initializes correctly', () {
      var headers = Headers.empty();
      expect(headers, isEmpty);
      expect(headers.date, isNull);
    });

    test('when custom headers are added then they are included', () {
      var headers = Headers.fromMap({
        'X-Custom-Header': ['value']
      });
      expect(headers['x-custom-header'], equals(['value']));
    });

    test('when custom headers are removed then they are no longer present', () {
      var headers = Headers.fromMap({
        'X-Custom-Header': ['value']
      });
      headers = headers.transform((mh) => mh.remove('X-Custom-Header'));
      expect(headers['x-custom-header'], isNull);
    });

    test('when accessing headers then they are case insensitive', () {
      var headers = Headers.fromMap({
        'Case-Insensitive': ['value']
      });
      expect(headers['case-insensitive'], contains('value'));
      expect(headers['CASE-INSENSITIVE'], contains('value'));
    });

    test('when headers are copied then modifications are correctly applied',
        () {
      var headers = Headers.fromMap({
        'Initial-Header': ['initial']
      });
      var copiedHeaders = headers.transform((mh) {
        mh.remove('Initial-Header');
        mh['Copied-Header'] = ['copied'];
      });
      expect(copiedHeaders['initial-header'], isNull);
      expect(copiedHeaders['copied-header'], equals(['copied']));
    });

    test('when headers are applied to a Response then they are set correctly',
        () {
      var headers = Headers.build((mh) {
        mh['Response-Header'] = ['response-value'];
      });
      var response = Response.ok(headers: headers);

      expect(response.headers['Response-Header'], equals(['response-value']));
    });

    test('when handling large headers then they are processed correctly', () {
      var largeValue = List.filled(10000, 'a').join();
      var headers = Headers.build((mh) {
        mh['Large-Header'] = [largeValue];
      });
      expect(headers['large-header']?.first.length, equals(10000));
    });

    test('when a managed header is removed then it is no longer present', () {
      var headers = Headers.build((mh) => mh.date = DateTime.now());
      headers = headers.transform((mh) => mh.date = null);
      expect(headers.date, isNull);
    });

    test('when a managed header is updated then it is correctly replaced', () {
      var headers = Headers.build((mh) => mh.date = DateTime.now());
      var newDate = DateTime.now()
          .add(Duration(days: 1))
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
        final header = v[mh];
        singleTest('then raw value not set',
            actual: mh, expected: isNot(contains(v.key)));
        singleTest('then not isSet', actual: header.isSet, expected: isFalse);
        singleTest('then set fails if type of value wrong',
            actual: () => header.set(Object()),
            expected: throwsA(isA<TypeError>()));
        singleTest('then set to null succeeds',
            actual: () => header.set(null), expected: returnsNormally);
        singleTest('then set succeeds if value is correct type',
            actual: () => header.set(header.valueOrNull),
            expected: returnsNormally);
      });
    },
    variants: Headers.all,
  );

  parameterizedGroup(
    (v) => 'Given a "${v.key}" header with no raw value',
    (v) {
      late final headers = Headers.empty();
      late final header = v[headers];

      singleTest('then raw value not set',
          actual: headers, expected: isNot(contains(v.key)));
      singleTest('then isSet is false',
          actual: header.isSet, expected: isFalse);
      singleTest('then isValid is false',
          actual: header.isValid, expected: isFalse);
      singleTest('then valueOrNull is null',
          actual: header.valueOrNull, expected: isNull);
      singleTest('then valueOrNullIfInvalid is null',
          actual: header.valueOrNullIfInvalid, expected: isNull);
      singleTest('then value throws',
          actual: () => header.value, expected: throwsMissingHeader);
    },
    variants: Headers.all,
  );

  parameterizedGroup(
    (v) => 'Given a "${v.key}" header with an empty raw value',
    (v) {
      late final headers = Headers.fromMap({
        v.key: ['']
      });
      late final header = v[headers];

      singleTest('then raw value set',
          actual: headers, expected: contains(v.key));
      singleTest('then isSet is true', actual: header.isSet, expected: isTrue);
      singleTest('then isValid is false',
          actual: header.isValid, expected: isFalse);
      singleTest('then valueOrNull throws',
          actual: () => header.valueOrNull, expected: throwsInvalidHeader);
      singleTest('then valueOrNullIfInvalid is null',
          actual: header.valueOrNullIfInvalid, expected: isNull);
      singleTest('then value throws',
          actual: () => header.value, expected: throwsInvalidHeader);
    },
    variants: Headers.all,
  );

  parameterizedGroup(
    (v) => 'Given a "${v.key}" header with a raw value "[\'invalid\']"}',
    (v) {
      late final header = v[Headers.fromMap({
        v.key: ['invalid']
      })];

      singleTest('then isSet is true', actual: header.isSet, expected: isTrue);
      singleTest('then isValid is false',
          actual: header.isValid, expected: isFalse);
      singleTest('then valueOrNull throws',
          actual: () => header.valueOrNull, expected: throwsInvalidHeader);
      singleTest('then value throws',
          actual: () => header.value, expected: throwsInvalidHeader);
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
      Headers.xPoweredBy,
    }),
  );

  parameterizedTest(
    (v) => 'Given a "${v.key.key}" header '
        'when using the named extension property on an empty Headers instance '
        'then reading it succeeds and returns null',
    (v) {
      expect(() => v.value(Headers.empty()), returnsNormally);
      expect(v.value(Headers.empty()), isNull);
    },
    variants: <HeaderFlyweight, dynamic Function(Headers)>{
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
    }.entries,
  );

  parameterizedTest(
    (v) => 'Given a "${v.key.key}" header '
        'when using the named extension property on an empty MutableHeaders instance '
        'then reading it succeeds and returns null',
    (v) {
      expect(() => Headers.build((mh) => v.value(mh)), returnsNormally);
      Headers.build((mh) => expect(v.value(mh), isNull));
    },
    variants: <HeaderFlyweight, dynamic Function(MutableHeaders)>{
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
    }.entries,
  );

  parameterizedTest(
    (v) => 'Given a "${v.key.key}" header '
        'when using the named extension property on an empty MutableHeaders instance '
        'then setting to null succeeds',
    (v) {
      expect(() => Headers.build((mh) => v.value(mh)), returnsNormally);
    },
    variants: <HeaderFlyweight, dynamic Function(MutableHeaders)>{
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
    }.entries,
  );
  parameterizedTest(
    (v) => 'Given a "${v.key.key}" header '
        'when using the named extension property on an empty MutableHeaders instance '
        'then setting to value succeeds',
    (v) {
      expect(() => Headers.build((mh) => v.value(mh)), returnsNormally);
    },
    variants: <HeaderFlyweight, dynamic Function(MutableHeaders)>{
      Headers.accept: (h) =>
          h.accept = AcceptHeader.parse(['application/vnd.example.api+json']),
      Headers.acceptEncoding: (h) =>
          h.acceptEncoding = AcceptEncodingHeader.wildcard(),
      Headers.acceptLanguage: (h) =>
          h.acceptLanguage = AcceptLanguageHeader.wildcard(),
      Headers.acceptRanges: (h) => h.acceptRanges = AcceptRangesHeader.none(),
      Headers.accessControlAllowCredentials: (h) =>
          h.accessControlAllowCredentials = true,
      Headers.accessControlAllowHeaders: (h) => h.accessControlAllowHeaders =
          AccessControlAllowHeadersHeader.wildcard(),
      Headers.accessControlAllowMethods: (h) => h.accessControlAllowMethods =
          AccessControlAllowMethodsHeader.wildcard(),
      Headers.accessControlAllowOrigin: (h) => h.accessControlAllowOrigin =
          AccessControlAllowOriginHeader.origin(origin: Uri()),
      Headers.accessControlExposeHeaders: (h) => h.accessControlExposeHeaders =
          AccessControlExposeHeadersHeader.headers(headers: null),
      Headers.accessControlMaxAge: (h) => h.accessControlMaxAge = 42,
      Headers.accessControlRequestHeaders: (h) =>
          h.accessControlRequestHeaders = [''],
      Headers.accessControlRequestMethod: (h) =>
          h.accessControlRequestMethod = RequestMethod.get,
      Headers.age: (h) => h.age = 42,
      Headers.allow: (h) => h.allow = [RequestMethod.get],
      Headers.authorization: (h) =>
          h.authorization = BearerAuthorizationHeader(token: 'foobar'),
      Headers.cacheControl: (h) =>
          h.cacheControl = CacheControlHeader.parse(['max-age=3600']),
      Headers.clearSiteData: (h) =>
          h.clearSiteData = ClearSiteDataHeader.wildcard(),
      Headers.connection: (h) => h.connection =
          ConnectionHeader(directives: [ConnectionHeaderType.keepAlive]),
      Headers.contentDisposition: (h) => h.contentDisposition =
          ContentDispositionHeader.parse('attachment; filename="report.pdf"'),
      Headers.contentEncoding: (h) =>
          h.contentEncoding = ContentEncodingHeader(encodings: []),
      Headers.contentLanguage: (h) =>
          h.contentLanguage = ContentLanguageHeader(languages: []),
      Headers.contentLength: (h) => h.contentLength = 1202,
      Headers.contentLocation: (h) => h.contentLocation = Uri(),
      Headers.contentRange: (h) => h.contentRange = ContentRangeHeader(),
      Headers.contentSecurityPolicy: (h) =>
          h.contentSecurityPolicy = ContentSecurityPolicyHeader(directives: []),
      Headers.cookie: (h) => h.cookie = CookieHeader(cookies: []),
      Headers.crossOriginEmbedderPolicy: (h) => h.crossOriginEmbedderPolicy =
          CrossOriginEmbedderPolicyHeader.unsafeNone,
      Headers.crossOriginOpenerPolicy: (h) =>
          h.crossOriginOpenerPolicy = CrossOriginOpenerPolicyHeader.unsafeNone,
      Headers.crossOriginResourcePolicy: (h) => h.crossOriginResourcePolicy =
          CrossOriginResourcePolicyHeader.sameSite,
      Headers.date: (h) => h.date = DateTime.now(),
      Headers.etag: (h) => h.etag = ETagHeader(value: ''),
      Headers.expect: (h) => h.expect = ExpectHeader.continue100,
      Headers.expires: (h) => h.expires = DateTime.now(),
      Headers.from: (h) => h.from = FromHeader(emails: []),
      Headers.host: (h) => h.host = Uri(),
      Headers.ifMatch: (h) => h.ifMatch = IfMatchHeader.wildcard(),
      Headers.ifModifiedSince: (h) => h.ifModifiedSince = DateTime.now(),
      Headers.ifNoneMatch: (h) => h.ifNoneMatch = IfNoneMatchHeader.wildcard(),
      Headers.ifRange: (h) =>
          h.ifRange = IfRangeHeader(lastModified: DateTime.now()),
      Headers.ifUnmodifiedSince: (h) => h.ifUnmodifiedSince = DateTime.now(),
      Headers.lastModified: (h) => h.lastModified = DateTime.now(),
      Headers.location: (h) => h.location = Uri(),
      Headers.maxForwards: (h) => h.maxForwards = 42,
      Headers.origin: (h) => h.origin = Uri(),
      Headers.permissionsPolicy: (h) =>
          h.permissionsPolicy = PermissionsPolicyHeader(directives: []),
      Headers.proxyAuthenticate: (h) => h.proxyAuthenticate =
          AuthenticationHeader(scheme: '', parameters: []),
      Headers.proxyAuthorization: (h) =>
          h.proxyAuthorization = BearerAuthorizationHeader(token: 'foobar'),
      Headers.range: (h) => h.range = RangeHeader(ranges: []),
      Headers.referer: (h) => h.referer = Uri(),
      Headers.referrerPolicy: (h) =>
          h.referrerPolicy = ReferrerPolicyHeader.origin,
      Headers.retryAfter: (h) => h.retryAfter = RetryAfterHeader(delay: 1),
      Headers.secFetchDest: (h) => h.secFetchDest = SecFetchDestHeader.audio,
      Headers.secFetchMode: (h) => h.secFetchMode = SecFetchModeHeader.cors,
      Headers.secFetchSite: (h) =>
          h.secFetchSite = SecFetchSiteHeader.crossSite,
      Headers.server: (h) => h.server = 'localhost',
      Headers.setCookie: (h) =>
          h.setCookie = SetCookieHeader(name: 'foo', value: 'bar'),
      Headers.strictTransportSecurity: (h) =>
          h.strictTransportSecurity = StrictTransportSecurityHeader(maxAge: 42),
      Headers.te: (h) => h.te = TEHeader(encodings: []),
      Headers.trailer: (h) => h.trailer = [],
      Headers.transferEncoding: (h) =>
          h.transferEncoding = TransferEncodingHeader(encodings: []),
      Headers.upgrade: (h) => h.upgrade = UpgradeHeader(protocols: []),
      Headers.userAgent: (h) => h.userAgent = 'null',
      Headers.vary: (h) => h.vary = VaryHeader.headers(fields: []),
      Headers.via: (h) => h.via = [],
      Headers.wwwAuthenticate: (h) =>
          h.wwwAuthenticate = AuthenticationHeader(scheme: '', parameters: []),
      Headers.xPoweredBy: (h) => h.xPoweredBy = 'null',
    }.entries,
  );
}
