import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fplboardman/app/theme/app_theme.dart';
import 'package:fplboardman/core/ui/app_header.dart';
import 'package:fplboardman/core/ui/app_widgets.dart';
import 'package:fplboardman/features/auth/presentation/auth_controller.dart';
import 'package:fplboardman/features/dashboard/domain/dashboard.dart';
import 'package:fplboardman/features/dashboard/presentation/dashboard_controller.dart';
import 'package:fplboardman/features/wallet/presentation/wallet_controller.dart';
import 'package:fplboardman/features/withdrawals/presentation/withdrawal_controller.dart';
import 'package:go_router/go_router.dart';

/// The Profile tab: who you are (account name, FPL ID, email) first, then
/// Wallet (with Top up and Withdraw), the bank account withdrawals are paid
/// to, and History. Each opens as a page underneath this one.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardProvider);
    return Scaffold(
      appBar: const AppHeader(title: 'Profile'),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dashboardProvider);
          ref.invalidate(walletProvider);
          ref.invalidate(bankAccountProvider);
          await ref.read(dashboardProvider.future);
        },
        child: AsyncContent(
          value: dashboard,
          onRetry: () => ref.invalidate(dashboardProvider),
          data: (value) => _ProfileBody(value: value),
        ),
      ),
    );
  }
}

class _ProfileBody extends ConsumerWidget {
  const _ProfileBody({required this.value});

  final Dashboard value;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = value.user;
    final team = value.team;
    final fplId = team?.entryId ?? user.fplEntryId;
    final ledgerCount = value.wallet.ledger.length;
    final bankAccount = ref.watch(bankAccountProvider);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 8, AppSpacing.md, 120),
      children: [
        // ── Account ────────────────────────────────────────────────────
        GradientPanel(
          colors: const [Color(0xFF0B4939), Color(0xFF2A174C)],
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: AppColors.lime.withValues(alpha: 0.18),
                child: Text(
                  user.firstName.characters.first.toUpperCase(),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: AppColors.lime,
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.fullName,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      team == null ? 'No FPL team linked' : team.teamName,
                      style: const TextStyle(color: Color(0xFFC9DED7)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        GradientPanel(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            children: [
              _Field(
                icon: Icons.badge_outlined,
                label: 'Account name',
                value: user.fullName,
              ),
              const Divider(height: 1),
              _Field(
                icon: Icons.sports_soccer_rounded,
                label: 'FPL ID',
                value: fplId == null ? 'Not linked' : '$fplId',
                trailing: fplId == null
                    ? TextButton(
                        onPressed: () => context.push('/link-team'),
                        child: const Text('Link team'),
                      )
                    : null,
              ),
              const Divider(height: 1),
              _Field(
                icon: Icons.mail_outline_rounded,
                label: 'Email',
                value: user.displayEmail.isEmpty
                    ? 'Not added'
                    : user.displayEmail,
                trailing: user.emailVerified
                    ? const StatusPill('Verified', color: AppColors.emerald)
                    : TextButton(
                        onPressed: () => context.push('/verify-email'),
                        child: const Text('Verify email'),
                      ),
              ),
            ],
          ),
        ),

        // ── Wallet ─────────────────────────────────────────────────────
        const SizedBox(height: 26),
        Text('Wallet', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        GradientPanel(
          onTap: () => context.go('/profile/wallet'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AVAILABLE BALANCE',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.7,
                              ),
                        ),
                        const SizedBox(height: 6),
                        FitText(
                          money(value.wallet.availableCents),
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: AppColors.purple,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${money(value.wallet.lockedCents)} locked in active games',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () async {
                        await context.push('/wallet/top-up');
                        ref.invalidate(dashboardProvider);
                        ref.invalidate(walletProvider);
                      },
                      child: const Text('Top up'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => context.push('/withdraw'),
                      child: const Text('Withdraw'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // ── Bank account ───────────────────────────────────────────────
        const SizedBox(height: 12),
        _LinkTile(
          icon: Icons.account_balance_outlined,
          title: 'Bank account',
          subtitle: bankAccount.when(
            data: (account) => account == null
                ? 'Add the account your withdrawals are paid to'
                : '${account.summary} · ${account.accountName}',
            loading: () => 'Loading…',
            error: (_, _) => 'Tap to view your bank account',
          ),
          onTap: () => context.push('/bank-account'),
        ),

        // ── History ────────────────────────────────────────────────────
        const SizedBox(height: 26),
        Text('History', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        _LinkTile(
          icon: Icons.history_rounded,
          title: 'Stakes, winnings and withdrawals',
          subtitle: ledgerCount == 0
              ? 'Nothing yet — your activity appears after you play.'
              : '$ledgerCount recent ${ledgerCount == 1 ? 'entry' : 'entries'}',
          onTap: () => context.go('/profile/history'),
        ),

        // ── Everything else ────────────────────────────────────────────
        const SizedBox(height: 26),
        _LinkTile(
          icon: Icons.tune_rounded,
          title: 'Settings',
          subtitle: 'Appearance and notifications',
          onTap: () => context.push('/settings'),
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: () async {
            await ref.read(authControllerProvider.notifier).logout();
            if (context.mounted) context.go('/welcome');
          },
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Sign out'),
        ),
      ],
    );
  }
}

/// One labelled value in the account panel, with an optional action or badge
/// on the right.
class _Field extends StatelessWidget {
  const _Field({
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ],
          ],
        ),
      );
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GradientPanel(
        onTap: onTap,
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.13),
              child: Icon(icon, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      );
}
