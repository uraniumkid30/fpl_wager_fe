import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpl_wager/app/theme/app_theme.dart';
import 'package:fpl_wager/core/network/providers.dart';
import 'package:fpl_wager/core/ui/app_notice.dart';
import 'package:fpl_wager/core/ui/app_widgets.dart';
import 'package:fpl_wager/features/withdrawals/domain/withdrawal_models.dart';
import 'package:fpl_wager/features/withdrawals/presentation/withdrawal_controller.dart';

/// Profile → Bank account: the one account a user's withdrawals are paid to.
///
/// To add or change it the user picks their bank from a list and types the
/// account number. "Check account" asks the payment provider whose account
/// that is and shows the name; only then can it be saved. The name is never
/// typed in, so money cannot be sent to an account under a made-up name.
///
/// A saved account can be changed or removed. There is only ever one.
class BankAccountScreen extends ConsumerStatefulWidget {
  const BankAccountScreen({super.key});

  @override
  ConsumerState<BankAccountScreen> createState() => _BankAccountScreenState();
}

class _BankAccountScreenState extends ConsumerState<BankAccountScreen> {
  final _form = GlobalKey<FormState>();
  final _number = TextEditingController();

  /// True while the form is open over a saved account ("Change").
  bool _editing = false;
  Bank? _bank;

