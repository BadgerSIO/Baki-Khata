import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:baki_khata/app.dart';
import 'package:baki_khata/core/current_user_service.dart';
import 'package:baki_khata/core/theme.dart';
import 'package:baki_khata/data/local/local_database.dart';
import 'package:baki_khata/data/models/app_settings.dart';
import 'package:baki_khata/data/models/customer.dart';
import 'package:baki_khata/data/models/transaction.dart';
import 'package:baki_khata/data/repositories/customer_repository.dart';
import 'package:baki_khata/data/repositories/settings_repository.dart';
import 'package:baki_khata/data/repositories/transaction_repository.dart';
import 'package:baki_khata/data/sync/sync_service.dart';
import 'package:baki_khata/features/onboarding/onboarding_screen.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await LocalDatabase.instance.close();
    await LocalDatabase.instance.initDatabase(path: inMemoryDatabasePath);
  });

  testWidgets('OnboardingScreen renders initial state with default currency symbol', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const OnboardingScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Baki Khata'), findsOneWidget);
    expect(find.text("Let's set up your shop"), findsOneWidget);
    expect(find.text('Shop Name *'), findsOneWidget);
    expect(find.text('Currency Symbol'), findsOneWidget);
    expect(find.text('৳'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('Empty shop name shows validation error on Continue', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const OnboardingScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Tap Continue with empty input
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter your shop name'), findsOneWidget);
    expect(find.byType(MainNavigationScaffold), findsNothing);
  });

  testWidgets('Submitting valid form saves local settings stamped with local_guest and triggers navigation', (tester) async {
    final now = DateTime.now();
    final dummySettings = AppSettings(
      userId: CurrentUserService.guestSentinel,
      shopName: 'Bhai Bhai General Store',
      currencySymbol: '৳',
      updatedAt: now,
    );
    final mockRepo = _MockSettingsRepository(initialSettings: dummySettings);
    bool continued = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWith((ref) => Stream.value(CurrentUserService.guestSentinel)),
          settingsRepositoryProvider.overrideWithValue(mockRepo),
          customersStreamProvider.overrideWith((ref) => Stream.value(<Customer>[])),
          transactionsStreamProvider.overrideWith((ref) => Stream.value(<AppTransaction>[])),
          settingsStreamProvider.overrideWith((ref) => Stream.value(dummySettings)),
          syncStatusProvider.overrideWith((ref) => SyncStatus.guest),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: OnboardingScreen(
            onContinue: () {
              continued = true;
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Enter Shop Name
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Shop Name *'),
      'Bhai Bhai General Store',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();

    // Tap Continue
    await tester.tap(find.text('Continue'));
    await tester.pump();

    // Verify callback was invoked
    expect(continued, isTrue);

    // Verify updateSettings was called on repository
    expect(mockRepo.updateCalls, equals(1));
    expect(mockRepo.updatedSettings?.shopName, equals('Bhai Bhai General Store'));
    expect(mockRepo.updatedSettings?.currencySymbol, equals('৳'));
  });
}

class _MockSettingsRepository implements SettingsRepository {
  final AppSettings initialSettings;
  AppSettings? updatedSettings;
  int updateCalls = 0;

  _MockSettingsRepository({required this.initialSettings});

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<AppSettings> updateSettings({
    required String shopName,
    required String currencySymbol,
  }) async {
    updateCalls++;
    updatedSettings = AppSettings(
      userId: initialSettings.userId,
      shopName: shopName,
      currencySymbol: currencySymbol,
      updatedAt: DateTime.now(),
    );
    return updatedSettings!;
  }

  @override
  Stream<AppSettings> watchSettings() => Stream.value(initialSettings);
}
