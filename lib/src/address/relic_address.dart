import 'dart:io';

/// A class that represents an address.
abstract class RelicAddress<T> {
  /// Returns the address as an [Object].
  T get address;
}

/// A class that represents a hostname address.
class RelicHostnameAddress implements RelicAddress<String> {
  /// The hostname of the address.
  final String hostname;

  RelicHostnameAddress({
    required this.hostname,
  });

  /// Returns the address as a [String].
  @override
  String get address => hostname;

  @override
  String toString() => 'RelicHostnameAddress(hostname: $hostname)';
}

/// A class that represents an internet address.
class RelicInternetAddress implements RelicAddress<InternetAddress> {
  /// The internet address of the address.
  final InternetAddress internetAddress;

  RelicInternetAddress({
    required this.internetAddress,
  });

  /// Returns the address as an [InternetAddress].
  @override
  InternetAddress get address => internetAddress;

  @override
  String toString() =>
      'RelicInternetAddress(internetAddress: $internetAddress)';
}
