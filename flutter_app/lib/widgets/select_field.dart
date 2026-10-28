// A read-only field that opens a picker when tapped (used for the governorate).

import 'package:flutter/material.dart';

import '../theme/palette.dart';

class SelectField extends StatelessWidget {
  const SelectField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.placeholder = 'اختر',
    this.icon,
    this.radius = 16,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final String placeholder;
  final IconData? icon;

  /// Corner radius of the field (16 like the web app's `.input`; the sign-in forms use 10).
  final double radius;

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    final IconData? leading = icon;
    final bool empty = value.isEmpty;
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
        Material(
          color: p.fieldBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
            side: BorderSide(color: p.fieldLine),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: <Widget>[
                  if (leading != null) ...<Widget>[
                    Icon(leading, color: p.muted, size: 20),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Text(
                      empty ? placeholder : value,
                      style: TextStyle(
                        color: empty ? p.placeholder : p.text,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Icon(Icons.expand_more_rounded, color: p.muted),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
