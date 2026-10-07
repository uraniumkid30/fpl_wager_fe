import 'package:flutter/material.dart';
import 'package:fpl_wager/app/theme/app_theme.dart';
import 'package:fpl_wager/core/ui/app_widgets.dart';
import 'package:fpl_wager/features/pools/domain/pool.dart';
import 'package:go_router/go_router.dart';

class PoolCard extends StatelessWidget {
  const PoolCard({
    required this.pool,
    required this.onJoin,
    this.joining = false,
    super.key,
  });
  final Pool pool;
  final VoidCallback onJoin;
  final bool joining;

  @override
  Widget build(BuildContext context) {
    final membership = pool.awaitingAdminApproval
        ? 'Awaiting admin approval'
        : pool.isPending
            ? 'Pending approval'
            : pool.hasJoined
                ? 'Joined'
                : pool.status;
    return GradientPanel(
      onTap: () => context.push('/pools/${pool.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusPill(
                membership,
                color: pool.awaitingAdminApproval || pool.isPending
                    ? Colors.orange
                    : null,
              ),
              const Spacer(),
              if (pool.isPrivate) ...[
                Icon(Icons.lock_outline_rounded, size: 15, color: Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text('PRIVATE', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w900)),
                const SizedBox(width: 10),
              ],
              if (pool.isAuto) ...[
                const Icon(Icons.autorenew_rounded, size: 17, color: AppColors.lime),
                const SizedBox(width: 5),
                Text('AUTO', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.lime, fontWeight: FontWeight.w900)),
                const SizedBox(width: 10),
              ],
              Icon(Icons.groups_2_outlined, size: 17, color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(width: 5),
              Text('${pool.memberCount}', style: Theme.of(context).textTheme.labelLarge),
              if (pool.maxMembers != null) Text(' / ${pool.maxMembers}', style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
          const SizedBox(height: 18),
          Text(pool.name, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: _Value(label: 'STAKE', value: money(pool.stakeCents))),
              Expanded(child: _Value(label: 'PRIZE POOL', value: money(pool.prizePoolCents), color: AppColors.purple)),
              const Icon(Icons.arrow_forward_rounded),
            ],
          ),
          const SizedBox(height: 14),
          Row(children: [const Icon(Icons.timer_outlined, size: 16), const SizedBox(width: 6), DeadlineCountdown(pool.deadline, compact: true)]),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.balance_rounded, size: 16),
              const SizedBox(width: 6),
              Text(
                'Draw: ${pool.drawMethod.label}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: pool.canJoin && !joining ? onJoin : null,
              icon: joining && pool.canJoin
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(_actionIcon),
              label: Text(_actionLabel),
            ),
          ),
        ],
      ),
    );
  }

  String get _actionLabel {
    if (pool.hasJoined) return 'Joined';
    if (pool.awaitingAdminApproval) return 'Awaiting admin approval';
    if (pool.isPending) return 'Pending approval';
    if (!pool.canJoin) return 'Pool ${pool.status}';
    return 'Join pool · ${money(pool.stakeCents)}';
  }

  IconData get _actionIcon {
    if (pool.hasJoined) return Icons.check_circle_rounded;
    if (pool.isPending) return Icons.hourglass_top_rounded;
    if (!pool.canJoin) return Icons.lock_clock_rounded;
    return Icons.login_rounded;
  }
}

class _Value extends StatelessWidget {
  const _Value({required this.label, required this.value, this.color});
  final String label, value; final Color? color;
  @override Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant, letterSpacing: .7)), const SizedBox(height: 3), Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: color, fontWeight: FontWeight.w900))]);
}
