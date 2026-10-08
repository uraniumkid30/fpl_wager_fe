import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fplboardman/core/network/providers.dart';
import 'package:fplboardman/features/auth/presentation/auth_controller.dart';
import 'package:fplboardman/features/settings/domain/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

final settingsControllerProvider =
    AsyncNotifierProvider<SettingsController, AppSettings>(SettingsController.new);

class SettingsController extends AsyncNotifier<AppSettings> {
  final _preferences = SharedPreferencesAsync();

  @override
  Future<AppSettings> build() async {
    final saved = await _preferences.getString('theme_mode');
    return AppSettings(
      themeMode: switch (saved) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      },
      pushNotifications:
          await _preferences.getBool('push_notifications') ?? true,
      poolNotifications:
          await _preferences.getBool('pool_notifications') ?? true,
      challengeNotifications:
          await _preferences.getBool('challenge_notifications') ?? true,
      marketingNotifications:
          await _preferences.getBool('marketing_notifications') ?? false,
    );
  }

  Future<void> saveSettings(AppSettings next) async {
    final previous = state.value ?? const AppSettings();
    state = AsyncData(next);
    await _persist(next);
    if (ref.read(authControllerProvider).value != null) {
      final result = await AsyncValue.guard(
        () => ref.read(appGatewayProvider).updateSettings(next),
      );
      if (result.hasError) {
        state = AsyncData(previous);
        await _persist(previous);
      } else {
        state = AsyncData(result.requireValue);
      }
    }
  }

  Future<void> _persist(AppSettings value) async {
    await _preferences.setString('theme_mode', value.themeMode.name);
    await _preferences.setBool('push_notifications', value.pushNotifications);
    await _preferences.setBool('pool_notifications', value.poolNotifications);
    await _preferences.setBool(
      'challenge_notifications',
      value.challengeNotifications,
    );
    await _preferences.setBool(
      'marketing_notifications',
      value.marketingNotifications,
    );
  }
}
