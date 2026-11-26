import 'package:euro_cars/core/text_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('toWesternDigits', () {
    test('converts Arabic-Indic digits', () {
      expect(toWesternDigits('٠١٢٣٤٥٦٧٨٩'), '0123456789');
    });

    test('converts Persian digits', () {
      expect(toWesternDigits('۰۱۲۳۴۵۶۷۸۹'), '0123456789');
    });

    test('leaves everything else alone', () {
      expect(toWesternDigits('٠٩٣٨ abc ١٢'), '0938 abc 12');
      expect(toWesternDigits(''), '');
    });
  });

  group('canonicalPhone', () {
    test('removes spaces, dashes, dots and brackets', () {
      expect(canonicalPhone('+963 982-026 134'), '+963982026134');
      expect(canonicalPhone('(0982) 026.134'), '0982026134');
    });

    test('converts Arabic digits', () {
      expect(canonicalPhone('٠٩٨٢ ٠٢٦ ١٣٤'), '0982026134');
    });

    test('removes invisible direction marks and no-break spaces', () {
      expect(canonicalPhone('‎0982 026134'), '0982026134');
    });

    test('trims the ends', () {
      expect(canonicalPhone('  0982026134  '), '0982026134');
    });
  });

  group('normalizeSearch', () {
    test('lower-cases and collapses whitespace', () {
      expect(normalizeSearch('  BMW   X5  '), 'bmw x5');
      expect(normalizeSearch(''), '');
      expect(normalizeSearch('   '), '');
    });

    test('removes Arabic diacritics and tatweel', () {
      expect(normalizeSearch('أَحمد'), 'احمد');
      expect(normalizeSearch('محـمد'), 'محمد');
    });

    test('unifies alef, yaa and taa marbuta variants', () {
      expect(normalizeSearch('إبراهيم'), 'ابراهيم');
      expect(normalizeSearch('آلة'), 'اله');
      expect(normalizeSearch('على'), 'علي');
      expect(normalizeSearch('مدرسة'), 'مدرسه');
    });

    test('converts Arabic digits', () {
      expect(normalizeSearch('٣٢٠D'), '320d');
    });
  });

  group('compactCode', () {
    test('keeps only ASCII letters and digits in lower case', () {
      expect(compactCode('A 276-180.00 09'), 'a2761800009');
      expect(compactCode('٣٢٠ d'), '320d');
      expect(compactCode(''), '');
      expect(compactCode('---'), '');
    });
  });

  group('isVinLike', () {
    test('accepts 17 characters without I, O and Q', () {
      expect(isVinLike('WBA3A5C51CF256651'), isTrue);
      expect(isVinLike('wba3a5c51cf256651'), isTrue);
      expect(isVinLike(' WBA3A5C51CF256651 '), isTrue);
      expect(isVinLike('WBA3A5C51CF٢٥٦٦٥١'), isTrue);
    });

    test('rejects other lengths and forbidden letters', () {
      expect(isVinLike('WBA3A5C51CF25665'), isFalse);
      expect(isVinLike('WBA3A5C51CF25665O'), isFalse);
      expect(isVinLike('WBA3A5C51CF25665I'), isFalse);
      expect(isVinLike('WBA3A5C51CF25665Q'), isFalse);
      expect(isVinLike('WBA3A5C51CF2566-1'), isFalse);
      expect(isVinLike(''), isFalse);
    });
  });

  group('initialsOf', () {
    test('uses the first letters of the first two words', () {
      expect(initialsOf('أحمد العلي'), 'أا');
      expect(initialsOf('  Ali   Hassan Omar '), 'AH');
      expect(initialsOf('Sara'), 'S');
    });

    test('is empty for an empty name', () {
      expect(initialsOf(''), '');
      expect(initialsOf('   '), '');
    });
  });
}
