import 'package:relic/src/method/request_method.dart';
import 'headers.dart';
import 'header_flyweight.dart';
import 'standard_headers_flyweights.dart' as std;
import 'typed/typed_headers.dart';

extension StandardHeadersBaseEx on HeadersBase {
  Header<DateTime> get date_ => std.date[this];
  Header<DateTime> get expires_ => std.expires[this];
  Header<DateTime> get lastModified_ => std.lastModified[this];
  Header<DateTime> get ifModifiedSince_ => std.ifModifiedSince[this];
  Header<DateTime> get ifUnmodifiedSince_ => std.ifUnmodifiedSince[this];
  Header<Uri> get origin_ => std.origin[this];
  Header<String> get server_ => std.server[this];
  Header<List<String>> get via_ => std.via[this];
  Header<FromHeader> get from_ => std.from[this];
  Header<Uri> get host_ => std.host[this];
  Header<AcceptEncodingHeader> get acceptEncoding_ => std.acceptEncoding[this];
  Header<AcceptLanguageHeader> get acceptLanguage_ => std.acceptLanguage[this];
  Header<List<String>> get accessControlRequestHeaders_ =>
      std.accessControlRequestHeaders[this];
  Header<RequestMethod> get accessControlRequestMethod_ =>
      std.accessControlRequestMethod[this];
  Header<int> get age_ => std.age[this];
  Header<AuthorizationHeader> get authorization_ => std.authorization[this];
  Header<ConnectionHeader> get connection_ => std.connection[this];
  Header<int> get contentLength_ => std.contentLength[this];
  Header<ExpectHeader> get expect_ => std.expect[this];
  Header<IfMatchHeader> get ifMatch_ => std.ifMatch[this];
  Header<IfNoneMatchHeader> get ifNoneMatch_ => std.ifNoneMatch[this];
  Header<IfRangeHeader> get ifRange_ => std.ifRange[this];
  Header<int> get maxForwards_ => std.maxForwards[this];
  Header<AuthorizationHeader> get proxyAuthorization_ =>
      std.proxyAuthorization[this];
  Header<RangeHeader> get range_ => std.range[this];
  Header<Uri> get referer_ => std.referer[this];
  Header<String> get userAgent_ => std.userAgent[this];
  Header<TEHeader> get te_ => std.te[this];
  Header<UpgradeHeader> get upgrade_ => std.upgrade[this];
  Header<Uri> get location_ => std.location[this];
  Header<String> get xPoweredBy_ => std.xPoweredBy[this];
  Header<AccessControlAllowOriginHeader> get accessControlAllowOrigin_ =>
      std.accessControlAllowOrigin[this];
  Header<AccessControlExposeHeadersHeader> get accessControlExposeHeaders_ =>
      std.accessControlExposeHeaders[this];
  Header<int> get accessControlMaxAge_ => std.accessControlMaxAge[this];
  Header<List<RequestMethod>> get allow_ => std.allow[this];
  Header<CacheControlHeader> get cacheControl_ => std.cacheControl[this];
  Header<ContentEncodingHeader> get contentEncoding_ =>
      std.contentEncoding[this];
  Header<ContentLanguageHeader> get contentLanguage_ =>
      std.contentLanguage[this];
  Header<Uri> get contentLocation_ => std.contentLocation[this];
  Header<ContentRangeHeader> get contentRange_ => std.contentRange[this];
  Header<ETagHeader> get etag_ => std.etag[this];
  Header<AuthenticationHeader> get proxyAuthenticate_ =>
      std.proxyAuthenticate[this];
  Header<RetryAfterHeader> get retryAfter_ => std.retryAfter[this];
  Header<List<String>> get trailer_ => std.trailer[this];
  Header<VaryHeader> get vary_ => std.vary[this];
  Header<AuthenticationHeader> get wwwAuthenticate_ =>
      std.wwwAuthenticate[this];
  Header<ContentDispositionHeader> get contentDisposition_ =>
      std.contentDisposition[this];
  Header<AcceptHeader> get accept_ => std.accept[this];
  Header<AcceptRangesHeader> get acceptRanges_ => std.acceptRanges[this];
  Header<TransferEncodingHeader> get transferEncoding_ =>
      std.transferEncoding[this];
  Header<CookieHeader> get cookie_ => std.cookie[this];
  Header<SetCookieHeader> get setCookie_ => std.setCookie[this];
  Header<StrictTransportSecurityHeader> get strictTransportSecurity_ =>
      std.strictTransportSecurity[this];
  Header<ContentSecurityPolicyHeader> get contentSecurityPolicy_ =>
      std.contentSecurityPolicy[this];
  Header<ReferrerPolicyHeader> get referrerPolicy_ => std.referrerPolicy[this];
  Header<PermissionsPolicyHeader> get permissionsPolicy_ =>
      std.permissionsPolicy[this];
  Header<bool> get accessControlAllowCredentials_ =>
      std.accessControlAllowCredentials[this];
  Header<AccessControlAllowMethodsHeader> get accessControlAllowMethods_ =>
      std.accessControlAllowMethods[this];
  Header<AccessControlAllowHeadersHeader> get accessControlAllowHeaders_ =>
      std.accessControlAllowHeaders[this];
  Header<ClearSiteDataHeader> get clearSiteData_ => std.clearSiteData[this];
  Header<SecFetchDestHeader> get secFetchDest_ => std.secFetchDest[this];
  Header<SecFetchModeHeader> get secFetchMode_ => std.secFetchMode[this];
  Header<SecFetchSiteHeader> get secFetchSite_ => std.secFetchSite[this];
  Header<CrossOriginResourcePolicyHeader> get crossOriginResourcePolicy_ =>
      std.crossOriginResourcePolicy[this];
  Header<CrossOriginEmbedderPolicyHeader> get crossOriginEmbedderPolicy_ =>
      std.crossOriginEmbedderPolicy[this];
  Header<CrossOriginOpenerPolicyHeader> get crossOriginOpenerPolicy_ =>
      std.crossOriginOpenerPolicy[this];
}

