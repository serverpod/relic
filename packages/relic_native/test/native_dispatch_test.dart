import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:relic_core/relic_core.dart';
import 'package:relic_native/relic_native.dart';
import 'package:test/test.dart';
import 'package:test_utils/adapter_conformance.dart';

void main() {
  test(
    'Given a streamed response whose subscription throws from resume, '
    'when the native side has written enough of it to resume it, '
    'then the error reaches the zone and the adapter answers the next request.',
    () async {
      final adapter = await NativeAdapter.bind(InternetAddress.loopbackIPv4);
      addTearDown(() => adapter.close(force: true));
      final errors = <Object>[];
      final exchanges = StreamController<AdapterExchange>();
      runZonedGuarded(
        () => adapter.start(exchanges.add),
        (error, _) => errors.add(error),
      );
      final next = StreamIterator(exchanges.stream);
      Future<AdapterExchange> nextExchange() async {
        expect(
          await next.moveNext().timeout(const Duration(seconds: 3)),
          isTrue,
        );
        return next.current;
      }

      final port = adapter.listeners.first.port;
      final first = await Socket.connect(InternetAddress.loopbackIPv4, port);
      addTearDown(first.destroy);
      first.write('GET /a HTTP/1.1\r\nHost: localhost\r\n\r\n');
      await first.flush();
      final firstReply = first.listen(null);
      addTearDown(firstReply.cancel);
      final stalled = await nextExchange();
      // Never finishes, since its body cannot resume. The forced close at
      // the end fails it.
      Future.value(
        stalled.respond(
          Response.ok(body: Body.fromDataStream(_ResumeThrows())),
        ),
      ).ignore();

      final reply = rawExchange(
        port,
        'GET /b HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n',
        timeout: const Duration(seconds: 3),
      );
      await (await nextExchange()).respond(Response.ok());

      expect(await reply, startsWith('HTTP/1.1 200 '));
      expect(errors, isNotEmpty);
      expect(errors, everyElement(isA<StateError>()));
    },
  );

  test('Given a sink that throws on an exchange, '
      'when the next request arrives, '
      'then the adapter hands it over.', () async {
    final adapter = await NativeAdapter.bind(InternetAddress.loopbackIPv4);
    addTearDown(() => adapter.close(force: true));
    final thrown = Completer<Object>();
    final exchanges = StreamController<AdapterExchange>();
    runZonedGuarded(
      () => adapter.start((exchange) {
        if (!thrown.isCompleted) throw StateError('sink failed');
        exchanges.add(exchange);
      }),
      (error, _) {
        if (!thrown.isCompleted) thrown.complete(error);
      },
    );
    final port = adapter.listeners.first.port;
    final first = await Socket.connect(InternetAddress.loopbackIPv4, port);
    addTearDown(first.destroy);
    first.write('GET /a HTTP/1.1\r\nHost: localhost\r\n\r\n');
    await first.flush();
    expect(
      await thrown.future.timeout(const Duration(seconds: 3)),
      isA<StateError>(),
    );

    final reply = rawExchange(
      port,
      'GET /b HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n',
      timeout: const Duration(seconds: 3),
    );
    final next = StreamIterator(exchanges.stream);
    expect(await next.moveNext().timeout(const Duration(seconds: 3)), isTrue);
    await next.current.respond(Response.ok());

    expect(await reply, startsWith('HTTP/1.1 200 '));
  });
}

/// A body whose subscription throws when resumed, as a hand-written one
/// may. The adapter pauses it once it is ahead of the socket.
class _ResumeThrows extends Stream<Uint8List> {
  @override
  StreamSubscription<Uint8List> listen(
    void Function(Uint8List event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => _ResumeThrowsSubscription(
    Stream.fromIterable(List.generate(64, (_) => Uint8List(1024))).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    ),
  );
}

class _ResumeThrowsSubscription implements StreamSubscription<Uint8List> {
  _ResumeThrowsSubscription(this._inner);

  final StreamSubscription<Uint8List> _inner;

  @override
  void resume() => throw StateError('resume failed');

  @override
  void pause([Future<void>? resumeSignal]) => _inner.pause(resumeSignal);

  @override
  bool get isPaused => _inner.isPaused;

  @override
  Future<void> cancel() => _inner.cancel();

  @override
  void onData(void Function(Uint8List data)? handleData) =>
      _inner.onData(handleData);

  @override
  void onError(Function? handleError) => _inner.onError(handleError);

  @override
  void onDone(void Function()? handleDone) => _inner.onDone(handleDone);

  @override
  Future<E> asFuture<E>([E? futureValue]) => _inner.asFuture(futureValue);
}
