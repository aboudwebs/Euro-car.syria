// Vehicle identification numbers (VIN / chassis numbers): checking what the user typed or the camera read.
//
// A modern VIN has 17 characters: digits and capital letters, never I, O or Q. Older cars and some makes have other
// numbers, so the check is a HINT for the screen: [checkVin] says what the text looks like, and only text that cannot
// be a chassis number at all (too short, or with other characters) is refused. Nothing here talks to the server.

import 'text_utils.dart';

/// What a chassis number looks like.
enum VinShape {
  /// 17 characters, digits and letters without I, O, Q: a standard VIN.
  standard,

  /// 17 characters but with I, O or Q (very likely a misread 1 or 0, or a non-standard number).
  standardLength,

  /// 5 to 32 letters, digits or dashes of another length: older cars and special numbers are accepted.
  other,

  /// Empty, too short or with characters a chassis number never has.
  invalid,
}

const int vinLength = 17;
const int minChassisLength = 5;
const int maxChassisLength = 32;

/// Capital letters and digits only (Arabic-Indic digits converted, spaces and separators removed).
String cleanVin(String input) {
  final String source = toWesternDigits(input).toUpperCase();
  final StringBuffer out = StringBuffer();
  for (final int r in source.runes) {
    final bool digit = r >= 0x30 && r <= 0x39;
    final bool letter = r >= 0x41 && r <= 0x5A;
    if (digit || letter) {
      out.writeCharCode(r);
    }
  }
  return out.toString();
}

bool _illegalInVin(int r) => r == 0x49 || r == 0x4F || r == 0x51; // I, O, Q

VinShape checkVin(String input) {
  final String text = toWesternDigits(input).toUpperCase().replaceAll(RegExp(r'\s+'), '');
  if (text.length < minChassisLength || text.length > maxChassisLength) {
    return VinShape.invalid;
  }
  if (!RegExp(r'^[A-Z0-9-]+$').hasMatch(text)) {
    return VinShape.invalid;
  }
  if (text.length != vinLength || text.contains('-')) {
    return VinShape.other;
  }
  for (final int r in text.runes) {
    if (_illegalInVin(r)) {
      return VinShape.standardLength;
    }
  }
  return VinShape.standard;
}

/// True when the text may be saved or searched as a chassis number (see [VinShape.invalid]).
bool isAcceptableChassis(String input) => checkVin(input) != VinShape.invalid;

const Map<String, int> _translit = <String, int>{
  'A': 1, 'B': 2, 'C': 3, 'D': 4, 'E': 5, 'F': 6, 'G': 7, 'H': 8,
  'J': 1, 'K': 2, 'L': 3, 'M': 4, 'N': 5, 'P': 7, 'R': 9,
  'S': 2, 'T': 3, 'U': 4, 'V': 5, 'W': 6, 'X': 7, 'Y': 8, 'Z': 9,
};
const List<int> _weights = <int>[8, 7, 6, 5, 4, 3, 2, 10, 0, 9, 8, 7, 6, 5, 4, 3, 2];

/// The ISO 3779 check digit (position 9). It is mandatory in North America only, so it is used to RANK camera
/// readings, never to refuse a number.
bool vinCheckDigitMatches(String vin) {
  final String text = vin.toUpperCase();
  if (text.length != vinLength) {
    return false;
  }
  int sum = 0;
  for (int i = 0; i < vinLength; i++) {
    final String ch = text[i];
    final int? value = RegExp(r'[0-9]').hasMatch(ch) ? int.parse(ch) : _translit[ch];
    if (value == null) {
      return false;
    }
    sum += value * _weights[i];
  }
  final int remainder = sum % 11;
  final String expected = remainder == 10 ? 'X' : remainder.toString();
  return text[8] == expected;
}

/// A chassis number found in the text the camera read.
class VinCandidate {
  const VinCandidate(this.value, {required this.score});

  final String value;

  /// Higher is more likely to be the number printed on the car.
  final int score;
}

/// Finds the most likely chassis numbers in lines of recognised text.
///
/// Camera text recognition often confuses O with 0, Q with 0 and I with 1 and splits a number over two lines or
/// with spaces. Each line (and each pair of neighbouring lines) is reduced to letters and digits, the three letters
/// a VIN never has are turned into the digits they look like, and every 17-character window is scored: a matching
/// check digit counts most, then a mix of letters and digits. Best first; at most [limit] results.
List<VinCandidate> extractVinCandidates(List<String> lines, {int limit = 4}) {
  final List<String> cleaned = <String>[
    for (final String line in lines)
      if (cleanVin(line).length >= 6) cleanVin(line),
  ];
  final List<String> sources = <String>[...cleaned];
  for (int i = 0; i + 1 < cleaned.length; i++) {
    sources.add(cleaned[i] + cleaned[i + 1]);
  }

  // A 17-character word of its own (such as the part after "VIN:") is far more likely than a window cut from the
  // middle of a longer run of text, so it gets a bonus.
  final Set<String> wholeWords = <String>{};
  for (final String line in lines) {
    for (final String word in line.split(RegExp(r'[\s:;,]+'))) {
      final String cleanedWord = cleanVin(word);
      if (cleanedWord.length == vinLength) {
        wholeWords.add(cleanedWord.replaceAll('O', '0').replaceAll('Q', '0').replaceAll('I', '1'));
      }
    }
  }

  final Map<String, int> best = <String, int>{};
  for (final String source in sources) {
    final String fixed = source.replaceAll('O', '0').replaceAll('Q', '0').replaceAll('I', '1');
    for (int start = 0; start + vinLength <= fixed.length; start++) {
      final String window = fixed.substring(start, start + vinLength);
      final bool hasDigit = RegExp(r'[0-9]').hasMatch(window);
      final bool hasLetter = RegExp(r'[A-Z]').hasMatch(window);
      if (!hasDigit || !hasLetter) {
        continue; // a run of only letters or only digits is a word or a phone number
      }
      int score = 10;
      if (vinCheckDigitMatches(window)) {
        score += 20;
      }
      // A printed VIN usually starts with a letter or digit of the world manufacturer code and has several digits.
      final int digits = RegExp(r'[0-9]').allMatches(window).length;
      if (digits >= 4 && digits <= 13) {
        score += 3;
      }
      if (source.length == vinLength) {
        score += 4; // the whole line is the number
      }
      if (wholeWords.contains(window)) {
        score += 6;
      }
      final int? old = best[window];
      if (old == null || score > old) {
        best[window] = score;
      }
    }
  }

  final List<VinCandidate> result = <VinCandidate>[
    for (final MapEntry<String, int> e in best.entries) VinCandidate(e.key, score: e.value),
  ]..sort((VinCandidate a, VinCandidate b) => b.score.compareTo(a.score));
  if (result.length > limit) {
    return result.sublist(0, limit);
  }
  return result;
}

/// When no 17-character number was found: the longest letters-and-digits line that could be part of one, so the user
/// can correct it by hand instead of typing it from nothing. Null when nothing useful was read.
String? bestPartialVin(List<String> lines) {
  String? best;
  for (final String line in lines) {
    final String text = cleanVin(line);
    final bool mixed = RegExp(r'[0-9]').hasMatch(text) && RegExp(r'[A-Z]').hasMatch(text);
    if (text.length >= 8 && text.length < vinLength + 8 && mixed) {
      if (best == null || (text.length - vinLength).abs() < (best.length - vinLength).abs()) {
        best = text;
      }
    }
  }
  return best;
}
