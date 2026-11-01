// Data models for the EURO CARS API. Every parser tolerates missing or oddly typed fields.

import 'config.dart';
import 'json_utils.dart';
import 'labels.dart';
import 'text_utils.dart';

/// The signed-in account (role workshop or marketer). The raw API map is kept so that unknown fields survive a
/// save / restore round trip, and the stored JSON keeps the exact shape the API returned.
class AppUser {
  const AppUser({
    required this.id,
    required this.role,
    required this.name,
    required this.phone,
    this.city,
    this.license,
    this.specs = const <String>[],
    this.tier,
    this.debtLimit,
    this.debtBalance,
    this.cashbackBalance,
    this.myRefCode,
    this.isActive = true,
    this.createdAt,
    this.raw = const <String, dynamic>{},
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    final Object? specsValue = json['specs'];
    final List<String> specs = specsValue is List
        ? specsValue.map((Object? e) => asString(e)).toList()
        : const <String>[];
    return AppUser(
      id: asString(json['id']),
      role: asString(json['role']),
      name: asString(json['name']),
      phone: asString(json['phone']),
      city: asOptionalString(json['city']),
      license: asOptionalString(json['license']),
      specs: specs,
      tier: asOptionalString(json['tier']),
      debtLimit: asDouble(json['debt_limit']),
      debtBalance: asDouble(json['debt_balance']),
      cashbackBalance: asDouble(json['cashback_balance']),
      myRefCode: asOptionalString(json['my_ref_code']),
      isActive: json['is_active'] != false,
      createdAt: asDate(json['created_at']),
      raw: json,
    );
  }

  final String id;
  final String role;
  final String name;
  final String phone;
  final String? city;
  final String? license;
  final List<String> specs;
  final String? tier;
  final double? debtLimit;
  final double? debtBalance;
  final double? cashbackBalance;
  final String? myRefCode;
  final bool isActive;
  final DateTime? createdAt;
  final Map<String, dynamic> raw;

  bool get isWorkshop => role == 'workshop';
  bool get isMarketer => role == 'marketer';

  /// Only workshop and marketer accounts may use the mobile app (admin is web only).
  bool get isCustomer => isWorkshop || isMarketer;

  /// Credit left under the debt limit, or null when the limit is unknown.
  double? get debtAvailable {
    final double? limit = debtLimit;
    if (limit == null) {
      return null;
    }
    final double left = limit - (debtBalance ?? 0);
    return left < 0 ? 0.0 : left;
  }

  Map<String, dynamic> toJson() => raw;

  /// A copy with fields from a newer server snapshot applied on top.
  AppUser mergedWith(Map<String, dynamic> update) {
    return AppUser.fromJson(<String, dynamic>{...raw, ...update});
  }
}

/// A catalog item as returned by GET /api/parts.
class Part {
  Part({
    required this.id,
    required this.name,
    required this.brand,
    required this.pn,
    required this.price,
    required this.stock,
    this.model = '',
    this.years = '',
    this.altGrade,
    this.branch = '',
    this.image,
    this.category,
  });

  factory Part.fromJson(Map<String, dynamic> json) {
    return Part(
      id: asString(json['id']),
      name: asString(json['name'], 'قطعة'),
      brand: asString(json['brand']),
      pn: asString(json['pn']),
      price: asDouble(json['price']) ?? 0.0,
      stock: asInt(json['stock']) ?? 0,
      model: asString(json['model']),
      years: asString(json['years']),
      altGrade: asOptionalString(json['altGrade']),
      branch: asString(json['branch']),
      image: asOptionalString(json['image']),
      category: asOptionalString(json['category'])?.trim(),
    );
  }

  final String id;
  final String name;
  final String brand;

  /// Catalogue section set by the admin (null when the part has none, or the server has no sections yet).
  final String? category;

  /// OEM part number.
  final String pn;
  final double price;
  final int stock;
  final String model;
  final String years;
  final String? altGrade;
  final String branch;
  final String? image;

  bool get inStock => stock > 0;
  bool get lowStock => stock > 0 && stock <= lowStockThreshold;

  /// Most units of this part one order line may hold (stock, and the server cap per line).
  int get maxOrderQty => stock < maxLineQuantity ? stock : maxLineQuantity;

  /// Lower-cased, normalised text the catalog search runs against.
  late final String searchText = normalizeSearch('$name $brand $pn $model $years $branch ${category ?? ''}');

  /// OEM number reduced to letters and digits, so "A 276-180" matches "A276180".
  late final String pnCompact = compactCode(pn);
}

class OrderLine {
  const OrderLine({
    required this.partId,
    required this.name,
    required this.brand,
    required this.oemNumber,
    required this.qty,
    required this.unitPrice,
    required this.lineTotal,
  });

