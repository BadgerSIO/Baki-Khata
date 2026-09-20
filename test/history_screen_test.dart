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
import 'package:baki_khata/features/history/history_screen.dart';

void main() {
  final now = DateTime.now();

  final testCustomer1 = Customer(
    id: 'cust-1',
    userId: 'user-1',
    name: 'Rahim Store',
    phone: '01711111111',
    address: 'Dhaka',
    createdAt: now.subtract(const Duration(days: 10)),
    updatedAt: now.subtract(const Duration(days: 10)),
  );

  final testCustomer2 = Customer(
    id: 'cust-2',
    userId: 'user-1',
    name: 'Karim Enterprise',
    phone: '01822222222',
    address: 'Chattogram',
    createdAt: now.subtract(const Duration(days: 5)),
    updatedAt: now.subtract(const Duration(days: 5)),
  );

  final txOldBaki = AppTransaction(
    id: 'tx-1',
    userId: 'user-1',
    customerId: 'cust-1',
    type: TransactionType.baki,
    amount: 500.0,
    description: 'Old groceries',
    date: now.subtract(const Duration(days: 2)),
    createdAt: now.subtract(const Duration(days: 2)),
    updatedAt: now.subtract(const Duration(days: 2)),
  );

  final txMidPayment = AppTransaction(
    id: 'tx-2',
    userId: 'user-1',
    customerId: 'cust-2',
    type: TransactionType.payment,
    amount: 300.0,
    description: 'Cash payment',
    date: now.subtract(const Duration(days: 1)),
    createdAt: now.subtract(const Duration(days: 1)),
    updatedAt: now.subtract(const Duration(days: 1)),
  );

  final txNewBaki = AppTransaction(
    id: 'tx-3',
    userId: 'user-1',
    customerId: 'cust-1',
    type: TransactionType.baki,
    amount: 1200.0,
    description: 'New stock order',
    date: now,
    createdAt: now,
    updatedAt: now,
  );

  final testSettings = AppSettings(
    userId: 'user-1',
    shopName: 'My Ledger',
    currencySymbol: '৳',
    updatedAt: now,
  );

  group('HistoryScreen', () {
    testWidgets('Renders transactions in reverse-chronological order with customer names & details', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            transactionsStreamProvider.overrideWith((ref) => Stream.value([
              txOldBaki,
              txMidPayment,
              txNewBaki,
            ])),
            customersStreamProvider.overrideWith((ref) => Stream.value([
              testCustomer1,
              testCustomer2,
            ])),
            settingsStreamProvider.overrideWith((ref) => Stream.value(testSettings)),
            transactionRepositoryProvider.overrideWithValue(_MockTransactionRepository()),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const HistoryScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Filter chips show counts
      expect(find.text('All (3)'), findsOneWidget);
      expect(find.text('Baki (2)'), findsOneWidget);
      expect(find.text('Payment (1)'), findsOneWidget);

      // Verify all 3 transactions are rendered
      expect(find.text('New stock order'), findsOneWidget);
      expect(find.text('Cash payment'), findsOneWidget);
      expect(find.text('Old groceries'), findsOneWidget);

      // Customer names displayed
      expect(find.text('Rahim Store'), findsNWidgets(2));
      expect(find.text('Karim Enterprise'), findsOneWidget);

      // Amounts formatted with signs and currency
      expect(find.text('+ ৳ 1,200.00'), findsOneWidget);
      expect(find.text('- ৳ 300.00'), findsOneWidget);
      expect(find.text('+ ৳ 500.00'), findsOneWidget);

      // Verify reverse-chronological order (txNewBaki is above txMidPayment, which is above txOldBaki)
      final topPos = tester.getTopLeft(find.text('New stock order')).dy;
      final midPos = tester.getTopLeft(find.text('Cash payment')).dy;
      final oldPos = tester.getTopLeft(find.text('Old groceries')).dy;

      expect(topPos < midPos, isTrue);
      expect(midPos < oldPos, isTrue);
    });

    testWidgets('Filter chips filter the list client-side', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            transactionsStreamProvider.overrideWith((ref) => Stream.value([
              txOldBaki,
              txMidPayment,
              txNewBaki,
            ])),
            customersStreamProvider.overrideWith((ref) => Stream.value([
              testCustomer1,
              testCustomer2,
            ])),
            settingsStreamProvider.overrideWith((ref) => Stream.value(testSettings)),
            transactionRepositoryProvider.overrideWithValue(_MockTransactionRepository()),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const HistoryScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Filter to Baki only
      await tester.tap(find.text('Baki (2)'));
      await tester.pumpAndSettle();

      expect(find.text('New stock order'), findsOneWidget);
      expect(find.text('Old groceries'), findsOneWidget);
      expect(find.text('Cash payment'), findsNothing);

      // Filter to Payment only
      await tester.tap(find.text('Payment (1)'));
      await tester.pumpAndSettle();

      expect(find.text('Cash payment'), findsOneWidget);
      expect(find.text('New stock order'), findsNothing);
      expect(find.text('Old groceries'), findsNothing);

      // Filter back to All
      await tester.tap(find.text('All (3)'));
      await tester.pumpAndSettle();

      expect(find.text('Cash payment'), findsOneWidget);
      expect(find.text('New stock order'), findsOneWidget);
      expect(find.text('Old groceries'), findsOneWidget);
    });

    testWidgets('Tapping card does not open edit modal, dedicated edit icon opens it', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            transactionsStreamProvider.overrideWith((ref) => Stream.value([
              txNewBaki,
            ])),
            customersStreamProvider.overrideWith((ref) => Stream.value([
              testCustomer1,
            ])),
            settingsStreamProvider.overrideWith((ref) => Stream.value(testSettings)),
            transactionRepositoryProvider.overrideWithValue(_MockTransactionRepository()),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const HistoryScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tapping on the transaction card should NOT open the edit modal
      await tester.tap(find.text('New stock order'));
      await tester.pumpAndSettle();
      expect(find.text('Edit Transaction'), findsNothing);

      // Verify amount, edit icon, and delete icon are vertically centered
      final amountCenter = tester.getCenter(find.text('+ ৳ 1,200.00'));
      final editIconCenter = tester.getCenter(find.byIcon(Icons.edit_outlined));
      final deleteIconCenter = tester.getCenter(find.byIcon(Icons.delete_outline_rounded));

      expect((amountCenter.dy - editIconCenter.dy).abs(), lessThanOrEqualTo(1.0));
      expect((editIconCenter.dy - deleteIconCenter.dy).abs(), lessThanOrEqualTo(1.0));

      // Tapping dedicated edit icon opens edit transaction dialog
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();

      // Edit Transaction dialog opened with segmented type toggle
      expect(find.text('Edit Transaction'), findsOneWidget);
      expect(find.byType(SegmentedButton<TransactionType>), findsOneWidget);
      expect(find.text('1200'), findsOneWidget);
      expect(find.text('New stock order'), findsNWidgets(2)); // in row + in text field
    });

    testWidgets('Delete icon opens confirmation dialog and deletes transaction', (tester) async {
      final mockRepo = _MockTransactionRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            transactionsStreamProvider.overrideWith((ref) => Stream.value([
              txNewBaki,
            ])),
            customersStreamProvider.overrideWith((ref) => Stream.value([
              testCustomer1,
            ])),
            settingsStreamProvider.overrideWith((ref) => Stream.value(testSettings)),
            transactionRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(
              body: HistoryScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap delete icon
      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await tester.pumpAndSettle();

      // Verify confirmation dialog
      expect(find.text('Delete Transaction?'), findsOneWidget);
      expect(
        find.textContaining('Are you sure you want to delete this baki of ৳ 1,200.00 for Rahim Store?'),
        findsOneWidget,
      );

      // Tap Delete button
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(mockRepo.deletedTransactionIds, contains('tx-3'));
      expect(find.text('Transaction deleted'), findsOneWidget);
    });

    testWidgets('Displays friendly empty state when no transactions exist', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            transactionsStreamProvider.overrideWith((ref) => Stream.value([])),
            customersStreamProvider.overrideWith((ref) => Stream.value([])),
            settingsStreamProvider.overrideWith((ref) => Stream.value(testSettings)),
            transactionRepositoryProvider.overrideWithValue(_MockTransactionRepository()),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const HistoryScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('No Transactions Yet'), findsOneWidget);
      expect(find.text('All (0)'), findsOneWidget);
    });

    testWidgets('Displays empty filter state when no transactions match active filter', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            transactionsStreamProvider.overrideWith((ref) => Stream.value([
              txNewBaki,
            ])),
            customersStreamProvider.overrideWith((ref) => Stream.value([
              testCustomer1,
            ])),
            settingsStreamProvider.overrideWith((ref) => Stream.value(testSettings)),
            transactionRepositoryProvider.overrideWithValue(_MockTransactionRepository()),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const HistoryScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Filter to Payment (count is 0)
      await tester.tap(find.text('Payment (0)'));
      await tester.pumpAndSettle();

      expect(find.text('No Payment Transactions'), findsOneWidget);
    });
  });
}

class _MockTransactionRepository implements TransactionRepository {
  final List<String> deletedTransactionIds = [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<void> deleteTransaction(String id) async {
    deletedTransactionIds.add(id);
  }
}
