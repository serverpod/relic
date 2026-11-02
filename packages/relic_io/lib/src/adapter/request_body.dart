import 'dart:async';
import 'dart:io' as io;
import 'dart:typed_data';

/// The body of a dart:io request, which its reader may stop reading before
/// the end.
///
/// dart:io ends the connection at once when its request stream is
/// cancelled, so a peer still sending gets a reset in place of the
/// response. And before it writes the head of a response, it drains a
/// request stream nobody listened to, for as long as the peer sends. Here
/// a reader that cancels only pauses the request, [hold] takes it before
/// the response, and [discardRest] reads what is left after.
final class IORequestBody {
  final io.HttpRequest _request;
  final _reader = StreamController<Uint8List>();
  StreamSubscription<Uint8List>? _held;
  var _ended = false;
  var _failed = false;
  Completer<bool>? _discarded;

  IORequestBody._(this._request) {
    _reader
      ..onListen = (() => _source.resume())
      ..onPause = (() => _source.pause())
      ..onResume = (() => _source.resume())
      ..onCancel = (() => _source.pause());
  }

  /// The body of [request], or null when it declares no length and is not
  /// chunked.
  static IORequestBody? of(io.HttpRequest request) =>
      request.contentLength < 0 && !request.headers.chunkedTransferEncoding
      ? null
      : IORequestBody._(request);

  /// The body for the handler to read, once.
  Stream<Uint8List> get stream => _reader.stream;

  /// dart:io's stream, listened to and paused the first time.
  ///
  /// Not before it is needed: a hijack takes the bytes of an unread body
  /// with the socket, which dart:io's parser keeps only while nobody
  /// listens.
  StreamSubscription<Uint8List> get _source =>
      _held ??= _request.listen(_reader.add, onError: _onError, onDone: _onDone)
        ..pause();

  /// Takes dart:io's stream before the head of the response goes out, so
  /// dart:io does not drain it first.
  void hold() => _source;

  /// Reads what is left of the body, and completes with whether it got to
  /// the end. It gives up after [total], or when no bytes came for [idle].
  ///
  /// A reader that still listens gets the rest. Otherwise it is dropped,
  /// and a reader that comes later gets a [StateError].
  Future<bool> discardRest({required Duration idle, required Duration total}) {
    if (_ended || _failed) return Future.value(_ended);
    final discarded = _discarded = Completer<bool>();
    var heard = true;
    final idleCheck = Timer.periodic(idle, (_) {
      if (!heard) _settle(false);
      heard = false;
    });
    final deadline = Timer(total, () => _settle(false));
    if (_reader.hasListener) {
      _source.onData((chunk) {
        heard = true;
        _reader.add(chunk);
      });
    } else {
      _reader
        ..addError(StateError('The request body was dropped after a response'))
        ..close().ignore();
      _source.onData((_) => heard = true);
      while (_source.isPaused) {
        _source.resume();
      }
    }
    return discarded.future.whenComplete(() {
      idleCheck.cancel();
      deadline.cancel();
    });
  }

  void _settle(bool ended) {
    final discarded = _discarded;
    if (discarded == null || discarded.isCompleted) return;
    if (!ended) _source.pause();
    discarded.complete(ended);
  }

  void _onError(Object error, StackTrace stackTrace) {
    _failed = true;
    _settle(false);
    if (!_reader.isClosed) _reader.addError(error, stackTrace);
  }

  void _onDone() {
    _ended = !_failed;
    _settle(_ended);
    _reader.close().ignore();
  }
}
