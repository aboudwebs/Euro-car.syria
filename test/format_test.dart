import 'package:euro_cars/core/display.dart';
import 'package:euro_cars/core/format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('roundMoney', () {
    test('rounds to cents like the server', () {
      expect(roundMoney(10.126), 10.13);
      expect(roundMoney(2.5), 2.5);
      expect(roundMoney(0), 0.0);
    });

    test('removes binary floating point noise', () {
      expect(roundMoney(0.1 + 0.2), 0.3);
      expect(roundMoney(10.5 * 3), 31.5);
    });
  });

  group('formatUsd', () {
    test('shows whole amounts without decimals', () {
      expect(formatUsd(0), '\$0');
      expect(formatUsd(12), '\$12');
      expect(formatUsd(999), '\$999');
      expect(formatUsd(20.0), '\$20');
    });

    test('keeps at most two decimals and drops trailing zeros', () {
      expect(formatUsd(1234.5), '\$1,234.5');
      expect(formatUsd(7.10), '\$7.1');
      expect(formatUsd(0.5), '\$0.5');
      expect(formatUsd(19.999), '\$20');
    });

    test('groups thousands with commas', () {
      expect(formatUsd(1000), '\$1,000');
      expect(formatUsd(100000), '\$100,000');
      expect(formatUsd(1234567.891), '\$1,234,567.89');
    });

    test('puts the minus sign before the dollar sign', () {
      expect(formatUsd(-45.5), '-\$45.5');
    });

    test('never shows NaN or infinity', () {
      expect(formatUsd(double.nan), '\$0');
      expect(formatUsd(double.infinity), '\$0');
      expect(formatUsd(double.negativeInfinity), '\$0');
    });
  });

  group('invoice currency formatting', () {
    test('formats SYP invoices from their saved exchange rate regardless of profile currency', () {
      DisplayPrefs.currency = currencyUsd;
      expect(formatInvoiceAmount(2, currency: 'SYP', rate: 143.75), '288 ل.س');
      expect(formatInvoiceAmount(2, currency: 'USD'), '\$2');
    });

    test('falls back to USD when the invoice rate is unavailable', () {
      expect(formatInvoiceAmount(2, currency: 'SYP'), '\$2');
    });
  });

  group('formatDate', () {
    test('uses dd/MM/yyyy with leading zeros', () {
      expect(formatDate(DateTime(2026, 3, 7)), '07/03/2026');
      expect(formatDate(DateTime(2026, 12, 25)), '25/12/2026');
    });

    test('shows a dash when the date is unknown', () {
      expect(formatDate(null), '—');
    });
  });

  group('formatUsd in Syrian pounds', () {
    tearDown(DisplayPrefs.reset);

    test('stays in dollars until a rate is published, even when SYP is chosen', () {
      DisplayPrefs.currency = currencySyp;
      expect(formatUsd(10), '\$10');
    });

    test('converts for display when SYP is chosen and a rate exists', () {
      DisplayPrefs.currency = currencySyp;
      DisplayPrefs.sypRate = 15000;
      expect(formatUsd(2), '30,000 ل.س');
      DisplayPrefs.language = languageEnglish;
      expect(formatUsd(2), 'SYP 30,000');
    });

    test('dollars are shown when the choice is USD even if a rate exists', () {
      DisplayPrefs.sypRate = 15000;
      expect(formatUsd(2), '\$2');
    });
  });
}
