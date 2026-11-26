// Display preferences chosen in the profile: the language of the interface (Arabic or English) and the currency
// prices are shown in (US dollars, or Syrian pounds when the admin has published an exchange rate).
//
// They are plain values read by tr() (lib/core/i18n.dart) and formatUsd() (lib/core/format.dart). AppState owns
// them: it sets them from the saved choice at start-up and whenever the user changes them, and the app rebuilds
// its whole widget tree on every change (see _EuroAppState), so every screen picks the new values up.

const String languageArabic = 'ar';
const String languageEnglish = 'en';
const String currencyUsd = 'USD';
const String currencySyp = 'SYP';

class DisplayPrefs {
  const DisplayPrefs._();

  static String language = languageArabic;
  static String currency = currencyUsd;

  /// Syrian pounds for one US dollar, as published by the admin (null until one is published).
  static double? sypRate;

  static bool get isEnglish => language == languageEnglish;

  /// True when prices are converted and shown in Syrian pounds (the choice is SYP and a rate is known).
  static bool get showSyp {
    final double? rate = sypRate;
    return currency == currencySyp && rate != null && rate > 0;
  }

  /// Back to the defaults (used when a session ends and by tests).
  static void reset() {
    language = languageArabic;
    currency = currencyUsd;
    sypRate = null;
  }
}
