// Interface language. The app is written in Arabic; the English interface is a dictionary keyed by the Arabic text
// (lib/core/i18n_en.dart). Every Text widget of the app goes through tr() (see lib/widgets/tx.dart), so a string
// that has no English entry simply stays Arabic. Texts that carry a value are keyed with {} for each value:
// "باقي {} للوصول إلى {}" matches "باقي $1,200 للوصول إلى فضية" and the captured values are translated too.

import 'display.dart';
import 'i18n_en.dart';

final Map<String, String> _cache = <String, String>{};
List<_Template>? _templates;

class _Template {
  _Template(this.english, String arabic) : pattern = _compile(arabic);

  final String english;
  final RegExp pattern;

  static RegExp _compile(String arabic) {
    final List<String> parts = arabic.split('{}');
    final StringBuffer source = StringBuffer('^');
    for (int i = 0; i < parts.length; i++) {
      source.write(RegExp.escape(parts[i]));
      if (i < parts.length - 1) {
        source.write('(.+?)');
      }
    }
    source.write(r'$');
    return RegExp(source.toString(), dotAll: true);
  }
}

List<_Template> _loadTemplates() {
  // The most specific template first ("{} من {} قطعة" before "{} قطعة"): more fixed text means more specific.
  final List<String> keys = <String>[
    for (final String key in enTexts.keys)
      if (key.contains('{}')) key,
  ]..sort((String a, String b) => b.replaceAll('{}', '').length.compareTo(a.replaceAll('{}', '').length));
  return _templates ??= <_Template>[
    for (final String key in keys) _Template(enTexts[key] ?? key, key),
  ];
}

/// The text in the chosen language (the Arabic original when the interface is Arabic or no translation exists).
String tr(String text) {
  if (!DisplayPrefs.isEnglish || text.isEmpty) {
    return text;
  }
  final String? cached = _cache[text];
  if (cached != null) {
    return cached;
  }
  final String result = _translate(text);
  if (_cache.length > 4000) {
    _cache.clear();
  }
  _cache[text] = result;
  return result;
}

String _translate(String text) {
  final String? exact = enTexts[text];
  if (exact != null) {
    return exact;
  }
  final String trimmed = text.trim();
  if (trimmed != text) {
    final String? inner = enTexts[trimmed];
    if (inner != null) {
      return inner;
    }
  }
  for (final _Template template in _loadTemplates()) {
    final RegExpMatch? match = template.pattern.firstMatch(text);
    if (match == null) {
      continue;
    }
    String out = template.english;
    for (int i = 1; i <= match.groupCount; i++) {
      final String value = match.group(i) ?? '';
      out = out.replaceFirst('{}', _translateValue(value));
    }
    return out;
  }
  return text;
}

String _translateValue(String value) {
  final String? exact = enTexts[value];
  return exact ?? value;
}

/// Clears the translation cache (tests, and when the language changes).
void resetTranslationCache() => _cache.clear();
