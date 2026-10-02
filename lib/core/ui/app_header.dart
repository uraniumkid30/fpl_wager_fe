import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpl_wager/core/ui/app_widgets.dart';
import 'package:fpl_wager/features/auth/presentation/auth_controller.dart';
import 'package:fpl_wager/features/wallet/presentation/wallet_controller.dart';
import 'package:fpl_wager/features/notifications/presentation/notifications_controller.dart';
import 'package:go_router/go_router.dart';

class AppHeader extends ConsumerWidget implements PreferredSizeWidget {
  const AppHeader({super.key, this.title, this.actions = const []});
  final String? title;
  final List<Widget> actions;

  @override
  Size get preferredSize => const Size.fromHeight(68);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(walletProvider).value;
    final isAdmin = ref.watch(authControllerProvider).value?.user.isAdmin ?? false;
    final unreadNotifications = ref.watch(unreadNotificationCountProvider);
    return AppBar(
      title: title == null ? const BrandMark(compact: true) : Text(title!),
      actions: [
        ...actions,
        if (wallet != null)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: ActionChip(
              avatar: const Icon(Icons.account_balance_wallet_outlined, size: 16),
              label: Text(money(wallet.availableCents)),
              onPressed: () => context.go('/wallet'),
            ),
          ),
        if (isAdmin)
          IconButton(
            tooltip: 'Administration',
            onPressed: () => context.push('/admin'),
            icon: const Icon(Icons.admin_panel_settings_outlined),
          ),
        Badge(
          isLabelVisible: unreadNotifications > 0,
          label: Text(unreadNotifications > 99 ? '99+' : '$unreadNotifications'),
          child: IconButton(
            tooltip: 'Notifications',
            onPressed: () => context.push('/notifications'),
            icon: const Icon(Icons.notifications_outlined),
          ),
        ),
        IconButton(
          tooltip: 'Settings',
          onPressed: () => context.push('/settings'),
          icon: const Icon(Icons.tune_rounded),
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}
