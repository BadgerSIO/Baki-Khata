import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:baki_khata/core/theme.dart';
import 'package:baki_khata/data/models/app_settings.dart';
import 'package:baki_khata/data/models/customer.dart';
import 'package:baki_khata/data/models/transaction.dart';
import 'package:baki_khata/data/repositories/customer_repository.dart';
import 'package:baki_khata/data/repositories/settings_repository.dart';
import 'package:baki_khata/data/repositories/transaction_repository.dart';
import 'package:baki_khata/features/customers/customer_details_screen.dart';

void main() {
  final now = DateTime.now();

  final testCustomerWithDue = Customer(
    id: 'cust-1',
    userId: 'user-1',
    name: 'Rahim Traders',
    phone: '01711111111',
    address: 'Dhanmondi, Dhaka',
    createdAt: now,
    updatedAt: now,
  );

  final testTransactions = [
    AppTransaction(
      id: 'tx-1',
      userId: 'user-1',
      customerId: 'cust-1',
      type: TransactionType.baki,
      amount: 1500.0,
      description: 'Rice sacks',
      date: now.subtract(const Duration(hours: 2)),
      createdAt: now.subtract(const Duration(hours: 2)),
      updatedAt: now.subtract(const Duration(hours: 2)),
    ),
    AppTransaction(
      id: 'tx-2',
      userId: 'user-1',
      customerId: 'cust-1',
      type: TransactionType.payment,
      amount: 500.0,
      description: 'Cash payment',
      date: now,
      createdAt: now,
      updatedAt: now,
    ),
  ];

  final testSettings = AppSettings(
    userId: 'user-1',
    shopName: 'Test Shop',
    currencySymbol: '৳',
    updatedAt: now,
  );

  testWidgets('CustomerDetailsScreen renders header, balance, action buttons, and transaction history', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          customersStreamProvider.overrideWith((ref) => Stream.value([testCustomerWithDue])),
          customerTransactionsStreamProvider('cust-1').overrideWith(
            (ref) => Stream.value(testTransactions),
          ),
          settingsStreamProvider.overrideWith((ref) => Stream.value(testSettings)),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const CustomerDetailsScreen(customerId: 'cust-1'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Verify Header Card
    expect(find.text('Rahim Traders'), findsNWidgets(2)); // in AppBar and Header Card
    expect(find.text('Dhanmondi, Dhaka'), findsOneWidget);
    expect(find.text('01711111111'), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);

    // 2. Verify Balance Summary Card (1500 baki - 500 payment = 1000 Due)
    expect(find.text('Current Balance'), findsOneWidget);
    expect(find.text('Due ৳1,000'), findsOneWidget);

    // 3. Verify Two Action Buttons
    expect(find.text('Add Baki'), findsOneWidget);
    expect(find.text('Record Payment'), findsOneWidget);

    // 4. Verify Transaction History
    expect(find.text('Transaction History'), findsOneWidget);
    expect(find.text('2 records'), findsOneWidget);
    expect(find.text('Rice sacks'), findsOneWidget);
    expect(find.text('Cash payment'), findsOneWidget);
    expect(find.text('+ ৳ 1,500.00'), findsOneWidget);
    expect(find.text('- ৳ 500.00'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsNWidgets(2));
  });

  testWidgets('Delete Customer opens confirmation dialog with warning badge when balance is not zero', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          customersStreamProvider.overrideWith((ref) => Stream.value([testCustomerWithDue])),
          customerTransactionsStreamProvider('cust-1').overrideWith(
            (ref) => Stream.value(testTransactions),
          ),
          settingsStreamProvider.overrideWith((ref) => Stream.value(testSettings)),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const CustomerDetailsScreen(customerId: 'cust-1'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Open overflow menu
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    // Tap Delete Customer
    await tester.tap(find.text('Delete Customer'));
    await tester.pumpAndSettle();

    // Verify confirmation dialog title and content
    expect(find.text('Delete Customer?'), findsOneWidget);
    expect(
      find.text(
        'This customer has an outstanding balance of ৳1,000',
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);

    // Verify cancel dismisses dialog
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Delete Customer?'), findsNothing);
  });

  testWidgets('Delete Transaction opens confirmation dialog', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          customersStreamProvider.overrideWith((ref) => Stream.value([testCustomerWithDue])),
          customerTransactionsStreamProvider('cust-1').overrideWith(
            (ref) => Stream.value(testTransactions),
          ),
          settingsStreamProvider.overrideWith((ref) => Stream.value(testSettings)),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const CustomerDetailsScreen(customerId: 'cust-1'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Tap first transaction delete icon
    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();

    expect(find.text('Delete Transaction?'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Delete Transaction?'), findsNothing);
  });

  testWidgets('Edit icon opens Edit Customer dialog with pre-filled fields', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          customersStreamProvider.overrideWith((ref) => Stream.value([testCustomerWithDue])),
          customerTransactionsStreamProvider('cust-1').overrideWith(
            (ref) => Stream.value(testTransactions),
          ),
          settingsStreamProvider.overrideWith((ref) => Stream.value(testSettings)),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const CustomerDetailsScreen(customerId: 'cust-1'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Tap edit icon
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();

    // Verify dialog title and fields
    expect(find.text('Edit Customer'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Rahim Traders'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '01711111111'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Dhanmondi, Dhaka'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Edit Customer'), findsNothing);
  });
}
