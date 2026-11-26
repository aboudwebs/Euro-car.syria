import 'package:euro_cars/core/display.dart';
import 'package:euro_cars/core/i18n.dart';
import 'package:euro_cars/core/i18n_en.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    DisplayPrefs.reset();
    resetTranslationCache();
  });

  test('Arabic stays as written', () {
    expect(tr('السلة'), 'السلة');
    expect(tr('طلب {}'), 'طلب {}');
  });

  test('English uses the dictionary', () {
    DisplayPrefs.language = languageEnglish;
    expect(tr('السلة'), 'Cart');
    expect(tr('نسيت كلمة المرور؟'), 'Forgot your password?');
  });

  test('a text with a value keeps the value', () {
    DisplayPrefs.language = languageEnglish;
    expect(tr('عضو منذ 01/02/2026'), 'Member since 01/02/2026');
    expect(tr('رقم الطلب: #15'), 'Order number: #15');
  });

  test('the more specific template wins ("x of y parts" before "y parts")', () {
    DisplayPrefs.language = languageEnglish;
    expect(tr('3 من 10 قطعة'), '3 of 10 parts');
    expect(tr('10 قطعة'), '10 parts');
  });

  test('a value that is itself a known text is translated too', () {
    DisplayPrefs.language = languageEnglish;
    expect(tr('طلب #15'), 'Order #15');
    expect(tr('تطوير Aboud Web'), 'Developed by Aboud Web');
  });

  test('an unknown text stays Arabic instead of disappearing', () {
    DisplayPrefs.language = languageEnglish;
    expect(tr('نص غير موجود في القاموس'), 'نص غير موجود في القاموس');
    expect(tr(''), '');
  });

  test('governorates, brands and statuses used by the app are translated', () {
    DisplayPrefs.language = languageEnglish;
    expect(tr('حلب'), 'Aleppo');
    expect(tr('إدلب'), 'Idlib');
    expect(tr('تم الشحن'), 'Shipped');
    expect(tr('كاش عند الاستلام'), 'Cash on delivery');
  });

  test('every dictionary entry has the same number of values in Arabic and English', () {
    for (final MapEntry<String, String> entry in enTexts.entries) {
      expect(
        entry.value.split('{}').length,
        entry.key.split('{}').length,
        reason: 'placeholders differ for: ${entry.key}',
      );
      expect(entry.value.trim(), isNotEmpty, reason: 'empty translation for: ${entry.key}');
    }
  });
}
