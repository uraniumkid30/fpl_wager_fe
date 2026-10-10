import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fplboardman/features/pools/domain/pool.dart';

/// "How the prize is paid" on the create and edit pool forms.
///
/// Winner takes all, or a split between a number of winners. For a split
/// the suggested shares are shown and can be changed. Problems are shown as
/// they happen, so the creator never has to press Create to find out.
class PayoutEditor extends StatefulWidget {
  const PayoutEditor({
    required this.initial,
    required this.rule,
    required this.maxMembers,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });

  final PayoutChoice initial;

  /// The winners limit the server enforces.
  final WinnerRule rule;

  /// The form's "Maximum managers" field: the winners must be payable when
  /// the pool is full.
  final TextEditingController maxMembers;
  final ValueChanged<PayoutChoice> onChanged;
  final bool enabled;

  /// What is wrong with [choice], or null if it can be submitted.
  static String? problem(PayoutChoice choice, WinnerRule rule, int? maxMembers) {
    if (choice.mode != PayoutMode.split) return null;
    return winnersProblem(choice.winners, rule, maxMembers) ??
        (choice.shares == null ? null : sharesProblem(choice.shares!));
  }

  /// What is wrong with a number of winners, or null.
  static String? winnersProblem(int? winners, WinnerRule rule, int? maxMembers) {
    if (winners == null) return 'Enter how many managers win.';
    if (winners < 2) {
      return 'A split needs at least 2 winners. For one, choose Winner takes all.';
    }
    if (winners > rule.maxWinners) {
      return 'A pool can have at most ${rule.maxWinners} winners.';
    }
    if (maxMembers != null && maxMembers > 0 && winners > rule.cap(maxMembers)) {
      final allowed = rule.cap(maxMembers);
      return 'With at most $maxMembers managers, at most $allowed can win '
          '(${rule.description}). '
          'Allow more managers or choose fewer winners.';
    }
    return null;
  }

  @override
  State<PayoutEditor> createState() => _PayoutEditorState();
}

class _PayoutEditorState extends State<PayoutEditor> {
  late PayoutMode _mode = widget.initial.mode;
  late final _winners = TextEditingController(
    text: '${widget.initial.winners < 2 ? 3 : widget.initial.winners}',
  );
  late bool _custom = widget.initial.shares != null;
  List<TextEditingController> _shares = [];

  @override
  void initState() {
    super.initState();
    _resetShares(widget.initial.shares);
    widget.maxMembers.addListener(_refresh);
  }

