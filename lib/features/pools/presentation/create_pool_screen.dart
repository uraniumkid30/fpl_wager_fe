import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fplboardman/app/theme/app_theme.dart';
import 'package:fplboardman/core/ui/app_notice.dart';
import 'package:fplboardman/core/ui/app_widgets.dart';
import 'package:fplboardman/features/dashboard/presentation/dashboard_controller.dart';
import 'package:fplboardman/features/fpl_team/presentation/team_requirement.dart';
import 'package:fplboardman/features/pools/domain/pool.dart';
import 'package:fplboardman/features/pools/presentation/payout_editor.dart';
import 'package:fplboardman/features/pools/presentation/pools_controller.dart';
import 'package:go_router/go_router.dart';

class CreatePoolDraft {
  const CreatePoolDraft({this.drawMethod = PoolDrawMethod.split});

  final PoolDrawMethod drawMethod;

  CreatePoolDraft copyWith({PoolDrawMethod? drawMethod}) =>
      CreatePoolDraft(drawMethod: drawMethod ?? this.drawMethod);
}

final createPoolDraftProvider =
    NotifierProvider<CreatePoolDraftController, CreatePoolDraft>(
  CreatePoolDraftController.new,
);

class CreatePoolDraftController extends Notifier<CreatePoolDraft> {
  @override
  CreatePoolDraft build() => const CreatePoolDraft();

  void setDrawMethod(PoolDrawMethod value) =>
      state = state.copyWith(drawMethod: value);
}

class CreatePoolScreen extends ConsumerStatefulWidget {
  const CreatePoolScreen({super.key});

  @override
  ConsumerState<CreatePoolScreen> createState() => _CreatePoolScreenState();
}

