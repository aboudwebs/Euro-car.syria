// A compact search box with a clear button (used by the catalog): the web app's inset field with the magnifier
// at the start.

import 'package:flutter/material.dart';

import '../theme/palette.dart';
import 'inputs.dart';

class SearchField extends StatelessWidget {
  const SearchField({
    super.key,
    required this.controller,
    required this.hint,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    return FieldShell(
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: TextStyle(color: p.text, fontSize: 16),
        cursorColor: p.accent,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: p.placeholder, fontSize: 15),
          prefixIcon: Icon(Icons.search_rounded, color: p.placeholder, size: 20),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  onPressed: onClear,
                  tooltip: 'مسح البحث',
                  icon: Icon(Icons.close_rounded, color: p.muted, size: 20),
                ),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
        ),
      ),
    );
  }
}
