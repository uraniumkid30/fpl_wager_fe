import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fplboardman/app/theme/app_theme.dart';
import 'package:fplboardman/core/errors/app_exception.dart';
import 'package:fplboardman/core/network/providers.dart';
import 'package:fplboardman/core/ui/app_notice.dart';
import 'package:fplboardman/core/ui/app_widgets.dart';
import 'package:fplboardman/features/auth/presentation/auth_controller.dart';
import 'package:go_router/go_router.dart';

/// "Sign in with email", opened from the welcome page.
///
/// For someone who already has an account — every account is created by
/// signing in with FPL — and has verified their email. They enter the
/// address, a six-digit code is emailed to it, and the code signs them in.
/// There is no password.
///
/// If the address has no account, or the account's email was never verified,
/// the server says so and this screen sends the person to "Sign in with FPL".
class EmailSignInScreen extends ConsumerStatefulWidget {
  const EmailSignInScreen({super.key});

  @override
  ConsumerState<EmailSignInScreen> createState() => _EmailSignInScreenState();
}

class _EmailSignInScreenState extends ConsumerState<EmailSignInScreen> {
  final _emailForm = GlobalKey<FormState>();
  final _codeForm = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _code = TextEditingController();

  /// The address the current code was sent to; null until one is sent.
  String? _sentTo;

  /// Set when the server says this address cannot sign in by email. It is
  /// shown on the page, next to the way that does work.
  String? _unavailable;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sentTo = _sentTo;
    final unavailable = _unavailable;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/welcome'),
        ),
        title: const Text('Sign in with email'),
      ),
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
                            Icons.mail_lock_outlined,
                            color: AppColors.lime,
                            size: 34,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Welcome back',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Enter the email you verified on your FPLboardman '
                            'account and we will send you a six-digit code. '
                            'No password needed.',
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
                        autofocus: true,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(
                          labelText: 'Email address',
                          prefixIcon: Icon(Icons.mail_outline_rounded),
                        ),
                        validator: _validateEmail,
                        onChanged: (_) {
                          // A different address deserves a fresh attempt.
                          if (_unavailable != null || _sentTo != null) {
                            setState(() {
                              _unavailable = null;
                              _sentTo = null;
                              _code.clear();
                            });
                          }
                        },
                        onFieldSubmitted: (_) {
                          if (_sentTo == null) _sendCode();
                        },
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (unavailable != null) ...[
                      GradientPanel(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.info_outline_rounded, color: scheme.error),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    unavailable,
                                    style: const TextStyle(height: 1.45),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            // FPL sign-in needs the mobile app; in a
                            // browser the welcome page explains that.
                            FilledButton.icon(
                              onPressed: () =>
                                  context.go(kIsWeb ? '/welcome' : '/fpl-login'),
                              icon: const Icon(Icons.sports_soccer_rounded),
                              label: const Text('Sign in with FPL instead'),
                            ),
                          ],
                        ),
                      ),
                    ] else if (sentTo == null)
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
                        style: TextStyle(color: scheme.onSurfaceVariant),
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
                            labelText: 'Sign-in code',
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
                            : const Icon(Icons.login_rounded),
                        label: const Text('Sign in'),
                      ),
                      const SizedBox(height: 6),
                      TextButton(
                        onPressed: _busy ? null : _sendCode,
                        child: const Text('Send a new code'),
                      ),
                    ],
                    const SizedBox(height: 18),
                    Text(
                      'New to FPLboardman? Go back and use Sign in with FPL. '
                      'That creates your account; verify your email '
                      'afterwards and you can sign in this way next time.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            height: 1.45,
                          ),
                    ),
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
    setState(() {
      _busy = true;
      _unavailable = null;
    });
    try {
      final challenge =
          await ref.read(appGatewayProvider).requestEmailSignIn(email);
      if (!mounted) return;
      setState(() {
        _sentTo = email;
        _code.clear();
      });
      AppNotice.info(context, challenge.message);
    } on AppException catch (error) {
      if (!mounted) return;
      if (error.code == 'EMAIL_SIGN_IN_UNAVAILABLE') {
        // No account, or the email is not verified: say so in a notice and
        // leave the explanation on the page with the way forward.
        setState(() {
          _unavailable = error.message;
          _sentTo = null;
        });
        AppNotice.error(context, error.message);
      } else {
        AppNotice.error(context, error);
      }
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
      final session = await ref
          .read(appGatewayProvider)
          .verifyEmailSignIn(sentTo, _code.text.trim());
      if (!mounted) return;
      ref.read(authControllerProvider.notifier).accept(session);
      context.go('/home');
    } on Object catch (error) {
      if (mounted) AppNotice.error(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
