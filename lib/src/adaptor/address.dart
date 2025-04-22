/// Platform-agnostic address type for server binding
class Address {
  /// The string representation of the address
  final String address; // TODO: Using string here rubs me the wrong way.

  /// Whether this is an IPv6 address
  final bool isIpV6;

  /// Create an address type with the specified address string
  const Address(this.address, {this.isIpV6 = false});

  /// Whether this is a loopback address
  bool get isLoopback => isIpV6 ? address == '::1' : address == '127.0.0.1';

  /// Convenience constructor for any address
  ///
  /// IPv4: 0.0.0.0
  /// IPv6: ::
  factory Address.any({final bool isIpV6 = false}) =>
      Address(isIpV6 ? '::' : '0.0.0.0', isIpV6: isIpV6);

  /// Convenience constructor for localhost
  ///
  /// IPv4: 127.0.0.1
  /// IPv6: ::1
  factory Address.loopback({final bool isIpV6 = false}) =>
      Address(isIpV6 ? '::1' : '127.0.0.1', isIpV6: isIpV6);
}
