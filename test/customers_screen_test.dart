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
import 'package:baki_khata/features/customers/customers_screen.dart';

void main() {
  final now = DateTime.now();

  final testCustomers = [
    Customer(
      id: 'cust-1',
      userId: 'user-1',
      name: 'Rahim Traders',
      phone: '01711111111',
      address: 'Dhanmondi, Dhaka',
      createdAt: now,
      updatedAt: now,
    ),
    Customer(
      id: 'cust-2',
      userId: 'user-1',
      name: 'Karim Store',
      phone: '01822222222',
      address: 'Gulshan, Dhaka',
      createdAt: now,
      updatedAt: now,
    ),
    Customer(
      id: 'cust-3',
      userId: 'user-1',
      name: 'Jamal Enterprise',
      phone: '01933333333',
      address: 'Agrabad, Chattogram',
      createdAt: now,
      updatedAt: now,
    ),
  ];

  final testTransactions = [
    // Rahim: 1500 baki, 500 payment -> Net balance = +1000 ("Due ৳1,000")
    AppTransaction(
      id: 'tx-1',
      userId: 'user-1',
      customerId: 'cust-1',
      type: TransactionType.baki,
      amount: 1500.0,
      date: now,
      createdAt: now,
      updatedAt: now,
    ),
    AppTransaction(
      id: 'tx-2',
      userId: 'user-1',
      customerId: 'cust-1',
      type: TransactionType.payment,
      amount: 500.0,
      date: now,
      createdAt: now,
      updatedAt: now,
    ),
    // Karim: 200 payment only -> Net balance = -200 ("Advance ৳200")
    AppTransaction(
      id: 'tx-3',
      userId: 'user-1',
      customerId: 'cust-2',
      type: TransactionType.payment,
      amount: 200.0,
      date: now,
      createdAt: now,
      updatedAt: now,
    ),
    // Jamal: 500 baki, 500 payment -> Net balance = 0 ("Settled")
    AppTransaction(
      id: 'tx-4',
      userId: 'user-1',
      customerId: 'cust-3',
      type: TransactionType.baki,
      amount: 500.0,
      date: now,
      createdAt: now,
      updatedAt: now,
    ),
    AppTransaction(
      id: 'tx-5',
      userId: 'user-1',
      customerId: 'cust-3',
      type: TransactionType.payment,
      amount: 500.0,
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

  testWidgets('CustomersScreen displays friendly empty state when no customers exist', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          customersStreamProvider.overrideWith((ref) => Stream.value([])),
          transactionsStreamProvider.overrideWith((ref) => Stream.value([])),
          settingsStreamProvider.overrideWith((ref) => Stream.value(testSettings)),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const CustomersScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('No customers yet'), findsOneWidget);
    expect(find.text('Add your first customer to start tracking credit and payments.'), findsOneWidget);
    expect(find.text('Add First Customer'), findsOneWidget);
  });

  testWidgets('CustomersScreen renders customer list with semantic balance badges', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          customersStreamProvider.overrideWith((ref) => Stream.value(testCustomers)),
          transactionsStreamProvider.overrideWith((ref) => Stream.value(testTransactions)),
          settingsStreamProvider.overrideWith((ref) => Stream.value(testSettings)),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const CustomersScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify search field is pinned at top
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Search by name, phone, or address...'), findsOneWidget);

    // Verify all 3 customers are displayed
    expect(find.text('Rahim Traders'), findsOneWidget);
    expect(find.text('Karim Store'), findsOneWidget);
    expect(find.text('Jamal Enterprise'), findsOneWidget);

    // Verify phones and phone icons
    expect(find.text('01711111111'), findsOneWidget);
    expect(find.text('01822222222'), findsOneWidget);
    expect(find.text('01933333333'), findsOneWidget);
    expect(find.byIcon(Icons.phone_outlined), findsNWidgets(3));

    // Verify balance badges:
    // Rahim: Due ৳1,000 (red)
    expect(find.text('Due ৳1,000'), findsOneWidget);
    // Karim: Advance ৳200 (teal)
    expect(find.text('Advance ৳200'), findsOneWidget);
    // Jamal: Settled (slate)
    expect(find.text('Settled'), findsOneWidget);
  });

  testWidgets('CustomersScreen live search filters by name, phone, and address', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          customersStreamProvider.overrideWith((ref) => Stream.value(testCustomers)),
          transactionsStreamProvider.overrideWith((ref) => Stream.value(testTransactions)),
          settingsStreamProvider.overrideWith((ref) => Stream.value(testSettings)),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const CustomersScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Search by name (case-insensitive: "rahim")
    await tester.enterText(find.byType(TextField), 'rahim');
    await tester.pumpAndSettle();
    expect(find.text('Rahim Traders'), findsOneWidget);
    expect(find.text('Karim Store'), findsNothing);
    expect(find.text('Jamal Enterprise'), findsNothing);

    // 2. Search by phone substring ("01822")
    await tester.enterText(find.byType(TextField), '01822');
    await tester.pumpAndSettle();
    expect(find.text('Karim Store'), findsOneWidget);
    expect(find.text('Rahim Traders'), findsNothing);
    expect(find.text('Jamal Enterprise'), findsNothing);

    // 3. Search by address ("chattogram")
    await tester.enterText(find.byType(TextField), 'chattogram');
    await tester.pumpAndSettle();
    expect(find.text('Jamal Enterprise'), findsOneWidget);
    expect(find.text('Rahim Traders'), findsNothing);
    expect(find.text('Karim Store'), findsNothing);

    // 4. Search with no match -> Shows "No matching customers"
    await tester.enterText(find.byType(TextField), 'nonexistent');
    await tester.pumpAndSettle();
    expect(find.text('No matching customers'), findsOneWidget);
    expect(find.text('No results found for "nonexistent"'), findsOneWidget);

    // 5. Clear search -> restores all customers
    await tester.tap(find.text('Clear Search'));
    await tester.pumpAndSettle();
    expect(find.text('Rahim Traders'), findsOneWidget);
    expect(find.text('Karim Store'), findsOneWidget);
    expect(find.text('Jamal Enterprise'), findsOneWidget);
  });

  testWidgets('Tapping a customer card navigates to CustomerDetailsScreen', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          customersStreamProvider.overrideWith((ref) => Stream.value(testCustomers)),
          customerTransactionsStreamProvider('cust-1').overrideWith(
            (ref) => Stream.value(testTransactions),
          ),
          transactionsStreamProvider.overrideWith((ref) => Stream.value(testTransactions)),
          settingsStreamProvider.overrideWith((ref) => Stream.value(testSettings)),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const CustomersScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Tap Rahim Traders
    await tester.tap(find.text('Rahim Traders'));
    await tester.pumpAndSettle();

    // Verify CustomerDetailsScreen is pushed
    expect(find.byType(CustomerDetailsScreen), findsOneWidget);
    expect(find.text('Transaction History'), findsOneWidget);
  });

  testWidgets('CustomersScreen tab filters correctly categorize customers by status', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          customersStreamProvider.overrideWith((ref) => Stream.value(testCustomers)),
          transactionsStreamProvider.overrideWith((ref) => Stream.value(testTransactions)),
          settingsStreamProvider.overrideWith((ref) => Stream.value(testSettings)),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const CustomersScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Verify all 4 filter chips exist with correct counts
    expect(find.text('All (3)'), findsOneWidget);
    expect(find.text('Due (1)'), findsOneWidget);
    expect(find.text('Advance (1)'), findsOneWidget);
    expect(find.text('Settled (1)'), findsOneWidget);

    // Initial state: All (3) is selected, shows aggregate banner
    expect(find.textContaining('Total Due: ৳1,000.00'), findsOneWidget);

    // 2. Tap "Due (1)" filter chip
    await tester.tap(find.text('Due (1)'));
    await tester.pumpAndSettle();

    expect(find.text('Rahim Traders'), findsOneWidget);
    expect(find.text('Karim Store'), findsNothing);
    expect(find.text('Jamal Enterprise'), findsNothing);
    expect(find.textContaining('1 customer owes a total of ৳1,000.00'), findsOneWidget);

    // 3. Tap "Advance (1)" filter chip
    await tester.tap(find.text('Advance (1)'));
    await tester.pumpAndSettle();

    expect(find.text('Karim Store'), findsOneWidget);
    expect(find.text('Rahim Traders'), findsNothing);
    expect(find.text('Jamal Enterprise'), findsNothing);
    expect(find.textContaining('1 customer has advance of ৳200.00'), findsOneWidget);

    // 4. Tap "Settled (1)" filter chip
    await tester.tap(find.text('Settled (1)'));
    await tester.pumpAndSettle();

    expect(find.text('Jamal Enterprise'), findsOneWidget);
    expect(find.text('Rahim Traders'), findsNothing);
    expect(find.text('Karim Store'), findsNothing);
    expect(find.textContaining('1 customer with settled account'), findsOneWidget);

    // 5. Switch back to "All (3)"
    await tester.tap(find.text('All (3)'));
    await tester.pumpAndSettle();

    expect(find.text('Rahim Traders'), findsOneWidget);
    expect(find.text('Karim Store'), findsOneWidget);
    expect(find.text('Jamal Enterprise'), findsOneWidget);
  });

  testWidgets('CustomersScreen shows tailored empty state when filter has zero matches', (tester) async {
    // Only 1 customer with due balance (Rahim)
    final dueOnlyCustomer = [testCustomers[0]];
    final dueOnlyTransactions = [testTransactions[0]];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          customersStreamProvider.overrideWith((ref) => Stream.value(dueOnlyCustomer)),
          transactionsStreamProvider.overrideWith((ref) => Stream.value(dueOnlyTransactions)),
          settingsStreamProvider.overrideWith((ref) => Stream.value(testSettings)),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const CustomersScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Tap Advance (which has 0 customers)
    await tester.tap(find.text('Advance (0)'));
    await tester.pumpAndSettle();

    expect(find.text('No advance payments'), findsOneWidget);
    expect(find.text('None of your customers have deposited advance credit.'), findsOneWidget);
    expect(find.text('View All Customers'), findsOneWidget);

    // Tap "View All Customers" to return to all
    await tester.tap(find.text('View All Customers'));
    await tester.pumpAndSettle();

    expect(find.text('Rahim Traders'), findsOneWidget);
  });

  testWidgets('CustomersScreen sort menu reorders customer list', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          customersStreamProvider.overrideWith((ref) => Stream.value(testCustomers)),
          transactionsStreamProvider.overrideWith((ref) => Stream.value(testTransactions)),
          settingsStreamProvider.overrideWith((ref) => Stream.value(testSettings)),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const CustomersScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify sort button is present
    expect(find.byIcon(Icons.sort_rounded), findsOneWidget);

    // Open sort menu
    await tester.tap(find.byIcon(Icons.sort_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Name (A–Z)'), findsOneWidget);
    expect(find.text('Highest Due'), findsOneWidget);
    expect(find.text('Recently Added'), findsOneWidget);

    // Select "Highest Due"
    await tester.tap(find.text('Highest Due'));
    await tester.pumpAndSettle();

    // Verify list is rendered and first item is Rahim Traders (highest balance = 1000)
    final customerCards = find.byType(Card);
    expect(customerCards, findsNWidgets(3));
  });
}
