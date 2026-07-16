import 'package:flutter/material.dart';

/// Centers its child and caps the width so forms and lists stay comfortable on
/// large desktop (Windows) screens instead of stretching edge-to-edge.
class AppConstrained extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  const AppConstrained({
    super.key,
    required this.child,
    this.maxWidth = 820,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
