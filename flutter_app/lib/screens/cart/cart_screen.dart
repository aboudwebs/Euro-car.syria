// Cart tab and checkout (POST /api/orders): payment choice, Sham Cash receipt and order confirmation.
//
// Only part ids and quantities are sent; the server recomputes prices, stock and the total.
//
// The look follows the web cart: one glass card with the lines and the total, one glass card with the payment
// methods in an inset segmented track, and the blue gradient pill that confirms the order.

import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/cart.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../state/app_state.dart';
import '../../theme/palette.dart';
import '../../widgets/feedback.dart';
import '../../widgets/inputs.dart';
import '../../widgets/panel.dart';
import '../../widgets/part_plate.dart';
import '../../widgets/pickers.dart';
import '../../widgets/segmented.dart';
import '../home/tab_header.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _PayOption {
  const _PayOption(this.key, this.icon, this.title, this.subtitle);

  final String key;
  final IconData icon;
  final String title;
  final String subtitle;
}

/// Same order as the web cart: Sham Cash, cash on delivery, debt ledger.
const List<_PayOption> _payOptions = <_PayOption>[
  _PayOption('sham', Icons.account_balance_outlined, 'شام كاش', 'حوّل المبلغ وأرفق إشعار التحويل'),
  _PayOption('cod', Icons.payments_outlined, 'كاش عند الاستلام', 'ادفع نقدًا للمندوب'),
  _PayOption(
    'debt',
    Icons.menu_book_outlined,
    'دفتر الدين (للورشات)',
    'بعد موافقة الأدمن يبدأ عدّاد 30 يومًا',
  ),
];

class _CartScreenState extends State<CartScreen> {
  String _pay = 'cod';
  Uint8List? _receipt;
  bool _busy = false;
  String? _error;

  Future<void> _pickReceipt() async {
    final ImagePickResult result = await pickPhoto(context, maxSide: 2000);
    if (!mounted) {
      return;
    }
    final Uint8List? bytes = result.bytes;
    final String? failure = result.error;
    setState(() {
      if (bytes != null) {
        _receipt = bytes;
        _error = null;
      } else if (failure != null) {
        _error = failure;
      }
    });
  }

