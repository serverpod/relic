import 'dart:convert';
import 'dart:io';

import 'package:relic/relic.dart';
import 'package:test/test.dart';
import 'package:test_utils/test_utils.dart';

import 'headers/headers_test_utils.dart';
import 'ssl/ssl_certs.dart';
import 'util/test_util.dart';

void main() {
  group('Given a TLS server,', () {
    late SecurityContext securityContext;
    late HttpClient sslClient;
    RelicServer? server;

    setUp(() {
      securityContext = SecurityContext()
        ..setTrustedCertificatesBytes(certChainBytes)
        ..useCertificateChainBytes(certChainBytes)
        ..usePrivateKeyBytes(certKeyBytes, password: 'dartdart');

      sslClient = HttpClient(context: securityContext);
    });

    tearDown(() async {
      sslClient.close();
      await server?.close();
      server = null;
    });

    Future<HttpClientRequest> scheduleSecureGet() =>
        sslClient.getUrl(server!.url.replace(scheme: 'https'));

    test('when a sync handler is served, '
        'then the client receives its value over TLS.', () async {
      server = await testServe(syncHandler, context: securityContext);

      final req = await scheduleSecureGet();

      final response = await req.close();
      expect(response.statusCode, HttpStatus.ok);
      expect(
        await response.cast<List<int>>().transform(utf8.decoder).single,
        'Hello from /',
      );
    });

    test('when an async handler is served, '
        'then the client receives its value over TLS.', () async {
      server = await testServe(asyncHandler, context: securityContext);

      final req = await scheduleSecureGet();
      final response = await req.close();
      expect(response.statusCode, HttpStatus.ok);
      expect(
        await response.cast<List<int>>().transform(utf8.decoder).single,
        'Hello from /',
      );
    });
  });
}
