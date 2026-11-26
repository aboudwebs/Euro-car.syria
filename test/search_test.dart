import 'package:euro_cars/core/config.dart';
import 'package:euro_cars/core/models.dart';
import 'package:euro_cars/core/search.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fixtures.dart';

void main() {
  final Part oilFilter = makePart(
    id: 'p1',
    name: 'فلتر زيت',
    brand: 'BMW',
    pn: 'A 276-180',
    model: 'X5',
    years: '2015-2019',
    branch: 'حلب',
  );
  final Part brakePads = makePart(
    id: 'p2',
    name: 'تيل فرامل أمامي',
    brand: 'Mercedes-Benz',
    pn: 'B 123456',
    model: 'C200',
    years: '2010-2014',
    branch: 'دمشق',
  );
  final Part airFilter = makePart(
    id: 'p3',
    name: 'فلتر هواء',
    brand: 'Audi',
    pn: 'AU-998877',
    model: 'A4',
  );
  final List<Part> catalog = <Part>[oilFilter, brakePads, airFilter];

  List<String> ids(List<Part> parts) => parts.map((Part p) => p.id).toList();

  group('filterParts', () {
    test('an empty query and brand returns everything', () {
      expect(ids(filterParts(catalog)), <String>['p1', 'p2', 'p3']);
    });

    test('filters by brand', () {
      expect(ids(filterParts(catalog, brand: 'BMW')), <String>['p1']);
      expect(ids(filterParts(catalog, brand: 'Porsche')), isEmpty);
    });

    test('matches words of the name', () {
      expect(ids(filterParts(catalog, query: 'فلتر')), <String>['p1', 'p3']);
    });

    test('needs every word of the query', () {
      expect(ids(filterParts(catalog, query: 'فلتر زيت')), <String>['p1']);
    });

    test('ignores letter case', () {
      expect(ids(filterParts(catalog, query: 'BMW')), <String>['p1']);
      expect(ids(filterParts(catalog, query: 'bmw')), <String>['p1']);
    });

    test('matches an OEM number however it is separated', () {
      expect(ids(filterParts(catalog, query: 'A276180')), <String>['p1']);
      expect(ids(filterParts(catalog, query: 'a 276-180')), <String>['p1']);
      expect(ids(filterParts(catalog, query: 'A 276 180')), <String>['p1']);
      expect(ids(filterParts(catalog, query: 'AU998877')), <String>['p3']);
    });

    test('matches model and years', () {
      expect(ids(filterParts(catalog, query: 'x5')), <String>['p1']);
      expect(ids(filterParts(catalog, query: '2015')), <String>['p1']);
      expect(ids(filterParts(catalog, query: 'a4')), <String>['p3']);
    });

    test('matches Arabic spelling variants and Arabic digits', () {
      expect(ids(filterParts(catalog, query: 'أمامي')), <String>['p2']);
      expect(ids(filterParts(catalog, query: 'امامي')), <String>['p2']);
      expect(ids(filterParts(catalog, query: '٢٠١٠')), <String>['p2']);
    });

    test('combines the query with the brand', () {
      expect(ids(filterParts(catalog, query: 'فلتر', brand: 'Audi')), <String>['p3']);
      expect(ids(filterParts(catalog, query: 'فلتر', brand: 'Mercedes-Benz')), isEmpty);
    });

    test('returns nothing when no part matches', () {
      expect(filterParts(catalog, query: 'zzzz'), isEmpty);
    });

    test('a VIN-like query does not hide anything', () {
      expect(ids(filterParts(catalog, query: 'WBA3A5C51CF256651')), <String>['p1', 'p2', 'p3']);
      expect(ids(filterParts(catalog, query: 'WBA3A5C51CF256651', brand: 'Audi')), <String>['p3']);
    });
  });

  group('catalogBrands', () {
    test('lists the known brands first, then any other brand in the catalog once', () {
      final List<Part> parts = <Part>[
        makePart(brand: 'BMW'),
        makePart(brand: 'Porsche'),
        makePart(brand: ' Porsche '),
        makePart(brand: ''),
        makePart(brand: 'Toyota'),
      ];
      expect(
        catalogBrands(parts),
        <String>[...carBrands, 'Porsche', 'Toyota'],
      );
    });

    test('without parts it is the known brands', () {
      expect(catalogBrands(const <Part>[]), carBrands);
    });
  });

  group('sections (categories)', () {
    final Part brakes = makePart(id: 'c1', name: 'تيل فرامل', category: 'الفرامل');
    final Part discs = makePart(id: 'c2', name: 'قرص فرامل', category: 'الفرامل');
    final Part filter = makePart(id: 'c3', name: 'فلتر زيت', category: 'الفلاتر');
    final Part loose = makePart(id: 'c4', name: 'قطعة بلا قسم');
    final List<Part> parts = <Part>[brakes, discs, filter, loose];

    test('a section shows only its own parts', () {
      expect(ids(filterParts(parts, category: 'الفرامل')), <String>['c1', 'c2']);
      expect(ids(filterParts(parts, category: 'الفلاتر')), <String>['c3']);
    });

    test('an empty section means every part, including those without a section', () {
      expect(ids(filterParts(parts)), <String>['c1', 'c2', 'c3', 'c4']);
    });

    test('search and brand still work inside a section', () {
      expect(ids(filterParts(parts, category: 'الفرامل', query: 'قرص')), <String>['c2']);
      expect(ids(filterParts(parts, category: 'الفرامل', brand: 'Audi')), isEmpty);
    });

    test('catalogCategories lists each section once, sorted, without the empty one', () {
      expect(catalogCategories(parts), <String>['الفرامل', 'الفلاتر']);
      expect(catalogCategories(<Part>[loose]), isEmpty);
    });
  });
}
