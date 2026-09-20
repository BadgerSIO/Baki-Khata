import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:baki_khata/app.dart';
import 'package:baki_khata/core/current_user_service.dart';
import 'package:baki_khata/core/theme.dart';
import 'package:baki_khata/features/auth/account_screen.dart';
import 'package:baki_khata/features/dashboard/home_user_header.dart';

void main() {
  group('HomeUserHeaderAction', () {
    testWidgets('Guest mode renders Login / Sign Up button and navigates to AccountScreen', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProfileProvider.overrideWith(
              (ref) => Stream.value(CurrentUserProfile.guest),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              appBar: AppBar(
                actions: const [HomeUserHeaderAction()],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify "Login / Sign Up" button is visible
      expect(find.byKey(const Key('home_login_signup_button')), findsOneWidget);
      expect(find.text('Login / Sign Up'), findsOneWidget);
      expect(find.textContaining('Hi '), findsNothing);

      // Tap button and verify it pushes AccountScreen
      await tester.tap(find.byKey(const Key('home_login_signup_button')));
      await tester.pumpAndSettle();

      expect(find.byType(AccountScreen), findsOneWidget);
    });

    testWidgets('Authenticated mode with name renders "Hi [Name]" and fallback icon when no avatar', (tester) async {
      int activeTab = 0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProfileProvider.overrideWith(
              (ref) => Stream.value(
                const CurrentUserProfile(
                  id: 'user-123',
                  email: 'saad@example.com',
                  displayName: 'Saad',
                  avatarUrl: null,
                  isGuest: false,
                ),
              ),
            ),
          ],
          child: Consumer(
            builder: (context, ref, child) {
              activeTab = ref.watch(currentTabProvider);
              return MaterialApp(
                theme: AppTheme.lightTheme,
                home: Scaffold(
                  appBar: AppBar(
                    actions: const [HomeUserHeaderAction()],
                  ),
                ),
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify "Login / Sign Up" is absent
      expect(find.byKey(const Key('home_login_signup_button')), findsNothing);

      // Verify "Hi Saad" is rendered
      expect(find.text('Hi Saad'), findsOneWidget);

      // Verify fallback person icon is rendered
      expect(find.byIcon(Icons.person_rounded), findsOneWidget);

      // Tap profile and verify tab changes to Settings (index 3)
      await tester.tap(find.byKey(const Key('home_user_profile_button')));
      await tester.pumpAndSettle();

      expect(activeTab, 3);
    });

    testWidgets('Authenticated mode with avatarUrl renders Image widget', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProfileProvider.overrideWith(
              (ref) => Stream.value(
                const CurrentUserProfile(
                  id: 'user-123',
                  email: 'saad@example.com',
                  displayName: 'Saad',
                  avatarUrl: 'https://example.com/avatar.jpg',
                  isGuest: false,
                ),
              ),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              appBar: AppBar(
                actions: const [HomeUserHeaderAction()],
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Hi Saad'), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
    });
  });
}
