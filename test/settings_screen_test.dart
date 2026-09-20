import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:baki_khata/core/current_user_service.dart';
import 'package:baki_khata/core/theme.dart';
import 'package:baki_khata/data/models/app_settings.dart';
import 'package:baki_khata/data/models/customer.dart';
import 'package:baki_khata/data/models/transaction.dart';
import 'package:baki_khata/data/repositories/customer_repository.dart';
import 'package:baki_khata/data/repositories/settings_repository.dart';
import 'package:baki_khata/data/repositories/transaction_repository.dart';
import 'package:baki_khata/data/sync/sync_service.dart';
import 'package:baki_khata/features/settings/settings_screen.dart';

void main() {
  final now = DateTime.now();

  final testSettings = AppSettings(
    userId: 'user-1',
    shopName: 'Bhai Bhai Store',
    currencySymbol: '৳',
    updatedAt: now,
  );

  // Common empty-data overrides for tests that don't care about customer/tx data
  final emptyDataOverrides = [
    customersStreamProvider.overrideWith((ref) => Stream.value(<Customer>[])),
    transactionsStreamProvider
        .overrideWith((ref) => Stream.value(<AppTransaction>[])),
  ];

  group('SettingsScreen', () {
    testWidgets(
        'Pre-fills shop name and currency in view mode, shows Edit button, hides Save Changes button',
        (tester) async {
      final mockRepo = _MockSettingsRepository(initialSettings: testSettings);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...emptyDataOverrides,
            settingsStreamProvider.overrideWith((ref) => Stream.value(testSettings)),
            settingsRepositoryProvider.overrideWithValue(mockRepo),
            syncStatusProvider.overrideWith((ref) => SyncStatus.idle),
            lastSyncedTimeProvider.overrideWith((ref) => now),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Pre-filled values in view mode
      expect(find.text('Bhai Bhai Store'), findsOneWidget);
      expect(find.text('৳'), findsOneWidget);

      // Edit button is rendered
      expect(find.widgetWithText(FilledButton, 'Edit'), findsOneWidget);

      // Save and Cancel buttons are NOT rendered in view mode
      expect(find.widgetWithText(FilledButton, 'Save'), findsNothing);
      expect(find.widgetWithText(OutlinedButton, 'Cancel'), findsNothing);
    });

    testWidgets(
        'Tapping Edit enters edit mode and renders text fields, Cancel, and Save Changes buttons',
        (tester) async {
      final mockRepo = _MockSettingsRepository(initialSettings: testSettings);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...emptyDataOverrides,
            settingsStreamProvider.overrideWith((ref) => Stream.value(testSettings)),
            settingsRepositoryProvider.overrideWithValue(mockRepo),
            syncStatusProvider.overrideWith((ref) => SyncStatus.idle),
            lastSyncedTimeProvider.overrideWith((ref) => now),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap Edit button
      await tester.tap(find.widgetWithText(FilledButton, 'Edit'));
      await tester.pumpAndSettle();

      // Form fields and buttons now appear
      expect(find.widgetWithText(TextFormField, 'Shop Name'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Currency Symbol'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Cancel'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Save'), findsOneWidget);

      // Edit button in header is no longer visible
      expect(find.widgetWithText(FilledButton, 'Edit'), findsNothing);
    });

    testWidgets(
        'Tapping Save saves settings immediately, shows confirmation snackbar, and returns to view mode',
        (tester) async {
      final mockRepo = _MockSettingsRepository(initialSettings: testSettings);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...emptyDataOverrides,
            settingsStreamProvider.overrideWith((ref) => Stream.value(testSettings)),
            settingsRepositoryProvider.overrideWithValue(mockRepo),
            syncStatusProvider.overrideWith((ref) => SyncStatus.idle),
            lastSyncedTimeProvider.overrideWith((ref) => now),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap Edit
      await tester.tap(find.widgetWithText(FilledButton, 'Edit'));
      await tester.pumpAndSettle();

      // Edit shop name
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Shop Name'), 'New Shop Name');
      await tester.pump();

      // Tap Save
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      // Saved immediately
      expect(mockRepo.updateCalls.length, 1);
      expect(mockRepo.updateCalls.first['shopName'], 'New Shop Name');

      // Confirmation snackbar is shown
      expect(find.text('Shop information saved'), findsOneWidget);

      // Returns to view mode: Save disappears, Edit button returns
      expect(find.widgetWithText(FilledButton, 'Save'), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Edit'), findsOneWidget);
    });

    testWidgets(
        'Tapping Cancel discards changes, does not save settings, and returns to view mode',
        (tester) async {
      final mockRepo = _MockSettingsRepository(initialSettings: testSettings);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...emptyDataOverrides,
            settingsStreamProvider.overrideWith((ref) => Stream.value(testSettings)),
            settingsRepositoryProvider.overrideWithValue(mockRepo),
            syncStatusProvider.overrideWith((ref) => SyncStatus.idle),
            lastSyncedTimeProvider.overrideWith((ref) => now),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap Edit
      await tester.tap(find.widgetWithText(FilledButton, 'Edit'));
      await tester.pumpAndSettle();

      // Edit shop name
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Shop Name'), 'Unwanted Changes');
      await tester.pump();

      // Tap Cancel
      await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
      await tester.pumpAndSettle();

      // No updateSettings call was made
      expect(mockRepo.updateCalls.isEmpty, isTrue);

      // Returns to view mode with original values
      expect(find.widgetWithText(FilledButton, 'Save'), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Edit'), findsOneWidget);
      expect(find.text('Bhai Bhai Store'), findsOneWidget);
    });

    testWidgets('Keystrokes do not auto-save without tapping Save Changes',
        (tester) async {
      final mockRepo = _MockSettingsRepository(initialSettings: testSettings);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...emptyDataOverrides,
            settingsStreamProvider.overrideWith((ref) => Stream.value(testSettings)),
            settingsRepositoryProvider.overrideWithValue(mockRepo),
            syncStatusProvider.overrideWith((ref) => SyncStatus.idle),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap Edit
      await tester.tap(find.widgetWithText(FilledButton, 'Edit'));
      await tester.pumpAndSettle();

      // Edit shop name
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Shop Name'), 'Modern Traders');
      await tester.pump(const Duration(seconds: 2));

      // No auto-saving after typing
      expect(mockRepo.updateCalls.isEmpty, isTrue);

      // Edit currency symbol
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Currency Symbol'), '\$');
      await tester.pump(const Duration(seconds: 2));

      // Still no calls
      expect(mockRepo.updateCalls.isEmpty, isTrue);
    });

    testWidgets(
        'Sync status row displays status dot, formatted time, and triggers sync',
        (tester) async {
      final mockRepo = _MockSettingsRepository(initialSettings: testSettings);
      final mockSync = _MockSyncService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...emptyDataOverrides,
            settingsStreamProvider.overrideWith((ref) => Stream.value(testSettings)),
            settingsRepositoryProvider.overrideWithValue(mockRepo),
            syncServiceProvider.overrideWithValue(mockSync),
            syncStatusProvider.overrideWith((ref) => SyncStatus.idle),
            lastSyncedTimeProvider.overrideWith((ref) => now),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Status text and Last synced text
      expect(find.text('Synced'), findsOneWidget);
      expect(find.textContaining('Last synced: Just now'), findsOneWidget);

      // Sync Now button
      final syncBtn = find.widgetWithText(FilledButton, 'Sync Now');
      expect(syncBtn, findsOneWidget);

      await tester.tap(syncBtn);
      await tester.pumpAndSettle();

      expect(mockSync.fullSyncCallCount, 1);
    });

    testWidgets('Guest mode (empty) shows amber warning nudge and sign-in CTA',
        (tester) async {
      final mockRepo = _MockSettingsRepository(initialSettings: testSettings);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserIdProvider.overrideWith((ref) => Stream.value('local_guest')),
            // Empty data → generic nudge copy
            customersStreamProvider
                .overrideWith((ref) => Stream.value(<Customer>[])),
            transactionsStreamProvider
                .overrideWith((ref) => Stream.value(<AppTransaction>[])),
            settingsStreamProvider
                .overrideWith((ref) => Stream.value(testSettings)),
            settingsRepositoryProvider.overrideWithValue(mockRepo),
            syncStatusProvider.overrideWith((ref) => SyncStatus.guest),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Generic nudge copy when no customers
      expect(find.text('Sign in to back up and sync your data to the cloud'),
          findsOneWidget);
      // CTA button still present
      expect(find.text('Sign In / Create Account'), findsOneWidget);
      // No sign-out button in guest mode
      expect(find.text('Sign Out'), findsNothing);
      // Warning icon present
      expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);
    });

    testWidgets(
        'Guest mode with customers shows live-count nudge copy', (tester) async {
      final mockRepo = _MockSettingsRepository(initialSettings: testSettings);
      final customer = Customer(
        id: 'c1',
        userId: 'local_guest',
        name: 'Rahim',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final tx = AppTransaction(
        id: 't1',
        customerId: 'c1',
        userId: 'local_guest',
        type: TransactionType.baki,
        date: DateTime.now(),
        amount: 4200,
        description: null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserIdProvider.overrideWith((ref) => Stream.value('local_guest')),
            customersStreamProvider
                .overrideWith((ref) => Stream.value([customer])),
            transactionsStreamProvider
                .overrideWith((ref) => Stream.value([tx])),
            settingsStreamProvider
                .overrideWith((ref) => Stream.value(testSettings)),
            settingsRepositoryProvider.overrideWithValue(mockRepo),
            syncStatusProvider.overrideWith((ref) => SyncStatus.guest),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Live count copy with amount and customer count
      expect(
        find.textContaining("1 customer isn't backed up"),
        findsOneWidget,
      );
    });

    testWidgets(
        'Authenticated user shows email and Sign Out button opens confirmation dialog',
        (tester) async {
      final mockRepo = _MockSettingsRepository(initialSettings: testSettings);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserIdProvider.overrideWith((ref) => Stream.value('user-1')),
            ...emptyDataOverrides,
            settingsStreamProvider
                .overrideWith((ref) => Stream.value(testSettings)),
            settingsRepositoryProvider.overrideWithValue(mockRepo),
            syncStatusProvider.overrideWith((ref) => SyncStatus.idle),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Sign Out button exists
      final signOutBtn = find.widgetWithText(FilledButton, 'Sign Out');
      expect(signOutBtn, findsOneWidget);

      await tester.ensureVisible(signOutBtn);
      await tester.pumpAndSettle();
      await tester.tap(signOutBtn);
      await tester.pumpAndSettle();

      // Confirmation dialog shown
      expect(find.text('Sign Out?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });
  });
}

class _MockSettingsRepository implements SettingsRepository {
  final AppSettings initialSettings;
  final List<Map<String, String>> updateCalls = [];

  _MockSettingsRepository({required this.initialSettings});

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Stream<AppSettings> watchSettings() => Stream.value(initialSettings);

  @override
  Future<AppSettings> updateSettings({
    required String shopName,
    required String currencySymbol,
  }) async {
    updateCalls.add({
      'shopName': shopName,
      'currencySymbol': currencySymbol,
    });
    return AppSettings(
      userId: initialSettings.userId,
      shopName: shopName,
      currencySymbol: currencySymbol,
      updatedAt: DateTime.now(),
    );
  }
}

class _MockSyncService implements SyncService {
  int fullSyncCallCount = 0;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<void> fullSync() async {
    fullSyncCallCount++;
  }
}
