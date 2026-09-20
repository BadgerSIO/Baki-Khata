import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:baki_khata/app.dart';
import 'package:baki_khata/core/theme.dart';
import 'package:baki_khata/data/models/app_settings.dart';
import 'package:baki_khata/data/models/customer.dart';
import 'package:baki_khata/data/models/transaction.dart';
import 'package:baki_khata/data/repositories/customer_repository.dart';
import 'package:baki_khata/data/repositories/settings_repository.dart';
import 'package:baki_khata/data/repositories/transaction_repository.dart';
import 'package:baki_khata/features/dashboard/home_screen.dart';

void main() {
  testWidgets('HomeScreen computes and renders reactive dashboard metrics', (tester) async {
    final now = DateTime.now();

    final testCustomers = [
      Customer(
        id: 'cust-1',
        userId: 'user-1',
        name: 'Rahim Traders',
        phone: '01711111111',
        createdAt: now,
        updatedAt: now,
      ),
      Customer(
        id: 'cust-2',
        userId: 'user-1',
        name: 'Karim Store',
        phone: '01822222222',
        createdAt: now,
        updatedAt: now,
      ),
    ];

    final testTransactions = [
      // Rahim has 1500 baki today
      AppTransaction(
        id: 'tx-1',
        userId: 'user-1',
        customerId: 'cust-1',
        type: TransactionType.baki,
        amount: 1500.0,
        description: 'Rice sacks',
        date: now,
        createdAt: now,
        updatedAt: now,
      ),
      // Rahim pays 500 today -> net debt = 1000
      AppTransaction(
        id: 'tx-2',
        userId: 'user-1',
        customerId: 'cust-1',
        type: TransactionType.payment,
        amount: 500.0,
        description: 'Partial cash',
        date: now,
        createdAt: now,
        updatedAt: now,
      ),
      // Karim pays 300 today -> net debt = -300 (advance, so not in total outstanding)
      AppTransaction(
        id: 'tx-3',
        userId: 'user-1',
        customerId: 'cust-2',
        type: TransactionType.payment,
        amount: 300.0,
        description: 'Advance payment',
        date: now,
        createdAt: now,
        updatedAt: now,
      ),
    ];

    final testSettings = AppSettings(
      userId: 'user-1',
      shopName: 'Bismillah General Store',
      currencySymbol: '৳',
      updatedAt: now,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          customersStreamProvider.overrideWith((ref) => Stream.value(testCustomers)),
          transactionsStreamProvider.overrideWith((ref) => Stream.value(testTransactions)),
          settingsStreamProvider.overrideWith((ref) => Stream.value(testSettings)),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const HomeScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Verify Stat Cards
    // Total Outstanding = Rahim's net positive balance of 1000.00
    expect(find.text('Total Outstanding'), findsOneWidget);
    expect(find.text('৳ 1,000.00'), findsOneWidget);

    // Total Customers = 2
    expect(find.text('Total Customers'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);

    // New Baki Today = 1500.00
    expect(find.text('New Baki Today'), findsOneWidget);
    expect(find.text('৳ 1,500.00'), findsOneWidget);

    // Collected Today = 500 + 300 = 800.00, Total Collected All-Time = 800.00
    expect(find.text('Collected Today'), findsOneWidget);
    expect(find.text('Total Collected All-Time'), findsOneWidget);
    expect(find.text('৳ 800.00'), findsNWidgets(2));

    // 4. Verify Quick Actions
    expect(find.text('Add Customer'), findsOneWidget);
    expect(find.text('Add Baki'), findsOneWidget);
    expect(find.text('Record Payment'), findsOneWidget);

    // 5. Verify Recent Transactions Section (scroll into view if needed)
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();

    expect(find.text('Recent Transactions'), findsOneWidget);
    expect(find.text('View All'), findsOneWidget);
    expect(find.text('Rahim Traders'), findsWidgets);
    expect(find.text('Karim Store'), findsWidgets);
  });

  testWidgets('Tapping Total Outstanding and Total Customers switches tabs', (tester) async {
    final testContainer = ProviderContainer(
      overrides: [
        customersStreamProvider.overrideWith((ref) => Stream.value([])),
        transactionsStreamProvider.overrideWith((ref) => Stream.value([])),
        settingsStreamProvider.overrideWith(
          (ref) => Stream.value(AppSettings(
            userId: 'user-1',
            shopName: 'Test Shop',
            currencySymbol: '৳',
            updatedAt: DateTime.now(),
          )),
        ),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: testContainer,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const HomeScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify initial tab is 0
    expect(testContainer.read(currentTabProvider), 0);

    // Tap Total Outstanding -> switches to History tab (2)
    await tester.tap(find.text('Total Outstanding'));
    await tester.pumpAndSettle();
    expect(testContainer.read(currentTabProvider), 2);

    // Tap Total Customers -> switches to Customers tab (1)
    await tester.tap(find.text('Total Customers'));
    await tester.pumpAndSettle();
    expect(testContainer.read(currentTabProvider), 1);

    // Tap View All -> switches to History tab (2)
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View All'));
    await tester.pumpAndSettle();
    expect(testContainer.read(currentTabProvider), 2);
  });
}
