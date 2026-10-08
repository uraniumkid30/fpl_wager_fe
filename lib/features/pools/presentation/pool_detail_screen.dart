import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fplboardman/app/theme/app_theme.dart';
import 'package:fplboardman/core/config/app_config.dart';
import 'package:fplboardman/core/errors/app_exception.dart';
import 'package:fplboardman/core/network/providers.dart';
import 'package:fplboardman/core/realtime/realtime_sync.dart';
import 'package:fplboardman/core/ui/app_notice.dart';
import 'package:fplboardman/core/ui/app_widgets.dart';
import 'package:fplboardman/features/dashboard/presentation/dashboard_controller.dart';
import 'package:fplboardman/features/fpl_team/presentation/team_requirement.dart';
import 'package:fplboardman/features/pools/domain/pool.dart';
import 'package:fplboardman/features/pools/presentation/pool_leaderboard.dart';
import 'package:fplboardman/features/pools/presentation/pools_controller.dart';
import 'package:fplboardman/features/wallet/presentation/insufficient_funds.dart';
import 'package:fplboardman/features/wallet/presentation/wallet_controller.dart';
import 'package:go_router/go_router.dart';

/// A pool opened from the app's own lists, by its id.
class PoolDetailScreen extends ConsumerWidget {
  const PoolDetailScreen({required this.poolId, super.key});

  final String poolId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pool = ref.watch(poolProvider(poolId));
    final action = ref.watch(poolActionProvider);
    return Scaffold(
      appBar: AppBar(
        leading: _leadingFor(context),
        title: const Text('Pool details'),
      ),
      body: AsyncContent(
        value: pool,
        // The page reloads itself while the gameweek is live; one failed
        // reload should not replace the table with an error.
        keepDataOnError: true,
        onRetry: () => ref.invalidate(poolProvider(poolId)),
        data: (item) => _Body(
          item: item,
          busy: action.isLoading,
          onJoin: () => _join(context, ref, item),
          onChanged: () => ref.invalidate(poolProvider(poolId)),
        ),
      ),
    );
  }

  Future<void> _join(BuildContext context, WidgetRef ref, Pool item) async {
    final hasTeam = await requireLinkedFplTeam(
      context,
      ref,
      action: TeamProtectedAction.pool,
    );
    if (!hasTeam || !context.mounted) return;
    final joined = await ref.read(poolActionProvider.notifier).join(poolId);
    if (!context.mounted) return;
    if (joined == null) {
      _showActionError(context, ref, 'The pool could not be joined.');
      return;
    }
    ref.invalidate(poolProvider(poolId));
    AppNotice.success(context, 'You joined ${joined.name}.');
  }
}

/// A private pool opened from its invite link or code.
///
/// It shows the pool before the manager pays, and joining sends the code
/// along so the server lets them in.
class JoinPoolScreen extends ConsumerWidget {
  const JoinPoolScreen({required this.code, super.key});

  final String code;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pool = ref.watch(poolInviteProvider(code));
    final action = ref.watch(poolActionProvider);
    // An invite link opens this page on its own, with nothing underneath to
    // go back to. Back then leads to the pools list instead of leaving the
    // app.
    final standalone = !context.canPop();
    return PopScope(
      canPop: !standalone,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          context.go('/pools');
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: _leadingFor(context),
          title: const Text('Pool invite'),
        ),
        body: pool.when(
          // As above: a failed background reload keeps the page.
          skipError: true,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _InviteProblem(
            error: error,
            onRetry: () => ref.invalidate(poolInviteProvider(code)),
          ),
          data: (item) => _Body(
            item: item,
            busy: action.isLoading,
            invited: true,
            onJoin: () => _join(context, ref, item),
            onChanged: () => ref.invalidate(poolInviteProvider(code)),
          ),
        ),
      ),
    );
  }

  Future<void> _join(BuildContext context, WidgetRef ref, Pool item) async {
    final hasTeam = await requireLinkedFplTeam(
      context,
      ref,
      action: TeamProtectedAction.pool,
    );
    if (!hasTeam || !context.mounted) return;
    final joined =
        await ref.read(poolActionProvider.notifier).joinByInvite(code);
    if (!context.mounted) return;
    if (joined == null) {
      _showActionError(context, ref, 'The pool could not be joined.');
      return;
    }
    ref.invalidate(poolInviteProvider(code));
    AppNotice.success(context, 'You joined ${joined.name}. Good luck!');
  }
}

