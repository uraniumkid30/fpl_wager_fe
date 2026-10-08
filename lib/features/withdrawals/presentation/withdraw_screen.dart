import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fplboardman/app/theme/app_theme.dart';
import 'package:fplboardman/core/network/providers.dart';
import 'package:fplboardman/core/ui/app_notice.dart';
import 'package:fplboardman/core/ui/app_widgets.dart';
import 'package:fplboardman/features/dashboard/domain/dashboard.dart';
import 'package:fplboardman/features/dashboard/presentation/dashboard_controller.dart';
import 'package:fplboardman/features/wallet/presentation/wallet_controller.dart';
import 'package:fplboardman/features/withdrawals/domain/withdrawal_models.dart';
import 'package:fplboardman/features/withdrawals/presentation/withdrawal_controller.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

/// Profile → Withdraw.
///
/// Before a user can withdraw they need a verified email and a bank account.
/// Whichever is missing is shown first, with a button that takes them
/// straight to it. With both in place they enter an amount and send the
/// request; an administrator approves it before any money goes to the bank.
///
/// Below the form is every withdrawal they have made and where it stands.
class WithdrawScreen extends ConsumerWidget {
  const WithdrawScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Withdraw')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dashboardProvider);
          ref.invalidate(bankAccountProvider);
          ref.invalidate(withdrawalsProvider);
          await ref.read(dashboardProvider.future);
        },
        child: AsyncContent(
          value: dashboard,
          onRetry: () => ref.invalidate(dashboardProvider),
          data: (value) => _WithdrawBody(dashboard: value),
        ),
      ),
    );
  }
}

class _WithdrawBody extends ConsumerWidget {
  const _WithdrawBody({required this.dashboard});

  final Dashboard dashboard;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(bankAccountProvider);
    final history = ref.watch(withdrawalsProvider);
    final emailVerified = dashboard.user.emailVerified;
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 8, AppSpacing.md, 120),
      children: [
        GradientPanel(
          colors: const [Color(0xFF0B4939), Color(0xFF2A174C)],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'AVAILABLE TO WITHDRAW',
                style: TextStyle(
                  color: Color(0xFFC9DED7),
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  letterSpacing: 0.7,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                money(dashboard.wallet.availableCents),
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: AppColors.lime,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Money locked in active games cannot be withdrawn until the '
                'game ends.',
                style: TextStyle(color: Color(0xFFD1E3DC), height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),

        // What is still needed, in the order to do it.
        if (!emailVerified) ...[
          _Requirement(
            icon: Icons.mark_email_unread_outlined,
            title: 'Verify your email first',
            message: 'We confirm every withdrawal by email, so your address '
                'has to be verified before you can withdraw.',
            action: 'Verify email',
            onAction: () async {
              await context.push('/verify-email');
              if (context.mounted) ref.invalidate(dashboardProvider);
            },
          ),
          const SizedBox(height: 12),
        ],
        account.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => _Requirement(
            icon: Icons.cloud_off_rounded,
            title: 'Could not load your bank account',
            message: error.toString(),
            action: 'Try again',
            onAction: () => ref.invalidate(bankAccountProvider),
          ),
          data: (bank) {
            if (bank == null) {
              return _Requirement(
                icon: Icons.account_balance_outlined,
                title: 'Add your bank account',
                message: 'Tell us which account to pay. You only do this once.',
                action: 'Add bank account',
                onAction: () => context.push('/bank-account'),
              );
            }
            if (!emailVerified) {
              return _Destination(bank: bank);
            }
            return _WithdrawForm(
              bank: bank,
              availableCents: dashboard.wallet.availableCents,
              // Until the list has loaded, assume the usual minimum; the
              // server enforces the real one either way.
              minimumCents:
                  history.hasValue ? history.requireValue.minimumCents : 100000,
            );
          },
        ),

        const SizedBox(height: 28),
        Text('Your withdrawals', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        history.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => Text(
            error.toString(),
            style: TextStyle(color: scheme.error),
          ),
          data: (overview) => overview.items.isEmpty
              ? Text(
                  'Nothing yet. Your requests appear here with their status.',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                )
              : Column(
                  children: overview.items
                      .map((item) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _WithdrawalTile(item: item),
                          ))
                      .toList(),
                ),
        ),
      ],
    );
  }
}

/// Something the user must do before they can withdraw, with the button that
/// takes them there.
class _Requirement extends StatelessWidget {
  const _Requirement({
    required this.icon,
    required this.title,
    required this.message,
    required this.action,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => GradientPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        message,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            FilledButton(onPressed: onAction, child: Text(action)),
          ],
        ),
      );
}

