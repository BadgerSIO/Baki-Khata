import 'package:flutter/material.dart';
import 'account_screen.dart';

export 'account_screen.dart';

/// Backward-compatible alias/wrapper for AccountScreen.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AccountScreen();
  }
}
