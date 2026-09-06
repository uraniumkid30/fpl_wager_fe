import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpl_wager/app/theme/app_theme.dart';
import 'package:fpl_wager/core/ui/app_widgets.dart';
import 'package:fpl_wager/features/admin/presentation/admin_providers.dart';
import 'package:fpl_wager/features/admin/presentation/admin_resources.dart';
import 'package:go_router/go_router.dart';

class AdminResourceScreen extends ConsumerWidget {
  const AdminResourceScreen({required this.resource, super.key});
  final String resource;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final definition = adminResources[resource];
    if (definition == null) {
      return const Scaffold(body: EmptyState(icon: Icons.search_off_rounded, title: 'Unknown admin resource', message: 'Return to the admin dashboard and choose a valid section.'));
    }
    final value = ref.watch(adminCollectionProvider(resource));
    final action = ref.watch(adminResourceActionProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(definition.label),
        actions: [
          if (resource == 'wagers' || resource == 'settings')
            IconButton.filledTonal(
              tooltip: resource == 'wagers' ? 'Create wager' : 'Create setting',
              onPressed: action.isLoading ? null : () => _create(context, ref),
              icon: const Icon(Icons.add_rounded),
            ),
          const SizedBox(width: 10),
        ],
      ),
      floatingActionButton: resource == 'wagers' || resource == 'settings'
          ? FloatingActionButton.extended(
              onPressed: action.isLoading ? null : () => _create(context, ref),
              icon: const Icon(Icons.add_rounded),
              label: Text(resource == 'wagers' ? 'Create wager' : 'Add setting'),
            )
          : null,
      body: Column(
        children: [
          if (action.isLoading) const LinearProgressIndicator(),
          if (action.hasError)
            MaterialBanner(
              content: Text(action.error.toString()),
              actions: [TextButton(onPressed: () => ref.invalidate(adminResourceActionProvider), child: const Text('Dismiss'))],
            ),
          if (resource == 'transactions' || resource == 'payments' || resource == 'wallets')
            _AuditNotice(resource: resource),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(adminCollectionProvider(resource));
                await ref.read(adminCollectionProvider(resource).future);
              },
              child: value.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => ListView(children: [EmptyState(icon: Icons.cloud_off_rounded, title: 'Could not load ${definition.label}', message: error.toString())]),
                data: (items) => items.isEmpty
                    ? ListView(physics: const AlwaysScrollableScrollPhysics(), children: [EmptyState(icon: definition.icon, title: 'No ${definition.label.toLowerCase()}', message: 'Records will appear here when they are available.')])
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 120),
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) => FadeSlideIn(
                          delay: Duration(milliseconds: index * 35),
                          child: _RecordCard(resource: resource, record: items[index], onTap: () => _open(context, ref, items[index])),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) {
    return switch (resource) {
      'wagers' => _createWager(context, ref),
      'settings' => _putSetting(context, ref),
      _ => Future<void>.value(),
    };
  }

  void _open(
    BuildContext context,
    WidgetRef ref,
    Map<String, Object?> record,
  ) {
    switch (resource) {
      case 'users':
        final id = record['id'];
        if (id != null) context.push('/admin/users/$id');
        return;
      case 'wagers':
        unawaited(_updateWager(context, ref, record));
        return;
      case 'payments':
        unawaited(_verifyPayment(context, ref, record));
        return;
      case 'wallets':
        unawaited(_adjustWallet(context, ref, record));
        return;
      case 'settings':
        unawaited(_putSetting(context, ref, record: record));
        return;
      case 'transactions':
        unawaited(_showJson(context, record));
        return;
    }
  }
}

class _AuditNotice extends StatelessWidget {
  const _AuditNotice({required this.resource});
  final String resource;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, 4, AppSpacing.md, 0),
        child: GradientPanel(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            const Icon(Icons.verified_user_outlined, color: AppColors.lime),
            const SizedBox(width: 12),
            Expanded(child: Text(resource == 'transactions' ? 'Ledger entries are immutable and read-only.' : resource == 'payments' ? 'Payments are immutable; use verification to reconcile provider state.' : 'Wallet balances change only through audited ledger adjustments.')),
          ]),
        ),
      );
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({required this.resource, required this.record, required this.onTap});
  final String resource;
  final Map<String, Object?> record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = _first(record, const ['full_name', 'name', 'email', 'reference', 'key', 'description', 'id', 'user_id']);
    final subtitle = _subtitle(record, title);
    return GradientPanel(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(children: [
        CircleAvatar(backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.13), child: Icon(adminResources[resource]!.icon, color: Theme.of(context).colorScheme.primary)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
          if (subtitle.isNotEmpty) Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant), maxLines: 2, overflow: TextOverflow.ellipsis),
        ])),
        if (record['status'] != null) StatusPill('${record['status']}'),
        const SizedBox(width: 6),
        const Icon(Icons.chevron_right_rounded),
      ]),
    );
  }
}

