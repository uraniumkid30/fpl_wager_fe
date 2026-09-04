import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpl_wager/core/network/providers.dart';
import 'package:fpl_wager/features/dashboard/domain/dashboard.dart';

final dashboardProvider = FutureProvider.autoDispose<Dashboard>(
  (ref) => ref.watch(appGatewayProvider).dashboard(),
);

