import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fplboardman/app/theme/app_theme.dart';
import 'package:fplboardman/core/network/providers.dart';
import 'package:fplboardman/core/ui/app_notice.dart';
import 'package:fplboardman/core/ui/app_widgets.dart';
import 'package:fplboardman/features/auth/domain/web_link.dart';
import 'package:fplboardman/features/linked_browsers/presentation/linked_browsers_controller.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Profile → Linked browsers: the browsers signed in to this account by
/// scanning their QR code, each with a way to sign it out, and the button
/// that scans a new one.
class LinkedBrowsersScreen extends ConsumerWidget {
  const LinkedBrowsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final links = ref.watch(webLinksProvider);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Scaffold(
      appBar: AppBar(title: const Text('Linked browsers')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(webLinksProvider);
          await ref.read(webLinksProvider.future);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, 8, AppSpacing.md, 48),
          children: [
            GradientPanel(
              colors: const [Color(0xFF0B4939), Color(0xFF2A174C)],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.qr_code_scanner_rounded, color: AppColors.lime, size: 34),
                  const SizedBox(height: 12),
                  Text(
                    'Use FPLboardman on a computer',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Open the FPLboardman website, then scan the code it shows. '
                    'That browser stays signed in to your account for 90 days.',
                    style: TextStyle(color: Color(0xFFD1E3DC), height: 1.45),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => context.push('/linked-browsers/scan'),
                      icon: const Icon(Icons.qr_code_scanner_rounded),
                      label: const Text('Link a browser'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('Signed in', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            links.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => Text('$error'),
              data: (items) => items.isEmpty
                  ? Text(
                      'No browsers are signed in to your account.',
                      style: TextStyle(color: muted),
                    )
                  : Column(
                      children: [
                        for (final link in items)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _LinkTile(link: link),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LinkTile extends ConsumerStatefulWidget {
  const _LinkTile({required this.link});
  final WebLink link;

  @override
  ConsumerState<_LinkTile> createState() => _LinkTileState();
}

class _LinkTileState extends ConsumerState<_LinkTile> {
  bool _busy = false;

  Future<void> _unlink() async {
    final link = widget.link;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Sign out ${link.label}?'),
        content: const Text(
          'That browser is signed out of your account within a few minutes. '
          'You can link it again by scanning its code.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(appGatewayProvider).revokeWebLink(link.id);
      ref.invalidate(webLinksProvider);
      if (mounted) AppNotice.success(context, '${link.label} was signed out.');
    } on Object catch (error) {
      if (mounted) AppNotice.error(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final link = widget.link;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final date = DateFormat('d MMM y');
    final daysLeft = link.expiresAt.difference(DateTime.now()).inDays;
    return GradientPanel(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.13),
            child: Icon(Icons.computer_rounded, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(link.label, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  'Linked ${date.format(link.createdAt)} · '
                  '${daysLeft <= 0 ? 'expires today' : 'expires in $daysLeft ${daysLeft == 1 ? 'day' : 'days'}'}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _busy ? null : _unlink,
            child: _busy
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}
