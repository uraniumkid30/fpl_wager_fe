import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fplboardman/core/network/providers.dart';
import 'package:fplboardman/features/auth/domain/web_link.dart';

/// The browsers signed in to the account through a QR code.
final webLinksProvider = FutureProvider.autoDispose<List<WebLink>>(
  (ref) => ref.watch(appGatewayProvider).webLinks(),
);
