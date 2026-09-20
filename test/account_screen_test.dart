import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:baki_khata/features/auth/account_screen.dart';

void main() {
  testWidgets('AccountScreen renders Sign In and Create Account tabs', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: AccountScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Title and Tabs
    expect(find.text('Account'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Sign In'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Create Account'), findsOneWidget);

    // Initial tab is Sign In
    expect(find.widgetWithText(FilledButton, 'Sign In'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
  });

  testWidgets('Switching to Create Account tab displays signup fields and password requirements', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: AccountScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Tap "Create Account" tab
    await tester.tap(find.widgetWithText(Tab, 'Create Account'));
    await tester.pumpAndSettle();

    // Verify password helper text and create account button
    expect(find.text('Minimum 8 characters'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Create Account'), findsOneWidget);
  });

  testWidgets('Create account form validates short password (< 8 chars)', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: AccountScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Switch to Create Account tab
    await tester.tap(find.widgetWithText(Tab, 'Create Account'));
    await tester.pumpAndSettle();

    // Enter email
    final emailField = find.widgetWithText(TextFormField, 'Email');
    await tester.enterText(emailField, 'test@example.com');

    // Enter short password (5 chars)
    final passwordField = find.widgetWithText(TextFormField, 'Password');
    await tester.enterText(passwordField, '12345');

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();

    // Tap Create Account button
    final createAccountButton = find.widgetWithText(FilledButton, 'Create Account');
    await tester.tap(createAccountButton);
    await tester.pumpAndSettle();

    // Verify validation message
    expect(find.text('Password must be at least 8 characters'), findsOneWidget);
  });
}
