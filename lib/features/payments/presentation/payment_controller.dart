import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fplboardman/core/config/app_config.dart';
import 'package:fplboardman/core/network/providers.dart';
import 'package:fplboardman/features/dashboard/presentation/dashboard_controller.dart';
import 'package:fplboardman/features/payments/domain/payment.dart';
import 'package:fplboardman/features/wallet/presentation/wallet_controller.dart';

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
            cancelUrl: AppConfig.paymentCancelUrl,
          ),
    );
    return state.value;
  }
}

/// How many times, and how often, a payment that is still pending is checked
/// again before the screen stops waiting (about 25 seconds in all).
const _verificationAttempts = 9;
const _verificationInterval = Duration(seconds: 3);

/// Asks the server to confirm a payment with the provider and credit the
/// wallet.
///
/// Card payments are confirmed on the first check. A bank transfer or USSD
/// payment can take a little longer, so while the provider still reports the
/// payment as pending this keeps checking for a short while. If it is still
/// pending after that, nothing is lost: the provider's webhook credits the
/// wallet when the money arrives, whether or not the app is open.
final paymentVerificationProvider = FutureProvider.autoDispose.family<Payment, String>((ref, reference) async {
  var disposed = false;
  ref.onDispose(() => disposed = true);
  final gateway = ref.read(appGatewayProvider);

  var payment = await gateway.verifyPayment(reference);
  for (var attempt = 1;
      attempt < _verificationAttempts && !payment.isFinal && !disposed;
      attempt++) {
    await Future<void>.delayed(_verificationInterval);
    if (disposed) break;
    payment = await gateway.verifyPayment(reference);
  }

  if (payment.isSuccessful && !disposed) {
    ref.invalidate(walletProvider);
    ref.invalidate(dashboardProvider);
  }
  return payment;
});
