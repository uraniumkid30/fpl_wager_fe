import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpl_wager/app/theme/app_theme.dart';
import 'package:fpl_wager/core/ui/app_widgets.dart';
import 'package:fpl_wager/features/auth/presentation/auth_controller.dart';
import 'package:fpl_wager/features/dashboard/presentation/dashboard_controller.dart';
import 'package:fpl_wager/features/settings/domain/app_settings.dart';
import 'package:fpl_wager/features/settings/presentation/settings_controller.dart';
import 'package:go_router/go_router.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(settingsControllerProvider);
    final profile = ref.watch(dashboardProvider).value?.user ??
        ref.watch(authControllerProvider).value?.user;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: AsyncContent(
        value: async,
        onRetry: () => ref.invalidate(settingsControllerProvider),
        data: (settings) => ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            if (profile != null)
              GradientPanel(
                child: Row(children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                    child: Text(profile.firstName.characters.first.toUpperCase(), style: Theme.of(context).textTheme.titleLarge),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(profile.fullName, style: Theme.of(context).textTheme.titleMedium),
                    if (profile.displayEmail.isNotEmpty)
                      Text(profile.displayEmail, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 6),
                    StatusPill(profile.status),
                  ])),
                ]),
              ),
            const SizedBox(height: 24),
            Text('Appearance', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.system, label: Text('System'), icon: Icon(Icons.brightness_auto_rounded)),
                ButtonSegment(value: ThemeMode.light, label: Text('Light'), icon: Icon(Icons.light_mode_outlined)),
                ButtonSegment(value: ThemeMode.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode_outlined)),
              ],
              selected: {settings.themeMode},
              onSelectionChanged: (value) => _update(ref, settings.copyWith(themeMode: value.first)),
            ),
            const SizedBox(height: 26),
            Text('Notifications', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            GradientPanel(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Column(children: [
                SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Push notifications'), subtitle: const Text('Master switch for device alerts'), value: settings.pushNotifications, onChanged: (value) => _update(ref, settings.copyWith(pushNotifications: value))),
                SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Pool updates'), subtitle: const Text('Entries, deadlines and settlements'), value: settings.poolNotifications, onChanged: settings.pushNotifications ? (value) => _update(ref, settings.copyWith(poolNotifications: value)) : null),
                SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Challenges'), subtitle: const Text('Requests, results and refunds'), value: settings.challengeNotifications, onChanged: settings.pushNotifications ? (value) => _update(ref, settings.copyWith(challengeNotifications: value)) : null),
                SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Product news'), subtitle: const Text('Occasional feature announcements'), value: settings.marketingNotifications, onChanged: settings.pushNotifications ? (value) => _update(ref, settings.copyWith(marketingNotifications: value)) : null),
              ]),
            ),
            const SizedBox(height: 26),
            OutlinedButton.icon(
              onPressed: () async {
                await ref.read(authControllerProvider.notifier).logout();
                if (context.mounted) context.go('/welcome');
              },
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Sign out'),
            ),
            const SizedBox(height: 12),
            Text('FPLwager is not affiliated with the Premier League. 18+ · Play responsibly.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  void _update(WidgetRef ref, AppSettings settings) => ref.read(settingsControllerProvider.notifier).saveSettings(settings);
}
