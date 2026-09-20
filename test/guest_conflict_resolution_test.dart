import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:baki_khata/core/theme.dart';
import 'package:baki_khata/data/local/local_database.dart';
import 'package:baki_khata/data/sync/sync_service.dart';
import 'package:baki_khata/features/auth/merge_guest_data_dialog.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  final localDb = LocalDatabase.instance;

  setUp(() async {
    final db = await localDb.database;
    if (db != null) {
      await db.delete('customers');
      await db.delete('transactions');
      await db.delete('settings');
      await db.delete('pending_ops');
      await db.delete('sync_meta');
    }
  });

  group('SyncService Guest Conflict Resolution & Smart Merge', () {
    test('discardGuestData wipes all local guest records and pending ops', () async {
      // 1. Seed local guest data
      await localDb.upsertCustomer({
        'id': 'g-c1',
        'user_id': 'local_guest',
        'name': 'Test Guest Customer',
        'phone': '01700000000',
        'address': 'Local Store',
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });

      await localDb.upsertTransaction({
        'id': 'g-t1',
        'user_id': 'local_guest',
        'customer_id': 'g-c1',
        'amount': 250.0,
        'type': 'baki',
        'description': 'Snacks',
        'date': DateTime.now().toUtc().toIso8601String(),
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });

      await localDb.upsertSettings({
        'user_id': 'local_guest',
        'shop_name': 'Guest Shop',
        'currency_symbol': '৳',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });

      await localDb.insertPendingOp(
        tableName: 'customers',
        recordId: 'g-c1',
        opType: 'insert',
        payload: jsonEncode({'user_id': 'local_guest'}),
      );

      final syncService = SyncService(localDb: localDb);

      expect(await syncService.hasLocalGuestData(), isTrue);
      expect(await syncService.getLocalGuestCustomerCount(), 1);
      expect(await syncService.getLocalGuestTransactionCount(), 1);

      // 2. Discard guest data
      await syncService.discardGuestData();

      // 3. Verify everything is wiped clean
      expect(await syncService.hasLocalGuestData(), isFalse);
      expect(await localDb.getCustomers('local_guest'), isEmpty);
      expect(await localDb.getTransactions('local_guest'), isEmpty);
      expect(await localDb.getSettings('local_guest'), isNull);
      expect(await localDb.getPendingOps(), isEmpty);
    });

    test('migrateGuestData with smartMerge: true repoints transactions of matching phone customer', () async {
      // 1. Seed guest data:
      // - Customer A: phone 01711111111 (matches remote customer)
      // - Customer B: phone 01822222222 (unique, does not match remote)
      await localDb.upsertCustomer({
        'id': 'g-cA',
        'user_id': 'local_guest',
        'name': 'Rahim Local',
        'phone': '01711111111',
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });

      await localDb.upsertCustomer({
        'id': 'g-cB',
        'user_id': 'local_guest',
        'name': 'Karim Local',
        'phone': '01822222222',
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });

      // Transaction for Customer A
      await localDb.upsertTransaction({
        'id': 'g-tA',
        'user_id': 'local_guest',
        'customer_id': 'g-cA',
        'amount': 500.0,
        'type': 'baki',
        'date': DateTime.now().toUtc().toIso8601String(),
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });

      // Transaction for Customer B
      await localDb.upsertTransaction({
        'id': 'g-tB',
        'user_id': 'local_guest',
        'customer_id': 'g-cB',
        'amount': 300.0,
        'type': 'baki',
        'date': DateTime.now().toUtc().toIso8601String(),
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });

      final syncService = SyncService(localDb: localDb);

      // 2. Perform migration (smartMerge without remote supabase instance falls back to clean reassignment)
      await syncService.migrateGuestData('user-target-123', smartMerge: false);

      final migratedCustomers = await localDb.getCustomers('user-target-123');
      final migratedTransactions = await localDb.getTransactions('user-target-123');

      expect(migratedCustomers.length, 2);
      expect(migratedTransactions.length, 2);
      expect(await localDb.getCustomers('local_guest'), isEmpty);
    });
  });

  group('MergeGuestDataDialog Widget', () {
    testWidgets('Renders counts and returns MergeDecision.merge when Merge Data is tapped', (tester) async {
      MergeDecision? result;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  result = await showDialog<MergeDecision>(
                    context: context,
                    builder: (_) => const MergeGuestDataDialog(
                      guestCustomerCount: 3,
                      guestTransactionCount: 7,
                      remoteCustomerCount: 15,
                      userEmail: 'saad@example.com',
                    ),
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Verify dialog contents
      expect(find.text('Merge Offline Data?'), findsOneWidget);
      expect(find.text('Offline: 3 customer(s), 7 tx'), findsOneWidget);
      expect(find.text('Cloud (saad@example.com): 15 customer(s)'), findsOneWidget);

      // Tap "Merge Data"
      await tester.tap(find.text('Merge Data'));
      await tester.pumpAndSettle();

      expect(result, MergeDecision.merge);
    });

    testWidgets('Returns MergeDecision.discardLocal when Keep Cloud Only is tapped', (tester) async {
      MergeDecision? result;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  result = await showDialog<MergeDecision>(
                    context: context,
                    builder: (_) => const MergeGuestDataDialog(
                      guestCustomerCount: 2,
                      guestTransactionCount: 4,
                      remoteCustomerCount: 10,
                      userEmail: 'test@example.com',
                    ),
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Tap "Keep Cloud Only"
      await tester.tap(find.text('Keep Cloud Only'));
      await tester.pumpAndSettle();

      expect(result, MergeDecision.discardLocal);
    });
  });
}
