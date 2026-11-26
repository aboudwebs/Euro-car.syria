import 'package:euro_cars/core/referral.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseReferral', () {
    test('empty and blank text give an empty referral', () {
      expect(parseReferral('').isEmpty, isTrue);
      expect(parseReferral('   ').isEmpty, isTrue);
    });

    test('a plain code stays as typed and is not signed', () {
      final ReferralInput input = parseReferral('  MK-1A2B3C ');
      expect(input.code, 'MK-1A2B3C');
      expect(input.signature, '');
      expect(input.isSigned, isFalse);
      expect(input.isEmpty, isFalse);
    });

    test('reads the code and signature of an invitation link', () {
      final ReferralInput input = parseReferral('https://euro.example/login?ref=MK-1A2B3C&sig=abcDEF123');
      expect(input.code, 'MK-1A2B3C');
      expect(input.signature, 'abcDEF123');
      expect(input.isSigned, isTrue);
    });

    test('reads the signed referral from the Android deep link', () {
      final ReferralInput input = parseReferral('eurocars://referral?ref=MK-1A2B3C&sig=abcDEF123');
      expect(input.code, 'MK-1A2B3C');
      expect(input.signature, 'abcDEF123');
      expect(input.isSigned, isTrue);
    });

    test('ignores a fragment after the query', () {
      final ReferralInput input = parseReferral('https://euro.example/login?ref=MK-1&sig=ab#section');
      expect(input.code, 'MK-1');
      expect(input.signature, 'ab');
    });

    test('accepts only the query part without a question mark', () {
      final ReferralInput input = parseReferral('ref=MK-9&sig=zz');
      expect(input.code, 'MK-9');
      expect(input.signature, 'zz');
    });

    test('a link without a signature gives an unsigned code', () {
      final ReferralInput input = parseReferral('https://euro.example/login?ref=MK-5');
      expect(input.code, 'MK-5');
      expect(input.isSigned, isFalse);
    });

    test('decodes percent escapes', () {
      final ReferralInput input = parseReferral('https://euro.example/login?ref=MK%2D1A&sig=a%2Fb');
      expect(input.code, 'MK-1A');
      expect(input.signature, 'a/b');
    });

    test('limits the code to 80 characters', () {
      final String long = 'M' * 200;
      expect(parseReferral(long).code, hasLength(80));
      final ReferralInput linked = parseReferral('https://euro.example/login?ref=$long&sig=abc');
      expect(linked.code, hasLength(80));
      expect(linked.signature, 'abc');
    });

    test('broken escapes and non-ASCII text in a link never throw', () {
      expect(() => parseReferral('https://euro.example/login?ref=%ZZ'), returnsNormally);
      expect(() => parseReferral('https://euro.example/login?ref=%'), returnsNormally);
      expect(() => parseReferral('ref=كود'), returnsNormally);
      expect(parseReferral('ref=%ZZ').isEmpty, isFalse);
    });
  });
}
