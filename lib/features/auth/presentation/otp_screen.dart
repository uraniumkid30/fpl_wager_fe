import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpl_wager/features/auth/presentation/auth_controller.dart';
import 'package:fpl_wager/features/auth/presentation/auth_scaffold.dart';
import 'package:fpl_wager/features/auth/presentation/sign_in_screen.dart';
import 'package:go_router/go_router.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key});
  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _otp = TextEditingController();

  @override
  void dispose() {
    _otp.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final flow = ref.watch(authFlowControllerProvider);
    final destination = switch (flow.kind) {
      AuthFlowKind.registration => '/sign-up',
      AuthFlowKind.passwordReset => '/forgot-password',
      _ => '/sign-in',
    };
    if (!flow.needsOtp) {
      return AuthScaffold(
        title: 'No active code',
        subtitle: 'Start sign in, registration, or password recovery again.',
        onBack: () => context.go('/welcome'),
        child: FilledButton(
          onPressed: () => context.go('/sign-in'),
          child: const Text('Return to sign in'),
        ),
      );
    }
    return AuthScaffold(
      title: 'Check your email',
      subtitle: flow.message.isEmpty
          ? 'Enter the six-digit code sent to ${flow.email}.'
          : flow.message,
      onBack: () {
        ref.read(authFlowControllerProvider.notifier).clear();
        context.go(destination);
      },
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _otp,
              autofocus: true,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              autofillHints: const [AutofillHints.oneTimeCode],
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(letterSpacing: 12, fontWeight: FontWeight.w900),
              decoration: const InputDecoration(labelText: 'Verification code', counterText: ''),
              validator: (value) => value?.length == 6 ? null : 'Enter the six-digit code',
              onFieldSubmitted: (_) => flow.isLoading ? null : _verify(),
            ),
            const SizedBox(height: 10),
            Text(
              'Sent to ${flow.email}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            if (flow.error != null) ...[
              InlineAuthError(flow.error!),
              const SizedBox(height: 12),
            ],
            FilledButton.icon(
              onPressed: flow.isLoading ? null : _verify,
              icon: flow.isLoading
                  ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.lock_open_rounded),
              label: const Text('Verify code'),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: flow.isLoading
                  ? null
                  : () {
                      ref.read(authFlowControllerProvider.notifier).clear();
                      context.go(destination);
                    },
              child: const Text('Start again'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _verify() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final kind = ref.read(authFlowControllerProvider).kind;
    final ok = await ref.read(authFlowControllerProvider.notifier).verifyOtp(_otp.text);
    if (!ok || !mounted) return;
    context.go(kind == AuthFlowKind.passwordReset ? '/reset-password' : '/dashboard');
  }
}
