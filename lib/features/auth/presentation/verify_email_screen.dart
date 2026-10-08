import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fplboardman/app/theme/app_theme.dart';
import 'package:fplboardman/core/network/providers.dart';
import 'package:fplboardman/core/ui/app_notice.dart';
import 'package:fplboardman/core/ui/app_widgets.dart';
import 'package:fplboardman/features/auth/presentation/auth_controller.dart';
import 'package:fplboardman/features/dashboard/presentation/dashboard_controller.dart';
import 'package:go_router/go_router.dart';

/// "Verify email", opened from the dashboard and from Profile.
///
/// Two steps on one page: enter the address and get a six-digit code sent to
/// it, then enter the code. Nothing changes on the account until the code is
/// accepted, so a mistyped address can simply be corrected and sent again.
class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  final _emailForm = GlobalKey<FormState>();
  final _codeForm = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _code = TextEditingController();

  /// The address the current code was sent to; null until one is sent.
  String? _sentTo;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Start from the address already on the account, if it is a real one.
    final user = ref.read(dashboardProvider).value?.user ??
        ref.read(authControllerProvider).value?.user;
    _email.text = user?.displayEmail ?? '';
  }

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sentTo = _sentTo;
    return Scaffold(
      appBar: AppBar(title: const Text('Verify email')),
      body: SafeArea(
        child: Center(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GradientPanel(
                      colors: const [Color(0xFF0B4939), Color(0xFF2A174C)],
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.mark_email_read_outlined,
                            color: AppColors.lime,
                            size: 34,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Confirm your email',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'We use it for receipts, pool approvals and '
                            'anything important about your money.',
                            style: TextStyle(
                              color: Color(0xFFD1E3DC),
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Form(
                      key: _emailForm,
                      child: TextFormField(
                        controller: _email,
                        enabled: !_busy,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(
                          labelText: 'Email address',
                          prefixIcon: Icon(Icons.mail_outline_rounded),
                        ),
                        validator: _validateEmail,
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (sentTo == null)
                      FilledButton.icon(
                        onPressed: _busy ? null : _sendCode,
                        icon: _busy
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.send_rounded),
                        label: const Text('Send code'),
                      )
                    else ...[
                      Text(
                        'Enter the six-digit code we sent to $sentTo.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Form(
                        key: _codeForm,
                        child: TextFormField(
                          controller: _code,
                          enabled: !_busy,
                          autofocus: true,
                          keyboardType: TextInputType.number,
                          autofillHints: const [AutofillHints.oneTimeCode],
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Verification code',
                            prefixIcon: Icon(Icons.pin_outlined),
                          ),
                          validator: (value) =>
                              (value ?? '').trim().length == 6
                                  ? null
                                  : 'Enter the six-digit code',
                          onFieldSubmitted: (_) => _verify(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: _busy ? null : _verify,
                        icon: _busy
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.verified_outlined),
                        label: const Text('Verify email'),
                      ),
                      const SizedBox(height: 6),
                      TextButton(
                        onPressed: _busy ? null : _sendCode,
                        child: const Text('Send a new code'),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _validateEmail(String? value) {
    final email = (value ?? '').trim();
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)
        ? null
        : 'Enter a valid email address';
  }

  Future<void> _sendCode() async {
    if (!(_emailForm.currentState?.validate() ?? false)) return;
    final email = _email.text.trim().toLowerCase();
    setState(() => _busy = true);
    try {
      final challenge =
          await ref.read(appGatewayProvider).requestEmailVerification(email);
      if (!mounted) return;
      setState(() {
        _sentTo = email;
        _code.clear();
      });
      AppNotice.info(context, challenge.message);
    } on Object catch (error) {
      if (mounted) AppNotice.error(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    final sentTo = _sentTo;
    if (sentTo == null) return;
    if (!(_codeForm.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      await ref.read(appGatewayProvider).verifyEmail(sentTo, _code.text.trim());
      // The dashboard and profile read the user from here; refresh them so
      // the "Verify email" link goes away.
      ref.invalidate(dashboardProvider);
      if (!mounted) return;
      AppNotice.success(context, '$sentTo is now verified.');
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/home');
      }
    } on Object catch (error) {
      if (mounted) AppNotice.error(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