  @override
  void didUpdateWidget(PayoutEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.maxMembers != widget.maxMembers) {
      oldWidget.maxMembers.removeListener(_refresh);
      widget.maxMembers.addListener(_refresh);
    }
  }

  @override
  void dispose() {
    widget.maxMembers.removeListener(_refresh);
    _winners.dispose();
    for (final controller in _shares) {
      controller.dispose();
    }
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  int? get _winnerCount => int.tryParse(_winners.text.trim());

  int? get _maxMembers {
    final value = int.tryParse(widget.maxMembers.text.trim());
    return value == null || value <= 0 ? null : value;
  }

  /// One share field per winner, filled with [shares] or the suggestion.
  void _resetShares([List<int>? shares]) {
    for (final controller in _shares) {
      controller.dispose();
    }
    final typed = _winnerCount ?? 0;
    final count = typed < 0
        ? 0
        : typed > widget.rule.maxWinners
            ? widget.rule.maxWinners
            : typed;
    final values = shares != null && shares.length == count
        ? shares
        : defaultShares(count);
    _shares = [
      for (final share in values) TextEditingController(text: percentInput(share)),
    ];
  }

  List<int> get _typedShares {
    final values = <int>[];
    for (final controller in _shares) {
      values.add(parsePercent(controller.text) ?? 0);
    }
    return values;
  }

  PayoutChoice get _choice => PayoutChoice(
        mode: _mode,
        winners: _winnerCount ?? 0,
        shares: _mode == PayoutMode.split && _custom ? _typedShares : null,
      );

  void _changed({bool sharesFollowWinners = false}) {
    setState(() {
      if (sharesFollowWinners) _resetShares();
    });
    widget.onChanged(_choice);
  }

  void _step(int by) {
    var next = (_winnerCount ?? 1) + by;
    if (next < 2) next = 2;
    if (next > widget.rule.maxWinners) next = widget.rule.maxWinners;
    _winners.text = '$next';
    _changed(sharesFollowWinners: true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = scheme.onSurfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('How the prize is paid', style: theme.textTheme.titleMedium),
        const SizedBox(height: 10),
        SegmentedButton<PayoutMode>(
          segments: const [
            ButtonSegment(
              value: PayoutMode.winnerTakesAll,
              icon: Icon(Icons.emoji_events_outlined),
              label: Text('Winner takes all'),
            ),
            ButtonSegment(
              value: PayoutMode.split,
              icon: Icon(Icons.groups_outlined),
              label: Text('Split'),
            ),
          ],
          selected: {_mode},
          showSelectedIcon: false,
          onSelectionChanged: widget.enabled
              ? (selection) {
                  _mode = selection.single;
                  _changed();
                }
              : null,
        ),
        const SizedBox(height: 10),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _mode == PayoutMode.winnerTakesAll
              ? _Note(
                  icon: Icons.emoji_events_outlined,
                  text: '1st place takes the whole prize pool. If managers '
                      'tie for 1st, the draw rule above decides.',
                )
              : _splitSettings(context, muted),
        ),
      ],
    );
  }

  Widget _splitSettings(BuildContext context, Color muted) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final rule = widget.rule;
    final winners = _winnerCount;
    final winnersError = PayoutEditor.winnersProblem(winners, rule, _maxMembers);
    final shares = _custom ? _typedShares : defaultShares(winners ?? 0);
    final sharesError = _custom && winnersError == null ? sharesProblem(shares) : null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.30),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Number of winners', style: theme.textTheme.titleSmall),
              ),
              IconButton.filledTonal(
                tooltip: 'Fewer winners',
                onPressed: widget.enabled && (winners ?? 0) > 2 ? () => _step(-1) : null,
                icon: const Icon(Icons.remove_rounded),
              ),
              SizedBox(
                width: 64,
                child: TextField(
                  controller: _winners,
                  enabled: widget.enabled,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    errorText: winnersError == null ? null : '',
                    errorStyle: const TextStyle(height: 0, fontSize: 0),
                  ),
                  onChanged: (_) => _changed(sharesFollowWinners: true),
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'More winners',
                onPressed: widget.enabled && (winners ?? 0) < rule.maxWinners ? () => _step(1) : null,
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (winnersError != null)
            _Message(text: winnersError, error: true)
          else
            _Message(
              text: 'All $winners places are paid once '
                  '${rule.managersNeeded(winners!)} managers have joined '
                  '(${rule.description}, up to ${rule.maxWinners}). With fewer, '
                  'fewer places are paid and their shares grow to cover the '
                  'whole prize.',
            ),
          if (winnersError == null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _custom ? 'Your shares' : 'Suggested shares',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                TextButton.icon(
                  onPressed: widget.enabled
                      ? () {
                          _custom = !_custom;
                          if (!_custom) _resetShares();
                          _changed();
                        }
                      : null,
                  icon: Icon(_custom ? Icons.restart_alt_rounded : Icons.tune_rounded, size: 18),
                  label: Text(_custom ? 'Use suggested' : 'Change shares'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (_custom)
              ..._shareFields(context, shares)
            else
              _ShareBars(shares: shares),
            if (_custom) ...[
              const SizedBox(height: 8),
              sharesError == null
                  ? const _Message(text: 'Adds up to 100%.', ok: true)
                  : _Message(text: sharesError, error: true),
            ] else
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Optional: tap "Change shares" to set your own. Each place '
                  'gets at least as much as the one below it.',
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
              ),
          ],
        ],
      ),
    );
  }

  List<Widget> _shareFields(BuildContext context, List<int> shares) {
    final theme = Theme.of(context);
    final top = shares.fold<int>(1, (best, share) => share > best ? share : best);
    return [
      for (var index = 0; index < _shares.length; index++)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              SizedBox(
                width: 44,
                child: Text(placeLabel(index + 1), style: theme.textTheme.labelLarge),
              ),
              SizedBox(
                width: 92,
                child: TextField(
                  controller: _shares[index],
                  enabled: widget.enabled,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    LengthLimitingTextInputFormatter(6),
                  ],
                  textAlign: TextAlign.end,
                  decoration: const InputDecoration(
                    isDense: true,
                    suffixText: '%',
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  ),
                  onChanged: (_) => _changed(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: shares[index] >= top ? 1.0 : shares[index] / top,
                    minHeight: 8,
                  ),
                ),
              ),
            ],
          ),
        ),
    ];
  }
}

/// The suggested shares, as labelled bars.
class _ShareBars extends StatelessWidget {
  const _ShareBars({required this.shares});

  final List<int> shares;

  /// Beyond this many places the rest are summed up in one line.
  static const _shown = 8;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final top = shares.isEmpty ? 1 : shares.first;
    final hidden = shares.length - _shown;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < shares.length && index < _shown; index++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                SizedBox(
                  width: 44,
                  child: Text(placeLabel(index + 1), style: theme.textTheme.labelLarge),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: shares[index] / top,
                      minHeight: 8,
                    ),
                  ),
                ),
                SizedBox(
                  width: 64,
                  child: Text(
                    percentLabel(shares[index]),
                    textAlign: TextAlign.end,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        if (hidden > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '…and $hidden more places, '
              '${percentLabel(shares.skip(_shown).fold(0, (sum, share) => sum + share))} between them.',
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
          ),
      ],
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.30),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(text)),
          ],
        ),
      );
}

/// A one-line explanation under a field: an error in red, a confirmation in
/// green, or a hint in the muted colour.
class _Message extends StatelessWidget {
  const _Message({required this.text, this.error = false, this.ok = false});

  final String text;
  final bool error;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = error
        ? scheme.error
        : ok
            ? const Color(0xFF2E9E5B)
            : scheme.onSurfaceVariant;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(
            error
                ? Icons.error_outline_rounded
                : ok
                    ? Icons.check_circle_outline_rounded
                    : Icons.info_outline_rounded,
            size: 16,
            color: color,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color, height: 1.35),
          ),
        ),
      ],
    );
  }
}
