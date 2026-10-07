import 'package:baki_khata/data/models/app_settings.dart';
import 'package:baki_khata/data/models/customer.dart';
import 'package:baki_khata/data/models/transaction.dart';
import 'package:baki_khata/features/statements/models/statement_models.dart';
import 'package:baki_khata/features/statements/services/html_statement_builder.dart';
import 'package:baki_khata/features/statements/services/ledger_calculator_service.dart';
import 'package:baki_khata/features/statements/services/pdf_statement_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LedgerCalculatorService Unit Tests', () {
    final testSettings = AppSettings(
      userId: 'user_1',
      shopName: 'Bismillah General Store',
      proprietorName: 'Md. Rafiqul Islam',
      shopPhone: '01812345678',
      shopAddress: 'Mirpur 10, Dhaka',
      currencySymbol: '৳',
      updatedAt: DateTime.now(),
    );

    final testCustomer = Customer(
      id: 'cust_1',
      userId: 'user_1',
      name: 'Kashem Traders',
      phone: '01711223344',
      address: 'Shop 4, Mirpur',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    test('computes customer statement with opening balance and running ledger correctly', () {
      // Prior transactions (before Sept 1, 2026)
      final txPrior1 = AppTransaction(
        id: 'tx_p1',
        userId: 'user_1',
        customerId: 'cust_1',
        type: TransactionType.baki,
        amount: 1000.0,
        description: 'Initial goods',
        date: DateTime(2026, 8, 10),
        createdAt: DateTime(2026, 8, 10),
        updatedAt: DateTime(2026, 8, 10),
      );

      final txPrior2 = AppTransaction(
        id: 'tx_p2',
        userId: 'user_1',
        customerId: 'cust_1',
        type: TransactionType.payment,
        amount: 400.0,
        description: 'Cash payment',
        date: DateTime(2026, 8, 20),
        createdAt: DateTime(2026, 8, 20),
        updatedAt: DateTime(2026, 8, 20),
      );

      // In-period transactions (Sept 1 to Sept 30, 2026)
      final txPeriod1 = AppTransaction(
        id: 'tx_1',
        userId: 'user_1',
        customerId: 'cust_1',
        type: TransactionType.baki,
        amount: 500.0,
        description: '[ITEMS]\n5kg Miniket Rice|5kg|60|300\n1L Soyabean Oil|1L|200|200\n[/ITEMS]\nHome delivery',
        date: DateTime(2026, 9, 5),
        createdAt: DateTime(2026, 9, 5),
        updatedAt: DateTime(2026, 9, 5),
      );

      final txPeriod2 = AppTransaction(
        id: 'tx_2',
        userId: 'user_1',
        customerId: 'cust_1',
        type: TransactionType.payment,
        amount: 200.0,
        description: 'bKash paid',
        date: DateTime(2026, 9, 15),
        createdAt: DateTime(2026, 9, 15),
        updatedAt: DateTime(2026, 9, 15),
      );

      final allTxs = [txPeriod2, txPrior1, txPeriod1, txPrior2];

      final period = StatementPeriod(
        type: StatementPeriodType.custom,
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 9, 30),
      );

      final statement = LedgerCalculatorService.computeCustomerStatement(
        customer: testCustomer,
        allTransactions: allTxs,
        settings: testSettings,
        period: period,
        isDetailed: true,
      );

      // Opening balance: 1000 - 400 = 600
      expect(statement.openingBalance, 600.0);

      // Period totals
      expect(statement.totalBaki, 500.0);
      expect(statement.totalPayment, 200.0);
      expect(statement.closingBalance, 900.0);

      // Entries should be sorted chronologically
      expect(statement.entries.length, 2);

      // Entry 1
      expect(statement.entries[0].transaction.id, 'tx_1');
      expect(statement.entries[0].debit, 500.0);
      expect(statement.entries[0].credit, 0.0);
      expect(statement.entries[0].runningBalance, 1100.0); // 600 + 500
      expect(statement.entries[0].items.length, 2);
      expect(statement.entries[0].items[0].name, '5kg Miniket Rice');
      expect(statement.entries[0].items[1].name, '1L Soyabean Oil');

      // Entry 2
      expect(statement.entries[1].transaction.id, 'tx_2');
      expect(statement.entries[1].debit, 0.0);
      expect(statement.entries[1].credit, 200.0);
      expect(statement.entries[1].runningBalance, 900.0); // 1100 - 200
    });

    test('computes store-wide master statement summary across multiple customers', () {
      final cust2 = Customer(
        id: 'cust_2',
        userId: 'user_1',
        name: 'Rahim Store',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      final txCust1 = AppTransaction(
        id: 't1',
        userId: 'user_1',
        customerId: 'cust_1',
        type: TransactionType.baki,
        amount: 800.0,
        date: DateTime(2026, 9, 10),
        createdAt: DateTime(2026, 9, 10),
        updatedAt: DateTime(2026, 9, 10),
      );

      final txCust2Prior = AppTransaction(
        id: 't2',
        userId: 'user_1',
        customerId: 'cust_2',
        type: TransactionType.baki,
        amount: 2000.0,
        date: DateTime(2026, 8, 1),
        createdAt: DateTime(2026, 8, 1),
        updatedAt: DateTime(2026, 8, 1),
      );

      final txCust2Period = AppTransaction(
        id: 't3',
        userId: 'user_1',
        customerId: 'cust_2',
        type: TransactionType.payment,
        amount: 500.0,
        date: DateTime(2026, 9, 12),
        createdAt: DateTime(2026, 9, 12),
        updatedAt: DateTime(2026, 9, 12),
      );

      final period = StatementPeriod(
        type: StatementPeriodType.custom,
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 9, 30),
      );

      final storeStatement = LedgerCalculatorService.computeStoreStatement(
        customers: [testCustomer, cust2],
        allTransactions: [txCust1, txCust2Prior, txCust2Period],
        settings: testSettings,
        period: period,
      );

      // Store opening: cust1 has 0, cust2 has 2000 => 2000
      expect(storeStatement.totalOpeningBalance, 2000.0);
      // Period baki: cust1 has 800 => 800
      expect(storeStatement.totalBaki, 800.0);
      // Period payment: cust2 has 500 => 500
      expect(storeStatement.totalPayment, 500.0);
      // Closing total: 2000 + 800 - 500 = 2300
      expect(storeStatement.totalClosingBalance, 2300.0);

      // Summaries should be sorted by closing balance descending:
      // cust2 has 1500, cust1 has 800
      expect(storeStatement.customerSummaries.length, 2);
      expect(storeStatement.customerSummaries[0].customer.id, 'cust_2');
      expect(storeStatement.customerSummaries[0].closingBalance, 1500.0);
      expect(storeStatement.customerSummaries[1].customer.id, 'cust_1');
      expect(storeStatement.customerSummaries[1].closingBalance, 800.0);
    });
  });

  group('HtmlStatementBuilder Unit Tests', () {
    test('builds complete HTML containing branding, customer info, and SVG seal', () {
      final testSettings = AppSettings(
        userId: 'user_1',
        shopName: 'M/S Bhai Bhai Enterprise',
        proprietorName: 'Al-Haj Abdul Karim',
        shopPhone: '01712345678',
        shopAddress: 'Sadar Road, Barishal',
        currencySymbol: '৳',
        updatedAt: DateTime.now(),
      );

      final testCustomer = Customer(
        id: 'c1',
        userId: 'user_1',
        name: 'Monirul Islam',
        phone: '01999887766',
        address: 'Chowk Bazaar',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      final statement = CustomerStatementData(
        customer: testCustomer,
        settings: testSettings,
        period: StatementPeriod.fromType(StatementPeriodType.last30Days),
        openingBalance: 1250.0,
        entries: [
          LedgerEntry(
            transaction: AppTransaction(
              id: 'tx_abc',
              userId: 'user_1',
              customerId: 'c1',
              type: TransactionType.baki,
              amount: 500.0,
              description: 'Groceries',
              date: DateTime(2026, 9, 20),
              createdAt: DateTime(2026, 9, 20),
              updatedAt: DateTime(2026, 9, 20),
            ),
            voucherNumber: '#BK-ABC123',
            items: [],
            notes: 'Groceries',
            debit: 500.0,
            credit: 0.0,
            runningBalance: 1750.0,
          ),
        ],
        totalBaki: 500.0,
        totalPayment: 0.0,
        closingBalance: 1750.0,
        generatedAt: DateTime(2026, 10, 1),
      );

      final html = HtmlStatementBuilder.buildCustomerStatementHtml(
        statement,
        isBengali: true,
      );

      expect(html, contains('M/S Bhai Bhai Enterprise'));
      expect(html, contains('স্বত্বাধিকারী: Al-Haj Abdul Karim'));
      expect(html, contains('Monirul Islam'));
      expect(html, contains('01999887766'));
      expect(html, contains('প্রারম্ভিক জের'));
      expect(html, contains('অনুমোদিত হিসাব')); // Seal verification
      expect(html, contains('গ্রাহকের স্বাক্ষর')); // Signature
      expect(html, contains('স্বত্বাধিকারীর স্বাক্ষর ও সিল')); // Proprietor Signature
    });
  });

  group('PdfDocumentBuilder & PdfStatementService Pure PDF Tests', () {
    final testSettings = AppSettings(
      userId: 'user_1',
      shopName: 'Bismillah General Store',
      proprietorName: 'Md. Rafiqul Islam',
      shopPhone: '01812345678',
      shopAddress: 'Mirpur 10, Dhaka',
      currencySymbol: '৳',
      updatedAt: DateTime.now(),
    );

    final testCustomer = Customer(
      id: 'c1',
      userId: 'user_1',
      name: 'Monirul Islam',
      phone: '01999887766',
      address: 'Chowk Bazaar',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    test('generates valid customer statement PDF bytes using pure PDF engine', () async {
      final statement = CustomerStatementData(
        customer: testCustomer,
        settings: testSettings,
        period: StatementPeriod.fromType(StatementPeriodType.last30Days),
        openingBalance: 1250.0,
        entries: [
          LedgerEntry(
            transaction: AppTransaction(
              id: 'tx_abc',
              userId: 'user_1',
              customerId: 'c1',
              type: TransactionType.baki,
              amount: 500.0,
              description: 'Groceries',
              date: DateTime(2026, 9, 20),
              createdAt: DateTime(2026, 9, 20),
              updatedAt: DateTime(2026, 9, 20),
            ),
            voucherNumber: '#BK-ABC123',
            items: [],
            notes: 'Groceries',
            debit: 500.0,
            credit: 0.0,
            runningBalance: 1750.0,
          ),
        ],
        totalBaki: 500.0,
        totalPayment: 0.0,
        closingBalance: 1750.0,
        generatedAt: DateTime(2026, 10, 1),
      );

      final pdfBytes = await PdfStatementService.generateCustomerStatementPdf(
        statement,
        isBengali: true,
      );

      expect(pdfBytes, isNotNull);
      expect(pdfBytes.isNotEmpty, isTrue);
      expect(pdfBytes.length, greaterThan(1000));
    });

    test('generates valid store master ledger PDF bytes using pure PDF engine', () async {
      final storeData = StoreStatementData(
        settings: testSettings,
        period: StatementPeriod.fromType(StatementPeriodType.last30Days),
        customerSummaries: [
          StoreCustomerSummary(
            customer: testCustomer,
            openingBalance: 500.0,
            periodBaki: 1000.0,
            periodPayment: 200.0,
            closingBalance: 1300.0,
          ),
        ],
        totalOpeningBalance: 500.0,
        totalBaki: 1000.0,
        totalPayment: 200.0,
        totalClosingBalance: 1300.0,
        generatedAt: DateTime(2026, 10, 1),
      );

      final pdfBytes = await PdfStatementService.generateStoreStatementPdf(
        storeData,
        isBengali: true,
      );

      expect(pdfBytes, isNotNull);
      expect(pdfBytes.isNotEmpty, isTrue);
      expect(pdfBytes.length, greaterThan(1000));
    });
  });
}
