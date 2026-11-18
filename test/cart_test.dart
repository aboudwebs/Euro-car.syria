import 'package:euro_cars/core/cart.dart';
import 'package:euro_cars/core/models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fixtures.dart';

AppUser workshop({double? limit, double? balance}) {
  return AppUser(
    id: 'w1',
    role: 'workshop',
    name: 'ورشة',
    phone: '0982026134',
    debtLimit: limit,
    debtBalance: balance,
  );
}

AppUser marketer() {
  return const AppUser(id: 'm1', role: 'marketer', name: 'مسوّق', phone: '0933000111');
}

void main() {
  group('CartLine and cartTotal', () {
    test('a line total is the unit price times the quantity, rounded to cents', () {
      expect(CartLine(makePart(price: 10.5), 3).total, 31.5);
      expect(CartLine(makePart(price: 0.1), 3).total, closeTo(0.3, 1e-9));
    });

    test('the cart total sums the lines', () {
      final List<CartLine> lines = <CartLine>[
        CartLine(makePart(id: 'a', price: 10.5), 3),
        CartLine(makePart(id: 'b', price: 0.1), 3),
      ];
      expect(cartTotal(lines), closeTo(31.8, 1e-9));
    });

    test('an empty cart is zero', () {
      expect(cartTotal(const <CartLine>[]), 0.0);
    });
  });

  group('cartCount', () {
    test('counts units, not lines', () {
      expect(cartCount(<String, int>{'a': 2, 'b': 3}), 5);
      expect(cartCount(<String, int>{}), 0);
    });
  });

  group('payMethodsFor', () {
    test('workshops may use cash, Sham Cash and the debt ledger', () {
      expect(payMethodsFor(workshop()), <String>['cod', 'sham', 'debt']);
    });

    test('marketers may not use the debt ledger', () {
      expect(payMethodsFor(marketer()), <String>['cod', 'sham']);
    });

    test('independent customers may use only cash on delivery and Sham Cash', () {
      const AppUser customer = AppUser(id: 'c1', role: 'customer', name: 'زبون', phone: '0933000111');
      expect(customer.isIndependentCustomer, isTrue);
      expect(payMethodsFor(customer), <String>['cod', 'sham']);
    });
  });

  group('checkDebtPayment', () {
    test('is refused for a marketer', () {
      final DebtCheck check = checkDebtPayment(user: marketer(), total: 10);
      expect(check.allowed, isFalse);
      expect(check.message, isNotEmpty);
    });

    test('is left to the server when the limit is unknown', () {
      final DebtCheck check = checkDebtPayment(user: workshop(), total: 10);
      expect(check.allowed, isTrue);
      expect(check.available, isNull);
    });

    test('is refused when no debt limit was set', () {
      final DebtCheck check = checkDebtPayment(user: workshop(limit: 0, balance: 0), total: 10);
      expect(check.allowed, isFalse);
      expect(check.available, 0.0);
      expect(check.message, isNotEmpty);
    });

    test('is allowed up to the credit that is left', () {
      final AppUser user = workshop(limit: 1000, balance: 300);
      final DebtCheck within = checkDebtPayment(user: user, total: 500);
      expect(within.allowed, isTrue);
      expect(within.available, 700.0);

      final DebtCheck exact = checkDebtPayment(user: user, total: 700);
      expect(exact.allowed, isTrue);
    });

    test('is refused above the credit that is left and names the amount', () {
      final DebtCheck check = checkDebtPayment(user: workshop(limit: 1000, balance: 300), total: 700.01);
      expect(check.allowed, isFalse);
      expect(check.available, 700.0);
      expect(check.message, contains('\$700'));
    });

    test('is refused when the balance already exceeds the limit', () {
      final DebtCheck check = checkDebtPayment(user: workshop(limit: 100, balance: 150), total: 1);
      expect(check.allowed, isFalse);
      expect(check.available, 0.0);
    });
  });
}
