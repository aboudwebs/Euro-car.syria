// Reads the text of a photo on the device (Google ML Kit text recognition, Latin script, no network and no account).
// Kept behind a tiny interface so the scanner screen and its tests do not depend on the plugin.

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Turns a photo file into the lines of text found in it.
abstract class VinTextReader {
  Future<List<String>> readLines(String imagePath);
}

class MlKitVinTextReader implements VinTextReader {
  const MlKitVinTextReader();

  @override
  Future<List<String>> readLines(String imagePath) async {
    final TextRecognizer recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final RecognizedText result = await recognizer.processImage(InputImage.fromFilePath(imagePath));
      final List<String> lines = <String>[];
      for (final TextBlock block in result.blocks) {
        for (final TextLine line in block.lines) {
          final String text = line.text.trim();
          if (text.isNotEmpty) {
            lines.add(text);
          }
        }
      }
      return lines;
    } finally {
      await recognizer.close();
    }
  }
}
