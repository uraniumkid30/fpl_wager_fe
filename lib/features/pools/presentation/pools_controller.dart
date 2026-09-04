import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpl_wager/core/network/providers.dart';
import 'package:fpl_wager/features/dashboard/presentation/dashboard_controller.dart';
import 'package:fpl_wager/features/pools/domain/pool.dart';
import 'package:fpl_wager/features/wallet/presentation/wallet_controller.dart';

final poolsProvider = FutureProvider.autoDispose<List<Pool>>(
  (ref) => ref.watch(appGatewayProvider).pools(),
);

final poolProvider = FutureProvider.autoDispose.family<Pool, String>(
  (ref, id) => ref.watch(appGatewayProvider).pool(id),
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
      ref.invalidate(dashboardProvider);
      ref.invalidate(walletProvider);
      return result.requireValue;
    }
    return null;
  }
}
