// One part in the catalog list, plus helpers shared with the part details screen.

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/labels.dart';
import '../../core/models.dart';
import '../../state/app_state.dart';
import '../../theme/palette.dart';
import '../../widgets/feedback.dart';
import '../../widgets/inputs.dart';
import '../../widgets/panel.dart';
import '../../widgets/part_plate.dart';
import '../../widgets/pickers.dart';

/// Adds one unit of [part] to the cart and explains it when that is not possible (out of stock, limit reached).
void addPartToCart(BuildContext context, Part part) {
  final String? problem = AppScope.read(context).addToCart(part);
  if (problem != null) {
    showSnack(context, problem);
  }
}

/// "model · years" for a part, or an empty text when the catalog has no fitment data for it.
String partFitText(Part part) {
  final List<String> pieces = <String>[];
  if (part.model.isNotEmpty) {
    pieces.add(part.model);
  }
  if (part.years.isNotEmpty) {
    pieces.add(part.years);
  }
  return pieces.join(' · ');
}

class PartCard extends StatelessWidget {
  const PartCard({
    super.key,
    required this.part,
    required this.onOpen,
    required this.onRequest,
  });

  final Part part;

  /// Opens the details of the part.
  final VoidCallback onOpen;

  /// Opens a special request for the part (shown when it is out of stock).
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    final AppState state = AppScope.of(context);
    final int qty = state.qtyInCart(part.id);
    final String fit = partFitText(part);

    return Panel(
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  part.brand,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: p.primary, fontSize: 12.5, fontWeight: FontWeight.w500),
                ),
              ),
              if (part.inStock && part.lowStock)
                const StatusChip(label: 'كمية محدودة', tone: StatusTone.waiting),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            part.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: p.text,
              fontSize: 16.5,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 10,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              PartNumberPlate(number: part.pn),
              if (fit.isNotEmpty) Text(fit, style: TextStyle(color: p.muted, fontSize: 12.5)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  formatUsd(part.price),
                  style: TextStyle(
                    color: p.text,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              _action(context, state, qty),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'اضغط لعرض التفاصيل والتوافق',
            style: TextStyle(color: p.muted.withValues(alpha: 0.9), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _action(BuildContext context, AppState state, int qty) {
    if (!part.inStock) {
      return SecondaryButton(
        label: 'غير متوفرة — اطلبها',
        onPressed: onRequest,
        compact: true,
      );
    }
    if (qty <= 0) {
      return PrimaryButton(
        label: 'أضف للسلة',
        icon: Icons.add_rounded,
        compact: true,
        onPressed: () => addPartToCart(context, part),
      );
    }
    return QuantityStepper(
      quantity: qty,
      onIncrement: qty < part.maxOrderQty ? () => addPartToCart(context, part) : null,
      onDecrement: () => state.decrementCart(part.id),
    );
  }
}
