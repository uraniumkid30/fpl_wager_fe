import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpl_wager/app/theme/app_theme.dart';
import 'package:fpl_wager/core/ui/app_header.dart';
import 'package:fpl_wager/core/ui/app_widgets.dart';
import 'package:fpl_wager/features/pools/presentation/pool_card.dart';
import 'package:fpl_wager/features/pools/presentation/pools_controller.dart';
import 'package:go_router/go_router.dart';

class PoolsScreen extends ConsumerWidget {
  const PoolsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pools = ref.watch(poolsProvider);
    return Scaffold(
      appBar: const AppHeader(title: 'Gameweek pools'),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => context.push('/pools/create'), icon: const Icon(Icons.add_rounded), label: const Text('Create pool')),
      body: RefreshIndicator(
        onRefresh: () async { ref.invalidate(poolsProvider); await ref.read(poolsProvider.future); },
        child: AsyncContent(
          value: pools,
          onRetry: () => ref.invalidate(poolsProvider),
          data: (items) => items.isEmpty
              ? ListView(children: const [EmptyState(icon: Icons.emoji_events_outlined, title: 'No open pools yet', message: 'Create the first pool for this gameweek.')])
              : ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(AppSpacing.md, 8, AppSpacing.md, 120),
                  children: [
                    Text('Fixed fees, clear rules, transparent prize splits.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 20),
                    ...items.indexed.map((entry) => Padding(padding: const EdgeInsets.only(bottom: 14), child: FadeSlideIn(delay: Duration(milliseconds: entry.$1 * 55), child: PoolCard(pool: entry.$2)))),
                  ],
                ),
        ),
      ),
    );
  }
}
