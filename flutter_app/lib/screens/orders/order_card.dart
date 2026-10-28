// Cards for the orders tab: a placed order (expandable list of its parts) and a special request.
//
// Like the web "طلباتي" list: the order or part name with its date and amount, the status as a coloured line of
// text, a red box with the cancellation reason and a blue box with the admin's note.

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/labels.dart';
import '../../core/models.dart';
import '../../theme/palette.dart';
import '../../widgets/panel.dart';
import '../../widgets/part_plate.dart';

class OrderCard extends StatefulWidget {
  const OrderCard({super.key, required this.order});

  final Order order;

  @override
  State<OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<OrderCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    final Order order = widget.order;
    final bool hasItems = order.items.isNotEmpty;
    final String? note = order.statusNote;

    int units = 0;
    for (final OrderLine line in order.items) {
      units += line.qty;
    }

    return Panel(
      onTap: hasItems ? () => setState(() => _open = !_open) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Text(
                  'طلب ${order.label}',
                  style: TextStyle(color: p.text, fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                formatUsd(order.total),
                style: TextStyle(
                  color: p.text,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            '${formatDate(order.createdAt)} · ${payMethodLabel(order.payMethod)}',
            style: TextStyle(color: p.muted, fontSize: 12.5),
          ),
          const SizedBox(height: 9),
          Row(
            children: <Widget>[
              _StatusLine(
                label: orderStatusLabel(order.status),
                color: p.toneColor(statusTone(order.status)),
              ),
              const Spacer(),
              if (hasItems) ...<Widget>[
                Text(
                  units == 1 ? 'قطعة واحدة' : '$units قطع',
                  style: TextStyle(color: p.muted, fontSize: 13),
                ),
                const SizedBox(width: 4),
                Icon(
                  _open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                  color: p.muted,
                ),
              ],
            ],
          ),
          if (order.isCancelled && note != null && note.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            NoteBox(text: 'السبب: $note', color: p.err),
          ],
          if (_open && hasItems) ...<Widget>[
            const SizedBox(height: 8),
            Divider(height: 1, thickness: 1, color: p.line),
            for (final OrderLine line in order.items) _OrderLineRow(line: line),
          ],
        ],
      ),
    );
  }
}

/// A status as a small semibold line of coloured text with a dot in front (the web list shows status as text).
class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        DecoratedBox(
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          child: const SizedBox(width: 8, height: 8),
        ),
        const SizedBox(width: 7),
        Text(
          label,
          style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _OrderLineRow extends StatelessWidget {
  const _OrderLineRow({required this.line});

  final OrderLine line;

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  line.name,
                  style: TextStyle(color: p.text, fontSize: 14.5, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    if (line.oemNumber.isNotEmpty) PartNumberPlate(number: line.oemNumber),
                    if (line.brand.isNotEmpty)
                      Text(line.brand, style: TextStyle(color: p.muted, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                formatUsd(line.lineTotal),
                style: TextStyle(color: p.text, fontSize: 14.5, fontWeight: FontWeight.w700),
              ),
              Text(
                '${line.qty} × ${formatUsd(line.unitPrice)}',
                style: TextStyle(color: p.muted, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class RequestCard extends StatelessWidget {
  const RequestCard({super.key, required this.request});

  final SpecialRequest request;

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    final double? price = request.quotedPrice;

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Text(
                  request.partName,
                  style: TextStyle(color: p.text, fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              if (price != null && price > 0) ...<Widget>[
                const SizedBox(width: 12),
                Text(
                  formatUsd(price),
                  style: TextStyle(
                    color: p.text,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 3),
          Text(
            '${request.brandLabel} · ${formatDate(request.createdAt)}',
            style: TextStyle(color: p.muted, fontSize: 12.5),
          ),
          const SizedBox(height: 9),
          _StatusLine(
            label: specialStatusLabel(request.status),
            color: p.toneColor(statusTone(request.status)),
          ),
          if (price != null && price > 0) ...<Widget>[
            const SizedBox(height: 4),
            Text('السعر المقترح', style: TextStyle(color: p.muted, fontSize: 12)),
          ],
          if (request.adminNote.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            NoteBox(text: 'ملاحظة الإدارة: ${request.adminNote}', color: p.accent),
          ],
        ],
      ),
    );
  }
}
