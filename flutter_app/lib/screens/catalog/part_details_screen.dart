// Details of one catalog part: number, price, availability and fitment, with the buy action.

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/labels.dart';
import '../../core/models.dart';
import '../../state/app_state.dart';
import '../../theme/palette.dart';
import '../../widgets/app_bar.dart';
import '../../widgets/backdrop.dart';
import '../../widgets/feedback.dart';
import '../../widgets/inputs.dart';
import '../../widgets/panel.dart';
import '../../widgets/part_plate.dart';
import '../special/special_request_screen.dart';
import 'part_card.dart';

class PartDetailsScreen extends StatelessWidget {
  const PartDetailsScreen({super.key, required this.partId});

  final String partId;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    Part? part;
    for (final Part candidate in state.parts) {
      if (candidate.id == partId) {
        part = candidate;
        break;
      }
    }

    final Part? found = part;
    return AppBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: buildScreenBar(context, 'تفاصيل القطعة'),
        body: SafeArea(
          child: found == null ? _missing(context, state) : _Details(part: found),
        ),
        bottomNavigationBar: found == null ? null : _BuyBar(part: found),
      ),
    );
  }

  Widget _missing(BuildContext context, AppState state) {
    if (state.partsLoading) {
      return const Center(child: LoadingBlock(message: 'جارٍ تحميل تفاصيل القطعة...'));
    }
    final String? error = state.partsError;
    if (error != null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          NoticeBanner(
            message: error,
            kind: NoticeKind.error,
            onRetry: () => state.loadParts(),
          ),
        ],
      );
    }
    return Center(
      child: EmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'القطعة غير موجودة',
        message: 'ربما لم تعد متاحة في الكتالوج.',
        actionLabel: 'العودة إلى الكتالوج',
        onAction: () => Navigator.of(context).pop(),
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.part});

  final Part part;

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    final String fit = partFitText(part);
    final String? altGrade = part.altGrade;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: <Widget>[
        Text(
          part.name,
          style: TextStyle(
            color: p.text,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          'تفاصيل القطعة والسعر والتوافق مع السيارات',
          style: TextStyle(color: p.muted, fontSize: 14, height: 1.45),
        ),
        const SizedBox(height: 18),
        Panel(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('رقم القطعة', style: TextStyle(color: p.primary, fontSize: 14)),
                        const SizedBox(height: 4),
                        PartNumberPlate(number: part.pn, large: true),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  StatusChip(
                    label: part.inStock ? 'متوفرة' : 'غير متوفرة',
                    tone: part.inStock ? StatusTone.success : StatusTone.waiting,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'اضغط مطولاً على رقم القطعة لنسخه.',
                style: TextStyle(color: p.muted, fontSize: 12),
              ),
              const SizedBox(height: 14),
              Divider(color: p.line),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  children: <Widget>[
                    Text('السعر', style: TextStyle(color: p.muted, fontSize: 14)),
                    const Spacer(),
                    Text(
                      formatUsd(part.price),
                      style: TextStyle(color: p.primary, fontSize: 26, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              Divider(color: p.line),
              const SizedBox(height: 12),
              Text(
                'الماركة الأساسية',
                style: TextStyle(color: p.text, fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                part.brand,
                style: TextStyle(color: p.text.withValues(alpha: 0.8), fontSize: 15),
              ),
              if (part.inStock) ...<Widget>[
                const SizedBox(height: 6),
                InfoRow(
                  label: 'الكمية المتاحة',
                  value: '${part.stock}',
                  valueColor: part.lowStock ? p.warn : null,
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: p.accent.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: p.accent.withValues(alpha: 0.30)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Icon(Icons.check_circle_outline_rounded, color: p.primary, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'التوافق مع السيارات',
                              style: TextStyle(color: p.text, fontSize: 15, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          fit.isNotEmpty
                              ? fit
                              : 'قائمة الموديلات والسنوات المتوافقة غير مسجّلة لهذه القطعة، لذلك لن نعرض توافقاً غير مؤكّد. '
                                  'أرسل رقم الشاصي (VIN) أو اطلب مطابقة رقم القطعة للتأكد من توافقها مع سيارتك قبل الشراء.',
                          style: TextStyle(color: p.text.withValues(alpha: 0.8), fontSize: 14, height: 1.7),
                        ),
                        if (altGrade != null) ...<Widget>[
                          const SizedBox(height: 8),
                          Text(
                            'درجة البديل: $altGrade',
                            style: TextStyle(color: p.muted, fontSize: 13.5),
                          ),
                        ],
                        const SizedBox(height: 6),
                        TextButton(
                          onPressed: () => openSpecialRequestForPart(context, part),
                          child: const Text(
                            'طلب مطابقة أو قطعة خاصة',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The bar at the bottom of the screen: add to cart, change the quantity, or ask for an unavailable part.
class _BuyBar extends StatelessWidget {
  const _BuyBar({required this.part});

  final Part part;

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    final AppState state = AppScope.of(context);
    final int qty = state.qtyInCart(part.id);

    final Widget action;
    if (!part.inStock) {
      action = PrimaryButton(
        label: 'اطلب القطعة',
        icon: Icons.travel_explore_rounded,
        onPressed: () => openSpecialRequestForPart(context, part),
      );
    } else if (qty <= 0) {
      action = PrimaryButton(
        label: 'إضافة للسلة',
        icon: Icons.add_shopping_cart_rounded,
        onPressed: () => addPartToCart(context, part),
      );
    } else {
      action = Row(
        children: <Widget>[
          QuantityStepper(
            quantity: qty,
            onIncrement: qty < part.maxOrderQty ? () => addPartToCart(context, part) : null,
            onDecrement: () => state.decrementCart(part.id),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: PrimaryButton(
              label: 'عرض السلة',
              icon: Icons.shopping_bag_outlined,
              onPressed: () {
                state.selectTab(tabCart);
                Navigator.of(context).popUntil((Route<dynamic> route) => route.isFirst);
              },
            ),
          ),
        ],
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.barBg,
        border: Border(top: BorderSide(color: p.barLine)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: action,
        ),
      ),
    );
  }
}
