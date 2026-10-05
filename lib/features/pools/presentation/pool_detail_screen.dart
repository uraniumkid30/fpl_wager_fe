import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpl_wager/app/theme/app_theme.dart';
import 'package:fpl_wager/core/ui/app_notice.dart';
import 'package:fpl_wager/core/ui/app_widgets.dart';
import 'package:fpl_wager/features/pools/domain/pool.dart';
import 'package:fpl_wager/features/pools/presentation/pools_controller.dart';
import 'package:fpl_wager/features/wallet/presentation/insufficient_funds.dart';

class PoolDetailScreen extends ConsumerWidget {
  const PoolDetailScreen({required this.poolId, super.key});

  final String poolId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pool = ref.watch(poolProvider(poolId));
    final action = ref.watch(poolActionProvider);
    ref.listen(poolActionProvider, (_, next) {
      if (next.hasError) {
        if (openTopUpIfInsufficientFunds(context, next.error)) return;
        AppNotice.error(context, next.error!);
      }
    });
    return Scaffold(
      appBar: AppBar(title: const Text('Pool details')),
      body: AsyncContent(
        value: pool,
        onRetry: () => ref.invalidate(poolProvider(poolId)),
        data: (item) => _Body(
          item: item,
          busy: action.isLoading,
          onJoin: () async {
            await ref.read(poolActionProvider.notifier).join(poolId);
            ref.invalidate(poolProvider(poolId));
          },
          onLeave: () async {
            await ref.read(poolActionProvider.notifier).leave(poolId);
            ref.invalidate(poolProvider(poolId));
          },
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.item,
    required this.busy,
    required this.onJoin,
    required this.onLeave,
  });

  final Pool item;
  final bool busy;
  final VoidCallback onJoin;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, 8, AppSpacing.md, 48),
        children: [
          GradientPanel(
            colors: const [Color(0xFF0B4939), Color(0xFF2C174A)],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    StatusPill(item.status),
                    const Spacer(),
                    Text(
                      'GW${item.gameweek}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  item.name,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _HeroValue(
                        label: 'YOUR STAKE',
                        value: money(item.stakeCents),
                        color: AppColors.lime,
                      ),
                    ),
                    Expanded(
                      child: _HeroValue(
                        label: 'PRIZE POOL',
                        value: money(item.prizePoolCents),
                        color: const Color(0xFFE859FF),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'FPL deadline',
                  style: TextStyle(color: Color(0xFFC9DED7)),
                ),
                const SizedBox(height: 4),
                DeadlineCountdown(item.deadline),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (item.canJoin)
            FilledButton(
              onPressed: busy ? null : onJoin,
              child: Text(
                item.approvalRequired
                    ? 'Request to join · ${money(item.stakeCents)}'
                    : 'Join · ${money(item.stakeCents)}',
              ),
            )
          else if (item.isPending)
            const FilledButton(
              onPressed: null,
              child: Text('Pending manager approval'),
            )
          else if (item.hasJoined)
            OutlinedButton(
              onPressed: busy ? null : onLeave,
              child: const Text('Leave and refund'),
            ),
          const SizedBox(height: 24),
          Text('Draw settlement', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          GradientPanel(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.13),
                  child: Icon(
                    item.drawMethod == PoolDrawMethod.split
                        ? Icons.call_split_rounded
                        : item.drawMethod == PoolDrawMethod.captains
                            ? Icons.workspace_premium_outlined
                            : Icons.numbers_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.isAuto
                            ? '${item.drawMethod.label} (auto-pool default)'
                            : item.drawMethod.label,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(item.drawMethod.description),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (item.rules.isNotEmpty) ...[
            const SizedBox(height: 22),
            Text('Pool rules', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            GradientPanel(child: Text(item.rules)),
          ],
          const SizedBox(height: 28),
          Text('Leaderboard', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          GradientPanel(
            child: item.leaderboard.isEmpty
                ? const Text('Scores appear when the gameweek begins.')
                : Column(
                    children: item.leaderboard
                        .map((member) => _Leader(member: member))
                        .toList(),
                  ),
          ),
          const SizedBox(height: 22),
          Text('Prize split', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          if (item.payout != null && item.payout!.entrants > 0) ...[
            _PayoutSummary(plan: item.payout!),
            const SizedBox(height: 12),
          ],
          GradientPanel(
            child: item.prizeSplit.isEmpty
                ? const Text(
                    'Prizes appear once the first manager joins. One manager '
                    'wins for every ten who enter.',
                  )
                : Column(
                    children: item.prizeSplit
                        .map(
                          (prize) => ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(child: Text('${prize.place}')),
                            title: Text(_placeLabel(prize.place)),
                            subtitle: Text(
                              '${prize.percentLabel}% of the prize pool',
                            ),
                            trailing: Text(
                              money(prize.amountCents),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
          const SizedBox(height: 20),
          Text(
            'Prizes are worked out from the entries so far and grow as more '
            'managers join. Official FPL points decide the places.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      );
}

String _placeLabel(int place) {
  // 11th, 12th and 13th are the exceptions to 1st, 2nd, 3rd.
  final lastTwo = place % 100;
  final last = place % 10;
  final suffix = lastTwo >= 11 && lastTwo <= 13
      ? 'th'
      : last == 1
          ? 'st'
          : last == 2
              ? 'nd'
              : last == 3
                  ? 'rd'
                  : 'th';
  return '$place$suffix place';
}

/// How the pot becomes the prize pool: total staked, the platform fee, what
/// is left for the winners and how many of them there are.
class _PayoutSummary extends StatelessWidget {
  const _PayoutSummary({required this.plan});

  final PayoutPlan plan;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return GradientPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PayoutRow(
            label: '${plan.entrants} ${plan.entrants == 1 ? 'manager' : 'managers'} × ${money(plan.stakeCents)}',
            value: money(plan.totalStakedCents),
          ),
          _PayoutRow(
            label: 'Platform fee (${plan.houseCutPercentLabel}%)',
            value: '−${money(plan.houseCutCents)}',
          ),
          const Divider(height: 22),
          _PayoutRow(
            label: 'Prize pool',
            value: money(plan.totalWinningCents),
            strong: true,
          ),
          const SizedBox(height: 12),
          Text(
            '${plan.winners} ${plan.winners == 1 ? 'winner' : 'winners'}. '
            'One manager wins for every ten who enter, up to fifty. Each '
            'place wins a little less than the place above, and the last '
            'winner always gets at least 130% of the stake.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: muted,
                  height: 1.4,
                ),
          ),
        ],
      ),
    );
  }
}

class _PayoutRow extends StatelessWidget {
  const _PayoutRow({
    required this.label,
    required this.value,
    this.strong = false,
  });

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final style = strong
        ? Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            )
        : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          const SizedBox(width: 12),
          Text(value, style: style),
        ],
      ),
    );
  }
}

class _HeroValue extends StatelessWidget {
  const _HeroValue({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFC9DED7),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w900,
                ),
          ),
        ],
      );
}

class _Leader extends StatelessWidget {
  const _Leader({required this.member});

  final PoolMember member;

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          backgroundColor:
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
          child: Text(member.rank == 0 ? '–' : '${member.rank}'),
        ),
        title: Text(member.displayName),
        // Shown once the pool is settled, for the entries that were paid.
        subtitle: member.payoutCents > 0
            ? Text(
                'Won ${money(member.payoutCents)}',
                style: const TextStyle(
                  color: AppColors.emerald,
                  fontWeight: FontWeight.w700,
                ),
              )
            : null,
        trailing: Text(
          '${member.points}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      );
}
