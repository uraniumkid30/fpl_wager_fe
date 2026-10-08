import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fplboardman/core/ui/app_widgets.dart';
import 'package:fplboardman/core/ui/wallet_icon.dart';
import 'package:fplboardman/features/wallet/presentation/wallet_controller.dart';
import 'package:fplboardman/features/notifications/presentation/notifications_controller.dart';
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
    final unreadNotifications = ref.watch(unreadNotificationCountProvider);
    return AppBar(
      // On a narrow phone the name gives way to the balance beside it.
      title: title == null
          ? const FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: BrandMark(compact: true),
            )
          : Text(title!),
      actions: [
        ...actions,
        if (wallet != null)
          Padding(
            padding: const EdgeInsets.only(right: 2),
            child: _WalletPill(
              cents: wallet.availableCents,
              onTap: () => context.go('/profile/wallet'),
            ),
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

/// The wallet balance in the header. Tapping it opens the wallet.
///
/// The figure comes from the wallet the app keeps current (see
/// `wallet_live.dart`), and counts up or down to a new balance when it
/// changes, so a top-up or a win is seen to arrive.
class _WalletPill extends StatelessWidget {
  const _WalletPill({required this.cents, required this.onTap});

  /// The available balance in cents (kobo).
  final int cents;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = scheme.primary;
    return Semantics(
      button: true,
      label: 'Wallet balance ${money(cents)}',
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: accent.withValues(alpha: 0.09),
        shape: StadiumBorder(
          side: BorderSide(color: accent.withValues(alpha: 0.26)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(5, 5, 12, 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: WalletIcon(size: 16, color: accent, strokeWidth: 1.7),
                ),
                const SizedBox(width: 8),
                // A very large balance shrinks to fit rather than pushing
                // the other buttons off the bar.
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 108),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(end: cents.toDouble()),
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) => Text(
                        money(value.round()),
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          // Digits of equal width, so the figure does not
                          // jiggle while it counts.
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
