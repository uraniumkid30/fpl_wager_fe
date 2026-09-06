import 'dart:async';

import 'package:flutter/material.dart';

enum AppNoticeType { success, error, info }

/// Displays important feedback above dialogs, sheets and nested navigators.
///
/// A [SnackBar] belongs to a [ScaffoldMessenger], so it can be obscured by a
/// modal barrier. This notice is inserted into the root overlay instead.
abstract final class AppNotice {
  static OverlayEntry? _current;
  static Timer? _timer;

  static void success(BuildContext context, String message) => show(
        context,
        message: message,
        type: AppNoticeType.success,
      );

  static void error(BuildContext context, Object error) => show(
        context,
        message: _message(error),
        type: AppNoticeType.error,
        duration: const Duration(seconds: 6),
      );

  static void info(BuildContext context, String message) => show(
        context,
        message: message,
        type: AppNoticeType.info,
      );

  static void show(
    BuildContext context, {
    required String message,
    required AppNoticeType type,
    Duration duration = const Duration(seconds: 4),
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    dismiss();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _Notice(
        message: message,
        type: type,
        onDismiss: () => _remove(entry),
      ),
    );
    _current = entry;
    overlay.insert(entry);
    _timer = Timer(duration, () => _remove(entry));
  }

  static void dismiss() {
    _timer?.cancel();
    _timer = null;
    final entry = _current;
    _current = null;
    if (entry?.mounted ?? false) entry!.remove();
  }

  static void _remove(OverlayEntry entry) {
    if (!identical(_current, entry)) return;
    dismiss();
  }

  static String _message(Object error) {
    final value = error.toString().trim();
    return value
        .replaceFirst(RegExp(r'^(Exception|Error):\s*'), '')
        .replaceFirst(RegExp(r'^[A-Za-z]+Exception:\s*'), '');
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.message,
    required this.type,
    required this.onDismiss,
  });

  final String message;
  final AppNoticeType type;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (background, foreground, icon) = switch (type) {
      AppNoticeType.success => (
          const Color(0xFF087443),
          Colors.white,
          Icons.check_circle_rounded,
        ),
      AppNoticeType.error => (
          scheme.errorContainer,
          scheme.onErrorContainer,
          Icons.error_rounded,
        ),
      AppNoticeType.info => (
          scheme.inverseSurface,
          scheme.onInverseSurface,
          Icons.info_rounded,
        ),
    };

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: -0.18, end: 0),
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            builder: (context, offset, child) => FractionalTranslation(
              translation: Offset(0, offset),
              child: child,
            ),
            child: Material(
              color: background,
              elevation: 16,
              shadowColor: Colors.black45,
              borderRadius: BorderRadius.circular(16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                  child: Row(
                    children: [
                      Icon(icon, color: foreground),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          message,
                          style: TextStyle(
                            color: foreground,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Dismiss',
                        onPressed: onDismiss,
                        color: foreground,
                        icon: const Icon(Icons.close_rounded),
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
