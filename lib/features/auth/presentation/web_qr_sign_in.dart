import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fplboardman/core/config/app_config.dart';
import 'package:fplboardman/core/network/providers.dart';
import 'package:fplboardman/features/auth/domain/web_link.dart';
import 'package:fplboardman/features/auth/presentation/auth_controller.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// "Scan with your phone" on the website, like WhatsApp Web.
///
/// Shows a QR code and keeps asking the server whether the phone app has
/// approved it. A code lasts two minutes; a new one replaces it on its own,
/// for a while, then the page waits for a tap so an idle tab does not keep
/// asking forever. Once the phone approves, this browser is signed in for
/// 90 days.
class WebQrSignIn extends ConsumerStatefulWidget {
  const WebQrSignIn({super.key});

  @override
  ConsumerState<WebQrSignIn> createState() => _WebQrSignInState();
}

class _WebQrSignInState extends ConsumerState<WebQrSignIn> {
  /// New codes made without anyone touching the page before it stops and
  /// waits (about 20 minutes).
  static const _autoRenewals = 10;
  static const _pollEvery = Duration(seconds: 2);

  QrLogin? _login;
  QrStatus _status = QrStatus.pending;
  Timer? _timer;
  bool _polling = false;
  bool _loading = false;
  int _renewals = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _newCode();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _newCode({bool byUser = false}) async {
    if (byUser) _renewals = 0;
    _timer?.cancel();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final login = await ref.read(appGatewayProvider).createQrLogin();
      if (!mounted) return;
      setState(() {
        _login = login;
        _status = QrStatus.pending;
        _loading = false;
      });
      _timer = Timer.periodic(_pollEvery, (_) => _poll());
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$error';
      });
    }
  }

  Future<void> _poll() async {
    final login = _login;
    if (login == null || _polling || !mounted) return;
    _polling = true;
    try {
      final poll = await ref.read(appGatewayProvider).pollQrLogin(login);
      if (!mounted) return;
      final session = poll.session;
      if (session != null) {
        _timer?.cancel();
        // Signed in: the router takes the browser into the app.
        ref.read(authControllerProvider.notifier).accept(session);
        return;
      }
      switch (poll.status) {
        case QrStatus.expired:
        case QrStatus.consumed:
          _timer?.cancel();
          if (_renewals < _autoRenewals) {
            _renewals++;
            unawaited(_newCode());
          } else {
            setState(() => _status = QrStatus.expired);
          }
        case QrStatus.declined:
          _timer?.cancel();
          setState(() => _status = QrStatus.declined);
        case QrStatus.pending:
        case QrStatus.scanned:
        case QrStatus.approved:
          if (poll.status != _status) setState(() => _status = poll.status);
      }
    } on Object {
      // A missed poll is tried again two seconds later.
    } finally {
      _polling = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final login = _login;
    final days = login?.linkDays ?? 90;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Sign in with your phone',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: SizedBox.square(
            dimension: 232,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: _code(login, theme),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_status == QrStatus.scanned)
          _Note(
            icon: Icons.phonelink_lock_rounded,
            text: 'Code scanned. Approve the sign-in on your phone.',
            color: theme.colorScheme.primary,
          )
        else ...[
          _Step(number: 1, text: 'Open FPLboardman on your phone.'),
          _Step(number: 2, text: 'Go to Profile, then Linked browsers.'),
          _Step(number: 3, text: 'Tap Link a browser and point your phone at this code.'),
        ],
        const SizedBox(height: 8),
        Text(
          'This browser then stays signed in for $days days, or until you '
          'unlink it from your phone.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(color: muted),
        ),
      ],
    );
  }

  Widget _code(QrLogin? login, ThemeData theme) {
    if (_loading && login == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && login == null) {
      return _Overlay(
        text: 'Could not get a sign-in code.',
        action: 'Try again',
        onAction: () => _newCode(byUser: true),
      );
    }
    if (login == null) return const SizedBox.shrink();
    final qr = QrImageView(
      data: AppConfig.webLinkUrl(login.code),
      version: QrVersions.auto,
      backgroundColor: Colors.white,
      padding: EdgeInsets.zero,
      eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF06201B)),
      dataModuleStyle: const QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: Color(0xFF06201B),
      ),
    );
    final String? cover = switch (_status) {
      QrStatus.expired => 'The code expired.',
      QrStatus.declined => 'The sign-in was declined on the phone.',
      _ => null,
    };
    if (cover == null && !_loading) return qr;
    return Stack(
      fit: StackFit.expand,
      children: [
        Opacity(opacity: 0.12, child: qr),
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else
          _Overlay(
            text: cover!,
            action: 'Show a new code',
            onAction: () => _newCode(byUser: true),
          ),
      ],
    );
  }
}

class _Overlay extends StatelessWidget {
  const _Overlay({required this.text, required this.action, required this.onAction});
  final String text;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF06201B), fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(action),
            ),
          ],
        ),
      );
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.text});
  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 11,
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.14),
            child: Text(
              '$number',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text, required this.color});
  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 10),
            Expanded(child: Text(text)),
          ],
        ),
      );
}
