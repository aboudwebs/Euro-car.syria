import 'package:euro_cars/core/vin.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('cleanVin', () {
    test('keeps capital letters and digits only', () {
      expect(cleanVin(' wba-3a5c5 5fk 123456 '), 'WBA3A5C55FK123456');
    });

    test('converts Arabic-Indic digits', () {
      expect(cleanVin('١٢٣ab'), '123AB');
    });
  });

  group('checkVin', () {
    test('a 17 character number without I, O, Q is a standard VIN', () {
      expect(checkVin('1M8GDM9AXKP042788'), VinShape.standard);
      expect(checkVin('  1m8gdm9axkp042788 '), VinShape.standard);
    });

    test('17 characters with I, O or Q are flagged but not refused', () {
      expect(checkVin('1M8GDM9AXKP04278O'), VinShape.standardLength);
      expect(isAcceptableChassis('1M8GDM9AXKP04278O'), isTrue);
    });

    test('other lengths between 5 and 32 are accepted (older or special numbers)', () {
      expect(checkVin('ABC12'), VinShape.other);
      expect(checkVin('WDB1240231A123456789'), VinShape.other);
      expect(checkVin('JT-2AE-91-12345'), VinShape.other);
      expect(isAcceptableChassis('ABC12'), isTrue);
    });

    test('too short, too long or with other characters is invalid', () {
      expect(checkVin(''), VinShape.invalid);
      expect(checkVin('AB12'), VinShape.invalid);
      expect(checkVin('A' * 33), VinShape.invalid);
      expect(checkVin('ABC 12 #'), VinShape.invalid);
      expect(isAcceptableChassis('AB12'), isFalse);
    });
  });

  group('vinCheckDigitMatches', () {
    test('accepts a VIN whose ninth character is the right check digit', () {
      expect(vinCheckDigitMatches('1M8GDM9AXKP042788'), isTrue);
    });

    test('rejects a changed digit and a wrong length', () {
      expect(vinCheckDigitMatches('1M8GDM9A1KP042788'), isFalse);
      expect(vinCheckDigitMatches('1M8GDM9AX'), isFalse);
    });
  });

  group('extractVinCandidates', () {
    test('finds a VIN in a line of recognised text', () {
      final List<VinCandidate> found = extractVinCandidates(<String>['VIN: 1M8GDM9AXKP042788', 'MADE IN USA']);
      expect(found, isNotEmpty);
      expect(found.first.value, '1M8GDM9AXKP042788');
    });

    test('repairs the letters O, Q and I that the camera reads instead of 0 and 1', () {
      final List<VinCandidate> found = extractVinCandidates(<String>['1M8GDM9AXKPO42788']);
      expect(found.map((VinCandidate c) => c.value), contains('1M8GDM9AXKP042788'));
    });

    test('joins a number split over two lines', () {
      final List<VinCandidate> found = extractVinCandidates(<String>['1M8GDM9AX', 'KP042788']);
      expect(found.map((VinCandidate c) => c.value), contains('1M8GDM9AXKP042788'));
    });

    test('ignores phone numbers and plain words', () {
      expect(extractVinCandidates(<String>['00963982026134123']), isEmpty);
      expect(extractVinCandidates(<String>['ABCDEFGHJKLMNPRST']), isEmpty);
    });

    test('returns nothing for empty input', () {
      expect(extractVinCandidates(const <String>[]), isEmpty);
    });
  });

  group('bestPartialVin', () {
    test('offers the closest mixed letters-and-digits line so it can be corrected by hand', () {
      expect(bestPartialVin(<String>['hello', '1M8GDM9AXKP0427']), '1M8GDM9AXKP0427');
    });

    test('returns null when nothing looks like a chassis number', () {
      expect(bestPartialVin(<String>['hello', 'world']), isNull);
    });
  });
}
