import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fplboardman/core/config/app_config.dart';
import 'package:fplboardman/core/network/api_client.dart';
import 'package:fplboardman/core/network/providers.dart';
import 'package:fplboardman/core/realtime/realtime_socket.dart';
import 'package:fplboardman/features/auth/presentation/auth_controller.dart';
import 'package:fplboardman/features/challenges/presentation/challenges_controller.dart';
import 'package:fplboardman/features/dashboard/presentation/dashboard_controller.dart';
import 'package:fplboardman/features/pools/presentation/pools_controller.dart';
import 'package:fplboardman/features/wallet/presentation/wallet_controller.dart';
import 'package:fplboardman/features/notifications/presentation/notifications_controller.dart';
import 'package:fplboardman/features/withdrawals/presentation/withdrawal_controller.dart';

/// Keeps server-owned read models fresh without putting JWTs in WebSocket URLs.
/// The HTTP client first obtains a short-lived, single-use connection ticket.
final realtimeSyncProvider = Provider<RealtimeSync?>((ref) {
  final session = ref.watch(authControllerProvider).value;
  if (session == null || AppConfig.useDemoData) return null;

  final sync = RealtimeSync(
    client: ref.watch(apiClientProvider),
    onResources: (resources, resourceId) =>
        _invalidate(ref, resources, resourceId),
    onReconnected: () => _catchUp(ref),
  )..start();
  ref.onDispose(sync.dispose);
  return sync;
});

void _invalidate(Ref ref, Set<String> resources, String? resourceId) {
  if (resources.contains('dashboard')) ref.invalidate(dashboardProvider);
  if (resources.contains('wallet') || resources.contains('history')) {
    ref.invalidate(walletProvider);
  }
  if (resources.contains('pools')) {
    ref.invalidate(poolsProvider);
    if (resourceId != null && resourceId.isNotEmpty) {
      ref.invalidate(poolProvider(resourceId));
    } else {
      // A change to every pool, such as the delete fee: open pool pages and
      // the create page show it.
      ref.invalidate(poolProvider);
      ref.invalidate(poolTermsProvider);
    }
  }
  // A pool's leaderboard moved (its gameweek is being played). Only the
  // pages showing that pool reload; the list of pools does not change.
  if (resources.contains('pool_standings')) {
    if (resourceId != null && resourceId.isNotEmpty) {
      ref.invalidate(poolProvider(resourceId));
    }
    ref.invalidate(poolInviteProvider);
  }
  if (resources.contains('challenges')) ref.invalidate(challengesProvider);
  if (resources.contains('account')) {
    ref.invalidate(authControllerProvider);
  }
  if (resources.contains('notifications')) {
    ref.invalidate(notificationsProvider);
  }
  if (resources.contains('withdrawals')) ref.invalidate(withdrawalsProvider);
  if (resources.contains('bank_account')) ref.invalidate(bankAccountProvider);
}

/// The connection was lost and has come back. Whatever the server announced
/// in between was missed, so everything that may be on screen is loaded
/// again.
void _catchUp(Ref ref) {
  ref.invalidate(dashboardProvider);
  ref.invalidate(walletProvider);
  ref.invalidate(poolsProvider);
  ref.invalidate(poolProvider);
  ref.invalidate(challengesProvider);
  ref.invalidate(notificationsProvider);
  ref.invalidate(withdrawalsProvider);
}

final class RealtimeSync {
  RealtimeSync({
    required this.client,
    required this.onResources,
    this.onReconnected,
  });

  final ApiClient client;
  final void Function(Set<String> resources, String? resourceId) onResources;

  /// Called each time the connection is made again after having been lost
  /// (not the first time it is made).
  final void Function()? onReconnected;

  /// Whether the live connection is up right now.
  bool get isConnected => _socket != null;
  bool _connectedBefore = false;
  final _random = Random();

  RealtimeSocket? _socket;
  StreamSubscription<String>? _messages;
  bool _disposed = false;
  int _attempt = 0;

  void start() => unawaited(_connectLoop());

  Future<void> dispose() async {
    _disposed = true;
    await _messages?.cancel();
    await _socket?.close();
  }

  Future<void> _connectLoop() async {
    while (!_disposed) {
      try {
        final ticket = await client.createRealtimeTicket();
        if (_disposed) return;
        final socket = await connectRealtimeSocket(client.realtimeUri(ticket));
        if (_disposed) {
          await socket.close();
          return;
        }
        _socket = socket;
        _attempt = 0;
        if (_connectedBefore) onReconnected?.call();
        _connectedBefore = true;
        _messages = socket.messages.listen(
          _handleMessage,
          onError: (_) {},
        );
        await socket.done;
      } on Object {
        // Network transitions are expected. The next iteration gets a fresh
        // one-time ticket before reconnecting.
      } finally {
        await _messages?.cancel();
        _messages = null;
        _socket = null;
      }
      if (_disposed) return;
      final exponent = min(_attempt++, 5);
      final baseMilliseconds = 1000 * (1 << exponent);
      final jitter = _random.nextInt(500);
      await Future<void>.delayed(
        Duration(milliseconds: min(baseMilliseconds + jitter, 30000)),
      );
    }
  }

  void _handleMessage(String message) {
    try {
      final event = jsonDecode(message);
      if (event is! Map<Object?, Object?>) return;
      final raw = event['resources'];
      if (raw is! List<Object?>) return;
      onResources(
        raw.whereType<String>().toSet(),
        event['resource_id'] as String?,
      );
    } on FormatException {
      // Ignore malformed messages; the next valid invalidation is sufficient.
    }
  }
}
