/// How a pool a user creates pays out, and the limits on it.
///
/// This mirrors the server (internal/store/payout_rules.go). The server
/// checks everything again; the app works the same things out so the form
/// can say what is wrong as it is filled in, before anything is sent.
library;

/// Shares are in basis points: 10000 is the whole prize pool, 5000 is 50%.
const shareBasisPoints = 10000;

enum PayoutMode {
  winnerTakesAll('winner_takes_all', 'Winner takes all'),
  split('split', 'Split');

  const PayoutMode(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static PayoutMode fromWireValue(String? value) =>
      value == 'split' ? PayoutMode.split : PayoutMode.winnerTakesAll;
}

/// At most [winners] paid places for every [entrants] managers, and never
/// more than [maxWinners]. Administrators set it; 3 for every 5, at most 50.
class WinnerRule {
  const WinnerRule({this.winners = 3, this.entrants = 5, this.maxWinners = 50});

  factory WinnerRule.fromJson(Map<String, Object?>? json) {
    if (json == null) return const WinnerRule();
    final winners = (json['winners'] as num?)?.toInt() ?? 3;
    final entrants = (json['entrants'] as num?)?.toInt() ?? 5;
    final maxWinners = (json['max_winners'] as num?)?.toInt() ?? 50;
    if (entrants < 1 || winners < 1 || maxWinners < 1) return const WinnerRule();
    return WinnerRule(winners: winners, entrants: entrants, maxWinners: maxWinners);
  }

  final int winners;
  final int entrants;
  final int maxWinners;

  /// How many places can be paid with this many managers in the pool.
  int cap(int managers) {
    if (managers <= 0) return 0;
    var places = managers * winners ~/ entrants;
    if (places > maxWinners) places = maxWinners;
    if (places > managers) places = managers;
    return places < 1 ? 1 : places;
  }

  /// The fewest managers that let [places] places all be paid.
  int managersNeeded(int places) {
    if (places <= 1) return 2;
    final needed = (places * entrants + winners - 1) ~/ winners;
    return needed < places ? places : needed;
  }

  /// "3 winners for every 5 managers".
  String get description =>
      '$winners ${winners == 1 ? 'winner' : 'winners'} for every $entrants '
      '${entrants == 1 ? 'manager' : 'managers'}';
}

/// The suggested shares for [winners] places: 60/40, 50/30/20, 40/30/20/10,
/// 35/25/20/12/8, and beyond that a straight line down.
List<int> defaultShares(int winners) {
  switch (winners) {
    case <= 0:
      return const [];
    case 1:
      return const [10000];
    case 2:
      return const [6000, 4000];
    case 3:
      return const [5000, 3000, 2000];
    case 4:
      return const [4000, 3000, 2000, 1000];
    case 5:
      return const [3500, 2500, 2000, 1200, 800];
  }
  final total = winners * (winners + 1) ~/ 2;
  final shares = [
    for (var index = 0; index < winners; index++)
      shareBasisPoints * (winners - index) ~/ total,
  ];
  shares[0] += shareBasisPoints - shares.fold(0, (sum, share) => sum + share);
  return shares;
}

/// What is wrong with a set of shares, or null if they can be used.
String? sharesProblem(List<int> shares) {
  final total = shares.fold(0, (sum, share) => sum + share);
  for (var index = 0; index < shares.length; index++) {
    if (shares[index] < 1) {
      return '${placeLabel(index + 1)} place must get something.';
    }
    if (index > 0 && shares[index] > shares[index - 1]) {
      return '${placeLabel(index + 1)} place can\'t get more than '
          '${placeLabel(index)}.';
    }
  }
  if (total != shareBasisPoints) {
    final difference = (shareBasisPoints - total).abs();
    return total < shareBasisPoints
        ? 'The shares add up to ${percentLabel(total)}. '
            '${percentLabel(difference)} still to give out.'
        : 'The shares add up to ${percentLabel(total)}. '
            'Take off ${percentLabel(difference)}.';
  }
  return null;
}

/// 5000 -> "50%", 3333 -> "33.33%".
String percentLabel(int basisPoints) {
  final whole = basisPoints ~/ 100;
  final rest = basisPoints % 100;
  if (rest == 0) return '$whole%';
  return '$whole.${rest.toString().padLeft(2, '0').replaceFirst(RegExp(r'0$'), '')}%';
}

/// 5000 -> "50", 3333 -> "33.33": what goes in a percentage field.
String percentInput(int basisPoints) =>
    percentLabel(basisPoints).replaceAll('%', '');

/// "50" or "33.33" -> basis points; null if it is not a percentage with at
/// most two decimal places.
int? parsePercent(String text) {
  final match =
      RegExp(r'^\s*(\d{1,3})(?:[.,](\d{1,2}))?\s*%?\s*$').firstMatch(text);
  if (match == null) return null;
  final whole = int.parse(match.group(1)!);
  final fraction = (match.group(2) ?? '').padRight(2, '0');
  return whole * 100 + (fraction.isEmpty ? 0 : int.parse(fraction));
}

String placeLabel(int place) {
  final lastTwo = place % 100;
  if (lastTwo >= 11 && lastTwo <= 13) return '${place}th';
  return switch (place % 10) {
    1 => '${place}st',
    2 => '${place}nd',
    3 => '${place}rd',
    _ => '${place}th',
  };
}

/// How one pool pays out, as the server stored it.
class PayoutRule {
  const PayoutRule({
    required this.mode,
    this.winners = 1,
    this.shares = const [],
    this.limit = const WinnerRule(),
  });

  factory PayoutRule.fromJson(Map<String, Object?> json) {
    final mode = PayoutMode.fromWireValue(json['mode'] as String?);
    final winners = (json['winners'] as num?)?.toInt() ?? 1;
    final shares = (json['shares'] as List<Object?>? ?? const [])
        .map((share) => (share as num? ?? 0).toInt())
        .toList();
    return PayoutRule(
      mode: mode,
      winners: mode == PayoutMode.split ? winners : 1,
      shares: shares.length == winners ? shares : defaultShares(winners),
      limit: WinnerRule.fromJson(json['limit'] as Map<String, Object?>?),
    );
  }

  final PayoutMode mode;
  final int winners;
  final List<int> shares;
  final WinnerRule limit;

  /// "Winner takes all" or "Top 3 share 50% · 30% · 20%".
  String get summary => mode == PayoutMode.winnerTakesAll
      ? 'Winner takes all'
      : 'Top $winners share ${shares.map(percentLabel).join(' · ')}';
}

/// What a creator chose on the form. [shares] is null when they kept the
/// suggested shares; the server then uses the same suggestion.
class PayoutChoice {
  const PayoutChoice({
    this.mode = PayoutMode.winnerTakesAll,
    this.winners = 3,
    this.shares,
  });

  final PayoutMode mode;
  final int winners;
  final List<int>? shares;

  List<int> get effectiveShares =>
      mode == PayoutMode.split ? (shares ?? defaultShares(winners)) : const [10000];

  Map<String, Object?> toJson() => {
        'payout_mode': mode.wireValue,
        if (mode == PayoutMode.split) 'winners': winners,
        if (mode == PayoutMode.split && shares != null) 'shares': shares,
      };
}
