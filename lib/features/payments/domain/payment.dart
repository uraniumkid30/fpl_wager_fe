class Payment {
  const Payment({
    required this.id,
    required this.userId,
    required this.provider,
    required this.credentialMode,
    required this.reference,
    required this.amountCents,
    required this.currency,
    required this.status,
    this.checkoutUrl,
  });

  factory Payment.fromJson(Map<String, Object?> json) => Payment(
        id: json['id']! as String,
        userId: json['user_id']! as String,
        provider: json['provider']! as String,
        credentialMode: json['credential_mode']! as String,
        reference: json['reference']! as String,
        amountCents: (json['amount_cents']! as num).toInt(),
        currency: json['currency']! as String,
        status: json['status']! as String,
        checkoutUrl: json['checkout_url'] as String?,
      );

  final String id;
  final String userId;
  final String provider;
  final String credentialMode;
  final String reference;
  final int amountCents;
  final String currency;
  final String status;
  final String? checkoutUrl;

  bool get isSuccessful => status == 'succeeded';
  bool get isFinal => isSuccessful || status == 'failed' || status == 'cancelled';
}
