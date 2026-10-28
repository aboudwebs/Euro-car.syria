// Colour tokens. They mirror the web app's theme system (app/globals.css): the dark theme is the original
// "liquid glass" identity (#06080E canvas, translucent white surfaces, #0A84FF accent) and the light theme is the
// clean variant (#EEF3F9 canvas, white cards, #007AFF accent). Status and accent colours are darker in the light
// theme so text on white keeps enough contrast, exactly like the web app does.
//
// `primary`, `ok`, `warn` and `err` are always safe to use as TEXT colours. `accent` is the fill colour used for
// rings, gradients and the cursor.

import 'package:flutter/material.dart';

import '../core/labels.dart';

/// Top and bottom colour of the primary pill button (the web app's `.btn`).
const Color accentGradientTop = Color(0xFF3A9BFD);
const Color accentGradientBottom = Color(0xFF007AFF);

/// Second ambient orb colour of the web app's background.
const Color orbIndigo = Color(0xFF5E5CE6);

class Palette {
  const Palette({
    required this.isDark,
    required this.bg,
    required this.panel,
    required this.panelAlt,
    required this.plate,
    required this.line,
    required this.lineStrong,
    required this.text,
    required this.muted,
    required this.placeholder,
    required this.primary,
    required this.accent,
    required this.brand,
    required this.ok,
    required this.warn,
    required this.err,
    required this.surfaceTop,
    required this.surfaceBottom,
    required this.edgeTop,
    required this.fieldBg,
    required this.fieldLine,
    required this.track,
    required this.menuBg,
    required this.barBg,
    required this.barLine,
    required this.btn2Bg,
    required this.glass1,
    required this.glass2,
    required this.orbOpacity,
    required this.cardShadow,
  });

  final bool isDark;

  /// Screen background.
  final Color bg;

  /// A solid surface for sheets, menus and refresh indicators (the web app's `menu-bg`).
  final Color panel;

  /// Inset areas such as progress tracks.
  final Color panelAlt;

  /// Kept for older call sites; it is the same as the field background.
  final Color plate;
  final Color line;
  final Color lineStrong;
  final Color text;
  final Color muted;
  final Color placeholder;

  /// Accent used for text and icons (darker in the light theme).
  final Color primary;

  /// Accent used for fills, focus rings and the text cursor.
  final Color accent;

  /// Secondary accent (the indigo orb colour).
  final Color brand;
  final Color ok;
  final Color warn;
  final Color err;

  /// Glass card: top and bottom colour of the vertical gradient.
  final Color surfaceTop;
  final Color surfaceBottom;

  /// Colour of the card's top edge (the inset highlight in the dark theme).
  final Color edgeTop;

  /// Inset text fields.
  final Color fieldBg;
  final Color fieldLine;

  /// Segmented-control tracks and progress tracks.
  final Color track;
  final Color menuBg;

  /// Top and bottom glass bars.
  final Color barBg;
  final Color barLine;

  /// Secondary pill button fill.
  final Color btn2Bg;

  /// Faint tints used for unselected tiles (`glass-1`) and the auth mode switch track (`glass-2`).
  final Color glass1;
  final Color glass2;

  /// Opacity of the ambient orbs (toned down in the light theme).
  final double orbOpacity;
  final List<BoxShadow> cardShadow;

  static const Palette dark = Palette(
    isDark: true,
    bg: Color(0xFF06080E),
    panel: Color(0xFF0B0F1A),
    panelAlt: Color(0x66000000),
    plate: Color(0x59000000),
    line: Color(0x26FFFFFF),
    lineStrong: Color(0x40FFFFFF),
    text: Color(0xFFFFFFFF),
    muted: Color(0x99FFFFFF),
    placeholder: Color(0x66FFFFFF),
    primary: Color(0xFF0A84FF),
    accent: Color(0xFF0A84FF),
    brand: Color(0xFF5E5CE6),
    ok: Color(0xFF30D158),
    warn: Color(0xFFFF9F0A),
    err: Color(0xFFFF453A),
    surfaceTop: Color(0x1AFFFFFF),
    surfaceBottom: Color(0x08FFFFFF),
    edgeTop: Color(0x4DFFFFFF),
    fieldBg: Color(0x59000000),
    fieldLine: Color(0x1AFFFFFF),
    track: Color(0x66000000),
    menuBg: Color(0xFF0B0F1A),
    barBg: Color(0xA606080E),
    barLine: Color(0x1FFFFFFF),
    btn2Bg: Color(0x14FFFFFF),
    glass1: Color(0x05FFFFFF),
    glass2: Color(0x0DFFFFFF),
    orbOpacity: 1,
    cardShadow: <BoxShadow>[
      BoxShadow(color: Color(0x47000000), blurRadius: 24, offset: Offset(0, 10)),
    ],
  );

  static const Palette light = Palette(
    isDark: false,
    bg: Color(0xFFEEF3F9),
    panel: Color(0xFFFFFFFF),
    panelAlt: Color(0x0F0F172A),
    plate: Color(0xFFFFFFFF),
    line: Color(0xFFD5DEEA),
    lineStrong: Color(0xFFB8C4D6),
    text: Color(0xFF0F172A),
    muted: Color(0xFF475569),
    placeholder: Color(0xFF64748B),
    primary: Color(0xFF0A63D1),
    accent: Color(0xFF007AFF),
    brand: Color(0xFF5E5CE6),
    ok: Color(0xFF15803D),
    warn: Color(0xFFB45309),
    err: Color(0xFFB91C1C),
    surfaceTop: Color(0xFFFFFFFF),
    surfaceBottom: Color(0xFFF8FAFC),
    edgeTop: Color(0xFFD5DEEA),
    fieldBg: Color(0xFFFFFFFF),
    fieldLine: Color(0xFFC5D0DF),
    track: Color(0x0F0F172A),
    menuBg: Color(0xFFFFFFFF),
    barBg: Color(0xDBFFFFFF),
    barLine: Color(0xFFD5DEEA),
    btn2Bg: Color(0xFFFFFFFF),
    glass1: Color(0x080F172A),
    glass2: Color(0x0F0F172A),
    orbOpacity: 0.55,
    cardShadow: <BoxShadow>[
      BoxShadow(color: Color(0x0F0F172A), blurRadius: 2, offset: Offset(0, 1)),
      BoxShadow(color: Color(0x240F172A), blurRadius: 28, spreadRadius: -8, offset: Offset(0, 12)),
    ],
  );

  static Palette of(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? dark : light;
  }

  /// Error colour for TEXT (the web app's `err-text`: a lighter red on the dark canvas, the deep red on white).
  Color get errText => isDark ? const Color(0xFFFF6961) : err;

  /// Colour that stands for a status tone.
  Color toneColor(StatusTone tone) {
    switch (tone) {
      case StatusTone.waiting:
        return warn;
      case StatusTone.progress:
        return primary;
      case StatusTone.success:
        return ok;
      case StatusTone.danger:
        return err;
    }
  }
}

/// Fonts: Tajawal is bundled; numbers and codes use the platform monospace face.
const String appFont = 'Tajawal';
const String codeFont = 'monospace';
