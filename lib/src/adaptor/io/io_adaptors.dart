import 'dart:io' as io;

import '../address_type.dart';
import '../security_options.dart';

/// Extension to convert dart:io InternetAddress to AddressType
extension InternetAddressAdaptor on io.InternetAddress {
  /// Convert to platform-agnostic AddressType
  Address toAddressType() => Address(
        address,
        isIpV6: type == io.InternetAddressType.IPv6,
      );
}

/// Extension to convert dart:io SecurityContext to SecurityOptions
extension SecurityContextAdaptor on io.SecurityContext {
  /// Convert to platform-agnostic SecurityOptions
  SecurityOptions toSecurityOptions() => SecurityOptions(this);
}

/// Extension to convert AddressType to dart:io InternetAddress
extension AddressTypeAdaptor on Address {
  /// Convert to dart:io InternetAddress
  io.InternetAddress toInternetAddress() => io.InternetAddress(address);
}

/// Extension to convert SecurityOptions to dart:io SecurityContext
extension SecurityOptionsAdaptor on SecurityOptions {
  /// Convert to dart:io SecurityContext
  io.SecurityContext toSecurityContext() => context as io.SecurityContext;
}