/// The account the money will go to, with a link to change it.
class _Destination extends StatelessWidget {
  const _Destination({required this.bank});

  final BankAccount bank;

  @override
  Widget build(BuildContext context) => GradientPanel(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.13),
              child: Icon(
                Icons.account_balance_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bank.accountName,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    bank.summary,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => context.push('/bank-account'),
              child: const Text('Change'),
            ),
          ],
        ),
      );
}

class _WithdrawForm extends ConsumerStatefulWidget {
  const _WithdrawForm({
    required this.bank,
    required this.availableCents,
    required this.minimumCents,
  });

  final BankAccount bank;
  final int availableCents;
  final int minimumCents;

  @override
  ConsumerState<_WithdrawForm> createState() => _WithdrawFormState();
}

class _WithdrawFormState extends ConsumerState<_WithdrawForm> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  bool _busy = false;

  /// Identifies one withdrawal to the server. It is kept until the request
  /// is known to have succeeded, so that trying again after a lost
  /// connection cannot create a second withdrawal for the same tap.
  String _requestKey = const Uuid().v4();

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tooLittle = widget.availableCents < widget.minimumCents;
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Pay to', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          _Destination(bank: widget.bank),
          const SizedBox(height: 18),
          TextFormField(
            controller: _amount,
            enabled: !_busy && !tooLittle,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            decoration: InputDecoration(
              labelText: 'Amount',
              prefixText: '₦ ',
              helperText: 'Minimum ${money(widget.minimumCents)}',
              suffixIcon: TextButton(
                onPressed: _busy || tooLittle
                    ? null
                    : () {
                        _amount.text =
                            (widget.availableCents / 100).toStringAsFixed(2);
                        _newRequest();
                      },
                child: const Text('All'),
              ),
            ),
            validator: _validateAmount,
            // A different amount is a different request.
            onChanged: (_) => _newRequest(),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy || tooLittle ? null : _submit,
            icon: _busy
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.north_east_rounded),
            label: const Text('Withdraw'),
          ),
          const SizedBox(height: 10),
          Text(
            tooLittle
                ? 'You need at least ${money(widget.minimumCents)} available '
                    'to withdraw.'
                : 'Every withdrawal is reviewed before it is paid. The '
                    'amount leaves your wallet now and comes straight back '
                    'if the request is not approved or the transfer fails.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.4,
                ),
          ),
        ],
      ),
    );
  }

  void _newRequest() => _requestKey = const Uuid().v4();

  String? _validateAmount(String? value) {
    final cents = nairaToCents(value ?? '');
    if (cents == null) return 'Enter an amount';
    if (cents < widget.minimumCents) {
      return 'The minimum is ${money(widget.minimumCents)}';
    }
    if (cents > widget.availableCents) {
      return 'You have ${money(widget.availableCents)} available';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final cents = nairaToCents(_amount.text);
    if (cents == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Withdraw ${money(cents)}?'),
        content: Text(
          'To ${widget.bank.accountName}\n${widget.bank.summary}\n\n'
          'An administrator reviews the request before it is paid.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Withdraw'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(appGatewayProvider).requestWithdrawal(
            amountCents: cents,
            idempotencyKey: _requestKey,
          );
      _newRequest();
      if (!mounted) return;
      ref.invalidate(withdrawalsProvider);
      ref.invalidate(walletProvider);
      ref.invalidate(dashboardProvider);
      _amount.clear();
      AppNotice.success(
        context,
        'Withdrawal requested. We will email you when it is paid.',
      );
    } on Object catch (error) {
      if (mounted) AppNotice.error(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _WithdrawalTile extends StatelessWidget {
  const _WithdrawalTile({required this.item});

  final Withdrawal item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = item.isPaid
        ? AppColors.emerald
        : item.wasRefunded
            ? scheme.error
            : AppColors.purple;
    final bank = item.bank;
    return GradientPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  money(item.amountCents),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              StatusPill(item.statusLabel, color: color),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            [
              if (bank != null) bank.summary,
              DateFormat('d MMM y · HH:mm').format(item.createdAt.toLocal()),
            ].join('  ·  '),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 6),
          Text(item.statusNote, style: const TextStyle(height: 1.35)),
          if (item.reason.isNotEmpty && item.wasRefunded) ...[
            const SizedBox(height: 4),
            Text(
              'Reason: ${item.reason}',
              style: TextStyle(color: scheme.onSurfaceVariant, height: 1.35),
            ),
          ],
        ],
      ),
    );
  }
}
