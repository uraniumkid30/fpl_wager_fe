import 'package:flutter/material.dart';
import 'package:fpl_wager/app/theme/app_theme.dart';
import 'package:fpl_wager/core/ui/app_widgets.dart';
import 'package:fpl_wager/features/pools/domain/pool.dart';
import 'package:go_router/go_router.dart';

class PoolCard extends StatelessWidget {
  const PoolCard({required this.pool, super.key});
  final Pool pool;

  @override
  Widget build(BuildContext context) {
    final membership = pool.isPending ? 'Pending approval' : pool.hasJoined ? 'Joined' : pool.status;
    return GradientPanel(
      onTap: () => context.push('/pools/${pool.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusPill(membership, color: pool.isPending ? Colors.orange : null),
              const Spacer(),
              Icon(Icons.groups_2_outlined, size: 17, color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(width: 5),
              Text('${pool.memberCount}', style: Theme.of(context).textTheme.labelLarge),
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
        ],
      ),
    );
  }
}

class _Value extends StatelessWidget {
  const _Value({required this.label, required this.value, this.color});
  final String label, value; final Color? color;
  @override Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant, letterSpacing: .7)), const SizedBox(height: 3), Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: color, fontWeight: FontWeight.w900))]);
}

