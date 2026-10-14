import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fplboardman/app/theme/app_theme.dart';
import 'package:fplboardman/core/ui/app_widgets.dart';
import 'package:fplboardman/features/pools/domain/gameweek_history.dart';
import 'package:fplboardman/features/pools/domain/pool.dart';
import 'package:fplboardman/features/pools/presentation/pools_controller.dart';
import 'package:go_router/go_router.dart';

/// Every gameweek the user played, newest first: where their score placed
/// them among everyone on FPLboardman, the pools they entered and what they
/// staked and won. Each pool opens its standings.
class GameweekHistoryScreen extends ConsumerWidget {
  const GameweekHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(gameweekHistoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Gameweek history')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(gameweekHistoryProvider);
          await ref.read(gameweekHistoryProvider.future);
        },
        child: AsyncContent(
          value: history,
          onRetry: () => ref.invalidate(gameweekHistoryProvider),
          data: (items) {
            final won = items.fold<int>(0, (sum, g) => sum + g.wonCents);
            final staked = items.fold<int>(0, (sum, g) => sum + g.stakedCents);
            final best = items
                .where((g) => g.position != null)
                .fold<int?>(null, (b, g) => b == null || g.position! < b ? g.position : b);
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, 8, AppSpacing.md, 48),
              children: [
                if (items.isEmpty)
                  const EmptyState(
                    icon: Icons.leaderboard_outlined,
                    title: 'No gameweeks yet',
                    message: 'Enter a pool and your gameweek results will be kept here.',
                  )
                else ...[
                  Row(
                    children: [
                      Expanded(child: _Stat(label: 'GAMEWEEKS', value: '${items.length}')),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _Stat(
                          label: 'BEST FINISH',
                          value: best == null ? '—' : '$best${ordinalSuffix(best)}',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _Stat(label: 'STAKED', value: money(staked))),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _Stat(
                          label: 'WON',
                          value: money(won),
                          color: won > 0 ? AppColors.lime : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  ...items.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _GameweekCard(item: item),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.color});
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) => GradientPanel(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    letterSpacing: .7,
                  ),
            ),
            const SizedBox(height: 4),
            FitText(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
            ),
          ],
        ),
      );
}

class _GameweekCard extends StatelessWidget {
  const _GameweekCard({required this.item});
  final GameweekResult item;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final position = item.position;
    final net = item.netCents;
    return GradientPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Gameweek ${item.gameweek}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              StatusPill(
                item.isFinal ? 'Final' : 'In progress',
                color: item.isFinal ? null : Colors.orange,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                position == null ? '—' : '$position${ordinalSuffix(position)}',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: position == 1 ? AppColors.lime : null,
                    ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    position == null
                        ? 'No position yet. It shows once points are scored.'
                        : 'of ${item.managers} managers on FPLboardman'
                            '${item.points == null ? '' : ' · ${item.points} pts'}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _Money(label: 'Staked', cents: item.stakedCents)),
              Expanded(
                child: _Money(
                  label: 'Won',
                  cents: item.wonCents,
                  color: item.wonCents > 0 ? AppColors.lime : null,
                ),
              ),
              Expanded(
                child: _Money(
                  label: 'Net',
                  cents: net,
                  signed: true,
                  color: net > 0 ? AppColors.lime : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 6),
          ...item.pools.map((pool) => _PoolRow(pool: pool)),
        ],
      ),
    );
  }
}

class _Money extends StatelessWidget {
  const _Money({required this.label, required this.cents, this.color, this.signed = false});
  final String label;
  final int cents;
  final Color? color;
  final bool signed;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 2),
          FitText(
            signed
                ? '${cents >= 0 ? '+' : '−'}${money(cents.abs())}'
                : money(cents),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
          ),
        ],
      );
}

class _PoolRow extends StatelessWidget {
  const _PoolRow({required this.pool});
  final GameweekPoolResult pool;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final rank = pool.rank;
    final place = rank == null || rank == 0
        ? (pool.isLive ? 'In play' : 'Not started')
        : '$rank${ordinalSuffix(rank)} of ${pool.entrants}'
            '${pool.isLive ? ' (live)' : ''}';
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => context.push('/pools/${pool.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pool.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    '$place · stake ${money(pool.stakeCents)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted),
                  ),
                ],
              ),
            ),
            Text(
              pool.payoutCents > 0
                  ? '+${money(pool.payoutCents)}'
                  : pool.isSettled
                      ? '—'
                      : '',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: pool.payoutCents > 0 ? AppColors.lime : muted,
                  ),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: muted),
          ],
        ),
      ),
    );
  }
}
