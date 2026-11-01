import 'package:flutter/material.dart' hide Text;

import '../../core/models.dart';
import '../../state/app_state.dart';
import '../../theme/palette.dart';
import '../../widgets/backdrop.dart';
import '../../widgets/panel.dart';
import '../../widgets/tx.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AppScope.read(context).loadNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final Palette p = Palette.of(context);
    return AppBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('الإشعارات'),
          backgroundColor: Colors.transparent,
          actions: <Widget>[
            if (state.unreadNotificationCount > 0)
              TextButton.icon(
                onPressed: () => state.markNotificationsRead(),
                icon: const Icon(Icons.done_all_rounded, size: 18),
                label: const Text('قراءة الكل'),
              ),
          ],
        ),
        body: RefreshIndicator(
          color: p.primary,
          backgroundColor: p.panel,
          onRefresh: () => state.loadNotifications(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: <Widget>[
              if (state.notificationsError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(state.notificationsError!, style: TextStyle(color: p.errText)),
                ),
              if (state.notifications.isEmpty)
                Panel(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      children: <Widget>[
                        Icon(Icons.notifications_none_rounded, size: 38, color: p.muted),
                        const SizedBox(height: 10),
                        Text(
                          state.notificationsLoading ? 'جارٍ تحميل الإشعارات...' : 'ما عندك إشعارات حالياً',
                          style: TextStyle(color: p.muted),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Panel(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Column(
                    children: <Widget>[
                      for (int i = 0; i < state.notifications.length; i++) ...<Widget>[
                        if (i > 0) Divider(height: 1, color: p.line),
                        _NotificationTile(item: state.notifications[i]),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item});

  final UserNotification item;

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    final IconData glyph = switch (item.type) {
      'cashback' => Icons.savings_outlined,
      'loyalty' => Icons.workspace_premium_outlined,
      'payment' => Icons.account_balance_wallet_outlined,
      'debt' => Icons.menu_book_outlined,
      'order' => Icons.receipt_long_outlined,
      _ => Icons.notifications_outlined,
    };
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      leading: CircleAvatar(
        backgroundColor: (item.isRead ? p.muted : p.primary).withValues(alpha: 0.12),
        child: Icon(glyph, color: item.isRead ? p.muted : p.primary),
      ),
      title: Text(
        item.title,
        style: TextStyle(color: p.text, fontWeight: item.isRead ? FontWeight.w500 : FontWeight.w800),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(item.body, style: TextStyle(color: p.muted, height: 1.5)),
      ),
      trailing: item.isRead ? null : Icon(Icons.circle, color: p.primary, size: 9),
    );
  }
}
