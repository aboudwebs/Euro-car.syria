import 'package:euro_cars/core/labels.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses the final 90-day EURO loyalty thresholds and cashback rates', () {
    expect(estimatedTiers, hasLength(6));
    expect(
      estimatedTiers.map((TierStep tier) => <Object>[tier.minSpend, tier.cashback]).toList(),
      <List<Object>>[
        <Object>[0, '0%'],
        <Object>[10000, '2%'],
        <Object>[15000, '5%'],
        <Object>[20000, '7%'],
        <Object>[30000, '10%'],
        <Object>[50000, '15%'],
      ],
    );
  });
}
