import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:baki_khata/core/theme.dart';
import 'package:baki_khata/data/models/app_settings.dart';
import 'package:baki_khata/data/models/customer.dart';
import 'package:baki_khata/data/models/transaction.dart';
import 'package:baki_khata/data/repositories/customer_repository.dart';
import 'package:baki_khata/data/repositories/settings_repository.dart';
import 'package:baki_khata/data/repositories/transaction_repository.dart';
import 'package:baki_khata/features/customers/customer_details_screen.dart';
import 'package:baki_khata/features/reminders/services/reminder_message_builder.dart';
import 'package:baki_khata/features/reminders/services/reminder_tracker_service.dart';
import 'package:baki_khata/features/reminders/widgets/whatsapp_reminder_sheet.dart';
import 'package:baki_khata/l10n/generated/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime(2026, 10, 6, 14, 30);

  final testCustomer = Customer(
    id: 'cust-101',
    userId: 'user-1',
    name: 'Kashem Store',
    phone: '01712345678',
    address: 'Mirpur, Dhaka',
    createdAt: now,
    updatedAt: now,
  );

  final testCustomerNoPhone = Customer(
    id: 'cust-102',
    userId: 'user-1',
    name: 'Hashem Mia',
    phone: null,
    address: 'Gulshan, Dhaka',
    createdAt: now,
    updatedAt: now,
  );

  final testSettings = AppSettings(
    userId: 'user-1',
    shopName: 'Bismillah General Store',
    shopPhone: '01812345678',
    shopAddress: 'Road 5, Mirpur 10',
    currencySymbol: '৳',
    updatedAt: now,
  );

  group('ReminderMessageBuilder Unit Tests', () {
    test('builds polite due reminder in Bengali', () {
      final message = ReminderMessageBuilder.build(
        customer: testCustomer,
        balance: 2500.0,
        settings: testSettings,
        lastTransactionDate: now.subtract(const Duration(days: 3)),
        tone: ReminderTone.polite,
        isBengali: true,
      );

      expect(message, contains('Bismillah General Store'));
      expect(message, contains('Kashem Store'));
      expect(message, contains('🔔 বাকি তাগাদা'));
      expect(message, contains('বর্তমান মোট বাকি: ৳ ২,৫০০'));
      expect(message, contains('*পরিশোধের মাধ্যম (বিকাশ/নগদ/দোকান):* 01812345678'));
      expect(message, contains('আসসালামু আলাইকুম'));
    });

    test('builds urgent due reminder in English', () {
      final message = ReminderMessageBuilder.build(
        customer: testCustomer,
        balance: 5000.0,
        settings: testSettings,
        lastTransactionDate: now.subtract(const Duration(days: 15)),
        tone: ReminderTone.urgent,
        isBengali: false,
      );

      expect(message, contains('🚨 URGENT DUE REMINDER'));
      expect(message, contains('Total Net Due: ৳ 5,000'));
      expect(message, contains('Urgent Notice: Your credit balance is overdue.'));
      expect(message, contains('*Payment Method (bKash/Nagad/Shop):* 01812345678'));
    });

    test('builds account statement for settled account', () {
      final message = ReminderMessageBuilder.build(
        customer: testCustomer,
        balance: 0.0,
        settings: testSettings,
        tone: ReminderTone.statement,
        isBengali: true,
      );

      expect(message, contains('📋 হিসাব বিবরণী'));
      expect(message, contains('হিসাব সম্পূর্ণ পরিশোধিত'));
      expect(message, contains('আপনার কোনো বকেয়া বাকি নেই'));
    });

    test('builds account statement for advance balance in Bengali', () {
      final message = ReminderMessageBuilder.build(
        customer: testCustomer,
        balance: -750.0,
        settings: testSettings,
        tone: ReminderTone.statement,
        isBengali: true,
      );

      expect(message, contains('📋 হিসাব বিবরণী'));
      expect(message, contains('অগ্রিম জমা: ৳ ৭৫০'));
      expect(message, contains('আপনার অগ্রিম টাকা জমা আছে'));
    });

    test('builds reminder with configured digital payment gateways and TrxID prompt in Bengali', () {
      final digitalSettings = testSettings.copyWith(
        bkashNumber: '01711001122',
        bkashIsMerchant: false,
        nagadNumber: '01822334455',
        nagadIsMerchant: true,
      );

      final message = ReminderMessageBuilder.build(
        customer: testCustomer,
        balance: 3200.0,
        settings: digitalSettings,
        tone: ReminderTone.polite,
        isBengali: true,
      );

      expect(message, contains('💳 *পরিশোধের মাধ্যম:*'));
      expect(message, contains('• বিকাশ (পার্সোনাল - Send Money): 01711001122'));
      expect(message, contains('• নগদ (মার্চেন্ট - Make Payment): 01822334455'));
      expect(message, contains('📌 টাকা পাঠিয়ে ট্রানজেকশন আইডি (TrxID) বা স্ক্রিনশট পাঠিয়ে নিশ্চিত করুন।'));
    });

    test('builds reminder with configured digital payment gateways and TrxID prompt in English', () {
      final digitalSettings = testSettings.copyWith(
        bkashNumber: '01711001122',
        bkashIsMerchant: false,
        rocketNumber: '01933445566',
        rocketIsMerchant: true,
      );

      final message = ReminderMessageBuilder.build(
        customer: testCustomer,
        balance: 1500.0,
        settings: digitalSettings,
        tone: ReminderTone.urgent,
        isBengali: false,
      );

      expect(message, contains('💳 *Payment Methods:*'));
      expect(message, contains('• bKash (Personal - Send Money): 01711001122'));
      expect(message, contains('• Rocket (Merchant - Make Payment): 01933445566'));
      expect(message, contains('📌 After payment, please reply with TrxID or screenshot to confirm.'));
    });
  });

  group('ReminderTrackerService Unit Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('records and retrieves last reminder timestamp', () async {
      final initial = await ReminderTrackerService.getLastReminderDate('cust-101');
      expect(initial, isNull);

      await ReminderTrackerService.recordReminderSent('cust-101');

      final recorded = await ReminderTrackerService.getLastReminderDate('cust-101');
      expect(recorded, isNotNull);
      expect(recorded!.difference(DateTime.now()).inSeconds.abs(), lessThan(5));
    });

    test('formats relative time strings correctly', () {
      expect(ReminderTrackerService.formatRelativeTime(null), isNull);

      final justNow = DateTime.now().subtract(const Duration(seconds: 30));
      expect(
        ReminderTrackerService.formatRelativeTime(justNow, isBengali: true),
        equals('এইমাত্র'),
      );
      expect(
        ReminderTrackerService.formatRelativeTime(justNow, isBengali: false),
        equals('Just now'),
      );

      final fiveMinsAgo = DateTime.now().subtract(const Duration(minutes: 5));
      expect(
        ReminderTrackerService.formatRelativeTime(fiveMinsAgo, isBengali: true),
        contains('মিনিট আগে'),
      );

      final threeDaysAgo = DateTime.now().subtract(const Duration(days: 3));
      expect(
        ReminderTrackerService.formatRelativeTime(threeDaysAgo, isBengali: true),
        contains('দিন আগে'),
      );
      expect(
        ReminderTrackerService.formatRelativeTime(threeDaysAgo, isBengali: false),
        contains('days ago'),
      );
    });
  });

  group('Customer Details Screen Reminder Integration Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('renders WhatsApp action button and banner for customer with phone and due', (tester) async {
      final txDue = [
        AppTransaction(
          id: 'tx-1',
          userId: 'user-1',
          customerId: 'cust-101',
          type: TransactionType.baki,
          amount: 2000.0,
          date: now,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            customersStreamProvider.overrideWith((ref) => Stream.value([testCustomer])),
            customerTransactionsStreamProvider('cust-101').overrideWith(
              (ref) => Stream.value(txDue),
            ),
            settingsStreamProvider.overrideWith((ref) => Stream.value(testSettings)),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const CustomerDetailsScreen(customerId: 'cust-101'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify "WhatsApp" action appears in phone row and banner
      expect(find.text('WhatsApp'), findsNWidgets(2));
      expect(find.text('Send Due Reminder'), findsOneWidget);

      // Tap reminder banner to open bottom sheet
      await tester.tap(find.text('Send Due Reminder'));
      await tester.pumpAndSettle();

      // Verify bottom sheet opened
      expect(find.byType(WhatsAppReminderSheet), findsOneWidget);
      expect(find.text('WhatsApp Reminder'), findsOneWidget);
      expect(find.text('Open WhatsApp'), findsOneWidget);
      expect(find.text('Share via Other'), findsOneWidget);
      expect(find.text('Polite'), findsOneWidget);
      expect(find.text('Urgent'), findsOneWidget);
      expect(find.text('Statement'), findsOneWidget);
      expect(
        find.text('Add bKash or Nagad in Settings to include payment info in reminders'),
        findsOneWidget,
      );

      // Verify switching tone
      await tester.tap(find.text('Urgent'));
      await tester.pumpAndSettle();
      expect(find.textContaining('URGENT DUE REMINDER'), findsOneWidget);

      // Close sheet
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(find.byType(WhatsAppReminderSheet), findsNothing);
    });

    testWidgets('renders Add Phone prompt when customer has no phone number', (tester) async {
      final txDue = [
        AppTransaction(
          id: 'tx-2',
          userId: 'user-1',
          customerId: 'cust-102',
          type: TransactionType.baki,
          amount: 1500.0,
          date: now,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            customersStreamProvider.overrideWith((ref) => Stream.value([testCustomerNoPhone])),
            customerTransactionsStreamProvider('cust-102').overrideWith(
              (ref) => Stream.value(txDue),
            ),
            settingsStreamProvider.overrideWith((ref) => Stream.value(testSettings)),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const CustomerDetailsScreen(customerId: 'cust-102'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify add phone prompt is rendered
      expect(find.text('Add phone number to send reminder'), findsOneWidget);
      expect(find.text('+ Add Phone'), findsOneWidget);
    });
  });
}
