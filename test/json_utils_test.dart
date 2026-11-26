import 'package:euro_cars/core/json_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('asDouble', () {
    test('reads numbers and numeric strings', () {
      expect(asDouble(1), 1.0);
      expect(asDouble(2.5), 2.5);
      expect(asDouble(' 3.75 '), 3.75);
      expect(asDouble('10'), 10.0);
    });

    test('is null for anything else', () {
      expect(asDouble(null), isNull);
      expect(asDouble('abc'), isNull);
      expect(asDouble(''), isNull);
      expect(asDouble(true), isNull);
      expect(asDouble(<int>[1]), isNull);
    });
  });

  group('asInt', () {
    test('reads integers, numbers and numeric strings', () {
      expect(asInt(7), 7);
      expect(asInt(7.9), 7);
      expect(asInt('12'), 12);
      expect(asInt(' 12 '), 12);
      expect(asInt('3.8'), 3);
    });

    test('is null for anything else', () {
      expect(asInt(null), isNull);
      expect(asInt('x'), isNull);
      expect(asInt(false), isNull);
    });
  });

  group('asString and asOptionalString', () {
    test('asString never returns null', () {
      expect(asString(null), '');
      expect(asString(null, 'fallback'), 'fallback');
      expect(asString(5), '5');
      expect(asString(1.5), '1.5');
      expect(asString('text'), 'text');
    });

    test('asOptionalString turns null and empty text into null', () {
      expect(asOptionalString(null), isNull);
      expect(asOptionalString(''), isNull);
      expect(asOptionalString('a'), 'a');
      expect(asOptionalString(0), '0');
    });
  });

  group('asDate', () {
    test('parses ISO 8601 text', () {
      final DateTime? parsed = asDate('2026-03-07T10:20:30Z');
      expect(parsed, isNotNull);
      expect(parsed!.isAtSameMomentAs(DateTime.utc(2026, 3, 7, 10, 20, 30)), isTrue);
    });

    test('is null for anything that is not a date', () {
      expect(asDate(null), isNull);
      expect(asDate(5), isNull);
      expect(asDate('garbage'), isNull);
    });
  });

  group('asMap and asList', () {
    test('asMap returns maps and an empty map otherwise', () {
      expect(asMap(<String, dynamic>{'a': 1}), <String, dynamic>{'a': 1});
      expect(asMap(<dynamic, dynamic>{'a': 1}), <String, dynamic>{'a': 1});
      expect(asMap(null), isEmpty);
      expect(asMap(<int>[1]), isEmpty);
      expect(asMap('x'), isEmpty);
    });

    test('asList returns lists and an empty list otherwise', () {
      expect(asList(<int>[1, 2]), <Object?>[1, 2]);
      expect(asList(null), isEmpty);
      expect(asList('x'), isEmpty);
      expect(asList(<String, dynamic>{'a': 1}), isEmpty);
    });
  });
}