class _CreatePoolScreenState extends ConsumerState<CreatePoolScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _stakeNaira = TextEditingController();
  final _maxMembers = TextEditingController();
  PayoutChoice _payout = const PayoutChoice();

  @override
  void dispose() {
    _name.dispose();
    _stakeNaira.dispose();
    _maxMembers.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(createPoolDraftProvider);
    final action = ref.watch(poolActionProvider);
    final dashboard = ref.watch(dashboardProvider).value;
    final gameweek = dashboard?.currentGameweek;

    final size = MediaQuery.sizeOf(context);
    // The fee and winners limit the server sets; the usual ones until they load.
    final terms = ref.watch(poolTermsProvider).value ?? const PoolTerms();

    return PopScope(
      canPop: !action.isLoading,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 680, maxHeight: size.height * 0.9),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 16, 10, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Create a private pool',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Only people you invite can see or join it.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: action.isLoading ? null : () => context.pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: Form(
                  key: _form,
                  child: ListView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    children: [
              GradientPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.auto_awesome_rounded,
                      color: AppColors.lime,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Your pool, your people.',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      gameweek == null
                          ? 'Loading the official FPL gameweek…'
                          : 'You get a link and a code to share once it is '
                              'created. One pool per gameweek; this one is '
                              'for Gameweek $gameweek and closes at the FPL '
                              'deadline.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Pool name',
                  hintText:
                      'e.g. Lagos Legends${gameweek == null ? '' : ' GW$gameweek'}',
                ),
                validator: (value) => value == null || value.trim().length < 3
                    ? 'Use at least 3 characters'
                    : null,
              ),
              const SizedBox(height: 20),
              Text(
                'Stake per manager',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _stakeNaira,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Amount (₦)',
                  hintText: 'Minimum ₦1,000',
                  prefixIcon: Icon(Icons.payments_outlined),
                ),
                validator: (value) {
                  final amount = int.tryParse((value ?? '').replaceAll(',', '').trim());
                  if (amount == null) return 'Enter a whole amount in naira';
                  if (amount < 1000) return 'The minimum amount is ₦1,000';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _maxMembers,
                keyboardType: TextInputType.number,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                decoration: const InputDecoration(
                  labelText: 'Maximum managers (optional)',
                  hintText: 'Unlimited',
                  prefixIcon: Icon(Icons.groups_outlined),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return null;
                  final parsed = int.tryParse(value);
                  return parsed == null || parsed < 2 ? 'Use 2 or more' : null;
                },
              ),
              const SizedBox(height: 24),
              Text(
                'If managers finish level',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                'Choose what happens when two or more managers finish on the same score.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 12),
              SegmentedButton<PoolDrawMethod>(
                segments: PoolDrawMethod.values
                    .map(
                      (method) => ButtonSegment<PoolDrawMethod>(
                        value: method,
                        label: Text(method.label),
                      ),
                    )
                    .toList(),
                selected: {draft.drawMethod},
                showSelectedIcon: false,
                onSelectionChanged: action.isLoading
                    ? null
                    : (selection) => ref
                        .read(createPoolDraftProvider.notifier)
                        .setDrawMethod(selection.single),
              ),
              const SizedBox(height: 10),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: Container(
                  key: ValueKey(draft.drawMethod),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primaryContainer
                        .withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        draft.drawMethod == PoolDrawMethod.split
                            ? Icons.call_split_rounded
                            : draft.drawMethod == PoolDrawMethod.captains
                                ? Icons.workspace_premium_outlined
                                : Icons.numbers_rounded,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(draft.drawMethod.description)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              PayoutEditor(
                initial: _payout,
                rule: terms.winnerRule,
                maxMembers: _maxMembers,
                enabled: !action.isLoading,
                onChanged: (choice) => _payout = choice,
              ),
              const SizedBox(height: 20),
              _DeleteFeeNote(stake: _stakeNaira, terms: terms),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: action.isLoading || gameweek == null
                    ? null
                    : () => _create(gameweek, draft),
                child: action.isLoading
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        gameweek == null
                            ? 'Syncing gameweek…'
                            : 'Create pool',
                      ),
              ),
              const SizedBox(height: 10),
              Text(
                'FPLboardman reviews new pools before anyone can join; we will tell you in the app and by email when yours is approved. Creating a pool costs nothing, and you can edit it until someone joins.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: action.isLoading ? null : () => context.pop(),
                child: const Text('Cancel'),
              ),
            ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _create(int gameweek, CreatePoolDraft draft) async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final terms = ref.read(poolTermsProvider).value ?? const PoolTerms();
    final payoutProblem = PayoutEditor.problem(
      _payout,
      terms.winnerRule,
      int.tryParse(_maxMembers.text.trim()),
    );
    if (payoutProblem != null) {
      AppNotice.error(context, payoutProblem);
      return;
    }
    final linked = await requireLinkedFplTeam(
      context,
      ref,
      action: TeamProtectedAction.pool,
    );
    if (!linked || !mounted) return;

    final amountNaira = int.parse(_stakeNaira.text.replaceAll(',', '').trim());
    final pool = await ref.read(poolActionProvider.notifier).create(
          CreatePoolCommand(
            name: _name.text.trim(),
            gameweek: gameweek,
            stakeCents: amountNaira * 100,
            drawMethod: draft.drawMethod,
            payout: _payout,
            maxMembers: int.tryParse(_maxMembers.text),
          ),
        );
    if (!mounted) return;
    if (pool == null) {
      AppNotice.error(
        context,
        ref.read(poolActionProvider).error ?? 'The pool could not be created.',
      );
      return;
    }

    AppNotice.success(
      context,
      '${pool.name} was created. Share its invite link with the managers you want in.',
    );
    // Closes with the new pool's id, so the pools page can open it.
    context.pop(pool.id);
  }
}

/// Tells the creator, before they create the pool, what deleting it will
/// cost once other managers have joined. The fee is set by the
/// administrators; the amount follows the stake as it is typed.
const _amber = Color(0xFFF5A524);

class _DeleteFeeNote extends StatelessWidget {
  const _DeleteFeeNote({required this.stake, required this.terms});

  final TextEditingController stake;
  final PoolTerms terms;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: stake,
      builder: (context, value, _) {
        final naira = int.tryParse(value.text.replaceAll(',', '').trim());
        final percent = '${terms.deleteFeePercentLabel}%';
        final example = naira == null || naira < 1000
            ? ''
            : ' That is ${money(terms.deleteFeeFor(naira * 100))} on a '
                '${money(naira * 100)} entry.';
        final free = terms.deleteFeeBasisPoints <= 0;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _amber.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _amber.withValues(alpha: 0.35)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded, size: 20, color: _amber),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      free
                          ? 'Deleting your pool'
                          : 'Deleting after someone joins costs a fee',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      free
                          ? 'You can delete this pool until the gameweek '
                              'deadline. Everyone who joined gets their money '
                              'back.'
                          : 'You can delete this pool until the gameweek '
                              'deadline. If another manager has joined, '
                              'everyone gets their money back and you pay '
                              '$percent of the entry fee.$example Deleting '
                              'before anyone else joins is free.',
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
