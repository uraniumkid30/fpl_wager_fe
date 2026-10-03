import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Forgets the FPL login held by the in-app WebView (its cookies and the
/// session FPL's web app keeps in localStorage).
///
/// Called on sign-out, so the next "Continue with FPL" opens FPL's login
/// page fresh — for the same manager or a different one — instead of
/// silently reusing the previous manager's FPL session.
///
/// Best-effort: it never throws, because signing out of this app must
/// succeed even where there is no WebView (web, desktop, tests).
Future<void> clearFplWebSession() async {
  if (kIsWeb) return;
  try {
    await WebViewCookieManager().clearCookies();
    await WebViewController().clearLocalStorage();
  } catch (error) {
    debugPrint('Could not clear the FPL web session: $error');
  }
}
