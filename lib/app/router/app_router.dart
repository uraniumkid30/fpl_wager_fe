import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import 'package:fpl_wager/app/router/app_shell.dart';
import 'package:fpl_wager/features/auth/presentation/auth_controller.dart';
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

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authControllerProvider);
  final signedIn = auth.value != null;
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/dashboard',
    redirect: (context, state) {
      final location = state.matchedLocation;
      final public = location == '/welcome' || location == '/fpl-login';
      if (auth.isLoading) return location == '/splash' ? null : '/splash';
      // Anyone who is not signed in — first launch, or just signed out —
      // lands on the app's own welcome page. FPL's login only opens when
      // they tap "Continue with FPL" there.
      if (!signedIn) return public ? null : '/welcome';
      if (public || location == '/splash') return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/welcome', builder: (_, _) => const WelcomeScreen()),
      GoRoute(path: '/fpl-login', builder: (_, _) => const FplLoginScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
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
        pageBuilder: (_, state) => _DialogPage<bool>(
          key: state.pageKey,
          child: const CreatePoolScreen(),
        ),
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
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/wallet/top-up',
        builder: (_, _) => const TopUpScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/payments/callback',
        builder: (_, state) => PaymentCallbackScreen(
          reference: state.uri.queryParameters['reference'] ??
              state.uri.queryParameters['trxref'] ??
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
