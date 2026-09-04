import 'package:flutter/material.dart';
import 'package:fpl_wager/app/theme/app_theme.dart';
import 'package:fpl_wager/core/ui/app_widgets.dart';
import 'package:go_router/go_router.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

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
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Align(alignment: Alignment.centerLeft, child: BrandMark()),
                  const Spacer(),
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
                  FilledButton(
                    onPressed: () => context.go('/sign-up'),
                    child: const Text('Create your account'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => context.go('/sign-in'),
                    child: const Text('I already play'),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '18+ · Play responsibly · Secure payments via Paystack or Korapay',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
