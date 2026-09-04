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
  });

  factory LedgerEntry.fromJson(Map<String, Object?> json) => LedgerEntry(
        id: json['id']! as String,
        kind: json['kind']! as String,
        description: json['description']! as String,
        amountCents: (json['amount_cents']! as num).toInt(),
        createdAt: DateTime.parse(json['created_at']! as String),
      );

  final String id;
  final String kind;
  final String description;
  final int amountCents;
  final DateTime createdAt;
}

