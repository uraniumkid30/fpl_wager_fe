import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpl_wager/app/theme/app_theme.dart';
import 'package:fpl_wager/core/ui/app_widgets.dart';
import 'package:fpl_wager/features/admin/presentation/admin_providers.dart';
import 'package:go_router/go_router.dart';

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
              GradientPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(user.email, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Wrap(spacing: 8, children: [StatusPill(user.role), StatusPill(user.status)]),
              ])),
              const SizedBox(height: 20),
              TextField(controller: _name, decoration: const InputDecoration(labelText: 'Full name')),
              const SizedBox(height: 12),
              TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone')),
              const SizedBox(height: 16),
              if (action.hasError) ...[
                Text(action.error.toString(), style: TextStyle(color: Theme.of(context).colorScheme.error)),
                const SizedBox(height: 12),
              ],
              FilledButton(
                onPressed: action.isLoading ? null : () => _update({'full_name': _name.text.trim(), 'phone': _phone.text.trim()}),
                child: const Text('Save profile'),
              ),
              const SizedBox(height: 22),
              DropdownButtonFormField<String>(
                key: ValueKey('status-${user.status}'),
                initialValue: user.status,
                decoration: const InputDecoration(labelText: 'Account status'),
                items: const ['active', 'inactive', 'deactivated', 'banned'].map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
                onChanged: action.isLoading ? null : (next) { if (next != null && next != user.status) _update({'status': next}); },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey('role-${user.role}'),
                initialValue: user.role,
                decoration: const InputDecoration(labelText: 'Role (superadmin only)'),
                items: const ['user', 'admin', 'superadmin'].map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
                onChanged: action.isLoading ? null : (next) { if (next != null && next != user.role) _update({'role': next}); },
              ),
              const SizedBox(height: 28),
              OutlinedButton.icon(onPressed: action.isLoading ? null : _deactivate, icon: const Icon(Icons.person_off_outlined), label: const Text('Deactivate user')),
            ],
          );
        },
      ),
    );
  }

  Future<void> _update(Map<String, Object?> changes) async {
    final ok = await ref.read(adminUserActionProvider.notifier).updateUser(widget.userId, changes);
    if (ok && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User updated')));
  }

  Future<void> _deactivate() async {
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Deactivate this user?'),
      content: const Text('Their sessions will be revoked. This action is audited.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Deactivate')),
      ],
    ));
    if (confirmed != true) return;
    final ok = await ref.read(adminUserActionProvider.notifier).deactivateUser(widget.userId);
    if (ok && mounted) context.pop();
  }
}
