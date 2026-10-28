/// The adapter conformance suite.
///
/// Every behaviour an [Adapter] owes the core, exercised over real sockets
/// against whichever adapter the caller binds. Run it from the adapter's
/// own package:
///
/// ```dart
/// void main() {
///   adapterConformance(
///     'IOAdapter',
///     bind: ({shared = false}) =>
///         () => IOAdapter.bind(InternetAddress.loopbackIPv4, shared: shared),
///     capabilities: const AdapterCapabilities(hijack: true, webSocket: true),
///   );
/// }
/// ```
library;

import 'package:relic_core/relic_core.dart';
import 'package:test/test.dart';

import 'src/conformance/cancel_tests.dart';
import 'src/conformance/close_from_handler_tests.dart';
import 'src/conformance/conformance.dart';
import 'src/conformance/connections_tests.dart';
import 'src/conformance/exchange_abort_tests.dart';
import 'src/conformance/framing_tests.dart';
import 'src/conformance/header_wire_tests.dart';
import 'src/conformance/hijack_tests.dart';
import 'src/conformance/request_body_tests.dart';
import 'src/conformance/response_failure_tests.dart';
import 'src/conformance/serve_tests.dart';
import 'src/conformance/server_tests.dart';
import 'src/conformance/shutdown_tests.dart';
import 'src/conformance/streaming_tests.dart';
import 'src/conformance/web_socket_origin_tests.dart';
import 'src/conformance/web_socket_tests.dart';

export 'src/conformance/conformance.dart';
export 'src/conformance/framing_tests.dart';

/// Declares the whole suite for one adapter.
///
/// [bind] returns a fresh adapter factory each time it is called. `shared`
/// is true when several isolates will call the factory for one server.
/// [connect] opens a raw client connection, see [AdapterConformance].
/// The three flags name what a transport may be unable to do, see
/// [AdapterConformance]. The suite skips the tests that need it, with the
/// reason.
void adapterConformance(
  String name, {
  required AdapterFactoryBuilder bind,
  required AdapterCapabilities capabilities,
  SocketConnector connect = plainConnect,
  bool seesPeerGone = true,
  bool failsRespondMidStream = true,
  bool keepsPipelinedBytes = true,
}) {
  final conformance = AdapterConformance(
    name,
    bind: bind,
    capabilities: capabilities,
    connect: connect,
    seesPeerGone: seesPeerGone,
    failsRespondMidStream: failsRespondMidStream,
    keepsPipelinedBytes: keepsPipelinedBytes,
  );
  group(name, () {
    serverTests(conformance);
    serveTests(conformance);
    framingTests(conformance);
    headerWireTests(conformance);
    requestBodyTests(conformance);
    streamingTests(conformance);
    cancelTests(conformance);
    shutdownTests(conformance);
    closeFromHandlerTests(conformance);
    connectionsTests(conformance);
    responseFailureTests(conformance);
    exchangeAbortTests(conformance);
    hijackTests(conformance);
    webSocketTests(conformance);
    webSocketOriginTests(conformance);
  });
}
