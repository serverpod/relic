import 'dart:typed_data';

import 'package:relic/src/ip_address/endianness.dart';
import 'package:relic/src/ip_address/ip_address.dart';
import 'package:test/test.dart';

void main() {
  group('Uint16List.toBigEndianUint8List', () {
    test('Given a Uint16List on big-endian system, '
        'when converted to Uint8List, '
        'then creates proper byte view', () {
      final u16list = Uint16List.fromList([0x1234, 0xABCD]);

      final u8list = u16list.toBigEndianUint8List();

      // Should be [0x12, 0x34, 0xAB, 0xCD] in big-endian
      expect(u8list.length, equals(4));
      expect(u8list[0], equals(0x12));
      expect(u8list[1], equals(0x34));
      expect(u8list[2], equals(0xAB));
      expect(u8list[3], equals(0xCD));
    });

    test('Given an empty Uint16List, '
        'when converted to Uint8List, '
        'then returns empty Uint8List', () {
      final u16list = Uint16List(0);

      final u8list = u16list.toBigEndianUint8List();

      expect(u8list.length, equals(0));
    });
  });

  group('Uint8List.toUint16ListFromBigEndian', () {
    test('Given a Uint8List with big-endian data on big-endian system, '
        'when converted to Uint16List, '
        'then creates proper view', () {
      final u8list = Uint8List.fromList([0x12, 0x34, 0xAB, 0xCD]);

      final u16list = u8list.toUint16ListFromBigEndian();

      expect(u16list.length, equals(2));
      expect(u16list[0], equals(0x1234));
      expect(u16list[1], equals(0xABCD));
    });

    test('Given an empty Uint8List, '
        'when converted to Uint16List, '
        'then returns empty Uint16List', () {
      final u8list = Uint8List(0);

      final u16list = u8list.toUint16ListFromBigEndian();

      expect(u16list.length, equals(0));
    });

    test('Given a Uint8List with odd length, '
        'when converted to Uint16List, '
        'then ArgumentError is thrown', () {
      final u8list = Uint8List.fromList([0x12, 0x34, 0xAB]);

      expect(() => u8list.toUint16ListFromBigEndian(), throwsArgumentError);
    });
  });
}