extension StandardHeadersExtensions on Headers {
  DateTime? get date => date_();
  DateTime? get expires => expires_();
  DateTime? get lastModified => lastModified_();
  DateTime? get ifModifiedSince => ifModifiedSince_();
  DateTime? get ifUnmodifiedSince => ifUnmodifiedSince_();
  Uri? get origin => origin_();
  String? get server => server_();
  List<String>? get via => via_();
  FromHeader? get from => from_();
  Uri? get host => host_();
  AcceptEncodingHeader? get acceptEncoding => acceptEncoding_();
  AcceptLanguageHeader? get acceptLanguage => acceptLanguage_();
  List<String>? get accessControlRequestHeaders =>
      accessControlRequestHeaders_();
  RequestMethod? get accessControlRequestMethod =>
      accessControlRequestMethod_();
  int? get age => age_();
  AuthorizationHeader? get authorization => authorization_();
  ConnectionHeader? get connection => connection_();
  int? get contentLength => contentLength_();
  ExpectHeader? get expect => expect_();
  IfMatchHeader? get ifMatch => ifMatch_();
  IfNoneMatchHeader? get ifNoneMatch => ifNoneMatch_();
  IfRangeHeader? get ifRange => ifRange_();
  int? get maxForwards => maxForwards_();
  AuthorizationHeader? get proxyAuthorization => proxyAuthorization_();
  RangeHeader? get range => range_();
  Uri? get referer => referer_();
  String? get userAgent => userAgent_();
  TEHeader? get te => te_();
  UpgradeHeader? get upgrade => upgrade_();
  Uri? get location => location_();
  String? get xPoweredBy => xPoweredBy_();
  AccessControlAllowOriginHeader? get accessControlAllowOrigin =>
      accessControlAllowOrigin_();
  AccessControlExposeHeadersHeader? get accessControlExposeHeaders =>
      accessControlExposeHeaders_();
  int? get accessControlMaxAge => accessControlMaxAge_();
  List<RequestMethod>? get allow => allow_();
  CacheControlHeader? get cacheControl => cacheControl_();
  ContentEncodingHeader? get contentEncoding => contentEncoding_();
  ContentLanguageHeader? get contentLanguage => contentLanguage_();
  Uri? get contentLocation => contentLocation_();
  ContentRangeHeader? get contentRange => contentRange_();
  ETagHeader? get etag => etag_();
  AuthenticationHeader? get proxyAuthenticate => proxyAuthenticate_();
  RetryAfterHeader? get retryAfter => retryAfter_();
  List<String>? get trailer => trailer_();
  VaryHeader? get vary => vary_();
  AuthenticationHeader? get wwwAuthenticate => wwwAuthenticate_();
  ContentDispositionHeader? get contentDisposition => contentDisposition_();
  AcceptHeader? get accept => accept_();
  AcceptRangesHeader? get acceptRanges => acceptRanges_();
  TransferEncodingHeader? get transferEncoding => transferEncoding_();
  CookieHeader? get cookie => cookie_();
  SetCookieHeader? get setCookie => setCookie_();
  StrictTransportSecurityHeader? get strictTransportSecurity =>
      strictTransportSecurity_();
  ContentSecurityPolicyHeader? get contentSecurityPolicy =>
      contentSecurityPolicy_();
  ReferrerPolicyHeader? get referrerPolicy => referrerPolicy_();
  PermissionsPolicyHeader? get permissionsPolicy => permissionsPolicy_();
  bool? get accessControlAllowCredentials => accessControlAllowCredentials_();
  AccessControlAllowMethodsHeader? get accessControlAllowMethods =>
      accessControlAllowMethods_();
  AccessControlAllowHeadersHeader? get accessControlAllowHeaders =>
      accessControlAllowHeaders_();
  ClearSiteDataHeader? get clearSiteData => clearSiteData_();
  SecFetchDestHeader? get secFetchDest => secFetchDest_();
  SecFetchModeHeader? get secFetchMode => secFetchMode_();
  SecFetchSiteHeader? get secFetchSite => secFetchSite_();
  CrossOriginResourcePolicyHeader? get crossOriginResourcePolicy =>
      crossOriginResourcePolicy_();
  CrossOriginEmbedderPolicyHeader? get crossOriginEmbedderPolicy =>
      crossOriginEmbedderPolicy_();
  CrossOriginOpenerPolicyHeader? get crossOriginOpenerPolicy =>
      crossOriginOpenerPolicy_();
}

