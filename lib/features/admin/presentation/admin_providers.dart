import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpl_wager/features/admin/data/admin_repository.dart';
import 'package:fpl_wager/features/admin/domain/admin_models.dart';
import 'package:fpl_wager/features/auth/domain/auth_models.dart';

final adminDashboardProvider = FutureProvider.autoDispose<AdminDashboardSummary>(
  (ref) => ref.watch(adminRepositoryProvider).dashboard(),
);

final adminCollectionProvider = FutureProvider.autoDispose
    .family<List<Map<String, Object?>>, String>(
  (ref, resource) => ref.watch(adminRepositoryProvider).collection(resource),
);

final adminUserProvider = FutureProvider.autoDispose.family<UserProfile, String>(
  (ref, userId) => ref.watch(adminRepositoryProvider).user(userId),
);

final adminUserActionProvider =
    AsyncNotifierProvider<AdminUserActionController, void>(
  AdminUserActionController.new,
);

class AdminUserActionController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> updateUser(
    String userId,
    Map<String, Object?> changes,
  ) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard<void>(
      () => ref.read(adminRepositoryProvider).updateUser(userId, changes),
    );
    state = result;

    if (!result.hasError) {
      ref.invalidate(adminUserProvider(userId));
      ref.invalidate(adminCollectionProvider('users'));
      ref.invalidate(adminDashboardProvider);
    }
    return !result.hasError;
  }

  Future<bool> deactivateUser(String userId) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard<void>(
      () => ref.read(adminRepositoryProvider).deactivateUser(userId),
    );
    state = result;

    if (!result.hasError) {
      ref.invalidate(adminUserProvider(userId));
      ref.invalidate(adminCollectionProvider('users'));
      ref.invalidate(adminDashboardProvider);
    }
    return !result.hasError;
  }
}

final adminResourceActionProvider =
    AsyncNotifierProvider<AdminResourceActionController, void>(
  AdminResourceActionController.new,
);

class AdminResourceActionController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> createWager(Map<String, Object?> values) => _run(
        'wagers',
        () => ref.read(adminRepositoryProvider).createWager(values),
      );

  Future<bool> updateWagerStatus(String id, String status) => _run(
        'wagers',
        () => ref.read(adminRepositoryProvider).updateWagerStatus(id, status),
      );

  Future<bool> putSetting(String key, Object? value) => _run(
        'settings',
        () => ref.read(adminRepositoryProvider).putSetting(key, value),
      );

  Future<bool> verifyPayment(String reference) => _run(
        'payments',
        () => ref.read(adminRepositoryProvider).verifyPayment(reference),
      );

  Future<bool> adjustWallet({
    required String userId,
    required int amountCents,
    required String reason,
  }) =>
      _run(
        'wallets',
        () => ref.read(adminRepositoryProvider).adjustWallet(
              userId: userId,
              amountCents: amountCents,
              reason: reason,
            ),
      );

  Future<bool> _run(
    String resource,
    Future<void> Function() action,
  ) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard<void>(action);
    state = result;

    if (!result.hasError) {
      ref.invalidate(adminCollectionProvider(resource));
      ref.invalidate(adminDashboardProvider);
    }
    return !result.hasError;
  }
}
