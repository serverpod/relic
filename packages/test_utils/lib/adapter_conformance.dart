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
///     bind: ({required address, port = 0, v6Only = false, shared = false}) =>
///         () => IOAdapter.bind(
///           address, port: port, v6Only: v6Only, shared: shared,
///         ),
///     capabilities: const AdapterCapabilities(hijack: true, webSocket: true),
///   );
/// }
/// ```
library;

import 'package:http/http.dart' as http;
import 'package:relic_core/relic_core.dart';
import 'package:test/test.dart';

import 'src/conformance/address_tests.dart';
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
export 'src/conformance/header_wire_tests.dart';
export 'src/conformance/request_body_tests.dart';

/// Declares the whole suite for one adapter.
///
/// [bind] returns a fresh adapter factory each time it is called. `address`
/// and `port` are where to listen, `v6Only` keeps an IPv6 listener from
/// taking IPv4 clients, and `shared` is true when several isolates will
/// call the factory for one server.
/// [connect], [scheme] and [newClient] say how a client reaches a server,
/// see [AdapterConformance].
/// The three flags name what a transport may be unable to do, see
/// [AdapterConformance]. The suite skips the tests that need it, with the
/// reason.
void adapterConformance(
  String name, {
  required AdapterFactoryBuilder bind,
  required AdapterCapabilities capabilities,
  SocketConnector connect = plainConnect,
  String scheme = 'http',
  http.Client Function() newClient = http.Client.new,
  bool seesPeerGone = true,
  bool failsRespondMidStream = true,
  bool keepsPipelinedBytes = true,
}) {
  final conformance = AdapterConformance(
    name,
    bind: bind,
    capabilities: capabilities,
    connect: connect,
    scheme: scheme,
    newClient: newClient,
    seesPeerGone: seesPeerGone,
    failsRespondMidStream: failsRespondMidStream,
    keepsPipelinedBytes: keepsPipelinedBytes,
  );
  group(name, () {
    serverTests(conformance);
    serveTests(conformance);
    addressTests(conformance);
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
