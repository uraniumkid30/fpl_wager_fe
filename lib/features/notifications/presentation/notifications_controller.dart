import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fplboardman/core/network/providers.dart';
import 'package:fplboardman/features/notifications/domain/app_notification.dart';

final notificationsProvider = FutureProvider.autoDispose<List<AppNotification>>(
  (ref) => ref.watch(appGatewayProvider).notifications(),
);

final unreadNotificationCountProvider = Provider<int>((ref) {
  return ref.watch(notificationsProvider).value?.where((item) => item.isUnread).length ?? 0;
});

final notificationActionProvider = AsyncNotifierProvider<NotificationActionController, void>(NotificationActionController.new);

class NotificationActionController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> markRead(String id) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() => ref.read(appGatewayProvider).markNotificationRead(id));
    state = result;
    if (!result.hasError) ref.invalidate(notificationsProvider);
    return !result.hasError;
  }
}
