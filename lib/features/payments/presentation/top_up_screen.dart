import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpl_wager/app/theme/app_theme.dart';
import 'package:fpl_wager/core/config/app_config.dart';
import 'package:fpl_wager/core/ui/app_widgets.dart';
import 'package:fpl_wager/features/payments/presentation/payment_controller.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';

class TopUpScreen extends ConsumerWidget {
  const TopUpScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(topUpDraftProvider);
    final action = ref.watch(paymentActionProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Top up wallet')),
      body: SafeArea(
        child: Center(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            shrinkWrap: true,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GradientPanel(
                      colors: const [Color(0xFF0B4939), Color(0xFF2A174C)],
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.shield_outlined, color: AppColors.lime, size: 34),
                          const SizedBox(height: 16),
                          Text('Secure wallet funding', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 8),
                          const Text('Payment credentials and test/live mode are selected securely by the server.', style: TextStyle(color: Color(0xFFD1E3DC), height: 1.5)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text('Choose amount', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [100000, 200000, 500000, 1000000].map((amount) => ChoiceChip(
                        label: Text(money(amount)),
                        selected: draft.amountCents == amount,
                        onSelected: (_) => ref.read(topUpDraftProvider.notifier).selectAmount(amount),
                      )).toList(),
                    ),
                    const SizedBox(height: 24),
                    Text('Payment provider', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 10),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'paystack', label: Text('Paystack'), icon: Icon(Icons.credit_card_rounded)),
                        ButtonSegment(value: 'korapay', label: Text('Korapay'), icon: Icon(Icons.account_balance_rounded)),
                      ],
                      selected: {draft.provider},
                      onSelectionChanged: (value) => ref.read(topUpDraftProvider.notifier).selectProvider(value.first),
                    ),
                    const SizedBox(height: 28),
                    if (action.hasError) ...[
                      Text(action.error.toString(), style: TextStyle(color: Theme.of(context).colorScheme.error)),
                      const SizedBox(height: 12),
                    ],
                    FilledButton.icon(
                      onPressed: action.isLoading ? null : () => _startCheckout(context, ref, draft),
                      icon: action.isLoading
                          ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.open_in_new_rounded),
                      label: Text('Continue to pay ${money(draft.amountCents)}'),
                    ),
                    const SizedBox(height: 10),
                    Text('You will return here after checkout so the server can verify and settle the payment.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startCheckout(BuildContext context, WidgetRef ref, TopUpDraft draft) async {
    final payment = await ref.read(paymentActionProvider.notifier).initialize(draft);
    if (payment == null || !context.mounted) return;
    if (AppConfig.useDemoData) {
      context.go('/payments/callback?reference=${payment.reference}');
      return;
    }
    final checkout = Uri.tryParse(payment.checkoutUrl ?? '');
    if (checkout == null || !await launchUrl(checkout, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open the secure checkout page.')));
      }
    }
  }
}
