import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:baki_khata/features/auth/login_screen.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('LoginScreen renders wallet icon, titles, and Google button', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: LoginScreen(),
        ),
      ),
    );

    // Verify Title and Subtitle
    expect(find.text('Baki Khata'), findsOneWidget);
    expect(find.text('Track customer credit, the simple way'), findsOneWidget);

    // Verify App logo
    expect(find.byType(Image), findsOneWidget);

    // Verify "Continue with Google" button and "G" text
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('G'), findsOneWidget);
    expect(find.byType(OutlinedButton), findsOneWidget);
  });
}
