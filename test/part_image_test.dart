import 'package:euro_cars/widgets/part_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isShowableImageUrl', () {
    test('accepts absolute http(s) addresses, also with spaces around them', () {
      expect(isShowableImageUrl('https://abc.supabase.co/storage/v1/object/public/parts-images/u/1.jpg'), isTrue);
      expect(isShowableImageUrl('http://example.com/a.png'), isTrue);
      expect(isShowableImageUrl('  https://example.com/a.webp  '), isTrue);
    });

    test('rejects empty values, storage paths and other schemes', () {
      expect(isShowableImageUrl(null), isFalse);
      expect(isShowableImageUrl(''), isFalse);
      expect(isShowableImageUrl('   '), isFalse);
      expect(isShowableImageUrl('parts-images/u/1.jpg'), isFalse);
      expect(isShowableImageUrl('/storage/v1/object/public/a.jpg'), isFalse);
      expect(isShowableImageUrl('file:///sdcard/a.jpg'), isFalse);
      expect(isShowableImageUrl('data:image/png;base64,AAAA'), isFalse);
      expect(isShowableImageUrl('https://'), isFalse);
    });
  });

  testWidgets('PartImage keeps its frame and placeholder while the photo is not there yet', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: PartImage(url: 'https://example.com/part.jpg', size: 88)),
        ),
      ),
    );

    expect(find.byType(Image), findsOneWidget);
    expect(find.byIcon(Icons.image_outlined), findsOneWidget);
    expect(tester.getSize(find.byType(PartImage)), const Size(88, 88));
  });
}