  factory OrderLine.fromJson(Map<String, dynamic> json) {
    final int qty = asInt(json['qty']) ?? 0;
    final double unit = asDouble(json['unit_price']) ?? 0.0;
    return OrderLine(
      partId: asString(json['part_id']),
      name: asString(json['name'], 'قطعة'),
      brand: asString(json['brand']),
      oemNumber: asString(json['oem_number']),
      qty: qty,
      unitPrice: unit,
      lineTotal: asDouble(json['line_total']) ?? unit * qty,
    );
  }

  final String partId;
  final String name;
  final String brand;
  final String oemNumber;
  final int qty;
  final double unitPrice;
  final double lineTotal;
}

class Order {
  const Order({
    required this.id,
    required this.total,
    required this.payMethod,
    required this.status,
    this.orderNumber,
    this.cashbackUsed = 0,
    this.amountDue,
    this.statusNote,
    this.createdAt,
    this.items = const <OrderLine>[],
    this.trackingNumber,
    this.deliveryAddress,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: asString(json['id']),
      orderNumber: asInt(json['order_number']),
      total: asDouble(json['total_amount']) ?? 0.0,
      cashbackUsed: asDouble(json['cashback_used']) ?? 0.0,
      amountDue: asDouble(json['amount_due']),
      payMethod: asString(json['pay_method']),
      status: asString(json['status']),
      statusNote: asOptionalString(json['status_note']),
      createdAt: asDate(json['created_at']),
      items: asList(json['items'])
          .map((Object? e) => OrderLine.fromJson(asMap(e)))
          .toList(),
      trackingNumber: asOptionalString(json['tracking_number'])?.trim(),
      deliveryAddress: json['delivery_address'] is Map
          ? SavedAddress.fromJson(asMap(json['delivery_address']))
          : null,
    );
  }

  final String id;
  final int? orderNumber;
  final double total;
  final double cashbackUsed;
  final double? amountDue;
  final String payMethod;
  final String status;

  /// Reason given by the admin when an order was rejected or cancelled.
  final String? statusNote;
  final DateTime? createdAt;
  final List<OrderLine> items;

  /// Shipment tracking number given by the admin (null until there is one).
  final String? trackingNumber;

  /// Copy of the delivery address chosen at checkout (null when none was chosen).
  final SavedAddress? deliveryAddress;

  /// "#123", or the first characters of the id when the order has no number yet.
  String get label {
    final int? number = orderNumber;
    if (number != null) {
      return '#$number';
    }
    final String short = id.length > 8 ? id.substring(0, 8) : id;
    return '#$short';
  }

  bool get isCancelled => status == 'cancelled';

  /// Not finished yet: waiting for review, approved or on its way.
  bool get isActive => status == 'pending' || status == 'approved' || status == 'shipped';
}

/// A delivery address saved by the customer (GET /api/account/addresses). Orders carry a copy of the one chosen.
class SavedAddress {
  const SavedAddress({
    required this.id,
    required this.label,
    this.governorate,
    this.area,
    this.street,
    this.details,
    this.phone,
    this.isDefault = false,
  });

  factory SavedAddress.fromJson(Map<String, dynamic> json) {
    return SavedAddress(
      id: asString(json['id']),
      label: asString(json['label']),
      governorate: asOptionalString(json['governorate']),
      area: asOptionalString(json['area']),
      street: asOptionalString(json['street']),
      details: asOptionalString(json['details']),
      phone: asOptionalString(json['phone']),
      isDefault: json['isDefault'] == true,
    );
  }

  final String id;
  final String label;
  final String? governorate;
  final String? area;
  final String? street;
  final String? details;
  final String? phone;
  final bool isDefault;

  /// "حلب - الفرقان - شارع ..." without the label.
  String get summary {
    final List<String> parts = <String?>[governorate, area, street, details]
        .whereType<String>()
        .where((String s) => s.trim().isNotEmpty)
        .toList();
    return parts.join(' - ');
  }
}

/// A vehicle registered by the customer (GET /api/account/vehicles).
class SavedVehicle {
  const SavedVehicle({
    required this.id,
    required this.vin,
    this.name,
    this.make,
    this.model,
    this.year,
    this.notes,
  });

  factory SavedVehicle.fromJson(Map<String, dynamic> json) {
    return SavedVehicle(
      id: asString(json['id']),
      vin: asString(json['vin']),
      name: asOptionalString(json['name']),
      make: asOptionalString(json['make']),
      model: asOptionalString(json['model']),
      year: asInt(json['year']),
      notes: asOptionalString(json['notes']),
    );
  }

