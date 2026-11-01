// Cards for the orders tab: a placed order (expandable list of its parts) and a special request.
//
// Like the web "طلباتي" list: the order or part name with its date and amount, the status as a coloured line of
// text, a red box with the cancellation reason and a blue box with the admin's note.

import 'package:flutter/material.dart' hide Text;

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/i18n.dart';
import '../../core/labels.dart';
import '../../core/models.dart';
import '../../state/app_state.dart';
import '../../theme/palette.dart';
import '../../widgets/feedback.dart';
import '../../widgets/panel.dart';
import '../../widgets/part_plate.dart';
import '../../widgets/tx.dart';

class OrderCard extends StatefulWidget {
  const OrderCard({super.key, required this.order});

  final Order order;

  @override
  State<OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<OrderCard> {
  bool _open = false;
  bool _cancelBusy = false;

  Future<void> _cancel(BuildContext context, Order order) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إلغاء الطلب'),
        content: Text(order.payMethod == 'sham'
            ? 'هل تريد إلغاء الطلب؟ إذا كنت قد حولت المبلغ عبر شام كاش، ستحتاج إلى مراجعة الإدارة لاسترداده.'
            : 'هل تريد إلغاء هذا الطلب؟ يمكن الإلغاء فقط قبل بدء التجهيز.'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('رجوع')),
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('تأكيد الإلغاء')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted || _cancelBusy) return;
    setState(() => _cancelBusy = true);
    try {
      await AppScope.read(context).cancelOrder(order.id);
      if (context.mounted) showSnack(context, 'تم إلغاء الطلب.');
    } on ApiException catch (error) {
      if (context.mounted) showSnack(context, error.message);
    } finally {
      if (mounted) setState(() => _cancelBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    final Order order = widget.order;
    final bool hasItems = order.items.isNotEmpty;
    final String? note = order.statusNote;
    final String? trackingNumber = order.trackingNumber;
    final SavedAddress? address = order.deliveryAddress;

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
          const SizedBox(height: 5),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Text(formatDate(order.createdAt), style: TextStyle(color: p.muted, fontSize: 12.5)),
              PayMethodBadge(method: order.payMethod),
            ],
          ),
          if (order.cashbackUsed > 0) ...<Widget>[
            const SizedBox(height: 8),
            _DetailLine(
              icon: Icons.savings_outlined,
              label: 'الكاش باك المستخدم',
              value: formatUsd(order.cashbackUsed),
            ),
            _DetailLine(
              icon: Icons.payments_outlined,
              label: 'المتبقي للدفع',
              value: formatUsd(order.amountDue ?? (order.total - order.cashbackUsed)),
            ),
          ],
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
          if (trackingNumber != null && trackingNumber.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            _DetailLine(
              icon: Icons.local_shipping_outlined,
              label: 'رقم التتبع',
              value: trackingNumber,
              ltr: true,
            ),
          ],
          if (order.status == 'pending') ...<Widget>[
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                onPressed: _cancelBusy ? null : () => _cancel(context, order),
                style: TextButton.styleFrom(foregroundColor: p.errText),
                icon: _cancelBusy ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.cancel_outlined, size: 17),
                label: Text(_cancelBusy ? 'جارٍ الإلغاء...' : 'إلغاء الطلب'),
              ),
            ),
          ],
          if (order.isCancelled && note != null && note.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            NoteBox(text: 'السبب: $note', color: p.err),
          ],
          if (order.isCancelled && order.payMethod == 'sham' && order.refundStatus != 'not_required') ...<Widget>[
            const SizedBox(height: 10),
            NoteBox(
              text: switch (order.refundStatus) {
                'pending_review' => 'استرداد شام كاش: بانتظار مراجعة الإدارة. إذا تم التحويل فعلياً، ستتابع الإدارة إعادة المبلغ.',
                'refunded' => 'استرداد شام كاش: أكدت الإدارة إعادة المبلغ إليك.',
                'not_refundable' => 'استرداد شام كاش: تمت مراجعة الطلب. ${order.refundNote ?? ''}',
                _ => 'استرداد شام كاش: الحالة قيد المراجعة.',
              },
              color: order.refundStatus == 'refunded' ? p.ok : p.warn,
            ),
          ],
          if (order.isCancelled && order.payMethod == 'sham' && order.refundStatus != 'not_required') ...<Widget>[
            const SizedBox(height: 8),
            NoteBox(
              text: switch (order.refundStatus) {
                'pending_review' => 'استرداد شام كاش: طلبك بانتظار مراجعة الإدارة. إذا تم التحويل فعلياً، ستتابع الإدارة إعادة المبلغ.',
                'refunded' => 'استرداد شام كاش: أكدت الإدارة إعادة المبلغ إليك.',
                'not_refundable' => 'استرداد شام كاش: أفادت الإدارة بأنه لا يوجد مبلغ مستحق للاسترداد. ${order.refundNote ?? ''}',
                _ => 'استرداد شام كاش قيد المراجعة.',
              },
              color: order.refundStatus == 'refunded' ? p.ok : p.warn,
            ),
          ],
          if (_open && address != null) ...<Widget>[
            const SizedBox(height: 8),
            _DetailLine(
              icon: Icons.location_on_outlined,
              label: 'عنوان التسليم',
              value: <String>[address.label, address.summary].where((String s) => s.isNotEmpty).join(' · '),
            ),
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

/// How the order is paid, as a coloured pill: debt ledger, cash on delivery or Sham Cash.
class PayMethodBadge extends StatelessWidget {
  const PayMethodBadge({super.key, required this.method});

  final String method;

  @override
  Widget build(BuildContext context) {
    final StatusTone tone = switch (method) {
      'debt' => StatusTone.waiting,
      'cod' => StatusTone.success,
      'cashback' => StatusTone.success,
      _ => StatusTone.progress,
    };
    return StatusChip(label: payMethodLabel(method), tone: tone);
  }
}

/// An icon, a muted label and a value on one line (tracking number, delivery address).
class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.icon, required this.label, required this.value, this.ltr = false});

  final IconData icon;
  final String label;
  final String value;
  final bool ltr;

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 16, color: p.muted),
        const SizedBox(width: 6),
        Text('${tr(label)}: ', style: TextStyle(color: p.muted, fontSize: 13)),
        Expanded(
          child: Text(
            value,
            textDirection: ltr ? TextDirection.ltr : null,
            textAlign: TextAlign.start,
            style: TextStyle(color: p.text, fontSize: 13, fontWeight: FontWeight.w600, height: 1.4),
          ),
        ),
      ],
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
