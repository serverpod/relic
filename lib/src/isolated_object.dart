import 'dart:async';
import 'dart:isolate';

typedef Factory<T> = FutureOr<T> Function();

typedef _Action<T> = ({int id, dynamic Function(T) function});
typedef _Response = ({int id, dynamic result});
typedef _Inflight = Map<int, Completer>;
typedef _Setup = (SendPort, ReceivePort, _Inflight);

class IsolatedObject<T> {
  final Future<_Setup> _connected;

  IsolatedObject(final Factory<T> create) : _connected = _connect(create);

  static Future<_Setup> _connect<T>(
    final Factory<T> create,
  ) async {
    final parentPort = RawReceivePort();
    final setupDone = Completer<_Setup>();

    parentPort.handler = (final dynamic message) async {
      final toChild = message as SendPort;
      final fromChild = ReceivePort.fromRawReceivePort(parentPort);
      final inflight = _Inflight();
      setupDone.complete((toChild, fromChild, inflight));
    };

    try {
      await _spawn(create, parentPort.sendPort);
    } catch (_) {
      parentPort.close();
    }

    final result = await setupDone.future;
    final (_, fromChild, inflight) = result;

    fromChild.listen((final message) {
      if (message case final _Response response) {
        final completer = inflight.remove(response.id);
        assert(completer != null, 'PROTOCOL BUG. No such ID ${response.id}');
        if (completer == null) return; // late/duplicate message, ignore
        switch (response.result) {
          case final RemoteError e:
            completer.completeError(e);
          default:
            completer.complete(response.result);
        }
      }
    });

    return result;
  }

  static Future<Isolate> _spawn<T>(
    final Factory<T> create,
    final SendPort toParent,
  ) {
    return Isolate.spawn((final toParent) async {
      final childPort = ReceivePort();
      toParent.send(childPort.sendPort); // complete handshake

      final isolatedObject = await create();

      // process inbound actions
      await for (final message in childPort) {
        if (message == null) {
          // shutdown signal recieved
          childPort.close();
          break;
        } else if (message case final _Action<T> action) {
          try {
            final result = await action.function(isolatedObject);
            toParent.send((id: action.id, result: result)); // return result
          } catch (e, st) {
            toParent.send((id: action.id, result: RemoteError('$e', '$st')));
          }
        }
      }
    }, toParent);
  }

  int _nextId = 0;
  Future<U> evaluate<U>(final U Function(T) function) async {
    final (toChild, _, inflight) = await _connected;

    final id = _nextId++;
    final completer = Completer<U>();
    inflight[id] = completer;

    toChild.send((id: id, function: function));
    return await completer.future;
  }

  @pragma('vm:prefer-inline')
  Future<void> evaluateVoid(final void Function(T) function) async {
    await evaluate<dynamic>(function);
  }

  Future<void> close() async {
    final (toChild, fromChild, _) = await _connected;
    toChild.send(null); // shutdown signal
    fromChild.close();
  }
}
