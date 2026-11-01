// Number and date formatting. Western digits are used everywhere, like the web app.

import 'display.dart';

/// Rounds to cents the same way the server does (Math.round(x * 100) / 100).
double roundMoney(double value) => (value * 100).roundToDouble() / 100;

/// Whole Syrian pounds with thousands separators: 1234567.4 becomes 1,234,567.
String _groupedWhole(double number) {
  final String digits = number.abs().round().toString();
  final StringBuffer grouped = StringBuffer();
  for (int i = 0; i < digits.length; i++) {
    final int remaining = digits.length - i;
    grouped.write(digits[i]);
    if (remaining > 1 && remaining % 3 == 1) {
      grouped.write(',');
    }
  }
  return '${number < 0 ? '-' : ''}$grouped';
}

/// A price. Amounts are stored in US dollars; when the profile says Syrian pounds and the admin has published a rate
/// the amount is converted for display only (orders and totals stay in dollars on the server). Otherwise
/// 1234.5 becomes $1,234.5 (at most two decimals, no trailing zeros), like usd() in the web app.
String formatUsd(num value) {
  final double number = value.toDouble();
  final double? rate = DisplayPrefs.sypRate;
  if (DisplayPrefs.showSyp && rate != null && !number.isNaN && !number.isInfinite) {
    final String whole = _groupedWhole(number * rate);
    return DisplayPrefs.isEnglish ? 'SYP $whole' : '$whole ل.س';
  }
  if (number.isNaN || number.isInfinite) {
    return '\$0';
  }
  final bool negative = number < 0;
  final String fixed = number.abs().toStringAsFixed(2);
  final List<String> parts = fixed.split('.');
  final String whole = parts[0];
  String decimals = parts.length > 1 ? parts[1] : '';
  while (decimals.endsWith('0')) {
    decimals = decimals.substring(0, decimals.length - 1);
  }
  final StringBuffer grouped = StringBuffer();
  for (int i = 0; i < whole.length; i++) {
    final int remaining = whole.length - i;
    grouped.write(whole[i]);
    if (remaining > 1 && remaining % 3 == 1) {
      grouped.write(',');
    }
  }
  final String sign = negative ? '-' : '';
  final String fraction = decimals.isEmpty ? '' : '.$decimals';
  return '$sign\$$grouped$fraction';
}

/// Whole Syrian pounds, based on the immutable rate stored with an invoice.
String formatSypAmount(num value) {
  final double number = value.toDouble();
  if (number.isNaN || number.isInfinite) return '0 ل.س';
  return '${_groupedWhole(number)} ل.س';
}

/// Formats an invoice amount using the currency and rate snapshot selected by the server.
String formatInvoiceAmount(num value, {required String currency, double? rate}) {
  if (currency == 'SYP' && rate != null && rate > 0) {
    return formatSypAmount(value.toDouble() * rate);
  }
  return formatUsd(value);
}

/// dd/MM/yyyy, or a dash when the date is unknown.
String formatDate(DateTime? date) {
  if (date == null) {
    return '—';
  }
  final String day = date.day.toString().padLeft(2, '0');
  final String month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}
