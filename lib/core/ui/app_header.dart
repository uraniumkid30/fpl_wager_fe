import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpl_wager/core/ui/app_widgets.dart';
import 'package:fpl_wager/features/wallet/presentation/wallet_controller.dart';
import 'package:go_router/go_router.dart';

class AppHeader extends ConsumerWidget implements PreferredSizeWidget {
  const AppHeader({super.key, this.title});
  final String? title;

  @override
  Size get preferredSize => const Size.fromHeight(68);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(walletProvider).value;
    return AppBar(
      title: title == null ? const BrandMark(compact: true) : Text(title!),
      actions: [
        if (wallet != null)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: ActionChip(
              avatar: const Icon(Icons.account_balance_wallet_outlined, size: 16),
              label: Text(money(wallet.availableCents)),
              onPressed: () => context.go('/wallet'),
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

