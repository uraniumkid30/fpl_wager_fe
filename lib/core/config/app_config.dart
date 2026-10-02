import 'package:flutter/foundation.dart';

class AppConfig {
  const AppConfig._();

  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://35.217.63.208',//http://127.0.0.1:8080
  );

  static const useDemoData = bool.fromEnvironment(
    'USE_DEMO_DATA',
    defaultValue: false,
  );

  static const enableDevCredit = useDemoData || bool.fromEnvironment(
    'ENABLE_DEV_CREDIT',
    defaultValue: false,
  );

  static const _configuredPaymentCallbackUrl = String.fromEnvironment(
    'PAYMENT_CALLBACK_URL',
    defaultValue: '',
  );

  /// Checkout return URL sent to the payment provider.
  ///
  /// Web defaults to the current origin and GoRouter's hash route. Production
  /// can override this with `--dart-define=PAYMENT_CALLBACK_URL=...`.
  static String get paymentCallbackUrl {
    if (_configuredPaymentCallbackUrl.isNotEmpty) {
      return _configuredPaymentCallbackUrl;
    }
    if (kIsWeb) return '${Uri.base.origin}/#/payments/callback';
    return 'fplwager:///payments/callback';
  }
}
