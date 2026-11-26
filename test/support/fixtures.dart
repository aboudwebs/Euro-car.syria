// Sample accounts and catalog rows shaped exactly like the API's JSON.

import 'package:euro_cars/core/models.dart';

Map<String, dynamic> workshopJson({
  String id = 'w1',
  double debtLimit = 1000,
  double debtBalance = 100,
}) {
  return <String, dynamic>{
    'id': id,
    'role': 'workshop',
    'name': 'ورشة النور',
    'phone': '0982026134',
    'city': 'حلب',
    'license': 'L-100',
    'specs': <String>['BMW'],
    'tier': 'Bronze',
    'debt_limit': debtLimit,
    'debt_balance': debtBalance,
    'cashback_balance': 0,
    'my_ref_code': null,
    'is_active': true,
  };
}

Map<String, dynamic> marketerJson({String id = 'm1'}) {
  return <String, dynamic>{
    'id': id,
    'role': 'marketer',
    'name': 'مسوّق الشمال',
    'phone': '0933000111',
    'my_ref_code': 'MK-1A2B3C',
    'is_active': true,
  };
}

Map<String, dynamic> adminJson() {
  return <String, dynamic>{
    'id': 'a1',
    'role': 'admin',
    'name': 'الإدارة',
    'phone': '0900000000',
  };
}

/// p1: plenty in stock, p2: three left, p3: sold out.
List<Map<String, dynamic>> catalogJson() {
  return <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 'p1',
      'name': 'فلتر زيت',
      'brand': 'BMW',
      'pn': 'A 276-180',
      'price': 10.5,
      'stock': 10,
      'model': 'X5',
      'years': '2015-2019',
      'branch': 'حلب',
    },
    <String, dynamic>{
      'id': 'p2',
      'name': 'تيل فرامل أمامي',
      'brand': 'Mercedes-Benz',
      'pn': 'B 123456',
      'price': 40,
      'stock': 3,
    },
    <String, dynamic>{
      'id': 'p3',
      'name': 'مرآة جانبية',
      'brand': 'Audi',
      'pn': 'AU-1',
      'price': 25,
      'stock': 0,
    },
  ];
}

Part makePart({
  String id = 'p',
  String name = 'قطعة',
  String brand = 'BMW',
  String pn = 'PN-1',
  double price = 10,
  int stock = 5,
  String model = '',
  String years = '',
  String branch = '',
  String? category,
}) {
  return Part(
    id: id,
    name: name,
    brand: brand,
    pn: pn,
    price: price,
    stock: stock,
    model: model,
    years: years,
    branch: branch,
    category: category,
  );
}
