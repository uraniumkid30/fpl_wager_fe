import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fplboardman/app/theme/app_theme.dart';
import 'package:fplboardman/core/ui/app_header.dart';
import 'package:fplboardman/core/ui/app_notice.dart';
import 'package:fplboardman/core/ui/app_widgets.dart';
import 'package:fplboardman/features/challenges/domain/challenge.dart';
import 'package:fplboardman/features/challenges/presentation/challenges_controller.dart';
import 'package:fplboardman/features/dashboard/presentation/dashboard_controller.dart';
import 'package:fplboardman/features/fpl_team/presentation/team_requirement.dart';
import 'package:fplboardman/features/wallet/presentation/insufficient_funds.dart';

/// The smallest stake the server accepts for a head-to-head: ₦100.
const _minimumStakeNaira = 100;

/// Reads a typed naira amount ("2,500" or "2500"); null if it is not one.
int? _parseNaira(String text) =>
    int.tryParse(text.replaceAll(',', '').replaceAll('₦', '').trim());

final challengeComposerProvider =
    NotifierProvider<ChallengeComposerController, bool>(
  ChallengeComposerController.new,
);

class ChallengeComposerController extends Notifier<bool> {
  @override
  bool build() => false;
  void open() => state = true;
  void close() => state = false;
}

class ChallengesScreen extends ConsumerStatefulWidget {
  const ChallengesScreen({super.key});

