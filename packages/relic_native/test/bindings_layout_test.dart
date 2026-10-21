import 'dart:ffi';

import 'package:relic_native/src/bindings.dart';
import 'package:test/test.dart';

// The extern structs in src/relic_native.zig follow the C ABI, and so do
// Dart Structs, so equal sizes with the same field order mean the same
// layout. A field added on the Dart side changes the size and fails here.
// Nothing here reads the Zig side. The sizes below are its only record.
void main() {
  test('Given the Options struct, when sized, then it is 40 bytes.', () {
    expect(sizeOf<Options>(), 40);
  });

  test('Given the TlsPem struct, when sized, then it is 32 bytes.', () {
    expect(sizeOf<TlsPem>(), 32);
  });

  test('Given the HeaderSlot struct, when sized, then it is 16 bytes.', () {
    expect(sizeOf<HeaderSlot>(), 16);
  });

  test('Given the ExchangeView struct, when sized, then it is 96 bytes.', () {
    expect(sizeOf<ExchangeView>(), 96);
  });

  test('Given the Stats struct, when sized, then it is 12 bytes.', () {
    expect(sizeOf<Stats>(), 12);
  });
}