/// Shows why joining failed. A balance that is too low opens the
/// top-up page instead of an error.
void _showActionError(BuildContext context, WidgetRef ref, String fallback) {
  final error = ref.read(poolActionProvider).error;
  if (openTopUpIfInsufficientFunds(context, error)) return;
  AppNotice.error(context, error ?? fallback);
}

/// A close button for a page that was opened on its own (from a link) and so
/// has no page to go back to. Null leaves the normal back arrow in place.
Widget? _leadingFor(BuildContext context) => context.canPop()
    ? null
    : IconButton(
        tooltip: 'Close',
        icon: const Icon(Icons.close_rounded),
        onPressed: () => context.go('/pools'),
      );

void _closePage(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go('/pools');
  }
}

/// What to show when an invite link or code does not lead to a pool.
class _InviteProblem extends StatelessWidget {
  const _InviteProblem({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final code = error is AppException ? (error as AppException).code : null;
    final notFound = code == 'INVITE_NOT_FOUND' || code == 'NOT_FOUND';
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              notFound ? Icons.link_off_rounded : Icons.cloud_off_rounded,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              notFound ? 'This invite does not work' : 'We could not open the invite',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              notFound
                  ? 'The link or code may be mistyped, or the pool\'s creator '
                      'has replaced it or deleted the pool. Ask them for the '
                      'latest link.'
                  : error.toString(),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            if (!notFound) ...[
              FilledButton.tonal(
                onPressed: onRetry,
                child: const Text('Try again'),
              ),
              const SizedBox(height: 8),
            ],
            TextButton(
              onPressed: () => _closePage(context),
              child: const Text('Back to pools'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.item,
    required this.busy,
    required this.onJoin,
    required this.onChanged,
    this.invited = false,
  });

  final Pool item;
  final bool busy;
  final VoidCallback onJoin;

  /// Called after the creator changes the pool, so the page reloads it.
  final VoidCallback onChanged;

  /// True when the page was opened from an invite link or code.
  final bool invited;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final manage = item.manage;
    final live = item.status == 'draft' || item.status == 'open';
    final page = ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 8, AppSpacing.md, 48),
      children: [
        GradientPanel(
          colors: const [Color(0xFF0B4939), Color(0xFF2C174A)],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  StatusPill(
                    item.awaitingAdminApproval ? 'awaiting approval' : item.status,
                    color: item.awaitingAdminApproval ? Colors.orange : null,
                  ),
                  const Spacer(),
                  Text(
                    'GW${item.gameweek}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                item.name,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              if (item.isPrivate) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.lock_outline_rounded,
                      size: 15,
                      color: Color(0xFFC9DED7),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        item.isCreator
                            ? 'Private pool · created by you'
                            : item.creatorName.isEmpty
                                ? 'Private pool · invite only'
                                : 'Private pool · by ${item.creatorName}',
                        style: const TextStyle(color: Color(0xFFC9DED7)),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _HeroValue(
                      label: 'STAKE',
                      value: money(item.stakeCents),
                      color: AppColors.lime,
                    ),
                  ),
                  Expanded(
                    child: _HeroValue(
                      label: 'PRIZE POOL',
                      value: money(item.prizePoolCents),
                      color: const Color(0xFFE859FF),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'FPL deadline',
                style: TextStyle(color: Color(0xFFC9DED7)),
              ),
              const SizedBox(height: 4),
              DeadlineCountdown(item.deadline),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (invited && item.canJoin && !item.isCreator) ...[
          Text(
            item.creatorName.isEmpty
                ? 'You have been invited to this pool.'
                : '${item.creatorName} invited you to this pool.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: muted),
          ),
          const SizedBox(height: 10),
        ],
        if (item.canJoin)
          FilledButton(
            onPressed: busy ? null : onJoin,
            child: busy
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    item.hasLeft
                        ? 'Rejoin · ${money(item.stakeCents)}'
                        : 'Join · ${money(item.stakeCents)}',
                  ),
          )
        else if (item.isPending)
          const FilledButton(
            onPressed: null,
            child: Text('Pending manager approval'),
          )
        else if (item.hasJoined && item.status == 'open')
          // An entry is final: there is no way to leave from here.
          const FilledButton(
            onPressed: null,
            child: Text('You have joined this pool'),
          )
        else if (item.awaitingAdminApproval)
          FilledButton(
            onPressed: null,
            child: Text(
              item.isCreator
                  ? 'Waiting for FPLboardman to approve'
                  : 'Not open yet · awaiting approval',
            ),
          ),
        if (item.isCreator && manage != null && live) ...[
          const SizedBox(height: 22),
          _OwnerPanel(pool: item, manage: manage, onChanged: onChanged),
        ],
        if (item.rules.isNotEmpty) ...[
          const SizedBox(height: 22),
          Text('Pool rules', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          GradientPanel(child: Text(item.rules)),
        ],
        const SizedBox(height: 26),
        PoolLeaderboard(pool: item),
        if (item.status != 'cancelled') ...[
          const SizedBox(height: 26),
          Text('Prizes', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            _prizeSentence(item),
            style:
                Theme.of(context).textTheme.bodyMedium?.copyWith(color: muted),
          ),
          if (item.status != 'settled' && item.prizeSplit.isNotEmpty) ...[
            const SizedBox(height: 12),
            GradientPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PrizeLadder(prizes: item.prizeSplit),
                  if (item.status == 'open' || item.status == 'draft') ...[
                    const SizedBox(height: 10),
                    Text(
                      'Prizes grow as more managers join.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: muted,
                          ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ],
    );
    // While the gameweek is being played the page keeps itself current.
    return _LiveRefresh(active: item.isLive, onRefresh: onChanged, child: page);
  }
}

/// Reloads a pool that is in play every so often, so its leaderboard stays
/// current even if the live connection is not available.
///
/// The server announces every change to the table over the live connection
/// (see `realtime_sync.dart`), which reloads the page at once. This is the
/// fallback: every 20 seconds without that connection, and once a minute
/// with it in case an announcement was missed.
class _LiveRefresh extends ConsumerStatefulWidget {
  const _LiveRefresh({
    required this.active,
    required this.onRefresh,
    required this.child,
  });

  /// Whether the pool is in play. Nothing is reloaded otherwise.
  final bool active;
  final VoidCallback onRefresh;
  final Widget child;

  @override
  ConsumerState<_LiveRefresh> createState() => _LiveRefreshState();
}

class _LiveRefreshState extends ConsumerState<_LiveRefresh> {
  Timer? _timer;
  int _ticks = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => _tick());
  }

  void _tick() {
    if (!mounted || !widget.active) return;
    // Nothing to keep current while the app is in the background.
    final state = WidgetsBinding.instance.lifecycleState;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      return;
    }
    _ticks++;
    final connected = ref.read(realtimeSyncProvider)?.isConnected ?? false;
    if (!connected || _ticks % 3 == 0) {
      widget.onRefresh();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// The one line that sums up who wins what.
///
/// Before the pool is settled: "Top 3 of 30 share ₦28,500.00 after the 5%
/// fee." Afterwards: "3 of 30 managers shared ₦28,500.00."
String _prizeSentence(Pool item) {
  final plan = item.payout;
  final entrants = plan?.entrants ?? item.memberCount;

  if (item.status == 'cancelled') {
    return 'This pool was cancelled and every entry was refunded.';
  }
  if (item.status == 'settled') {
    final paid = item.leaderboard.where((m) => m.payoutCents > 0).toList();
    final total = paid.fold<int>(0, (sum, m) => sum + m.payoutCents);
    if (paid.isEmpty) return 'This pool has been settled.';
    return paid.length == 1
        ? '1 of $entrants managers won ${money(total)}.'
        : '${paid.length} of $entrants managers shared ${money(total)}.';
  }
  if (plan == null || entrants == 0) {
    return 'One manager in ten wins. Prizes show once someone joins.';
  }
  final fee = '${plan.houseCutPercentLabel}% fee';
  final prize = money(plan.totalWinningCents);
  final line = plan.winners <= 1
      ? '1 of $entrants wins $prize after the $fee.'
      : 'Top ${plan.winners} of $entrants share $prize after the $fee.';
  // A split tie is the default and needs no words; the others do.
  return switch (item.drawMethod) {
    PoolDrawMethod.captains => '$line Ties go to captain points.',
    _ => line,
  };
}

/// What each paid place wins. Shows the first few and lets the user open
/// the rest, since a large pool can pay as many as fifty places.
class _PrizeLadder extends StatefulWidget {
  const _PrizeLadder({required this.prizes});

  final List<Prize> prizes;

  @override
  State<_PrizeLadder> createState() => _PrizeLadderState();
}

class _PrizeLadderState extends State<_PrizeLadder> {
  static const _collapsed = 5;
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final prizes = widget.prizes;
    final hidden = prizes.length - _collapsed;
    final shown =
        _showAll || hidden <= 0 ? prizes : prizes.take(_collapsed).toList();
    return AnimatedSize(
      duration: AppMotion.standard,
      curve: AppMotion.curve,
      alignment: Alignment.topCenter,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final prize in shown)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  SizedBox(
                    width: 46,
                    child: Text(
                      _ordinal(prize.place),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: prize.place == 1
                                ? Theme.of(context).colorScheme.primary
                                : null,
                          ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${prize.percentLabel}%',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                  Text(
                    money(prize.amountCents),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ],
              ),
            ),
          if (hidden > 0)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => setState(() => _showAll = !_showAll),
                child: Text(
                  _showAll ? 'Show fewer' : 'Show all ${prizes.length} prizes',
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// "1st", "2nd", "3rd", "11th" and so on.
String _ordinal(int place) => '$place${ordinalSuffix(place)}';

class _HeroValue extends StatelessWidget {
  const _HeroValue({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFC9DED7),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          FitText(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w900,
                ),
          ),
        ],
      );
}

/// The creator's own tools: the invite to share, and editing or deleting
/// the pool.
class _OwnerPanel extends ConsumerStatefulWidget {
  const _OwnerPanel({
    required this.pool,
    required this.manage,
    required this.onChanged,
  });

  final Pool pool;
  final PoolManage manage;
  final VoidCallback onChanged;

  @override
  ConsumerState<_OwnerPanel> createState() => _OwnerPanelState();
}

class _OwnerPanelState extends ConsumerState<_OwnerPanel> {
  bool _busy = false;

  String get _code => widget.pool.inviteCode ?? '';
  String get _link => AppConfig.poolInviteUrl(_code);

  @override
  Widget build(BuildContext context) {
    final pool = widget.pool;
    final manage = widget.manage;
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurfaceVariant;
    final others = manage.otherEntries;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Invite managers', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          pool.awaitingAdminApproval
              ? 'You can share this now. People can join as soon as the pool '
                  'is approved.'
              : 'Only people with this link or code can see and join your pool.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: muted),
        ),
        const SizedBox(height: 12),
        GradientPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_code.isNotEmpty) ...[
                Text(
                  'INVITE CODE',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: muted,
                        letterSpacing: .7,
                      ),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  _code,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3,
                      ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SelectableText(
                    _link,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _busy ? null : _copyInvite,
                        icon: const Icon(Icons.link_rounded, size: 18),
                        label: const Text('Copy invite'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : _copyCode,
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        label: const Text('Copy code'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _busy ? null : _resetInvite,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Replace with a new link'),
                  ),
                ),
              ] else
                const Text('The invite for this pool is not available.'),
              const Divider(height: 28),
              Text(
                manage.entries == 0
                    ? 'Nobody has joined yet, so you can still edit or delete '
                        'this pool.'
                    : others == 0
                        ? 'Only you have joined. The pool can no longer be '
                            'edited, but you can delete it at no cost.'
                        : '$others other ${others == 1 ? 'manager has' : 'managers have'} '
                            'joined. The pool can no longer be edited. Deleting '
                            'it refunds everyone and costs you '
                            '${money(manage.deleteFeeCents)} '
                            '(${manage.deleteFeePercentLabel}% of the entry fee).',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: muted,
                      height: 1.35,
                    ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (manage.canEdit) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : _edit,
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Edit'),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  if (manage.canDelete)
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: scheme.error,
                        ),
                        onPressed: _busy ? null : _delete,
                        icon: _busy
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.delete_outline_rounded, size: 18),
                        label: const Text('Delete pool'),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _copyInvite() async {
    final pool = widget.pool;
    await Clipboard.setData(
      ClipboardData(
        text: 'Join my FPLboardman pool "${pool.name}" for Gameweek '
            '${pool.gameweek} (${money(pool.stakeCents)} to enter):\n'
            '$_link\n'
            'Or open the app, tap "Join with a code" and enter $_code',
      ),
    );
    if (!mounted) return;
    AppNotice.success(context, 'Invite copied. Paste it to the people you want in.');
  }

  Future<void> _copyCode() async {
    await Clipboard.setData(ClipboardData(text: _code));
    if (!mounted) return;
    AppNotice.success(context, 'Code copied.');
  }

  Future<void> _resetInvite() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Replace the invite?'),
        content: const Text(
          'The current link and code stop working straight away. Managers '
          'who have already joined stay in. Use this if the invite has '
          'reached people you did not mean to invite.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Replace'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(appGatewayProvider).resetPoolInvite(widget.pool.id);
      if (!mounted) return;
      widget.onChanged();
      AppNotice.success(context, 'New invite ready. The old one no longer works.');
    } on Object catch (error) {
      if (mounted) {
        AppNotice.error(context, error);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _edit() async {
    final updated = await showDialog<Pool>(
      context: context,
      builder: (_) => _EditPoolDialog(pool: widget.pool),
    );
    if (!mounted) return;
    // The dialog closes without a pool when the edit was refused because
    // someone joined in the meantime; reloading shows the page as it now is.
    widget.onChanged();
    if (updated == null) return;
    ref.invalidate(poolsProvider);
    AppNotice.success(context, '${updated.name} was updated.');
  }

  Future<void> _delete() async {
    final gateway = ref.read(appGatewayProvider);
    var pool = widget.pool;
    var changed = false;
    // Asked again if the entries changed between showing the amounts and
    // deleting, so the creator always agrees to the figure that is charged.
    while (true) {
      final manage = pool.manage;
      if (manage == null || !manage.canDelete) {
        if (mounted) {
          widget.onChanged();
          AppNotice.info(context, 'This pool can no longer be deleted.');
        }
        return;
      }
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => _DeletePoolDialog(
          pool: pool,
          manage: manage,
          changed: changed,
        ),
      );
      if (confirmed != true || !mounted) {
        if (changed && mounted) {
          widget.onChanged();
        }
        return;
      }

      setState(() => _busy = true);
      try {
        await gateway.deletePool(pool.id, feeCents: manage.deleteFeeCents);
      } on Object catch (error) {
        if (!mounted) return;
        setState(() => _busy = false);
        if (error is AppException && error.code == 'DELETE_FEE_CHANGED') {
          try {
            pool = await gateway.pool(pool.id);
          } on Object catch (reloadError) {
            if (mounted) {
              AppNotice.error(context, reloadError);
            }
            return;
          }
          if (!mounted) return;
          changed = true;
          continue;
        }
        widget.onChanged();
        if (openTopUpIfInsufficientFunds(context, error)) return;
        AppNotice.error(context, error);
        return;
      }

      ref.invalidate(poolsProvider);
      ref.invalidate(dashboardProvider);
      ref.invalidate(walletProvider);
      if (!mounted) return;
      final refunded = manage.entries;
      final fee = manage.deleteFeeCents;
      AppNotice.success(
        context,
        refunded == 0
            ? '${pool.name} was deleted.'
            : fee == 0
                ? '${pool.name} was deleted and your stake was refunded.'
                : '${pool.name} was deleted. $refunded '
                    '${refunded == 1 ? 'entry was' : 'entries were'} refunded '
                    'and ${money(fee)} was taken from your wallet.',
      );
      _closePage(context);
      return;
    }
  }
}

/// Spells out what deleting the pool does before the creator agrees.
class _DeletePoolDialog extends StatelessWidget {
  const _DeletePoolDialog({
    required this.pool,
    required this.manage,
    required this.changed,
  });

  final Pool pool;
  final PoolManage manage;

  /// True when this is being asked a second time because the entries
  /// changed while the first question was open.
  final bool changed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final others = manage.otherEntries;
    final fee = manage.deleteFeeCents;

    final List<String> points;
    if (manage.entries == 0) {
      points = const [
        'Nobody has joined, so there is nothing to refund and no fee.',
        'The invite link and code stop working.',
      ];
    } else if (others == 0) {
      points = [
        'Your ${money(pool.stakeCents)} stake goes back to your wallet.',
        'No fee, because nobody else has joined.',
        'The invite link and code stop working.',
      ];
    } else {
      points = [
        'All ${manage.entries} entries are refunded in full '
            '(${money(pool.stakeCents)} each), yours included if you joined.',
        'A fee of ${manage.deleteFeePercentLabel}% of the '
            '${money(pool.stakeCents)} entry fee — ${money(fee)} — is taken '
            'from your wallet.',
        '$others ${others == 1 ? 'manager is' : 'managers are'} told the '
            'pool was cancelled.',
      ];
    }

    return AlertDialog(
      title: Text('Delete ${pool.name}?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (changed) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'The entries changed while you were deciding. Please check '
                  'the amounts again.',
                ),
              ),
              const SizedBox(height: 14),
            ],
            for (final point in points)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 6, right: 10),
                      child: Icon(Icons.circle, size: 6, color: scheme.onSurfaceVariant),
                    ),
                    Expanded(child: Text(point)),
                  ],
                ),
              ),
            if (fee > 0) ...[
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: scheme.error.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Expanded(child: Text('You pay')),
                    Text(
                      money(fee),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: scheme.error,
                          ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'This cannot be undone.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Keep pool'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: scheme.error,
            foregroundColor: scheme.onError,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(fee > 0 ? 'Delete and pay ${money(fee)}' : 'Delete pool'),
        ),
      ],
    );
  }
}

