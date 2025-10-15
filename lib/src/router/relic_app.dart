part of 'router.dart';

/// The main application class for a Relic web server.
///
/// [RelicApp] extends [RelicRouter] and provides a convenient way to create,
/// configure, and run a Relic HTTP server.
final class RelicApp extends _DelegatingRelicRouter {
  FutureOr<Adapter> Function()? _adapterFactory;
  final _server = _DelegatingRelicServer();
  final _setup = <_Setup>[];

  /// Creates and starts a [RelicServer] with the configured routes.
  ///
  /// The [adapterFactory] is a function that returns an [Adapter] for handling
  /// HTTP requests. This can be a synchronous function or an async function.
  /// The adapter factory pattern allows for deferred initialization of server
  /// resources.
  ///
  /// Returns a [Future] that completes with the running [RelicServer] instance.
  ///
  /// Example:
  /// ```dart
  /// final app = RelicApp()
  ///   ..get('/', (ctx) => ctx.ok('Hello!'));
  ///
  /// final server = await app.run(adapterFactory);
  /// ```
  ///
  /// Check out [RelicAppIOServeEx.serve] if you are using `dart:io` to avoid
  /// specifying [adapterFactory] explicitly.
  Future<RelicServer> run(
    final FutureOr<Adapter> Function() adapterFactory,
  ) async {
    if (_adapterFactory != null) throw StateError('Cannot call run twice');
    _adapterFactory = adapterFactory;
    await _init();
    await _hotReloader.register(this);
    return _server;
  }

  Future<void> _init() async {
    final router = RelicRouter();
    for (final s in _setup) {
      router.inject(s);
    }
    delegate = router;

    final server = RelicServer(await _adapterFactory!());
    await server.mountAndStart(call);
    _server.delegate = server;
  }

  Future<void> _reload() async {
    await _server.close();
    await _init();
  }

  @override
  void add(final Method method, final String path, final Handler route) {
    _setup.add(_HandlerSetup(method, path, route));
  }

  @override
  void attach(final String path, final Router<Handler> subRouter) {
    _setup.add(_AttachSetup(path, subRouter));
  }

  @override
  void use(final String path, final Handler Function(Handler p1) map) {
    _setup.add(_UseSetup(path, map));
  }
}

sealed class _Setup implements RouterInjectable {}

final class _HandlerSetup extends _Setup {
  final Method method;
  final String path;
  final Handler route;

  _HandlerSetup(this.method, this.path, this.route);

  @override
  void injectIn(final RelicRouter router) => router.add(method, path, route);
}

final class _AttachSetup extends _Setup {
  final String path;
  final Router<Handler> subRouter;

  _AttachSetup(this.path, this.subRouter);

  @override
  void injectIn(final RelicRouter router) => router.attach(path, subRouter);
}

final class _UseSetup extends _Setup {
  final String path;
  final Handler Function(Handler p1) map;

  _UseSetup(this.path, this.map);

  @override
  void injectIn(final RelicRouter router) => router.use(path, map);
}

class _DelegatingRelicServer implements RelicServer {
  late RelicServer delegate;
  _DelegatingRelicServer();

  @override
  Adapter get adapter => delegate.adapter;

  @override
  Future<void> close() => delegate.close();

  @override
  Future<void> mountAndStart(final Handler handler) =>
      delegate.mountAndStart(handler);
}

final class _DelegatingRelicRouter extends RelicRouter {
  late RelicRouter delegate;

  @override
  Handler? get fallback => delegate.fallback;

  @override
  set fallback(final Handler? value) => delegate.fallback = value;

  @override
  void add(final Method method, final String path, final Handler route) =>
      delegate.add(method, path, route);

  @override
  void attach(final String path, final Router<Handler> subRouter) =>
      delegate.attach(path, subRouter);

  @override
  bool get isEmpty => delegate.isEmpty;

  @override
  LookupResult<Handler> lookup(final Method method, final String path) =>
      delegate.lookup(method, path);

  @override
  void use(final String path, final Middleware map) => delegate.use(path, map);
}

class _HotReloader {
  final Future<vm.VmService?> vmService;

  _HotReloader() : vmService = _init();

  static Future<vm.VmService?> _init() async {
    final wsUri = (await Service.getInfo()).serverWebSocketUri;
    if (wsUri != null) {
      final vmService = await vmi.vmServiceConnectUri(wsUri.toString());
      await vmService.streamListen(vm.EventStreams.kIsolate);
      return vmService;
    }
    return null; // no vm service available
  }

  Future<void> register(final RelicApp app) async {
    final vms = await vmService;
    if (vms != null) {
      vms.onIsolateEvent.listen((final e) async {
        if (e.kind == 'IsolateReload') {
          await app._reload();
        }
      });
    }
  }
}

final _hotReloader = _HotReloader();
