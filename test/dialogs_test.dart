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
import 'package:baki_khata/features/shared/customer_dialog.dart';
import 'package:baki_khata/features/shared/transaction_dialog.dart';

void main() {
  final now = DateTime.now();

  final testCustomer = Customer(
    id: 'cust-1',
    userId: 'user-1',
    name: 'Rahim Traders',
    phone: '01711111111',
    address: 'Dhanmondi, Dhaka',
    createdAt: now,
    updatedAt: now,
  );

  final testSettings = AppSettings(
    userId: 'user-1',
    shopName: 'Test Shop',
    currencySymbol: '৳',
    updatedAt: now,
  );

  group('CustomerDialog', () {
    testWidgets('Save button is disabled until Name is non-empty in create mode', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            customerRepositoryProvider.overrideWithValue(
              _MockCustomerRepository(),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: Builder(
                builder: (context) => Consumer(
                  builder: (context, ref, _) => ElevatedButton(
                    onPressed: () => showCustomerDialog(context, ref),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Add New Customer'), findsOneWidget);

      // Verify Save button exists but is disabled
      final saveBtnFinder = find.widgetWithText(FilledButton, 'Save');
      expect(saveBtnFinder, findsOneWidget);
      FilledButton saveBtn = tester.widget(saveBtnFinder);
      expect(saveBtn.onPressed, isNull);

      // Enter name
      await tester.enterText(find.widgetWithText(TextFormField, 'Customer Name *'), 'Karim');
      await tester.pumpAndSettle();

      // Save button should now be enabled
      saveBtn = tester.widget(saveBtnFinder);
      expect(saveBtn.onPressed, isNotNull);

      // Clear name -> disabled again
      await tester.enterText(find.widgetWithText(TextFormField, 'Customer Name *'), '');
      await tester.pumpAndSettle();
      saveBtn = tester.widget(saveBtnFinder);
      expect(saveBtn.onPressed, isNull);
    });

    testWidgets('Edit mode pre-fills fields and updates customer', (tester) async {
      Customer? returnedCustomer;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            customerRepositoryProvider.overrideWithValue(
              _MockCustomerRepository(),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: Builder(
                builder: (context) => Consumer(
                  builder: (context, ref, _) => ElevatedButton(
                    onPressed: () async {
                      returnedCustomer = await showCustomerDialog(
                        context,
                        ref,
                        customer: testCustomer,
                      );
                    },
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Edit Customer'), findsOneWidget);
      expect(find.text('Rahim Traders'), findsOneWidget);
      expect(find.text('01711111111'), findsOneWidget);
      expect(find.text('Dhanmondi, Dhaka'), findsOneWidget);

      final saveBtnFinder = find.widgetWithText(FilledButton, 'Save');
      expect(saveBtnFinder, findsOneWidget);
      final FilledButton saveBtn = tester.widget(saveBtnFinder);
      expect(saveBtn.onPressed, isNotNull);

      // Modify name and tap save
      await tester.enterText(find.widgetWithText(TextFormField, 'Customer Name *'), 'Rahim Enterprise');
      await tester.pumpAndSettle();

      await tester.tap(saveBtnFinder);
      await tester.pumpAndSettle();

      expect(returnedCustomer, isNotNull);
      expect(returnedCustomer!.name, 'Rahim Enterprise');
    });
  });

  group('TransactionDialog', () {
    testWidgets('Shows searchable picker when no customer preselected, hides type toggle when adding fresh', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            customersStreamProvider.overrideWith((ref) => Stream.value([testCustomer])),
            settingsStreamProvider.overrideWith((ref) => Stream.value(testSettings)),
            transactionRepositoryProvider.overrideWithValue(_MockTransactionRepository()),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: Builder(
                builder: (context) => Consumer(
                  builder: (context, ref, _) => ElevatedButton(
                    onPressed: () => showTransactionDialog(
                      context,
                      ref,
                      type: TransactionType.baki,
                    ),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Add Baki (Credit)'), findsOneWidget);

      // Segmented toggle must NOT be visible when adding fresh with fixed type
      expect(find.byType(SegmentedButton<TransactionType>), findsNothing);

      // Customer picker should be visible
      expect(find.widgetWithText(TextField, 'Select Customer *'), findsOneWidget);

      // Save button should be disabled (no customer selected, no amount)
      final saveBtnFinder = find.widgetWithText(FilledButton, 'Save');
      expect(saveBtnFinder, findsOneWidget);
      FilledButton saveBtn = tester.widget(saveBtnFinder);
      expect(saveBtn.onPressed, isNull);

      // Select Rahim Traders from the list
      await tester.tap(find.text('Rahim Traders'));
      await tester.pumpAndSettle();

      // Customer is now selected, card is shown
      expect(find.text('Rahim Traders'), findsOneWidget);
      // Still disabled because amount is empty
      saveBtn = tester.widget(saveBtnFinder);
      expect(saveBtn.onPressed, isNull);

      // Enter invalid amount (0) -> Inline error
      await tester.enterText(find.widgetWithText(TextFormField, 'Amount *'), '0');
      await tester.pumpAndSettle();
      expect(find.text('Amount must be greater than 0'), findsOneWidget);
      saveBtn = tester.widget(saveBtnFinder);
      expect(saveBtn.onPressed, isNull);

      // Enter valid amount (500)
      await tester.enterText(find.widgetWithText(TextFormField, 'Amount *'), '500');
      await tester.pumpAndSettle();
      expect(find.text('Amount must be greater than 0'), findsNothing);

      saveBtn = tester.widget(saveBtnFinder);
      expect(saveBtn.onPressed, isNotNull);

      // Tap save
      await tester.tap(saveBtnFinder);
      await tester.pumpAndSettle();

      // Dialog closed
      expect(find.text('Add Baki (Credit)'), findsNothing);
    });

    testWidgets('Editing existing transaction shows Segmented Type toggle and pre-fills data', (tester) async {
      final existingTx = AppTransaction(
        id: 'tx-10',
        userId: 'user-1',
        customerId: 'cust-1',
        type: TransactionType.baki,
        amount: 250.0,
        description: 'Snacks',
        date: now,
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            customersStreamProvider.overrideWith((ref) => Stream.value([testCustomer])),
            settingsStreamProvider.overrideWith((ref) => Stream.value(testSettings)),
            transactionRepositoryProvider.overrideWithValue(_MockTransactionRepository()),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: Builder(
                builder: (context) => Consumer(
                  builder: (context, ref, _) => ElevatedButton(
                    onPressed: () => showTransactionDialog(
                      context,
                      ref,
                      existingTransaction: existingTx,
                    ),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Edit Transaction'), findsOneWidget);

      // Segmented toggle IS shown when editing
      expect(find.byType(SegmentedButton<TransactionType>), findsOneWidget);
      expect(find.text('Baki (Credit)'), findsOneWidget);
      expect(find.text('Payment'), findsOneWidget);

      // Pre-filled amount & description
      expect(find.text('250'), findsOneWidget);
      expect(find.text('Snacks'), findsOneWidget);

      // Pre-filled customer
      expect(find.text('Rahim Traders'), findsOneWidget);

      // Toggle to payment
      await tester.tap(find.text('Payment'));
      await tester.pumpAndSettle();

      // Verify Cancel and Save buttons are side-by-side
      final cancelCenter = tester.getCenter(find.text('Cancel'));
      final saveCenter = tester.getCenter(find.widgetWithText(FilledButton, 'Save'));
      expect((cancelCenter.dy - saveCenter.dy).abs(), lessThanOrEqualTo(1.0));
      expect(cancelCenter.dx, lessThan(saveCenter.dx));

      // Save button is enabled
      final saveBtnFinder = find.widgetWithText(FilledButton, 'Save');
      await tester.tap(saveBtnFinder);
      await tester.pumpAndSettle();

      expect(find.text('Edit Transaction'), findsNothing);
    });

    testWidgets('CustomerDialog action buttons (Cancel and Save) are laid out side-by-side', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            customerRepositoryProvider.overrideWithValue(_MockCustomerRepository()),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: Builder(
                builder: (context) => Consumer(
                  builder: (context, ref, _) => ElevatedButton(
                    onPressed: () => showCustomerDialog(context, ref),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final cancelCenter = tester.getCenter(find.text('Cancel'));
      final saveCenter = tester.getCenter(find.widgetWithText(FilledButton, 'Save'));

      // Both buttons are horizontally aligned (same dy) and Cancel is to the left of Save
      expect((cancelCenter.dy - saveCenter.dy).abs(), lessThanOrEqualTo(1.0));
      expect(cancelCenter.dx, lessThan(saveCenter.dx));
    });
  });
}

class _MockCustomerRepository implements CustomerRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<Customer> addCustomer({
    required String name,
    String? phone,
    String? address,
    String? id,
  }) async {
    return Customer(
      id: id ?? 'cust-new',
      userId: 'user-1',
      name: name,
      phone: phone,
      address: address,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<Customer> updateCustomer(Customer customer) async {
    return customer;
  }
}

class _MockTransactionRepository implements TransactionRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<AppTransaction> addTransaction({
    required String customerId,
    required TransactionType type,
    required double amount,
    String? description,
    DateTime? date,
    String? id,
  }) async {
    return AppTransaction(
      id: id ?? 'tx-new',
      userId: 'user-1',
      customerId: customerId,
      type: type,
      amount: amount,
      description: description,
      date: date ?? DateTime.now(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<AppTransaction> updateTransaction(AppTransaction transaction) async {
    return transaction;
  }
}

