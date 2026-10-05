/// One bank in the payment provider's list.
class Bank {
  const Bank({required this.name, required this.code});

  factory Bank.fromJson(Map<String, Object?> json) => Bank(
        name: json['name'] as String? ?? '',
        code: json['code'] as String? ?? '',
      );

  final String name;
  final String code;
}

/// The bank account a user withdraws to. A user has at most one.
///
/// [accountName] is never typed by the user: it is the name the payment
/// provider returned for the account number.
class BankAccount {
  const BankAccount({
    required this.bankCode,
    required this.bankName,
    required this.accountNumber,
    required this.accountName,
    this.provider = '',
  });

  factory BankAccount.fromJson(Map<String, Object?> json) => BankAccount(
        provider: json['provider'] as String? ?? '',
        bankCode: json['bank_code'] as String? ?? '',
        bankName: json['bank_name'] as String? ?? '',
        accountNumber: json['account_number'] as String? ?? '',
        accountName: json['account_name'] as String? ?? '',
      );

  /// Reads a bank account out of a JSON value that may be missing or not an
  /// object at all (a ledger entry's `meta.bank_details`, for instance).
  static BankAccount? maybeFrom(Object? value) {
    if (value is! Map<Object?, Object?>) return null;
    final account = BankAccount.fromJson(Map<String, Object?>.from(value));
    return account.accountNumber.isEmpty ? null : account;
  }

  final String provider;
  final String bankCode;
  final String bankName;
  final String accountNumber;
  final String accountName;

  /// The account number with all but the last four digits hidden.
  String get maskedNumber => accountNumber.length <= 4
      ? accountNumber
      : '••••${accountNumber.substring(accountNumber.length - 4)}';

  /// "Access Bank · ••••6789"
  String get summary => '$bankName · $maskedNumber';
}

/// A request to move money from the wallet to the user's bank account.
///
/// pending_approval → approved or rejected → successful, failed or reversed.
/// The amount leaves the wallet when the request is made and is returned if
/// the request is rejected, fails or is reversed.
class Withdrawal {
  const Withdrawal({
    required this.id,
    required this.reference,
    required this.amountCents,
    required this.status,
    required this.createdAt,
    this.bank,
    this.reason = '',
  });

  factory Withdrawal.fromJson(Map<String, Object?> json) => Withdrawal(
        id: json['id']! as String,
        reference: json['reference'] as String? ?? '',
        amountCents: (json['amount_cents']! as num).toInt(),
        status: json['status'] as String? ?? 'pending_approval',
        createdAt: DateTime.parse(json['created_at']! as String),
        bank: BankAccount.maybeFrom(json['bank_details']),
        reason: json['reason'] as String? ?? '',
      );

  final String id;
  final String reference;
  final int amountCents;
  final String status;
  final DateTime createdAt;

  /// The account this request is paid to, as it was when the request was
  /// made. Changing the saved bank account later does not change it.
  final BankAccount? bank;

  /// Why the request was rejected or the transfer failed, when one was given.
  final String reason;

  /// True while the money is still on its way: waiting for an administrator,
  /// or approved and being transferred.
  bool get isOpen => status == 'pending_approval' || status == 'approved';

  bool get isPaid => status == 'successful';

  /// True when the money came back to the wallet.
  bool get wasRefunded =>
      status == 'rejected' || status == 'failed' || status == 'reversed';

  String get statusLabel => switch (status) {
        'pending_approval' => 'Awaiting approval',
        'approved' => 'Processing',
        'successful' => 'Paid',
        'rejected' => 'Rejected',
        'failed' => 'Failed',
        'reversed' => 'Reversed',
        _ => status.replaceAll('_', ' '),
      };

  /// One line telling the user what the status means for their money.
  String get statusNote => switch (status) {
        'pending_approval' =>
          'An administrator reviews every withdrawal before it is paid.',
        'approved' => 'Approved. Your bank transfer is on its way.',
        'successful' => 'Paid to your bank account.',
        'rejected' => 'Not approved. The money is back in your wallet.',
        'failed' => 'The transfer failed. The money is back in your wallet.',
        'reversed' =>
          'Your bank returned the transfer. The money is back in your wallet.',
        _ => '',
      };
}

/// The user's withdrawals plus the smallest amount they may ask for.
class WithdrawalOverview {
  const WithdrawalOverview({required this.items, required this.minimumCents});

  factory WithdrawalOverview.fromJson(Map<String, Object?> json) =>
      WithdrawalOverview(
        items: (json['items'] as List<Object?>? ?? const [])
            .map((item) => Withdrawal.fromJson(
                  Map<String, Object?>.from(item! as Map<Object?, Object?>),
                ))
            .toList(),
        minimumCents: (json['minimum_cents'] as num?)?.toInt() ?? 100000,
      );

  final List<Withdrawal> items;
  final int minimumCents;
}

/// Turns what a person types for an amount of naira ("5000", "5,000",
/// "5000.50") into kobo. Returns null when it is not a positive amount with
/// at most two decimal places.
int? nairaToCents(String input) {
  final text = input.replaceAll(',', '').replaceAll('₦', '').trim();
  final match = RegExp(r'^(\d{1,9})(?:\.(\d{1,2}))?$').firstMatch(text);
  if (match == null) return null;
  final whole = int.parse(match.group(1)!);
  final fraction = (match.group(2) ?? '').padRight(2, '0');
  final cents = whole * 100 + int.parse(fraction);
  return cents > 0 ? cents : null;
}
