import 'package:flutter/material.dart';
import 'package:fpl_wager/app/theme/app_theme.dart';
import 'package:fpl_wager/core/ui/app_widgets.dart';

class AuthScaffold extends StatelessWidget {
  const AuthScaffold({required this.title, required this.subtitle, required this.child, super.key, this.onBack});
  final String title;
  final String subtitle;
  final Widget child;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: dark
                ? const [Color(0xFF021712), Color(0xFF071F1A)]
                : const [Color(0xFFF8FCF8), Color(0xFFEAF6EF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              const Positioned(right: -90, top: -100, child: _Glow(color: AppColors.purple, size: 280)),
              const Positioned(left: -100, bottom: -110, child: _Glow(color: AppColors.lime, size: 300)),
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1080),
                    child: Row(
                      children: [
                        if (wide) ...[
                          const Expanded(child: _AuthStory()),
                          const SizedBox(width: 72),
                        ],
                        Expanded(
                          flex: wide ? 0 : 1,
                          child: SizedBox(
                            width: wide ? 460 : null,
                            child: FadeSlideIn(
                              child: GradientPanel(
                                padding: const EdgeInsets.all(AppSpacing.xl),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Row(children: [
                                      if (onBack != null)
                                        IconButton.filledTonal(
                                          tooltip: 'Back',
                                          onPressed: onBack,
                                          icon: const Icon(Icons.arrow_back_rounded),
                                        ),
                                      if (onBack != null) const SizedBox(width: 12),
                                      const BrandMark(compact: true),
                                    ]),
                                    const SizedBox(height: 30),
                                    Text(title, style: Theme.of(context).textTheme.headlineMedium),
                                    const SizedBox(height: 8),
                                    Text(
                                      subtitle,
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                    const SizedBox(height: 28),
                                    child,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthStory extends StatelessWidget {
  const _AuthStory();

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const StatusPill('Built for gameweek'),
          const SizedBox(height: 24),
          Text(
            'Put your gameweek\nwhere your mouth is.',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w900, height: 1.05),
          ),
          const SizedBox(height: 18),
          Text(
            'Verified FPL teams, transparent wallets, and private competition—all in one place.',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
          ),
        ],
      );
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.08)),
        ),
      );
}
