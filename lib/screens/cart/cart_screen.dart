// Cart tab and checkout (POST /api/orders): payment choice, Sham Cash receipt and order confirmation.
//
// Only part ids and quantities are sent; the server recomputes prices, stock and the total.
//
// The look follows the web cart: one glass card with the lines and the total, one glass card with the payment
// methods in an inset segmented track, and the blue gradient pill that confirms the order.

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';

import '../../core/api_client.dart';
import '../../core/cart.dart';
import '../../core/config.dart';
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
import '../account/addresses_screen.dart';
import '../home/tab_header.dart';
import '../../widgets/tx.dart';

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
  bool _useCashback = false;
  final TextEditingController _cashbackController = TextEditingController();
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

  Future<void> _copyShamAddress() async {
    await Clipboard.setData(const ClipboardData(text: shamCashAccountAddress));
    if (mounted) {
      showSnack(context, 'تم نسخ عنوان الحساب بنجاح');
    }
  }

  static const String _newAddressKey = '__new__';

  /// Picks the delivery address of this order from the saved ones, or adds a new one.
  Future<void> _pickAddress() async {
    final AppState state = AppScope.read(context);
    final Set<String> before = <String>{for (final SavedAddress a in state.addresses) a.id};
    final String? picked = await showChoiceSheet<String>(
      context: context,
      title: 'عنوان التسليم',
      options: <String>[for (final SavedAddress a in state.addresses) a.id, _newAddressKey],
      labelOf: (String id) {
        if (id == _newAddressKey) {
          return '+ إضافة عنوان جديد';
        }
        final SavedAddress a = state.addresses.firstWhere((SavedAddress e) => e.id == id);
        final String summary = a.summary;
        return summary.isEmpty ? a.label : '${a.label} · $summary';
      },
      selected: state.checkoutAddress?.id,
    );
    if (picked == null || !mounted) {
      return;
    }
    if (picked != _newAddressKey) {
      state.selectCheckoutAddress(picked);
      return;
    }
    final bool saved = await openAddressForm(context);
    if (saved && mounted) {
      for (final SavedAddress a in state.addresses) {
        if (!before.contains(a.id)) {
          state.selectCheckoutAddress(a.id);
          break;
        }
      }
    }
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

  Future<void> _submit(String pay, double cashbackUsed) async {
    if (_busy) {
      return;
    }
    final AppState state = AppScope.read(context);
    final AppUser? current = state.user;
    final double total = state.cartTotalAmount;
    final double availableCashback = current?.cashbackBalance ?? 0;
    if (cashbackUsed < 0 || cashbackUsed > availableCashback || cashbackUsed > total) {
      setState(() => _error = 'المبلغ المحدد أكبر من رصيد الكاش باك أو من قيمة الطلب.');
      return;
    }
    final String invoiceCurrency = state.canUseSypInvoices ? 'SYP' : 'USD';
    if (invoiceCurrency == 'USD') {
      final bool? continueInUsd = await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) => AlertDialog(
          title: const Text('تأكيد عملة الفاتورة'),
          content: const Text(
            'سعر الصرف متقلب أو غير متاح حالياً. يجب إكمال الفاتورة بالدولار الأمريكي. '
            'طريقة الدفع التي اخترتها لن تتغير.',
          ),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('رجوع')),
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('متابعة بالدولار')),
          ],
        ),
      );
      if (continueInUsd != true || !mounted) return;
    }

    // The database requires the dedicated payment method when cashback covers the whole order.
    // Do not send the default COD method for a zero-amount remainder.
    final bool fullyCoveredByCashback = cashbackUsed > 0 && (total - cashbackUsed).abs() < 0.005;
    final String effectivePay = fullyCoveredByCashback ? 'cashback' : pay;
    if (effectivePay == 'sham' && (total - cashbackUsed) > 0 && _receipt == null) {
      setState(() => _error = 'يرجى إرفاق إشعار تحويل شام كاش لإتمام الطلب.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final PlacedOrder placed = await state.placeOrder(
        pay: effectivePay,
        invoiceCurrency: invoiceCurrency,
        receipt: effectivePay == 'sham' ? _receipt : null,
        addressId: state.checkoutAddress?.id,
        cashbackUsed: cashbackUsed,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _receipt = null;
        _pay = 'cod';
        _useCashback = false;
        _cashbackController.clear();
      });
      await _showSuccess(placed, effectivePay, cashbackUsed);
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

  Future<void> _showSuccess(PlacedOrder placed, String pay, double cashbackUsed) async {
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
                (placed.total - cashbackUsed) <= 0.001
                    ? 'تم تغطية قيمة الطلب بالكامل من رصيد الكاش باك.'
                    : pay == 'debt'
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
  void dispose() {
    _cashbackController.dispose();
    super.dispose();
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
    final double cashbackBalance = user.isWorkshop ? (user.cashbackBalance ?? 0).clamp(0, double.infinity).toDouble() : 0;
    final double cashbackUsed = _useCashback ? (double.tryParse(_cashbackController.text.trim()) ?? 0) : 0;
    final double amountDue = (total - cashbackUsed).clamp(0, double.infinity).toDouble();
    final List<String> methods = payMethodsFor(user);
    final DebtCheck debt = checkDebtPayment(user: user, total: amountDue);
    String pay = _pay;
    if (!methods.contains(pay) || (pay == 'debt' && !debt.allowed)) {
      pay = 'cod';
    }
    final String? error = _error;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: <Widget>[
        if (!state.canUseSypInvoices) ...<Widget>[
          const NoticeBanner(
            message: 'سعر الصرف متقلب أو غير متاح. ستصدر الفاتورة بالدولار بعد موافقتك، دون تغيير طريقة الدفع.',
            kind: NoticeKind.warning,
          ),
          const SizedBox(height: 10),
        ],
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
                  invoiceCurrency: state.canUseSypInvoices ? 'SYP' : 'USD',
                  invoiceRate: state.invoiceRate,
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
                    formatInvoiceAmount(total, currency: state.canUseSypInvoices ? 'SYP' : 'USD', rate: state.invoiceRate),
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
        if (user.isWorkshop && cashbackBalance > 0) ...<Widget>[
          const SizedBox(height: 12),
          Panel(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _useCashback,
                  onChanged: _busy ? null : (bool value) => setState(() {
                    _useCashback = value;
                    _error = null;
                    if (value) {
                      final double full = cashbackBalance < total ? cashbackBalance : total;
                      _cashbackController.text = full.toStringAsFixed(2);
                    } else {
                      _cashbackController.clear();
                    }
                  }),
                  title: Text('استخدام رصيد الكاش باك', style: TextStyle(color: p.text, fontWeight: FontWeight.w700)),
                  subtitle: Text(
                    'الرصيد المتاح: ${formatUsd(cashbackBalance)}',
                    style: TextStyle(color: p.muted, fontSize: 12.5),
                  ),
                  activeTrackColor: p.primary,
                ),
                if (_useCashback) ...<Widget>[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: TextFormField(
                      controller: _cashbackController,
                      enabled: !_busy,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                      ],
                      onChanged: (_) => setState(() => _error = null),
                      style: TextStyle(color: p.text, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        labelText: 'المبلغ المراد استخدامه',
                        prefixText: '\$ ',
                        helperText: 'يمكنك استخدام كامل الرصيد أو تحديد جزء منه',
                        filled: true,
                        fillColor: p.fieldBg,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
        if (cashbackUsed > 0) ...<Widget>[
          const SizedBox(height: 10),
          Panel(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              children: <Widget>[
                InfoRow(label: 'الكاش باك المستخدم', value: '-${formatUsd(cashbackUsed)}'),
                const SizedBox(height: 5),
                InfoRow(label: 'المتبقي للدفع', value: formatUsd(amountDue), bold: true),
              ],
            ),
          ),
        ],
        if (state.addressesReady) ...<Widget>[
          const SizedBox(height: 14),
          _addressPanel(p, state),
        ],
        if (amountDue > 0) ...<Widget>[
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
              if (pay == 'sham' && amountDue > 0) ...<Widget>[
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
              const SizedBox(height: 16),
              PrimaryButton(
                label: 'تأكيد الطلب · ${formatInvoiceAmount(amountDue, currency: state.canUseSypInvoices ? 'SYP' : 'USD', rate: state.invoiceRate)}',
                icon: Icons.check_rounded,
                busy: _busy,
                onPressed: () => _submit(pay, cashbackUsed),
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
        if (amountDue <= 0) ...<Widget>[
          const SizedBox(height: 14),
          Panel(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: <Widget>[
                Icon(Icons.verified_rounded, color: p.ok),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'سيتم دفع الطلب بالكامل من رصيد الكاش باك، ولا يلزم اختيار طريقة دفع أو إرفاق إيصال.',
                    style: TextStyle(color: p.text, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          PrimaryButton(
            label: 'تأكيد الطلب · ${formatInvoiceAmount(total, currency: state.canUseSypInvoices ? 'SYP' : 'USD', rate: state.invoiceRate)}',
            icon: Icons.check_rounded,
            busy: _busy,
            onPressed: () => _submit(pay, cashbackUsed),
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
        ],
        if (error != null) ...<Widget>[
          const SizedBox(height: 14),
          NoticeBanner(message: error, kind: NoticeKind.error),
        ],
      ],
    );
  }

  /// The delivery address of the order: the chosen saved address, or a button to add one.
  Widget _addressPanel(Palette p, AppState state) {
    final SavedAddress? address = state.checkoutAddress;
    return Panel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.location_on_outlined, color: p.primary, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'عنوان التسليم',
                  style: TextStyle(color: p.text, fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (address == null) ...<Widget>[
            Text(
              'احفظ عنوان التسليم ليُرفق بطلبك.',
              style: TextStyle(color: p.muted, fontSize: 13.5, height: 1.5),
            ),
            const SizedBox(height: 10),
            SecondaryButton(
              label: 'إضافة عنوان',
              icon: Icons.add_location_alt_outlined,
              compact: true,
              onPressed: _busy ? null : () => openAddressForm(context),
            ),
          ] else ...<Widget>[
            Text(
              address.label,
              style: TextStyle(color: p.text, fontSize: 15, fontWeight: FontWeight.w700),
            ),
            if (address.summary.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  address.summary,
                  style: TextStyle(color: p.muted, fontSize: 13.5, height: 1.5),
                ),
              ),
            const SizedBox(height: 10),
            SecondaryButton(
              label: 'تغيير العنوان',
              icon: Icons.swap_horiz_rounded,
              compact: true,
              onPressed: _busy ? null : _pickAddress,
            ),
          ],
        ],
      ),
    );
  }

  /// The Sham Cash account: the barcode, the account name and the account address with a copy button.
  Widget _shamAccount(Palette p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: p.line),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Image.asset(
                shamCashQrAsset,
                width: 220,
                height: 220,
                fit: BoxFit.contain,
                semanticLabel: 'باركود حساب شام كاش',
                errorBuilder: (BuildContext context, Object error, StackTrace? stack) => const SizedBox(
                  width: 220,
                  height: 220,
                  child: Center(child: Icon(Icons.qr_code_2_rounded, size: 64, color: Colors.black26)),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        InfoRow(label: 'اسم الحساب', value: shamCashAccountName, bold: true),
        const SizedBox(height: 6),
        Text('عنوان الحساب', style: TextStyle(color: p.muted, fontSize: 13)),
        const SizedBox(height: 4),
        Row(
          children: <Widget>[
            Expanded(
              child: SelectableText(
                shamCashAccountAddress,
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.start,
                style: TextStyle(color: p.text, fontSize: 14, fontWeight: FontWeight.w600, height: 1.4),
              ),
            ),
            RoundIconButton(
              icon: Icons.copy_rounded,
              tooltip: 'نسخ عنوان الحساب',
              onTap: _copyShamAddress,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'امسح الباركود من تطبيق شام كاش أو انسخ عنوان الحساب وحوّل المبلغ، ثم أرفق صورة الإشعار. '
          'تتحقق الإدارة من التحويل يدوياً بعد استلام الطلب.',
          style: TextStyle(color: p.muted, fontSize: 12.5, height: 1.6),
        ),
        const SizedBox(height: 14),
      ],
    );
  }

  /// The Sham Cash transfer receipt: the web cart's pill upload button, plus a preview with change / remove.
  Widget _receiptSection(Palette p) {
    final Uint8List? receipt = _receipt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _shamAccount(p),
        Text(
          'بعد التحويل أرفق صورة الإشعار (JPG أو PNG أو WebP، حتى 5 ميغابايت).',
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
  const _CartLineTile({super.key, required this.line, required this.enabled, required this.invoiceCurrency, this.invoiceRate});

  final CartLine line;
  final bool enabled;
  final String invoiceCurrency;
  final double? invoiceRate;

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
                      formatInvoiceAmount(line.total, currency: invoiceCurrency, rate: invoiceRate),
                      style: TextStyle(color: p.text, fontSize: 16.5, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '${formatInvoiceAmount(part.price, currency: invoiceCurrency, rate: invoiceRate)} للقطعة',
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
