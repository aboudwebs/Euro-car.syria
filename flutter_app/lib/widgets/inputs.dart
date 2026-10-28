// Text fields, buttons, quantity stepper and avatar: the web app's inset fields (`.input`) and pill buttons
// (`.btn` / `.btn2`).

import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/text_utils.dart';
import '../theme/palette.dart';
import 'panel.dart';
import 'pressable.dart';

/// The inset container of every text field: tinted fill, hairline border, 16 px corners, and a blue ring while the
/// field inside it has focus.
class FieldShell extends StatefulWidget {
  const FieldShell({super.key, required this.child, this.enabled = true, this.radius = 16});

  final Widget child;
  final bool enabled;
  final double radius;

  @override
  State<FieldShell> createState() => _FieldShellState();
}

class _FieldShellState extends State<FieldShell> {
  bool _focused = false;

  void _onFocusChange(bool value) {
    if (mounted && _focused != value) {
      setState(() => _focused = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    final bool ring = _focused && widget.enabled;
    final Widget shell = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: p.fieldBg,
        gradient: p.isDark
            ? const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[Color(0x59000000), Color(0x00000000)],
                stops: <double>[0, 0.14],
              )
            : null,
        borderRadius: BorderRadius.circular(widget.radius),
        border: Border.all(color: ring ? p.accent : p.fieldLine),
        boxShadow: ring
            ? <BoxShadow>[BoxShadow(color: p.accent.withValues(alpha: 0.25), spreadRadius: 3)]
            : const <BoxShadow>[],
      ),
      child: widget.child,
    );
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: _onFocusChange,
      child: widget.enabled ? shell : Opacity(opacity: 0.6, child: shell),
    );
  }
}

/// A text field with the app's look. Labels sit above the field (not floating) so long Arabic labels never get cut.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.icon,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.onChanged,
    this.maxLength,
    this.maxLines = 1,
    this.ltr = false,
    this.readOnly = false,
    this.enabled = true,
    this.obscureText = false,
    this.autofillHints,
    this.focusNode,
    this.suffix,
    this.radius = 16,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData? icon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final int? maxLength;
  final int maxLines;

  /// Left-to-right text for phone numbers, codes and links.
  final bool ltr;
  final bool readOnly;
  final bool enabled;
  final bool obscureText;
  final Iterable<String>? autofillHints;
  final FocusNode? focusNode;
  final Widget? suffix;

  /// Corner radius of the field (16 like the web app's `.input`; the sign-in form uses 10).
  final double radius;

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    final IconData? leading = icon;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            label,
            style: TextStyle(color: p.muted, fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
        FieldShell(
          enabled: enabled,
          radius: radius,
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            onSubmitted: onSubmitted,
            onChanged: onChanged,
            maxLength: maxLength,
            maxLines: maxLines,
            readOnly: readOnly,
            enabled: enabled,
            obscureText: obscureText,
            autofillHints: autofillHints,
            textDirection: ltr ? TextDirection.ltr : null,
            textAlign: ltr ? TextAlign.left : TextAlign.start,
            style: TextStyle(color: p.text, fontSize: 16),
            cursorColor: p.accent,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: p.placeholder, fontSize: 15),
              prefixIcon: leading == null ? null : Icon(leading, color: p.muted, size: 20),
              suffixIcon: suffix,
              counterText: '',
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }
}

/// Password field with a show / hide toggle.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.textInputAction,
    this.onSubmitted,
    this.autofillHints,
    this.focusNode,
    this.radius = 16,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Iterable<String>? autofillHints;
  final FocusNode? focusNode;
  final double radius;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    return AppTextField(
      controller: widget.controller,
      label: widget.label,
      hint: widget.hint,
      icon: Icons.lock_outline_rounded,
      obscureText: _hidden,
      ltr: true,
      maxLength: 128,
      textInputAction: widget.textInputAction,
      onSubmitted: widget.onSubmitted,
      autofillHints: widget.autofillHints,
      focusNode: widget.focusNode,
      radius: widget.radius,
      keyboardType: TextInputType.visiblePassword,
      suffix: IconButton(
        onPressed: () => setState(() => _hidden = !_hidden),
        tooltip: _hidden ? 'إظهار كلمة المرور' : 'إخفاء كلمة المرور',
        icon: Icon(
          _hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          color: p.muted,
          size: 20,
        ),
      ),
    );
  }
}

