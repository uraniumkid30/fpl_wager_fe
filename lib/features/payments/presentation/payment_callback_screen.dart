import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpl_wager/app/theme/app_theme.dart';
import 'package:fpl_wager/core/ui/app_notice.dart';
import 'package:fpl_wager/core/ui/app_widgets.dart';
import 'package:fpl_wager/features/payments/presentation/payment_controller.dart';
import 'package:go_router/go_router.dart';

class PaymentCallbackScreen extends ConsumerStatefulWidget {
  const PaymentCallbackScreen({required this.reference, super.key});
  final String reference;

  @override
  ConsumerState<PaymentCallbackScreen> createState() =>
      _PaymentCallbackScreenState();
}

class _PaymentCallbackScreenState extends ConsumerState<PaymentCallbackScreen> {
  bool _returnScheduled = false;

  @override
  Widget build(BuildContext context) {
    final reference = widget.reference;
    final provider = paymentVerificationProvider(reference);
    final result = reference.isEmpty ? null : ref.watch(provider);

    if (reference.isNotEmpty) {
      ref.listen(provider, (_, next) {
        final payment = next.value;
        if (payment?.isSuccessful != true || _returnScheduled) return;
        _returnScheduled = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          AppNotice.success(
            context,
            '${money(payment!.amountCents)} was added to your wallet.',
          );
          context.go('/profile/wallet');
        });
      });
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: GradientPanel(
                child: result == null
                    ? _Result(icon: Icons.error_outline_rounded, title: 'Missing payment reference', message: 'Return to your wallet and try the top up again.', onDone: () => context.go('/profile/wallet'))
                    : result.when(
                        // Show the spinner again while "Check again" runs,
                        // instead of leaving the old answer on screen.
                        skipLoadingOnRefresh: false,
                        loading: () => const Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), SizedBox(height: 20), Text('Confirming your payment…', textAlign: TextAlign.center)]),
                        error: (error, _) => _Result(icon: Icons.sync_problem_rounded, title: 'Verification needs attention', message: error.toString(), onDone: () => ref.invalidate(paymentVerificationProvider(reference)), action: 'Try again'),
                        data: (payment) => switch (payment.status) {
                          'succeeded' => _Result(
                              icon: Icons.check_circle_rounded,
                              title: 'Wallet funded',
                              message: '${money(payment.amountCents)} has been added to your wallet.',
                              onDone: () => context.go('/profile/wallet'),
                            ),
                          'failed' => _Result(
                              icon: Icons.error_outline_rounded,
                              title: 'Payment failed',
                              message: 'The payment did not go through and nothing was added to your wallet. You can try again.',
                              onDone: () => context.go('/wallet/top-up'),
                              action: 'Try again',
                              onSecondary: () => context.go('/profile/wallet'),
                              secondaryAction: 'Back to wallet',
                            ),
                          'cancelled' => _Result(
                              icon: Icons.cancel_outlined,
                              title: 'Payment cancelled',
                              message: 'Nothing was added to your wallet.',
                              onDone: () => context.go('/profile/wallet'),
                            ),
                          // Still pending after waiting: a bank transfer that
                          // has not landed yet, or a payment never finished.
                          _ => _Result(
                              icon: Icons.schedule_rounded,
                              title: 'Waiting for confirmation',
                              message: 'Your payment has not been confirmed yet. If you paid, your wallet updates automatically as soon as it is — you do not need to stay on this screen.',
                              onDone: () => ref.invalidate(paymentVerificationProvider(reference)),
                              action: 'Check again',
                              onSecondary: () => context.go('/profile/wallet'),
                              secondaryAction: 'Back to wallet',
                            ),
                        },
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({
    required this.icon,
    required this.title,
    required this.message,
    required this.onDone,
    this.action = 'Back to wallet',
    this.onSecondary,
    this.secondaryAction,
  });
  final IconData icon;
  final String title;
  final String message;
  final VoidCallback onDone;
  final String action;
  final VoidCallback? onSecondary;
  final String? secondaryAction;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 58, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 18),
          Text(title, style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          FilledButton(onPressed: onDone, child: Text(action)),
          if (onSecondary != null && secondaryAction != null) ...[
            const SizedBox(height: 8),
            TextButton(onPressed: onSecondary, child: Text(secondaryAction!)),
          ],
        ],
      );
}
