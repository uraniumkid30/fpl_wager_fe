import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fplboardman/core/network/providers.dart';
import 'package:fplboardman/features/auth/domain/auth_models.dart';
import 'package:fplboardman/features/auth/presentation/fpl_web_session.dart';

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthSession?>(AuthController.new);

class AuthController extends AsyncNotifier<AuthSession?> {
  @override
  Future<AuthSession?> build() => ref.read(appGatewayProvider).restoreSession();

  void accept(AuthSession session) => state = AsyncData(session);

  Future<void> logout() async {
    await ref.read(appGatewayProvider).logout();
    await clearFplWebSession();
    state = const AsyncData(null);
  }
}