/// Edits the creator's own pool. Only offered while nobody has joined.
///
/// Closes with the updated pool, or with nothing if the user cancelled or
/// the pool could no longer be edited.
class _EditPoolDialog extends ConsumerStatefulWidget {
  const _EditPoolDialog({required this.pool});

  final Pool pool;

  @override
  ConsumerState<_EditPoolDialog> createState() => _EditPoolDialogState();
}

class _EditPoolDialogState extends ConsumerState<_EditPoolDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.pool.name);
  late final _stakeNaira = TextEditingController(
    text: (widget.pool.stakeCents ~/ 100).toString(),
  );
  late final _maxMembers = TextEditingController(
    text: widget.pool.maxMembers?.toString() ?? '',
  );
  late PoolDrawMethod _drawMethod = widget.pool.drawMethod;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _stakeNaira.dispose();
    _maxMembers.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        title: const Text('Edit pool'),
        content: SizedBox(
          width: 460,
          child: Form(
            key: _form,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(labelText: 'Pool name'),
                    validator: (value) {
                      final length = value?.trim().length ?? 0;
                      if (length < 3) return 'Use at least 3 characters';
                      if (length > 80) return 'Use 80 characters or fewer';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _stakeNaira,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Stake per manager (₦)',
                      hintText: 'Minimum ₦1,000',
                    ),
                    validator: (value) {
                      final amount = int.tryParse(
                        (value ?? '').replaceAll(',', '').trim(),
                      );
                      if (amount == null) return 'Enter a whole amount in naira';
                      if (amount < 1000) return 'The minimum amount is ₦1,000';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'If managers finish level',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<PoolDrawMethod>(
                    segments: PoolDrawMethod.values
                        .map(
                          (method) => ButtonSegment<PoolDrawMethod>(
                            value: method,
                            label: Text(method.label),
                          ),
                        )
                        .toList(),
                    selected: {_drawMethod},
                    showSelectedIcon: false,
                    onSelectionChanged: _saving
                        ? null
                        : (selection) =>
                            setState(() => _drawMethod = selection.single),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _drawMethod.description,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: muted),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _maxMembers,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Maximum managers (optional)',
                      hintText: 'No limit',
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) return null;
                      final parsed = int.tryParse(text);
                      return parsed == null || parsed < 2
                          ? 'Use 2 or more, or leave empty for no limit'
                          : null;
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save changes'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final updated = await ref.read(appGatewayProvider).updatePool(
            widget.pool.id,
            name: _name.text.trim(),
            stakeCents:
                int.parse(_stakeNaira.text.replaceAll(',', '').trim()) * 100,
            drawMethod: _drawMethod,
            maxMembers: int.tryParse(_maxMembers.text.trim()),
          );
      if (!mounted) return;
      Navigator.of(context).pop(updated);
    } on Object catch (error) {
      if (!mounted) return;
      AppNotice.error(context, error);
      // Someone joined, or the deadline passed, while the form was open:
      // nothing here can be saved any more.
      final code = error is AppException ? error.code : null;
      if (code == 'POOL_HAS_ENTRIES' || code == 'POOL_CLOSED') {
        Navigator.of(context).pop();
        return;
      }
      setState(() => _saving = false);
    }
  }
}
