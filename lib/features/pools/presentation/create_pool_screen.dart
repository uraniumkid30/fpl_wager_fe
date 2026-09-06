import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpl_wager/app/theme/app_theme.dart';
import 'package:fpl_wager/core/ui/app_notice.dart';
import 'package:fpl_wager/core/ui/app_widgets.dart';
import 'package:fpl_wager/features/dashboard/presentation/dashboard_controller.dart';
import 'package:fpl_wager/features/fpl_team/presentation/team_requirement.dart';
import 'package:fpl_wager/features/pools/domain/pool.dart';
import 'package:fpl_wager/features/pools/presentation/pools_controller.dart';
import 'package:go_router/go_router.dart';

class CreatePoolDraft {
  const CreatePoolDraft({
    this.stakeCents = 100000,
    this.approvalRequired = false,
  });

  final int stakeCents;
  final bool approvalRequired;

  CreatePoolDraft copyWith({int? stakeCents, bool? approvalRequired}) =>
      CreatePoolDraft(
        stakeCents: stakeCents ?? this.stakeCents,
        approvalRequired: approvalRequired ?? this.approvalRequired,
      );
}

final createPoolDraftProvider =
    NotifierProvider<CreatePoolDraftController, CreatePoolDraft>(
  CreatePoolDraftController.new,
);

class CreatePoolDraftController extends Notifier<CreatePoolDraft> {
  @override
  CreatePoolDraft build() => const CreatePoolDraft();

  void selectStake(int value) => state = state.copyWith(stakeCents: value);
  void setApprovalRequired(bool value) =>
      state = state.copyWith(approvalRequired: value);
}

class CreatePoolScreen extends ConsumerStatefulWidget {
  const CreatePoolScreen({super.key});

  @override
  ConsumerState<CreatePoolScreen> createState() => _CreatePoolScreenState();
}

class _CreatePoolScreenState extends ConsumerState<CreatePoolScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _maxMembers = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
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
                            'Create a gameweek pool',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Set the entry rules and invite managers.',
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
                      'Your rules. One clean pool.',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      gameweek == null
                          ? 'Loading the official FPL gameweek…'
                          : 'Gameweek $gameweek closes automatically at the official FPL deadline.',
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
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [50000, 100000, 200000, 500000]
                    .map(
                      (value) => ChoiceChip(
                        label: Text(money(value)),
                        selected: draft.stakeCents == value,
                        onSelected: (_) => ref
                            .read(createPoolDraftProvider.notifier)
                            .selectStake(value),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _maxMembers,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Maximum managers (optional)',
                  hintText: 'Unlimited',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return null;
                  final parsed = int.tryParse(value);
                  return parsed == null || parsed < 2 ? 'Use 2 or more' : null;
                },
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Approve managers before entry'),
                subtitle: const Text(
                  'Requests remain pending until you accept them.',
                ),
                value: draft.approvalRequired,
                onChanged: ref
                    .read(createPoolDraftProvider.notifier)
                    .setApprovalRequired,
              ),
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
                            : 'Create pool · ${money(draft.stakeCents)}',
                      ),
              ),
              const SizedBox(height: 10),
              Text(
                'Your stake is locked when the pool is created and refunded if the pool is cancelled.',
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
    final linked = await requireLinkedFplTeam(
      context,
      ref,
      action: TeamProtectedAction.pool,
    );
    if (!linked || !mounted) return;

    final pool = await ref.read(poolActionProvider.notifier).create(
          CreatePoolCommand(
            name: _name.text.trim(),
            gameweek: gameweek,
            stakeCents: draft.stakeCents,
            approvalRequired: draft.approvalRequired,
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

    AppNotice.success(context, '${pool.name} was created successfully.');
    context.pop(pool.id);
  }
}
