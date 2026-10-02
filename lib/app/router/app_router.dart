import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import 'package:fpl_wager/app/router/app_shell.dart';
import 'package:fpl_wager/features/auth/presentation/auth_controller.dart';
import 'package:fpl_wager/features/auth/presentation/sign_in_screen.dart';
import 'package:fpl_wager/features/auth/presentation/sign_up_screen.dart';
import 'package:fpl_wager/features/auth/presentation/splash_screen.dart';
import 'package:fpl_wager/features/auth/presentation/welcome_screen.dart';
import 'package:fpl_wager/features/auth/presentation/fpl_login_screen.dart';
import 'package:fpl_wager/features/auth/presentation/forgot_password_screen.dart';
import 'package:fpl_wager/features/auth/presentation/otp_screen.dart';
import 'package:fpl_wager/features/auth/presentation/reset_password_screen.dart';
import 'package:fpl_wager/features/challenges/presentation/challenges_screen.dart';
import 'package:fpl_wager/features/dashboard/presentation/dashboard_screen.dart';
import 'package:fpl_wager/features/fpl_team/presentation/link_team_screen.dart';
import 'package:fpl_wager/features/history/presentation/history_screen.dart';
import 'package:fpl_wager/features/pools/presentation/create_pool_screen.dart';
import 'package:fpl_wager/features/pools/presentation/pool_detail_screen.dart';
import 'package:fpl_wager/features/pools/presentation/pools_screen.dart';
import 'package:fpl_wager/features/settings/presentation/settings_screen.dart';
import 'package:fpl_wager/features/wallet/presentation/wallet_screen.dart';
import 'package:fpl_wager/features/admin/presentation/admin_screen.dart'
    as admin_dashboard;
import 'package:fpl_wager/features/admin/presentation/admin_resource_screen.dart'
    as admin_resource;
import 'package:fpl_wager/features/admin/presentation/admin_user_screen.dart'
    as admin_user;
import 'package:fpl_wager/features/payments/presentation/payment_callback_screen.dart';
import 'package:fpl_wager/features/payments/presentation/top_up_screen.dart';
import 'package:fpl_wager/features/notifications/presentation/notifications_screen.dart';


final _rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authControllerProvider);
  final signedIn = auth.value != null;
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/dashboard',
    redirect: (context, state) {
      final location = state.matchedLocation;
      final public =
          location == '/welcome' ||
          location == '/fpl-login' ||
          location == '/sign-in' ||
          location == '/sign-up' ||
          location == '/auth/verify' ||
          location == '/forgot-password' ||
          location == '/reset-password';
      if (auth.isLoading) return location == '/splash' ? null : '/splash';
      // '/fpl-login' is now the primary, and effectively only intended,
      // entry point — see welcome_screen.dart. '/sign-in' and '/sign-up'
      // stay reachable (not deleted) for now; decide whether to remove them
      // once this path is verified end to end.
      if (!signedIn) return public ? null : '/fpl-login';
      if (public || location == '/splash') return '/dashboard';
      if (location.startsWith('/admin') && !(auth.value?.user.isAdmin ?? false)) {
        return '/dashboard';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/welcome', builder: (_, _) => const WelcomeScreen()),
      GoRoute(path: '/fpl-login', builder: (_, _) => const FplLoginScreen()),
      GoRoute(path: '/sign-in', builder: (_, _) => const SignInScreen()),
      GoRoute(path: '/sign-up', builder: (_, _) => const SignUpScreen()),
      GoRoute(path: '/auth/verify', builder: (_, _) => const OtpScreen()),
      GoRoute(
        path: '/forgot-password',
        builder: (_, _) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (_, state) => ResetPasswordScreen(
          email: state.uri.queryParameters['email'],
          token: state.uri.queryParameters['token'],
        ),
      ),
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
                path: '/challenges',
                pageBuilder: (_, state) =>
                    const NoTransitionPage(child: ChallengesScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/wallet',
                pageBuilder: (_, state) =>
                    const NoTransitionPage(child: WalletScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/history',
                pageBuilder: (_, state) =>
                    const NoTransitionPage(child: HistoryScreen()),
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
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/admin',
        builder: (_, _) => const admin_dashboard.AdminScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/admin/users/:userId',
        builder: (_, state) => admin_user.AdminUserScreen(
          userId: state.pathParameters['userId']!,
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/admin/resources/:resource',
        builder: (_, state) => admin_resource.AdminResourceScreen(
          resource: state.pathParameters['resource']!,
        ),
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
