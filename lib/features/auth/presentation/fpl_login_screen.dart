import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:fpl_wager/app/theme/app_theme.dart';
import 'package:fpl_wager/core/errors/app_exception.dart';
import 'package:fpl_wager/core/network/providers.dart';
import 'package:fpl_wager/features/auth/presentation/auth_controller.dart';

/// "Sign in with FPL" — the sole account entry point.
///
/// Opens FPL's real login page inside a WebView. The user types their own
/// FPL email and password directly into fantasy.premierleague.com's own
/// page — this app's Dart code never sees or handles that password. Once
/// login completes, this widget reads the OIDC refresh token FPL's web app
/// leaves in the WebView's localStorage and sends that token to our
/// backend, which exchanges it, resolves the manager's identity, and
/// returns a normal platform session. Alongside it goes the non-secret part
/// of the same stored login (profile claims, scope, expiry) so the server
/// can record what FPL exposes; the access and id tokens never leave the
/// WebView.
///
/// Trust note: because this renders inside an in-app WebView rather than
/// the device's external browser, this app's process technically has the
/// capability to inject JavaScript into FPL's page — this widget only ever
/// reads FPL's session entry from localStorage after login completes (and
/// removes that one entry if the backend reports it expired, so the user can
/// log in again); it never touches form fields.
/// If a stronger, externally-verifiable trust signal matters more than a
/// seamless in-app flow, swap this for an external-browser + deep-link-back
/// flow instead (see the note this project's docs carry from that
/// discussion).
class FplLoginScreen extends ConsumerStatefulWidget {
  const FplLoginScreen({super.key});

  @override
  ConsumerState<FplLoginScreen> createState() => _FplLoginScreenState();
}

class _FplLoginScreenState extends ConsumerState<FplLoginScreen> {
  /// Reads the OIDC session FPL's web app keeps in localStorage, or null.
  static const _readSessionScript = '''
    (function() {
      const key = Object.keys(localStorage).find(k => k.startsWith('oidc.user:'));
      return key ? localStorage.getItem(key) : null;
    })();
  ''';

  /// Drops that session from the page without logging out of FPL itself.
  static const _forgetSessionScript = '''
    Object.keys(localStorage)
      .filter(k => k.startsWith('oidc.user:'))
      .forEach(k => localStorage.removeItem(k));
  ''';

  /// Keys of FPL's stored login that are credentials. They are stripped
  /// before the rest is printed or sent anywhere; only the refresh token is
  /// ever sent, on its own, to complete the sign-in.
  static const _tokenKeys = {
    'access_token',
    'refresh_token',
    'id_token',
    'session_state',
    'code_verifier',
  };

  static Map<String, Object?> _withoutTokens(Map<String, Object?> source) => {
        for (final entry in source.entries)
          if (!_tokenKeys.contains(entry.key)) entry.key: entry.value,
      };

  late final WebViewController _controller;
  bool _completing = false;
  String? _error;

  /// Bumped on every page load so an older poll loop stops when a newer page
  /// takes over.
  int _pageLoad = 0;

  /// True while a sign-in attempt is in flight. Set synchronously, unlike
  /// [_completing], so two page-finished events can't both start one.
  bool _submitting = false;

  /// The last refresh token sent to the backend. FPL refresh tokens are
  /// single-use, so sending the same one twice can only ever fail.
  String? _lastSubmittedToken;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(onPageFinished: _onPageFinished),
      )
      ..loadRequest(Uri.parse('https://fantasy.premierleague.com/'));
  }

  Future<void> _onPageFinished(String url) async {
    final pageLoad = ++_pageLoad;
    // FPL's login pages never hold the session; nothing to look for there.
    if (url.contains('account.premierleague.com') ||
        url.contains('as/authorization')) {
      return;
    }

    // FPL's web app finishes its login callback a moment after the page
    // itself has loaded, so look for the session a few times before giving up.
    for (var attempt = 0; attempt < 20; attempt++) {
      if (!mounted || pageLoad != _pageLoad) return;
      if (await _trySignIn()) return;
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
  }

  /// Returns true once a session was found and handled (successfully or not),
  /// false if the page has no FPL session yet.
  Future<bool> _trySignIn() async {
    if (_submitting) return true;

    final String? decoded;
    try {
      decoded = _decodeJsResult(
        await _controller.runJavaScriptReturningResult(_readSessionScript),
      );
    } catch (_) {
      return false; // page navigated away mid-read; the next load retries
    }
    if (decoded == null) return false; // not logged in yet

    final String? refreshToken;
    final Map<String, Object?> session;
    try {
      final oidcUser = jsonDecode(decoded) as Map<String, Object?>;
      refreshToken = oidcUser['refresh_token'] as String?;
      session = _withoutTokens(oidcUser);
    } catch (_) {
      return false;
    }
    if (refreshToken == null || refreshToken == _lastSubmittedToken) {
      return refreshToken != null;
    }

    _submitting = true;
    _lastSubmittedToken = refreshToken;
    if (mounted) {
      setState(() {
        _completing = true;
        _error = null;
      });
    }
    // Everything FPL's page stored for this login except the tokens: the
    // profile claims, the scope and the expiry. Printed here so it shows in
    // the debug console, and sent along so the server records it next to
    // what FPL's own APIs return (see "FPL sign-ins" in the admin app).
    debugPrint(
      'FPL login data from the page (tokens removed):\n'
      '${const JsonEncoder.withIndent('  ').convert(session)}',
    );
    try {
      final signedIn = await ref
          .read(appGatewayProvider)
          .continueWithFpl(refreshToken: refreshToken, session: session);
      debugPrint(
        'FPL sign-in accepted: name=${signedIn.user.fullName} '
        'email=${signedIn.user.email} '
        'emailVerified=${signedIn.user.emailVerified} '
        'fplEntryId=${signedIn.user.fplEntryId}',
      );
      if (!mounted) return true;
      ref.read(authControllerProvider.notifier).accept(signedIn);
      context.go('/home');
    } catch (error) {
      debugPrint(
        'FPL sign-in failed: ${error.runtimeType} '
        'code=${error is AppException ? error.code : null} $error',
      );
      final expired =
          error is AppException && error.code == 'FPL_SESSION_EXPIRED';
      if (expired) {
        // The token this page is holding is dead. Forget it and reload so the
        // user can log in to FPL again and hand over a fresh one, instead of
        // this screen re-reading the same dead token forever.
        try {
          await _controller.runJavaScript(_forgetSessionScript);
          await _controller.reload();
        } catch (_) {
          // best-effort
        }
      }
      if (!mounted) return true;
      setState(() {
        _completing = false;
        _error = expired
            ? 'Your FPL login has expired. Please log in to FPL again.'
            : 'Could not complete FPL sign-in. Please try again.';
      });
    } finally {
      _submitting = false;
    }
    return true;
  }

  String? _decodeJsResult(Object? raw) {
    if (raw == null) return null;
    var value = raw.toString();
    if (value == 'null') return null;
    if (value.startsWith('"') && value.endsWith('"')) {
      try {
        value = jsonDecode(value) as String;
      } catch (_) {
        // use as-is
      }
    }
    return value;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Sign in with FPL'),
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => context.go('/welcome'),
          ),
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_completing)
              const ColoredBox(
                color: Colors.black45,
                child: Center(child: CircularProgressIndicator()),
              ),
            if (_error != null)
              Positioned(
                left: AppSpacing.lg,
                right: AppSpacing.lg,
                bottom: AppSpacing.lg,
                child: Material(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
}