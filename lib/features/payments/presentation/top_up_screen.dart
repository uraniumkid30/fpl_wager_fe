import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpl_wager/app/theme/app_theme.dart';
import 'package:fpl_wager/core/config/app_config.dart';
import 'package:fpl_wager/core/ui/app_notice.dart';
import 'package:fpl_wager/core/ui/app_widgets.dart';
import 'package:fpl_wager/features/payments/presentation/payment_controller.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';

class TopUpScreen extends ConsumerStatefulWidget {
  const TopUpScreen({super.key});

  @override
  ConsumerState<TopUpScreen> createState() => _TopUpScreenState();
}

class _TopUpScreenState extends ConsumerState<TopUpScreen>
    with WidgetsBindingObserver {
  String? _pendingReference;
  bool _verifyingPendingPayment = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_verifyPendingPayment());
    }
  }

  @override
  Widget build(BuildContext context) {
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
                      onPressed: action.isLoading ? null : () => _startCheckout(draft),
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

  Future<void> _startCheckout(TopUpDraft draft) async {
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
    if (AppConfig.useDemoData) {
      context.go('/payments/callback?reference=${payment.reference}');
      return;
    }
    _pendingReference = payment.reference;
    final checkout = Uri.tryParse(payment.checkoutUrl ?? '');
    final opened = checkout != null &&
        await (kIsWeb
            ? launchUrl(checkout, webOnlyWindowName: '_self')
            : launchUrl(checkout, mode: LaunchMode.externalApplication));
    if (!opened && mounted) {
      _pendingReference = null;
      AppNotice.error(context, 'Could not open the secure checkout page.');
    }
  }

  Future<void> _verifyPendingPayment() async {
    final reference = _pendingReference;
    if (reference == null || _verifyingPendingPayment) return;
    _verifyingPendingPayment = true;
    try {
      await Future<void>.delayed(const Duration(milliseconds: 700));
      final payment = await ref.read(
        paymentVerificationProvider(reference).future,
      );
      if (!mounted) return;
      if (payment.isSuccessful) {
        _pendingReference = null;
        AppNotice.success(
          context,
          '${money(payment.amountCents)} was added to your wallet.',
        );
        context.go('/profile/wallet');
      } else {
        AppNotice.info(
          context,
          'Payment is still being confirmed. Return here to check again.',
        );
      }
    } on Object catch (error) {
      if (mounted) AppNotice.error(context, error);
    } finally {
      _verifyingPendingPayment = false;
    }
  }
}