  final String id;
  final String vin;
  final String? name;
  final String? make;
  final String? model;
  final int? year;
  final String? notes;

  /// The name the customer gave, otherwise "make model year", otherwise the VIN.
  String get title {
    final String? given = name;
    if (given != null && given.trim().isNotEmpty) {
      return given.trim();
    }
    final String described = <String?>[make, model, year?.toString()]
        .whereType<String>()
        .where((String s) => s.trim().isNotEmpty)
        .join(' ');
    return described.isEmpty ? vin : described;
  }

  /// "make model year" (empty when none is known).
  String get description {
    return <String?>[make, model, year?.toString()]
        .whereType<String>()
        .where((String s) => s.trim().isNotEmpty)
        .join(' ');
  }
}

/// A pending request to delete the account (GET /api/account/deletion).
class DeletionRequest {
  const DeletionRequest({required this.dueAt, this.requestedAt});

  factory DeletionRequest.fromJson(Map<String, dynamic> json) {
    final DateTime? due = asDate(json['dueAt']);
    return DeletionRequest(
      dueAt: due ?? DateTime.now().add(const Duration(days: 30)),
      requestedAt: asDate(json['requestedAt']),
    );
  }

  final DateTime dueAt;
  final DateTime? requestedAt;

  /// Whole days left before the deletion happens (at least 0).
  int get daysLeft {
    final int days = dueAt.difference(DateTime.now()).inHours;
    return days <= 0 ? 0 : (days / 24).ceil();
  }
}

class SpecialRequest {
  const SpecialRequest({
    required this.id,
    required this.brand,
    required this.partName,
    required this.status,
    this.otherBrand,
    this.quotedPrice,
    this.adminNote = '',
    this.createdAt,
  });

  factory SpecialRequest.fromJson(Map<String, dynamic> json) {
    return SpecialRequest(
      id: asString(json['id']),
      brand: asString(json['brand']),
      otherBrand: asOptionalString(json['other_brand']),
      partName: asString(json['part_name']),
      quotedPrice: asDouble(json['quoted_price']),
      status: asString(json['status']),
      adminNote: asString(json['admin_note']),
      createdAt: asDate(json['created_at']),
    );
  }

  final String id;
  final String brand;
  final String? otherBrand;
  final String partName;
  final double? quotedPrice;
  final String status;
  final String adminNote;
  final DateTime? createdAt;

  /// The brand the customer typed when they chose "other", otherwise the chosen brand.
  String get brandLabel {
    final String? other = otherBrand;
    if (brand == otherLabel && other != null && other.isNotEmpty) {
      return other;
    }
    return brand;
  }
}

class LedgerEntry {
  const LedgerEntry({
    required this.id,
    required this.type,
    required this.amount,
    required this.balanceAfter,
    this.note,
    this.createdAt,
  });

  factory LedgerEntry.fromJson(Map<String, dynamic> json) {
    return LedgerEntry(
      id: asString(json['id']),
      type: asString(json['tx_type']),
      amount: asDouble(json['amount']) ?? 0.0,
      balanceAfter: asDouble(json['balance_after']) ?? 0.0,
      note: asOptionalString(json['note']),
      createdAt: asDate(json['created_at']),
    );
  }

  final String id;

  /// debit or payment.
  final String type;
  final double amount;
  final double balanceAfter;
  final String? note;
  final DateTime? createdAt;

  bool get isPayment => type == 'payment';
}

/// Payload of GET /api/workshop/dashboard.
class WorkshopDashboard {
  const WorkshopDashboard({
    required this.name,
    required this.debtBalance,
    required this.cashbackBalance,
    this.tier,
    this.debtLimit,
    this.orders = const <Order>[],
    this.ledger = const <LedgerEntry>[],
    this.userJson = const <String, dynamic>{},
  });

  factory WorkshopDashboard.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> user = asMap(json['user']);
    return WorkshopDashboard(
      name: asString(user['name']),
      tier: asOptionalString(user['tier']),
      debtLimit: asDouble(user['debt_limit']),
      debtBalance: asDouble(user['debt_balance']) ?? 0.0,
      cashbackBalance: asDouble(user['cashback_balance']) ?? 0.0,
      orders: asList(json['orders']).map((Object? e) => Order.fromJson(asMap(e))).toList(),
      ledger: asList(json['ledger']).map((Object? e) => LedgerEntry.fromJson(asMap(e))).toList(),
      userJson: user,
    );
  }

  final String name;
  final String? tier;
  final double? debtLimit;
  final double debtBalance;
  final double cashbackBalance;
  final List<Order> orders;
  final List<LedgerEntry> ledger;

