import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fpl_wager/app/theme/app_theme.dart';
import 'package:fpl_wager/core/ui/app_notice.dart';
import 'package:fpl_wager/core/ui/app_widgets.dart';
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
  Widget build(BuildContext context) => Scaffold(
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: Theme.of(context).brightness == Brightness.dark
                  ? const [Color(0xFF031C17), Color(0xFF0A2F27), Color(0xFF22123B)]
                  : const [Color(0xFFF7FBF5), Color(0xFFE7FBE8), Color(0xFFF1E9FF)],
              begin: Alignment.topCenter,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            // The page fills the screen, with the buttons at the bottom, and
            // scrolls instead of overflowing on a small phone or with large
            // text.
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    // The space left inside the padding above and below.
                    minHeight: constraints.maxHeight > 2 * AppSpacing.lg
                        ? constraints.maxHeight - 2 * AppSpacing.lg
                        : 0.0,
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Align(alignment: Alignment.centerLeft, child: BrandMark()),
                  const Spacer(),
                  const SizedBox(height: 24),
                  FadeSlideIn(
                    child: Container(
                      width: 92,
                      height: 92,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.13),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.emoji_events_rounded, size: 48, color: Theme.of(context).colorScheme.primary),
                    ),
                  ),
                  const SizedBox(height: 28),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 90),
                    child: Text(
                      'Put your gameweek\nwhere your mouth is.',
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 160),
                    child: Text(
                      'Join trusted pools, challenge a rival head to head, and follow every result with a transparent wallet.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            height: 1.5,
                          ),
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(height: 28),
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
                  const SizedBox(height: 10),
                  Text(
                    'New here? Use Sign in with FPL: it opens the official '
                    'Fantasy Premier League login, where your password goes '
                    'straight to them and never to us. Once you have verified '
                    'your email you can also sign in with email.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '18+ · Play responsibly',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}
