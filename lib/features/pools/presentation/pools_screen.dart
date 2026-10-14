import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fplboardman/app/theme/app_theme.dart';
import 'package:fplboardman/core/ui/app_header.dart';
import 'package:fplboardman/core/ui/app_notice.dart';
import 'package:fplboardman/core/ui/app_widgets.dart';
import 'package:fplboardman/features/dashboard/presentation/dashboard_controller.dart';
import 'package:fplboardman/features/fpl_team/presentation/team_requirement.dart';
import 'package:fplboardman/features/pools/domain/pool.dart';
import 'package:fplboardman/features/pools/presentation/pool_card.dart';
import 'package:fplboardman/features/pools/presentation/pools_controller.dart';
import 'package:fplboardman/features/wallet/presentation/insufficient_funds.dart';
import 'package:go_router/go_router.dart';

/// The Pools tab. "Active" shows, in this order: the user's custom pools
/// (with Create / Join), the gameweek being played, the next gameweek's
/// pools that are open for entries, and head to head. "Past" shows the
/// pools the user played that have been settled, with their result, and
/// leads to their gameweek history.
class PoolsScreen extends ConsumerStatefulWidget {
  const PoolsScreen({super.key});

  @override
  ConsumerState<PoolsScreen> createState() => _PoolsScreenState();
}

enum _PoolsTab { active, past }

class _PoolsScreenState extends ConsumerState<PoolsScreen> {
  _PoolsTab _tab = _PoolsTab.active;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: const AppHeader(title: 'Gameweek pools'),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                4,
                AppSpacing.md,
                10,
              ),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<_PoolsTab>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: _PoolsTab.active,
                      icon: Icon(Icons.sports_soccer_rounded),
                      label: Text('Active'),
                    ),
                    ButtonSegment(
                      value: _PoolsTab.past,
                      icon: Icon(Icons.history_rounded),
                      label: Text('Past'),
                    ),
                  ],
                  selected: {_tab},
                  onSelectionChanged: (selection) =>
                      setState(() => _tab = selection.first),
                ),
              ),
            ),
            Expanded(
              child: _tab == _PoolsTab.active
                  ? _ActivePools(
                      onCreate: () => _createPool(context, ref),
                      onJoinWithCode: () => _joinWithCode(context),
                      onJoin: (pool) => _joinPool(context, ref, pool),
                      onShowPast: () =>
                          setState(() => _tab = _PoolsTab.past),
                    )
                  : const _PastPools(),
            ),
          ],
        ),
      );

  Future<void> _createPool(BuildContext context, WidgetRef ref) async {
    // The form closes with the new pool's id.
    final createdId = await openTeamProtectedRoute<String>(
      context,
      ref,
      action: TeamProtectedAction.pool,
      route: '/pools/create',
    );
    if (createdId == null) return;
    ref.invalidate(poolsProvider);
    // Straight to the new pool, where its invite link is waiting to be
    // shared.
    if (context.mounted) context.push('/pools/$createdId');
  }

  Future<void> _joinWithCode(BuildContext context) async {
    final code = await showDialog<String>(
      context: context,
      builder: (_) => const _JoinWithCodeDialog(),
    );
    if (code == null || !context.mounted) return;
    context.push('/join/$code');
  }

  Future<void> _joinPool(
    BuildContext context,
    WidgetRef ref,
    Pool pool,
  ) async {
    final hasTeam = await requireLinkedFplTeam(
      context,
      ref,
      action: TeamProtectedAction.pool,
    );
    if (!hasTeam || !context.mounted) return;

    final joined = await ref.read(poolActionProvider.notifier).join(pool.id);
    if (!context.mounted) return;
    if (joined == null) {
      final error = ref.read(poolActionProvider).error;
      if (openTopUpIfInsufficientFunds(context, error)) return;
      AppNotice.error(context, error ?? 'The pool could not be joined.');
      return;
    }
    AppNotice.success(
      context,
      joined.isPending
          ? 'Your request to join ${joined.name} is awaiting approval.'
          : 'You joined ${joined.name}.',
    );
  }
}

/// What can still be joined or is being played.
class _ActivePools extends ConsumerWidget {
  const _ActivePools({
    required this.onCreate,
    required this.onJoinWithCode,
    required this.onJoin,
    required this.onShowPast,
  });

