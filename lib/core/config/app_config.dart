class AppConfig {
  const AppConfig._();

  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8080',
  );

  static const useDemoData = bool.fromEnvironment(
    'USE_DEMO_DATA',
    defaultValue: false,
  );

  static const enableDevCredit = useDemoData || bool.fromEnvironment(
    'ENABLE_DEV_CREDIT',
    defaultValue: false,
  );

  static const paymentCallbackUrl = String.fromEnvironment(
    'PAYMENT_CALLBACK_URL',
    defaultValue: 'fplwager://payments/callback',
  );
}
