import 'dart:async';
import 'dart:typed_data';

import 'package:relic_core/relic_core.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/fake.dart';
import 'package:test/test.dart';
import 'package:test_utils/test_utils.dart';

/// An in-process adapter.
///
/// Hands the sink to the test, so a test can push an exchange and inspect
/// what came back with no socket in between.
final class _FakeAdapter implements Adapter {
  ExchangeSink? sink;
  var closed = false;

  @override
  AdapterCapabilities get capabilities =>
      const AdapterCapabilities(hijack: true, webSocket: true);

  @override
  List<Listener> get listeners => const [
    Listener(Transport.tcp, '127.0.0.1', 1, {HttpProtocol.http11}),
  ];

  @override
  void start(ExchangeSink sink) => this.sink = sink;

  @override
  Future<void> close({bool force = false}) async => closed = true;

  @override
  ConnectionsInfo get connectionsInfo => (active: 0, closing: 0, idle: 0);
}

/// What the fake exchange should do when the core calls back into it.
enum _Respond { sync, async, throwSync, failAsync }

final class _FakeExchange implements AdapterExchange {
  final _Respond respondMode;
  final Uri url;
  final Headers headers;
  final bool toRequestThrows;

  final responses = <Response>[];
  var aborted = false;
  var hijacked = false;
  var upgraded = false;
  final _done = Completer<ExchangeEnd>();

  _FakeExchange({
    this.respondMode = _Respond.sync,
    Uri? url,
    Headers? headers,
    this.toRequestThrows = false,
  }) : url = url ?? localhostUri,
       headers = headers ?? Headers.empty();

  @override
  HttpProtocol get protocol => HttpProtocol.http11;

  @override
  Request toRequest() {
    if (toRequestThrows) throw const FormatException('bad target');
    return RequestInternal.create(Method.get, url, Object(), headers: headers);
  }

  @override
  FutureOr<void> respond(Response response) {
    responses.add(response);
    switch (respondMode) {
      case _Respond.sync:
        _finish(ExchangeEnd.completed);
        return null;
      case _Respond.async:
        return Future<void>.delayed(Duration.zero, () {
          _finish(ExchangeEnd.completed);
        });
      case _Respond.throwSync:
        throw StateError('transport gone');
      case _Respond.failAsync:
        return Future<void>.error(StateError('transport gone'));
    }
  }

  @override
  FutureOr<StreamChannel<Uint8List>> hijack() {
    hijacked = true;
    _finish(ExchangeEnd.hijacked);
    final controller = StreamController<Uint8List>();
    return StreamChannel(controller.stream, controller.sink);
  }

  @override
  FutureOr<RelicWebSocket> upgradeWebSocket() {
    upgraded = true;
    _finish(ExchangeEnd.upgraded);
    return _FakeWebSocket();
  }

  @override
  void abort() {
    aborted = true;
    _finish(ExchangeEnd.aborted);
  }

  @override
  Future<void> get cancelled => Completer<void>().future;

  @override
  Future<ExchangeEnd> get done => _done.future;

  void _finish(ExchangeEnd end) {
    if (!_done.isCompleted) _done.complete(end);
  }
}

final class _FakeWebSocket extends Fake implements RelicWebSocket {}

Future<(RelicServer, _FakeAdapter)> _serve(Handler handler) async {
  final adapter = _FakeAdapter();
  final server = RelicServer(() => adapter);
  await server.mountAndStart(handler);
  return (server, adapter);
}

/// Pushes [exchange] through the sink and waits for whatever the core
/// returned, so async paths have settled when the test inspects the fake.
Future<void> _push(_FakeAdapter adapter, _FakeExchange exchange) {
  final pending = adapter.sink!(exchange);
  return pending is Future<void> ? pending : Future.value();
}

Response _ok() => Response.ok(body: Body.fromString('ok'));