  final VoidCallback onCreate;
  final VoidCallback onJoinWithCode;
  final void Function(Pool pool) onJoin;
  final VoidCallback onShowPast;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pools = ref.watch(poolsProvider);
    final action = ref.watch(poolActionProvider);
    final currentGameweek = ref.watch(dashboardProvider).value?.currentGameweek;
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(poolsProvider);
        await ref.read(poolsProvider.future);
      },
      child: AsyncContent(
        value: pools,
        onRetry: () => ref.invalidate(poolsProvider),
        data: (items) {
          final customPools = items.where((item) => !item.isAuto).toList()
            ..sort(_byGameweekThenJoined);
          // Auto pools by gameweek, earliest first: the gameweek being
          // played (or about to close) above the next one.
          final byGameweek = <int, List<Pool>>{};
          for (final pool in items.where((item) => item.isAuto)) {
            byGameweek.putIfAbsent(pool.gameweek, () => []).add(pool);
          }
          final gameweeks = byGameweek.keys.toList()..sort();
          // A manager may run one pool of their own per gameweek.
          final myPool = currentGameweek == null
              ? null
              : customPools
                  .where((p) => p.isMine && p.gameweek == currentGameweek)
                  .firstOrNull;
          var index = 0;
          Widget card(Pool pool) {
            // Only the first few cards ease in one after another.
            final step = index < 8 ? index : 8;
            index++;
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: FadeSlideIn(
                delay: Duration(milliseconds: step * 55),
                child: PoolCard(
                  pool: pool,
                  joining: action.isLoading,
                  onJoin: () => onJoin(pool),
                ),
              ),
            );
          }
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              6,
              AppSpacing.md,
              120,
            ),
            children: [
              _SectionTitle(
                title: 'Custom pools',
                subtitle: 'Private pools: yours, and the ones you were invited to',
                count: customPools.length,
              ),
              const SizedBox(height: 12),
              _CustomPoolActions(
                onCreate: myPool == null ? onCreate : null,
                onJoin: onJoinWithCode,
                note: myPool == null
                    ? null
                    : 'You can run one pool of your own per gameweek. To '
                        'start another for Gameweek ${myPool.gameweek}, '
                        'delete ${myPool.name} first.',
              ),
              const SizedBox(height: 14),
              ...customPools.map(card),
              const SizedBox(height: 14),
              if (gameweeks.isEmpty) ...[
                const _SectionTitle(
                  title: 'Auto pools',
                  subtitle: 'Open to every manager',
                  count: 0,
                ),
                const SizedBox(height: 12),
                const _AutoPoolsSyncing(),
              ],
              for (final gameweek in gameweeks) ...[
                _GameweekTitle(
                  gameweek: gameweek,
                  pools: byGameweek[gameweek]!,
                ),
                const SizedBox(height: 12),
                ...(byGameweek[gameweek]!..sort(_joinedThenStake)).map(card),
                const SizedBox(height: 14),
              ],
              _HeadToHeadCard(onTap: () => context.push('/challenges')),
              const SizedBox(height: 18),
              Center(
                child: TextButton.icon(
                  onPressed: onShowPast,
                  icon: const Icon(Icons.history_rounded),
                  label: const Text('Finished pools and results'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

int _byGameweekThenJoined(Pool a, Pool b) {
  final byGameweek = a.gameweek.compareTo(b.gameweek);
  return byGameweek != 0 ? byGameweek : _joinedThenStake(a, b);
}

/// Pools the user is in first, then by stake.
int _joinedThenStake(Pool a, Pool b) {
  final aIn = a.hasJoined || a.isPending ? 0 : 1;
  final bIn = b.hasJoined || b.isPending ? 0 : 1;
  if (aIn != bIn) return aIn.compareTo(bIn);
  return a.stakeCents.compareTo(b.stakeCents);
}

/// "Gameweek 6 · In play" over the pools being played, "Gameweek 7 · Open
/// for entries" over the ones that can still be joined.
class _GameweekTitle extends StatelessWidget {
  const _GameweekTitle({required this.gameweek, required this.pools});
  final int gameweek;
  final List<Pool> pools;

  @override
  Widget build(BuildContext context) {
    final live = pools.any((pool) => pool.isLive);
    final joined = pools.where((pool) => pool.hasJoined).length;
    final subtitle = live
        ? joined > 0
            ? 'Entries closed · you are in $joined. Tap one for live standings.'
            : 'Entries closed. Tap a pool for live standings.'
        : 'Open for entries · ${_stakesLabel(pools)}';
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      'Gameweek $gameweek',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusPill(
                    live ? 'In play' : 'Open',
                    color: live ? Colors.orange : AppColors.lime,
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
        StatusPill('${pools.length}'),
      ],
    );
  }
}

/// The settled pools the user played, newest gameweek first, and the way
/// into their gameweek history.
class _PastPools extends ConsumerWidget {
  const _PastPools();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final past = ref.watch(pastPoolsProvider);
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(pastPoolsProvider);
        await ref.read(pastPoolsProvider.future);
      },
      child: AsyncContent(
        value: past,
        onRetry: () => ref.invalidate(pastPoolsProvider),
        data: (items) {
          final byGameweek = <int, List<Pool>>{};
          for (final pool in items) {
            byGameweek.putIfAbsent(pool.gameweek, () => []).add(pool);
          }
          final gameweeks = byGameweek.keys.toList()
            ..sort((a, b) => b.compareTo(a));
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              6,
              AppSpacing.md,
              120,
            ),
            children: [
              GradientPanel(
                onTap: () => context.push('/gameweeks'),
                colors: const [Color(0xFF0A4437), Color(0xFF261A47)],
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 24,
                      backgroundColor: Color(0x243EFF75),
                      child: Icon(Icons.leaderboard_rounded, color: AppColors.lime),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Gameweek history',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                          const SizedBox(height: 3),
                          const Text(
                            'Where you finished each gameweek, and what you staked and won.',
                            style: TextStyle(color: Color(0xFFC9DED7)),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_rounded, color: Colors.white),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              if (items.isEmpty)
                const EmptyState(
                  icon: Icons.emoji_events_outlined,
                  title: 'No finished pools yet',
                  message: 'Pools you play in appear here once they are settled, with your result.',
                ),
              for (final gameweek in gameweeks) ...[
                _PastGameweekHeader(
                  gameweek: gameweek,
                  pools: byGameweek[gameweek]!,
                ),
                const SizedBox(height: 10),
                ...byGameweek[gameweek]!.map(
                  (pool) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: PastPoolTile(pool: pool),
                  ),
                ),
                const SizedBox(height: 14),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _PastGameweekHeader extends StatelessWidget {
  const _PastGameweekHeader({required this.gameweek, required this.pools});
  final int gameweek;
  final List<Pool> pools;

  @override
  Widget build(BuildContext context) {
    final won = pools.fold<int>(0, (sum, p) => sum + (p.myPayoutCents ?? 0));
    final staked = pools.fold<int>(0, (sum, p) => sum + p.stakeCents);
    final net = won - staked;
    return Row(
      children: [
        Expanded(
          child: Text(
            'Gameweek $gameweek',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        Text(
          '${net >= 0 ? '+' : '−'}${money(net.abs())}',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w900,
                color: net > 0
                    ? AppColors.lime
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

/// One finished pool: where the user finished and what they won. Opens the
/// pool's final standings.
class PastPoolTile extends StatelessWidget {
  const PastPoolTile({required this.pool, super.key});
  final Pool pool;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final rank = pool.myRank ?? 0;
    final won = pool.myPayoutCents ?? 0;
    final place = rank > 0
        ? '$rank${ordinalSuffix(rank)} of ${pool.memberCount}'
        : '${pool.memberCount} managers';
    final points = pool.myPoints == null ? '' : ' · ${pool.myPoints} pts';
    return GradientPanel(
      onTap: () => context.push('/pools/${pool.id}'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: (won > 0 ? AppColors.lime : muted).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: won > 0
                ? const Icon(Icons.emoji_events_rounded, color: AppColors.lime)
                : Text(
                    rank > 0 ? '$rank${ordinalSuffix(rank)}' : '—',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: muted,
                        ),
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pool.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$place$points · stake ${money(pool.stakeCents)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                won > 0 ? '+${money(won)}' : 'No prize',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: won > 0 ? AppColors.lime : muted,
                    ),
              ),
              const SizedBox(height: 2),
              Icon(Icons.chevron_right_rounded, size: 18, color: muted),
            ],
          ),
        ],
      ),
    );
  }
}

/// "₦1,000 · ₦2,000 · ₦5,000" from the auto pools actually on offer.
String _stakesLabel(List<Pool> autoPools) {
  final stakes = autoPools.map((pool) => pool.stakeCents).toSet().toList()
    ..sort();
  if (stakes.isEmpty) return 'Open to every manager';
  return stakes.map(money).join(' · ');
}

/// Pulls the invite code out of whatever was typed or pasted: the code on
/// its own, or a whole invite link (or invite message) that contains it.
/// Returns null when there is no usable code.
String? inviteCodeFrom(String input) {
  var text = input.trim();
  if (text.isEmpty) return null;
  final link = RegExp(r'join/([A-Za-z0-9-]+)').firstMatch(text);
  if (link != null) text = link.group(1)!;
  final code = text.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');
  return RegExp(r'^[A-Z0-9]{6,16}$').hasMatch(code) ? code : null;
}

/// Asks for an invite code (or a pasted link) and closes with the code.
class _JoinWithCodeDialog extends StatefulWidget {
  const _JoinWithCodeDialog();

  @override
  State<_JoinWithCodeDialog> createState() => _JoinWithCodeDialogState();
}

class _JoinWithCodeDialogState extends State<_JoinWithCodeDialog> {
  final _input = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _submit() {
    final code = inviteCodeFrom(_input.text);
    if (code == null) {
      setState(
        () => _error = 'That does not look like an invite code or link.',
      );
      return;
    }
    Navigator.of(context).pop(code);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Join a private pool'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter the code the pool\'s creator gave you, or paste their '
                'invite link.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _input,
                autofocus: true,
                autocorrect: false,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: 'Invite code or link',
                  errorText: _error,
                  prefixIcon: const Icon(Icons.vpn_key_outlined),
                ),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                onSubmitted: (_) => _submit(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(onPressed: _submit, child: const Text('Find pool')),
        ],
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle, required this.count});

  final String title;
  final String subtitle;
  final int count;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 2),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          StatusPill('$count'),
        ],
      );
}

class _AutoPoolsSyncing extends StatelessWidget {
  const _AutoPoolsSyncing();

  @override
  Widget build(BuildContext context) => const GradientPanel(
        child: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Expanded(child: Text('The standard auto pools are being prepared. Pull down to refresh.')),
          ],
        ),
      );
}

class _HeadToHeadCard extends StatelessWidget {
  const _HeadToHeadCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GradientPanel(
        onTap: onTap,
        colors: const [Color(0xFF0A4437), Color(0xFF261A47)],
        child: Row(
          children: [
            const CircleAvatar(radius: 26, backgroundColor: Color(0x243EFF75), child: Icon(Icons.compare_arrows_rounded, color: AppColors.lime)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Head-to-head pool', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  const Text('Challenge another verified FPL manager.', style: TextStyle(color: Color(0xFFC9DED7))),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_rounded, color: Colors.white),
          ],
        ),
      );
}

/// The two ways into a custom pool: start one, or join one with its code.
class _CustomPoolActions extends StatelessWidget {
  const _CustomPoolActions({
    required this.onCreate,
    required this.onJoin,
    this.note,
  });

  /// Null when the user already has a pool this gameweek.
  final VoidCallback? onCreate;
  final VoidCallback onJoin;

  /// Why creating is not possible right now, if it is not.
  final String? note;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    const padding = EdgeInsets.symmetric(vertical: 14);
    return GradientPanel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onCreate,
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  label: const Padding(
                    padding: padding,
                    child: FitText('Create new pool'),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onJoin,
                  icon: const Icon(Icons.vpn_key_outlined),
                  label: const Padding(
                    padding: padding,
                    child: FitText('Join pool'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            note ??
                'Create a pool and share its link, or join a friend\'s pool '
                    'with the code or link they sent you.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted),
          ),
        ],
      ),
    );
  }
}
