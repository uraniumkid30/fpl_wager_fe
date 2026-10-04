import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// How a checkout session ended.
enum CheckoutOutcome {
  /// The provider sent the customer back to the callback address. The payment
  /// has usually succeeded, but only the server can say so: verify it next.
  completed,

  /// The customer pressed the cancel button on the provider's page.
  cancelled,

  /// The customer left the checkout themselves (close button or back).
  closed,
}

/// The payment provider's hosted checkout page, shown inside the app.
///
/// The server starts the transaction and gives the app a checkout address.
/// This screen loads that address and watches where the page goes next:
///
///  * the callback address  → the customer finished paying,
///  * the cancel address    → the customer pressed cancel,
///  * Paystack's close page → a card's 3-D Secure step finished.
///
/// In each case the screen closes itself and reports the outcome. It never
/// decides whether money was received — the caller asks the server, which
/// confirms the transaction with the provider before crediting the wallet.
///
/// No secret key and no card detail ever passes through the app: the card form
/// belongs to the provider and is loaded straight from their site.
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({
    required this.checkoutUrl,
    required this.callbackUrl,
    required this.providerLabel,
    super.key,
  });

  /// The provider's checkout page for this payment.
  final Uri checkoutUrl;

  /// The address the provider redirects to when checkout finishes. Adding
  /// `status=cancelled` to its query marks a cancelled checkout.
  final String callbackUrl;

  /// "Paystack" or "Korapay", for the title bar.
  final String providerLabel;

  /// Opens the checkout over the whole app and waits for it to end.
  static Future<CheckoutOutcome> open(
    BuildContext context, {
    required Uri checkoutUrl,
    required String callbackUrl,
    required String providerLabel,
  }) async {
    final outcome = await Navigator.of(context, rootNavigator: true)
        .push<CheckoutOutcome>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => CheckoutScreen(
          checkoutUrl: checkoutUrl,
          callbackUrl: callbackUrl,
          providerLabel: providerLabel,
        ),
      ),
    );
    return outcome ?? CheckoutOutcome.closed;
  }

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  /// Addresses the page itself may load. Anything else (a `tel:` USSD code, a
  /// bank app link) is handed to the phone instead.
  static const _pageSchemes = {'http', 'https', 'about', 'data', 'blob'};

  late final WebViewController _controller;
  late final Uri? _callback = Uri.tryParse(widget.callbackUrl);

  int _progress = 0;
  String? _loadError;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    // The browser's own user agent is kept on purpose: banks' 3-D Secure pages
    // are built for real browsers and some refuse an unfamiliar one.
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: _onNavigationRequest,
          // A second look at every page that starts loading, in case a
          // redirect reached the page without passing through the check above.
          onPageStarted: _onPageStarted,
          onProgress: (progress) {
            if (mounted) setState(() => _progress = progress);
          },
          onWebResourceError: _onWebResourceError,
        ),
      )
      ..loadRequest(widget.checkoutUrl);
  }

  /// What reaching [url] means for the checkout, or null to keep going.
  CheckoutOutcome? _outcomeFor(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;

    // Paystack sends the customer here once their bank's 3-D Secure step is
    // done. There is nothing more for them to do on the page.
    if (uri.host == 'standard.paystack.co' && uri.path == '/close') {
      return CheckoutOutcome.completed;
    }

    final callback = _callback;
    if (callback == null) return null;
    final isCallback = uri.scheme == callback.scheme &&
        uri.host == callback.host &&
        uri.port == callback.port &&
        uri.path == callback.path;
    if (!isCallback) return null;
    return uri.queryParameters['status'] == 'cancelled'
        ? CheckoutOutcome.cancelled
        : CheckoutOutcome.completed;
  }

  NavigationDecision _onNavigationRequest(NavigationRequest request) {
    final outcome = _outcomeFor(request.url);
    if (outcome != null) {
      _finish(outcome);
      return NavigationDecision.prevent;
    }

    final uri = Uri.tryParse(request.url);
    if (uri != null && !_pageSchemes.contains(uri.scheme)) {
      unawaited(_openOutsideTheApp(uri));
      return NavigationDecision.prevent;
    }
    // Everything else must be allowed: the bank's own authorisation pages are
    // reached by redirects from the checkout.
    return NavigationDecision.navigate;
  }

  void _onPageStarted(String url) {
    final outcome = _outcomeFor(url);
    if (outcome != null) {
      _finish(outcome);
      return;
    }
    if (mounted && _loadError != null) setState(() => _loadError = null);
  }

  void _onWebResourceError(WebResourceError error) {
    // Only a failure of the page itself matters; a missing image or tracker
    // inside it does not stop the customer from paying.
    if (error.isForMainFrame == false || _finished || !mounted) return;
    setState(() {
      _loadError = 'The checkout page could not be loaded. '
          'Check your connection and try again.';
    });
  }

  Future<void> _openOutsideTheApp(Uri uri) async {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Object {
      // Nothing on this phone can open the link (for example a bank app that
      // is not installed). The checkout page is still open, so the customer
      // can pick another way to pay.
    }
  }

  void _finish(CheckoutOutcome outcome) {
    if (_finished || !mounted) return;
    _finished = true;
    Navigator.of(context).pop(outcome);
  }

  Future<void> _confirmLeave() async {
    if (_finished) return;
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave checkout?'),
        content: const Text(
          'If you have already paid, your wallet is still credited as soon '
          'as the payment is confirmed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Stay'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (leave == true) _finish(CheckoutOutcome.closed);
  }

  Future<void> _onBack() async {
    if (_finished) return;
    // Back first steps back inside the checkout (for example from the bank's
    // page to the list of payment methods), then offers to leave.
    if (await _controller.canGoBack()) {
      await _controller.goBack();
      return;
    }
    await _confirmLeave();
  }

  void _retry() {
    setState(() {
      _loadError = null;
      _progress = 0;
    });
    unawaited(_controller.loadRequest(widget.checkoutUrl));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final loading = _progress < 100 && _loadError == null;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_onBack());
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Close checkout',
            icon: const Icon(Icons.close_rounded),
            onPressed: _confirmLeave,
          ),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_rounded, size: 18, color: scheme.primary),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '${widget.providerLabel} checkout',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(3),
            child: loading
                ? LinearProgressIndicator(
                    minHeight: 3,
                    value: _progress == 0 ? null : _progress / 100,
                  )
                : const SizedBox(height: 3),
          ),
        ),
        body: SafeArea(
          child: _loadError == null
              ? WebViewWidget(controller: _controller)
              : _LoadError(
                  message: _loadError!,
                  onRetry: _retry,
                  onClose: () => _finish(CheckoutOutcome.closed),
                ),
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({
    required this.message,
    required this.onRetry,
    required this.onClose,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.wifi_off_rounded,
                size: 52,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 22),
              FilledButton(onPressed: onRetry, child: const Text('Try again')),
              const SizedBox(height: 8),
              TextButton(onPressed: onClose, child: const Text('Close')),
            ],
          ),
        ),
      );
}
