import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpl_wager/features/admin/data/admin_repository.dart';
import 'package:fpl_wager/features/auth/domain/auth_models.dart';

final adminCollectionProvider = FutureProvider.autoDispose
    .family<List<Map<String, Object?>>, String>(
  (ref, resource) {
    return ref.watch(adminRepositoryProvider).collection(resource);
  },
);

final adminUserProvider =
    FutureProvider.autoDispose.family<UserProfile, String>(
  (ref, userId) {
    return ref.watch(adminRepositoryProvider).user(userId);
  },
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
      () => ref.read(adminRepositoryProvider).updateUser(
            userId,
            changes,
          ),
    );

    state = result;

    if (!result.hasError) {
      ref.invalidate(adminUserProvider(userId));
      ref.invalidate(adminCollectionProvider('users'));
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
    }

    return !result.hasError;
  }
}