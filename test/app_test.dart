import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:baki_khata/app.dart';
import 'package:baki_khata/core/current_user_service.dart';
import 'package:baki_khata/core/theme.dart';
import 'package:baki_khata/data/models/app_settings.dart';
import 'package:baki_khata/data/models/customer.dart';
import 'package:baki_khata/data/models/transaction.dart';
import 'package:baki_khata/data/repositories/customer_repository.dart';
import 'package:baki_khata/data/repositories/settings_repository.dart';
import 'package:baki_khata/data/repositories/transaction_repository.dart';
import 'package:baki_khata/data/sync/sync_service.dart';

void main() {
  final now = DateTime.now();

  final testSettings = AppSettings(
    userId: 'user-1',
    shopName: 'Test Shop',
    currencySymbol: '৳',
    updatedAt: now,
  );

  group('BakiKhataApp Routing', () {
    testWidgets('Renders OnboardingScreen when no local settings row exists', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hasLocalSettingsProvider.overrideWith((ref) => Future.value(false)),
          ],
          child: const BakiKhataApp(),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text("Let's set up your shop"), findsOneWidget);
      expect(find.text('Baki Khata'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
      expect(find.byType(MainNavigationScaffold), findsNothing);
    });

    testWidgets('Renders MainNavigationScaffold when local settings exist without showing auth screen', (tester) async {
      final mockSettingsRepo = _MockSettingsRepository(initialSettings: testSettings);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hasLocalSettingsProvider.overrideWith((ref) => Future.value(true)),
            currentUserIdProvider.overrideWith((ref) => Stream.value('local_guest')),
            settingsRepositoryProvider.overrideWithValue(mockSettingsRepo),
            customersStreamProvider.overrideWith((ref) => Stream.value(<Customer>[])),
            transactionsStreamProvider.overrideWith((ref) => Stream.value(<AppTransaction>[])),
            settingsStreamProvider.overrideWith((ref) => Stream.value(testSettings)),
            syncStatusProvider.overrideWith((ref) => SyncStatus.guest),
          ],
          child: const BakiKhataApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Main Navigation Scaffold is displayed immediately with 4 tabs, no auth screen
      expect(find.byType(MainNavigationScaffold), findsOneWidget);
      expect(find.byType(BottomNavigationBar), findsOneWidget);
      expect(find.text("Let's set up your shop"), findsNothing);
    });
  });

  group('MainNavigationScaffold Tab Navigation & IndexedStack', () {
    testWidgets('Has 4 tabs, preserves state with IndexedStack, and switches tabs', (tester) async {
      final mockSettingsRepo = _MockSettingsRepository(initialSettings: testSettings);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserIdProvider.overrideWith((ref) => Stream.value('local_guest')),
            settingsRepositoryProvider.overrideWithValue(mockSettingsRepo),
            customersStreamProvider.overrideWith((ref) => Stream.value(<Customer>[])),
            transactionsStreamProvider.overrideWith((ref) => Stream.value(<AppTransaction>[])),
            settingsStreamProvider.overrideWith((ref) => Stream.value(testSettings)),
            syncStatusProvider.overrideWith((ref) => SyncStatus.guest),
            lastSyncedTimeProvider.overrideWith((ref) => now),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const MainNavigationScaffold(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify BottomNavigationBar has 4 tabs
      final bottomNavBarFinder = find.byType(BottomNavigationBar);
      expect(bottomNavBarFinder, findsOneWidget);
      final BottomNavigationBar bar = tester.widget(bottomNavBarFinder);
      expect(bar.items.length, 4);
      expect(bar.items[0].label, 'Home');
      expect(bar.items[1].label, 'Customers');
      expect(bar.items[2].label, 'History');
      expect(bar.items[3].label, 'Settings');

      // Default index is 0 (Home shows shop name and storefront icon)
      expect(find.text('Test Shop'), findsOneWidget);
      expect(find.byIcon(Icons.storefront_outlined), findsOneWidget);
      expect(find.text('Total Outstanding'), findsOneWidget);

      // Verify IndexedStack exists with 4 children
      final indexedStackFinder = find.byType(IndexedStack);
      expect(indexedStackFinder, findsOneWidget);
      final IndexedStack stack = tester.widget(indexedStackFinder);
      expect(stack.children.length, 4);

      // Switch to Customers tab (index 1)
      await tester.tap(find.text('Customers'));
      await tester.pumpAndSettle();

      expect(find.text('No customers yet'), findsOneWidget);

      // Switch to History tab (index 2)
      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();

      expect(find.text('No Transactions Yet'), findsOneWidget);

      // Switch to Settings tab (index 3)
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      expect(find.text('Shop Information'), findsOneWidget);
      expect(find.text('Guest Mode'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Sign In / Create Account'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Sign In / Create Account'), findsOneWidget);
    });
  });
}

class _MockSettingsRepository implements SettingsRepository {
  final AppSettings initialSettings;
  int ensureSettingsCalls = 0;

  _MockSettingsRepository({required this.initialSettings});

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<void> ensureSettingsForCurrentUser() async {
    ensureSettingsCalls++;
  }

  @override
  Stream<AppSettings> watchSettings() => Stream.value(initialSettings);
}
