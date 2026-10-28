// Choice controls of the web app: the inset "segmented track" with a raised thumb under the selected option (brand
// filter, payment method, theme switch, orders / requests switch) and the small outlined toggle chip used for
// multi-select lists.

import 'package:flutter/material.dart';

import '../theme/palette.dart';

enum SegmentLayout {
  /// Options share the width equally (two or three options).
  equal,

  /// Options keep their own width and the track scrolls sideways.
  scroll,

  /// One option per row with an icon and a caption (payment methods).
  stacked,

  /// A grid with [SegmentedTrack.columns] columns (brand picker).
  grid,
}

/// One option of a [SegmentedTrack].
class SegmentOption<T> {
  const SegmentOption({
    required this.value,
    required this.label,
    this.icon,
    this.caption,
    this.enabled = true,
    this.note,
  });

  final T value;
  final String label;
  final IconData? icon;
  final String? caption;

  /// A disabled option cannot be chosen; [note] (if any) says why.
  final bool enabled;
  final String? note;
}

class SegmentedTrack<T> extends StatelessWidget {
  const SegmentedTrack({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.layout = SegmentLayout.equal,
    this.columns = 2,
  });

  final List<SegmentOption<T>> options;
  final T selected;
  final ValueChanged<T> onChanged;
  final SegmentLayout layout;
  final int columns;

  Widget _segment(SegmentOption<T> option) {
    return _Segment(
      label: option.label,
      icon: option.icon,
      caption: option.caption,
      note: option.note,
      selected: option.value == selected,
      layout: layout,
      onTap: option.enabled ? () => onChanged(option.value) : null,
    );
  }

  Widget _body() {
    switch (layout) {
      case SegmentLayout.equal:
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (int i = 0; i < options.length; i++) ...<Widget>[
                if (i > 0) const SizedBox(width: 4),
                Expanded(child: _segment(options[i])),
              ],
            ],
          ),
        );
      case SegmentLayout.scroll:
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (int i = 0; i < options.length; i++) ...<Widget>[
                  if (i > 0) const SizedBox(width: 4),
                  _segment(options[i]),
                ],
              ],
            ),
          ),
        );
      case SegmentLayout.stacked:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (int i = 0; i < options.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(height: 6),
              _segment(options[i]),
            ],
          ],
        );
      case SegmentLayout.grid:
        final int perRow = columns < 1 ? 1 : columns;
        final List<Widget> rows = <Widget>[];
        for (int start = 0; start < options.length; start += perRow) {
          rows.add(
            Padding(
              padding: EdgeInsets.only(top: start == 0 ? 0 : 6),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    for (int j = 0; j < perRow; j++) ...<Widget>[
                      if (j > 0) const SizedBox(width: 6),
                      Expanded(
                        child: start + j < options.length ? _segment(options[start + j]) : const SizedBox.shrink(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }
        return Column(children: rows);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.track,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.isDark ? const Color(0x14FFFFFF) : p.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: _body(),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.icon,
    required this.caption,
    required this.note,
    required this.selected,
    required this.layout,
    required this.onTap,
  });

  final String label;
  final IconData? icon;
  final String? caption;
  final String? note;
  final bool selected;
  final SegmentLayout layout;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    final BorderRadius shape = BorderRadius.circular(12);
    final IconData? leading = icon;
    final String? sub = caption;
    final String? warning = note;
    final bool stacked = layout == SegmentLayout.stacked;

    final Color thumb = p.isDark ? const Color(0x26FFFFFF) : Colors.white;
    final Color thumbEdge = p.isDark ? const Color(0x38FFFFFF) : p.lineStrong;
    final List<BoxShadow> thumbShadow = p.isDark
        ? const <BoxShadow>[BoxShadow(color: Color(0x4D000000), blurRadius: 10, offset: Offset(0, 4))]
        : const <BoxShadow>[BoxShadow(color: Color(0x240F172A), blurRadius: 3, offset: Offset(0, 1))];

    final Widget text = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: stacked ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: <Widget>[
        Text(
          label,
          textAlign: stacked ? TextAlign.start : TextAlign.center,
          style: TextStyle(
            color: selected ? p.text : p.muted,
            fontSize: 14,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            height: 1.35,
          ),
        ),
        if (sub != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              sub,
              textAlign: stacked ? TextAlign.start : TextAlign.center,
              style: TextStyle(color: p.muted.withValues(alpha: 0.8), fontSize: 12, height: 1.35),
            ),
          ),
        if (warning != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              warning,
              textAlign: stacked ? TextAlign.start : TextAlign.center,
              style: TextStyle(color: p.warn, fontSize: 12, height: 1.4),
            ),
          ),
      ],
    );

    final Widget content = leading == null
        ? text
        : Row(
            mainAxisSize: stacked ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: stacked ? MainAxisAlignment.start : MainAxisAlignment.center,
            children: <Widget>[
              Icon(leading, color: p.primary, size: 20),
              const SizedBox(width: 10),
              Flexible(child: text),
            ],
          );

    return Semantics(
      button: true,
      selected: selected,
      enabled: onTap != null,
      child: Opacity(
        opacity: onTap == null && !selected ? 0.6 : 1,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: shape,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              padding: EdgeInsets.symmetric(horizontal: stacked ? 12 : 16, vertical: stacked ? 10 : 9),
              constraints: const BoxConstraints(minHeight: 44),
              alignment: stacked ? AlignmentDirectional.centerStart : Alignment.center,
              decoration: BoxDecoration(
                color: selected ? thumb : Colors.transparent,
                borderRadius: shape,
                border: Border.all(color: selected ? thumbEdge : Colors.transparent),
                boxShadow: selected ? thumbShadow : const <BoxShadow>[],
              ),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

/// A small outlined chip that toggles on and off (the multi-select brand list of the registration form).
class ToggleChip extends StatelessWidget {
  const ToggleChip({super.key, required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    final BorderRadius shape = BorderRadius.circular(10);
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: shape,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            constraints: const BoxConstraints(minHeight: 38),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: selected ? p.accent.withValues(alpha: 0.20) : Colors.transparent,
              borderRadius: shape,
              border: Border.all(color: selected ? p.accent : p.line),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  selected ? Icons.check_rounded : Icons.add_rounded,
                  size: 15,
                  color: selected ? p.primary : p.muted,
                ),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? p.primary : p.muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