  /// The provider's answer for the bank and number currently in the form.
  /// Cleared the moment either changes, so what is saved is always what was
  /// checked.
  BankAccount? _checked;
  bool _busy = false;

  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(bankAccountProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Bank account')),
      body: AsyncContent(
        value: account,
        onRetry: () => ref.invalidate(bankAccountProvider),
        data: (saved) => ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, 8, AppSpacing.md, 120),
          children: [
            Text(
              'Withdrawals are paid to this account. You can keep one '
              'account at a time.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            if (saved != null && !_editing)
              _SavedAccount(
                account: saved,
                busy: _busy,
                onChange: () => _startEditing(saved),
                onRemove: _remove,
              )
            else
              _buildForm(context, saved),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context, BankAccount? saved) {
    final scheme = Theme.of(context).colorScheme;
    final checked = _checked;
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            saved == null ? 'Add your bank account' : 'Change your bank account',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 14),
          // The bank is chosen from the provider's list, never typed.
          FormField<Bank>(
            initialValue: _bank,
            validator: (_) => _bank == null ? 'Choose your bank' : null,
            builder: (field) => InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _busy ? null : () => _pickBank(field),
              child: InputDecorator(
                isEmpty: _bank == null,
                decoration: InputDecoration(
                  labelText: 'Bank',
                  prefixIcon: const Icon(Icons.account_balance_outlined),
                  suffixIcon: const Icon(Icons.expand_more_rounded),
                  errorText: field.errorText,
                ),
                child: _bank == null ? null : Text(_bank!.name),
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _number,
            enabled: !_busy,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            decoration: const InputDecoration(
              labelText: 'Account number',
              prefixIcon: Icon(Icons.numbers_rounded),
              helperText: '10 digits',
            ),
            validator: (value) => (value ?? '').trim().length == 10
                ? null
                : 'Enter the 10-digit account number',
            onChanged: (_) {
              if (_checked != null) setState(() => _checked = null);
            },
          ),
          const SizedBox(height: 16),
          if (checked == null)
            FilledButton.icon(
              onPressed: _busy ? null : _check,
              icon: _busy
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.search_rounded),
              label: const Text('Check account'),
            )
          else ...[
            GradientPanel(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  const Icon(Icons.verified_rounded, color: AppColors.emerald),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ACCOUNT NAME',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.7,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          checked.accountName,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${checked.bankName} · ${checked.accountNumber}',
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Is this your account? Withdrawals will be sent here.',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _busy ? null : _save,
              icon: _busy
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_rounded),
              label: const Text('Yes, save this account'),
            ),
          ],
          if (saved != null) ...[
            const SizedBox(height: 6),
            TextButton(
              onPressed: _busy ? null : _cancelEditing,
              child: const Text('Cancel'),
            ),
          ],
        ],
      ),
    );
  }

  void _startEditing(BankAccount saved) {
    setState(() {
      _editing = true;
      _bank = Bank(name: saved.bankName, code: saved.bankCode);
      _number.text = saved.accountNumber;
      _checked = null;
    });
  }

  void _cancelEditing() {
    setState(() {
      _editing = false;
      _bank = null;
      _number.clear();
      _checked = null;
    });
  }

  Future<void> _pickBank(FormFieldState<Bank> field) async {
    final picked = await showModalBottomSheet<Bank>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => const _BankPicker(),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _bank = picked;
      _checked = null;
    });
    field.didChange(picked);
  }

  Future<void> _check() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final bank = _bank;
    if (bank == null) return;
    setState(() => _busy = true);
    try {
      final resolved = await ref.read(appGatewayProvider).resolveBankAccount(
            bankCode: bank.code,
            accountNumber: _number.text.trim(),
          );
      if (mounted) setState(() => _checked = resolved);
    } on Object catch (error) {
      if (mounted) AppNotice.error(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final checked = _checked;
    if (checked == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(appGatewayProvider).saveBankAccount(
            bankCode: checked.bankCode,
            accountNumber: checked.accountNumber,
          );
      if (!mounted) return;
      ref.invalidate(bankAccountProvider);
      // Wait for the saved account to load before closing the form, so the
      // page goes straight from the form to the new account.
      try {
        await ref.read(bankAccountProvider.future);
      } on Object {
        // The account is saved; only re-reading it failed. The page shows
        // its own "Try again" for that, so the save is still reported.
      }
      if (!mounted) return;
      setState(() {
        _editing = false;
        _bank = null;
        _number.clear();
        _checked = null;
      });
      AppNotice.success(context, 'Bank account saved.');
    } on Object catch (error) {
      if (mounted) AppNotice.error(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove bank account?'),
        content: const Text(
          'You will need to add an account again before your next '
          'withdrawal. Withdrawals you have already requested are not '
          'affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(appGatewayProvider).deleteBankAccount();
      if (!mounted) return;
      ref.invalidate(bankAccountProvider);
      AppNotice.success(context, 'Bank account removed.');
    } on Object catch (error) {
      if (mounted) AppNotice.error(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

/// The saved account, with the two things that can be done to it.
class _SavedAccount extends StatelessWidget {
  const _SavedAccount({
    required this.account,
    required this.busy,
    required this.onChange,
    required this.onRemove,
  });

  final BankAccount account;
  final bool busy;
  final VoidCallback onChange;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 2),
              Text(value, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GradientPanel(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              row('Bank', account.bankName),
              const Divider(height: 1),
              row('Account number', account.accountNumber),
              const Divider(height: 1),
              row('Account name', account.accountName),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: busy ? null : onChange,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Change'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: busy ? null : onRemove,
                style: OutlinedButton.styleFrom(foregroundColor: scheme.error),
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Remove'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// A searchable list of banks, shown as a sheet. Returns the bank tapped.
class _BankPicker extends ConsumerStatefulWidget {
  const _BankPicker();

  @override
  ConsumerState<_BankPicker> createState() => _BankPickerState();
}

class _BankPickerState extends ConsumerState<_BankPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final banks = ref.watch(banksProvider);
    return Padding(
      // Keep the list above the keyboard while the user types a search.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Search banks',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
                onChanged: (value) =>
                    setState(() => _query = value.trim().toLowerCase()),
              ),
            ),
            Expanded(
              child: AsyncContent(
                value: banks,
                onRetry: () => ref.invalidate(banksProvider),
                data: (items) {
                  final matches = _query.isEmpty
                      ? items
                      : items
                          .where((bank) => bank.name.toLowerCase().contains(_query))
                          .toList();
                  if (matches.isEmpty) {
                    return const EmptyState(
                      icon: Icons.account_balance_outlined,
                      title: 'No bank found',
                      message: 'Check the spelling and try again.',
                    );
                  }
                  return ListView.builder(
                    itemCount: matches.length,
                    itemBuilder: (context, index) => ListTile(
                      leading: const Icon(Icons.account_balance_outlined),
                      title: Text(matches[index].name),
                      onTap: () => Navigator.of(context).pop(matches[index]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
