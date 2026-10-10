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

class PoolsScreen extends ConsumerWidget {
  const PoolsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pools = ref.watch(poolsProvider);
    final action = ref.watch(poolActionProvider);
    final currentGameweek = ref.watch(dashboardProvider).value?.currentGameweek;
    return Scaffold(
      appBar: const AppHeader(title: 'Gameweek pools'),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(poolsProvider);
          await ref.read(poolsProvider.future);
        },
        child: AsyncContent(
          value: pools,
          onRetry: () => ref.invalidate(poolsProvider),
          data: (items) {
            final autoPools = items.where((item) => item.isAuto).toList();
            final customPools = items.where((item) => !item.isAuto).toList();
            // A manager may run one pool of their own per gameweek.
            final myPool = currentGameweek == null
                ? null
                : customPools
                    .where((p) => p.isMine && p.gameweek == currentGameweek)
                    .firstOrNull;
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                8,
                AppSpacing.md,
                120,
              ),
              children: [
                Text(
                  'Enter an auto pool, or run a private one for your own circle.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 22),
                _SectionTitle(
                  title: 'Auto pools',
                  subtitle: _stakesLabel(autoPools),
                  count: autoPools.length,
                ),
                const SizedBox(height: 12),
                if (autoPools.isEmpty)
                  const _AutoPoolsSyncing()
                else
                  ...autoPools.indexed.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: FadeSlideIn(
                        delay: Duration(milliseconds: entry.$1 * 55),
                        child: PoolCard(
                          pool: entry.$2,
                          joining: action.isLoading,
                          onJoin: () => _joinPool(context, ref, entry.$2),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                _HeadToHeadCard(onTap: () => context.push('/challenges')),
                const SizedBox(height: 28),
                _SectionTitle(
                  title: 'Custom pools',
                  subtitle: 'Private pools: yours, and the ones you were invited to',
                  count: customPools.length,
                ),
                const SizedBox(height: 12),
                _CustomPoolActions(
                  onCreate: myPool == null ? () => _createPool(context, ref) : null,
                  onJoin: () => _joinWithCode(context),
                  note: myPool == null
                      ? null
                      : 'You can run one pool of your own per gameweek. To '
                          'start another for Gameweek ${myPool.gameweek}, '
                          'delete ${myPool.name} first.',
                ),
                const SizedBox(height: 14),
                if (customPools.isEmpty)
                  const EmptyState(
                    icon: Icons.tune_rounded,
                    title: 'No private pools yet',
                    message: 'Create one and share its link, or join a friend\'s pool with their code.',
                  )
                else
                  ...customPools.indexed.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: FadeSlideIn(
                        delay: Duration(milliseconds: entry.$1 * 55),
                        child: PoolCard(
                          pool: entry.$2,
                          joining: action.isLoading,
                          onJoin: () => _joinPool(context, ref, entry.$2),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

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
