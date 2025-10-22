import 'dart:async';

/// Run [callback] and capture any errors that would otherwise be top-leveled.
///
/// If `this` is called in a non-root error zone, it will just run [callback]
/// and return the result. Otherwise, it will capture any errors using
/// [runZoned] and pass them to [onError].
void catchTopLevelErrors(final void Function() callback,
    final void Function(dynamic error, StackTrace) onError) {
  if (Zone.current.inSameErrorZone(Zone.root)) {
    return runZonedGuarded(callback, onError);
  } else {
    return callback();
  }
}

/// Multiple header values are joined with commas.
/// See https://datatracker.ietf.org/doc/html/draft-ietf-httpbis-p1-messaging-21#page-22
String? joinHeaderValues(final List<String>? values) {
  if (values == null) return null;
  if (values.isEmpty) return '';
  if (values.length == 1) return values.single;
  return values.join(',');
}

extension EventSinkEx<T> on EventSink<T> {
  /// Creates a new [StreamSink<R>] that maps its incoming values of type [R]
  /// to type [T] using the provided [mapper] function, and then adds them
  /// to this sink.
  StreamSink<R> mapFrom<R>(final T Function(R) mapper) {
    final controller = StreamController<R>();
    controller.stream.map(mapper).listen(
          add,
          onError: addError,
          onDone: close,
        );
    return controller.sink;
  }
}

extension StreamEx<T> on Stream<T> {
  /// Adds a possible async subscription to this stream.
  ///
  /// The [onData] callbacks are guaranteed to be serialized even when async.
  /// Otherwise behaves as [Stream.listen]
  StreamSubscription<void> asyncListen(
    final FutureOr<void> Function(T event) onData, {
    final Function? onError,
    final void Function()? onDone,
    final bool? cancelOnError,
  }) =>
      asyncMap(onData).listen((final _) {},
          onError: onError, onDone: onDone, cancelOnError: cancelOnError);
}
