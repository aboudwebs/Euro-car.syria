// Image type detection from the first bytes (the server does the same and ignores the file name).

import 'dart:typed_data';

bool isJpegBytes(Uint8List bytes) {
  return bytes.length > 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF;
}

bool isPngBytes(Uint8List bytes) {
  return bytes.length > 8 && bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47;
}

bool isWebpBytes(Uint8List bytes) {
  return bytes.length > 12 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50;
}

/// jpg, png or webp (the formats the API accepts), or null for anything else.
String? imageExtension(Uint8List bytes) {
  if (isJpegBytes(bytes)) {
    return 'jpg';
  }
  if (isPngBytes(bytes)) {
    return 'png';
  }
  if (isWebpBytes(bytes)) {
    return 'webp';
  }
  return null;
}
