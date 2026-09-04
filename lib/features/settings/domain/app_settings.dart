import 'package:flutter/material.dart';

class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.pushNotifications = true,
    this.poolNotifications = true,
    this.challengeNotifications = true,
    this.marketingNotifications = false,
  });

  factory AppSettings.fromJson(Map<String, Object?> json) => AppSettings(
        themeMode: switch (json['theme_mode']) {
          'light' => ThemeMode.light,
          'dark' => ThemeMode.dark,
          _ => ThemeMode.system,
        },
        pushNotifications: json['push_notifications'] as bool? ?? true,
        poolNotifications: json['pool_notifications'] as bool? ?? true,
        challengeNotifications:
            json['challenge_notifications'] as bool? ?? true,
        marketingNotifications:
            json['marketing_notifications'] as bool? ?? false,
      );

  final ThemeMode themeMode;
  final bool pushNotifications;
  final bool poolNotifications;
  final bool challengeNotifications;
  final bool marketingNotifications;

  AppSettings copyWith({
    ThemeMode? themeMode,
    bool? pushNotifications,
    bool? poolNotifications,
    bool? challengeNotifications,
    bool? marketingNotifications,
  }) =>
      AppSettings(
        themeMode: themeMode ?? this.themeMode,
        pushNotifications: pushNotifications ?? this.pushNotifications,
        poolNotifications: poolNotifications ?? this.poolNotifications,
        challengeNotifications:
            challengeNotifications ?? this.challengeNotifications,
        marketingNotifications:
            marketingNotifications ?? this.marketingNotifications,
      );

  Map<String, Object?> toJson() => {
        'theme_mode': themeMode.name,
        'push_notifications': pushNotifications,
        'pool_notifications': poolNotifications,
        'challenge_notifications': challengeNotifications,
        'marketing_notifications': marketingNotifications,
      };
}

