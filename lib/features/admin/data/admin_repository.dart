import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpl_wager/core/network/api_client.dart';
import 'package:fpl_wager/core/network/providers.dart';
import 'package:fpl_wager/features/auth/domain/auth_models.dart';

final adminRepositoryProvider = Provider<AdminRepository>(
  (ref) => AdminRepository(ref.watch(apiClientProvider)),
);

class AdminRepository {
  const AdminRepository(this._client);
  final ApiClient _client;

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
}
