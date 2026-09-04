import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fpl_wager/core/config/app_config.dart';
import 'package:fpl_wager/core/network/api_client.dart';
import 'package:fpl_wager/core/network/app_gateway.dart';
import 'package:fpl_wager/core/network/demo_gateway.dart';
import 'package:fpl_wager/core/network/remote_gateway.dart';
import 'package:fpl_wager/core/storage/session_store.dart';

final secureStorageProvider = Provider<FlutterSecureStorage>(
  (ref) => const FlutterSecureStorage(
    aOptions: AndroidOptions(),
  ),
);

final sessionStoreProvider = Provider<SessionStore>(
  (ref) => SessionStore(ref.watch(secureStorageProvider)),
);

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(AppConfig.apiBaseUrl),
);

final demoGatewayProvider = Provider<DemoGateway>((ref) => DemoGateway());

final appGatewayProvider = Provider<AppGateway>((ref) {
  if (AppConfig.useDemoData) return ref.watch(demoGatewayProvider);
  return RemoteGateway(
    ref.watch(apiClientProvider),
    ref.watch(sessionStoreProvider),
  );
});
