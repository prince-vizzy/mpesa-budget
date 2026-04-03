import 'package:flutter/material.dart';

/// Wraps any child with the full-screen swirl background image.
/// Use this as the outermost container in every page's Scaffold body.
class AppBackground extends StatelessWidget {
  final Widget child;

  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Background image — covers the entire screen
        Image.asset(
          'assets/background.jpg',
          fit: BoxFit.cover,
        ),
        // Page content on top
        child,
      ],
    );
  }
}
