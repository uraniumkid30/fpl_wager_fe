import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import 'package:fpl_wager/app/router/app_shell.dart';
import 'package:fpl_wager/features/auth/presentation/auth_controller.dart';
import 'package:fpl_wager/features/auth/presentation/email_sign_in_screen.dart';
import 'package:fpl_wager/features/auth/presentation/fpl_login_screen.dart';
import 'package:fpl_wager/features/auth/presentation/splash_screen.dart';
import 'package:fpl_wager/features/auth/presentation/verify_email_screen.dart';
import 'package:fpl_wager/features/auth/presentation/welcome_screen.dart';
import 'package:fpl_wager/features/challenges/presentation/challenges_screen.dart';
import 'package:fpl_wager/features/dashboard/presentation/dashboard_screen.dart';
import 'package:fpl_wager/features/fpl_team/presentation/link_team_screen.dart';
import 'package:fpl_wager/features/history/presentation/history_screen.dart';
import 'package:fpl_wager/features/notifications/presentation/notifications_screen.dart';
import 'package:fpl_wager/features/payments/presentation/payment_callback_screen.dart';
import 'package:fpl_wager/features/payments/presentation/top_up_screen.dart';
import 'package:fpl_wager/features/pools/presentation/create_pool_screen.dart';
import 'package:fpl_wager/features/pools/presentation/pool_detail_screen.dart';
import 'package:fpl_wager/features/pools/presentation/pools_screen.dart';
import 'package:fpl_wager/features/profile/presentation/profile_screen.dart';
import 'package:fpl_wager/features/settings/presentation/settings_screen.dart';
import 'package:fpl_wager/features/wallet/presentation/wallet_screen.dart';
import 'package:fpl_wager/features/withdrawals/presentation/bank_account_screen.dart';
import 'package:fpl_wager/features/withdrawals/presentation/withdraw_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// Where to go once the app knows whether someone is signed in.
///
/// The app can be opened at a particular page — an invite link, or the page
/// a payment provider returns to on the web — before the saved sign-in has
/// been read. That page is remembered here while the splash screen shows,
/// and an invite link is kept for as long as it takes the user to sign in.
String? _returnTo;

bool _isInviteLocation(String? location) =>
    location != null && location.startsWith('/join/');

/// The page a router state is at, as a path the router can be sent back to.
///
/// When the app is opened from a link, the state's address can still carry
/// the link's scheme ("fplboardman:///join/CODE"); only the path and any
/// query are wanted.
String _pathOf(GoRouterState state) {
  final uri = state.uri;
  return uri.hasQuery ? '${uri.path}?${uri.query}' : uri.path;
}

