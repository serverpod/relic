import 'dart:io';

import 'package:relic_core/relic_core.dart';
import 'package:relic_native/relic_native.dart';
import 'package:test/test.dart';
import 'package:test_utils/adapter_conformance.dart';

/// The conformance tests that write raw requests, over TLS, so the bytes
/// go through tls.zig's records.
void main() {
  final tls = NativeTls.fromFiles(
    certificateChain: 'test/certs/localhost_cert.pem',
    privateKey: 'test/certs/localhost_key.pem',
  );
  final trustTestCa = SecurityContext(withTrustedRoots: false)
    ..setTrustedCertificates('test/certs/ca_cert.pem');
  final conformance = AdapterConformance(
    'NativeAdapter over TLS',
    bind:
        ({
          required InternetAddress address,
          int port = 0,
          bool v6Only = false,
          bool shared = false,
        }) =>
            () => NativeAdapter.bind(
              address,
              port: port,
              v6Only: v6Only,
              tls: tls,
            ),
    capabilities: const AdapterCapabilities(hijack: true, webSocket: true),
    connect: (port) =>
        SecureSocket.connect('localhost', port, context: trustTestCa),
  );

  group('NativeAdapter over TLS.', () {
    framingTests(conformance);
    headerWireTests(conformance);
  });
}