void main() {
  test(
    'Given a sync handler and a sync respond, '
    'when an exchange is pushed, '
    'then the response is sent before the sink returns and no Future is made',
    () async {
      final (_, adapter) = await _serve((_) => _ok());
      final exchange = _FakeExchange();

      final result = adapter.sink!(exchange);

      expect(
        result,
        isNull,
        reason: 'the sync path must not allocate a Future',
      );
      expect(exchange.responses.single.statusCode, 200);
    },
  );

  test('Given an async handler, '
      'when an exchange is pushed, '
      'then the response is sent once the handler completes', () async {
    final (_, adapter) = await _serve((_) async => _ok());
    final exchange = _FakeExchange();

    await _push(adapter, exchange);

    expect(exchange.responses.single.statusCode, 200);
    expect(await exchange.done, ExchangeEnd.completed);
  });

  test('Given a handler that throws synchronously, '
      'when an exchange is pushed, '
      'then a 500 is sent', () async {
    final (_, adapter) = await _serve((_) => throw StateError('oh no'));
    final exchange = _FakeExchange();

    await _push(adapter, exchange);

    expect(exchange.responses.single.statusCode, 500);
    expect(exchange.aborted, isFalse);
  });

  test('Given a handler that returns a failed Future, '
      'when an exchange is pushed, '
      'then a 500 is sent', () async {
    final (_, adapter) = await _serve(
      (_) => Future<Result>.error(StateError('oh no')),
    );
    final exchange = _FakeExchange();

    await _push(adapter, exchange);

    expect(exchange.responses.single.statusCode, 500);
  });

  test('Given an exchange whose request cannot be read, '
      'when it is pushed, '
      'then a 400 is sent and the handler never runs', () async {
    var handled = false;
    final (_, adapter) = await _serve((_) {
      handled = true;
      return _ok();
    });
    final exchange = _FakeExchange(toRequestThrows: true);

    await _push(adapter, exchange);

    expect(exchange.responses.single.statusCode, 400);
    expect(handled, isFalse);
  });

  const mapped = <(String, Object, int)>[
    (
      'an InvalidHeaderException',
      InvalidHeaderException('bad', headerType: 'x-test'),
      400,
    ),
    (
      'a MissingHeaderException',
      MissingHeaderException('', headerType: 'x'),
      400,
    ),
    ('a MalformedFormDataException', MalformedFormDataException('bad'), 400),
    ('a MissingFormFieldException', MissingFormFieldException('name'), 400),
    (
      'a FormLimitExceededException',
      FormLimitExceededException(limit: FormLimit.maxBodySize, message: 'big'),
      413,
    ),
  ];

  for (final (name, error, status) in mapped) {
    test('Given a sync handler that throws $name, '
        'when an exchange is pushed, '
        'then the mapped $status is sent', () async {
      final (_, adapter) = await _serve((_) => throw error);
      final exchange = _FakeExchange();

      await _push(adapter, exchange);

      expect(exchange.responses.single.statusCode, status);
    });

    test('Given an async handler that throws $name, '
        'when an exchange is pushed, '
        'then the mapped $status is sent', () async {
      final (_, adapter) = await _serve((_) async => throw error);
      final exchange = _FakeExchange();

      await _push(adapter, exchange);

      expect(exchange.responses.single.statusCode, status);
    });
  }

  test('Given a handler that throws MaxBodySizeExceeded, '
      'when an exchange is pushed, '
      'then a 413 is sent', () async {
    final (_, adapter) = await _serve((_) => throw MaxBodySizeExceeded(1));
    final exchange = _FakeExchange();

    await _push(adapter, exchange);

    expect(exchange.responses.single.statusCode, 413);
  });

  test('Given a handler that throws a form parse exception, '
      'when an exchange is pushed, '
      'then the response asks to close the connection', () async {
    final (_, adapter) = await _serve(
      (_) => throw const MalformedFormDataException('bad'),
    );
    final exchange = _FakeExchange();

    await _push(adapter, exchange);

    expect(exchange.responses.single.headers.connection?.isClose, isTrue);
  });

  test('Given an exchange whose respond throws synchronously, '
      'when a handler responds, '
      'then the exchange is aborted and the sink does not throw', () async {
    final (_, adapter) = await _serve((_) => _ok());
    final exchange = _FakeExchange(respondMode: _Respond.throwSync);

    await _push(adapter, exchange);

    expect(exchange.aborted, isTrue);
  });

  test('Given an exchange whose respond returns a failed Future, '
      'when a handler responds, '
      'then the exchange is aborted and the sink does not fail', () async {
    final (_, adapter) = await _serve((_) => _ok());
    final exchange = _FakeExchange(respondMode: _Respond.failAsync);

    await _push(adapter, exchange);

    expect(exchange.aborted, isTrue);
  });

  test('Given an exchange whose respond always fails, '
      'when the handler throws, '
      'then the 500 is attempted and the exchange is aborted', () async {
    final (_, adapter) = await _serve((_) => throw StateError('oh no'));
    final exchange = _FakeExchange(respondMode: _Respond.failAsync);

    await _push(adapter, exchange);

    expect(exchange.responses.single.statusCode, 500);
    expect(exchange.aborted, isTrue);
  });

  test('Given a closed server, '
      'when an exchange is still pushed, '
      'then it is aborted without a response', () async {
    final (server, adapter) = await _serve((_) => _ok());
    await server.close();
    final exchange = _FakeExchange();

    await _push(adapter, exchange);

    expect(exchange.aborted, isTrue);
    expect(exchange.responses, isEmpty);
  });

  test('Given a handler that hijacks, '
      'when an exchange is pushed, '
      'then the callback receives the channel in the same call', () async {
    StreamChannel<Uint8List>? channel;
    final (_, adapter) = await _serve((_) => Hijack((c) => channel = c));
    final exchange = _FakeExchange();

    final result = adapter.sink!(exchange);

    expect(result, isNull);
    expect(channel, isNotNull);
    expect(exchange.hijacked, isTrue);
  });

  test('Given a handler that upgrades to WebSocket, '
      'when a same-origin exchange is pushed, '
      'then the adapter performs the upgrade', () async {
    RelicWebSocket? socket;
    final (_, adapter) = await _serve(
      (_) => WebSocketUpgrade((ws) => socket = ws),
    );
    final exchange = _FakeExchange(
      url: Uri.parse('http://example.com/ws'),
      headers: Headers.build((mh) => mh['origin'] = ['http://example.com']),
    );

    await _push(adapter, exchange);

    expect(exchange.upgraded, isTrue);
    expect(socket, isNotNull);
  });

  test('Given a handler that upgrades to WebSocket, '
      'when a cross-origin exchange is pushed, '
      'then a 403 is sent and no upgrade happens', () async {
    final (_, adapter) = await _serve((_) => WebSocketUpgrade((_) {}));
    final exchange = _FakeExchange(
      url: Uri.parse('http://example.com/ws'),
      headers: Headers.build((mh) => mh['origin'] = ['http://evil.com']),
    );

    await _push(adapter, exchange);

    expect(exchange.upgraded, isFalse);
    expect(exchange.responses.single.statusCode, 403);
  });

  test('Given a mounted server, '
      'when a second handler is mounted, '
      'then the adapter is started once and the new handler serves', () async {
    final (server, adapter) = await _serve((_) => Response.notFound());
    final firstSink = adapter.sink;
    await server.mountAndStart((_) => _ok());
    final exchange = _FakeExchange();

    await _push(adapter, exchange);

    expect(adapter.sink, same(firstSink));
    expect(exchange.responses.single.statusCode, 200);
  });
}
