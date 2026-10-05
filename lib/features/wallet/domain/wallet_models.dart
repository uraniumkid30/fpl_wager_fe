import 'package:fpl_wager/features/withdrawals/domain/withdrawal_models.dart';

class WalletSummary {
  const WalletSummary({
    required this.availableCents,
    required this.lockedCents,
    this.ledger = const [],
  });

  factory WalletSummary.fromJson(Map<String, Object?> json) => WalletSummary(
        availableCents: (json['available_cents']! as num).toInt(),
        lockedCents: (json['locked_cents']! as num).toInt(),
        ledger: (json['ledger'] as List<Object?>? ?? const [])
            .map((item) => LedgerEntry.fromJson(item! as Map<String, Object?>))
            .toList(),
      );

  final int availableCents;
  final int lockedCents;
  final List<LedgerEntry> ledger;
}

class LedgerEntry {
  const LedgerEntry({
    required this.id,
    required this.kind,
    required this.description,
    required this.amountCents,
    required this.createdAt,
    this.meta = const {},
  });

  factory LedgerEntry.fromJson(Map<String, Object?> json) => LedgerEntry(
        id: json['id']! as String,
        kind: json['kind']! as String,
        description: json['description']! as String,
        amountCents: (json['amount_cents']! as num).toInt(),
        createdAt: DateTime.parse(json['created_at']! as String),
        meta: json['meta'] is Map<Object?, Object?>
            ? Map<String, Object?>.from(json['meta']! as Map<Object?, Object?>)
            : const {},
      );

  final String id;
  final String kind;
  final String description;
  final int amountCents;
  final DateTime createdAt;

  /// Extra detail the server recorded with the entry. A withdrawal (and its
  /// refund, if any) carries the bank account the money was sent to.
  final Map<String, Object?> meta;

  /// The bank account a withdrawal entry was paid to; null for other entries.
  BankAccount? get bank => BankAccount.maybeFrom(meta['bank_details']);

  /// Why a withdrawal was refunded, when the server recorded a reason.
  String get reason => meta['reason'] as String? ?? '';
}

