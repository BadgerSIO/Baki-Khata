import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:baki_khata/data/models/app_settings.dart';
import 'package:baki_khata/data/models/customer.dart';
import 'package:baki_khata/data/models/transaction.dart';
import 'package:baki_khata/data/repositories/transaction_repository.dart';
import 'package:baki_khata/features/vouchers/voucher_card.dart';
import 'package:baki_khata/features/vouchers/voucher_model.dart';
import 'package:baki_khata/features/vouchers/voucher_preview_sheet.dart';
import 'package:baki_khata/features/vouchers/voucher_service.dart';
import 'package:baki_khata/l10n/generated/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testDate = DateTime(2026, 10, 6, 14, 30);

  final testCustomer = Customer(
    id: 'cust-123',
    userId: 'user-1',
    name: 'Kashem Store',
    phone: '01812345678',
    address: 'Chawkbazar, Chittagong',
    createdAt: testDate,
    updatedAt: testDate,
  );

  final testSettings = AppSettings(
    userId: 'user-1',
    shopName: 'Bismillah General Store',
    shopPhone: '01700000000',
    shopAddress: 'Mirpur-10, Dhaka',
    currencySymbol: '৳',
    autoShowReceipt: true,
    updatedAt: testDate,
  );

  group('VoucherItem', () {
    test('toMap and fromMap serialize and deserialize correctly', () {
      const item = VoucherItem(
        name: 'Miniket Rice 25kg',
        quantity: '2 bags',
        rate: 1800.0,
        total: 3600.0,
      );

      final map = item.toMap();
      expect(map['name'], 'Miniket Rice 25kg');
      expect(map['quantity'], '2 bags');
      expect(map['rate'], 1800.0);
      expect(map['total'], 3600.0);

      final fromMap = VoucherItem.fromMap(map);
      expect(fromMap.name, item.name);
      expect(fromMap.quantity, item.quantity);
      expect(fromMap.rate, item.rate);
      expect(fromMap.total, item.total);
    });
  });

  group('ItemParser', () {
    test('serialize and parse multiple items with notes', () {
      final items = [
        const VoucherItem(name: 'Soybean Oil', quantity: '5L', rate: 190.0, total: 950.0),
        const VoucherItem(name: 'Sugar', quantity: '2kg', rate: 135.0, total: 270.0),
      ];
      const notes = 'Urgent delivery by evening';

      final serialized = ItemParser.serialize(items, notes: notes);
      expect(serialized.contains('[ITEMS]'), isTrue);
      expect(serialized.contains('[/ITEMS]'), isTrue);
      expect(serialized.contains('Soybean Oil|5L|190.0|950.0'), isTrue);
      expect(serialized.contains('Sugar|2kg|135.0|270.0'), isTrue);
      expect(serialized.contains(notes), isTrue);

      final parsed = ItemParser.parse(serialized);
      expect(parsed.items.length, 2);
      expect(parsed.items[0].name, 'Soybean Oil');
      expect(parsed.items[0].quantity, '5L');
      expect(parsed.items[0].rate, 190.0);
      expect(parsed.items[0].total, 950.0);
      expect(parsed.items[1].name, 'Sugar');
      expect(parsed.items[1].quantity, '2kg');
      expect(parsed.items[1].rate, 135.0);
      expect(parsed.items[1].total, 270.0);
      expect(parsed.notes, notes);
    });

    test('serialize returns only notes when items list is empty', () {
      final serialized = ItemParser.serialize([], notes: 'General grocery loan');
      expect(serialized, 'General grocery loan');
      expect(serialized.contains('[ITEMS]'), isFalse);
    });

    test('parse legacy plaintext notes without tags returns items empty and preserves notes', () {
      const legacyDesc = 'Customer took 500 taka cash advance';
      final parsed = ItemParser.parse(legacyDesc);
      expect(parsed.items, isEmpty);
      expect(parsed.notes, legacyDesc);
    });

    test('parse handles corrupt tags gracefully', () {
      const corrupt = '[ITEMS]Only one tag';
      final parsed = ItemParser.parse(corrupt);
      expect(parsed.items, isEmpty);
      expect(parsed.notes, corrupt);
    });

    test('serialize replaces pipe characters in item fields to avoid corrupting delimiter', () {
      final items = [
        const VoucherItem(name: 'Item | Special', quantity: '1|pack', total: 100.0),
      ];
      final serialized = ItemParser.serialize(items);
      final parsed = ItemParser.parse(serialized);
      expect(parsed.items.length, 1);
      expect(parsed.items.first.name, 'Item - Special');
      expect(parsed.items.first.quantity, '1-pack');
    });
  });

  group('PhoneUtils', () {
    test('normalizeForWhatsApp sanitizes Bangladeshi and international formats', () {
      // Local 11-digit format starting with 01
      expect(PhoneUtils.normalizeForWhatsApp('01812345678'), '8801812345678');
      expect(PhoneUtils.normalizeForWhatsApp('+8801812345678'), '8801812345678');
      expect(PhoneUtils.normalizeForWhatsApp('8801812345678'), '8801812345678');

      // 10-digit format starting with 1
      expect(PhoneUtils.normalizeForWhatsApp('1812345678'), '8801812345678');

      // With dashes or spaces
      expect(PhoneUtils.normalizeForWhatsApp('018-1234-5678'), '8801812345678');
      expect(PhoneUtils.normalizeForWhatsApp('+88 018 12345678'), '8801812345678');

      // International number >= 7 digits
      expect(PhoneUtils.normalizeForWhatsApp('+1-555-123-4567'), '15551234567');

      // Too short or invalid
      expect(PhoneUtils.normalizeForWhatsApp('12345'), isNull);
      expect(PhoneUtils.normalizeForWhatsApp(''), isNull);
      expect(PhoneUtils.normalizeForWhatsApp(null), isNull);
    });

    test('toBengaliNumber converts digits correctly', () {
      expect(PhoneUtils.toBengaliNumber('0123456789'), '০১২৩৪৫৬৭৮৯');
      expect(PhoneUtils.toBengaliNumber('Total: 500.50'), 'Total: ৫০০.৫০');
    });
  });

  group('VoucherData & VoucherService', () {
    final creditTx = AppTransaction(
      id: 'tx-001-abcdef',
      userId: 'user-1',
      customerId: 'cust-123',
      type: TransactionType.baki,
      amount: 1220.0,
      description: ItemParser.serialize([
        const VoucherItem(name: 'Soybean Oil', quantity: '5L', rate: 190.0, total: 950.0),
        const VoucherItem(name: 'Sugar', quantity: '2kg', rate: 135.0, total: 270.0),
      ], notes: 'Paid 0 today'),
      date: testDate,
      createdAt: testDate,
      updatedAt: testDate,
    );

    const snapshot = VoucherBalanceSnapshot(
      balanceBefore: 300.0,
      transactionAmount: 1220.0,
      type: TransactionType.baki,
      balanceAfter: 1520.0,
    );

    final voucherData = VoucherData.fromTransaction(
      transaction: creditTx,
      customer: testCustomer,
      settings: testSettings,
      balance: snapshot,
    );

    test('generates formatted voucher code', () {
      expect(voucherData.voucherNumber, '#BK-TX001A');
    });

    test('generateTextReceipt formats credit memo correctly in English and Bengali', () {
      final textBn = VoucherService.generateTextReceipt(voucherData, isBengali: true);
      expect(textBn.contains('Bismillah General Store'), isTrue);
      expect(textBn.contains('বাকি চালান'), isTrue);
      expect(textBn.contains('Kashem Store'), isTrue);
      expect(textBn.contains('Soybean Oil'), isTrue);
      expect(textBn.contains('Sugar'), isTrue);
      expect(textBn.contains('বর্তমান মোট বাকি'), isTrue);
      expect(textBn.contains('বাকি খাতা অ্যাপের মাধ্যমে তৈরি'), isTrue);

      final textEn = VoucherService.generateTextReceipt(voucherData, isBengali: false);
      expect(textEn.contains('CREDIT MEMO'), isTrue);
      expect(textEn.contains('Customer:'), isTrue);
      expect(textEn.contains('Total Net Due:'), isTrue);
      expect(textEn.contains('Generated by Baki Khata App'), isTrue);
    });

    test('generateTextReceipt formats payment settlement correctly', () {
      final paymentTx = AppTransaction(
        id: 'tx-002-payment',
        userId: 'user-1',
        customerId: 'cust-123',
        type: TransactionType.payment,
        amount: 1520.0,
        description: 'Full settlement via bKash',
        date: testDate,
        createdAt: testDate,
        updatedAt: testDate,
      );

      const paymentSnapshot = VoucherBalanceSnapshot(
        balanceBefore: 1520.0,
        transactionAmount: 1520.0,
        type: TransactionType.payment,
        balanceAfter: 0.0,
      );

      final paymentData = VoucherData.fromTransaction(
        transaction: paymentTx,
        customer: testCustomer,
        settings: testSettings,
        balance: paymentSnapshot,
      );

      final textBn = VoucherService.generateTextReceipt(paymentData, isBengali: true);
      expect(textBn.contains('জমা রসিদ'), isTrue);
      expect(textBn.contains('হিসাব পরিশোধিত'), isTrue);
      expect(textBn.contains('Full settlement via bKash'), isTrue);

      final textEn = VoucherService.generateTextReceipt(paymentData, isBengali: false);
      expect(textEn.contains('PAYMENT RECEIPT'), isTrue);
      expect(textEn.contains('Fully Settled'), isTrue);
    });
  });

  group('VoucherCard Widget', () {
    final txWithItems = AppTransaction(
      id: 'tx-widget-1',
      userId: 'user-1',
      customerId: 'cust-123',
      type: TransactionType.baki,
      amount: 500.0,
      description: ItemParser.serialize([
        const VoucherItem(name: 'Mustard Oil 1L', quantity: '1', rate: 300.0, total: 300.0),
        const VoucherItem(name: 'Lentils (ডাল)', quantity: '1kg', rate: 200.0, total: 200.0),
      ], notes: 'Payment expected on Saturday'),
      date: testDate,
      createdAt: testDate,
      updatedAt: testDate,
    );

    const snapshot = VoucherBalanceSnapshot(
      balanceBefore: 1000.0,
      transactionAmount: 500.0,
      type: TransactionType.baki,
      balanceAfter: 1500.0,
    );

    final voucherData = VoucherData.fromTransaction(
      transaction: txWithItems,
      customer: testCustomer,
      settings: testSettings,
      balance: snapshot,
    );

    testWidgets('renders shop header, customer info, item table and net balance', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: VoucherCard(data: voucherData, isBengali: false),
            ),
          ),
        ),
      );

      // Shop Information
      expect(find.text('Bismillah General Store'), findsOneWidget);
      expect(find.text('Mirpur-10, Dhaka'), findsOneWidget);
      expect(find.text('📞 01700000000'), findsOneWidget);

      // Customer & Badge
      expect(find.text('Kashem Store'), findsOneWidget);
      expect(find.text('01812345678'), findsOneWidget);
      expect(find.text('CREDIT MEMO'), findsOneWidget);

      // Items Table
      expect(find.text('1. Mustard Oil 1L'), findsOneWidget);
      expect(find.text('2. Lentils (ডাল)'), findsOneWidget);

      // Ledger Balance summary
      expect(find.text('Current Credit Amount:'), findsOneWidget);
      expect(find.text('Previous Due:'), findsOneWidget);
      expect(find.text('🔴 Total Net Due:'), findsOneWidget);
      expect(find.text('৳ 1,500'), findsOneWidget);
      expect(find.text('Powered by Baki Khata App'), findsOneWidget);
    });

    testWidgets('renders Bengali mode properly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: VoucherCard(data: voucherData, isBengali: true),
            ),
          ),
        ),
      );

      expect(find.text('বাকি চালান'), findsOneWidget);
      expect(find.text('কাস্টমার'), findsOneWidget);
      expect(find.text('পণ্যের বিবরণ'), findsOneWidget);
      expect(find.text('🔴 বর্তমান মোট বাকি:'), findsOneWidget);
      expect(find.text('বাকি খাতা অ্যাপ দ্বারা সুরক্ষিত'), findsOneWidget);
    });
  });

  group('VoucherPreviewSheet Widget', () {
    final tx = AppTransaction(
      id: 'tx-sheet-1',
      userId: 'user-1',
      customerId: 'cust-123',
      type: TransactionType.baki,
      amount: 250.0,
      description: 'Quick credit memo',
      date: testDate,
      createdAt: testDate,
      updatedAt: testDate,
    );

    const snapshot = VoucherBalanceSnapshot(
      balanceBefore: 0.0,
      transactionAmount: 250.0,
      type: TransactionType.baki,
      balanceAfter: 250.0,
    );

    final voucherData = VoucherData.fromTransaction(
      transaction: tx,
      customer: testCustomer,
      settings: testSettings,
      balance: snapshot,
    );

    testWidgets('renders action buttons and copies text to clipboard', (tester) async {
      final List<MethodCall> log = [];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall methodCall) async {
          log.add(methodCall);
          return null;
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VoucherPreviewSheet(data: voucherData),
          ),
        ),
      );

      // Action buttons presence
      expect(find.byIcon(Icons.send_rounded), findsOneWidget);
      expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsOneWidget);
      expect(find.byIcon(Icons.download_rounded), findsOneWidget);
      expect(find.byIcon(Icons.copy_rounded), findsOneWidget);

      // Tap Copy Text
      await tester.tap(find.byIcon(Icons.copy_rounded));
      await tester.pumpAndSettle();

      // Check snackbar in English (default locale)
      expect(find.text('Voucher details copied to clipboard'), findsOneWidget);

      // Verify clipboard interaction
      expect(log.any((call) => call.method == 'Clipboard.setData'), isTrue);
    });

    testWidgets('renders action buttons and copies text in Bengali locale', (tester) async {
      final List<MethodCall> log = [];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall methodCall) async {
          log.add(methodCall);
          return null;
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('bn'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: VoucherPreviewSheet(data: voucherData),
          ),
        ),
      );

      // Tap Copy Text
      await tester.tap(find.byIcon(Icons.copy_rounded));
      await tester.pumpAndSettle();

      // Check snackbar in Bengali
      expect(find.text('ভাউচারের বিবরণ ক্লিপবোর্ডে কপি করা হয়েছে'), findsOneWidget);
      expect(log.any((call) => call.method == 'Clipboard.setData'), isTrue);
    });
  });
}
