// ignore_for_file: avoid_print

import 'package:relic/relic.dart';

/// A simple 'Hello World' server
void main() {
  final parent = Router<int>();
  final child = parent.group(
      '/foo'); // groups defined as the simple extension method from above
  child.get('/bar', 42);
  parent.get('/foo/doo', 1202);
  print(parent.lookup(Method.get, '/foo/bar')?.value); // was added to child
  print(child.lookup(Method.get, '/doo')?.value); // was added to parent
}
