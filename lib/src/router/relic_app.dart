part of 'router.dart';

/// The main application class for a Relic web server.
///
/// [RelicApp] extends [RelicRouter] and provides a convenient way to create,
/// configure, and run a Relic HTTP server.
final class RelicApp extends _DelegatingRelicRouter {
  RelicServer? _server;
  final _setup = <RouterInjectable>[];

  RelicApp() : super(RelicRouter());

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
    if (_server != null) throw StateError('Cannot call run twice');
    _server = RelicServer(await adapterFactory());
    await _init();
    await _hotReloader.register(this);
    return _server!;
  }

  Future<void> _init() async {
    await _server!.mountAndStart(delegate.asHandler);
  }

  Future<void> _reload() async {
    await _rebuild();
    await _init();
  }

  Future<void> _rebuild() async {
    delegate = RelicRouter();
    for (final injectable in _setup) {
      delegate.inject(injectable);
    }
  }

  void _injectAndTrack(final RouterInjectable injectable) {
    delegate.inject(injectable);
    _setup.add(injectable);
  }

  @override
  void add(final Method method, final String path, final Handler route) =>
      _injectAndTrack(_HandlerSetup(method, path, route));

  @override
  void attach(final String path, final RelicRouter subRouter) =>
      _injectAndTrack(_AttachSetup(path, subRouter));

  @override
  void use(final String path, final Middleware map) =>
      _injectAndTrack(_UseSetup(path, map));

  @override
  void inject(final RouterInjectable injectable) => _injectAndTrack(injectable);
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
  final Middleware middleware;

  _UseSetup(this.path, this.middleware);

  @override
  void injectIn(final RelicRouter router) => router.use(path, middleware);
}

final class _DelegatingRelicRouter extends RelicRouter {
  RelicRouter delegate;

  _DelegatingRelicRouter(this.delegate);

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
