import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fplboardman/app/theme/app_theme.dart';
import 'package:fplboardman/core/network/providers.dart';
import 'package:fplboardman/core/ui/app_widgets.dart';
import 'package:fplboardman/features/dashboard/presentation/dashboard_controller.dart';
import 'package:fplboardman/features/fpl_team/domain/fpl_team.dart';
import 'package:go_router/go_router.dart';

final linkTeamActionProvider =
    AsyncNotifierProvider<LinkTeamController, FplManager?>(
  LinkTeamController.new,
);

class LinkTeamController extends AsyncNotifier<FplManager?> {
  int? _validatedId;

  @override
  Future<FplManager?> build() async => null;

  Future<bool> validateTeam(int id) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(appGatewayProvider).validateTeam(id),
    );
    if (!state.hasError) _validatedId = id;
    return !state.hasError;
  }

  Future<bool> linkTeam() async {
    final id = _validatedId;
    if (id == null) return false;
    final preview = state.value;
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref.read(appGatewayProvider).linkTeam(id),
    );
    state = result.when(
      data: (_) => AsyncData(preview),
      error: (error, stack) => AsyncError<FplManager?>(error, stack),
      loading: () => const AsyncLoading(),
    );
    if (!result.hasError) ref.invalidate(dashboardProvider);
    return !result.hasError;
  }

  void reset() {
    _validatedId = null;
    state = const AsyncData(null);
  }
}

/// Dialog content used by the `/link-team` modal route.
class LinkTeamDialog extends ConsumerStatefulWidget {
  const LinkTeamDialog({super.key, this.reason});

  final String? reason;

  @override
  ConsumerState<LinkTeamDialog> createState() => _LinkTeamDialogState();
}

class _LinkTeamDialogState extends ConsumerState<LinkTeamDialog> {
  final _form = GlobalKey<FormState>();
  final _teamId = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(ref.read(linkTeamActionProvider.notifier).reset);
  }

  @override
  void dispose() {
    _teamId.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final action = ref.watch(linkTeamActionProvider);
    final manager = action.value;
    final size = MediaQuery.sizeOf(context);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 640,
          maxHeight: size.height * 0.9,
        ),
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
                          'Link your FPL team',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _reasonText(widget.reason),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: action.isLoading ? null : () => context.pop(false),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GradientPanel(
                      colors: const [Color(0xFF0B4939), Color(0xFF271747)],
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.verified_rounded,
                            color: AppColors.lime,
                            size: 34,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'One ID. Your real team.',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Preview the public manager profile before linking it. We never ask for your FPL password.',
                            style: TextStyle(
                              color: Color(0xFFD1E3DC),
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Form(
                      key: _form,
                      child: TextFormField(
                        controller: _teamId,
                        enabled: manager == null && !action.isLoading,
                        keyboardType: TextInputType.number,
                        autofocus: true,
                        decoration: const InputDecoration(
                          labelText: 'FPL Team ID',
                          hintText: 'e.g. 1234567',
                          prefixIcon: Icon(Icons.tag_rounded),
                        ),
                        validator: (value) {
                          final id = int.tryParse(value ?? '');
                          return id == null || id < 1
                              ? 'Enter the numeric ID from your FPL URL'
                              : null;
                        },
                        onFieldSubmitted: (_) {
                          if (!action.isLoading && manager == null) _validate();
                        },
                      ),
                    ),
                    if (action.hasError) ...[
                      const SizedBox(height: 12),
                      Text(
                        action.error.toString(),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    AnimatedSwitcher(
                      duration: AppMotion.standard,
                      child: manager == null
                          ? FilledButton.icon(
                              key: const ValueKey('validate'),
                              onPressed: action.isLoading ? null : _validate,
                              icon: action.isLoading
                                  ? const SizedBox.square(
                                      dimension: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.search_rounded),
                              label: const Text('Find team'),
                            )
                          : _ManagerPreview(
                              key: ValueKey(manager.entryId),
                              manager: manager,
                              busy: action.isLoading,
                              onChange:
                                  ref.read(linkTeamActionProvider.notifier).reset,
                              onConfirm: _link,
                            ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Where to find it',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    const _Step(
                      number: '1',
                      text: 'Open fantasy.premierleague.com and view your team.',
                    ),
                    const _Step(
                      number: '2',
                      text: 'Copy the number after /entry/ in the page URL.',
                    ),
                    const _Step(
                      number: '3',
                      text: 'Paste it above and confirm the profile is yours.',
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed:
                          action.isLoading ? null : () => context.pop(false),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _validate() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    await ref
        .read(linkTeamActionProvider.notifier)
        .validateTeam(int.parse(_teamId.text));
  }

  Future<void> _link() async {
    final linked =
        await ref.read(linkTeamActionProvider.notifier).linkTeam();
    if (linked && mounted) context.pop(true);
  }
}

String _reasonText(String? reason) => switch (reason) {
      'pool' => 'Link a verified team before creating a pool.',
      'challenge' => 'Link a verified team before creating a head-to-head.',
      _ => 'Connect the team you use in Fantasy Premier League.',
    };

class _ManagerPreview extends StatelessWidget {
  const _ManagerPreview({
    required this.manager,
    required this.busy,
    required this.onChange,
    required this.onConfirm,
    super.key,
  });

  final FplManager manager;
  final bool busy;
  final VoidCallback onChange;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) => GradientPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const StatusPill('Verified public profile'),
            const SizedBox(height: 14),
            Text(
              manager.teamName,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              '${manager.managerName} · Team ${manager.entryId}',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _Metric(
                    label: 'Overall points',
                    value: '${manager.overallPoints}',
                  ),
                ),
                Expanded(
                  child: _Metric(
                    label: 'Overall rank',
                    value: manager.overallRank == null
                        ? '—'
                        : '#${manager.overallRank}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: busy ? null : onChange,
                    child: const Text('Use another ID'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: busy ? null : onConfirm,
                    child: busy
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Confirm and link'),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.titleLarge),
        ],
      );
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.text});
  final String number;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.14),
              child: Text(
                number,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(text)),
          ],
        ),
      );
}
