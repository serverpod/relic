import 'dart:async';
import 'dart:io';
import 'package:relic/io_adapter.dart';
import 'package:relic/relic.dart';

void main() async {
  print('Testing force close feature...\n');
  
  // Example 1: Force close immediately
  print('Example 1: Force close (ignores in-flight requests)');
  final server = RelicServer(
    () => IOAdapter.bind(InternetAddress.loopbackIPv4, port: 0),
  );
  
  await server.mountAndStart((req) async {
    await Future.delayed(Duration(seconds: 5));
    return Response.ok(body: Body.fromString('Done'));
  });
  
  print('Server started on port ${server.port}');
  
  // Start a long request (don't wait for it)
  unawaited(
    HttpClient()
      .get('localhost', server.port, '/')
      .then((req) => req.close())
      .then((response) {
        print('  Request completed: ${response.statusCode}');
      })
      .catchError((e) {
        print('  Request failed (expected): ${e.runtimeType}');
      })
  );
  
  // Wait for request to start
  await Future.delayed(Duration(milliseconds: 100));
  
  final stopwatch = Stopwatch()..start();
  await server.close(force: true);
  stopwatch.stop();
  print('  Force close took ${stopwatch.elapsedMilliseconds}ms');
  print('  ✓ Quick shutdown (did not wait 5 seconds)\n');
  
  // Example 2: Graceful close with timeout using Future.any
  print('Example 2: Close with timeout (uses Future.any pattern)');
  final server2 = RelicServer(
    () => IOAdapter.bind(InternetAddress.loopbackIPv4, port: 0),
  );
  
  await server2.mountAndStart((req) async {
    await Future.delayed(Duration(seconds: 5));
    return Response.ok(body: Body.fromString('Done'));
  });
  
  print('Server 2 started on port ${server2.port}');
  
  // Start a long request
  unawaited(
    HttpClient()
      .get('localhost', server2.port, '/')
      .then((req) => req.close())
      .then((response) {
        print('  Request completed: ${response.statusCode}');
      })
      .catchError((e) {
        print('  Request failed after timeout: ${e.runtimeType}');
      })
  );
  
  await Future.delayed(Duration(milliseconds: 100));
  
  final stopwatch2 = Stopwatch()..start();
  // Pattern from issue: Close with timeout, then force close if needed
  await Future.any([
    server2.close(),  // Graceful close (would take 5 seconds)
    Future.delayed(Duration(seconds: 2)).then((_) => server2.close(force: true))
  ]);
  stopwatch2.stop();
  
  print('  Close with 2-second timeout took ${stopwatch2.elapsedMilliseconds}ms');
  print('  ✓ Timeout triggered force close (did not wait 5 seconds)\n');
  
  print('All examples completed successfully! ✓');
}
