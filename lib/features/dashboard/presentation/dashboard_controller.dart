import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fplboardman/core/network/providers.dart';
import 'package:fplboardman/features/dashboard/domain/dashboard.dart';

final dashboardProvider = FutureProvider.autoDispose<Dashboard>(
  (ref) => ref.watch(appGatewayProvider).dashboard(),
);

