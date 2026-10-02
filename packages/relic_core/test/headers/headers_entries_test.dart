import 'package:relic_core/relic_core.dart';
import 'package:test/test.dart';

void main() {
  test('Given headers with two fields, when entries is read, '
      'then each field is one entry with its lowercase name', () {
    final headers = Headers.build((final mh) {
      mh['X-One'] = ['a', 'b'];
      mh['Two'] = ['c'];
    });

    // ignore: deprecated_member_use_from_same_package
    final entries = headers.entries.toList();

    expect(entries.map((final e) => e.key), ['x-one', 'two']);
    expect(entries.map((final e) => e.value), [
      ['a', 'b'],
      ['c'],
    ]);
  });
}
