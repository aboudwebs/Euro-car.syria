import 'package:euro_cars/core/models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fixtures.dart';

void main() {
  group('AppUser', () {
    test('reads every field and keeps unknown ones for the round trip', () {
      final Map<String, dynamic> json = <String, dynamic>{
        ...workshopJson(debtLimit: 500, debtBalance: 120.5),
        'cashback_balance': '7.25',
        'loyalty_season_spend': '1250.5',
        'loyalty_season_started_at': '2026-01-01T00:00:00Z',
        'my_ref_code': 'MK-1',
        'created_at': '2026-01-02T03:04:05Z',
        'future_field': 'kept',
      };
      final AppUser user = AppUser.fromJson(json);

      expect(user.id, 'w1');
      expect(user.role, 'workshop');
      expect(user.name, 'ورشة النور');
      expect(user.phone, '0982026134');
      expect(user.city, 'حلب');
      expect(user.license, 'L-100');
      expect(user.specs, <String>['BMW']);
      expect(user.tier, 'Bronze');
      expect(user.seasonSpend, 1250.5);
      expect(user.seasonStartedAt!.isAtSameMomentAs(DateTime.utc(2026, 1, 1)), isTrue);
      expect(user.debtLimit, 500.0);
      expect(user.debtBalance, 120.5);
      expect(user.cashbackBalance, 7.25);
      expect(user.myRefCode, 'MK-1');
      expect(user.isActive, isTrue);
      expect(user.createdAt, isNotNull);
      expect(user.toJson()['future_field'], 'kept');
    });

    test('knows which roles may use the mobile app', () {
      final AppUser workshop = AppUser.fromJson(workshopJson());
      final AppUser marketer = AppUser.fromJson(marketerJson());
      final AppUser admin = AppUser.fromJson(adminJson());

      expect(workshop.isWorkshop, isTrue);
      expect(workshop.isMarketer, isFalse);
      expect(workshop.isCustomer, isTrue);
      expect(marketer.isMarketer, isTrue);
      expect(marketer.isCustomer, isTrue);
      expect(admin.isCustomer, isFalse);
    });

    test('debtAvailable is the credit left under the limit, never negative', () {
      expect(AppUser.fromJson(workshopJson(debtLimit: 500, debtBalance: 120.5)).debtAvailable, 379.5);
      expect(AppUser.fromJson(workshopJson(debtLimit: 100, debtBalance: 150)).debtAvailable, 0.0);
      expect(AppUser.fromJson(marketerJson()).debtAvailable, isNull);
    });

    test('survives an empty or oddly typed payload', () {
      final AppUser empty = AppUser.fromJson(<String, dynamic>{});
      expect(empty.id, '');
      expect(empty.isCustomer, isFalse);
      expect(empty.isActive, isTrue);
      expect(empty.specs, isEmpty);

      final AppUser odd = AppUser.fromJson(<String, dynamic>{'specs': 'BMW', 'is_active': false});
      expect(odd.specs, isEmpty);
      expect(odd.isActive, isFalse);
    });

    test('mergedWith applies a newer snapshot without touching the original', () {
      final AppUser before = AppUser.fromJson(workshopJson());
      final AppUser after = before.mergedWith(<String, dynamic>{'name': 'اسم جديد', 'debt_balance': 200});

      expect(after.name, 'اسم جديد');
      expect(after.debtBalance, 200.0);
      expect(after.id, 'w1');
      expect(after.city, 'حلب');
      expect(before.name, 'ورشة النور');
      expect(before.debtBalance, 100.0);
    });
  });

  group('Part', () {
    test('reads numbers that arrive as strings', () {
      final Part part = Part.fromJson(<String, dynamic>{
        'id': 'p1',
        'name': 'فلتر زيت',
        'brand': 'BMW',
        'pn': 'A 276-180',
        'price': '12.5',
        'stock': '3',
        'model': 'X5',
        'years': '2015-2019',
        'altGrade': 'Bosch',
        'branch': 'حلب',
        'image': '',
      });

      expect(part.price, 12.5);
      expect(part.stock, 3);
      expect(part.altGrade, 'Bosch');
      expect(part.image, isNull);
      expect(part.inStock, isTrue);
      expect(part.lowStock, isTrue);
      expect(part.maxOrderQty, 3);
      expect(part.pnCompact, 'a276180');
      expect(part.searchText, contains('فلتر'));
      expect(part.searchText, contains('bmw'));
      expect(part.searchText, contains('x5'));
    });

    test('has safe defaults for a missing row', () {
      final Part part = Part.fromJson(<String, dynamic>{});
      expect(part.name, 'قطعة');
      expect(part.price, 0.0);
      expect(part.stock, 0);
      expect(part.inStock, isFalse);
      expect(part.lowStock, isFalse);
      expect(part.maxOrderQty, 0);
    });

    test('caps one order line at 100 units and flags low stock up to 5', () {
      expect(makePart(stock: 500).maxOrderQty, 100);
      expect(makePart(stock: 100).maxOrderQty, 100);
      expect(makePart(stock: 42).maxOrderQty, 42);
      expect(makePart(stock: 5).lowStock, isTrue);
      expect(makePart(stock: 6).lowStock, isFalse);
      expect(makePart(stock: 0).lowStock, isFalse);
    });
  });

  group('OrderLine and Order', () {
    test('OrderLine computes the line total when the API leaves it out', () {
      final OrderLine line = OrderLine.fromJson(<String, dynamic>{
        'part_id': 'p1',
        'name': 'x',
        'brand': 'BMW',
        'oem_number': 'N1',
        'qty': '2',
        'unit_price': '10.5',
      });
      expect(line.qty, 2);
      expect(line.unitPrice, 10.5);
      expect(line.lineTotal, 21.0);

      final OrderLine given = OrderLine.fromJson(<String, dynamic>{
        'qty': 2,
        'unit_price': 10,
        'line_total': 22,
      });
      expect(given.lineTotal, 22.0);
    });

    test('Order reads its fields and its lines', () {
      final Order order = Order.fromJson(<String, dynamic>{
        'id': '0123456789abcdef',
        'order_number': 15,
        'total_amount': '99.9',
        'pay_method': 'cod',
        'status': 'pending',
        'status_note': null,
        'refund_status': 'pending_review',
        'refund_note': 'بانتظار مراجعة الإدارة',
        'refunded_at': null,
        'created_at': '2026-02-03T00:00:00Z',
        'items': <Map<String, dynamic>>[
          <String, dynamic>{'part_id': 'p1', 'qty': 1, 'unit_price': 5},
          <String, dynamic>{'part_id': 'p2', 'qty': 2, 'unit_price': 7},
        ],
      });

      expect(order.total, 99.9);
      expect(order.payMethod, 'cod');
      expect(order.statusNote, isNull);
      expect(order.refundStatus, 'pending_review');
      expect(order.refundNote, 'بانتظار مراجعة الإدارة');
      expect(order.refundedAt, isNull);
      expect(order.createdAt, isNotNull);
      expect(order.items, hasLength(2));
      expect(order.items[1].lineTotal, 14.0);
      expect(order.isCancelled, isFalse);
    });

    test('Order.label uses the number, or the start of the id', () {
      expect(Order.fromJson(<String, dynamic>{'id': 'x', 'order_number': 15}).label, '#15');
      expect(Order.fromJson(<String, dynamic>{'id': '0123456789abcdef'}).label, '#01234567');
      expect(Order.fromJson(<String, dynamic>{'id': 'abc'}).label, '#abc');
      expect(Order.fromJson(<String, dynamic>{'id': '12345678'}).label, '#12345678');
    });

    test('Order.isCancelled follows the status', () {
      expect(Order.fromJson(<String, dynamic>{'id': 'x', 'status': 'cancelled'}).isCancelled, isTrue);
    });
  });

  group('SpecialRequest', () {
    test('brandLabel shows the typed brand only for "other"', () {
      final SpecialRequest other = SpecialRequest.fromJson(<String, dynamic>{
        'id': 's1',
        'brand': 'أخرى',
        'other_brand': 'Toyota',
        'part_name': 'مرآة',
        'quoted_price': '45',
        'status': 'priced',
        'admin_note': 'متوفرة',
      });
      expect(other.brandLabel, 'Toyota');
      expect(other.quotedPrice, 45.0);
      expect(other.adminNote, 'متوفرة');

      final SpecialRequest listed = SpecialRequest.fromJson(<String, dynamic>{
        'id': 's2',
        'brand': 'BMW',
        'other_brand': 'Toyota',
      });
      expect(listed.brandLabel, 'BMW');

      final SpecialRequest blank = SpecialRequest.fromJson(<String, dynamic>{'id': 's3', 'brand': 'أخرى'});
      expect(blank.brandLabel, 'أخرى');
      expect(blank.quotedPrice, isNull);
      expect(blank.adminNote, '');
    });
  });

  group('LedgerEntry', () {
    test('reads a payment entry', () {
      final LedgerEntry entry = LedgerEntry.fromJson(<String, dynamic>{
        'id': 'l1',
        'tx_type': 'payment',
        'amount': '50',
        'balance_after': 100,
        'note': '',
      });
      expect(entry.isPayment, isTrue);
      expect(entry.amount, 50.0);
      expect(entry.balanceAfter, 100.0);
      expect(entry.note, isNull);
      expect(entry.createdAt, isNull);
    });
  });

  group('WorkshopDashboard', () {
    Map<String, dynamic> order(String id, num total, String pay, String status) {
      return <String, dynamic>{
        'id': id,
        'order_number': 1,
        'total_amount': total,
        'pay_method': pay,
        'status': status,
      };
    }

    WorkshopDashboard dashboard(
      List<Map<String, dynamic>> orders, [
      List<Map<String, dynamic>>? ledger,
      String tier = 'Bronze',
      num seasonSpend = 0,
    ]) {
      return WorkshopDashboard.fromJson(<String, dynamic>{
        'user': <String, dynamic>{
          'name': 'ورشة',
          'tier': tier,
          'loyalty_season_spend': seasonSpend,
          'debt_limit': 1000,
          'debt_balance': '250',
          'cashback_balance': 12,
        },
        'orders': orders,
        'ledger': ledger ?? <Map<String, dynamic>>[],
      });
    }

    test('reads the account block and the lists', () {
      final WorkshopDashboard d = dashboard(<Map<String, dynamic>>[order('o1', 400, 'cod', 'delivered')]);
      expect(d.name, 'ورشة');
      expect(d.tier, 'Bronze');
      expect(d.debtLimit, 1000.0);
      expect(d.debtBalance, 250.0);
      expect(d.cashbackBalance, 12.0);
      expect(d.orders, hasLength(1));
      expect(d.userJson['name'], 'ورشة');
    });

    test('splits orders into cash and debt and ignores cancelled ones', () {
      final WorkshopDashboard d = dashboard(<Map<String, dynamic>>[
        order('o1', 400, 'cod', 'delivered'),
        order('o2', 700, 'debt', 'approved'),
        order('o3', 900, 'sham', 'cancelled'),
        order('o4', 50, 'sham', 'pending'),
      ]);
      expect(d.cashOrders.map((Order o) => o.id), <String>['o1', 'o4']);
      expect(d.debtOrders.map((Order o) => o.id), <String>['o2']);
    });

    test('approved spend counts only approved, shipped and delivered orders', () {
      final WorkshopDashboard d = dashboard(<Map<String, dynamic>>[
        order('o1', 400, 'cod', 'delivered'),
        order('o2', 700, 'debt', 'approved'),
        order('o3', 900, 'sham', 'cancelled'),
        order('o4', 50, 'sham', 'pending'),
        order('o5', 30, 'cod', 'shipped'),
      ]);
      expect(d.approvedSpend, 1130.0);
    });

    test('seasonDaysLeft follows the 90-day server season start', () {
      final WorkshopDashboard active = WorkshopDashboard.fromJson(<String, dynamic>{
        'user': <String, dynamic>{'loyalty_season_started_at': '2026-01-01T00:00:00Z'},
      });
      expect(active.seasonDaysLeft(DateTime.utc(2026, 3, 31)), 1);
      expect(active.seasonDaysLeft(DateTime.utc(2026, 4, 1)), 0);
      expect(dashboard(<Map<String, dynamic>>[]).seasonDaysLeft(DateTime.utc(2026, 3, 1)), isNull);
    });

    test('tier estimate and progress follow the spend', () {
      final WorkshopDashboard none = dashboard(<Map<String, dynamic>>[]);
      expect(none.tierIndex, 0);
      expect(none.currentTier.name, 'برونزية');
      expect(none.nextTier?.name, 'فضية');
      expect(none.tierProgress, 0.0);

      final WorkshopDashboard silver = dashboard(<Map<String, dynamic>>[
        order('o1', 1100, 'cod', 'delivered'),
      ]);
      expect(silver.tierIndex, 1);
      expect(silver.currentTier.name, 'فضية');
      expect(silver.nextTier?.name, 'ذهبية');
      expect(silver.tierProgress, closeTo(0.1, 1e-9));

      final WorkshopDashboard top = dashboard(<Map<String, dynamic>>[
        order('o1', 12000, 'cod', 'shipped'),
      ]);
      expect(top.tierIndex, 4);
      expect(top.nextTier, isNull);
      expect(top.tierProgress, 1.0);
    });

    test('debtDaysLeft counts down from the latest debit that left a balance', () {
      final DateTime now = DateTime.utc(2026, 3, 11);
      final WorkshopDashboard d = dashboard(<Map<String, dynamic>>[], <Map<String, dynamic>>[
        <String, dynamic>{'id': 'l1', 'tx_type': 'payment', 'amount': 50, 'balance_after': 250},
        <String, dynamic>{
          'id': 'l2',
          'tx_type': 'debit',
          'amount': 300,
          'balance_after': 300,
          'created_at': '2026-03-01T00:00:00Z',
        },
        <String, dynamic>{
          'id': 'l3',
          'tx_type': 'debit',
          'amount': 100,
          'balance_after': 100,
          'created_at': '2026-01-01T00:00:00Z',
        },
      ]);
      expect(d.debtDaysLeft(now), 20);
      expect(d.debtDaysLeft(DateTime.utc(2026, 5, 1)), 0);
    });

    test('debtDaysLeft is null without a usable debit entry', () {
      final DateTime now = DateTime.utc(2026, 3, 11);
      expect(dashboard(<Map<String, dynamic>>[]).debtDaysLeft(now), isNull);

      final WorkshopDashboard settled = dashboard(<Map<String, dynamic>>[], <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'l1',
          'tx_type': 'debit',
          'amount': 100,
          'balance_after': 0,
          'created_at': '2026-03-01T00:00:00Z',
        },
      ]);
      expect(settled.debtDaysLeft(now), isNull);

      final WorkshopDashboard undated = dashboard(<Map<String, dynamic>>[], <Map<String, dynamic>>[
        <String, dynamic>{'id': 'l1', 'tx_type': 'debit', 'amount': 100, 'balance_after': 100},
      ]);
      expect(undated.debtDaysLeft(now), isNull);
    });

    test('an empty payload does not crash', () {
      final WorkshopDashboard d = WorkshopDashboard.fromJson(<String, dynamic>{});
      expect(d.orders, isEmpty);
      expect(d.ledger, isEmpty);
      expect(d.debtBalance, 0.0);
      expect(d.tierIndex, 0);
    });
  });

  group('MarketerDashboard, Commissions and PlacedOrder', () {
    test('MarketerDashboard reads the code, link and commissions', () {
      final MarketerDashboard d = MarketerDashboard.fromJson(<String, dynamic>{
        'marketer': <String, dynamic>{
          'name': 'مسوّق',
          'code': 'MK-1A2B3C',
          'referralUrl': 'https://example.test/login?ref=MK-1A2B3C&sig=abc',
        },
        'workshops': '4',
        'commissions': <String, dynamic>{'available': 1, 'held': 2, 'paid': 3, 'total': 6},
        'payoutRequests': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'pr1',
            'amount': '12.5',
            'status': 'rejected',
            'payout_details': 'محفظة تجريبية',
            'admin_note': 'بيانات الحساب غير مكتملة',
            'created_at': '2026-02-01T00:00:00Z',
            'processed_at': '2026-02-02T00:00:00Z',
          },
        ],
      });
      expect(d.code, 'MK-1A2B3C');
      expect(d.referralUrl, contains('sig=abc'));
      expect(d.workshops, 4);
      expect(d.commissions.available, 1.0);
      expect(d.commissions.held, 2.0);
      expect(d.commissions.paid, 3.0);
      expect(d.commissions.total, 6.0);
      expect(d.payoutRequests, hasLength(1));
      expect(d.payoutRequests.single.amount, 12.5);
      expect(d.payoutRequests.single.status, 'rejected');
      expect(d.payoutRequests.single.adminNote, 'بيانات الحساب غير مكتملة');
      expect(d.payoutRequests.single.processedAt, isNotNull);
    });

    test('Commissions defaults missing values to zero', () {
      final Commissions c = Commissions.fromJson(<String, dynamic>{'available': '10', 'held': 5, 'paid': null});
      expect(c.available, 10.0);
      expect(c.held, 5.0);
      expect(c.paid, 0.0);
      expect(c.total, 0.0);
    });

    test('PlacedOrder reads the order number and total', () {
      final PlacedOrder placed = PlacedOrder.fromJson(<String, dynamic>{
        'orderId': 'o9',
        'orderNumber': '12',
        'pay': 'cod',
        'total': '33.5',
      });
      expect(placed.orderId, 'o9');
      expect(placed.orderNumber, 12);
      expect(placed.pay, 'cod');
      expect(placed.total, 33.5);
    });
  });

  group('AuthResult', () {
    test('exposes its kind', () {
      expect(const AuthResult(AuthResultKind.signedIn).isSignedIn, isTrue);
      expect(const AuthResult(AuthResultKind.pendingApproval, 'wait').isPending, isTrue);
      expect(const AuthResult(AuthResultKind.failed, 'no').isSignedIn, isFalse);
      expect(const AuthResult(AuthResultKind.failed, 'no').message, 'no');
    });
  });

  group('new account models', () {
    test('Order reads the tracking number and the delivery address copy', () {
      final Order order = Order.fromJson(<String, dynamic>{
        'id': 'o1',
        'status': 'shipped',
        'tracking_number': ' TRK-123 ',
        'delivery_address': <String, dynamic>{
          'label': 'الورشة',
          'governorate': 'حلب',
          'area': 'الفرقان',
        },
      });
      expect(order.trackingNumber, 'TRK-123');
      expect(order.deliveryAddress?.label, 'الورشة');
      expect(order.deliveryAddress?.summary, 'حلب - الفرقان');
      expect(Order.fromJson(<String, dynamic>{'id': 'x'}).trackingNumber, isNull);
      expect(Order.fromJson(<String, dynamic>{'id': 'x'}).deliveryAddress, isNull);
    });

    test('Order.isActive is true until the order is delivered or cancelled', () {
      bool active(String status) => Order.fromJson(<String, dynamic>{'id': 'x', 'status': status}).isActive;
      expect(active('pending'), isTrue);
      expect(active('approved'), isTrue);
      expect(active('shipped'), isTrue);
      expect(active('delivered'), isFalse);
      expect(active('cancelled'), isFalse);
    });

    test('SavedAddress reads its fields and builds a one-line summary', () {
      final SavedAddress address = SavedAddress.fromJson(<String, dynamic>{
        'id': 'a1',
        'label': 'المستودع',
        'governorate': 'إدلب',
        'area': '',
        'street': 'شارع النور',
        'details': null,
        'phone': '0933000111',
        'isDefault': true,
      });
      expect(address.id, 'a1');
      expect(address.isDefault, isTrue);
      expect(address.summary, 'إدلب - شارع النور');
      expect(address.phone, '0933000111');
    });

    test('SavedVehicle title falls back from the given name to make/model/year to the VIN', () {
      expect(SavedVehicle.fromJson(<String, dynamic>{'id': 'v', 'vin': 'V1', 'name': 'سيارة الورشة'}).title, 'سيارة الورشة');
      expect(
        SavedVehicle.fromJson(<String, dynamic>{'id': 'v', 'vin': 'V1', 'make': 'BMW', 'model': 'X5', 'year': 2018}).title,
        'BMW X5 2018',
      );
      expect(SavedVehicle.fromJson(<String, dynamic>{'id': 'v', 'vin': 'WBA3A5C55FK123456'}).title, 'WBA3A5C55FK123456');
    });

    test('DeletionRequest counts the days left, never below zero', () {
      final DeletionRequest soon = DeletionRequest(dueAt: DateTime.now().add(const Duration(days: 3, hours: 2)));
      expect(soon.daysLeft, 4);
      final DeletionRequest over = DeletionRequest(dueAt: DateTime.now().subtract(const Duration(days: 1)));
      expect(over.daysLeft, 0);
    });

    test('Part reads its section (category)', () {
      final Part part = Part.fromJson(<String, dynamic>{
        'id': 'p',
        'name': 'x',
        'brand': 'BMW',
        'pn': '1',
        'price': 1,
        'stock': 1,
        'category': '  الفرامل ',
      });
      expect(part.category, 'الفرامل');
    });
  });
}
