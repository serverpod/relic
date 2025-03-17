import 'package:relic/src/method/request_method.dart';

import 'headers.dart';
import 'header_flyweight.dart';
import 'standard_headers_flyweights.dart' as std;
import 'typed/typed_headers.dart';

extension StandardHeadersEx on Headers {
  Header<DateTime> get date_ => std.date[this];
  DateTime? get date => date_();

  Header<DateTime> get expires_ => std.expires[this];
  DateTime? get expires => expires_();

  Header<DateTime> get lastModified_ => std.lastModified[this];
  DateTime? get lastModified => lastModified_();

  Header<DateTime> get ifModifiedSince_ => std.ifModifiedSince[this];
  DateTime? get ifModifiedSince => ifModifiedSince_();

  Header<DateTime> get ifUnmodifiedSince_ => std.ifUnmodifiedSince[this];
  DateTime? get ifUnmodifiedSince => ifUnmodifiedSince_();

  Header<Uri> get origin_ => std.origin[this];
  Uri? get origin => origin_();

  Header<String> get server_ => std.server[this];
  String? get server => server_();

  Header<List<String>> get via_ => std.via[this];
  List<String>? get via => via_();

  Header<FromHeader> get from_ => std.from[this];
  FromHeader? get from => from_();

  Header<Uri> get host_ => std.host[this];
  Uri? get host => host_();

  Header<AcceptEncodingHeader> get acceptEncoding_ => std.acceptEncoding[this];
  AcceptEncodingHeader? get acceptEncoding => acceptEncoding_();

  Header<AcceptLanguageHeader> get acceptLanguage_ => std.acceptLanguage[this];
  AcceptLanguageHeader? get acceptLanguage => acceptLanguage_();

  Header<List<String>> get accessControlRequestHeaders_ =>
      std.accessControlRequestHeaders[this];
  List<String>? get accessControlRequestHeaders =>
      accessControlRequestHeaders_();

  Header<RequestMethod> get accessControlRequestMethod_ =>
      std.accessControlRequestMethod[this];
  RequestMethod? get accessControlRequestMethod =>
      accessControlRequestMethod_();

  Header<int> get age_ => std.age[this];
  int? get age => age_();

  Header<AuthorizationHeader> get authorization_ => std.authorization[this];
  AuthorizationHeader? get authorization => authorization_();

  Header<ConnectionHeader> get connection_ => std.connection[this];
  ConnectionHeader? get connection => connection_();

  Header<int> get contentLength_ => std.contentLength[this];
  int? get contentLength => contentLength_();

  Header<ExpectHeader> get expect_ => std.expect[this];
  ExpectHeader? get expect => expect_();

  Header<IfMatchHeader> get ifMatch_ => std.ifMatch[this];
  IfMatchHeader? get ifMatch => ifMatch_();

  Header<IfNoneMatchHeader> get ifNoneMatch_ => std.ifNoneMatch[this];
  IfNoneMatchHeader? get ifNoneMatch => ifNoneMatch_();

  Header<IfRangeHeader> get ifRange_ => std.ifRange[this];
  IfRangeHeader? get ifRange => ifRange_();

  Header<int> get maxForwards_ => std.maxForwards[this];
  int? get maxForwards => maxForwards_();

  Header<AuthorizationHeader> get proxyAuthorization_ =>
      std.proxyAuthorization[this];
  AuthorizationHeader? get proxyAuthorization => proxyAuthorization_();

  Header<RangeHeader> get range_ => std.range[this];
  RangeHeader? get range => range_();

  Header<Uri> get referer_ => std.referer[this];
  Uri? get referer => referer_();

  Header<String> get userAgent_ => std.userAgent[this];
  String? get userAgent => userAgent_();

  Header<TEHeader> get te_ => std.te[this];
  TEHeader? get te => te_();

  Header<UpgradeHeader> get upgrade_ => std.upgrade[this];
  UpgradeHeader? get upgrade => upgrade_();

  Header<Uri> get location_ => std.location[this];
  Uri? get location => location_();

  Header<String> get xPoweredBy_ => std.xPoweredBy[this];
  String? get xPoweredBy => xPoweredBy_();

  Header<AccessControlAllowOriginHeader> get accessControlAllowOrigin_ =>
      std.accessControlAllowOrigin[this];
  AccessControlAllowOriginHeader? get accessControlAllowOrigin =>
      accessControlAllowOrigin_();

  Header<AccessControlExposeHeadersHeader> get accessControlExposeHeaders_ =>
      std.accessControlExposeHeaders[this];
  AccessControlExposeHeadersHeader? get accessControlExposeHeaders =>
      accessControlExposeHeaders_();

  Header<int> get accessControlMaxAge_ => std.accessControlMaxAge[this];
  int? get accessControlMaxAge => accessControlMaxAge_();

  Header<List<RequestMethod>> get allow_ => std.allow[this];
  List<RequestMethod>? get allow => allow_();

  Header<CacheControlHeader> get cacheControl_ => std.cacheControl[this];
  CacheControlHeader? get cacheControl => cacheControl_();

  Header<ContentEncodingHeader> get contentEncoding_ =>
      std.contentEncoding[this];
  ContentEncodingHeader? get contentEncoding => contentEncoding_();

