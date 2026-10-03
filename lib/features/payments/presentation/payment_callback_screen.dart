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
                        loading: () => const Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), SizedBox(height: 20), Text('Verifying payment…')]),
                        error: (error, _) => _Result(icon: Icons.sync_problem_rounded, title: 'Verification needs attention', message: error.toString(), onDone: () => ref.invalidate(paymentVerificationProvider(reference)), action: 'Try again'),
                        data: (payment) => _Result(
                          icon: payment.isSuccessful ? Icons.check_circle_rounded : Icons.schedule_rounded,
                          title: payment.isSuccessful ? 'Wallet funded' : 'Payment ${payment.status}',
                          message: payment.isSuccessful ? '${money(payment.amountCents)} has been added to your wallet.' : 'We have not received a successful payment confirmation yet.',
                          onDone: () => context.go('/profile/wallet'),
                        ),
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
  const _Result({required this.icon, required this.title, required this.message, required this.onDone, this.action = 'Back to wallet'});
  final IconData icon;
  final String title;
  final String message;
  final VoidCallback onDone;
  final String action;

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
        ],
      );
}
