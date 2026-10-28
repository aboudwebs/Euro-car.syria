// Building blocks shared by the workshop and marketer dashboards: the web dashboard's stat cards, its blue progress
// bar and its hairline-separated lists.

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/labels.dart';
import '../../core/models.dart';
import '../../theme/palette.dart';
import '../../widgets/panel.dart';

/// A figure with an optional icon above it, a label and an optional explanation (the web's stat card).
class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.note,
    this.accent,
    this.valueColor,
    this.borderColor,
    this.footer,
    this.compact = false,
  });

  final String label;
  final String value;
  final IconData? icon;
  final String? note;

  /// Colour of the icon (defaults to the primary colour).
  final Color? accent;
  final Color? valueColor;
  final Color? borderColor;

  /// Extra content under the figure, for example a progress bar.
  final Widget? footer;

  /// A smaller figure (the web's three-up row of the marketer dashboard).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    final IconData? glyph = icon;
    final String? text = note;
    final Widget? extra = footer;
    return Panel(
      borderColor: borderColor,
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (glyph != null) ...<Widget>[
              Icon(glyph, color: accent ?? p.primary, size: 24),
              const SizedBox(height: 8),
            ],
            Text(label, style: TextStyle(color: p.muted, fontSize: 14, height: 1.4)),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                color: valueColor ?? p.text,
                fontSize: compact ? 24 : 28,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
                height: 1.25,
              ),
            ),
            if (text != null) ...<Widget>[
              const SizedBox(height: 4),
              Text(text, style: TextStyle(color: p.placeholder, fontSize: 12.5, height: 1.5)),
            ],
            if (extra != null) ...<Widget>[
              const SizedBox(height: 10),
              extra,
            ],
          ],
        ),
      ),
    );
  }
}

/// A rounded progress bar: an inset dark track with the web's blue gradient fill (or a solid [color], for example
/// red when the debt deadline is close). The fill starts at the reading side (right in Arabic).
class ProgressBar extends StatelessWidget {
  const ProgressBar({super.key, required this.value, this.color, this.height = 8});

  /// From 0 to 1.
  final double value;
  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    final double clamped = value < 0 ? 0.0 : (value > 1 ? 1.0 : value);
    final Color? solid = color;
    final BorderRadius shape = BorderRadius.circular(height);
    return ClipRRect(
      borderRadius: shape,
      child: SizedBox(
        height: height,
        child: DecoratedBox(
          decoration: BoxDecoration(color: p.track),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: FractionallySizedBox(
              widthFactor: clamped,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: solid,
                  gradient: solid == null
                      ? const LinearGradient(
                          begin: AlignmentDirectional.centerStart,
                          end: AlignmentDirectional.centerEnd,
                          colors: <Color>[accentGradientBottom, accentGradientTop],
                        )
                      : null,
                  borderRadius: shape,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One line of a dashboard list: a title with a small caption at the start and an amount at the end, separated from
/// the line above by a hairline.
class DashboardRow extends StatelessWidget {
  const DashboardRow({
    super.key,
    required this.title,
    required this.caption,
    required this.amount,
    this.amountColor,
    this.divider = true,
  });

  final String title;
  final String caption;
  final String amount;
  final Color? amountColor;

  /// Draw the hairline above this line (false for the first line of a list).
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: divider ? Border(top: BorderSide(color: p.line)) : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: TextStyle(color: p.text, fontSize: 14.5, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 1),
                  Text(caption, style: TextStyle(color: p.placeholder, fontSize: 12.5)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              amount,
              style: TextStyle(
                color: amountColor ?? p.text,
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A titled group of orders (the workshop dashboard lists cash orders and debt orders separately).
class OrderGroup extends StatelessWidget {
  const OrderGroup({
    super.key,
    required this.title,
    required this.color,
    required this.orders,
    required this.total,
  });

  final String title;
  final Color color;
  final List<Order> orders;

  /// Sum of the orders shown.
  final double total;

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    return Panel(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 6),
            if (orders.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  'لا توجد طلبات ضمن هذه الفئة حتى الآن.',
                  style: TextStyle(color: p.placeholder, fontSize: 13.5),
                ),
              )
            else ...<Widget>[
              for (int i = 0; i < orders.length; i++)
                DashboardRow(
                  divider: i > 0,
                  title: 'طلب ${orders[i].label}',
                  caption: '${formatDate(orders[i].createdAt)} · ${orderStatusLabel(orders[i].status)}',
                  amount: formatUsd(orders[i].total),
                ),
              const SizedBox(height: 6),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Text(
                  'إجمالي الطلبات المعروضة: ${formatUsd(total)}',
                  style: TextStyle(color: p.muted, fontSize: 13.5),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
