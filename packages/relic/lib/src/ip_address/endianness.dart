import 'dart:typed_data';

extension Uint8ListConversionExtensions on Uint8List {
  /// Converts this Uint8List (assumed to represent data in big-endian byte order)
  /// to a Uint16List.
  ///
  /// Each pair of bytes from this list is interpreted as a big-endian 16-bit integer.
  /// The length of this Uint8List must be an even number.
  ///
  /// Throws [ArgumentError] if the list length is odd.
  ///
  /// Example:
  /// ```dart
  /// final u8list = Uint8List.fromList([0x12, 0x34, 0xAB, 0xCD]); // Big-endian data
  /// final u16list = u8list.toUint16ListFromBigEndian();
  /// // u16list will be [0x1234, 0xABCD]
  /// ```
  Uint16List toUint16ListFromBigEndian() {
    if (lengthInBytes % 2 != 0) {
      throw ArgumentError(
        'Uint8List length must be even to be converted to Uint16List. Length was $lengthInBytes.',
      );
    }
    if (isEmpty) {
      return Uint16List(0);
    }

    // If the host system is already big-endian, and our source Uint8List is big-endian,
    // we can directly view the buffer as Uint16List.
    if (Endian.host == Endian.big) {
      // Ensure we are viewing the correct segment of the buffer.
      return buffer.asUint16List(offsetInBytes, lengthInBytes ~/ 2);
    } else {
      final int resultLength = lengthInBytes ~/ 2;
      final Uint16List resultList = Uint16List(resultLength);
      final ByteData byteDataView = ByteData.view(
        buffer,
        offsetInBytes,
        lengthInBytes,
      );

      for (int i = 0; i < resultLength; i++) {
        resultList[i] = byteDataView.getUint16(i * 2, Endian.big);
      }
      return resultList;
    }
  }
}
