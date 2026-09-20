import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:baki_khata/data/local/local_database.dart';
import 'package:baki_khata/data/sync/sync_service.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  final localDb = LocalDatabase.instance;

  setUp(() async {
    await localDb.initDatabase(path: inMemoryDatabasePath);
    final db = await localDb.database;
    if (db != null) {
      await db.delete('customers');
      await db.delete('transactions');
      await db.delete('settings');
      await db.delete('pending_ops');
      await db.delete('sync_meta');
    }
  });

  tearDown(() async {
    await localDb.close();
  });

  group('SyncService Resilience & Error Handling', () {
    test('lastSyncErrorProvider is initially null', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(lastSyncErrorProvider), isNull);
    });

    test('pushNow sets SyncStatus.guest if unauthenticated', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final syncService = container.read(syncServiceProvider);

      syncService.pushNow();
      expect(container.read(syncStatusProvider), equals(SyncStatus.guest));
    });

    test('isPermanentError detects postgres constraints and RLS violations', () {
      final syncService = SyncService(
        localDb: localDb,
        enablePeriodicSync: false,
      );

      // PostgrestException check
      expect(
        syncService.isPermanentErrorForTesting(
          'PostgrestException: new row violates row-level security policy for table "transactions"',
        ),
        isTrue,
      );

      expect(
        syncService.isPermanentErrorForTesting(
          'PostgrestException: insert or update on table "transactions" violates foreign key constraint "transactions_customer_id_fkey"',
        ),
        isTrue,
      );

      expect(
        syncService.isPermanentErrorForTesting(
          'SocketException: Failed host lookup',
        ),
        isFalse,
      );
    });

    test('realtime handlers update local store and call refresh callbacks', () async {
      final syncService = SyncService(
        localDb: localDb,
        enablePeriodicSync: false,
      );

      bool callbackFired = false;
      syncService.registerRefreshCallback(() async {
        callbackFired = true;
      });

      // Insert customer via realtime handler
      await syncService.handleRealtimeCustomerForTesting(
        eventType: 'INSERT',
        newRecord: {
          'id': 'rt-c1',
          'user_id': 'user-123',
          'name': 'Realtime Customer',
          'phone': '01999999999',
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
      );

      final customer = await localDb.getCustomerById('rt-c1');
      expect(customer, isNotNull);
      expect(customer!['name'], equals('Realtime Customer'));
      expect(callbackFired, isTrue);

      // Insert transaction via realtime handler
      await syncService.handleRealtimeTransactionForTesting(
        eventType: 'INSERT',
        newRecord: {
          'id': 'rt-t1',
          'user_id': 'user-123',
          'customer_id': 'rt-c1',
          'type': 'baki',
          'amount': 350.0,
          'date': DateTime.now().toUtc().toIso8601String(),
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
      );

      final tx = await localDb.getTransactionById('rt-t1');
      expect(tx, isNotNull);
      expect(tx!['amount'], equals(350.0));

      // Delete customer via realtime handler
      await syncService.handleRealtimeCustomerForTesting(
        eventType: 'DELETE',
        oldRecord: {'id': 'rt-c1'},
      );

      expect(await localDb.getCustomerById('rt-c1'), isNull);
    });
  });
}
