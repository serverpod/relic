import 'dart:collection';
import 'dart:io' as io; // TODO: Get rid of this dependen

import 'package:http_parser/http_parser.dart';

part 'mutable_headers.dart';

typedef _BackingStore = CaseInsensitiveMap<Iterable<String>>;

class HeadersBase extends UnmodifiableMapView<String, Iterable<String>> {
  final _BackingStore _backing;
  HeadersBase._(this._backing) : super(_backing);
}

/// [Headers] is a case-insensitive, unmodifiable map that stores headers
class Headers extends HeadersBase {
  /// Request Headers
  static const acceptHeader = "accept";
  static const acceptEncodingHeader = "accept-encoding";
  static const acceptLanguageHeader = "accept-language";
  static const authorizationHeader = "authorization";
  static const expectHeader = "expect";
  static const fromHeader = "from";
  static const hostHeader = "host";
  static const ifMatchHeader = "if-match";
  static const ifModifiedSinceHeader = "if-modified-since";
  static const ifNoneMatchHeader = "if-none-match";
  static const ifRangeHeader = "if-range";
  static const ifUnmodifiedSinceHeader = "if-unmodified-since";
  static const maxForwardsHeader = "max-forwards";
  static const proxyAuthorizationHeader = "proxy-authorization";
  static const rangeHeader = "range";
  static const teHeader = "te";
  static const upgradeHeader = "upgrade";
  static const userAgentHeader = "user-agent";
  static const accessControlRequestHeadersHeader =
      'access-control-request-headers';
  static const accessControlRequestMethodHeader =
      'access-control-request-method';

  /// Response Headers
  static const accessControlAllowCredentialsHeader =
      'access-control-allow-credentials';
  static const accessControlAllowOriginHeader = 'access-control-allow-origin';
  static const accessControlExposeHeadersHeader =
      'access-control-expose-headers';
  static const accessControlMaxAgeHeader = 'access-control-max-age';
  static const ageHeader = "age";
  static const allowHeader = "allow";
  static const cacheControlHeader = "cache-control";
  static const connectionHeader = "connection";
  static const contentDispositionHeader = "content-disposition";
  static const contentEncodingHeader = "content-encoding";
  static const contentLanguageHeader = "content-language";
  static const contentLocationHeader = "content-location";
  static const contentRangeHeader = "content-range";
  static const etagHeader = "etag";
  static const expiresHeader = "expires";
  static const lastModifiedHeader = "last-modified";
  static const locationHeader = "location";
  static const proxyAuthenticateHeader = "proxy-authenticate";
  static const retryAfterHeader = "retry-after";
  static const trailerHeader = "trailer";
  static const transferEncodingHeader = "transfer-encoding";
  static const varyHeader = "vary";
  static const wwwAuthenticateHeader = "www-authenticate";
  static const xPoweredByHeader = 'x-powered-by';

  /// Common Headers (Used in Both Requests and Responses)
  static const acceptRangesHeader = "accept-ranges";
  static const contentLengthHeader = "content-length";
  static const contentTypeHeader = "content-type";

  /// General Headers
  static const dateHeader = "date";
  static const originHeader = "origin";
  static const refererHeader = "referer";
  static const serverHeader = "server";
  static const viaHeader = "via";
  static const cookieHeader = "cookie";
  static const setCookieHeader = "set-cookie";

  /// Security and Modern Headers
  static const strictTransportSecurityHeader = "strict-transport-security";
  static const contentSecurityPolicyHeader = "content-security-policy";
  static const referrerPolicyHeader = "referrer-policy";
  static const permissionsPolicyHeader = "permissions-policy";
  static const accessControlAllowMethodsHeader = "access-control-allow-methods";
  static const accessControlAllowHeadersHeader = "access-control-allow-headers";
  static const clearSiteDataHeader = "clear-site-data";
  static const secFetchDestHeader = "sec-fetch-dest";
  static const secFetchModeHeader = "sec-fetch-mode";
  static const secFetchSiteHeader = "sec-fetch-site";
  static const crossOriginResourcePolicyHeader = "cross-origin-resource-policy";
  static const crossOriginEmbedderPolicyHeader = "cross-origin-embedder-policy";
  static const crossOriginOpenerPolicyHeader = "cross-origin-opener-policy";

  factory Headers.from(Map<String, Iterable<String>>? values) {
    if (values == null || values.isEmpty) {
      return _emptyHeaders;
    } else if (values is Headers) {
      return values;
    } else {
      return Headers._fromEntries(values.entries);
    }
  }

  factory Headers.fromEntries(
    Iterable<MapEntry<String, Iterable<String>>>? entries,
  ) {
    if (entries == null || entries.isEmpty) {
      return _emptyHeaders;
    } else {
      return Headers._fromEntries(entries);
    }
  }

  factory Headers.empty() => _emptyHeaders;

  factory Headers.build(void Function(MutableHeaders) update) =>
      Headers.empty().transform(update);

  // cannot be made const before: <insert link to dart CL
  Headers._empty() : this._fromEntries(const {});

  Headers._fromEntries(Iterable<MapEntry<String, Iterable<String>>> entries)
      : this._(CaseInsensitiveMap.from(Map.fromEntries(
          entries
              .where((e) => e.value.isNotEmpty)
              .map((e) => MapEntry(e.key, List.unmodifiable(e.value))),
        )));

  Headers._(super.backing) : super._();

  Headers transform(void Function(MutableHeaders) update) {
    final mutable = MutableHeaders._from(this);
    update(mutable);
    return mutable._freeze();
  }

  // TODO: Should die
  factory Headers.fromHttpRequest(
    io.HttpRequest request, {
    bool strict = false,
    required String? xPoweredBy,
    DateTime? date,
  }) {
    return Headers.build((mh) {
      request.headers.forEach((k, v) => mh[k] = v);
    });
  }
}

final _emptyHeaders = Headers._empty();
