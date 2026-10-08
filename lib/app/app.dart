import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fplboardman/app/router/app_router.dart';
import 'package:fplboardman/app/theme/app_theme.dart';
import 'package:fplboardman/features/settings/presentation/settings_controller.dart';
import 'package:fplboardman/core/realtime/realtime_sync.dart';
import 'package:fplboardman/features/wallet/presentation/wallet_live.dart';

class FplBoardmanApp extends ConsumerWidget {
  const FplBoardmanApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(realtimeSyncProvider);
    // Keeps the wallet balance in the header current.
    ref.watch(walletLiveProvider);
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(settingsControllerProvider).value?.themeMode ?? ThemeMode.system;
    return MaterialApp.router(
      title: 'FPLboardman',
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
