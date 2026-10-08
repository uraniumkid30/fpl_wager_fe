import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fplboardman/core/ui/app_notice.dart';
import 'package:fplboardman/features/dashboard/presentation/dashboard_controller.dart';
import 'package:go_router/go_router.dart';

enum TeamProtectedAction {
  pool('pool'),
  challenge('challenge');

  const TeamProtectedAction(this.queryValue);
  final String queryValue;
}

/// Ensures a verified FPL team exists before a team-dependent command starts.
///
/// A successful link returns `true`; cancelling the modal or tapping its
/// barrier returns `false`. The backend remains the final authorization layer.
Future<bool> requireLinkedFplTeam(
  BuildContext context,
  WidgetRef ref, {
  required TeamProtectedAction action,
}) async {
  try {
    final cached = ref.read(dashboardProvider).value;
    final dashboard = cached ?? await ref.read(dashboardProvider.future);
    if (dashboard?.team != null) return true;
  } on Object {
    if (context.mounted) {
      AppNotice.error(
        context,
        'We could not check your FPL team. Please try again.',
      );
    }
    return false;
  }

  if (!context.mounted) return false;
  final linked = await context.push<bool>(
    '/link-team?reason=${action.queryValue}',
  );
  return linked ?? false;
}

Future<T?> openTeamProtectedRoute<T>(
  BuildContext context,
  WidgetRef ref, {
  required TeamProtectedAction action,
  required String route,
}) async {
  final allowed = await requireLinkedFplTeam(
    context,
    ref,
    action: action,
  );
  if (!allowed || !context.mounted) return null;
  return context.push<T>(route);
}
