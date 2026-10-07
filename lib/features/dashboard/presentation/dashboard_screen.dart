import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpl_wager/app/theme/app_theme.dart';
import 'package:fpl_wager/core/ui/app_header.dart';
import 'package:fpl_wager/core/ui/app_widgets.dart';
import 'package:fpl_wager/features/dashboard/domain/dashboard.dart';
import 'package:fpl_wager/features/dashboard/presentation/dashboard_controller.dart';
import 'package:fpl_wager/features/pools/domain/pool.dart';
import 'package:fpl_wager/features/pools/presentation/pools_controller.dart';
import 'package:go_router/go_router.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardProvider);
    return Scaffold(
      appBar: const AppHeader(),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dashboardProvider);
          ref.invalidate(poolsProvider);
          await ref.read(dashboardProvider.future);
        },
        child: AsyncContent(
          value: dashboard,
          onRetry: () => ref.invalidate(dashboardProvider),
          data: (value) => _DashboardBody(value: value),
        ),
      ),
    );
  }
}

class _DashboardBody extends ConsumerWidget {
  const _DashboardBody({required this.value});
  final Dashboard value;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pools = ref.watch(poolsProvider).value ?? const <Pool>[];
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 8, AppSpacing.md, 120),
      children: [
        FadeSlideIn(
          child: Text('Hello, ${value.user.firstName}', style: Theme.of(context).textTheme.headlineMedium),
        ),
        const SizedBox(height: 4),
        Text('Gameweek ${value.currentGameweek} · make every point count', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 20),
        if (value.team == null) ...[
          GradientPanel(
            onTap: () => context.push('/link-team'),
            colors: const [Color(0xFF0B4939), Color(0xFF27204D)],
            child: Row(
              children: [
                const Icon(Icons.link_rounded, color: AppColors.lime, size: 30),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Link your FPL team', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white)), const SizedBox(height: 4), const Text('Verify your team ID to enter a pool.', style: TextStyle(color: Color(0xFFC8DDD5)))])),
                const Icon(Icons.arrow_forward_rounded, color: Colors.white),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
        if (!value.user.emailVerified) ...[
          _VerifyEmailLink(email: value.user.displayEmail),
          const SizedBox(height: 14),
        ],
        _Metrics(value: value),
        const SizedBox(height: 28),
        Row(
          children: [
            Expanded(child: Text('Quick join', style: Theme.of(context).textTheme.titleLarge)),
            TextButton(onPressed: () => context.go('/pools'), child: const Text('See all')),
          ],
        ),
        const SizedBox(height: 8),
        ...pools.take(3).map((pool) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _QuickPool(pool: pool),
            )),
        const SizedBox(height: 16),
        Text('Built for a fair gameweek', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        const _Principle(icon: Icons.emoji_events_outlined, title: 'Gameweek pools', body: 'Fixed stakes and visible prize splits.'),
        const _Principle(icon: Icons.compare_arrows_rounded, title: 'Head to head', body: 'Challenge any verified FPL manager from the Pools tab.'),
        const _Principle(icon: Icons.receipt_long_outlined, title: 'Transparent wallet', body: 'Every movement has a ledger entry.'),
      ],
    );
  }
}

/// Shown until the account's email address has been confirmed with a code.
class _VerifyEmailLink extends StatelessWidget {
  const _VerifyEmailLink({required this.email});

  /// The address on the account, or empty if there isn't a real one yet.
  final String email;

  @override
  Widget build(BuildContext context) => GradientPanel(
        onTap: () => context.push('/verify-email'),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            Icon(
              Icons.mark_email_unread_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your email is not verified',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    email.isEmpty
                        ? 'Add one for receipts and important updates.'
                        : email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Verify email',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w800,
                    decoration: TextDecoration.underline,
                  ),
            ),
          ],
        ),
      );
}

class _Metrics extends StatelessWidget {
  const _Metrics({required this.value});
  final Dashboard value;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth > 540;
          final cards = <Widget>[
            _Metric(icon: Icons.account_balance_wallet_outlined, label: 'Available balance', value: money(value.wallet.availableCents), accent: AppColors.purple),
            _Metric(icon: Icons.bolt_rounded, label: 'Active entries', value: '${value.activeWagers}', accent: AppColors.lime),
          ];
          return Column(
            children: [
              if (wide)
                Row(
                  children: cards
                      .map((item) => Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: item,
                            ),
                          ))
                      .toList(),
                )
              else
                ...cards.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: item,
                    )),
              if (wide) const SizedBox(height: 14),
              if (value.deadline == null)
                const _Metric(
                  icon: Icons.timer_outlined,
                  label: 'FPL deadline',
                  value: 'Schedule syncing',
                  accent: Color(0xFF49D7F2),
                )
              else
                FlipDeadlineCountdown(
                  value.deadline!,
                  gameweek: value.currentGameweek,
                ),
            ],
          );
        },
      );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.label, required this.value, required this.accent});
  final IconData icon; final String label; final String value; final Color accent;
  @override
  Widget build(BuildContext context) => GradientPanel(
        child: Row(children: [Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: accent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(15)), child: Icon(icon, color: accent)), const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)), const SizedBox(height: 5), Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900, color: accent))]))]),
      );
}

class _QuickPool extends StatelessWidget {
  const _QuickPool({required this.pool}); final Pool pool;
  @override
  Widget build(BuildContext context) => GradientPanel(
        onTap: () => context.push('/pools/${pool.id}'),
        padding: const EdgeInsets.all(18),
        child: Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [StatusPill(pool.status), const SizedBox(width: 8), Text('GW${pool.gameweek}', style: Theme.of(context).textTheme.labelLarge)]), const SizedBox(height: 10), Text(money(pool.stakeCents), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)), Text('Join an open ${money(pool.prizePoolCents)} prize pool', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant))])), const Icon(Icons.arrow_forward_rounded)]),
      );
}

class _Principle extends StatelessWidget {
  const _Principle({required this.icon, required this.title, required this.body}); final IconData icon; final String title; final String body;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(children: [Container(padding: const EdgeInsets.all(11), decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: Theme.of(context).colorScheme.primary)), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: Theme.of(context).textTheme.titleMedium), Text(body, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant))]))]));
}