  Future<void> _confirmClear() async {
    final bool? clear = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        final Palette p = Palette.of(dialogContext);
        return AlertDialog(
          title: const Text('تفريغ السلة'),
          content: const Text('هل تريد إزالة جميع القطع من السلة؟'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: TextButton.styleFrom(foregroundColor: p.errText),
              child: const Text('تفريغ'),
            ),
          ],
        );
      },
    );
    if (clear == true && mounted) {
      AppScope.read(context).clearCart();
    }
  }

  Future<void> _submit(String pay) async {
    if (_busy) {
      return;
    }
    if (pay == 'sham' && _receipt == null) {
      setState(() => _error = 'يرجى إرفاق إشعار تحويل شام كاش لإتمام الطلب.');
      return;
    }
    final AppState state = AppScope.read(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final PlacedOrder placed = await state.placeOrder(
        pay: pay,
        receipt: pay == 'sham' ? _receipt : null,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _receipt = null;
        _pay = 'cod';
      });
      await _showSuccess(placed, pay);
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _error = unexpectedMessage;
      });
    }
  }

  Future<void> _showSuccess(PlacedOrder placed, String pay) async {
    final int? number = placed.orderNumber;
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        final Palette p = Palette.of(dialogContext);
        return AlertDialog(
          icon: Icon(Icons.check_circle_rounded, color: p.ok, size: 48),
          title: const Text('تم إرسال الطلب', textAlign: TextAlign.center),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (number != null) ...<Widget>[
                Text(
                  'رقم الطلب: #$number',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: p.text, fontSize: 15.5, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
              ],
              Text(
                pay == 'debt'
                    ? 'طلبك بانتظار موافقة الأدمن على الدين.'
                    : 'سنتواصل معك لتأكيد التوصيل.',
                textAlign: TextAlign.center,
                style: TextStyle(color: p.muted, fontSize: 14.5, height: 1.6),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: <Widget>[
            PrimaryButton(
              label: 'عرض طلباتي',
              compact: true,
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
          ],
        );
      },
    );
    if (!mounted) {
      return;
    }
    AppScope.read(context).selectTab(tabOrders);
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final AppUser? user = state.user;
    if (user == null) {
      return const SizedBox.shrink();
    }
    final List<CartLine> lines = state.cartLines;

    return Column(
      children: <Widget>[
        TabHeader(
          title: 'السلة وإتمام الطلب',
          subtitle: 'توصيل وشحن لكافة المحافظات السورية',
          actions: <Widget>[
            if (lines.isNotEmpty)
              RoundIconButton(
                icon: Icons.delete_sweep_outlined,
                tooltip: 'تفريغ السلة',
                size: 44,
                onTap: _busy ? null : _confirmClear,
              ),
          ],
        ),
        Expanded(child: _body(context, state, user, lines)),
      ],
    );
  }

  Widget _body(BuildContext context, AppState state, AppUser user, List<CartLine> lines) {
    final String? notice = state.cartNotice;

    if (lines.isEmpty) {
      final bool waitingForCatalog = state.cartItems.isNotEmpty && !state.partsLoaded;
      if (waitingForCatalog) {
        final String? error = state.partsError;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: <Widget>[
            if (error != null)
              NoticeBanner(
                message: error,
                kind: NoticeKind.error,
                onRetry: () => state.loadParts(),
              )
            else
              const LoadingBlock(message: 'جارٍ تحميل السلة...'),
          ],
        );
      }
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: <Widget>[
          if (notice != null) ...<Widget>[
            NoticeBanner(
              message: notice,
              kind: NoticeKind.warning,
              onDismiss: state.dismissCartNotice,
            ),
            const SizedBox(height: 10),
          ],
          Panel(
            padding: EdgeInsets.zero,
            child: EmptyState(
              icon: Icons.shopping_bag_outlined,
              title: 'السلة فارغة',
              message: 'أضف قطعاً من الكتالوج لتبدأ طلبك.',
              actionLabel: 'تصفّح الكتالوج',
              onAction: () => state.selectTab(tabCatalog),
            ),
          ),
        ],
      );
    }

    final Palette p = Palette.of(context);
    final double total = state.cartTotalAmount;
    final List<String> methods = payMethodsFor(user);
    final DebtCheck debt = checkDebtPayment(user: user, total: total);
    String pay = _pay;
    if (!methods.contains(pay) || (pay == 'debt' && !debt.allowed)) {
      pay = 'cod';
    }
    final String? error = _error;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: <Widget>[
        if (notice != null) ...<Widget>[
          NoticeBanner(
            message: notice,
            kind: NoticeKind.warning,
            onDismiss: state.dismissCartNotice,
          ),
          const SizedBox(height: 10),
        ],
        Panel(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 14),
          child: Column(
            children: <Widget>[
              for (int i = 0; i < lines.length; i++) ...<Widget>[
                if (i > 0) Divider(height: 1, thickness: 1, color: p.line),
                _CartLineTile(
                  key: ValueKey<String>(lines[i].part.id),
                  line: lines[i],
                  enabled: !_busy,
                ),
              ],
              Divider(height: 1, thickness: 1, color: p.line),
              const SizedBox(height: 8),
              InfoRow(label: 'عدد القطع', value: '${state.cartItemCount}'),
              Row(
                children: <Widget>[
                  Text('إجمالي الطلب', style: TextStyle(color: p.muted, fontSize: 14)),
                  const Spacer(),
                  Text(
                    formatUsd(total),
                    style: TextStyle(
                      color: p.text,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Panel(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'طريقة الدفع',
                style: TextStyle(color: p.text, fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              SegmentedTrack<String>(
                layout: SegmentLayout.stacked,
                selected: pay,
                onChanged: (String key) {
                  if (_busy) {
                    return;
                  }
                  setState(() {
                    _pay = key;
                    _error = null;
                  });
                },
                options: <SegmentOption<String>>[
                  for (final _PayOption option in _payOptions)
                    if (methods.contains(option.key))
                      SegmentOption<String>(
                        value: option.key,
                        label: option.title,
                        icon: option.icon,
                        caption: option.subtitle,
                        enabled: !(option.key == 'debt' && !debt.allowed),
                        note: option.key == 'debt' && !debt.allowed ? debt.message : null,
                      ),
                ],
              ),
              if (pay == 'sham') ...<Widget>[
                const SizedBox(height: 14),
                _receiptSection(p),
              ],
              if (pay == 'debt') ...<Widget>[
                const SizedBox(height: 14),
                NoticeBanner(
                  kind: NoticeKind.warning,
                  message: 'عدّاد 30 يومًا يبدأ من أول قطعة دين. عند تجاوزه يتوقف السحب الآجل حتى التسديد. '
                      'الكاش باك والعمولة يُصرفان بعد التسديد.\n'
                      'المتاح من سقفك: ${debt.available == null ? 'غير محدد' : formatUsd(debt.available ?? 0)}',
                ),
              ],
              if (error != null) ...<Widget>[
                const SizedBox(height: 14),
                NoticeBanner(message: error, kind: NoticeKind.error),
              ],
              const SizedBox(height: 16),
              PrimaryButton(
                label: 'تأكيد الطلب · ${formatUsd(total)}',
                icon: Icons.check_rounded,
                busy: _busy,
                onPressed: () => _submit(pay),
              ),
              if (_busy)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    'جارٍ إرسال الطلب، قد يستغرق ذلك لحظات إذا كان الخادم في وضع السكون. لا تغلق التطبيق.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: p.muted, fontSize: 13, height: 1.5),
                  ),
                ),
              if (!user.isWorkshop)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    'الدفع بالدين متاح حصريًا لحسابات الورشات.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: p.placeholder, fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// The Sham Cash transfer receipt: the web cart's pill upload button, plus a preview with change / remove.
  Widget _receiptSection(Palette p) {
    final Uint8List? receipt = _receipt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'حوّل المبلغ عبر شام كاش ثم أرفق صورة الإشعار (JPG أو PNG أو WebP، حتى 5 ميغابايت).',
          style: TextStyle(color: p.muted, fontSize: 13, height: 1.6),
        ),
        const SizedBox(height: 10),
        if (receipt == null)
          SecondaryButton(
            label: 'ارفع إشعار التحويل',
            icon: Icons.upload_rounded,
            onPressed: _busy ? null : _pickReceipt,
          )
        else ...<Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              color: p.fieldBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: p.fieldLine),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: SizedBox(
                height: 190,
                child: Image.memory(receipt, fit: BoxFit.contain),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: SecondaryButton(
                  label: 'تغيير الصورة',
                  icon: Icons.swap_horiz_rounded,
                  compact: true,
                  onPressed: _busy ? null : _pickReceipt,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SecondaryButton(
                  label: 'إزالة',
                  icon: Icons.delete_outline_rounded,
                  compact: true,
                  color: p.errText,
                  onPressed: _busy ? null : () => setState(() => _receipt = null),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// One cart entry with its quantity stepper and remove button.
class _CartLineTile extends StatelessWidget {
  const _CartLineTile({super.key, required this.line, required this.enabled});

  final CartLine line;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    final AppState state = AppScope.of(context);
    final Part part = line.part;
    final bool atLimit = line.qty >= part.maxOrderQty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
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
                    Text(
                      part.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: p.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        Text(part.brand, style: TextStyle(color: p.muted, fontSize: 12.5)),
                        Text('·', style: TextStyle(color: p.placeholder, fontSize: 12.5)),
                        PartNumberPlate(number: part.pn),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              RoundIconButton(
                icon: Icons.delete_outline_rounded,
                tooltip: 'حذف من السلة',
                size: 36,
                iconColor: p.muted,
                onTap: enabled ? () => state.removeFromCart(part.id) : null,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              QuantityStepper(
                quantity: line.qty,
                onIncrement: enabled && !atLimit
                    ? () {
                        final String? problem = state.addToCart(part);
                        if (problem != null) {
                          showSnack(context, problem);
                        }
                      }
                    : null,
                onDecrement: enabled ? () => state.decrementCart(part.id) : null,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text(
                      formatUsd(line.total),
                      style: TextStyle(color: p.text, fontSize: 16.5, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '${formatUsd(part.price)} للقطعة',
                      style: TextStyle(color: p.placeholder, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (atLimit)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'وصلت إلى أقصى كمية متاحة من هذه القطعة.',
                style: TextStyle(color: p.warn, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}
