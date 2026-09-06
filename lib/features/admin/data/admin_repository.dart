import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpl_wager/core/network/api_client.dart';
import 'package:fpl_wager/core/network/providers.dart';
import 'package:fpl_wager/features/auth/domain/auth_models.dart';
import 'package:fpl_wager/features/admin/domain/admin_models.dart';
import 'package:uuid/uuid.dart';

final adminRepositoryProvider = Provider<AdminRepository>(
  (ref) => AdminRepository(ref.watch(apiClientProvider)),
);

class AdminRepository {
  const AdminRepository(this._client);
  final ApiClient _client;
  static const _uuid = Uuid();

  Future<AdminDashboardSummary> dashboard() async =>
      AdminDashboardSummary.fromJson(await _client.get('/admin/dashboard'));

  Future<List<Map<String, Object?>>> collection(String resource) async {
    final body = await _client.get('/admin/$resource');
    return (body['items'] as List<Object?>? ?? const [])
        .map((item) => Map<String, Object?>.from(item! as Map<Object?, Object?>))
        .toList();
  }

  Future<UserProfile> user(String id) async =>
      UserProfile.fromJson(await _client.get('/admin/users/$id'));

  Future<UserProfile> updateUser(String id, Map<String, Object?> changes) async =>
      UserProfile.fromJson(await _client.patch('/admin/users/$id', data: changes));

  Future<void> deactivateUser(String id) async {
    await _client.delete('/admin/users/$id');
  }

  Future<void> createWager(Map<String, Object?> values) async {
    await _client.post(
      '/admin/wagers',
      data: values,
      idempotencyKey: _uuid.v4(),
    );
  }

  Future<void> updateWagerStatus(String id, String status) async {
    await _client.patch('/admin/wagers/$id', data: {'status': status});
  }

  Future<void> putSetting(String key, Object? value) async {
    await _client.put('/admin/settings/$key', data: {'value': value});
  }

  Future<void> verifyPayment(String reference) async {
    await _client.post('/admin/payments/$reference/verify');
  }

  Future<void> adjustWallet({
    required String userId,
    required int amountCents,
    required String reason,
  }) async {
    await _client.post(
      '/admin/wallets/$userId/adjustments',
      data: {'amount_cents': amountCents, 'reason': reason},
      idempotencyKey: _uuid.v4(),
    );
  }
}
