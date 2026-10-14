import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fplboardman/core/network/providers.dart';
import 'package:fplboardman/features/dashboard/presentation/dashboard_controller.dart';
import 'package:fplboardman/features/pools/domain/gameweek_history.dart';
import 'package:fplboardman/features/pools/domain/pool.dart';
import 'package:fplboardman/features/wallet/presentation/wallet_controller.dart';

/// The pools that can still be joined or are being played, earliest
/// gameweek first. Settled and cancelled pools are never in it.
final poolsProvider = FutureProvider.autoDispose<List<Pool>>((ref) async {
  final items = await ref.watch(appGatewayProvider).pools();
  return items.where((pool) => !pool.isFinished).toList();
});

/// The settled pools the user played in, newest first, with their result.
final pastPoolsProvider = FutureProvider.autoDispose<List<Pool>>(
  (ref) => ref.watch(appGatewayProvider).pools(view: PoolView.past),
);

/// The user's gameweeks, newest first.
final gameweekHistoryProvider =
    FutureProvider.autoDispose<List<GameweekResult>>(
  (ref) => ref.watch(appGatewayProvider).gameweekHistory(),
);

final poolProvider = FutureProvider.autoDispose.family<Pool, String>(
  (ref, id) => ref.watch(appGatewayProvider).pool(id),
);

/// The private pool an invite code belongs to, for the "join by link" page.
final poolInviteProvider = FutureProvider.autoDispose.family<Pool, String>(
  (ref, code) => ref.watch(appGatewayProvider).poolByInvite(code),
);

/// The fee terms for pools users create, shown before creating one.
final poolTermsProvider = FutureProvider.autoDispose<PoolTerms>(
  (ref) => ref.watch(appGatewayProvider).poolTerms(),
);

final poolActionProvider =
    AsyncNotifierProvider<PoolActionController, void>(PoolActionController.new);

class PoolActionController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<Pool?> create(CreatePoolCommand command) =>
      _run(() => ref.read(appGatewayProvider).createPool(command));
  Future<Pool?> join(String id) =>
      _run(() => ref.read(appGatewayProvider).joinPool(id));
  Future<Pool?> leave(String id) =>
      _run(() => ref.read(appGatewayProvider).leavePool(id));
  Future<Pool?> joinByInvite(String code) =>
      _run(() => ref.read(appGatewayProvider).joinPoolByInvite(code));

  Future<Pool?> _run(Future<Pool> Function() action) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(action);
    state = result.when(
      data: (_) => const AsyncData(null),
      error: (error, stack) => AsyncError<void>(error, stack),
      loading: () => const AsyncLoading(),
    );
    if (!result.hasError) {
      ref.invalidate(poolsProvider);
      ref.invalidate(gameweekHistoryProvider);
      ref.invalidate(dashboardProvider);
      ref.invalidate(walletProvider);
      return result.requireValue;
    }
    return null;
  }
}
