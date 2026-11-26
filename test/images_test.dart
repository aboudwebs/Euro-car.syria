import 'dart:typed_data';

import 'package:euro_cars/core/images.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List bytes(List<int> values) => Uint8List.fromList(values);

void main() {
  final Uint8List jpeg = bytes(<int>[0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10]);
  final Uint8List png = bytes(<int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00]);
  final Uint8List webp = bytes(<int>[
    0x52, 0x49, 0x46, 0x46, // RIFF
    0x24, 0x00, 0x00, 0x00, // size
    0x57, 0x45, 0x42, 0x50, // WEBP
    0x56, 0x50, 0x38, 0x20,
  ]);
  final Uint8List gif = bytes(<int>[0x47, 0x49, 0x46, 0x38, 0x39, 0x61, 0x01, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00]);

  group('image type detection', () {
    test('recognises JPEG, PNG and WebP by their first bytes', () {
      expect(isJpegBytes(jpeg), isTrue);
      expect(isPngBytes(png), isTrue);
      expect(isWebpBytes(webp), isTrue);
      expect(imageExtension(jpeg), 'jpg');
      expect(imageExtension(png), 'png');
      expect(imageExtension(webp), 'webp');
    });

    test('does not mix the formats up', () {
      expect(isJpegBytes(png), isFalse);
      expect(isPngBytes(jpeg), isFalse);
      expect(isWebpBytes(jpeg), isFalse);
      expect(isWebpBytes(png), isFalse);
    });

    test('rejects other formats, truncated data and empty data', () {
      expect(imageExtension(gif), isNull);
      expect(imageExtension(bytes(<int>[])), isNull);
      expect(isJpegBytes(bytes(<int>[0xFF, 0xD8, 0xFF])), isFalse);
      expect(isPngBytes(bytes(<int>[0x89, 0x50, 0x4E, 0x47])), isFalse);
    });
  });
}