  /// The `user` object exactly as received, used to refresh the cached account.
  final Map<String, dynamic> userJson;

  /// Orders that are not cancelled and were paid in cash or with Sham Cash.
  List<Order> get cashOrders => orders
      .where((Order o) => o.payMethod != 'debt' && o.status != 'cancelled')
      .toList();

  /// Orders that are not cancelled and were put on the debt ledger.
  List<Order> get debtOrders => orders
      .where((Order o) => o.payMethod == 'debt' && o.status != 'cancelled')
      .toList();

  /// Total of orders an admin has approved (approved, shipped or delivered).
  double get approvedSpend {
    double sum = 0.0;
    for (final Order o in orders) {
      if (o.status == 'approved' || o.status == 'shipped' || o.status == 'delivered') {
        sum += o.total;
      }
    }
    return sum;
  }

  int get tierIndex {
    final double spend = approvedSpend;
    int index = 0;
    for (int i = 0; i < estimatedTiers.length; i++) {
      if (spend >= estimatedTiers[i].minSpend) {
        index = i;
      }
    }
    return index;
  }

  TierStep get currentTier => estimatedTiers[tierIndex];

  TierStep? get nextTier {
    final int next = tierIndex + 1;
    return next < estimatedTiers.length ? estimatedTiers[next] : null;
  }

  /// Progress towards the next tier from 0 to 1 (1 when already at the top).
  double get tierProgress {
    final TierStep? next = nextTier;
    if (next == null) {
      return 1.0;
    }
    final double span = next.minSpend - currentTier.minSpend;
    if (span <= 0) {
      return 1.0;
    }
    final double value = (approvedSpend - currentTier.minSpend) / span;
    if (value < 0) {
      return 0.0;
    }
    return value > 1 ? 1.0 : value;
  }

  /// Days left of the 30-day repayment window, counted from the latest debit entry that left a balance.
  /// Null when there is no such entry.
  int? debtDaysLeft(DateTime now) {
    for (final LedgerEntry entry in ledger) {
      if (entry.type == 'debit' && entry.balanceAfter > 0) {
        final DateTime? when = entry.createdAt;
        if (when == null) {
          return null;
        }
        final int elapsed = now.difference(when).inDays;
        final int left = debtWindowDays - elapsed;
        return left < 0 ? 0 : left;
      }
    }
    return null;
  }
}

class Commissions {
  const Commissions({
    this.available = 0.0,
    this.held = 0.0,
    this.paid = 0.0,
    this.total = 0.0,
  });

  factory Commissions.fromJson(Map<String, dynamic> json) {
    return Commissions(
      available: asDouble(json['available']) ?? 0.0,
      held: asDouble(json['held']) ?? 0.0,
      paid: asDouble(json['paid']) ?? 0.0,
      total: asDouble(json['total']) ?? 0.0,
    );
  }

  final double available;
  final double held;
  final double paid;
  final double total;
}

/// Payload of GET /api/marketer/dashboard.
class MarketerDashboard {
  const MarketerDashboard({
    required this.name,
    required this.code,
    required this.referralUrl,
    this.workshops = 0,
    this.commissions = const Commissions(),
  });

  factory MarketerDashboard.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> marketer = asMap(json['marketer']);
    return MarketerDashboard(
      name: asString(marketer['name']),
      code: asString(marketer['code']),
      referralUrl: asString(marketer['referralUrl']),
      workshops: asInt(json['workshops']) ?? 0,
      commissions: Commissions.fromJson(asMap(json['commissions'])),
    );
  }

  final String name;
  final String code;
  final String referralUrl;
  final int workshops;
  final Commissions commissions;
}

/// Result of POST /api/orders.
class PlacedOrder {
  const PlacedOrder({
    required this.orderId,
    required this.pay,
    required this.total,
    this.orderNumber,
  });

  factory PlacedOrder.fromJson(Map<String, dynamic> json) {
    return PlacedOrder(
      orderId: asString(json['orderId']),
      orderNumber: asInt(json['orderNumber']),
      pay: asString(json['pay']),
      total: asDouble(json['total']) ?? 0.0,
    );
  }

  final String orderId;
  final int? orderNumber;
  final String pay;
  final double total;
}

/// What a sign-in or registration attempt led to.
enum AuthResultKind { signedIn, pendingApproval, failed }

class AuthResult {
  const AuthResult(this.kind, [this.message = '']);

  final AuthResultKind kind;
  final String message;

  bool get isSignedIn => kind == AuthResultKind.signedIn;
  bool get isPending => kind == AuthResultKind.pendingApproval;
}
