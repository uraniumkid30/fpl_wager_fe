import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fpl_wager/core/network/providers.dart';
import 'package:fpl_wager/features/auth/domain/auth_models.dart';

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthSession?>(AuthController.new);

class AuthController extends AsyncNotifier<AuthSession?> {
  @override
  Future<AuthSession?> build() => ref.read(appGatewayProvider).restoreSession();

  void accept(AuthSession session) => state = AsyncData(session);

  Future<void> logout() async {
    await ref.read(appGatewayProvider).logout();
    state = const AsyncData(null);
  }
}

enum AuthFlowKind { idle, login, registration, passwordReset }

class AuthFlowState {
  const AuthFlowState({
    this.kind = AuthFlowKind.idle,
    this.email = '',
    this.message = '',
    this.expiresAt,
    this.verificationToken,
    this.isLoading = false,
    this.error,
  });

  final AuthFlowKind kind;
  final String email;
  final String message;
  final DateTime? expiresAt;
  final String? verificationToken;
  final bool isLoading;
  final Object? error;

  bool get needsOtp => kind != AuthFlowKind.idle && verificationToken == null;

  AuthFlowState copyWith({
    AuthFlowKind? kind,
    String? email,
    String? message,
    DateTime? expiresAt,
    String? verificationToken,
    bool clearVerificationToken = false,
    bool? isLoading,
    Object? error,
    bool clearError = false,
  }) => AuthFlowState(
        kind: kind ?? this.kind,
        email: email ?? this.email,
        message: message ?? this.message,
        expiresAt: expiresAt ?? this.expiresAt,
        verificationToken: clearVerificationToken
            ? null
            : verificationToken ?? this.verificationToken,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : error ?? this.error,
      );
}

final authFlowControllerProvider =
    NotifierProvider<AuthFlowController, AuthFlowState>(AuthFlowController.new);

class AuthFlowController extends Notifier<AuthFlowState> {
  @override
  AuthFlowState build() => const AuthFlowState();

  Future<bool> startLogin(String email, String password) async => _challenge(
        kind: AuthFlowKind.login,
        email: email,
        request: () => ref.read(appGatewayProvider).requestLogin(email, password),
      );

  Future<bool> startRegistration({
    required String fullName,
    required String email,
    required String phone,
    required String password,
  }) async => _challenge(
        kind: AuthFlowKind.registration,
        email: email,
        request: () => ref.read(appGatewayProvider).requestRegistration(
          fullName: fullName,
          email: email,
          phone: phone,
          password: password,
        ),
      );

  Future<bool> startPasswordReset(String email) async {
    state = AuthFlowState(
      kind: AuthFlowKind.passwordReset,
      email: email,
      isLoading: true,
    );
    try {
      await ref.read(appGatewayProvider).requestPasswordReset(email);
      state = AuthFlowState(
        kind: AuthFlowKind.passwordReset,
        email: email,
        message: 'If an active account exists, instructions have been sent.',
      );
      return true;
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error);
      return false;
    }
  }

  Future<bool> verifyOtp(String otp) async {
    if (!state.needsOtp || state.isLoading) return false;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      switch (state.kind) {
        case AuthFlowKind.login:
          final session = await ref
              .read(appGatewayProvider)
              .verifyLogin(state.email, otp);
          ref.read(authControllerProvider.notifier).accept(session);
          state = const AuthFlowState();
          break;
        case AuthFlowKind.registration:
          final session = await ref
              .read(appGatewayProvider)
              .verifyRegistration(state.email, otp);
          ref.read(authControllerProvider.notifier).accept(session);
          state = const AuthFlowState();
          break;
        case AuthFlowKind.passwordReset:
          final token = await ref
              .read(appGatewayProvider)
              .verifyPasswordOtp(state.email, otp);
          state = state.copyWith(
            verificationToken: token,
            isLoading: false,
            clearError: true,
          );
          break;
        case AuthFlowKind.idle:
          return false;
      }
      return true;
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error);
      return false;
    }
  }

  Future<bool> completePasswordReset({
    String? email,
    String? token,
    required String newPassword,
  }) async {
    final resolvedEmail = email ?? state.email;
    final resolvedToken = token ?? state.verificationToken ?? '';
    if (resolvedEmail.isEmpty || resolvedToken.isEmpty) return false;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await ref.read(appGatewayProvider).resetPassword(
            email: resolvedEmail,
            token: resolvedToken,
            newPassword: newPassword,
          );
      state = const AuthFlowState();
      return true;
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error);
      return false;
    }
  }

  void clear() => state = const AuthFlowState();

  Future<bool> _challenge({
    required AuthFlowKind kind,
    required String email,
    required Future<VerificationChallenge> Function() request,
  }) async {
    state = AuthFlowState(kind: kind, email: email, isLoading: true);
    try {
      final challenge = await request();
      state = AuthFlowState(
        kind: kind,
        email: email,
        message: challenge.message,
        expiresAt: DateTime.now().add(
          Duration(seconds: challenge.expiresInSeconds),
        ),
      );
      return true;
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error);
      return false;
    }
  }
}
