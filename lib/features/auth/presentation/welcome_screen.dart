import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fplboardman/app/theme/app_theme.dart';
import 'package:fplboardman/core/ui/app_notice.dart';
import 'package:fplboardman/core/ui/app_widgets.dart';
import 'package:fplboardman/features/auth/presentation/web_qr_sign_in.dart';
import 'package:go_router/go_router.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  /// FPL sign-in reads the session from FPL's own login page inside an
  /// in-app browser. A web page is not allowed to do that to another site,
  /// so in a browser this button explains what to do instead.
  void _signInWithFpl(BuildContext context) {
    if (kIsWeb) {
      AppNotice.info(
        context,
        'Sign in with FPL works in the FPLboardman mobile app. Sign in there '
        'once and verify your email, then use Sign in with email here.',
      );
      return;
    }
    context.go('/fpl-login');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final muted = scheme.onSurfaceVariant;
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: dark
                ? const [Color(0xFF031C17), Color(0xFF0A2F27), Color(0xFF22123B)]
                : const [Color(0xFFF7FBF5), Color(0xFFE7FBE8), Color(0xFFF1E9FF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            // Two soft glows in the brand colours behind the card.
            Positioned(
              top: -160,
              left: -120,
              child: _Glow(
                color: scheme.primary.withValues(alpha: dark ? 0.20 : 0.14),
                size: 460,
              ),
            ),
            Positioned(
              bottom: -180,
              right: -140,
              child: _Glow(
                color: AppColors.purple.withValues(alpha: dark ? 0.18 : 0.10),
                size: 520,
              ),
            ),
            SafeArea(
              child: Center(
                // Scrolls instead of overflowing on a small phone or with
                // large text; the inner Center stops the card stretching to
                // the width of a wide screen.
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Center(child: BrandMark()),
                          const SizedBox(height: 24),
                          FadeSlideIn(child: _card(context, theme, dark, muted)),
                          const SizedBox(height: 18),
                          Text(
                            '18+ · Play responsibly',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.labelSmall?.copyWith(color: muted),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(BuildContext context, ThemeData theme, bool dark, Color muted) =>
      DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: dark ? 0.86 : 0.94),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: dark ? 0.35 : 0.08),
              blurRadius: 40,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: kIsWeb
              ? _webCard(context, theme, muted)
              : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.13),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.emoji_events_rounded,
                    size: 38,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Put your gameweek\nwhere your mouth is.',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Join trusted pools, challenge a rival head to head, and '
                'follow every result with a transparent wallet.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: muted,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 26),
              FilledButton.icon(
                onPressed: () => _signInWithFpl(context),
                icon: const Icon(Icons.sports_soccer_rounded),
                label: const Text('Sign in with FPL'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => context.go('/email-sign-in'),
                icon: const Icon(Icons.mail_outline_rounded),
                label: const Text('Sign in with email'),
              ),
              const SizedBox(height: 16),
              Text(
                'New here? Use Sign in with FPL: it opens the official '
                'Fantasy Premier League login, where your password goes '
                'straight to them and never to us. Once you have verified '
                'your email you can also sign in with email.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
            ],
          ),
        ),
      );

  /// On the website: sign in by scanning a QR code with the phone app, or
  /// with email.
  Widget _webCard(BuildContext context, ThemeData theme, Color muted) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const WebQrSignIn(),
          const SizedBox(height: 18),
          Row(
            children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('or', style: TextStyle(color: muted)),
              ),
              const Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () => context.go('/email-sign-in'),
            icon: const Icon(Icons.mail_outline_rounded),
            label: const Text('Sign in with email'),
          ),
          const SizedBox(height: 14),
          Text(
            'New to FPLboardman? Create your account in the Android app with '
            'Sign in with FPL, then sign in here with your phone.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
        ],
      );
}

/// A soft round glow of colour behind the sign-in card.
class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
          ),
        ),
      );
}
