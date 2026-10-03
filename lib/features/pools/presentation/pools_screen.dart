import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpl_wager/app/theme/app_theme.dart';
import 'package:fpl_wager/core/ui/app_header.dart';
import 'package:fpl_wager/core/ui/app_notice.dart';
import 'package:fpl_wager/core/ui/app_widgets.dart';
import 'package:fpl_wager/features/fpl_team/presentation/team_requirement.dart';
import 'package:fpl_wager/features/pools/domain/pool.dart';
import 'package:fpl_wager/features/pools/presentation/pool_card.dart';
import 'package:fpl_wager/features/pools/presentation/pools_controller.dart';
import 'package:fpl_wager/features/wallet/presentation/insufficient_funds.dart';
import 'package:go_router/go_router.dart';

class PoolsScreen extends ConsumerWidget {
  const PoolsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pools = ref.watch(poolsProvider);
    final action = ref.watch(poolActionProvider);
    return Scaffold(
      appBar: const AppHeader(title: 'Gameweek pools'),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(poolsProvider);
          await ref.read(poolsProvider.future);
        },
        child: AsyncContent(
          value: pools,
          onRetry: () => ref.invalidate(poolsProvider),
          data: (items) {
            final autoPools = items.where((item) => item.isAuto).toList();
            final customPools = items.where((item) => !item.isAuto).toList();
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                8,
                AppSpacing.md,
                120,
              ),
              children: [
                Text(
                  'Choose a standard auto pool or create something custom.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 22),
                _SectionTitle(
                  title: 'Auto pools',
                  subtitle: '₦1,000 · ₦2,000 · ₦5,000',
                  count: autoPools.length,
                ),
                const SizedBox(height: 12),
                if (autoPools.isEmpty)
                  const _AutoPoolsSyncing()
                else
                  ...autoPools.indexed.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: FadeSlideIn(
                        delay: Duration(milliseconds: entry.$1 * 55),
                        child: PoolCard(
                          pool: entry.$2,
                          joining: action.isLoading,
                          onJoin: () => _joinPool(context, ref, entry.$2),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                _HeadToHeadCard(onTap: () => context.push('/challenges')),
                const SizedBox(height: 28),
                _SectionTitle(
                  title: 'Custom pools',
                  subtitle: 'Community pools reviewed by FPLwager',
                  count: customPools.length,
                ),
                const SizedBox(height: 12),
                if (customPools.isEmpty)
                  const EmptyState(
                    icon: Icons.tune_rounded,
                    title: 'No custom pools yet',
                    message: 'Approved custom pools and your pending submissions appear here.',
                  )
                else
                  ...customPools.indexed.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: FadeSlideIn(
                        delay: Duration(milliseconds: entry.$1 * 55),
                        child: PoolCard(
                          pool: entry.$2,
                          joining: action.isLoading,
                          onJoin: () => _joinPool(context, ref, entry.$2),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                _CreateCustomPoolCard(
                  onTap: () => _createPool(context, ref),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _createPool(BuildContext context, WidgetRef ref) async {
    final submitted = await openTeamProtectedRoute<bool>(
      context,
      ref,
      action: TeamProtectedAction.pool,
      route: '/pools/create',
    );
    if (submitted == true) ref.invalidate(poolsProvider);
  }

  Future<void> _joinPool(
    BuildContext context,
    WidgetRef ref,
    Pool pool,
  ) async {
    final hasTeam = await requireLinkedFplTeam(
      context,
      ref,
      action: TeamProtectedAction.pool,
    );
    if (!hasTeam || !context.mounted) return;

    final joined = await ref.read(poolActionProvider.notifier).join(pool.id);
    if (!context.mounted) return;
    if (joined == null) {
      final error = ref.read(poolActionProvider).error;
      if (openTopUpIfInsufficientFunds(context, error)) return;
      AppNotice.error(context, error ?? 'The pool could not be joined.');
      return;
    }
    AppNotice.success(
      context,
      joined.isPending
          ? 'Your request to join ${joined.name} is awaiting approval.'
          : 'You joined ${joined.name}.',
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle, required this.count});

  final String title;
  final String subtitle;
  final int count;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 2),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          StatusPill('$count available'),
        ],
      );
}

class _AutoPoolsSyncing extends StatelessWidget {
  const _AutoPoolsSyncing();

  @override
  Widget build(BuildContext context) => const GradientPanel(
        child: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Expanded(child: Text('The standard auto pools are being prepared. Pull down to refresh.')),
          ],
        ),
      );
}

class _HeadToHeadCard extends StatelessWidget {
  const _HeadToHeadCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GradientPanel(
        onTap: onTap,
        colors: const [Color(0xFF0A4437), Color(0xFF261A47)],
        child: Row(
          children: [
            const CircleAvatar(radius: 26, backgroundColor: Color(0x243EFF75), child: Icon(Icons.compare_arrows_rounded, color: AppColors.lime)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Head-to-head pool', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  const Text('Challenge another verified FPL manager.', style: TextStyle(color: Color(0xFFC9DED7))),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_rounded, color: Colors.white),
          ],
        ),
      );
}

class _CreateCustomPoolCard extends StatelessWidget {
  const _CreateCustomPoolCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.add_circle_outline_rounded),
        label: const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Text('Create a custom pool'),
        ),
      );
}
