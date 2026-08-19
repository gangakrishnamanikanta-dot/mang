import 'package:flutter/material.dart';

class SafeAreaView extends StatelessWidget {
  final Widget child;

  const SafeAreaView({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: child,
      ),
    );
  }
}