extension StandardMutableHeadersExtensions on MutableHeaders {
  set date(DateTime? value) => date_.set(value);
  set expires(DateTime? value) => expires_.set(value);
  set lastModified(DateTime? value) => lastModified_.set(value);
  set ifModifiedSince(DateTime? value) => ifModifiedSince_.set(value);
  set ifUnmodifiedSince(DateTime? value) => ifUnmodifiedSince_.set(value);
  set origin(Uri? value) => origin_.set(value);
  set server(String? value) => server_.set(value);
  set via(List<String>? value) => via_.set(value);
  set from(FromHeader? value) => from_.set(value);
  set host(Uri? value) => host_.set(value);
  set acceptEncoding(AcceptEncodingHeader? value) => acceptEncoding_.set(value);
  set acceptLanguage(AcceptLanguageHeader? value) => acceptLanguage_.set(value);
  set accessControlRequestHeader(List<String>? value) =>
      accessControlRequestHeaders_.set(value);
  set accessControlRequestMethod(RequestMethod? value) =>
      accessControlRequestMethod_.set(value);
  set age(int? value) => age_.set(value);
  set authorization(AuthorizationHeader? value) => authorization_.set(value);
  set connection(ConnectionHeader? value) => connection_.set(value);
  set contentLength(int? value) => contentLength_.set(value);
  set expect(ExpectHeader? value) => expect_.set(value);
  set ifMatch(IfMatchHeader? value) => ifMatch_.set(value);
  set ifNoneMatch(IfNoneMatchHeader? value) => ifNoneMatch_.set(value);
  set ifRange(IfRangeHeader? value) => ifRange_.set(value);
  set maxForwards(int? value) => maxForwards_.set(value);
  set proxyAuthorization(AuthorizationHeader? value) =>
      proxyAuthorization_.set(value);
  set range(RangeHeader? value) => range_.set(value);
  set referer(Uri? value) => referer_.set(value);
  set userAgent(String? value) => userAgent_.set(value);
  set te(TEHeader? value) => te_.set(value);
  set upgrade(UpgradeHeader? value) => upgrade_.set(value);
  set location(Uri? value) => location_.set(value);
  set xPoweredBy(String? value) => xPoweredBy_.set(value);
  set accessControlAllowOrigin(AccessControlAllowOriginHeader? value) =>
      accessControlAllowOrigin_.set(value);
  set accessControlExposeHeaders(AccessControlExposeHeadersHeader? value) =>
      accessControlExposeHeaders_.set(value);
  set accessControlMaxAge(int? value) => accessControlMaxAge_.set(value);
  set allow(List<RequestMethod>? value) => allow_.set(value);
  set cacheControl(CacheControlHeader? value) => cacheControl_.set(value);
  set contentEncoding(ContentEncodingHeader? value) =>
      contentEncoding_.set(value);
  set contentLanguage(ContentLanguageHeader? value) =>
      contentLanguage_.set(value);
  set contentLocation(Uri? value) => contentLocation_.set(value);
  set contentRange(ContentRangeHeader? value) => contentRange_.set(value);
  set etag(ETagHeader? value) => etag_.set(value);
  set proxyAuthenticate(AuthenticationHeader? value) =>
      proxyAuthenticate_.set(value);
  set retryAfter(RetryAfterHeader? value) => retryAfter_.set(value);
  set trailer(List<String>? value) => trailer_.set(value);
  set vary(VaryHeader? value) => vary_.set(value);
  set wwwAuthenticate(AuthenticationHeader? value) =>
      wwwAuthenticate_.set(value);
  set contentDisposition(ContentDispositionHeader? value) =>
      contentDisposition_.set(value);
  set accept(AcceptHeader? value) => accept_.set(value);
  set acceptRanges(AcceptRangesHeader? value) => acceptRanges_.set(value);
  set transferEncoding(TransferEncodingHeader? value) =>
      transferEncoding_.set(value);
  set cookie(CookieHeader? value) => cookie_.set(value);
  set setCookie(SetCookieHeader? value) => setCookie_.set(value);
  set strictTransportSecurity(StrictTransportSecurityHeader? value) =>
      strictTransportSecurity_.set(value);
  set contentSecurityPolicy(ContentSecurityPolicyHeader? value) =>
      contentSecurityPolicy_.set(value);
  set referrerPolicy(ReferrerPolicyHeader? value) => referrerPolicy_.set(value);
  set permissionsPolicy(PermissionsPolicyHeader? value) =>
      permissionsPolicy_.set(value);
  set accessControlAllowCredentials(bool? value) =>
      accessControlAllowCredentials_.set(value);
  set accessControlAllowMethods(AccessControlAllowMethodsHeader? value) =>
      accessControlAllowMethods_.set(value);
  set accessControlAllowHeaders(AccessControlAllowHeadersHeader? value) =>
      accessControlAllowHeaders_.set(value);
  set clearSiteData(ClearSiteDataHeader? value) => clearSiteData_.set(value);
  set secFetchDest(SecFetchDestHeader? value) => secFetchDest_.set(value);
  set secFetchMode(SecFetchModeHeader? value) => secFetchMode_.set(value);
  set secFetchSite(SecFetchSiteHeader? value) => secFetchSite_.set(value);
  set crossOriginResourcePolicy(CrossOriginResourcePolicyHeader? value) =>
      crossOriginResourcePolicy_.set(value);
  set crossOriginEmbedderPolicy(CrossOriginEmbedderPolicyHeader? value) =>
      crossOriginEmbedderPolicy_.set(value);
  set crossOriginOpenerPolicy(CrossOriginOpenerPolicyHeader? value) =>
      crossOriginOpenerPolicy_.set(value);
  DateTime? get date => date_();
  DateTime? get expires => expires_();
  DateTime? get lastModified => lastModified_();
  DateTime? get ifModifiedSince => ifModifiedSince_();
  DateTime? get ifUnmodifiedSince => ifUnmodifiedSince_();
  Uri? get origin => origin_();
  String? get server => server_();
  List<String>? get via => via_();
  FromHeader? get from => from_();
  Uri? get host => host_();
  AcceptEncodingHeader? get acceptEncoding => acceptEncoding_();
  AcceptLanguageHeader? get acceptLanguage => acceptLanguage_();
  List<String>? get accessControlRequestHeaders =>
      accessControlRequestHeaders_();
  RequestMethod? get accessControlRequestMethod =>
      accessControlRequestMethod_();
  int? get age => age_();
  AuthorizationHeader? get authorization => authorization_();
  ConnectionHeader? get connection => connection_();
  int? get contentLength => contentLength_();
  ExpectHeader? get expect => expect_();
  IfMatchHeader? get ifMatch => ifMatch_();
  IfNoneMatchHeader? get ifNoneMatch => ifNoneMatch_();
  IfRangeHeader? get ifRange => ifRange_();
  int? get maxForwards => maxForwards_();
  AuthorizationHeader? get proxyAuthorization => proxyAuthorization_();
  RangeHeader? get range => range_();
  Uri? get referer => referer_();
  String? get userAgent => userAgent_();
  TEHeader? get te => te_();
  UpgradeHeader? get upgrade => upgrade_();
  Uri? get location => location_();
  String? get xPoweredBy => xPoweredBy_();
  AccessControlAllowOriginHeader? get accessControlAllowOrigin =>
      accessControlAllowOrigin_();
  AccessControlExposeHeadersHeader? get accessControlExposeHeaders =>
      accessControlExposeHeaders_();
  int? get accessControlMaxAge => accessControlMaxAge_();
  List<RequestMethod>? get allow => allow_();
  CacheControlHeader? get cacheControl => cacheControl_();
  ContentEncodingHeader? get contentEncoding => contentEncoding_();
  ContentLanguageHeader? get contentLanguage => contentLanguage_();
  Uri? get contentLocation => contentLocation_();
  ContentRangeHeader? get contentRange => contentRange_();
  ETagHeader? get etag => etag_();
  AuthenticationHeader? get proxyAuthenticate => proxyAuthenticate_();
  RetryAfterHeader? get retryAfter => retryAfter_();
  List<String>? get trailer => trailer_();
  VaryHeader? get vary => vary_();
  AuthenticationHeader? get wwwAuthenticate => wwwAuthenticate_();
  ContentDispositionHeader? get contentDisposition => contentDisposition_();
  AcceptHeader? get accept => accept_();
  AcceptRangesHeader? get acceptRanges => acceptRanges_();
  TransferEncodingHeader? get transferEncoding => transferEncoding_();
  CookieHeader? get cookie => cookie_();
  SetCookieHeader? get setCookie => setCookie_();
  StrictTransportSecurityHeader? get strictTransportSecurity =>
      strictTransportSecurity_();
  ContentSecurityPolicyHeader? get contentSecurityPolicy =>
      contentSecurityPolicy_();
  ReferrerPolicyHeader? get referrerPolicy => referrerPolicy_();
  PermissionsPolicyHeader? get permissionsPolicy => permissionsPolicy_();
  bool? get accessControlAllowCredentials => accessControlAllowCredentials_();
  AccessControlAllowMethodsHeader? get accessControlAllowMethods =>
      accessControlAllowMethods_();
  AccessControlAllowHeadersHeader? get accessControlAllowHeaders =>
      accessControlAllowHeaders_();
  ClearSiteDataHeader? get clearSiteData => clearSiteData_();
  SecFetchDestHeader? get secFetchDest => secFetchDest_();
  SecFetchModeHeader? get secFetchMode => secFetchMode_();
  SecFetchSiteHeader? get secFetchSite => secFetchSite_();
  CrossOriginResourcePolicyHeader? get crossOriginResourcePolicy =>
      crossOriginResourcePolicy_();
  CrossOriginEmbedderPolicyHeader? get crossOriginEmbedderPolicy =>
      crossOriginEmbedderPolicy_();
  CrossOriginOpenerPolicyHeader? get crossOriginOpenerPolicy =>
      crossOriginOpenerPolicy_();
}
