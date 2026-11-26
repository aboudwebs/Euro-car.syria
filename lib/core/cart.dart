// Cart arithmetic and payment rules. The server recomputes everything; this only drives what the screen shows.

import 'format.dart';
import 'models.dart';

/// A cart entry joined with its catalog part.
class CartLine {
  const CartLine(this.part, this.qty);

  final Part part;
  final int qty;

  /// Line total rounded like the server does.
  double get total => roundMoney(part.price * qty);
}

double cartTotal(List<CartLine> lines) {
  double sum = 0.0;
  for (final CartLine line in lines) {
    sum += line.total;
  }
  return roundMoney(sum);
}

int cartCount(Map<String, int> items) {
  int count = 0;
  for (final int qty in items.values) {
    count += qty;
  }
  return count;
}

/// Payment methods a role may use: cash on delivery and Sham Cash for everyone, the debt ledger only for workshops.
List<String> payMethodsFor(AppUser user) {
  if (user.isWorkshop) {
    return const <String>['cod', 'sham', 'debt'];
  }
  return const <String>['cod', 'sham'];
}

/// Whether the debt ledger can be used for an order of the given total.
class DebtCheck {
  const DebtCheck.allowed({this.available})
      : allowed = true,
        message = null;

  const DebtCheck.blocked(String this.message, {this.available}) : allowed = false;

  final bool allowed;
  final String? message;

  /// Credit left under the limit, when it is known.
  final double? available;
}

DebtCheck checkDebtPayment({required AppUser user, required double total}) {
  if (!user.isWorkshop) {
    return const DebtCheck.blocked('الدفع بالدين متاح حصريًا لحسابات الورشات.');
  }
  final double? limit = user.debtLimit;
  if (limit == null) {
    // The limit is unknown on this device, so the server decides.
    return const DebtCheck.allowed();
  }
  final double available = user.debtAvailable ?? 0.0;
  if (!(limit > 0)) {
    return const DebtCheck.blocked(
      'لم يُحدَّد سقف دين لحسابك بعد، تواصل مع الإدارة.',
      available: 0.0,
    );
  }
  if (total > available) {
    return DebtCheck.blocked(
      'قيمة الطلب تتجاوز سقف الدين المتاح (${formatUsd(available)}).',
      available: available,
    );
  }
  return DebtCheck.allowed(available: available);
}
