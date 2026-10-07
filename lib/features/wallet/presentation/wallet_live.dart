import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpl_wager/core/config/app_config.dart';
import 'package:fpl_wager/core/network/providers.dart';
import 'package:fpl_wager/core/realtime/realtime_sync.dart';
import 'package:fpl_wager/features/auth/presentation/auth_controller.dart';
import 'package:fpl_wager/features/dashboard/presentation/dashboard_controller.dart';
import 'package:fpl_wager/features/wallet/domain/wallet_models.dart';
import 'package:fpl_wager/features/wallet/presentation/wallet_controller.dart';

/// Keeps the wallet balance on screen current for as long as someone is
/// signed in. Watched once, by the app itself.
///
/// The live connection (see `realtime_sync.dart`) is what normally brings a
/// change to the screen the moment it happens. This is the safety net for
/// when that connection is down or cannot be made at all, and for changes
/// that happened while the app was in the background:
///
///  * it asks the server for the balance every [_whenOffline] while there is
///    no live connection, and every [_whenLive] while there is one;
///  * it asks again the moment the app comes back to the foreground;
///  * it asks nothing while the app is in the background.
///
/// The check is a small request for two numbers. Only when they differ from
/// what is showing are the wallet and the home page loaded again, so nothing
/// on screen flickers, and a check that fails (no network) changes nothing.
final walletLiveProvider = Provider<void>((ref) {
  final session = ref.watch(authControllerProvider).value;
  if (session == null || AppConfig.useDemoData) return;

  // Listening keeps the wallet loaded, so the header has a figure on every
  // page, and tells this watcher what that figure currently is.
  WalletSummary? showing;
  var failed = false;
  ref.listen<AsyncValue<WalletSummary>>(
    walletProvider,
    (_, next) {
      showing = next.hasValue ? next.requireValue : null;
      failed = next.hasError;
    },
    fireImmediately: true,
  );

  var disposed = false;
  var checking = false;
  var lastCheck = DateTime.now();

  Future<void> check() async {
    if (checking || disposed) return;
    checking = true;
    try {
      final latest = await ref.read(appGatewayProvider).walletBalance();
      if (disposed) return;
      final shown = showing;
      final changed = shown == null
          // Nothing is showing: worth another go only if loading it failed.
          ? failed
          : shown.availableCents != latest.availableCents ||
              shown.lockedCents != latest.lockedCents;
      if (changed) {
        ref.invalidate(walletProvider);
        ref.invalidate(dashboardProvider);
      }
    } on Object {
      // Offline, or the server is busy. The next check will do.
    } finally {
      checking = false;
      lastCheck = DateTime.now();
    }
  }

  bool visible(AppLifecycleState? state) =>
      state == null ||
      state == AppLifecycleState.resumed ||
      state == AppLifecycleState.inactive;

  var foreground = visible(WidgetsBinding.instance.lifecycleState);
  final lifecycle = AppLifecycleListener(
    onStateChange: (state) {
      final now = visible(state);
      if (now && !foreground) unawaited(check());
      foreground = now;
    },
  );

  final timer = Timer.periodic(const Duration(seconds: 5), (_) {
    if (!foreground || disposed) return;
    final live = ref.read(realtimeSyncProvider)?.isConnected ?? false;
    final due = live ? _whenLive : _whenOffline;
    if (DateTime.now().difference(lastCheck) >= due) unawaited(check());
  });

  ref.onDispose(() {
    disposed = true;
    timer.cancel();
    lifecycle.dispose();
  });
});

/// How often the balance is checked while the live connection is up. The
/// connection already announces every change; this only catches one that
/// slipped through.
const _whenLive = Duration(seconds: 60);

/// How often the balance is checked while there is no live connection.
const _whenOffline = Duration(seconds: 10);
