import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpl_wager/app/theme/app_theme.dart';
import 'package:fpl_wager/core/ui/app_header.dart';
import 'package:fpl_wager/core/ui/app_widgets.dart';
import 'package:fpl_wager/core/ui/app_notice.dart';
import 'package:fpl_wager/features/fpl_team/presentation/team_requirement.dart';
import 'package:fpl_wager/features/pools/domain/pool.dart';
import 'package:fpl_wager/features/pools/presentation/pool_card.dart';
import 'package:fpl_wager/features/pools/presentation/pools_controller.dart';
import 'package:go_router/go_router.dart';

class PoolsScreen extends ConsumerWidget {
  const PoolsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pools = ref.watch(poolsProvider);
    final action = ref.watch(poolActionProvider);
    return Scaffold(
      appBar: AppHeader(
        title: 'Gameweek pools',
        actions: [
          IconButton.filledTonal(
            tooltip: 'Create pool',
            onPressed: () => _createPool(context, ref),
            icon: const Icon(Icons.add_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _createPool(context, ref), icon: const Icon(Icons.add_rounded), label: const Text('Create pool')),
      body: RefreshIndicator(
        onRefresh: () async { ref.invalidate(poolsProvider); await ref.read(poolsProvider.future); },
        child: AsyncContent(
          value: pools,
          onRetry: () => ref.invalidate(poolsProvider),
          data: (items) => items.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    _EmptyPools(
                      onCreate: () => _createPool(context, ref),
                    ),
                  ],
                )
              : ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(AppSpacing.md, 8, AppSpacing.md, 120),
                  children: [
                    Text('Fixed fees, clear rules, transparent prize splits.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Available pools',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        StatusPill('${items.length} pools'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...items.indexed.map(
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
                  ],
                ),
        ),
      ),
    );
  }

  Future<void> _createPool(BuildContext context, WidgetRef ref) async {
    final poolId = await openTeamProtectedRoute<String>(
      context,
      ref,
      action: TeamProtectedAction.pool,
      route: '/pools/create',
    );
    if (poolId != null && context.mounted) {
      context.push('/pools/$poolId');
    }
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
      AppNotice.error(
        context,
        ref.read(poolActionProvider).error ?? 'The pool could not be joined.',
      );
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

class _EmptyPools extends StatelessWidget {
  const _EmptyPools({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.xxl,
          AppSpacing.lg,
          120,
        ),
        child: Column(
          children: [
            const EmptyState(
              icon: Icons.emoji_events_outlined,
              title: 'No open pools yet',
              message: 'Create the first pool for this gameweek or pull down to refresh.',
            ),
            SizedBox(
              width: 260,
              child: FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Create a pool'),
              ),
            ),
          ],
        ),
      );
}
