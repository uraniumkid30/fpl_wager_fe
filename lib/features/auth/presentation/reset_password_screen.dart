import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpl_wager/features/auth/presentation/auth_controller.dart';
import 'package:fpl_wager/features/auth/presentation/auth_scaffold.dart';
import 'package:fpl_wager/features/auth/presentation/sign_in_screen.dart';
import 'package:go_router/go_router.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key, this.email, this.token});
  final String? email;
  final String? token;

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  final _passwordVisible = ValueNotifier<bool>(false);
  final _confirmationVisible = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    _passwordVisible.dispose();
    _confirmationVisible.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final flow = ref.watch(authFlowControllerProvider);
    final hasCredentials = (widget.email?.isNotEmpty ?? false) && (widget.token?.isNotEmpty ?? false) ||
        (flow.email.isNotEmpty && (flow.verificationToken?.isNotEmpty ?? false));
    return AuthScaffold(
      title: 'Choose a new password',
      subtitle: hasCredentials
          ? 'Use a strong password you have not used for this account before.'
          : 'This reset link is incomplete or expired. Request a new one.',
      onBack: () => context.go('/sign-in'),
      child: hasCredentials
          ? Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ValueListenableBuilder<bool>(
                    valueListenable: _passwordVisible,
                    builder: (context, visible, _) => TextFormField(
                      controller: _password,
                      obscureText: !visible,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: InputDecoration(
                        labelText: 'New password',
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
                  const SizedBox(height: 14),
                  ValueListenableBuilder<bool>(
                    valueListenable: _confirmationVisible,
                    builder: (context, visible, _) => TextFormField(
                      controller: _confirmation,
                      obscureText: !visible,
                      decoration: InputDecoration(
                        labelText: 'Confirm password',
                        prefixIcon: const Icon(Icons.verified_outlined),
                        suffixIcon: IconButton(
                          tooltip: visible ? 'Hide password' : 'Show password',
                          onPressed: () => _confirmationVisible.value = !visible,
                          icon: Icon(visible ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                        ),
                      ),
                      validator: (value) => value != _password.text ? 'Passwords do not match' : null,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (flow.error != null) ...[
                    InlineAuthError(flow.error!),
                    const SizedBox(height: 12),
                  ],
                  FilledButton(
                    onPressed: flow.isLoading ? null : _submit,
                    child: flow.isLoading
                        ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Save new password'),
                  ),
                ],
              ),
            )
          : FilledButton(
              onPressed: () => context.go('/forgot-password'),
              child: const Text('Request a new reset link'),
            ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final ok = await ref.read(authFlowControllerProvider.notifier).completePasswordReset(
          email: widget.email,
          token: widget.token,
          newPassword: _password.text,
        );
    if (!ok || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated. Sign in to continue.')));
    context.go('/sign-in');
  }
}
