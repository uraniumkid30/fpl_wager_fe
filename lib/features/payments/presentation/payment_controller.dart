import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpl_wager/core/config/app_config.dart';
import 'package:fpl_wager/core/network/providers.dart';
import 'package:fpl_wager/features/dashboard/presentation/dashboard_controller.dart';
import 'package:fpl_wager/features/payments/domain/payment.dart';
import 'package:fpl_wager/features/wallet/presentation/wallet_controller.dart';

class TopUpDraft {
  const TopUpDraft({this.amountCents = 100000, this.provider = 'paystack'});
  final int amountCents;
  final String provider;

  TopUpDraft copyWith({int? amountCents, String? provider}) => TopUpDraft(
        amountCents: amountCents ?? this.amountCents,
        provider: provider ?? this.provider,
      );
}

final topUpDraftProvider = NotifierProvider<TopUpDraftController, TopUpDraft>(TopUpDraftController.new);

class TopUpDraftController extends Notifier<TopUpDraft> {
  @override
  TopUpDraft build() => const TopUpDraft();
  void selectAmount(int value) => state = state.copyWith(amountCents: value);
  void selectProvider(String value) => state = state.copyWith(provider: value);
}

final paymentActionProvider = AsyncNotifierProvider<PaymentActionController, Payment?>(PaymentActionController.new);

class PaymentActionController extends AsyncNotifier<Payment?> {
  @override
  Future<Payment?> build() async => null;

  Future<Payment?> initialize(TopUpDraft draft) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(appGatewayProvider).initializePayment(
            amountCents: draft.amountCents,
            provider: draft.provider,
            callbackUrl: AppConfig.paymentCallbackUrl,
          ),
    );
    return state.value;
  }
}

final paymentVerificationProvider = FutureProvider.autoDispose.family<Payment, String>((ref, reference) async {
  final payment = await ref.read(appGatewayProvider).verifyPayment(reference);
  if (payment.isSuccessful) {
    ref.invalidate(walletProvider);
    ref.invalidate(dashboardProvider);
  }
  return payment;
});