Future<void> _createWager(BuildContext context, WidgetRef ref) async {
  final name = TextEditingController();
  final gameweek = TextEditingController();
  final stake = TextEditingController(text: '100000');
  final accepted = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
    title: const Text('Create wager'),
    content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
      const SizedBox(height: 12),
      TextField(controller: gameweek, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Gameweek')),
      const SizedBox(height: 12),
      TextField(controller: stake, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Stake (integer cents)')),
    ])),
    actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Create'))],
  ));
  if (accepted == true) {
    await ref.read(adminResourceActionProvider.notifier).createWager({
      'name': name.text.trim(),
      'gameweek': int.tryParse(gameweek.text),
      'stake_cents': int.tryParse(stake.text),
      'visibility': 'public',
      'approval_required': false,
    });
  }
  name.dispose(); gameweek.dispose(); stake.dispose();
}

Future<void> _updateWager(BuildContext context, WidgetRef ref, Map<String, Object?> record) async {
  final id = record['id']?.toString();
  if (id == null) return;
  final status = ValueNotifier<String>(record['status']?.toString() ?? 'draft');
  final accepted = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
    title: Text(_first(record, const ['name', 'id'])),
    content: ValueListenableBuilder<String>(valueListenable: status, builder: (context, value, _) => DropdownButtonFormField<String>(
      initialValue: value,
      decoration: const InputDecoration(labelText: 'Wager status'),
      items: const ['draft', 'open', 'locked', 'scoring', 'settled', 'cancelled'].map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
      onChanged: (next) { if (next != null) status.value = next; },
    )),
    actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Update'))],
  ));
  if (accepted == true) await ref.read(adminResourceActionProvider.notifier).updateWagerStatus(id, status.value);
  status.dispose();
}

Future<void> _putSetting(BuildContext context, WidgetRef ref, {Map<String, Object?>? record}) async {
  final key = TextEditingController(text: record?['key']?.toString() ?? '');
  final value = TextEditingController(text: record == null ? 'true' : const JsonEncoder.withIndent('  ').convert(record['value']));
  final accepted = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
    title: Text(record == null ? 'Add setting' : 'Update setting'),
    content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: key, enabled: record == null, decoration: const InputDecoration(labelText: 'Key')),
      const SizedBox(height: 12),
      TextField(controller: value, minLines: 3, maxLines: 8, decoration: const InputDecoration(labelText: 'JSON value')),
    ])),
    actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save'))],
  ));
  if (accepted == true) {
    try {
      await ref.read(adminResourceActionProvider.notifier).putSetting(key.text.trim(), jsonDecode(value.text));
    } on FormatException {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Setting value must be valid JSON.')));
    }
  }
  key.dispose(); value.dispose();
}

Future<void> _verifyPayment(BuildContext context, WidgetRef ref, Map<String, Object?> record) async {
  final reference = record['reference']?.toString();
  if (reference == null) return;
  final accepted = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
    title: const Text('Verify payment?'),
    content: Text('The configured provider will be queried for $reference. No payment record will be deleted.'),
    actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Verify'))],
  ));
  if (accepted == true) await ref.read(adminResourceActionProvider.notifier).verifyPayment(reference);
}

Future<void> _adjustWallet(BuildContext context, WidgetRef ref, Map<String, Object?> record) async {
  final userId = record['user_id']?.toString();
  if (userId == null) return;
  final amount = TextEditingController();
  final reason = TextEditingController();
  final accepted = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
    title: Text('Adjust ${_first(record, const ['full_name', 'email', 'user_id'])}'),
    content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(signed: true), decoration: const InputDecoration(labelText: 'Amount in cents', helperText: 'Use a negative integer to debit.')),
      const SizedBox(height: 12),
      TextField(controller: reason, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Audit reason')),
    ])),
    actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Post adjustment'))],
  ));
  final parsed = int.tryParse(amount.text);
  if (accepted == true && parsed != null && parsed != 0) await ref.read(adminResourceActionProvider.notifier).adjustWallet(userId: userId, amountCents: parsed, reason: reason.text.trim());
  amount.dispose(); reason.dispose();
}

Future<void> _showJson(BuildContext context, Map<String, Object?> record) => showDialog<void>(context: context, builder: (context) => AlertDialog(
  title: const Text('Transaction detail'),
  content: SingleChildScrollView(child: SelectableText(const JsonEncoder.withIndent('  ').convert(record))),
  actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
));

String _first(Map<String, Object?> record, List<String> keys) {
  for (final key in keys) { final value = record[key]; if (value != null && '$value'.isNotEmpty) return '$value'; }
  return 'Record';
}

String _subtitle(Map<String, Object?> record, String title) {
  final amount = record['amount_cents'] ?? record['available_cents'] ?? record['stake_cents'];
  final text = _first(record, const ['email', 'provider', 'kind', 'currency', 'value', 'gameweek']);
  final parts = <String>[if (text != title && text != 'Record') text, if (amount is num) money(amount.toInt())];
  return parts.join(' · ');
}
