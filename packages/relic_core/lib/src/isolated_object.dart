import 'dart:async';
import 'dart:isolate';

import 'util/util.dart';

typedef Factory<T> = FutureOr<T> Function();

typedef _Action<T> = ({int id, dynamic Function(T) function});
typedef _Response = ({int id, dynamic result});
typedef _Inflight = Map<int, Completer>;
typedef _Setup = (SendPort, ReceivePort, _Inflight);

class IsolatedObject<T> {
  final Future<_Setup> _connected;

  IsolatedObject(final Factory<T> create) : _connected = _connect(create);

  static Future<_Setup> _connect<T>(final Factory<T> create) async {
    final parentPort = RawReceivePort();
    final setupDone = Completer<_Setup>();

    parentPort.handler = (final dynamic message) async {
      if (message case final RemoteError e) {
        setupDone.completeError(e, e.stackTrace);
      } else {
        final toChild = message as SendPort;
        final fromChild = ReceivePort.fromRawReceivePort(parentPort);
        final inflight = _Inflight();
        setupDone.complete((toChild, fromChild, inflight));
      }
    };

    try {
      await _spawn(create, parentPort.sendPort);
    } catch (_) {
      parentPort.close();
      rethrow;
    }

    final result = await setupDone.future;
    final (toChild, fromChild, inflight) = result;

    fromChild.asyncListen(
      (final message) async {
        if (message case final _Response response) {
          final completer = inflight.remove(response.id);
          assert(completer != null, 'PROTOCOL BUG. No such ID ${response.id}');
          if (completer == null) return; // coverage: ignore-line
          switch (response.result) {
            case final RemoteError e:
              completer.completeError(e, e.stackTrace);
            default:
              completer.complete(await response.result);
          }
        }
      },
      onDone: () {
        // ReceivePort closed. Fail any pending requests to avoid hangs.
        for (final c in inflight.values) {
          if (!c.isCompleted) {
            c.completeError(StateError('IsolatedObject<$T> channel closed'));
          }
        }
        inflight.clear();
      },
    );

    return result;
  }

  static Future<Isolate> _spawn<T>(
    final Factory<T> create,
    final SendPort toParent,
  ) {
    return Isolate.spawn((final toParent) async {
      final childPort = ReceivePort();
      final T isolatedObject;
      try {
        isolatedObject = await create();
        toParent.send(childPort.sendPort); // complete handshake
      } catch (e, st) {
        toParent.send(RemoteError('$e', '$st'));
        return;
      }

      // process inbound actions
      await for (final message in childPort) {
        if (message == null) {
          // shutdown signal received
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
  Future<U> evaluate<U>(final FutureOr<U> Function(T) function) async {
    final (toChild, _, inflight) = await _connected;

    final id = _nextId++;
    final completer = Completer<U>();
    inflight[id] = completer;

    toChild.send((id: id, function: function));
    return await completer.future;
  }

  Future<void> close() async {
    final (toChild, fromChild, _) = await _connected;
    toChild.send(null); // shutdown signal
    fromChild.close();
  }
}
