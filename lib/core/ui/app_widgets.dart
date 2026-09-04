import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpl_wager/app/theme/app_theme.dart';
import 'package:intl/intl.dart';

final _clockProvider = StreamProvider.autoDispose<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream<DateTime>.periodic(
    const Duration(seconds: 1),
    (_) => DateTime.now(),
  );
});

String money(int cents) => NumberFormat.currency(
      locale: 'en_NG',
      symbol: '₦',
      decimalDigits: 0,
    ).format(cents / 100);

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 30 : 38,
            height: compact ? 30 : 38,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.lime, AppColors.emerald],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppColors.lime.withValues(alpha: 0.25),
                  blurRadius: 18,
                ),
              ],
            ),
            child: Icon(Icons.emoji_events_rounded, size: compact ? 18 : 22, color: AppColors.ink),
          ),
          const SizedBox(width: 10),
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'FPL'),
                TextSpan(
                  text: 'Wager',
                  style: TextStyle(color: Theme.of(context).colorScheme.primary),
                ),
              ],
            ),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
        ],
      );
}

class GradientPanel extends StatelessWidget {
  const GradientPanel({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.colors,
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final List<Color>? colors;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final panel = AnimatedContainer(
      duration: AppMotion.standard,
      curve: AppMotion.curve,
      padding: padding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors ??
              (dark
                  ? const [Color(0xFF0B3C31), Color(0xFF241342)]
                  : const [Color(0xFFFFFFFF), Color(0xFFF0E8FF)]),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
        boxShadow: dark
            ? null
            : [const BoxShadow(color: Color(0x14052B22), blurRadius: 24, offset: Offset(0, 10))],
      ),
      child: child,
    );
    return onTap == null
        ? panel
        : Material(color: Colors.transparent, child: InkWell(borderRadius: BorderRadius.circular(24), onTap: onTap, child: panel));
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill(this.label, {super.key, this.color});
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final resolved = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: resolved.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label.toUpperCase(), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: resolved, fontWeight: FontWeight.w900, letterSpacing: 0.4)),
    );
  }
}

class DeadlineCountdown extends ConsumerWidget {
  const DeadlineCountdown(this.deadline, {super.key, this.compact = false});
  final DateTime deadline;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(_clockProvider).value ?? DateTime.now();
    final remaining = deadline.difference(now);
    final safe = remaining.isNegative ? Duration.zero : remaining;
    final days = safe.inDays;
    final hours = safe.inHours.remainder(24);
    final minutes = safe.inMinutes.remainder(60);
    final value = '${days}d ${hours}h ${minutes}m';
    return Text(value, style: (compact ? Theme.of(context).textTheme.labelMedium : Theme.of(context).textTheme.headlineMedium)?.copyWith(fontWeight: FontWeight.w900));
  }
}

class AsyncContent<T> extends StatelessWidget {
  const AsyncContent({required this.value, required this.data, super.key, this.onRetry});
  final AsyncValue<T> value;
  final Widget Function(T value) data;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => value.when(
        data: data,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_off_rounded, size: 44, color: Theme.of(context).colorScheme.error),
                const SizedBox(height: 16),
                Text(error.toString(), textAlign: TextAlign.center),
                if (onRetry != null) ...[
                  const SizedBox(height: 16),
                  FilledButton.tonal(onPressed: onRetry, child: const Text('Try again')),
                ],
              ],
            ),
          ),
        ),
      );
}

class EmptyState extends StatelessWidget {
  const EmptyState({required this.icon, required this.title, required this.message, super.key});
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12), shape: BoxShape.circle), child: Icon(icon, size: 34, color: Theme.of(context).colorScheme.primary)),
              const SizedBox(height: 18),
              Text(title, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(message, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant), textAlign: TextAlign.center),
            ],
          ),
        ),
      );
}

class FadeSlideIn extends StatelessWidget {
  const FadeSlideIn({required this.child, super.key, this.delay = Duration.zero});
  final Widget child;
  final Duration delay;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        duration: AppMotion.entrance + delay,
        curve: AppMotion.curve,
        tween: Tween(begin: 0, end: 1),
        builder: (context, value, child) => Opacity(
          opacity: value,
          child: Transform.translate(offset: Offset(0, 18 * (1 - value)), child: child),
        ),
        child: child,
      );
}

