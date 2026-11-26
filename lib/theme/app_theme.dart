// Material 3 themes built from the palette. Only long-stable theme classes are used on purpose
// (NavigationBarThemeData, SnackBarThemeData, BottomSheetThemeData, DividerThemeData, ...), so the file keeps
// compiling across Flutter releases. The look follows the web app: glass bars, pill buttons, rounded surfaces.

import 'package:flutter/material.dart';

import 'palette.dart';

ThemeData buildTheme(Brightness brightness) {
  final bool isDark = brightness == Brightness.dark;
  final Palette p = isDark ? Palette.dark : Palette.light;

  final ColorScheme scheme = isDark
      ? ColorScheme.dark(
          primary: p.accent,
          onPrimary: Colors.white,
          primaryContainer: p.accent.withValues(alpha: 0.22),
          onPrimaryContainer: p.text,
          secondary: p.brand,
          onSecondary: Colors.white,
          secondaryContainer: p.accent.withValues(alpha: 0.22),
          onSecondaryContainer: p.text,
          error: p.err,
          onError: Colors.white,
          surface: p.menuBg,
          onSurface: p.text,
          outline: p.line,
          outlineVariant: p.line,
        )
      : ColorScheme.light(
          primary: p.accent,
          onPrimary: Colors.white,
          primaryContainer: p.accent.withValues(alpha: 0.14),
          onPrimaryContainer: p.text,
          secondary: p.brand,
          onSecondary: Colors.white,
          secondaryContainer: p.accent.withValues(alpha: 0.14),
          onSecondaryContainer: p.text,
          error: p.err,
          onError: Colors.white,
          surface: p.menuBg,
          onSurface: p.text,
          outline: p.line,
          outlineVariant: p.line,
        );

  // Material 3 is the default since Flutter 3.16, so it is not requested explicitly.
  final ThemeData base = ThemeData(
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: appFont,
  );

  const StadiumBorder pill = StadiumBorder();

  return base.copyWith(
    scaffoldBackgroundColor: p.bg,
    textTheme: base.textTheme.apply(bodyColor: p.text, displayColor: p.text),
    dividerTheme: DividerThemeData(color: p.line, thickness: 1, space: 1),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: p.accent,
      selectionColor: const Color(0x4D0A84FF),
      selectionHandleColor: p.accent,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: p.accent,
      linearTrackColor: p.track,
    ),
    // The glass bottom bar: a translucent fill over the backdrop, a hairline on top, the active tab in the accent.
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.barBg,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      indicatorColor: Colors.transparent,
      elevation: 0,
      height: 66,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>((Set<WidgetState> states) {
        final bool selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontFamily: appFont,
          fontSize: 11.5,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? p.primary : p.muted,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith<IconThemeData?>((Set<WidgetState> states) {
        final bool selected = states.contains(WidgetState.selected);
        return IconThemeData(size: 23, color: selected ? p.primary : p.muted);
      }),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: p.accent,
        foregroundColor: Colors.white,
        shape: pill,
        textStyle: const TextStyle(fontFamily: appFont, fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.text,
        backgroundColor: p.btn2Bg,
        side: BorderSide(color: p.line),
        shape: pill,
        textStyle: const TextStyle(fontFamily: appFont, fontSize: 14.5, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: p.primary,
        shape: pill,
        textStyle: const TextStyle(fontFamily: appFont, fontSize: 14, fontWeight: FontWeight.w700),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.all<Color>(Colors.white),
      trackColor: WidgetStateProperty.resolveWith<Color?>((Set<WidgetState> states) {
        return states.contains(WidgetState.selected) ? const Color(0xFF30D158) : p.lineStrong;
      }),
      trackOutlineColor: WidgetStateProperty.all<Color>(Colors.transparent),
    ),
    listTileTheme: ListTileThemeData(
      textColor: p.text,
      iconColor: p.muted,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: isDark ? p.menuBg : const Color(0xFF0F172A),
      contentTextStyle: const TextStyle(fontFamily: appFont, fontSize: 14, color: Colors.white),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? p.lineStrong : Colors.transparent),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.menuBg,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: p.lineStrong,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    // Confirmation dialogs share the menu surface and the 24px radius of the web cards.
    dialogTheme: DialogThemeData(
      backgroundColor: p.menuBg,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: p.line),
      ),
      titleTextStyle: TextStyle(
        fontFamily: appFont,
        fontSize: 19,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        color: p.text,
      ),
      contentTextStyle: TextStyle(
        fontFamily: appFont,
        fontSize: 14.5,
        height: 1.6,
        color: p.muted,
      ),
    ),
  );
}
