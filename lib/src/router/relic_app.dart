part of 'router.dart';

/// The main application class for a Relic web server.
///
/// [RelicApp] extends [RelicRouter] and provides a convenient way to create,
/// configure, and run a Relic HTTP server.
final class RelicApp implements RelicRouter {
  RelicServer? _server;
  StreamSubscription? _reloadSubscription;
  var delegate = RelicRouter();
  final _setup = <RouterInjectable>[];

  RelicApp();

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
    _reloadSubscription = await _hotReloader.register(this);
    return _server!;
  }

  Future<void> close() async {
    await _reloadSubscription?.cancel();
    await _server?.close();
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

  @override
  Handler? get fallback => delegate.fallback;

  @override
  set fallback(final Handler? value) => _injectAndTrack(_FallbackSetup(value));

  @override
  PathTrie<_RouterEntry<Handler>> get _allRoutes => delegate._allRoutes;

  @override
  bool get isEmpty => delegate.isEmpty;

  @override
  LookupResult<Handler> lookup(final Method method, final String path) =>
      delegate.lookup(method, path);
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

final class _FallbackSetup extends _Setup {
  final Handler? fallback;

  _FallbackSetup(this.fallback);

  @override
  void injectIn(final RelicRouter router) => router.fallback = fallback;
}

class _HotReloader {
  static final Future<Stream<void>?> _reloadStream = _init();

  static Future<Stream<void>?> _init() async {
    final wsUri = (await Service.getInfo()).serverWebSocketUri;
    if (wsUri != null) {
      final vmService = await vmi.vmServiceConnectUri(wsUri.toString());
      const streamId = vm.EventStreams.kIsolate;
      return vmService.onIsolateEvent
          .asBroadcastStream(
              onListen: (final _) => vmService.streamListen(streamId),
              onCancel: (final _) => vmService.streamCancel(streamId))
          .where((final e) => e.kind == 'IsolateReload');
    }
    return null; // no vm service available
  }

  Future<StreamSubscription?> register(final RelicApp app) async {
    final reloadStream = await _reloadStream;
    if (reloadStream != null) {
      return reloadStream
          .asyncMap((final _) => app._reload())
          .listen((final _) {});
    }
    return null;
  }
}

final _hotReloader = _HotReloader();
