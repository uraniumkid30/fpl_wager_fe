import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpl_wager/app/theme/app_theme.dart';
import 'package:fpl_wager/core/config/app_config.dart';
import 'package:fpl_wager/core/ui/app_notice.dart';
import 'package:fpl_wager/core/ui/app_widgets.dart';
import 'package:fpl_wager/core/network/providers.dart';
import 'package:fpl_wager/features/dashboard/presentation/dashboard_controller.dart';
import 'package:fpl_wager/features/payments/presentation/checkout_screen.dart';
import 'package:fpl_wager/features/payments/presentation/payment_controller.dart';
import 'package:fpl_wager/features/wallet/presentation/wallet_controller.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';

class TopUpScreen extends ConsumerStatefulWidget {
  const TopUpScreen({super.key});

  @override
  ConsumerState<TopUpScreen> createState() => _TopUpScreenState();
}

class _TopUpScreenState extends ConsumerState<TopUpScreen> {
  static const _providerLabels = {'paystack': 'Paystack', 'korapay': 'Korapay'};

  /// True from the moment the checkout opens until its result is known, so
  /// the pay button cannot start a second payment in the meantime.
  bool _checkingOut = false;

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(topUpDraftProvider);
    final action = ref.watch(paymentActionProvider);
    final busy = action.isLoading || _checkingOut;
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
                      onPressed: busy ? null : () => _startCheckout(draft),
                      icon: busy
                          ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.lock_rounded),
                      label: Text('Continue to pay ${money(draft.amountCents)}'),
                    ),
                    const SizedBox(height: 10),
                    Text('Checkout opens securely inside the app. Your wallet is credited as soon as the payment is confirmed.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startCheckout(TopUpDraft draft) async {
    if (_checkingOut) return;
    setState(() => _checkingOut = true);
    try {
      await _checkout(draft);
    } finally {
      if (mounted) setState(() => _checkingOut = false);
    }
  }

  /// The whole payment, in three steps:
  ///
  ///  1. the server starts the transaction with the provider and returns the
  ///     address of the provider's checkout page,
  ///  2. the customer pays on that page,
  ///  3. the server confirms the payment with the provider and credits the
  ///     wallet.
  ///
  /// The app only carries the customer between the steps. It never holds a
  /// provider key and never tells the server that a payment succeeded.
  Future<void> _checkout(TopUpDraft draft) async {
    final payment = await ref.read(paymentActionProvider.notifier).initialize(draft);
    if (!mounted) return;
    if (payment == null) {
      AppNotice.error(
        context,
        ref.read(paymentActionProvider).error ??
            'Payment could not be initialized. Please try again.',
      );
      return;
    }
    final confirmation =
        '/payments/callback?reference=${Uri.encodeQueryComponent(payment.reference)}';
    if (AppConfig.useDemoData) {
      context.go(confirmation);
      return;
    }

    final checkout = Uri.tryParse(payment.checkoutUrl ?? '');
    if (checkout == null || !checkout.hasScheme) {
      AppNotice.error(context, 'Could not open the secure checkout page.');
      return;
    }

    if (kIsWeb) {
      // In a browser the provider takes over the tab and redirects back to
      // the confirmation route when the customer is done.
      final opened = await launchUrl(checkout, webOnlyWindowName: '_self');
      if (!opened && mounted) {
        AppNotice.error(context, 'Could not open the secure checkout page.');
      }
      return;
    }

    final outcome = await CheckoutScreen.open(
      context,
      checkoutUrl: checkout,
      callbackUrl: AppConfig.paymentCallbackUrl,
      providerLabel: _providerLabels[draft.provider] ?? 'Secure',
    );
    if (!mounted) return;

    if (outcome == CheckoutOutcome.completed) {
      // The confirmation screen asks the server to verify and settle.
      context.go(confirmation);
      return;
    }
    await _checkAfterLeaving(payment.reference, outcome);
  }

  /// The customer cancelled or closed the checkout. They may still have paid
  /// (closing the page a moment after the bank approved, for instance), so
  /// the server is asked once before saying anything.
  Future<void> _checkAfterLeaving(
    String reference,
    CheckoutOutcome outcome,
  ) async {
    try {
      final payment = await ref.read(appGatewayProvider).verifyPayment(reference);
      if (!mounted) return;
      if (payment.isSuccessful) {
        ref.invalidate(walletProvider);
        ref.invalidate(dashboardProvider);
        AppNotice.success(
          context,
          '${money(payment.amountCents)} was added to your wallet.',
        );
        context.go('/profile/wallet');
        return;
      }
    } on Object {
      // This check is only a courtesy. If it cannot be made, the message
      // below still holds: a completed payment is credited by the provider's
      // webhook without the app's help.
      if (!mounted) return;
    }
    AppNotice.info(
      context,
      outcome == CheckoutOutcome.cancelled
          ? 'Payment cancelled. Nothing was added to your wallet.'
          : 'Checkout closed. If you completed the payment, your wallet '
              'updates as soon as it is confirmed.',
    );
  }
}
