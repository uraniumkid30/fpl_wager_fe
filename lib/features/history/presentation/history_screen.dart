import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpl_wager/app/theme/app_theme.dart';
import 'package:fpl_wager/core/ui/app_header.dart';
import 'package:fpl_wager/core/ui/app_widgets.dart';
import 'package:fpl_wager/features/wallet/presentation/wallet_controller.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(walletProvider);
    return Scaffold(
      appBar: const AppHeader(title: 'History'),
      body: AsyncContent(
        value: wallet,
        onRetry: () => ref.invalidate(walletProvider),
        data: (value) => value.ledger.isEmpty
            ? const EmptyState(
                icon: Icons.history_rounded,
                title: 'Nothing settled yet',
                message: 'Your results and wallet activity will appear after each gameweek.',
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, 8, AppSpacing.md, 120),
                children: [
                  Text(
                    'A complete record of stakes, refunds and winnings.',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 18),
                  ...value.ledger.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: GradientPanel(
                        padding: const EdgeInsets.all(16),
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            entry.amountCents > 0
                                ? Icons.add_circle_outline
                                : Icons.remove_circle_outline,
                            color: entry.amountCents > 0
                                ? AppColors.emerald
                                : AppColors.purple,
                          ),
                          title: Text(entry.description),
                          subtitle: Text(entry.kind.replaceAll('_', ' ')),
                          trailing: Text(
                            money(entry.amountCents),
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