  @override
  ConsumerState<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends ConsumerState<ChallengesScreen> {
  final _form = GlobalKey<FormState>();
  final _opponent = TextEditingController();
  final _amount = TextEditingController();

  @override
  void dispose() {
    _opponent.dispose();
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final challenges = ref.watch(challengesProvider);
    final action = ref.watch(challengeActionProvider);
    final composerOpen = ref.watch(challengeComposerProvider);
    final gameweek = ref.watch(dashboardProvider).value?.currentGameweek;

    return Scaffold(
      appBar: AppHeader(
        title: 'Head to head',
        actions: [
          IconButton.filledTonal(
            tooltip: composerOpen ? 'Close challenge form' : 'Create challenge',
            onPressed: action.isLoading
                ? null
                : composerOpen
                    ? ref.read(challengeComposerProvider.notifier).close
                    : _beginCreate,
            icon: Icon(composerOpen ? Icons.close_rounded : Icons.add_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: composerOpen
          ? null
          : FloatingActionButton.extended(
              onPressed: _beginCreate,
              icon: const Icon(Icons.add_rounded),
              label: const Text('New challenge'),
            ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(challengesProvider);
          ref.invalidate(dashboardProvider);
          await ref.read(challengesProvider.future);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            8,
            AppSpacing.md,
            120,
          ),
          children: [
            Text(
              'Challenge any verified FPL manager. Winner takes the pot.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            AnimatedSwitcher(
              duration: AppMotion.standard,
              child: composerOpen
                  ? _ChallengeComposer(
                      key: const ValueKey('composer'),
                      formKey: _form,
                      opponent: _opponent,
                      amount: _amount,
                      gameweek: gameweek,
                      busy: action.isLoading,
                      onSubmit: _submit,
                      onCancel:
                          ref.read(challengeComposerProvider.notifier).close,
                    )
                  : _CreateChallengeCard(
                      key: const ValueKey('call-to-action'),
                      onCreate: _beginCreate,
                    ),
            ),
            const SizedBox(height: 26),
            Text(
              'Your head-to-heads',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            challenges.when(
              data: (items) => items.isEmpty
                  ? const EmptyState(
                      icon: Icons.compare_arrows_rounded,
                      title: 'No challenges yet',
                      message: 'Pick a rival and make this gameweek personal.',
                    )
                  : Column(
                      children: items
                          .map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _ChallengeCard(item: item),
                            ),
                          )
                          .toList(),
                    ),
              loading: () => const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => Text(error.toString()),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _beginCreate() async {
    final linked = await requireLinkedFplTeam(
      context,
      ref,
      action: TeamProtectedAction.challenge,
    );
    if (linked && mounted) {
      ref.read(challengeComposerProvider.notifier).open();
    }
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final linked = await requireLinkedFplTeam(
      context,
      ref,
      action: TeamProtectedAction.challenge,
    );
    if (!linked || !mounted) return;

    final gameweek = ref.read(dashboardProvider).value?.currentGameweek;
    if (gameweek == null) {
      AppNotice.info(context, 'The current FPL gameweek is still syncing.');
      return;
    }

    final created = await ref.read(challengeActionProvider.notifier).create(
          opponentTeamId: int.parse(_opponent.text),
          gameweek: gameweek,
          stakeCents: _parseNaira(_amount.text)! * 100,
        );
    if (created && mounted) {
      _opponent.clear();
      _amount.clear();
      ref.read(challengeComposerProvider.notifier).close();
      AppNotice.success(context, 'Head-to-head challenge created.');
    } else if (mounted) {
      final error = ref.read(challengeActionProvider).error;
      if (openTopUpIfInsufficientFunds(context, error)) return;
      AppNotice.error(context, error ?? 'The challenge could not be created.');
    }
  }
}

class _CreateChallengeCard extends StatelessWidget {
  const _CreateChallengeCard({required this.onCreate, super.key});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => GradientPanel(
        colors: const [Color(0xFF0B4939), Color(0xFF271747)],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.compare_arrows_rounded,
              color: AppColors.lime,
              size: 34,
            ),
            const SizedBox(height: 14),
            Text(
              'Ready for a one-on-one?',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                  ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Create a challenge against another verified FPL manager.',
              style: TextStyle(color: Color(0xFFD1E3DC)),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create head-to-head'),
            ),
          ],
        ),
      );
}

class _ChallengeComposer extends StatelessWidget {
  const _ChallengeComposer({
    required this.formKey,
    required this.opponent,
    required this.amount,
    required this.gameweek,
    required this.busy,
    required this.onSubmit,
    required this.onCancel,
    super.key,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController opponent;

  /// What each manager stakes, typed in naira.
  final TextEditingController amount;
  final int? gameweek;
  final bool busy;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) => GradientPanel(
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.compare_arrows_rounded,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      gameweek == null
                          ? 'New challenge'
                          : 'New Gameweek $gameweek challenge',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cancel',
                    onPressed: busy ? null : onCancel,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: opponent,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Opponent FPL Team ID',
                  prefixIcon: Icon(Icons.tag_rounded),
                ),
                validator: (value) => int.tryParse(value ?? '') == null
                    ? 'Enter a valid numeric team ID'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: amount,
                keyboardType: TextInputType.number,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                decoration: const InputDecoration(
                  labelText: 'Stake (₦)',
                  hintText: 'How much each of you puts in',
                  helperText: 'Whole naira, at least ₦100',
                  prefixIcon: Icon(Icons.payments_outlined),
                ),
                validator: (value) {
                  final naira = _parseNaira(value ?? '');
                  if (naira == null) return 'Enter a whole amount in naira';
                  if (naira < _minimumStakeNaira) {
                    return 'The minimum stake is ₦$_minimumStakeNaira';
                  }
                  return null;
                },
                onFieldSubmitted: (_) {
                  if (!busy && gameweek != null) onSubmit();
                },
              ),
              const SizedBox(height: 18),
              // The button shows the amount as it is typed.
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: amount,
                builder: (context, value, _) {
                  final naira = _parseNaira(value.text);
                  final label = gameweek == null
                      ? 'Syncing gameweek…'
                      : naira == null || naira < _minimumStakeNaira
                          ? 'Send challenge'
                          : 'Send challenge · ${money(naira * 100)}';
                  return FilledButton(
                    onPressed: busy || gameweek == null ? null : onSubmit,
                    child: busy
                        ? const SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(label),
                  );
                },
              ),
            ],
          ),
        ),
      );
}

class _ChallengeCard extends StatelessWidget {
  const _ChallengeCard({required this.item});
  final Challenge item;

  @override
  Widget build(BuildContext context) => GradientPanel(
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .secondary
                    .withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                Icons.compare_arrows_rounded,
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.opponentName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    'GW${item.gameweek} · Team ${item.opponentTeamId}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  money(item.stakeCents),
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 5),
                StatusPill(item.status),
              ],
            ),
          ],
        ),
      );
}
