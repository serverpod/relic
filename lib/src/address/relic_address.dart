import 'dart:io';

/// A class that represents an address.
class RelicAddress {
  /// The hostname of the address.
  final String? hostname;

  /// The internet address of the address.
  final InternetAddress? internetAddress;

  /// The port of the address.
  final int port;

  RelicAddress._({
    this.hostname,
    this.internetAddress,
    required this.port,
  });

  /// Creates an address from a string.
  factory RelicAddress.fromString({
    required String address,
    required int port,
  }) {
    return RelicAddress._(hostname: address, port: port);
  }

  /// Creates an address from an [InternetAddress].
  factory RelicAddress.fromInternetAddress({
    required InternetAddress address,
    required int port,
  }) {
    return RelicAddress._(internetAddress: address, port: port);
  }

  /// Returns the address as an [Object].
  Object get address => hostname ?? internetAddress!;

  @override
  String toString() {
    final addr = hostname ?? internetAddress!.address;
    return '$addr:$port';
  }
}

/// An extension on [InternetAddress] to create a [RelicAddress] with a port.
extension InternetAddressExtension on InternetAddress {
  /// Creates a [RelicAddress] with a port.
  RelicAddress withPort(int port) {
    return RelicAddress.fromInternetAddress(address: this, port: port);
  }
}

/// An extension on [String] to create a [RelicAddress] with a port.
extension StringExtension on String {
  /// Creates a [RelicAddress] with a port.
  RelicAddress withPort(int port) {
    return RelicAddress.fromString(address: this, port: port);
  }
}
