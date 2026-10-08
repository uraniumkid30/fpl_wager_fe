import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fplboardman/core/network/providers.dart';
import 'package:fplboardman/features/dashboard/presentation/dashboard_controller.dart';
import 'package:fplboardman/features/wallet/domain/wallet_models.dart';

final walletProvider = FutureProvider.autoDispose<WalletSummary>(
  (ref) => ref.watch(appGatewayProvider).wallet(),
);

final walletActionProvider =
    AsyncNotifierProvider<WalletActionController, void>(WalletActionController.new);

class WalletActionController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> credit(int amountCents) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref.read(appGatewayProvider).creditWallet(amountCents),
    );
    state = result.when(
      data: (_) => const AsyncData(null),
      error: (error, stack) => AsyncError<void>(error, stack),
      loading: () => const AsyncLoading(),
    );
    if (!result.hasError) {
      ref.invalidate(walletProvider);
      ref.invalidate(dashboardProvider);
    }
    return !result.hasError;
  }
}
