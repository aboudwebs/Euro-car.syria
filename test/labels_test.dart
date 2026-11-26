import 'package:euro_cars/core/labels.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Arabic labels', () {
    test('every status the API uses has a label', () {
      for (final String status in <String>['pending', 'approved', 'shipped', 'delivered', 'cancelled']) {
        expect(orderStatusLabels.containsKey(status), isTrue, reason: status);
      }
      for (final String status in <String>['new', 'priced', 'ordered', 'completed', 'cancelled']) {
        expect(specialStatusLabels.containsKey(status), isTrue, reason: status);
      }
      for (final String method in <String>['sham', 'cod', 'debt']) {
        expect(payMethodLabels.containsKey(method), isTrue, reason: method);
      }
      for (final String type in <String>['debit', 'payment']) {
        expect(ledgerTxLabels.containsKey(type), isTrue, reason: type);
      }
    });

    test('a few labels match the web app', () {
      expect(orderStatusLabel('pending'), 'قيد المراجعة');
      expect(orderStatusLabel('cancelled'), 'ملغي');
      expect(payMethodLabel('sham'), 'شام كاش');
      expect(payMethodLabel('cod'), 'كاش عند الاستلام');
      expect(payMethodLabel('debt'), 'دفتر الدين');
      expect(roleLabel('workshop'), 'ورشة');
      expect(roleLabel('marketer'), 'مسوّق');
    });

    test('an unknown value is shown as it is', () {
      expect(orderStatusLabel('mystery'), 'mystery');
      expect(payMethodLabel('crypto'), 'crypto');
      expect(specialStatusLabel('x'), 'x');
      expect(ledgerTxLabel('y'), 'y');
      expect(tierLabel('Diamond'), 'Diamond');
      expect(roleLabel('guest'), 'guest');
    });
  });

  group('statusTone', () {
    test('cancelled is a danger', () {
      expect(statusTone('cancelled'), StatusTone.danger);
    });

    test('delivered and completed are a success', () {
      expect(statusTone('delivered'), StatusTone.success);
      expect(statusTone('completed'), StatusTone.success);
    });

    test('pending and new are waiting', () {
      expect(statusTone('pending'), StatusTone.waiting);
      expect(statusTone('new'), StatusTone.waiting);
    });

    test('everything else is in progress', () {
      for (final String status in <String>['approved', 'shipped', 'priced', 'ordered', 'whatever']) {
        expect(statusTone(status), StatusTone.progress, reason: status);
      }
    });
  });

  group('estimatedTiers', () {
    test('start at zero and rise strictly', () {
      expect(estimatedTiers.first.minSpend, 0.0);
      for (int i = 1; i < estimatedTiers.length; i++) {
        expect(estimatedTiers[i].minSpend, greaterThan(estimatedTiers[i - 1].minSpend));
      }
    });
  });
}
