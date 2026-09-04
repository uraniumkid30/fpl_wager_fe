import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fpl_wager/app/router/app_router.dart';
import 'package:fpl_wager/app/theme/app_theme.dart';
import 'package:fpl_wager/features/settings/presentation/settings_controller.dart';

class FplWagerApp extends ConsumerWidget {
  const FplWagerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(settingsControllerProvider).value?.themeMode ?? ThemeMode.system;
    return MaterialApp.router(
      title: 'FPLWager',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      themeAnimationDuration: AppMotion.standard,
      themeAnimationCurve: AppMotion.curve,
      routerConfig: router,
    );
  }
}

