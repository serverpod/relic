import 'dart:ffi';

import 'package:relic_native/src/bindings.dart';
import 'package:test/test.dart';

// The extern structs in src/relic_native.zig follow the C ABI, and so do
// Dart Structs, so equal sizes with the same field order mean the same
// layout. A field added on the Dart side changes the size and fails here.
// Nothing here reads the Zig side. The sizes below are its only record.
void main() {
  test('Given the Options struct, when sized, then it is 48 bytes.', () {
    expect(sizeOf<Options>(), 48);
  });

  test('Given the TlsPem struct, when sized, then it is 64 bytes.', () {
    expect(sizeOf<TlsPem>(), 64);
  });

  test('Given the HeaderSlot struct, when sized, then it is 16 bytes.', () {
    expect(sizeOf<HeaderSlot>(), 16);
  });

  test('Given the ExchangeView struct, when sized, then it is 104 bytes.', () {
    expect(sizeOf<ExchangeView>(), 104);
  });

  test('Given the Stats struct, when sized, then it is 12 bytes.', () {
    expect(sizeOf<Stats>(), 12);
  });

  test('Given a tick result with the top bit set, '
      'when decoded, '
      'then count is the low 31 bits and pending is true.', () {
    const tick = TickResult(0x80000000 | 64);
    expect(tick.count, 64);
    expect(tick.pending, isTrue);
  });

  test('Given a tick result without the top bit, '
      'when decoded, '
      'then count is the value and pending is false.', () {
    const tick = TickResult(3);
    expect(tick.count, 3);
    expect(tick.pending, isFalse);
  });
}
