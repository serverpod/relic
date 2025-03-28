import 'package:relic/relic.dart';
import 'package:relic/src/headers/standard_headers_extensions.dart';
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
    (v) => 'Given a "${v.key}" header with no raw value',
    (v) {
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
    (v) => 'Given a "${v.key}" header with an empty raw value',
    (v) {
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

  const invalid = ['invalid'];
  parameterizedGroup(
    (v) => 'Given a "${v.key}" header with a raw value $invalid',
    (v) {
      late final header = v[Headers.fromMap({v.key: invalid})];

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
      Headers.xPoweredBy,
    }),
  );

  test(
      'Given a headers object '
      'when using the named extensions getters '
      'then it succeeds', () {
    final headers = Headers.empty();
    // contentType, // Huh?
    expect(headers.cacheControl, isNull);
    expect(headers.connection, isNull);
    expect(headers.contentEncoding, isNull);
    expect(headers.contentLanguage, isNull);
    expect(headers.contentLength, isNull);
    expect(headers.contentLocation, isNull);
    expect(headers.date, isNull);
    expect(headers.referrerPolicy, isNull);
    expect(headers.trailer, isNull);
    expect(headers.transferEncoding, isNull);
    expect(headers.via, isNull);
    expect(headers.accept, isNull);
    expect(headers.acceptEncoding, isNull);
    expect(headers.acceptLanguage, isNull);
    expect(headers.authorization, isNull);
    expect(headers.cookie, isNull);
    expect(headers.expect, isNull);
    expect(headers.from, isNull);
    expect(headers.host, isNull);
    expect(headers.ifMatch, isNull);
    expect(headers.ifModifiedSince, isNull);
    expect(headers.ifNoneMatch, isNull);
    expect(headers.ifRange, isNull);
    expect(headers.ifUnmodifiedSince, isNull);
    expect(headers.maxForwards, isNull);
    expect(headers.origin, isNull);
    expect(headers.proxyAuthorization, isNull);
    expect(headers.range, isNull);
    expect(headers.referer, isNull);
    expect(headers.te, isNull);
    expect(headers.userAgent, isNull);
    expect(headers.accessControlRequestHeaders, isNull);
    expect(headers.accessControlRequestMethod, isNull);
    expect(headers.secFetchDest, isNull);
    expect(headers.secFetchMode, isNull);
    expect(headers.secFetchSite, isNull);
    expect(headers.acceptRanges, isNull);
    expect(headers.accessControlAllowCredentials, isNull);
    expect(headers.accessControlAllowHeaders, isNull);
    expect(headers.accessControlAllowMethods, isNull);
    expect(headers.accessControlMaxAge, isNull);
    expect(headers.age, isNull);
    expect(headers.allow, isNull);
    expect(headers.clearSiteData, isNull);
    expect(headers.contentRange, isNull);
    expect(headers.contentSecurityPolicy, isNull);
    expect(headers.crossOriginEmbedderPolicy, isNull);
    expect(headers.crossOriginOpenerPolicy, isNull);
    expect(headers.etag, isNull);
    expect(headers.expires, isNull);
    expect(headers.lastModified, isNull);
    expect(headers.location, isNull);
    expect(headers.permissionsPolicy, isNull);
    expect(headers.proxyAuthenticate, isNull);
    expect(headers.retryAfter, isNull);
    expect(headers.server, isNull);
    expect(headers.setCookie, isNull);
    expect(headers.strictTransportSecurity, isNull);
    expect(headers.vary, isNull);
    expect(headers.wwwAuthenticate, isNull);
    expect(headers.xPoweredBy, isNull);
  });

  test(
      'Given a MutableHeader object '
      'when using the named getter and setter extensions '
      'then it succeeds', () {
    Headers.build((mh) {
      // contentType, // Huh?

      expect(mh.cacheControl, isNull);
      expect(() => mh.cacheControl = null, returnsNormally);

      expect(mh.connection, isNull);
      expect(() => mh.connection = null, returnsNormally);

      expect(mh.contentDisposition, isNull);
      expect(() => mh.contentDisposition = null, returnsNormally);

      expect(mh.contentEncoding, isNull);
      expect(() => mh.contentEncoding = null, returnsNormally);

      expect(mh.contentLanguage, isNull);
      expect(() => mh.contentLanguage = null, returnsNormally);

      expect(mh.contentLength, isNull);
      expect(() => mh.contentLength = null, returnsNormally);

      expect(mh.contentLocation, isNull);
      expect(() => mh.contentLocation = null, returnsNormally);

      expect(mh.date, isNull);
      expect(() => mh.date = null, returnsNormally);

      expect(mh.referrerPolicy, isNull);
      expect(() => mh.referrerPolicy = null, returnsNormally);

      expect(mh.trailer, isNull);
      expect(() => mh.trailer = null, returnsNormally);

      expect(mh.transferEncoding, isNull);
      expect(() => mh.transferEncoding = null, returnsNormally);

      expect(mh.upgrade, isNull);
      expect(() => mh.upgrade = null, returnsNormally);

      expect(mh.via, isNull);
      expect(() => mh.via = null, returnsNormally);

      expect(mh.accept, isNull);
      expect(() => mh.accept = null, returnsNormally);

      expect(mh.acceptEncoding, isNull);
      expect(() => mh.acceptEncoding = null, returnsNormally);

      expect(mh.acceptLanguage, isNull);
      expect(() => mh.acceptLanguage = null, returnsNormally);

      expect(mh.authorization, isNull);
      expect(() => mh.authorization = null, returnsNormally);

      expect(mh.cookie, isNull);
      expect(() => mh.cookie = null, returnsNormally);

      expect(mh.expect, isNull);
      expect(() => mh.expect = null, returnsNormally);

      expect(mh.from, isNull);
      expect(() => mh.from = null, returnsNormally);

      expect(mh.host, isNull);
      expect(() => mh.host = null, returnsNormally);

      expect(mh.ifMatch, isNull);
      expect(() => mh.ifMatch = null, returnsNormally);

      expect(mh.ifModifiedSince, isNull);
      expect(() => mh.ifModifiedSince = null, returnsNormally);

      expect(mh.ifNoneMatch, isNull);
      expect(() => mh.ifNoneMatch = null, returnsNormally);

      expect(mh.ifRange, isNull);
      expect(() => mh.ifRange = null, returnsNormally);

      expect(mh.ifUnmodifiedSince, isNull);
      expect(() => mh.ifUnmodifiedSince = null, returnsNormally);

      expect(mh.maxForwards, isNull);
      expect(() => mh.maxForwards = null, returnsNormally);

      expect(mh.origin, isNull);
      expect(() => mh.origin = null, returnsNormally);

      expect(mh.proxyAuthorization, isNull);
      expect(() => mh.proxyAuthorization = null, returnsNormally);

      expect(mh.range, isNull);
      expect(() => mh.range = null, returnsNormally);

      expect(mh.referer, isNull);
      expect(() => mh.referer = null, returnsNormally);

      expect(mh.te, isNull);
      expect(() => mh.te = null, returnsNormally);

      expect(mh.userAgent, isNull);
      expect(() => mh.userAgent = null, returnsNormally);

      expect(mh.accessControlRequestHeaders, isNull);
      expect(() => mh.accessControlRequestHeaders = null, returnsNormally);

      expect(mh.accessControlRequestMethod, isNull);
      expect(() => mh.accessControlRequestMethod = null, returnsNormally);

      expect(mh.secFetchDest, isNull);
      expect(() => mh.secFetchDest = null, returnsNormally);

      expect(mh.secFetchMode, isNull);
      expect(() => mh.secFetchMode = null, returnsNormally);

      expect(mh.secFetchSite, isNull);
      expect(() => mh.secFetchSite = null, returnsNormally);

      expect(mh.acceptRanges, isNull);
      expect(() => mh.acceptRanges = null, returnsNormally);

      expect(mh.accessControlAllowCredentials, isNull);
      expect(() => mh.accessControlAllowCredentials = null, returnsNormally);

      expect(mh.accessControlAllowHeaders, isNull);
      expect(() => mh.accessControlAllowHeaders = null, returnsNormally);

      expect(mh.accessControlAllowMethods, isNull);
      expect(() => mh.accessControlAllowMethods = null, returnsNormally);

      expect(mh.accessControlAllowOrigin, isNull);
      expect(() => mh.accessControlAllowOrigin = null, returnsNormally);

      expect(mh.accessControlExposeHeaders, isNull);
      expect(() => mh.accessControlExposeHeaders = null, returnsNormally);

      expect(mh.accessControlMaxAge, isNull);
      expect(() => mh.accessControlMaxAge = null, returnsNormally);

      expect(mh.age, isNull);
      expect(() => mh.age = null, returnsNormally);

      expect(mh.allow, isNull);
      expect(() => mh.allow = null, returnsNormally);

      expect(mh.clearSiteData, isNull);
      expect(() => mh.clearSiteData = null, returnsNormally);

      expect(mh.contentRange, isNull);
      expect(() => mh.contentRange = null, returnsNormally);

      expect(mh.contentSecurityPolicy, isNull);
      expect(() => mh.contentSecurityPolicy = null, returnsNormally);

      expect(mh.crossOriginEmbedderPolicy, isNull);
      expect(() => mh.crossOriginEmbedderPolicy = null, returnsNormally);

      expect(mh.crossOriginOpenerPolicy, isNull);
      expect(() => mh.crossOriginOpenerPolicy = null, returnsNormally);

      expect(mh.crossOriginResourcePolicy, isNull);
      expect(() => mh.crossOriginResourcePolicy = null, returnsNormally);

      expect(mh.etag, isNull);
      expect(() => mh.etag = null, returnsNormally);

      expect(mh.expires, isNull);
      expect(() => mh.expires = null, returnsNormally);

      expect(mh.lastModified, isNull);
      expect(() => mh.lastModified = null, returnsNormally);

      expect(mh.location, isNull);
      expect(() => mh.location = null, returnsNormally);

      expect(mh.permissionsPolicy, isNull);
      expect(() => mh.permissionsPolicy = null, returnsNormally);

      expect(mh.proxyAuthenticate, isNull);
      expect(() => mh.proxyAuthenticate = null, returnsNormally);

      expect(mh.retryAfter, isNull);
      expect(() => mh.retryAfter = null, returnsNormally);

      expect(mh.server, isNull);
      expect(() => mh.server = null, returnsNormally);

      expect(mh.setCookie, isNull);
      expect(() => mh.setCookie = null, returnsNormally);

      expect(mh.strictTransportSecurity, isNull);
      expect(() => mh.strictTransportSecurity = null, returnsNormally);

      expect(mh.vary, isNull);
      expect(() => mh.vary = null, returnsNormally);

      expect(mh.wwwAuthenticate, isNull);
      expect(() => mh.wwwAuthenticate = null, returnsNormally);

      expect(mh.xPoweredBy, isNull);
      expect(() => mh.xPoweredBy = null, returnsNormally);
    });
  });
}
