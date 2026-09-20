import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:baki_khata/features/auth/otp_verification_screen.dart';

void main() {
  testWidgets('OtpVerificationScreen displays target email and initial timer', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: OtpVerificationScreen(email: 'merchant@store.com'),
        ),
      ),
    );
    await tester.pump();

    // Verify Title and Subtitle with email
    expect(find.text('Verify Email'), findsOneWidget);
    expect(find.text('Check your email'), findsOneWidget);
    expect(find.text('We sent a 6-digit code to\nmerchant@store.com'), findsOneWidget);

    // Initial resend state shows countdown
    expect(find.text('Resend code in 60s'), findsOneWidget);

    // Verify button is disabled initially
    final verifyButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Verify'),
    );
    expect(verifyButton.onPressed, isNull);
  });

  testWidgets('Verify button requires exactly 6 digits and filters non-numeric input', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: OtpVerificationScreen(email: 'merchant@store.com'),
        ),
      ),
    );
    await tester.pump();

    final inputFinder = find.byType(TextField);

    // Enter 4 digits -> disabled
    await tester.enterText(inputFinder, '1234');
    await tester.pump();
    var verifyButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Verify'),
    );
    expect(verifyButton.onPressed, isNull);

    // Enter letters and numbers -> letters filtered out
    await tester.enterText(inputFinder, '12ab34');
    await tester.pump();
    expect(find.text('1234'), findsOneWidget);
    verifyButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Verify'),
    );
    expect(verifyButton.onPressed, isNull);

    // Enter full 6 digits -> button enabled
    await tester.enterText(inputFinder, '123456');
    await tester.pump();
    verifyButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Verify'),
    );
    expect(verifyButton.onPressed, isNotNull);

    // Enter more than 6 digits -> length limited to 6
    await tester.enterText(inputFinder, '123456789');
    await tester.pump();
    expect(find.text('123456'), findsOneWidget);
  });

  testWidgets('Resend code button appears after countdown elapses', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: OtpVerificationScreen(email: 'merchant@store.com'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Resend code in 60s'), findsOneWidget);

    // Advance time by 30 seconds
    await tester.pump(const Duration(seconds: 30));
    expect(find.text('Resend code in 30s'), findsOneWidget);

    // Advance remaining 30 seconds
    await tester.pump(const Duration(seconds: 30));
    expect(find.text('Resend code'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Resend code'), findsOneWidget);
  });
}
