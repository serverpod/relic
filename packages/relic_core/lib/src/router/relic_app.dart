part of 'router.dart';

/// The main application class for a Relic web server.
///
/// [RelicApp] extends [RelicRouter] and provides a convenient way to create,
/// configure, and run a Relic HTTP server.
///
/// ## Virtual Host Routing
///
/// When [useHostWhenRouting] is `true`, the router prepends the request's
/// `Host` header to the path during route lookup. This enables virtual host
/// routing where different hosts can have different route handlers.
///
/// Routes should be registered with the host as the first path segment:
/// ```dart
/// final app = RelicApp(useHostWhenRouting: true)
///   ..get('api.example.com/users', apiUsersHandler)
///   ..get('www.example.com/about', aboutHandler)
///   ..get('*/health', healthHandler);  // Matches any host
/// ```
///
/// When `useHostWhenRouting` is `false` (the default), routing works as normal
/// using only the request path.
///
/// ## Hot Reload Support
///
/// When running with `--enable-vm-service`, [RelicApp] automatically listens for
/// hot-reload requests. When a hot reload is triggered, it will re-configure
/// the internal router with the latest route definitions.
///
/// This allows you to modify your route handlers and see the changes immediately
/// without restarting the server. Note that this only works for changes to the
/// route configuration and handlers - changes to server state or global variables
/// may require a full restart.
final class RelicApp implements RelicRouter {
  /// Whether to prepend the request's `Host` header to the path during routing.
  ///
  /// When `true`, routes should include the host as the first segment
  /// (e.g., `'api.example.com/users'`). Use `'*'` as the host segment to match
  /// any host (e.g., `'*/health'`).
  final bool useHostWhenRouting;

  RelicServer? _server;
  bool _backtrack = true;
  StreamSubscription? _reloadSubscription;
  var delegate = RelicRouter();
  final _setup = <RouterInjectable>[];

  /// Creates a new [RelicApp].
  ///
  /// Set [useHostWhenRouting] to `true` to enable virtual host routing.
  RelicApp({this.useHostWhenRouting = false});

  /// Creates and starts a [RelicServer] with the configured routes.
  ///
  /// The [adapterFactory] is a function that returns an [Adapter] for handling
  /// HTTP requests. This can be a synchronous function or an async function.
  /// The adapter factory pattern allows for deferred initialization of server
  /// resources.
  ///
  /// If [noOfIsolates] equals 1, the server is started on the current isolate.
  /// Otherwise [noOfIsolates] isolates are spun up. When using multiple isolates make
  /// sure that any handler and middleware configured are sendable.
  /// (see https://api.dart.dev/stable/dart-isolate/SendPort/send.html).
  ///
  /// Returns a [Future] that completes with the running [RelicServer] instance.
  ///
  /// [RelicApp] instances supports hot-reload. They will re-configure the internal
  /// router on hot-reload. This allows adding and removing routes despite `main`
  /// not being re-run.
  ///
  /// Example:
  /// ```dart
  /// final app = RelicApp()
  ///   ..get('/', (req) => req.ok('Hello!'));
  ///
  /// final adapterFactory = () => IOAdapter.bind(InternetAddress.loopbackIPv4, port: 8080);
  /// final server = await app.run(adapterFactory);
  ///
  /// // later .. when done
  ///
  /// await app.close();
  /// ```
  ///
  /// Check out [RelicAppIOServeEx.serve] if you are using `dart:io` to avoid
  /// specifying [adapterFactory] explicitly.
  Future<RelicServer> run(
    final FutureOr<Adapter> Function() adapterFactory, {
    final int noOfIsolates = 1,
    final bool backtrack = true,
  }) async {
    if (_server != null) throw StateError('Cannot call run twice');
    _server = RelicServer(adapterFactory, noOfIsolates: noOfIsolates);
    _backtrack = backtrack;
    await _init();
    _reloadSubscription = await _hotReloader.register(this);
    return _server!;
  }

  Future<void> close() async {
    await _reloadSubscription?.cancel();
    _reloadSubscription = null;
    await _server?.close();
    _server = null;
  }

  Future<void> _init() async {
    await _server!.mountAndStart(
      _RouterHandlerObject(
        delegate,
        backtrack: _backtrack,
        useHostWhenRouting: useHostWhenRouting,
      ).call,
    );
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
      inject(_Injectable((final r) => r.add(method, path, route)));

  @override
  void attach(
    final String path,
    final RelicRouter subRouter, {
    final bool consume = false,
  }) => inject(
    _Injectable((final r) => r.attach(path, subRouter, consume: consume)),
  );

  @override
  void use(final String path, final Middleware map) =>
      inject(_Injectable((final r) => r.use(path, map)));

  @override
  void inject(final RouterInjectable injectable) => _injectAndTrack(injectable);

  @override
  Handler? get fallback => delegate.fallback;

  @override
  set fallback(final Handler? value) =>
      inject(_Injectable((final r) => r.fallback = value));

  @override
  PathTrie<_RouterEntry<Handler>> get _allRoutes => delegate._allRoutes;

  @override
  bool get isEmpty => delegate.isEmpty;

  @override
  bool get isSingle => delegate.isSingle;

  @override
  LookupResult<Handler> lookup(
    final Method method,
    final String path, {
    final bool backtrack = true,
  }) => delegate.lookup(method, path, backtrack: backtrack);
}

final class _Injectable implements RouterInjectable {
  final void Function(RelicRouter) setup;

  _Injectable(this.setup);

  @override
  void injectIn(final RelicRouter owner) => setup(owner);
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
            onListen: (_) => vmService.streamListen(streamId),
            onCancel: (_) => vmService.streamCancel(streamId),
          )
          .where((final e) => e.kind == vm.EventKind.kIsolateReload);
    }
    return null; // no vm service available
  }

  Future<StreamSubscription?> register(final RelicApp app) async {
    final reloadStream = await _reloadStream;
    if (reloadStream != null) {
      return reloadStream.asyncListen((_) => app._reload());
    }
    return null;
  }
}

final _hotReloader = _HotReloader();

class _RouterHandlerObject extends HandlerObject {
  final RelicRouter router;
  final bool backtrack;
  final bool useHostWhenRouting;

  _RouterHandlerObject(
    this.router, {
    this.backtrack = true,
    this.useHostWhenRouting = false,
  });

  @override
  FutureOr<Result> call(final Request req) => const Pipeline()
      .addMiddleware(
        routeWith(
          router,
          backtrack: backtrack,
          useHostWhenRouting: useHostWhenRouting,
        ),
      )
      .addHandler(router.fallback ?? (_) => Response.notFound())(req);
}
