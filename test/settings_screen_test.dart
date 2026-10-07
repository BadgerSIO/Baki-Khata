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
import 'package:baki_khata/l10n/generated/app_localizations.dart';

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
    setUp(() {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      binding.platformDispatcher.views.first.physicalSize = const Size(800, 1400);
      binding.platformDispatcher.views.first.devicePixelRatio = 1.0;
    });

    tearDown(() {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      binding.platformDispatcher.views.first.resetPhysicalSize();
      binding.platformDispatcher.views.first.resetDevicePixelRatio();
    });

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

      // Edit buttons are rendered (Shop Info + Payment Methods)
      expect(find.widgetWithText(FilledButton, 'Edit'), findsNWidgets(2));

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

      // Tap Edit button on Shop Info
      await tester.tap(find.widgetWithText(FilledButton, 'Edit').first);
      await tester.pumpAndSettle();

      // Form fields and buttons now appear
      expect(find.widgetWithText(TextFormField, 'Shop Name'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Currency Symbol'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Cancel'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Save'), findsOneWidget);

      // Edit button for Shop Info is replaced by Save/Cancel, Payment Methods edit button still visible
      expect(find.widgetWithText(FilledButton, 'Edit'), findsOneWidget);
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
      await tester.tap(find.widgetWithText(FilledButton, 'Edit').first);
      await tester.pumpAndSettle();

      // Edit shop name
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Shop Name'), 'New Shop Name');
      await tester.pump();

      // Tap Save
      await tester.tap(find.widgetWithText(FilledButton, 'Save').first);
      await tester.pumpAndSettle();

      // Saved immediately
      expect(mockRepo.updateCalls.length, 1);
      expect(mockRepo.updateCalls.first['shopName'], 'New Shop Name');

      // Confirmation snackbar is shown
      expect(find.text('Shop information saved'), findsOneWidget);

      // Returns to view mode: Save disappears, Edit button returns
      expect(find.widgetWithText(FilledButton, 'Save'), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Edit'), findsNWidgets(2));
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
      await tester.tap(find.widgetWithText(FilledButton, 'Edit').first);
      await tester.pumpAndSettle();

      // Edit shop name
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Shop Name'), 'Unwanted Changes');
      await tester.pump();

      // Tap Cancel
      await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel').first);
      await tester.pumpAndSettle();

      // No updateSettings call was made
      expect(mockRepo.updateCalls.isEmpty, isTrue);

      // Returns to view mode with original values
      expect(find.widgetWithText(FilledButton, 'Save'), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Edit'), findsNWidgets(2));
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
      await tester.tap(find.widgetWithText(FilledButton, 'Edit').first);
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
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Sign in to back up and sync your data to the cloud'),
        200,
        scrollable: find.byType(Scrollable).first,
      );

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
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.textContaining("1 customer isn't backed up"),
        200,
        scrollable: find.byType(Scrollable).first,
      );

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
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Sign Out button exists
      final signOutBtn = find.widgetWithText(FilledButton, 'Sign Out');
      await tester.scrollUntilVisible(
        signOutBtn,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(signOutBtn);
      await tester.pumpAndSettle();
      expect(signOutBtn, findsOneWidget);

      await tester.tap(signOutBtn);
      await tester.pumpAndSettle();

      // Confirmation dialog shown
      expect(find.text('Sign Out?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets(
        'Authenticated user renders Delete Account button and tapping it opens confirmation dialog',
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
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final deleteBtn = find.widgetWithText(OutlinedButton, 'Delete Account');
      await tester.scrollUntilVisible(
        deleteBtn,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(deleteBtn);
      await tester.pumpAndSettle();
      expect(deleteBtn, findsOneWidget);

      await tester.tap(deleteBtn);
      await tester.pumpAndSettle();

      // Delete confirmation dialog shown
      expect(find.widgetWithText(FilledButton, 'Delete Permanently'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Cancel'), findsOneWidget);
    });

    testWidgets('About & Legal Card displays app version, privacy policy, and terms of service', (tester) async {
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
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('About & Legal'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('About & Legal'), findsOneWidget);
      expect(find.text('Version 1.0.0'), findsOneWidget);
      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(find.text('Terms of Service'), findsOneWidget);
      expect(find.text('Support & Contact'), findsOneWidget);

      // Scroll to Privacy Policy tile and verify dialog opens
      final privacyTile = find.text('Privacy Policy');
      await tester.scrollUntilVisible(
        privacyTile,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(privacyTile);
      await tester.pumpAndSettle();

      await tester.tap(privacyTile);
      await tester.pumpAndSettle();
      expect(find.text('Got it'), findsOneWidget);
    });

    testWidgets('Digital Payment Methods Card displays configured methods and allows editing', (tester) async {
      final configuredSettings = testSettings.copyWith(
        bkashNumber: '01711223344',
        bkashIsMerchant: false,
        nagadNumber: '01855667788',
        nagadIsMerchant: true,
      );
      final mockRepo = _MockSettingsRepository(initialSettings: configuredSettings);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...emptyDataOverrides,
            settingsStreamProvider.overrideWith((ref) => Stream.value(configuredSettings)),
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

      // Scroll to Digital Payment Methods Card
      await tester.scrollUntilVisible(
        find.text('Digital Payment Methods'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Digital Payment Methods'), findsOneWidget);

      // Verify configured channels rendered in view mode
      expect(find.text('01711223344'), findsOneWidget);
      expect(find.text('Personal (Send Money)'), findsOneWidget);
      expect(find.text('01855667788'), findsOneWidget);
      expect(find.text('Merchant (Make Payment)'), findsOneWidget);

      // Tap Edit button on Digital Payment Methods Card (find Edit buttons)
      final editButtons = find.widgetWithText(FilledButton, 'Edit');
      expect(editButtons, findsNWidgets(2)); // Shop Info + Payment Methods
      await tester.tap(editButtons.last);
      await tester.pumpAndSettle();

      // Verify form fields for phone numbers
      expect(find.widgetWithText(TextFormField, '01711223344'), findsOneWidget);

      // Edit bKash number
      await tester.enterText(find.widgetWithText(TextFormField, '01711223344'), '01799887766');
      await tester.pump();

      // Tap Save button on Payment Methods
      final saveButtons = find.widgetWithText(FilledButton, 'Save');
      await tester.tap(saveButtons.last);
      await tester.pumpAndSettle();

      // Verify repo was called with new payment methods
      expect(mockRepo.updateCalls.isNotEmpty, isTrue);
      final lastCall = mockRepo.updateCalls.last;
      expect(lastCall['bkashNumber'], '01799887766');
      expect(lastCall['overridePaymentMethods'], isTrue);
    });
  });
}

class _MockSettingsRepository implements SettingsRepository {
  final AppSettings initialSettings;
  final List<Map<String, dynamic>> updateCalls = [];

  _MockSettingsRepository({required this.initialSettings});

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Stream<AppSettings> watchSettings() => Stream.value(initialSettings);

  @override
  Future<AppSettings> updateSettings({
    required String shopName,
    required String currencySymbol,
    String? shopPhone,
    String? shopAddress,
    bool? autoShowReceipt,
    String? bkashNumber,
    bool? bkashIsMerchant,
    String? nagadNumber,
    bool? nagadIsMerchant,
    String? rocketNumber,
    bool? rocketIsMerchant,
    String? proprietorName,
    String? shopLogoPath,
    String? shopSealType,
    String? customSealPath,
    bool overridePaymentMethods = false,
  }) async {
    updateCalls.add({
      'shopName': shopName,
      'currencySymbol': currencySymbol,
      'shopPhone': shopPhone,
      'shopAddress': shopAddress,
      'autoShowReceipt': autoShowReceipt,
      'bkashNumber': bkashNumber,
      'bkashIsMerchant': bkashIsMerchant,
      'nagadNumber': nagadNumber,
      'nagadIsMerchant': nagadIsMerchant,
      'rocketNumber': rocketNumber,
      'rocketIsMerchant': rocketIsMerchant,
      'proprietorName': proprietorName,
      'shopLogoPath': shopLogoPath,
      'shopSealType': shopSealType,
      'customSealPath': customSealPath,
      'overridePaymentMethods': overridePaymentMethods,
    });
    return AppSettings(
      userId: initialSettings.userId,
      shopName: shopName,
      shopPhone: shopPhone,
      shopAddress: shopAddress,
      currencySymbol: currencySymbol,
      autoShowReceipt: autoShowReceipt ?? true,
      bkashNumber: bkashNumber ?? initialSettings.bkashNumber,
      bkashIsMerchant: bkashIsMerchant ?? initialSettings.bkashIsMerchant,
      nagadNumber: nagadNumber ?? initialSettings.nagadNumber,
      nagadIsMerchant: nagadIsMerchant ?? initialSettings.nagadIsMerchant,
      rocketNumber: rocketNumber ?? initialSettings.rocketNumber,
      rocketIsMerchant: rocketIsMerchant ?? initialSettings.rocketIsMerchant,
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