final routerProvider = Provider<GoRouter>((ref) {
  // One router for the life of the app. It checks its redirect again each
  // time the sign-in state changes, rather than being rebuilt, so a change
  // to the account never throws the user off the page they are on.
  final authChanges = ValueNotifier<int>(0);
  ref.onDispose(authChanges.dispose);
  ref.listen(authControllerProvider, (_, _) => authChanges.value++);

  final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/home',
    refreshListenable: authChanges,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final signedIn = auth.value != null;
      final location = state.matchedLocation;
      final public = location == '/welcome' ||
          location == '/fpl-login' ||
          location == '/email-sign-in';

      // The saved sign-in is still being read. (A later refresh of an
      // account that is already signed in is not a reason to interrupt.)
      if (auth.isLoading && !auth.hasValue) {
        if (location == '/splash') return null;
        if (!public) _returnTo = _pathOf(state);
        return '/splash';
      }
      // FPL's sign-in needs the in-app browser of the mobile app. In a web
      // browser that page cannot work, so it is never shown there.
      if (kIsWeb && location == '/fpl-login') return '/welcome';
      // Anyone who is not signed in — first launch, or just signed out —
      // lands on the app's own welcome page. FPL's login only opens when
      // they tap "Sign in with FPL" there.
      if (!signedIn) {
        if (_isInviteLocation(location)) {
          // Opened from an invite link: come back to it after signing in.
          _returnTo = _pathOf(state);
        } else if (!_isInviteLocation(_returnTo)) {
          // Any other remembered page belonged to the last session.
          _returnTo = null;
        }
        return public ? null : '/welcome';
      }
      if (public || location == '/splash') {
        final target = _returnTo ?? '/home';
        _returnTo = null;
        return target;
      }
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/welcome', builder: (_, _) => const WelcomeScreen()),
      GoRoute(path: '/fpl-login', builder: (_, _) => const FplLoginScreen()),
      GoRoute(
        path: '/email-sign-in',
        builder: (_, _) => const EmailSignInScreen(),
      ),
      // The home page used to be called the dashboard; old links still work.
      GoRoute(path: '/dashboard', redirect: (_, _) => '/home'),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                pageBuilder: (_, state) =>
                    const NoTransitionPage(child: DashboardScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/pools',
                pageBuilder: (_, state) =>
                    const NoTransitionPage(child: PoolsScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                pageBuilder: (_, state) =>
                    const NoTransitionPage(child: ProfileScreen()),
                routes: [
                  // Wallet and History live under Profile. Opening either
                  // keeps Profile underneath, so Back returns to it.
                  GoRoute(
                    path: 'wallet',
                    builder: (_, _) => const WalletScreen(),
                  ),
                  GoRoute(
                    path: 'history',
                    builder: (_, _) => const HistoryScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/link-team',
        pageBuilder: (context, state) => _DialogPage<bool>(
          key: state.pageKey,
          child: LinkTeamDialog(
            reason: state.uri.queryParameters['reason'],
          ),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/pools/create',
        // Closes with the id of the pool that was created.
        pageBuilder: (_, state) => _DialogPage<String>(
          key: state.pageKey,
          child: const CreatePoolScreen(),
        ),
      ),
      // Where an invite link lands: /join/CODE shows the private pool the
      // code belongs to, ready to join.
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/join/:code',
        builder: (_, state) =>
            JoinPoolScreen(code: state.pathParameters['code']!),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/pools/:poolId',
        builder: (_, state) =>
            PoolDetailScreen(poolId: state.pathParameters['poolId']!),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/notifications',
        builder: (_, _) => const NotificationsScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/settings',
        builder: (_, _) => const SettingsScreen(),
      ),
      // Withdrawing, and the bank account it is paid to. Both are reached
      // from Profile and open as full pages over the tabs, like Top up.
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/withdraw',
        builder: (_, _) => const WithdrawScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/bank-account',
        builder: (_, _) => const BankAccountScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/wallet/top-up',
        builder: (_, _) => const TopUpScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/payments/callback',
        builder: (_, state) => PaymentCallbackScreen(
          // The provider adds the reference to the callback address. On the
          // web that address ends in "#/payments/callback", and a provider
          // may put its query before the "#" instead of after it, so both
          // places are checked.
          reference: state.uri.queryParameters['reference'] ??
              state.uri.queryParameters['trxref'] ??
              Uri.base.queryParameters['reference'] ??
              Uri.base.queryParameters['trxref'] ??
              '',
        ),
      ),
      // Head to head is no longer a tab; it opens from its card on Pools.
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/challenges',
        builder: (_, _) => const ChallengesScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/verify-email',
        builder: (_, _) => const VerifyEmailScreen(),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

class _DialogPage<T> extends Page<T> {
  const _DialogPage({required this.child, super.key});

  final Widget child;

  @override
  Route<T> createRoute(BuildContext context) => DialogRoute<T>(
        context: context,
        settings: this,
        barrierDismissible: true,
        barrierColor: Colors.black.withValues(alpha: 0.62),
        barrierLabel:
            MaterialLocalizations.of(context).modalBarrierDismissLabel,
        builder: (_) => child,
      );
}
