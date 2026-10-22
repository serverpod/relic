// Dispatch overhead of RelicServer with no socket in the way: an in-process
// adapter pushes exchanges through the sink and a trivial handler answers.
import 'dart:async';
import 'dart:typed_data';

import 'package:relic/relic.dart';
import 'package:stream_channel/stream_channel.dart';

/// Captures the sink so the benchmark can call it directly.
final class BenchmarkAdapter implements Adapter {
  ExchangeSink? sink;

  @override
  AdapterCapabilities get capabilities => const AdapterCapabilities();

  @override
  List<Listener> get listeners => const [
    Listener(Transport.tcp, '127.0.0.1', 1, {HttpProtocol.http11}),
  ];

  @override
  void start(final ExchangeSink sink) => this.sink = sink;

  @override
  Future<void> close({final bool force = false}) async {}

  @override
  ConnectionsInfo get connectionsInfo => (active: 0, closing: 0, idle: 0);
}

/// An exchange whose respond is synchronous, as a native adapter's is.
final class BenchmarkExchange implements AdapterExchange {
  static final _url = Uri.parse('http://localhost/path/to/resource?q=1');
  static final _headers = Headers.fromMap({
    'host': ['localhost'],
    'user-agent': ['bench/1.0'],
    'accept': ['*/*'],
  });

  Response? response;

  @override
  HttpProtocol get protocol => HttpProtocol.http11;

  @override
  Request toRequest(RequestFactory create) =>
      create(Method.get, this, url: _url, headers: _headers);

  @override
  FutureOr<void> respond(final Response response) {
    this.response = response;
    return null;
  }

  @override
  FutureOr<StreamChannel<Uint8List>> hijack() => throw UnsupportedError('');

  @override
  FutureOr<RelicWebSocket> upgradeWebSocket(final String acceptKey) =>
      throw UnsupportedError('');

  @override
  void abort() {}

  @override
  Future<void> get cancelled => Completer<void>().future;

  @override
  Future<ExchangeEnd> get done => Future.value(ExchangeEnd.completed);
}

/// Starts a server on a [BenchmarkAdapter] and returns the sink to drive.
Future<ExchangeSink> startDispatchServer(final Handler handler) async {
  final adapter = BenchmarkAdapter();
  final server = RelicServer(() => adapter);
  await server.mountAndStart(handler);
  return adapter.sink!;
}
