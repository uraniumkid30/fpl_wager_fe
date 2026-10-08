import 'package:flutter/material.dart';
import 'package:fplboardman/app/theme/app_theme.dart';
import 'package:fplboardman/core/ui/app_widgets.dart';
import 'package:fplboardman/features/pools/domain/pool.dart';
import 'package:intl/intl.dart';

/// A pool's table: every manager with their position, points and, for the
/// positions that pay, the prize.
///
/// While the gameweek is being played the server rescores the pool every
/// couple of minutes and the page reloads it, so rows count up to their new
/// points and slide to their new positions. Before the first points nobody
/// has a position; once the pool is settled the table is final.
class PoolLeaderboard extends StatefulWidget {
  const PoolLeaderboard({required this.pool, super.key});

  final Pool pool;

  @override
  State<PoolLeaderboard> createState() => _PoolLeaderboardState();
}

class _PoolLeaderboardState extends State<PoolLeaderboard> {
  /// Rows shown before "Show all" is pressed.
  static const _collapsed = 10;
  static const _rowHeight = 64.0;

  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final pool = widget.pool;
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurfaceVariant;
    final all = pool.leaderboard;

    // The first rows of the table, and the reader's own row if it is further
    // down, so they can always see where they stand.
    final rows = _showAll || all.length <= _collapsed
        ? all
        : [
            ...all.take(_collapsed),
            ...all.skip(_collapsed).where((member) => member.isMe),
          ];
    final hidden = all.length - rows.length;
    // The server sends the top of a very large pool, not all of it.
    final beyond = pool.memberCount - all.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                pool.status == 'settled' ? 'Final standings' : 'Leaderboard',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            if (pool.isLive) ...[
              const SizedBox(width: 10),
              const _LiveBadge(),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(
          _caption(pool),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: muted),
        ),
        const SizedBox(height: 12),
        GradientPanel(
          padding: const EdgeInsets.all(8),
          child: all.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    pool.status == 'settled'
                        ? 'Nobody was in this pool.'
                        : 'Nobody is in yet. Be the first.',
                    style: TextStyle(color: muted),
                  ),
                )
              // Row heights are fixed so rows can slide past each other, so
              // very large system text is held to a size that still fits.
              : MediaQuery.withClampedTextScaling(
                  maxScaleFactor: 1.2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AnimatedContainer(
                        duration: AppMotion.standard,
                        curve: AppMotion.curve,
                        height: rows.length * _rowHeight,
                        child: Stack(
                          clipBehavior: Clip.hardEdge,
                          children: [
                            for (final (index, member) in rows.indexed)
                              AnimatedPositioned(
                                // Keyed by manager, so when positions change
                                // each row glides to its new place.
                                key: ValueKey(_rowKey(member, index)),
                                duration: const Duration(milliseconds: 520),
                                curve: Curves.easeInOutCubic,
                                top: index * _rowHeight,
                                left: 0,
                                right: 0,
                                height: _rowHeight,
                                child: _Row(
                                  member: member,
                                  ranked: pool.ranked,
                                  settled: pool.status == 'settled',
                                  last: index == rows.length - 1,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (hidden > 0 || (_showAll && all.length > _collapsed))
                        TextButton(
                          onPressed: () =>
                              setState(() => _showAll = !_showAll),
                          child: Text(
                            _showAll ? 'Show fewer' : 'Show all ${all.length}',
                          ),
                        ),
                      if (beyond > 0 && (_showAll || hidden == 0))
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                          child: Text(
                            'Showing the top of the table: ${all.length} of '
                            '${NumberFormat.decimalPattern().format(pool.memberCount)} managers.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: muted),
                          ),
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  /// What identifies a row. Older servers do not send the manager's id, in
  /// which case the name and place in the list have to do.
  static String _rowKey(PoolMember member, int index) =>
      member.userId.isNotEmpty ? member.userId : '${member.displayName}#$index';

  /// The line under the heading: what state the table is in.
  static String _caption(Pool pool) {
    if (pool.status == 'settled') {
      return 'The official result. Prizes have been paid.';
    }
    if (pool.status == 'cancelled') {
      return 'This pool was cancelled and every entry was refunded.';
    }
    if (pool.isLive) {
      final updated = pool.scoredAt;
      final when = updated == null
          ? ''
          : 'Updated ${DateFormat('HH:mm').format(updated.toLocal())} · ';
      return pool.ranked
          ? '${when}provisional until FPL confirms the scores.'
          : 'The gameweek has started. Positions appear with the first points.';
    }
    return 'Positions appear when the gameweek kicks off.';
  }
}

/// A small pulsing "LIVE" tag.
class _LiveBadge extends StatefulWidget {
  const _LiveBadge();

  @override
  State<_LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<_LiveBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(7, 4, 9, 4),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FadeTransition(
              opacity: Tween<double>(begin: 0.35, end: 1).animate(_pulse),
              child: Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: AppColors.danger,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(width: 5),
            const Text(
              'LIVE',
              style: TextStyle(
                color: AppColors.danger,
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
                height: 1.1,
              ),
            ),
          ],
        ),
      );
}

/// One manager: position, name, prize if any, and points.
class _Row extends StatelessWidget {
  const _Row({
    required this.member,
    required this.ranked,
    required this.settled,
    required this.last,
  });

  final PoolMember member;

  /// Whether positions mean anything yet.
  final bool ranked;
  final bool settled;

  /// The last row has no line under it.
  final bool last;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurfaceVariant;
    final prize = settled ? member.payoutCents : member.projectedCents;
    final String? note = prize > 0
        ? '${settled ? 'Won' : 'Winning'} ${money(prize)}'
        : member.isPending
            ? 'Waiting for approval'
            : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: member.isMe ? scheme.primary.withValues(alpha: 0.09) : null,
        // Only the reader's own row is a rounded, outlined tile; the others
        // are separated by a hairline.
        borderRadius: member.isMe ? BorderRadius.circular(16) : null,
        border: member.isMe
            ? Border.all(color: scheme.primary.withValues(alpha: 0.30))
            : last
                ? null
                : Border(
                    bottom: BorderSide(
                      color: scheme.onSurface.withValues(alpha: 0.07),
                    ),
                  ),
      ),
      child: Row(
        children: [
          _PositionBadge(rank: ranked ? member.rank : 0),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        member.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (member.isMe) ...[
                      const SizedBox(width: 7),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.primary.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'YOU',
                          style: TextStyle(
                            color: scheme.primary,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (note != null) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (prize > 0) ...[
                        Icon(
                          Icons.emoji_events_rounded,
                          size: 13,
                          color: scheme.primary,
                        ),
                        const SizedBox(width: 4),
                      ],
                      Flexible(
                        child: Text(
                          note,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: prize > 0 ? scheme.primary : muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Counts up (or down) to the new score when it changes.
          TweenAnimationBuilder<double>(
            tween: Tween<double>(end: member.points.toDouble()),
            duration: const Duration(milliseconds: 650),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${value.round()}',
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  TextSpan(
                    text: ' pts',
                    style: TextStyle(fontSize: 11, color: muted),
                  ),
                ],
              ),
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}

/// The position at the side of a row: "1st", "2nd", "3rd" ... The top three
/// are gold, silver and bronze. A dash stands in before there are positions.
class _PositionBadge extends StatelessWidget {
  const _PositionBadge({required this.rank});

  /// Zero when the manager has no position yet.
  final int rank;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (List<Color>? medal, Color ink) = switch (rank) {
      1 => (const [Color(0xFFFFE08A), Color(0xFFF2B21B)], const Color(0xFF3A2A00)),
      2 => (const [Color(0xFFF1F4F7), Color(0xFFB8C2CC)], const Color(0xFF1E2A33)),
      3 => (const [Color(0xFFF2C29B), Color(0xFFC97B45)], const Color(0xFF3A1D08)),
      _ => (null, scheme.onSurface),
    };
    return AnimatedContainer(
      duration: AppMotion.standard,
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: medal == null ? scheme.primary.withValues(alpha: 0.12) : null,
        gradient: medal == null
            ? null
            : LinearGradient(
                colors: medal,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: rank <= 0
          ? Text(
              '–',
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            )
          : FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '$rank',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      TextSpan(
                        text: ordinalSuffix(rank),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  style: TextStyle(color: ink, height: 1.1),
                ),
              ),
            ),
    );
  }
}
