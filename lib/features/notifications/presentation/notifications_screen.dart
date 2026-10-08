import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fplboardman/app/theme/app_theme.dart';
import 'package:fplboardman/core/ui/app_widgets.dart';
import 'package:fplboardman/features/notifications/domain/app_notification.dart';
import 'package:fplboardman/features/notifications/presentation/notifications_controller.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(notificationsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(notificationsProvider);
          await ref.read(notificationsProvider.future);
        },
        child: AsyncContent(
          value: value,
          onRetry: () => ref.invalidate(notificationsProvider),
          data: (items) => items.isEmpty
              ? ListView(children: const [EmptyState(icon: Icons.notifications_none_rounded, title: 'No notifications', message: 'Pool approvals and important updates will appear here.')])
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) => _NotificationCard(item: items[index]),
                ),
        ),
      ),
    );
  }
}

class _NotificationCard extends ConsumerWidget {
  const _NotificationCard({required this.item});
  final AppNotification item;

  @override
  Widget build(BuildContext context, WidgetRef ref) => GradientPanel(
        onTap: () async {
          if (item.isUnread) {
            // Being marked read is a nicety; failing to must not stop the
            // notification from opening.
            try {
              await ref.read(notificationActionProvider.notifier).markRead(item.id);
            } catch (_) {}
          }
          final route = item.route;
          if (context.mounted && route != null) openNotificationRoute(context, route);
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.14),
              child: Icon(item.kind == 'pool_approved' ? Icons.verified_rounded : Icons.notifications_rounded, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [Expanded(child: Text(item.title, style: Theme.of(context).textTheme.titleMedium)), if (item.isUnread) const StatusPill('New')]),
                  const SizedBox(height: 6),
                  Text(item.body),
                  const SizedBox(height: 8),
                  Text(DateFormat('d MMM · HH:mm').format(item.createdAt.toLocal()), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      );
}

/// Opens the page a notification points to.
///
/// Home, Pools and Profile (and the pages inside Profile, such as History)
/// live in the bottom tabs. Those are switched to rather than stacked on top
/// of this page: stacking a second copy of the tabs is what crashed the app
/// with "keyReservation.contains(key)". Every other page (a pool, Withdraw
/// and so on) opens on top, so Back returns to the notifications.
void openNotificationRoute(BuildContext context, String route) {
  final uri = Uri.tryParse(route.trim());
  if (uri == null || !uri.path.startsWith('/')) return;
  final path = uri.path;
  final inTabs = path == '/home' ||
      path == '/dashboard' ||
      path == '/pools' ||
      path == '/profile' ||
      path.startsWith('/profile/');
  if (inTabs) {
    context.go(uri.toString());
  } else {
    context.push(uri.toString());
  }
}
