// Dashboard tab. A workshop sees cashback, debt, its tier estimate, its orders and the debt ledger
// (GET /api/workshop/dashboard); a marketer sees the invitation link and commissions
// (GET /api/marketer/dashboard).
//
// The cards, the blue progress bars and the hairline lists follow the web dashboards (workshop / marketer pages).

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';

import '../../core/api_client.dart';
import '../../core/config.dart';
import '../../core/format.dart';
import '../../core/labels.dart';
import '../../core/models.dart';
import '../../state/app_state.dart';
import '../../theme/palette.dart';
import '../../widgets/feedback.dart';
import '../../widgets/inputs.dart';
import '../../widgets/panel.dart';
import '../../widgets/pickers.dart';
import '../home/tab_header.dart';
import 'dashboard_widgets.dart';
import '../../widgets/tx.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final AppUser? user = state.user;
    if (user == null) {
      return const SizedBox.shrink();
    }
    final Palette p = Palette.of(context);
    final bool marketer = user.isMarketer;
    final String? error = state.dashboardError;
    final WorkshopDashboard? workshop = state.workshopDashboard;
    final MarketerDashboard? seller = state.marketerDashboard;

    final List<Widget> children = <Widget>[];
    if (!state.dashboardLoaded) {
      if (error != null) {
        children.add(
          NoticeBanner(
            message: error,
            kind: NoticeKind.error,
            onRetry: () => state.loadDashboard(),
          ),
        );
      } else {
        children.add(const LoadingBlock(message: 'جارٍ تحميل بيانات حسابك...'));
      }
    } else {
      if (error != null) {
        children.add(
          NoticeBanner(
            message: error,
            kind: NoticeKind.error,
            onRetry: () => state.loadDashboard(),
          ),
        );
        children.add(const SizedBox(height: 12));
      }
      if (marketer && seller != null) {
        children.addAll(_marketerChildren(context, seller));
      } else if (!marketer && workshop != null) {
        children.addAll(_workshopChildren(context, workshop));
      }
    }

    String subtitle = marketer
        ? 'عمولة 2% على طلبات الورشات المسجّلة عبر رابطك'
        : 'ملخص حساب الورشة وطلباتها';
    if (!marketer && workshop != null && workshop.name.isNotEmpty) {
      subtitle = workshop.name;
    }

    return Column(
      children: <Widget>[
        TabHeader(
          title: marketer ? 'لوحة المسوّق' : 'لوحة الورشة',
          subtitle: subtitle,
        ),
        Expanded(
          child: RefreshIndicator(
            color: p.primary,
            backgroundColor: p.panel,
            onRefresh: () => state.loadDashboard(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: children,
            ),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------ workshop

  List<Widget> _workshopChildren(BuildContext context, WorkshopDashboard data) {
    final Palette p = Palette.of(context);
    final double balance = data.debtBalance;
    final int? daysLeft = data.debtDaysLeft(DateTime.now());
    final bool urgent = balance > 0 && daysLeft != null && daysLeft <= 7;
    final double? limit = data.debtLimit;
    final TierStep tier = data.currentTier;
    final TierStep? next = data.nextTier;
    final List<Order> cash = data.cashOrders.take(5).toList();
    final List<Order> debt = data.debtOrders.take(5).toList();

    String debtNote;
    if (balance <= 0) {
      debtNote = 'لا يوجد دين مسجّل عليك';
    } else if (daysLeft == null) {
      debtNote = 'موعد التسديد غير متاح حالياً';
    } else {
      debtNote = 'الوقت المتبقي من آخر قيد دين: $daysLeft يومًا';
    }

    String limitNote;
    if (limit == null) {
      limitNote = 'لم يتم تحديد سقف الدين بعد.';
    } else if (limit <= 0) {
      limitNote = 'الدفع بالدين غير مفعّل لحسابك بعد، تواصل مع الإدارة.';
    } else {
      final double left = limit - balance;
      limitNote = 'المتاح حالياً: ${formatUsd(left < 0 ? 0.0 : left)}';
    }

    return <Widget>[
      MetricCard(
        icon: Icons.account_balance_wallet_outlined,
        label: 'رصيد الكاش باك',
        value: formatUsd(data.cashbackBalance),
        note: 'الرصيد المسجّل على حسابك لدى الإدارة.',
      ),
      const SizedBox(height: 12),
      MetricCard(
        icon: Icons.schedule_rounded,
        accent: urgent ? p.err : p.primary,
        borderColor: urgent ? p.err.withValues(alpha: 0.6) : null,
        label: 'الدين المستحق',
        value: formatUsd(balance),
        note: debtNote,
        footer: balance > 0 && daysLeft != null
            ? ProgressBar(
                value: (debtWindowDays - daysLeft) / debtWindowDays,
                color: urgent ? p.err : null,
                height: 6,
              )
            : null,
      ),
      const SizedBox(height: 12),
      MetricCard(
        icon: Icons.menu_book_outlined,
        label: 'سقف دفتر الدين',
        value: limit == null ? 'غير محدد' : formatUsd(limit),
        note: limitNote,
      ),
      const SizedBox(height: 12),
      Panel(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.workspace_premium_outlined, color: p.primary, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'مرتبتك الحالية حسب سجل الولاء',
                    style: TextStyle(color: p.text, fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  tooltip: 'شرح نظام الولاء',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.info_outline_rounded, color: p.primary, size: 22),
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (BuildContext dialogContext) => AlertDialog(
                      title: const Text('كيف يعمل نظام الولاء؟'),
                      content: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            const Text(
                              'تبدأ دورة الولاء من أول عملية شراء، وتستمر 90 يوماً. تُحتسب المشتريات المعتمدة خلال الدورة، وكلما زاد مجموع مشترياتك انتقلت إلى المرتبة التالية وارتفعت نسبة الكاش باك.',
                              style: TextStyle(height: 1.6),
                            ),
                            const SizedBox(height: 14),
                            for (final TierStep step in estimatedTiers)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: Text(
                                        step.minSpend == 0
                                            ? step.name
                                            : '${step.name} — بعد ${formatUsd(step.minSpend)}',
                                        style: const TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    Text(
                                      step.cashback,
                                      style: TextStyle(
                                        color: Palette.of(dialogContext).primary,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 4),
                            const Text(
                              'تُصفّر المشتريات المحتسبة عند انتهاء دورة الـ90 يوماً، وتبدأ دورة جديدة.',
                              style: TextStyle(height: 1.6),
                            ),
                          ],
                        ),
                      ),
                      actions: <Widget>[
                        TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          child: const Text('فهمت'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '${tier.name} · كاش باك ${tier.cashback}',
              style: TextStyle(
                color: p.primary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            if (next != null) ...<Widget>[
              const SizedBox(height: 2),
              Text(
                'باقي ${formatUsd(next.minSpend - data.approvedSpend)} للوصول إلى ${next.name}',
                style: TextStyle(color: p.muted, fontSize: 13.5),
              ),
            ],
            const SizedBox(height: 12),
            ProgressBar(value: data.tierProgress, height: 12),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                for (int i = 0; i < estimatedTiers.length; i++)
                  Expanded(
                    child: Text(
                      estimatedTiers[i].name,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: i <= data.tierIndex ? p.primary : p.placeholder,
                        fontSize: 11,
                        fontWeight: i <= data.tierIndex ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'المشتريات المحتسبة في الموسم الحالي: ${formatUsd(data.seasonSpend)}. تعتمد المرتبة ونسبة الكاش باك من قاعدة البيانات.',
              style: TextStyle(color: p.placeholder, fontSize: 12, height: 1.6),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      OrderGroup(
        title: 'طلبات الدفع النقدي / شام كاش',
        color: p.ok,
        orders: cash,
        total: _sum(cash),
      ),
      const SizedBox(height: 12),
      OrderGroup(
        title: 'طلبات دفتر الدين',
        color: p.warn,
        orders: debt,
        total: _sum(debt),
      ),
      const SizedBox(height: 12),
      _LedgerPanel(entries: data.ledger.take(5).toList()),
    ];
  }

  double _sum(List<Order> orders) {
    double total = 0.0;
    for (final Order order in orders) {
      total += order.total;
    }
    return roundMoney(total);
  }

  // ------------------------------------------------------------------ marketer

  List<Widget> _marketerChildren(BuildContext context, MarketerDashboard data) {
    final Palette p = Palette.of(context);
    final Commissions c = data.commissions;
    return <Widget>[
      _InvitationPanel(data: data),
      const SizedBox(height: 12),
      _PayoutRequestPanel(data: data),
      const SizedBox(height: 12),
      MetricCard(
        compact: true,
        valueColor: p.ok,
        label: 'عمولات متاحة للدفع',
        value: formatUsd(c.available),
      ),
      const SizedBox(height: 12),
      MetricCard(
        compact: true,
        label: 'عمولات معلّقة حتى تسديد الدين',
        value: formatUsd(c.held),
      ),
      const SizedBox(height: 12),
      MetricCard(
        compact: true,
        label: 'عمولات بطلب تحويل',
        value: formatUsd(c.requested),
      ),
      const SizedBox(height: 12),
      MetricCard(
        compact: true,
        label: 'إجمالي الورشات المرتبطة',
        value: '${data.workshops}',
      ),
      const SizedBox(height: 12),
      Panel(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            DecoratedBox(
              decoration: BoxDecoration(
                color: p.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: p.line),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Icon(Icons.groups_2_outlined, color: p.primary, size: 24),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'شبكة ورشاتك',
                    style: TextStyle(
                      color: p.text,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'إجمالي العمولات المسجّلة: ${formatUsd(c.total)} · المدفوع منها: ${formatUsd(c.paid)}',
                    style: TextStyle(color: p.muted, fontSize: 12.5, height: 1.5),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'تُسجّل العمولة بعد تسليم الطلب. عمولات طلبات الدين تبقى معلّقة حتى تسديد دين الورشة بالكامل.',
                    style: TextStyle(color: p.placeholder, fontSize: 12.5, height: 1.6),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ];
  }
}


class _PayoutRequestPanel extends StatefulWidget {
  const _PayoutRequestPanel({required this.data});
  final MarketerDashboard data;
  @override
  State<_PayoutRequestPanel> createState() => _PayoutRequestPanelState();
}

class _PayoutRequestPanelState extends State<_PayoutRequestPanel> {
  final TextEditingController _details = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _request() async {
    if (_busy || widget.data.commissions.available <= 0) return;
    final String details = _details.text.trim();
    if (details.length < 6) {
      showSnack(context, 'اكتب بيانات استلام التحويل بشكل واضح.');
      return;
    }
    setState(() => _busy = true);
    try {
      await AppScope.read(context).requestMarketerPayout(details);
      if (!mounted) return;
      _details.clear();
      showSnack(context, 'تم إرسال طلب سحب العمولات للإدارة.');
    } on ApiException catch (error) {
      if (mounted) showSnack(context, error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    final MarketerPayoutRequest? request = widget.data.payoutRequest;
    final bool pending = request?.status == 'pending';
    return Panel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('طلب تحويل العمولات', style: TextStyle(color: p.text, fontSize: 15.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 5),
          Text('المتاح للتحويل: ${formatUsd(widget.data.commissions.available)}. اكتب بيانات الحساب أو المحفظة التي تريد استلام المبلغ عليها.', style: TextStyle(color: p.muted, fontSize: 12.5, height: 1.6)),
          if (pending) ...<Widget>[
            const SizedBox(height: 10),
            StatusChip(label: 'طلب تحويل قيد المراجعة · ${formatUsd(request!.amount)}', tone: StatusTone.waiting),
          ] else ...<Widget>[
            const SizedBox(height: 12),
            TextField(
              controller: _details,
              minLines: 2,
              maxLines: 4,
              maxLength: 1000,
              textDirection: TextDirection.rtl,
              decoration: const InputDecoration(
                hintText: 'مثال: اسم المحفظة ورقم الحساب أو بيانات الاستلام',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            PrimaryButton(
              label: _busy ? 'جارٍ إرسال الطلب...' : 'طلب تحويل ${formatUsd(widget.data.commissions.available)}',
              icon: Icons.account_balance_wallet_outlined,
              onPressed: _busy || widget.data.commissions.available <= 0 ? null : _request,
            ),
          ],
        ],
      ),
    );
  }
}

/// The marketer's invitation link with copy and WhatsApp share.
class _InvitationPanel extends StatelessWidget {
  const _InvitationPanel({required this.data});

  final MarketerDashboard data;

  Future<void> _copy(BuildContext context, String link) async {
    await Clipboard.setData(ClipboardData(text: link));
    if (context.mounted) {
      showSnack(context, 'تم نسخ رابط الدعوة');
    }
  }

  Future<void> _share(BuildContext context, String link) async {
    final String text = 'سجّل ورشتك في اليورو: $link';
    final bool opened = await openExternalUrl('https://wa.me/?text=${Uri.encodeComponent(text)}');
    if (!opened && context.mounted) {
      showSnack(context, 'تعذر فتح واتساب. تأكد من تثبيته أو انسخ الرابط وأرسله يدوياً.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    final String link = data.referralUrl;
    final bool hasLink = link.isNotEmpty;

    return Panel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'رابط الدعوة الخاص بك',
            style: TextStyle(color: p.muted, fontSize: 14),
          ),
          const SizedBox(height: 8),
          FieldShell(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              child: hasLink
                  ? SelectableText(
                      link,
                      textDirection: TextDirection.ltr,
                      style: TextStyle(color: p.text, fontSize: 13.5, height: 1.5),
                    )
                  : Text(
                      'لا يوجد كود دعوة لحسابك',
                      style: TextStyle(color: p.placeholder, fontSize: 14),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: SecondaryButton(
                  label: 'نسخ',
                  icon: Icons.copy_rounded,
                  onPressed: hasLink ? () => _copy(context, link) : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PrimaryButton(
                  label: 'واتساب',
                  icon: Icons.share_rounded,
                  onPressed: hasLink ? () => _share(context, link) : null,
                ),
              ),
            ],
          ),
          if (data.code.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              'كود الدعوة: ${data.code}',
              style: TextStyle(color: p.placeholder, fontSize: 12.5),
            ),
          ],
        ],
      ),
    );
  }
}

/// The last debt ledger entries of a workshop.
class _LedgerPanel extends StatelessWidget {
  const _LedgerPanel({required this.entries});

  final List<LedgerEntry> entries;

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
              'آخر حركات دفتر الدين',
              style: TextStyle(color: p.text, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -0.2),
            ),
            const SizedBox(height: 6),
            if (entries.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  'لا توجد حركات دين مسجّلة.',
                  style: TextStyle(color: p.placeholder, fontSize: 13.5),
                ),
              )
            else
              for (int i = 0; i < entries.length; i++) _LedgerRow(entry: entries[i], divider: i > 0),
          ],
        ),
      ),
    );
  }
}

class _LedgerRow extends StatelessWidget {
  const _LedgerRow({required this.entry, required this.divider});

  final LedgerEntry entry;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    final String? note = entry.note;
    final String title = (note != null && note.isNotEmpty)
        ? note
        : (entry.isPayment ? 'تسديد دين' : 'قيد دين');
    return DashboardRow(
      divider: divider,
      title: title,
      caption: '${formatDate(entry.createdAt)} · ${ledgerTxLabel(entry.type)}',
      amount: formatUsd(entry.amount),
      amountColor: entry.isPayment ? p.ok : null,
    );
  }
}
