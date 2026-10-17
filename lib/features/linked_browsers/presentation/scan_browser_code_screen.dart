import 'package:flutter/material.dart';
import 'package:fplboardman/features/auth/domain/web_link.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// The camera, pointed at the QR code on the FPLboardman website. The first
/// FPLboardman code it sees opens the approval page for it.
class ScanBrowserCodeScreen extends StatefulWidget {
  const ScanBrowserCodeScreen({super.key});

  @override
  State<ScanBrowserCodeScreen> createState() => _ScanBrowserCodeScreenState();
}

class _ScanBrowserCodeScreenState extends State<ScanBrowserCodeScreen> {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );
  bool _handled = false;
  String? _notOurs;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final barcode in capture.barcodes) {
      final code = webLinkCodeFrom(barcode.rawValue);
      if (code != null) {
        _handled = true;
        context.pushReplacement('/link/$code');
        return;
      }
    }
    if (_notOurs == null && mounted) {
      setState(() => _notOurs = 'That is not an FPLboardman code. Scan the code on the FPLboardman website.');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: const Text('Scan the website code'),
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
              errorBuilder: (context, error) => _CameraProblem(error: error),
            ),
            // A square to aim with.
            Center(
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 3),
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 48,
              child: Text(
                _notOurs ??
                    'Open the FPLboardman website on your computer and point '
                        'your phone at the code it shows.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, height: 1.4, fontSize: 15),
              ),
            ),
          ],
        ),
      );
}

class _CameraProblem extends StatelessWidget {
  const _CameraProblem({required this.error});
  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          denied
              ? 'FPLboardman needs the camera to scan the code. Allow camera '
                  'access for FPLboardman in your phone settings, then try again.'
              : 'The camera could not be started. Close other apps using it '
                  'and try again.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, height: 1.4),
        ),
      ),
    );
  }
}
