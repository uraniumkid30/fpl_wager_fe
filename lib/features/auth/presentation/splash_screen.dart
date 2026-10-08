import 'package:flutter/material.dart';
import 'package:fplboardman/core/ui/app_widgets.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [BrandMark(), SizedBox(height: 28), CircularProgressIndicator()],
          ),
        ),
      );
}

