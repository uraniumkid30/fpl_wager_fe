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

  /// Where the payment provider sends the customer when checkout finishes.
  ///
  /// On a phone the checkout runs in an in-app browser that watches for this
  /// address and closes itself, so it only has to be an address we own: the
  /// API's own return page. On the web the provider redirects the whole tab,
  /// so it is the app's payment confirmation route.
  ///
  /// `--dart-define=PAYMENT_CALLBACK_URL=...` overrides it.
  static String get paymentCallbackUrl {
    if (_configuredPaymentCallbackUrl.isNotEmpty) {
      return _configuredPaymentCallbackUrl;
    }
    if (kIsWeb) return '${Uri.base.origin}/#/payments/callback';
    return '${apiBaseUrl.replaceFirst(RegExp(r'/+$'), '')}/v1/payments/callback';
  }

  /// Where the provider sends the customer when they press cancel on the
  /// checkout page (Paystack only).
  ///
  /// On a phone it is the callback address marked `status=cancelled`, which
  /// the in-app browser recognises. On the web it is the top-up screen.
  static String get paymentCancelUrl {
    if (kIsWeb) return '${Uri.base.origin}/#/wallet/top-up';
    final callback = Uri.parse(paymentCallbackUrl);
    return callback.replace(
      queryParameters: {...callback.queryParameters, 'status': 'cancelled'},
    ).toString();
  }
}
