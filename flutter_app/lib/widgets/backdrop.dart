// The page background of the web app: the canvas colour plus two soft "ambient orbs" (blue near the top corner,
// indigo near the bottom corner) and, in the light theme, a gentle colour wash. The web app blurs real circles with
// CSS; here the same glow is a radial gradient, painted once and cached by a RepaintBoundary. Nothing animates, so
// the background costs nothing while scrolling.

import 'package:flutter/material.dart';

import '../theme/palette.dart';

class AppBackdrop extends StatelessWidget {
  const AppBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        RepaintBoundary(
          child: CustomPaint(
            painter: _BackdropPainter(isDark: p.isDark, bg: p.bg, orbOpacity: p.orbOpacity),
          ),
        ),
        child,
      ],
    );
  }
}

class _BackdropPainter extends CustomPainter {
  const _BackdropPainter({required this.isDark, required this.bg, required this.orbOpacity});

  final bool isDark;
  final Color bg;
  final double orbOpacity;

  static const Color _blue = Color(0xFF0A84FF);
  static const Color _washBlue = Color(0xFF007AFF);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }
    canvas.clipRect(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, Paint()..color = bg);
    if (!isDark) {
      _wash(canvas, Offset(size.width * 0.15, size.height * 0.10), size.width * 0.66, size.height * 0.70, _washBlue, 0.10);
      _wash(canvas, Offset(size.width * 0.85, size.height * 0.85), size.width * 0.66, size.height * 0.66, orbIndigo, 0.08);
    }
    // 320 px circles sitting 96 px outside the top-right and bottom-left corners (-top-24 -right-24 / -bottom-24 -left-24).
    _orb(canvas, Offset(size.width - 64, 64), _blue, 0.15 * orbOpacity);
    _orb(canvas, Offset(64, size.height - 64), orbIndigo, 0.15 * orbOpacity);
  }

  /// A wide elliptical wash that fades to nothing at its edge.
  void _wash(Canvas canvas, Offset center, double rx, double ry, Color color, double alpha) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(1, ry / rx);
    final Rect box = Rect.fromCircle(center: Offset.zero, radius: rx);
    final Paint paint = Paint()
      ..shader = RadialGradient(
        colors: <Color>[color.withValues(alpha: alpha), color.withValues(alpha: 0)],
      ).createShader(box);
    canvas.drawCircle(Offset.zero, rx, paint);
    canvas.restore();
  }

  /// The profile of a heavily blurred disc: strongest in the middle, fading smoothly over ~420 px.
  void _orb(Canvas canvas, Offset center, Color color, double alpha) {
    const double reach = 420;
    final Rect box = Rect.fromCircle(center: center, radius: reach);
    final Paint paint = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          color.withValues(alpha: alpha * 0.65),
          color.withValues(alpha: alpha * 0.56),
          color.withValues(alpha: alpha * 0.35),
          color.withValues(alpha: alpha * 0.12),
          color.withValues(alpha: 0),
        ],
        stops: const <double>[0, 0.22, 0.45, 0.7, 1],
      ).createShader(box);
    canvas.drawCircle(center, reach, paint);
  }

  @override
  bool shouldRepaint(_BackdropPainter oldDelegate) {
    return oldDelegate.isDark != isDark || oldDelegate.bg != bg || oldDelegate.orbOpacity != orbOpacity;
  }
}
