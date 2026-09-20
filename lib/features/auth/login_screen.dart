import 'package:flutter/material.dart';
import 'account_screen.dart';

export 'account_screen.dart';

/// Backward-compatible alias/wrapper for AccountScreen.
class LoginScreen extends StatelessWidget {
  final int initialIndex;

  const LoginScreen({super.key, this.initialIndex = 0});

  @override
  Widget build(BuildContext context) {
    return AccountScreen(initialIndex: initialIndex);
  }
}
