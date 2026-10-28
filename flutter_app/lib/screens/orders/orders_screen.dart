// Orders tab: the caller's orders (GET /api/orders) and special requests (GET /api/special-requests).
// The switch between the two lists is the web app's inset segmented track.

import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../state/app_state.dart';
import '../../theme/palette.dart';
import '../../widgets/feedback.dart';
import '../../widgets/inputs.dart';
import '../../widgets/panel.dart';
import '../../widgets/segmented.dart';
import '../home/tab_header.dart';
import '../special/special_request_screen.dart';
import 'order_card.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final OrdersView view = state.ordersView;

    return Column(
      children: <Widget>[
        const TabHeader(
          title: 'طلباتي',
          subtitle: 'تابع حالة طلباتك وطلباتك الخاصة',
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          child: SegmentedTrack<OrdersView>(
            selected: view,
            onChanged: state.setOrdersView,
            options: const <SegmentOption<OrdersView>>[
              SegmentOption<OrdersView>(value: OrdersView.orders, label: 'الطلبات'),
              SegmentOption<OrdersView>(value: OrdersView.requests, label: 'الطلبات الخاصة'),
            ],
          ),
        ),
        Expanded(
          child: view == OrdersView.orders ? const _OrdersList() : const _RequestsList(),
        ),
      ],
    );
  }
}

class _OrdersList extends StatelessWidget {
  const _OrdersList();

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    final AppState state = AppScope.of(context);
    final List<Order> orders = state.orders;
    final String? error = state.ordersError;

    final Widget content;
    if (!state.ordersLoaded) {
      content = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: <Widget>[
          if (error != null)
            NoticeBanner(
              message: error,
              kind: NoticeKind.error,
              onRetry: () => state.loadOrders(),
            )
          else
            const LoadingBlock(message: 'جارٍ تحميل طلباتك...'),
        ],
      );
    } else if (orders.isEmpty) {
      content = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: <Widget>[
          if (error != null) ...<Widget>[
            NoticeBanner(
              message: error,
              kind: NoticeKind.error,
              onRetry: () => state.loadOrders(),
            ),
            const SizedBox(height: 10),
          ],
          Panel(
            padding: EdgeInsets.zero,
            child: EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'لا توجد طلبات بعد',
              message: 'ستظهر طلباتك هنا بعد إتمام أول عملية شراء.',
              actionLabel: 'تصفّح الكتالوج',
              onAction: () => state.selectTab(tabCatalog),
            ),
          ),
        ],
      );
    } else {
      final int extra = error != null ? 1 : 0;
      content = ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: orders.length + extra,
        itemBuilder: (BuildContext context, int index) {
          if (error != null && index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: NoticeBanner(
                message: error,
                kind: NoticeKind.error,
                onRetry: () => state.loadOrders(),
              ),
            );
          }
          final Order order = orders[index - extra];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: OrderCard(key: ValueKey<String>(order.id), order: order),
          );
        },
      );
    }

    return RefreshIndicator(
      color: p.primary,
      backgroundColor: p.panel,
      onRefresh: () => state.loadOrders(),
      child: content,
    );
  }
}

class _RequestsList extends StatelessWidget {
  const _RequestsList();

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    final AppState state = AppScope.of(context);
    final List<SpecialRequest> requests = state.requests;
    final String? error = state.requestsError;

    final List<Widget> children = <Widget>[
      PrimaryButton(
        label: 'طلب قطعة جديدة',
        icon: Icons.add_rounded,
        onPressed: () => openSpecialRequest(context),
      ),
      const SizedBox(height: 14),
    ];

    if (!state.requestsLoaded) {
      if (error != null) {
        children.add(
          NoticeBanner(
            message: error,
            kind: NoticeKind.error,
            onRetry: () => state.loadRequests(),
          ),
        );
      } else {
        children.add(const LoadingBlock(message: 'جارٍ تحميل طلباتك الخاصة...'));
      }
    } else {
      if (error != null) {
        children.add(
          NoticeBanner(
            message: error,
            kind: NoticeKind.error,
            onRetry: () => state.loadRequests(),
          ),
        );
        children.add(const SizedBox(height: 10));
      }
      if (requests.isEmpty) {
        children.add(
          const Panel(
            padding: EdgeInsets.zero,
            child: EmptyState(
              icon: Icons.travel_explore_rounded,
              title: 'لا توجد طلبات خاصة',
              message: 'القطعة غير متوفرة في الكتالوج؟ اطلبها وسنؤمّنها لك ونرسل لك السعر.',
            ),
          ),
        );
      } else {
        for (final SpecialRequest request in requests) {
          children.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: RequestCard(key: ValueKey<String>(request.id), request: request),
            ),
          );
        }
      }
    }

    return RefreshIndicator(
      color: p.primary,
      backgroundColor: p.panel,
      onRefresh: () => state.loadRequests(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: children,
      ),
    );
  }
}
