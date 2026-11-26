// The VIN scanner screen with a fake camera and a fake text reader (no plugin is touched).

import 'package:euro_cars/core/vin_ocr.dart';
import 'package:euro_cars/screens/catalog/vin_scanner_screen.dart';
import 'package:euro_cars/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

class _FakeReader implements VinTextReader {
  _FakeReader(this.lines, {this.fails = false});

  final List<String> lines;
  final bool fails;

  @override
  Future<List<String>> readLines(String imagePath) async {
    if (fails) {
      throw StateError('ocr failed');
    }
    return lines;
  }
}

/// Opens the scanner on top of a page and records what it returned.
Future<void> pumpScanner(
  WidgetTester tester, {
  required VinTextReader reader,
  required Future<XFile?> Function(ImageSource source) picker,
  required List<String?> results,
}) async {
  tester.view.physicalSize = const Size(1080, 2160);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildTheme(Brightness.dark),
      home: Builder(
        builder: (BuildContext context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () async {
                final String? vin = await Navigator.of(context).push<String>(
                  MaterialPageRoute<String>(
                    builder: (BuildContext _) => VinScannerScreen(
                      confirmLabel: 'بحث بهذا الرقم',
                      reader: reader,
                      picker: picker,
                    ),
                  ),
                );
                results.add(vin);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a denied camera permission shows a clear message and keeps the manual option', (WidgetTester tester) async {
    final List<String?> results = <String?>[];
    await pumpScanner(
      tester,
      reader: _FakeReader(const <String>[]),
      picker: (ImageSource source) async => throw PlatformException(code: 'camera_access_denied'),
      results: results,
    );

    await tester.tap(find.text('فتح الكاميرا'));
    await tester.pumpAndSettle();

    expect(find.text(cameraDeniedMessage), findsOneWidget);
    expect(find.text('كتابة الرقم يدوياً'), findsOneWidget);
  });

  testWidgets('cancelling the camera leaves the start page unchanged', (WidgetTester tester) async {
    final List<String?> results = <String?>[];
    await pumpScanner(
      tester,
      reader: _FakeReader(const <String>[]),
      picker: (ImageSource source) async => null,
      results: results,
    );

    await tester.tap(find.text('فتح الكاميرا'));
    await tester.pumpAndSettle();

    expect(find.text('فتح الكاميرا'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('a failed text reading says so and does not search', (WidgetTester tester) async {
    final List<String?> results = <String?>[];
    await pumpScanner(
      tester,
      reader: _FakeReader(const <String>[], fails: true),
      picker: (ImageSource source) async => XFile('photo.jpg'),
      results: results,
    );

    await tester.tap(find.text('فتح الكاميرا'));
    await tester.pumpAndSettle();

    expect(find.text(ocrFailedMessage), findsOneWidget);
    expect(results, isEmpty);
  });

  testWidgets('the number read from the photo is shown, can be corrected, and is returned only on confirmation',
      (WidgetTester tester) async {
    final List<String?> results = <String?>[];
    await pumpScanner(
      tester,
      reader: _FakeReader(const <String>['VIN: 1M8GDM9AXKP042788']),
      picker: (ImageSource source) async => XFile('photo.jpg'),
      results: results,
    );

    await tester.tap(find.text('فتح الكاميرا'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, '1M8GDM9AXKP042788'), findsOneWidget);
    expect(find.text('رقم شاصي صحيح الشكل: 17 خانة.'), findsOneWidget);
    expect(results, isEmpty, reason: 'nothing leaves the screen before the user confirms');

    // A manual correction to an older, shorter number is accepted with a warning, not refused.
    await tester.enterText(find.byType(TextField), 'abc12');
    await tester.pump();
    expect(find.textContaining('عدد الخانات 5 وليس 17'), findsOneWidget);

    await tester.tap(find.text('بحث بهذا الرقم'));
    await tester.pumpAndSettle();
    expect(results, <String?>['ABC12']);
  });

  testWidgets('a number that cannot be a chassis number cannot be confirmed', (WidgetTester tester) async {
    final List<String?> results = <String?>[];
    await pumpScanner(
      tester,
      reader: _FakeReader(const <String>['1M8GDM9AXKP042788']),
      picker: (ImageSource source) async => XFile('photo.jpg'),
      results: results,
    );

    await tester.tap(find.text('فتح الكاميرا'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'AB1');
    await tester.pump();

    await tester.tap(find.text('بحث بهذا الرقم'));
    await tester.pumpAndSettle();

    expect(find.text('اكتب 5 خانات على الأقل (أحرف إنجليزية وأرقام فقط).'), findsOneWidget);
    expect(results, isEmpty);
  });

  testWidgets('when nothing readable is found the user is told and can type the number', (WidgetTester tester) async {
    final List<String?> results = <String?>[];
    await pumpScanner(
      tester,
      reader: _FakeReader(const <String>['hello world']),
      picker: (ImageSource source) async => XFile('photo.jpg'),
      results: results,
    );

    await tester.tap(find.text('فتح الكاميرا'));
    await tester.pumpAndSettle();

    expect(find.text(noVinFoundMessage), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });
}
