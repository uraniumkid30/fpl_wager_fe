import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpl_wager/core/network/providers.dart';
import 'package:fpl_wager/features/withdrawals/domain/withdrawal_models.dart';

/// The payment provider's list of banks. It is the same for everyone and
/// changes rarely, so it is fetched once and kept for the session.
final banksProvider = FutureProvider<List<Bank>>(
  (ref) => ref.watch(appGatewayProvider).banks(),
);

/// The signed-in user's bank account, or null when they have not added one.
final bankAccountProvider = FutureProvider.autoDispose<BankAccount?>(
  (ref) => ref.watch(appGatewayProvider).bankAccount(),
);

/// The user's withdrawal requests and the minimum amount.
final withdrawalsProvider = FutureProvider.autoDispose<WithdrawalOverview>(
  (ref) => ref.watch(appGatewayProvider).withdrawals(),
);
