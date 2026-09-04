import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpl_wager/core/network/providers.dart';
import 'package:fpl_wager/features/challenges/domain/challenge.dart';
import 'package:fpl_wager/features/dashboard/presentation/dashboard_controller.dart';
import 'package:fpl_wager/features/wallet/presentation/wallet_controller.dart';

final challengesProvider = FutureProvider.autoDispose<List<Challenge>>(
  (ref) => ref.watch(appGatewayProvider).challenges(),
);

final challengeActionProvider = AsyncNotifierProvider<ChallengeActionController, void>(ChallengeActionController.new);

class ChallengeActionController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> create({required int opponentTeamId, required int gameweek, required int stakeCents}) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() => ref.read(appGatewayProvider).createChallenge(opponentTeamId: opponentTeamId, gameweek: gameweek, stakeCents: stakeCents));
    state = result.when(data: (_) => const AsyncData(null), error: (error, stack) => AsyncError<void>(error, stack), loading: () => const AsyncLoading());
    if (!result.hasError) { ref.invalidate(challengesProvider); ref.invalidate(walletProvider); ref.invalidate(dashboardProvider); }
    return !result.hasError;
  }
}
