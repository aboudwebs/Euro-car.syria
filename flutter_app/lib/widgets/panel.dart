// Basic surfaces: the glass card of the web app (`.card`), a section heading and a label / value row.

import 'package:flutter/material.dart';

import '../theme/palette.dart';

/// The glass card: a vertical gradient fill, a hairline edge that is brighter at the top, 24 px corners and a soft
/// shadow. Tappable when [onTap] is given (the ripple stays inside the rounded corners).
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.onTap,
    this.color,
    this.borderColor,
    this.radius = 24,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  /// A flat fill that replaces the glass gradient (used for tinted, highlighted cards).
  final Color? color;
  final Color? borderColor;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    final BorderRadius shape = BorderRadius.circular(radius);
    final Color? fill = color;
    final VoidCallback? tap = onTap;
    final Color? edge = borderColor;

    Widget content = Padding(padding: padding, child: child);
    if (tap != null) {
      content = InkWell(onTap: tap, child: content);
    }

    final Widget surface = DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        gradient: fill == null
            ? LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[p.surfaceTop, p.surfaceBottom],
              )
            : null,
        borderRadius: shape,
        boxShadow: p.cardShadow,
      ),
      child: CustomPaint(
        foregroundPainter: EdgePainter(radius: radius, top: edge ?? p.edgeTop, bottom: edge ?? p.line),
        child: ClipRRect(
          borderRadius: shape,
          child: Material(type: MaterialType.transparency, child: content),
        ),
      ),
    );

    final EdgeInsetsGeometry? outer = margin;
    if (outer == null) {
      return surface;
    }
    return Padding(padding: outer, child: surface);
  }
}

/// Paints a one pixel rounded edge whose colour runs from [top] to [bottom]. Flutter has no gradient borders, and
/// this is what gives the glass cards their brighter upper edge in the dark theme.
class EdgePainter extends CustomPainter {
  const EdgePainter({required this.radius, required this.top, required this.bottom, this.width = 1});

  final double radius;
  final Color top;
  final Color bottom;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }
    final Rect rect = Offset.zero & size;
    final double inset = width / 2;
    final double corner = radius > inset ? radius - inset : 0;
    final RRect edge = RRect.fromRectAndRadius(rect.deflate(inset), Radius.circular(corner));
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[top, bottom],
        stops: const <double>[0, 0.5],
      ).createShader(rect);
    canvas.drawRRect(edge, paint);
  }

  @override
  bool shouldRepaint(EdgePainter oldDelegate) {
    return oldDelegate.radius != radius ||
        oldDelegate.top != top ||
        oldDelegate.bottom != bottom ||
        oldDelegate.width != width;
  }
}

/// A heading above a group of content, with an optional trailing widget.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing, this.padding});

  final String text;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    final Widget? end = trailing;
    return Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(2, 18, 2, 10),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: p.text,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          ),
          if (end != null) end,
        ],
      ),
    );
  }
}

/// One label with its value, used in summaries.
class InfoRow extends StatelessWidget {
  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.ltr = false,
    this.bold = false,
  });

  final String label;
  final String value;
  final Color? valueColor;

  /// Force left-to-right for phone numbers, codes and links.
  final bool ltr;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: TextStyle(color: p.muted, fontSize: 14)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              textDirection: ltr ? TextDirection.ltr : null,
              style: TextStyle(
                color: valueColor ?? p.text,
                fontSize: 14,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A tinted box with a short message, used for the admin's notes and cancellation reasons.
class NoteBox extends StatelessWidget {
  const NoteBox({super.key, required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    final bool danger = color == p.err;
    final Color ink = danger ? p.errText : p.text.withValues(alpha: 0.85);
    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.28)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Text(text, style: TextStyle(color: ink, fontSize: 13, height: 1.6)),
        ),
      ),
    );
  }
}
