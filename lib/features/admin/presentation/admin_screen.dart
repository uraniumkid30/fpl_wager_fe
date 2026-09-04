import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpl_wager/app/theme/app_theme.dart';
import 'package:fpl_wager/core/ui/app_widgets.dart';
import 'package:fpl_wager/features/admin/presentation/admin_controller.dart';
import 'package:go_router/go_router.dart';

const _resources = <String, String>{
  'users': 'Users',
  'wagers': 'Wagers',
  'payments': 'Payments',
  'wallets': 'Wallets',
  'transactions': 'Transactions',
  'settings': 'System settings',
};

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: _resources.length,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Administration'),
            bottom: TabBar(
              isScrollable: true,
              tabs: _resources.values
                  .map((label) => Tab(text: label))
                  .toList(),
            ),
          ),
          body: TabBarView(
            children: _resources.keys
                .map((resource) => _AdminCollection(resource: resource))
                .toList(),
          ),
        ),
      );
}

class _AdminCollection extends ConsumerWidget {
  const _AdminCollection({required this.resource});

  final String resource;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(adminCollectionProvider(resource));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(adminCollectionProvider(resource));
        await ref.read(adminCollectionProvider(resource).future);
      },
      child: value.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ListView(
          children: [
            EmptyState(
              icon: Icons.admin_panel_settings_outlined,
              title: 'Could not load ${_resources[resource]}',
              message: error.toString(),
            ),
          ],
        ),
        data: (items) => items.isEmpty
            ? ListView(
                children: [
                  EmptyState(
                    icon: Icons.inbox_outlined,
                    title: 'No ${_resources[resource]?.toLowerCase()}',
                    message: 'Records will appear here.',
                  ),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) => _RecordCard(
                  resource: resource,
                  record: items[index],
                ),
              ),
      ),
    );
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({
    required this.resource,
    required this.record,
  });

  final String resource;
  final Map<String, Object?> record;

  @override
  Widget build(BuildContext context) {
    final title = _first(
      record,
      const [
        'full_name',
        'name',
        'email',
        'reference',
        'key',
        'description',
        'id',
      ],
    );
    final subtitle = _first(
      record,
      const ['email', 'status', 'provider', 'currency', 'value', 'kind'],
    );

    return GradientPanel(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      onTap: resource == 'users' && record['id'] != null
          ? () => context.push('/admin/users/${record['id']}')
          : null,
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor:
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.13),
            child: Icon(
              _iconFor(resource),
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != title)
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (record['status'] != null) StatusPill('${record['status']}'),
          if (resource == 'users') const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}

class AdminUserScreen extends ConsumerStatefulWidget {
  const AdminUserScreen({required this.userId, super.key});

  final String userId;

  @override
  ConsumerState<AdminUserScreen> createState() => _AdminUserScreenState();
}

class _AdminUserScreenState extends ConsumerState<AdminUserScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  String? _loadedId;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(adminUserProvider(widget.userId));
    final action = ref.watch(adminUserActionProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('User account')),
      body: AsyncContent(
        value: value,
        onRetry: () => ref.invalidate(adminUserProvider(widget.userId)),
        data: (user) {
          if (_loadedId != user.id) {
            _loadedId = user.id;
            _name.text = user.fullName;
            _phone.text = user.phone;
          }

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              GradientPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.email,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        StatusPill(user.role),
                        StatusPill(user.status),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Full name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phone,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
              const SizedBox(height: 16),
              if (action.hasError) ...[
                Text(
                  action.error.toString(),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              FilledButton(
                onPressed: action.isLoading
                    ? null
                    : () => _update({
                          'full_name': _name.text.trim(),
                          'phone': _phone.text.trim(),
                        }),
                child: const Text('Save profile'),
              ),
              const SizedBox(height: 22),
              DropdownButtonFormField<String>(
                initialValue: user.status,
                decoration: const InputDecoration(labelText: 'Account status'),
                items: const ['active', 'inactive', 'deactivated', 'banned']
                    .map(
                      (item) => DropdownMenuItem(
                        value: item,
                        child: Text(item),
                      ),
                    )
                    .toList(),
                onChanged: action.isLoading
                    ? null
                    : (next) {
                        if (next != null) {
                          _update({'status': next});
                        }
                      },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: user.role,
                decoration: const InputDecoration(
                  labelText: 'Role (superadmin only)',
                ),
                items: const ['user', 'admin', 'superadmin']
                    .map(
                      (item) => DropdownMenuItem(
                        value: item,
                        child: Text(item),
                      ),
                    )
                    .toList(),
                onChanged: action.isLoading
                    ? null
                    : (next) {
                        if (next != null) {
                          _update({'role': next});
                        }
                      },
              ),
              const SizedBox(height: 28),
              OutlinedButton.icon(
                onPressed: action.isLoading ? null : _deactivate,
                icon: const Icon(Icons.person_off_outlined),
                label: const Text('Deactivate user'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _update(Map<String, Object?> changes) async {
    await ref
        .read(adminUserActionProvider.notifier)
        .updateUser(widget.userId, changes);
  }

  Future<void> _deactivate() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deactivate this user?'),
        content: const Text(
          'Their sessions will be revoked. This action is audited.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final ok = await ref
        .read(adminUserActionProvider.notifier)
        .deactivateUser(widget.userId);

    if (ok && mounted) {
      context.pop();
    }
  }
}

String _first(Map<String, Object?> record, List<String> keys) {
  for (final key in keys) {
    final value = record[key];
    if (value != null && '$value'.isNotEmpty) {
      return '$value';
    }
  }

  return 'Record';
}

IconData _iconFor(String resource) => switch (resource) {
      'users' => Icons.people_outline_rounded,
      'wagers' => Icons.emoji_events_outlined,
      'payments' => Icons.payments_outlined,
      'wallets' => Icons.account_balance_wallet_outlined,
      'transactions' => Icons.receipt_long_outlined,
      _ => Icons.tune_rounded,
    };
