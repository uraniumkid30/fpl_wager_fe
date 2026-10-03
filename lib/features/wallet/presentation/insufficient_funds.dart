import 'package:flutter/material.dart';
import 'package:fpl_wager/core/errors/app_exception.dart';
import 'package:fpl_wager/core/ui/app_notice.dart';
import 'package:go_router/go_router.dart';

/// True when the server refused an action because the wallet balance does
/// not cover it (HTTP 422, code `INSUFFICIENT_FUNDS`).
bool isInsufficientFunds(Object? error) =>
    error is AppException && error.code == 'INSUFFICIENT_FUNDS';

/// Sends the user to the top-up page when [error] is an insufficient-funds
/// refusal, and returns whether it did.
///
/// Call this wherever a paid action (joining a pool, creating a challenge)
/// fails, before showing the error:
///
/// ```dart
/// if (openTopUpIfInsufficientFunds(context, error)) return;
/// AppNotice.error(context, error);
/// ```
///
/// The page is pushed, so Back returns to the pool or challenge the user was
/// trying to pay for.
bool openTopUpIfInsufficientFunds(BuildContext context, Object? error) {
  if (!isInsufficientFunds(error)) return false;
  AppNotice.info(
    context,
    'Your wallet balance is too low for this. Top up to continue.',
  );
  context.push('/wallet/top-up');
  return true;
}
