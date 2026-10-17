import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fplboardman/app/theme/app_theme.dart';
import 'package:fplboardman/core/errors/app_exception.dart';
import 'package:fplboardman/core/network/providers.dart';
import 'package:fplboardman/core/ui/app_notice.dart';
import 'package:fplboardman/core/ui/app_widgets.dart';
import 'package:fplboardman/features/auth/domain/web_link.dart';
import 'package:fplboardman/features/linked_browsers/presentation/linked_browsers_controller.dart';
import 'package:go_router/go_router.dart';

/// Which browser a scanned code belongs to, before approving it.
final _qrRequestProvider = FutureProvider.autoDispose.family<QrRequest, String>(
  (ref, code) => ref.watch(appGatewayProvider).scanQrLogin(code),
);

/// Approve signing a browser in, after scanning its QR code (in the app, or
/// with the phone's camera, which opens the app here).
class LinkBrowserScreen extends ConsumerStatefulWidget {
  const LinkBrowserScreen({required this.code, super.key});
  final String code;

  @override
  ConsumerState<LinkBrowserScreen> createState() => _LinkBrowserScreenState();
}

class _LinkBrowserScreenState extends ConsumerState<LinkBrowserScreen> {
  bool _busy = false;
  bool _done = false;

  void _leave() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/linked-browsers');
    }
  }

  Future<void> _answer({required bool approve}) async {
    setState(() => _busy = true);
    try {
      final gateway = ref.read(appGatewayProvider);
      if (approve) {
        await gateway.approveQrLogin(widget.code);
        ref.invalidate(webLinksProvider);
        if (!mounted) return;
        setState(() => _done = true);
      } else {
        await gateway.declineQrLogin(widget.code);
        if (!mounted) return;
        AppNotice.info(context, 'Sign-in declined. That browser was not signed in.');
        _leave();
      }
    } on Object catch (error) {
      if (mounted) AppNotice.error(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = ref.watch(_qrRequestProvider(widget.code));
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Scaffold(
      appBar: AppBar(title: const Text('Sign in on a browser')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: request.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => _Problem(
                  message: error is AppException && error.code == 'QR_EXPIRED'
                      ? 'This code has expired or was already used. Scan the '
                          'new code on the website.'
                      : '$error',
                  onScanAgain: () => context.pushReplacement('/linked-browsers/scan'),
                ),
                data: (value) => _done
                    ? _Done(label: value.label, days: value.linkDays, onClose: _leave)
                    : GradientPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Icon(Icons.computer_rounded, size: 44, color: theme.colorScheme.primary),
                            const SizedBox(height: 14),
                            Text(
                              'Sign in on ${value.label}?',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'That browser will be signed in to your FPLboardman '
                              'account, wallet included, for ${value.linkDays} days. '
                              'Only approve it if you are signing in there yourself '
                              'right now.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: muted, height: 1.45),
                            ),
                            const SizedBox(height: 22),
                            FilledButton.icon(
                              onPressed: _busy ? null : () => _answer(approve: true),
                              icon: _busy
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.check_rounded),
                              label: const Text('Yes, sign it in'),
                            ),
                            const SizedBox(height: 10),
                            OutlinedButton(
                              onPressed: _busy ? null : () => _answer(approve: false),
                              child: const Text('No, it wasn’t me'),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Done extends StatelessWidget {
  const _Done({required this.label, required this.days, required this.onClose});
  final String label;
  final int days;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => GradientPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.check_circle_rounded, size: 52, color: AppColors.emerald),
            const SizedBox(height: 14),
            Text(
              '$label is signed in',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'It stays signed in for $days days. You can sign it out any time '
              'from Profile, Linked browsers.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.45),
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: onClose, child: const Text('Done')),
          ],
        ),
      );
}

class _Problem extends StatelessWidget {
  const _Problem({required this.message, required this.onScanAgain});
  final String message;
  final VoidCallback onScanAgain;

  @override
  Widget build(BuildContext context) => GradientPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.qr_code_2_rounded, size: 44, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onScanAgain,
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: const Text('Scan again'),
            ),
          ],
        ),
      );
}