  Header<ContentLanguageHeader> get contentLanguage_ =>
      std.contentLanguage[this];
  ContentLanguageHeader? get contentLanguage => contentLanguage_();

  Header<Uri> get contentLocation_ => std.contentLocation[this];
  Uri? get contentLocation => contentLocation_();

  Header<ContentRangeHeader> get contentRange_ => std.contentRange[this];
  ContentRangeHeader? get contentRange => contentRange_();

  Header<ETagHeader> get etag_ => std.etag[this];
  ETagHeader? get etag => etag_();

  Header<AuthenticationHeader> get proxyAuthenticate_ =>
      std.proxyAuthenticate[this];
  AuthenticationHeader? get proxyAuthenticate => proxyAuthenticate_();

  Header<RetryAfterHeader> get retryAfter_ => std.retryAfter[this];
  RetryAfterHeader? get retryAfter => retryAfter_();

  Header<List<String>> get trailer_ => std.trailer[this];
  List<String>? get trailer => trailer_();

  Header<VaryHeader> get vary_ => std.vary[this];
  VaryHeader? get vary => vary_();

  Header<AuthenticationHeader> get wwwAuthenticate_ =>
      std.wwwAuthenticate[this];
  AuthenticationHeader? get wwwAuthenticate => wwwAuthenticate_();

  Header<ContentDispositionHeader> get contentDisposition_ =>
      std.contentDisposition[this];
  ContentDispositionHeader? get contentDisposition => contentDisposition_();

  Header<AcceptHeader> get accept_ => std.accept[this];
  AcceptHeader? get accept => accept_();

  Header<AcceptRangesHeader> get acceptRanges_ => std.acceptRanges[this];
  AcceptRangesHeader? get acceptRanges => acceptRanges_();

  Header<TransferEncodingHeader> get transferEncoding_ =>
      std.transferEncoding[this];
  TransferEncodingHeader? get transferEncoding => transferEncoding_();

  Header<CookieHeader> get cookie_ => std.cookie[this];
  CookieHeader? get cookie => cookie_();

  Header<SetCookieHeader> get setCookie_ => std.setCookie[this];
  SetCookieHeader? get setCookie => setCookie_();

  Header<StrictTransportSecurityHeader> get strictTransportSecurity_ =>
      std.strictTransportSecurity[this];
  StrictTransportSecurityHeader? get strictTransportSecurity =>
      strictTransportSecurity_();

  Header<ContentSecurityPolicyHeader> get contentSecurityPolicy_ =>
      std.contentSecurityPolicy[this];
  ContentSecurityPolicyHeader? get contentSecurityPolicy =>
      contentSecurityPolicy_();

  Header<ReferrerPolicyHeader> get referrerPolicy_ => std.referrerPolicy[this];
  ReferrerPolicyHeader? get referrerPolicy => referrerPolicy_();

  Header<PermissionsPolicyHeader> get permissionsPolicy_ =>
      std.permissionsPolicy[this];
  PermissionsPolicyHeader? get permissionsPolicy => permissionsPolicy_();

  Header<bool> get accessControlAllowCredentials_ =>
      std.accessControlAllowCredentials[this];
  bool? get accessControlAllowCredentials => accessControlAllowCredentials_();

  Header<AccessControlAllowMethodsHeader> get accessControlAllowMethods_ =>
      std.accessControlAllowMethods[this];
  AccessControlAllowMethodsHeader? get accessControlAllowMethods =>
      accessControlAllowMethods_();

  Header<AccessControlAllowHeadersHeader> get accessControlAllowHeaders_ =>
      std.accessControlAllowHeaders[this];
  AccessControlAllowHeadersHeader? get accessControlAllowHeaders =>
      accessControlAllowHeaders_();

  Header<ClearSiteDataHeader> get clearSiteData_ => std.clearSiteData[this];
  ClearSiteDataHeader? get clearSiteData => clearSiteData_();

  Header<SecFetchDestHeader> get secFetchDest_ => std.secFetchDest[this];
  SecFetchDestHeader? get secFetchDest => secFetchDest_();

  Header<SecFetchModeHeader> get secFetchMode_ => std.secFetchMode[this];
  SecFetchModeHeader? get secFetchMode => secFetchMode_();

  Header<SecFetchSiteHeader> get secFetchSite_ => std.secFetchSite[this];
  SecFetchSiteHeader? get secFetchSite => secFetchSite_();

  Header<CrossOriginResourcePolicyHeader> get crossOriginResourcePolicy_ =>
      std.crossOriginResourcePolicy[this];
  CrossOriginResourcePolicyHeader? get crossOriginResourcePolicy =>
      crossOriginResourcePolicy_();

  Header<CrossOriginEmbedderPolicyHeader> get crossOriginEmbedderPolicy_ =>
      std.crossOriginEmbedderPolicy[this];
  CrossOriginEmbedderPolicyHeader? get crossOriginEmbedderPolicy =>
      crossOriginEmbedderPolicy_();

  Header<CrossOriginOpenerPolicyHeader> get crossOriginOpenerPolicy_ =>
      std.crossOriginOpenerPolicy[this];
  CrossOriginOpenerPolicyHeader? get crossOriginOpenerPolicy =>
      crossOriginOpenerPolicy_();
}
