import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:mockito/mockito.dart';
import 'package:relic/relic.dart';

import 'package:test/test.dart';
import 'package:test_utils/adapter_conformance.dart';
import 'package:vm_service/vm_service_io.dart' as vmi;

void main() {
  group('RelicApp', () {
    test('Given RelicApp, '
        'when it is instantiated, '
        'then it is a Router<Handler>', () {
      final app = RelicApp();
      expect(app, isA<Router<Handler>>());
    });

    test('Given a RelicApp with a route, '
        'when calling lookupPath, '
        'then it delegates to the underlying router', () {
      Response handler(Request req) => Response.ok();
      final app = RelicApp()..get('/a/b', handler);

      final hit = app.lookupPath(Method.get, NormalizedPath('/a/b'));
      expect(hit, isA<RouterMatch<Handler>>());
      expect((hit as RouterMatch<Handler>).value, same(handler));

      expect(
        app.lookupPath(Method.post, NormalizedPath('/a/b')),
        isA<MethodMiss<Handler>>(),
      );
      expect(
        app.lookupPath(Method.get, NormalizedPath('/nope'), backtrack: false),
        isA<PathMiss<Handler>>(),
      );
    });

    test('Given a RelicApp with a route, '
        'when calling lookupUri, '
        'then it delegates to the underlying router', () {
      Response handler(Request req) => Response.ok();
      final app = RelicApp()..get('/a/b', handler);

      // The query and fragment are not part of the route path.
      final hit = app.lookupUri(
        Method.get,
        Uri.parse('http://example.com/a/b?q=1#frag'),
      );
      expect(hit, isA<RouterMatch<Handler>>());
      expect((hit as RouterMatch<Handler>).value, same(handler));

      expect(
        app.lookupUri(Method.post, Uri.parse('http://example.com/a/b')),
        isA<MethodMiss<Handler>>(),
      );
      expect(
        app.lookupUri(
          Method.get,
          Uri.parse('http://example.com/nope'),
          backtrack: false,
        ),
        isA<PathMiss<Handler>>(),
      );
    });

    test(
      'Given a RelicApp with only a GET route that answers with a lazy body, '
      'when a HEAD request is sent to that path, '
      "then the GET route's status and headers go out without the body",
      () async {
        var listened = false;
        Stream<Uint8List> report() async* {
          listened = true;
          yield Uint8List.fromList(utf8.encode('hello'));
        }

        final app = RelicApp()
          ..get(
            '/report',
            (_) => Response(
              203,
              headers: Headers.build(
                (final mh) => mh.add(HeaderName.lookup('x-route'), 'get'),
              ),
              body: Body.lazy(
                report,
                contentLength: 5,
                mimeType: MimeType.plainText,
              ),
            ),
          );
        final server = await app.serve(port: 0);
        addTearDown(() => app.close());

        final reply = await rawExchange(
          server.port,
          'HEAD /report HTTP/1.1\r\nHost: x\r\nConnection: close\r\n\r\n',
        );

        final (head: head, body: body) = splitHead(reply);
        expect(head, startsWith('HTTP/1.1 203'));
        expect(head.toLowerCase(), contains('x-route: get\r\n'));
        expect(head.toLowerCase(), contains('content-length: 5\r\n'));
        expect(
          head.toLowerCase(),
          contains('content-type: text/plain; charset=utf-8\r\n'),
        );
        expect(body, isEmpty);
        expect(listened, isFalse);
      },
    );

    test('Given a RelicApp with only a GET route that answers with a Hijack, '
        'when a HEAD request is sent to that path, '
        'then it gets 405 with GET as the allowed method', () async {
      var hijacked = false;
      final app = RelicApp()
        ..get(
          '/sse',
          (_) => Hijack((final channel) {
            hijacked = true;
            channel.sink.close();
          }),
        );
      final server = await app.serve(port: 0);
      addTearDown(() => app.close());

      final reply = await rawExchange(
        server.port,
        'HEAD /sse HTTP/1.1\r\nHost: x\r\nConnection: close\r\n\r\n',
      );

      final (head: head, body: _) = splitHead(reply);
      expect(head, startsWith('HTTP/1.1 405'));
      expect(head.toLowerCase(), contains('allow: get\r\n'));
      expect(hijacked, isFalse);
    });

    test('Given a RelicApp with GET and HEAD routes that answer with a Hijack, '
        'when a HEAD request is sent to that path, '
        'then the hijack answers it', () async {
      Hijack sse(final Request req) => Hijack((final channel) async {
        channel.sink.add(utf8.encode('HTTP/1.1 204 No Content\r\n\r\n'));
        await channel.sink.close();
      });
      final app = RelicApp()
        ..get('/sse', sse)
        ..head('/sse', sse);
      final server = await app.serve(port: 0);
      addTearDown(() => app.close());

      final reply = await rawExchange(
        server.port,
        'HEAD /sse HTTP/1.1\r\nHost: x\r\nConnection: close\r\n\r\n',
      );

      expect(reply, startsWith('HTTP/1.1 204'));
    });

    test('Given a RelicApp, '
        'when calling run with adapter factory, '
        'then it creates a RelicServer and mounts the handler', () async {
      final app = RelicApp()..any('/', (req) => Response.ok());

      final server = await app.run(() => _FakeAdapter());

      expect(server, isA<RelicServer>());
      // Server has been created and handler mounted
      await app.close();
    });

    test('Given a RelicApp, '
        'when calling serve, '
        'then it creates a RelicServer and mounts the handler', () async {
      final app = RelicApp()..any('/', (req) => Response.ok());

      final server = await app.serve(port: 0);

      expect(server, isA<RelicServer>());
      // Server has been created and handler mounted
      await app.close();
    });

    test('Given a RelicApp, '
        'when calling serve twice, '
        'then it fails the second time', () async {
      final app = RelicApp()..any('/', (req) => Response.ok());

      await app.serve(port: 0);
      await expectLater(app.serve(port: 0), throwsStateError);

      await app.close();
    });

    test('Given a RelicApp, '
        'when calling serve, close, serve, '
        'then it succeeds', () async {
      final app = RelicApp()..any('/', (req) => Response.ok());

      await app.serve(port: 0);
      await app.close();
      await expectLater(app.serve(port: 0), completes);

      await app.close();
    });

    group('Virtual hosting', () {
      test('Given RelicApp with useHostWhenRouting enabled, '
          'when a request matches a host-specific route, '
          'then the correct handler is invoked', () async {
        final app = RelicApp(useHostWhenRouting: true)
          ..get(
            'www.example.org/foo',
            (_) => Response.ok(body: Body.fromString('host-specific')),
          )
          ..get('*/bar', (_) => Response.ok(body: Body.fromString('any-host')));

        final server = await app.serve(port: 0);
        final client = HttpClient();

        try {
          final request = await client.getUrl(
            Uri.parse('http://localhost:${server.port}/foo'),
          );
          request.headers.set('Host', 'www.example.org');
          final response = await request.close();

          expect(response.statusCode, 200);
          final body = await response
              .transform(const SystemEncoding().decoder)
              .join();
          expect(body, 'host-specific');
        } finally {
          client.close();
          await app.close();
        }
      });

      test('Given RelicApp with useHostWhenRouting enabled, '
          'when a request matches a wildcard host route, '
          'then the wildcard handler is invoked', () async {
        final app = RelicApp(useHostWhenRouting: true)
          ..get(
            'www.example.org/foo',
            (_) => Response.ok(body: Body.fromString('host-specific')),
          )
          ..get('*/bar', (_) => Response.ok(body: Body.fromString('any-host')));

        final server = await app.serve(port: 0);
        final client = HttpClient();

        try {
          final request = await client.getUrl(
            Uri.parse('http://localhost:${server.port}/bar'),
          );
          request.headers.set('Host', 'other.example.com');
          final response = await request.close();

          expect(response.statusCode, 200);
          final body = await response
              .transform(const SystemEncoding().decoder)
              .join();
          expect(body, 'any-host');
        } finally {
          client.close();
          await app.close();
        }
      });

      test('Given RelicApp with useHostWhenRouting enabled, '
          'when a request does not match any host route, '
          'then 404 is returned', () async {
        final app = RelicApp(useHostWhenRouting: true)
          ..get('www.example.org/foo', (_) => Response.ok());

        final server = await app.serve(port: 0);
        final client = HttpClient();

        try {
          final request = await client.getUrl(
            Uri.parse('http://localhost:${server.port}/foo'),
          );
          request.headers.set('Host', 'other.example.com');
          final response = await request.close();

          expect(response.statusCode, 404);
        } finally {
          client.close();
          await app.close();
        }
      });

      test('Given RelicApp without useHostWhenRouting, '
          'when a request is made, '
          'then routing ignores the host header', () async {
        final app = RelicApp()
          ..get('/foo', (_) => Response.ok(body: Body.fromString('no-vhost')));

        final server = await app.serve(port: 0);
        final client = HttpClient();

        try {
          final request = await client.getUrl(
            Uri.parse('http://localhost:${server.port}/foo'),
          );
          request.headers.set('Host', 'any.host.com');
          final response = await request.close();

          expect(response.statusCode, 200);
          final body = await response
              .transform(const SystemEncoding().decoder)
              .join();
          expect(body, 'no-vhost');
        } finally {
          client.close();
          await app.close();
        }
      });
    });

    test('Given a RelicApp before run is called, '
        'when checking isDevMode, '
        'then it returns false', () {
      final app = RelicApp();
      expect(app.developerTools.isDevMode, isFalse);
    });

    test('Given a RelicApp before run is called, '
        'when checking reloadCount, '
        'then it returns 0', () {
      final app = RelicApp();
      expect(app.developerTools.reloadCount, 0);
    });

    test('Given a RelicApp, '
        'when hot-reloading isolate, '
        'then it is rebuild', () async {
      final wsUri = (await Service.getInfo()).serverWebSocketUri;
      if (wsUri == null) {
        markTestSkipped(
          'VM service not available! Use: dart run --enable-vm-service',
        );
        return;
      }
      if (Platform.script.path.endsWith('.dill')) {
        markTestSkipped(
          'Cannot reload! Use: dart test --enable-vm-service --compiler source',
        );
        return;
      }

      final vmService = await vmi.vmServiceConnectUri(wsUri.toString());
      final isolateId = Service.getIsolateId(Isolate.current)!;
      final packagesUri = (await Isolate.packageConfig)?.toString();
      Future<void> hotReload() async {
        await vmService.reloadSources(
          isolateId,
          force: true,
          packagesUri: packagesUri,
        );
      }

      int count = 0;
      final called = StreamController<int>();
      final app = RelicApp()
        ..inject(_Injectable(() => called.add(++count))); // 1 original

      await app.serve(noOfIsolates: 2);

      expect(app.developerTools.reloadCount, 0);

      await hotReload(); // 2
      expect(app.developerTools.reloadCount, 1);

      await hotReload(); // 3
      expect(app.developerTools.reloadCount, 2);

      await app.close();
      await hotReload(); // won't emit
      await hotReload(); // won't emit

      await expectLater(called.stream, emitsInOrder([1, 2, 3]));

      await vmService.dispose();
    }, tags: {'hot-reload'});

    test('Given a RelicApp before run is called, '
        'when checking staticChangeCount, '
        'then it returns 0', () {
      final app = RelicApp();
      expect(app.developerTools.staticChangeCount, 0);
    });

    test('Given a running RelicApp with VM service available, '
        'when notifyStaticChange is called, '
        'then staticChangeCount increments', () async {
      final wsUri = (await Service.getInfo()).serverWebSocketUri;
      if (wsUri == null) {
        markTestSkipped(
          'VM service not available! Use: dart run --enable-vm-service',
        );
        return;
      }

      final vmService = await vmi.vmServiceConnectUri(wsUri.toString());
      final isolateId = Service.getIsolateId(Isolate.current)!;
      final app = RelicApp()..any('/', (req) => Response.ok());

      await app.serve(port: 0);

      expect(app.developerTools.staticChangeCount, 0);

      await vmService.callServiceExtension(
        'ext.relic.notifyStaticChange',
        isolateId: isolateId,
      );
      expect(app.developerTools.staticChangeCount, 1);

      await vmService.callServiceExtension(
        'ext.relic.notifyStaticChange',
        isolateId: isolateId,
      );
      expect(app.developerTools.staticChangeCount, 2);

      await app.close();
      await vmService.dispose();
    }, tags: {'hot-reload'});

    test('Given a RelicApp with VM service available, '
        'when serve is called, '
        'then isDevMode returns true', () async {
      final wsUri = (await Service.getInfo()).serverWebSocketUri;
      if (wsUri == null) {
        markTestSkipped(
          'VM service not available! Use: dart run --enable-vm-service',
        );
        return;
      }

      final app = RelicApp()..any('/', (req) => Response.ok());

      expect(app.developerTools.isDevMode, isFalse);
      await app.serve(port: 0);
      expect(app.developerTools.isDevMode, isTrue);
      await app.close();
      expect(app.developerTools.isDevMode, isFalse);
    }, tags: {'hot-reload'});
  });
}

class _Injectable implements RouterInjectable {
  final void Function() _action;

  _Injectable(this._action);

  @override
  void injectIn(RelicRouter owner) => _action();
}

// Minimal fake adapter for testing
class _FakeAdapter extends Fake implements Adapter {
  final int port = Random().nextInt(65536);

  @override
  List<Listener> get listeners => [
    Listener(Transport.tcp, '127.0.0.1', port, const {HttpProtocol.http11}),
  ];

  @override
  AdapterCapabilities get capabilities => const AdapterCapabilities();

  @override
  void start(ExchangeSink sink) {}

  @override
  Future<void> close({bool force = false}) async {}
}