/// Main action button: the web app's gradient pill with a soft blue glow. Shows a spinner while [busy] and ignores
/// taps until it finishes; a button without [onPressed] is dimmed to half opacity like a disabled `.btn`.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.icon,
    this.color,
    this.compact = false,
    this.flat = false,
    this.radius,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final IconData? icon;

  /// Replaces the blue gradient (for example the amber "marketer" action).
  final Color? color;

  /// A content-width pill (for cards and empty states) instead of the full-width action button.
  final bool compact;

  /// The flat 12 px rounded rectangle of the web sign-in form (a solid [color], no gradient and no gloss).
  final bool flat;

  /// Corner radius of a gradient button that is a rounded rectangle instead of a pill (the web's `rounded-xl .btn`).
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final IconData? leading = icon;
    final Color? tint = color;
    final bool enabled = onPressed != null && !busy;
    final double? custom = radius;
    final double corner = flat ? 12 : (custom ?? 40);
    final OutlinedBorder shape = (flat || custom != null)
        ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(corner))
        : const StadiumBorder();

    final Color bottom = tint ?? (flat ? const Color(0xFF2563EB) : accentGradientBottom);
    final Color top;
    if (flat) {
      top = bottom;
    } else if (tint == null) {
      top = accentGradientTop;
    } else {
      top = Color.lerp(tint, Colors.white, 0.22) ?? tint;
    }

    final Widget face = FilledButton(
      onPressed: enabled ? onPressed : null,
      style: FilledButton.styleFrom(
        minimumSize: compact ? const Size(0, 44) : const Size.fromHeight(52),
        padding: compact ? const EdgeInsets.symmetric(horizontal: 22) : null,
        backgroundColor: Colors.transparent,
        disabledBackgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.white,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: shape,
        textStyle: TextStyle(
          fontFamily: appFont,
          fontSize: compact ? 14.5 : 16,
          fontWeight: FontWeight.w700,
        ),
      ),
      child: busy
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.6, color: Colors.white),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (leading != null) ...<Widget>[
                  Icon(leading, size: 20),
                  const SizedBox(width: 8),
                ],
                Flexible(child: Text(label, textAlign: TextAlign.center)),
              ],
            ),
    );

    final Widget button = PressScale(
      enabled: enabled,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[top, bottom],
          ),
          borderRadius: BorderRadius.circular(corner),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: flat ? const Color(0x33000000) : bottom.withValues(alpha: 0.38),
              blurRadius: flat ? 12 : 20,
              offset: Offset(0, flat ? 4 : 6),
            ),
          ],
        ),
        child: flat
            ? face
            : CustomPaint(
                foregroundPainter: EdgePainter(
                  radius: corner,
                  top: const Color(0x80FFFFFF),
                  bottom: const Color(0x00FFFFFF),
                  width: 1.4,
                ),
                child: face,
              ),
      ),
    );
    if (onPressed == null && !busy) {
      return Opacity(opacity: 0.5, child: button);
    }
    return button;
  }
}

/// Secondary pill button (the web app's `.btn2`): a light fill with a hairline border.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color,
    this.iconColor,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? color;

  /// Colour of the icon alone (for example a green support icon next to normal text).
  final Color? iconColor;

  /// A content-width pill instead of the full-width button.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    final IconData? leading = icon;
    final Color? tint = color;
    final Color ink = tint ?? p.text;
    final Widget button = PressScale(
      enabled: onPressed != null,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: compact ? const Size(0, 44) : const Size.fromHeight(48),
          padding: compact ? const EdgeInsets.symmetric(horizontal: 20) : null,
          foregroundColor: ink,
          disabledForegroundColor: ink,
          backgroundColor: tint == null ? p.btn2Bg : tint.withValues(alpha: 0.10),
          side: BorderSide(color: tint == null ? p.line : tint.withValues(alpha: 0.5)),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontFamily: appFont, fontSize: 15, fontWeight: FontWeight.w600),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (leading != null) ...<Widget>[
              Icon(leading, size: 20, color: iconColor),
              const SizedBox(width: 8),
            ],
            Flexible(child: Text(label, textAlign: TextAlign.center)),
          ],
        ),
      ),
    );
    if (onPressed == null) {
      return Opacity(opacity: 0.5, child: button);
    }
    return button;
  }
}

/// A round secondary button that holds one icon (the web header's light / dark switch and similar actions).
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.size = 40,
    this.iconColor,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final double size;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    return Tooltip(
      message: tooltip,
      child: PressScale(
        enabled: onTap != null,
        child: Material(
          color: p.btn2Bg,
          shape: CircleBorder(side: BorderSide(color: p.line)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              width: size,
              height: size,
              child: Icon(icon, size: size * 0.48, color: iconColor ?? p.text),
            ),
          ),
        ),
      ),
    );
  }
}

/// Minus / quantity / plus control. The buttons are round secondary pills like the web cart, with a touch target
/// big enough for work gloves.
class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.quantity,
    required this.onIncrement,
    required this.onDecrement,
  });

  final int quantity;

  /// Null disables the plus button (maximum reached).
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _StepButton(icon: Icons.remove_rounded, tooltip: 'إنقاص الكمية', onTap: onDecrement),
        SizedBox(
          width: 38,
          child: Text(
            '$quantity',
            textAlign: TextAlign.center,
            style: TextStyle(color: p.text, fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        _StepButton(icon: Icons.add_rounded, tooltip: 'زيادة الكمية', onTap: onIncrement),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    final bool enabled = onTap != null;
    return Tooltip(
      message: tooltip,
      child: PressScale(
        enabled: enabled,
        child: Material(
          color: p.btn2Bg,
          shape: CircleBorder(side: BorderSide(color: p.line)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              width: 42,
              height: 42,
              child: Icon(icon, size: 20, color: enabled ? p.text : p.muted.withValues(alpha: 0.4)),
            ),
          ),
        ),
      ),
    );
  }
}

/// The user's photo, or their initials when there is none.
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.name, this.bytes, this.size = 64});

  final String name;
  final Uint8List? bytes;
  final double size;

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    final Uint8List? photo = bytes;
    final String initials = initialsOf(name);
    final Widget fallback = Center(
      child: initials.isEmpty
          ? Icon(Icons.person_rounded, color: p.muted, size: size * 0.5)
          : Text(
              initials,
              style: TextStyle(
                color: p.primary,
                fontSize: size * 0.36,
                fontWeight: FontWeight.w800,
              ),
            ),
    );
    final BorderRadius shape = BorderRadius.circular(size * 0.34);
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: shape,
          border: Border.all(color: p.lineStrong),
        ),
        child: ClipRRect(
          borderRadius: shape,
          child: ColoredBox(
            color: p.accent.withValues(alpha: 0.14),
            child: photo == null
                ? fallback
                : Image.memory(
                    photo,
                    fit: BoxFit.cover,
                    width: size,
                    height: size,
                    gaplessPlayback: true,
                    errorBuilder: (BuildContext context, Object error, StackTrace? stack) => fallback,
                  ),
          ),
        ),
      ),
    );
  }
}
