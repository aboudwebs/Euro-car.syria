// Small text helpers: digit conversion, phone canonical form and search normalisation.

/// Converts Arabic-Indic and Persian digits to ASCII digits.
String toWesternDigits(String input) {
  final StringBuffer out = StringBuffer();
  for (final int rune in input.runes) {
    if (rune >= 0x0660 && rune <= 0x0669) {
      out.writeCharCode(rune - 0x0660 + 0x30);
    } else if (rune >= 0x06F0 && rune <= 0x06F9) {
      out.writeCharCode(rune - 0x06F0 + 0x30);
    } else {
      out.writeCharCode(rune);
    }
  }
  return out.toString();
}

/// Canonical phone form used when a NEW account is registered: ASCII digits, no spaces, dashes or brackets.
/// Sign-in deliberately sends the phone exactly as typed (trimmed) because the server compares the stored text.
String canonicalPhone(String raw) {
  final String digits = toWesternDigits(raw.trim());
  final StringBuffer out = StringBuffer();
  for (final int rune in digits.runes) {
    final bool skip = rune == 0x20 ||
        rune == 0x2D ||
        rune == 0x28 ||
        rune == 0x29 ||
        rune == 0x2E ||
        rune == 0xA0 ||
        rune == 0x200E ||
        rune == 0x200F;
    if (!skip) {
      out.writeCharCode(rune);
    }
  }
  return out.toString();
}

/// Lower-cases, converts digits, removes Arabic diacritics and unifies alef / yaa / taa-marbuta variants,
/// so that a mechanic typing quickly still finds the part.
String normalizeSearch(String input) {
  final String source = toWesternDigits(input).toLowerCase();
  final StringBuffer out = StringBuffer();
  bool lastWasSpace = true;
  for (final int rune in source.runes) {
    final bool diacritic = (rune >= 0x064B && rune <= 0x065F) || rune == 0x0670 || rune == 0x0640;
    if (diacritic) {
      continue;
    }
    int r = rune;
    if (r == 0x0623 || r == 0x0625 || r == 0x0622 || r == 0x0671) {
      r = 0x0627;
    } else if (r == 0x0649) {
      r = 0x064A;
    } else if (r == 0x0629) {
      r = 0x0647;
    }
    final String ch = String.fromCharCode(r);
    if (ch.trim().isEmpty) {
      if (!lastWasSpace) {
        out.write(' ');
        lastWasSpace = true;
      }
    } else {
      out.write(ch);
      lastWasSpace = false;
    }
  }
  return out.toString().trim();
}

/// Keeps only ASCII letters and digits (lower-cased): "A 276-180.00 09" becomes "a2761800009".
/// Used to match OEM part numbers however the user separates them.
String compactCode(String input) {
  final String source = toWesternDigits(input).toLowerCase();
  final StringBuffer out = StringBuffer();
  for (final int r in source.runes) {
    final bool digit = r >= 0x30 && r <= 0x39;
    final bool letter = r >= 0x61 && r <= 0x7A;
    if (digit || letter) {
      out.writeCharCode(r);
    }
  }
  return out.toString();
}

/// True when the text looks like a 17 character VIN (letters I, O and Q are never used in VINs).
bool isVinLike(String input) {
  final String s = toWesternDigits(input.trim()).toUpperCase();
  if (s.length != 17) {
    return false;
  }
  for (final int r in s.runes) {
    final bool digit = r >= 0x30 && r <= 0x39;
    final bool letter = r >= 0x41 && r <= 0x5A && r != 0x49 && r != 0x4F && r != 0x51;
    if (!digit && !letter) {
      return false;
    }
  }
  return true;
}

/// First letters of the first two words of a name, for the avatar placeholder.
String initialsOf(String name) {
  final List<String> words = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((String w) => w.isNotEmpty)
      .toList();
  final StringBuffer out = StringBuffer();
  for (final String word in words.take(2)) {
    out.write(String.fromCharCode(word.runes.first));
  }
  return out.toString();
}
