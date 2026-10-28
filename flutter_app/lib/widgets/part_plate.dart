// The part number and the brand mark. Part numbers are shown the way the web app shows them: a small left-to-right
// code line (long-press copies it). The brand mark is the "اليورو" wordmark of the web app's header.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/palette.dart';

class PartNumberPlate extends StatelessWidget {
  const PartNumberPlate({super.key, required this.number, this.large = false});

  final String number;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    final String text = number.trim().isEmpty ? '—' : number.trim();

    final Widget code = Directionality(
      textDirection: TextDirection.ltr,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: codeFont,
          fontWeight: large ? FontWeight.w700 : FontWeight.w500,
          fontSize: large ? 18 : 12.5,
          letterSpacing: 0.5,
          color: large ? p.text : p.muted.withValues(alpha: 0.85),
        ),
      ),
    );

    return Semantics(
      label: 'رقم القطعة $text',
      child: GestureDetector(
        onLongPress: () {
          Clipboard.setData(ClipboardData(text: text));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم نسخ رقم القطعة')),
          );
        },
        child: code,
      ),
    );
  }
}

/// The "اليورو" wordmark: semibold, tight tracking, in the text colour (the web app's header logo).
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 26});

  final double size;

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    return Text(
      'اليورو',
      style: TextStyle(
        fontFamily: appFont,
        fontWeight: FontWeight.w700,
        fontSize: size,
        letterSpacing: -0.3,
        color: p.text,
        height: 1.2,
      ),
    );
  }
}
