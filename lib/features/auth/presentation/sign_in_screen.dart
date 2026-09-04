import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpl_wager/features/auth/presentation/auth_controller.dart';
import 'package:fpl_wager/features/auth/presentation/auth_scaffold.dart';
import 'package:go_router/go_router.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});
  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final flow = ref.watch(authFlowControllerProvider);
    return AuthScaffold(
      title: 'Welcome back',
      subtitle: 'Enter your password, then confirm the secure code we email you.',
      onBack: () => context.go('/welcome'),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(labelText: 'Email address', prefixIcon: Icon(Icons.mail_outline_rounded)),
              validator: validateEmail,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _password,
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline_rounded)),
              validator: (value) => value == null || value.isEmpty ? 'Enter your password' : null,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: flow.isLoading ? null : () => context.go('/forgot-password'),
                child: const Text('Forgot password?'),
              ),
            ),
            if (flow.error != null) ...[
              InlineAuthError(flow.error!),
              const SizedBox(height: 12),
            ],
            FilledButton.icon(
              onPressed: flow.isLoading ? null : _submit,
              icon: flow.isLoading
                  ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.arrow_forward_rounded),
              label: const Text('Continue securely'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: flow.isLoading ? null : () => context.go('/sign-up'),
              child: const Text('New here? Create an account'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final ok = await ref.read(authFlowControllerProvider.notifier).startLogin(
          _email.text.trim(),
          _password.text,
        );
    if (ok && mounted) context.go('/auth/verify');
  }
}

String? validateEmail(String? value) {
  final email = value?.trim() ?? '';
  return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)
      ? null
      : 'Enter a valid email address';
}

class InlineAuthError extends StatelessWidget {
  const InlineAuthError(this.error, {super.key});
  final Object error;

  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        child: Text(error.toString(), style: TextStyle(color: Theme.of(context).colorScheme.error)),
      );
}
