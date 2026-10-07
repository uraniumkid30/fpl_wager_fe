import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The app's wallet mark: a fine-line wallet with a card tucked behind it
/// and a clasp on the right.
///
/// It is drawn here rather than taken from an icon font, so it stays crisp
/// at any size and needs no extra package. Like [Icon], it takes its colour
/// from the surrounding [IconTheme] unless [color] is given.
class WalletIcon extends StatelessWidget {
  const WalletIcon({
    super.key,
    this.size = 20,
    this.color,
    this.strokeWidth = 1.6,
  });

  final double size;
  final Color? color;

  /// The line weight on the icon's 24-unit grid. Small sizes read better a
  /// little heavier.
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final resolved = color ??
        IconTheme.of(context).color ??
        Theme.of(context).colorScheme.onSurface;
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _WalletPainter(color: resolved, strokeWidth: strokeWidth),
      ),
    );
  }
}

class _WalletPainter extends CustomPainter {
  const _WalletPainter({required this.color, required this.strokeWidth});

  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    // Everything below is on a 24 x 24 grid, scaled to the space given.
    final scale = size.shortestSide / 24;
    canvas.save();
    canvas.translate(
      (size.width - 24 * scale) / 2,
      (size.height - 24 * scale) / 2,
    );
    canvas.scale(scale);

    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    // The wallet itself.
    canvas.drawRRect(
      RRect.fromLTRBR(2.75, 7, 21.25, 19.5, const Radius.circular(3.2)),
      line,
    );

    // A card behind it, tilted a little; only the part above the wallet's
    // top edge shows.
    canvas.save();
    canvas.clipRect(const Rect.fromLTRB(0, 0, 24, 7));
    canvas.translate(5, 12);
    canvas.rotate(-8 * math.pi / 180);
    canvas.translate(-5, -12);
    canvas.drawRRect(
      RRect.fromLTRBR(5, 4.4, 17.5, 12.4, const Radius.circular(2)),
      line,
    );
    canvas.restore();

    // The clasp: a tab that runs off the right edge, with its stud.
    canvas.save();
    canvas.clipRect(const Rect.fromLTRB(0, 0, 21.25, 24));
    canvas.drawRRect(
      RRect.fromLTRBR(15, 11.2, 24, 15.3, const Radius.circular(2.05)),
      line,
    );
    canvas.restore();
    canvas.drawCircle(
      const Offset(17.5, 13.25),
      0.85,
      Paint()
        ..color = color
        ..isAntiAlias = true,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_WalletPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}
