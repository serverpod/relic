import 'dart:io';

/// A class that represents an address.
abstract final class RelicAddress<T> {
  /// Returns the address as an [Object].
  T get address;

  /// Creates a [RelicAddress] from a [String].
  static RelicAddress<String> fromHostname(String hostname) {
    return _RelicHostnameAddress(hostname: hostname);
  }

  /// Creates a [RelicAddress] from an [InternetAddress].
  static RelicAddress<InternetAddress> fromInternetAddress(
    InternetAddress address,
  ) {
    return _RelicInternetAddress(internetAddress: address);
  }
}

/// A class that represents a hostname address.
final class _RelicHostnameAddress implements RelicAddress<String> {
  /// The hostname of the address.
  final String hostname;

  _RelicHostnameAddress({
    required this.hostname,
  });

  /// Returns the address as a [String].
  @override
  String get address => hostname;

  @override
  String toString() => 'RelicHostnameAddress(hostname: $hostname)';
}

/// A class that represents an internet address.
final class _RelicInternetAddress implements RelicAddress<InternetAddress> {
  /// The internet address of the address.
  final InternetAddress internetAddress;

  _RelicInternetAddress({
    required this.internetAddress,
  });

  /// Returns the address as an [InternetAddress].
  @override
  InternetAddress get address => internetAddress;

  @override
  String toString() =>
      'RelicInternetAddress(internetAddress: $internetAddress)';
}
