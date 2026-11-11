// doctag<testing-in-process-server>
import 'dart:async';

import 'package:relic/relic.dart';
import 'package:test/fake.dart';

/// An adapter with no sockets. [handle] pushes each request straight into
/// the server.
final class InProcessAdapter extends Fake implements Adapter {
  late ExchangeSink _sink;

  @override
  AdapterCapabilities get capabilities => const AdapterCapabilities();

  @override
  List<Listener> get listeners => const [];

  @override
  void start(ExchangeSink sink) => _sink = sink;

  @override
  Future<void> close({bool force = false}) async {}
}

/// One request, and the response the server answers it with.
final class InProcessExchange extends Fake implements AdapterExchange {
  final Method method;
  final Uri url;
  final Headers headers;
  final Body body;

  final _response = Completer<Response>();
  final _done = Completer<ExchangeEnd>();
  final _cancelled = Completer<void>();

  InProcessExchange(this.method, this.url, {Headers? headers, Body? body})
    : headers = headers ?? Headers.empty(),
      body = body ?? Body.empty();

  /// The response the server sent.
  Future<Response> get response => _response.future;

  @override
  HttpProtocol get protocol => HttpProtocol.http11;

  @override
  Request toRequest(RequestFactory create) =>
      create(method, this, url: url, headers: headers, body: body);

  @override
  FutureOr<void> respond(Response response) {
    _response.complete(response);
    _done.complete(ExchangeEnd.completed);
  }

  @override
  void abort() {
    _response.completeError(StateError('The server aborted the exchange'));
    _done.complete(ExchangeEnd.aborted);
  }

  @override
  Future<void> get cancelled => _cancelled.future;

  @override
  Future<ExchangeEnd> get done => _done.future;
}

/// Runs [handler] in a [RelicServer] and answers one request with it.
Future<Response> handle(
  Handler handler,
  Method method,
  Uri url, {
  Headers? headers,
  Body? body,
}) async {
  final adapter = InProcessAdapter();
  final server = RelicServer(() => adapter);
  await server.mountAndStart(handler);
  try {
    final exchange = InProcessExchange(
      method,
      url,
      headers: headers,
      body: body,
    );
    await adapter._sink(exchange);
    return await exchange.response;
  } finally {
    await server.close();
  }
}

/// The [Request] the server builds for a request, for code that takes a
/// [Request] directly.
Future<Request> requestFor(Method method, Uri url, {Headers? headers}) async {
  late Request captured;
  await handle(
    (req) {
      captured = req;
      return Response.ok();
    },
    method,
    url,
    headers: headers,
  );
  return captured;
}

// end:doctag<testing-in-process-server>
