import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpl_wager/app/theme/app_theme.dart';
import 'package:fpl_wager/core/config/app_config.dart';
import 'package:fpl_wager/core/ui/app_notice.dart';
import 'package:fpl_wager/core/ui/app_header.dart';
import 'package:fpl_wager/core/ui/app_widgets.dart';
import 'package:fpl_wager/features/wallet/domain/wallet_models.dart';
import 'package:fpl_wager/features/wallet/presentation/wallet_controller.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(walletProvider);

    return Scaffold(
      appBar: const AppHeader(title: 'Wallet'),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(walletProvider);
          await ref.read(walletProvider.future);
        },
        child: AsyncContent(
          value: wallet,
          onRetry: () => ref.invalidate(walletProvider),
          data: (value) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              8,
              AppSpacing.md,
              120,
            ),
            children: [
              GradientPanel(
                colors: const [Color(0xFF0B4939), Color(0xFF2A174C)],
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'AVAILABLE BALANCE',
                      style: TextStyle(
                        color: Color(0xFFC9DED7),
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        letterSpacing: 0.7,
                      ),
                    ),
                    const SizedBox(height: 8),
                    FitText(
                      money(value.availableCents),
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: AppColors.purple,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${money(value.lockedCents)} locked in active games',
                      style: const TextStyle(color: Color(0xFFD1E3DC)),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            onPressed: () async {
                              await context.push('/wallet/top-up');
                              ref.invalidate(walletProvider);
                            },
                            child: const Text('Top up'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            // Opens Withdraw, which asks for a verified
                            // email and a bank account first if either is
                            // missing.
                            onPressed: () => context.push('/withdraw'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Withdraw'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              if (AppConfig.enableDevCredit) ...[
                OutlinedButton.icon(
                  onPressed: () => unawaited(_showTopUp(context, ref)),
                  icon: const Icon(Icons.science_outlined),
                  label: const Text('Add development credit'),
                ),
                const SizedBox(height: 18),
              ],
              Text(
                'Transaction ledger',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              if (value.ledger.isEmpty)
                const EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'No transactions',
                  message: 'Wallet activity appears here.',
                )
              else
                GradientPanel(
                  child: Column(
                    children: value.ledger
                        .map((entry) => _LedgerRow(entry: entry))
                        .toList(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showTopUp(BuildContext context, WidgetRef ref) async {
    final amount = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Choose an amount',
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(
                'Development credits only. Replace with signed payment webhooks.',
                style: TextStyle(
                  color: Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              ...[100000, 200000, 500000, 1000000].map(
                (amount) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(sheetContext).pop(amount),
                    child: Text(money(amount)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // The sheet is dismissed now; use the screen context for feedback.
    if (amount == null || !context.mounted) return;

    final ok = await ref.read(walletActionProvider.notifier).credit(amount);
    if (!context.mounted) return;

    if (ok) {
      AppNotice.success(context, 'Wallet credited successfully.');
    } else {
      AppNotice.error(
        context,
        ref.read(walletActionProvider).error ?? 'Top up failed.',
      );
    }
  }
}

class _LedgerRow extends StatelessWidget {
  const _LedgerRow({required this.entry});

  final LedgerEntry entry;

  @override
  Widget build(BuildContext context) {
    final credit = entry.amountCents > 0;
    final color = credit ? AppColors.emerald : AppColors.purple;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.13),
            child: Icon(
              credit ? Icons.south_west_rounded : Icons.north_east_rounded,
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.description,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                // A withdrawal names the account it was sent to.
                if (entry.bank != null)
                  Text(
                    entry.bank!.accountName,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                Text(
                  DateFormat('d MMM · HH:mm').format(entry.createdAt.toLocal()),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${credit ? '+' : ''}${money(entry.amountCents)}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: credit ? AppColors.emerald : null,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
