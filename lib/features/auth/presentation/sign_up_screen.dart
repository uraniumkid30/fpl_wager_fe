import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpl_wager/features/auth/presentation/auth_controller.dart';
import 'package:fpl_wager/features/auth/presentation/auth_scaffold.dart';
import 'package:fpl_wager/features/auth/presentation/sign_in_screen.dart';
import 'package:go_router/go_router.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});
  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _passwordVisible = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _passwordVisible.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final flow = ref.watch(authFlowControllerProvider);
    return AuthScaffold(
      title: 'Create your account',
      subtitle: 'Your account is created only after your email code is verified.',
      onBack: () => context.go('/welcome'),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              autofillHints: const [AutofillHints.name],
              decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.person_outline_rounded)),
              validator: (value) => (value?.trim().length ?? 0) < 2 ? 'Enter your full name' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(labelText: 'Email address', prefixIcon: Icon(Icons.mail_outline_rounded)),
              validator: validateEmail,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              autofillHints: const [AutofillHints.telephoneNumber],
              decoration: const InputDecoration(labelText: 'Phone number (optional)', hintText: '+234…', prefixIcon: Icon(Icons.phone_outlined)),
            ),
            const SizedBox(height: 14),
            ValueListenableBuilder<bool>(
              valueListenable: _passwordVisible,
              builder: (context, visible, _) => TextFormField(
                controller: _password,
                obscureText: !visible,
                autofillHints: const [AutofillHints.newPassword],
                decoration: InputDecoration(
                  labelText: 'Password',
                  helperText: 'Use at least 10 characters',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    tooltip: visible ? 'Hide password' : 'Show password',
                    onPressed: () => _passwordVisible.value = !visible,
                    icon: Icon(visible ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                  ),
                ),
                validator: (value) => (value?.length ?? 0) < 10 ? 'Use at least 10 characters' : null,
              ),
            ),
            const SizedBox(height: 20),
            if (flow.error != null) ...[
              InlineAuthError(flow.error!),
              const SizedBox(height: 12),
            ],
            FilledButton.icon(
              onPressed: flow.isLoading ? null : _submit,
              icon: flow.isLoading
                  ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.verified_user_outlined),
              label: const Text('Create account'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: flow.isLoading ? null : () => context.go('/sign-in'),
              child: const Text('Already have an account? Sign in'),
            ),
            const SizedBox(height: 6),
            Text(
              'By continuing, you confirm you are 18+ and accept the game and wallet terms.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final ok = await ref.read(authFlowControllerProvider.notifier).startRegistration(
          fullName: _name.text.trim(),
          email: _email.text.trim(),
          phone: _phone.text.trim(),
          password: _password.text,
        );
    if (ok && mounted) context.go('/auth/verify');
  }
}
