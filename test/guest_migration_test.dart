import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:baki_khata/core/current_user_service.dart';
import 'package:baki_khata/data/local/local_database.dart';
import 'package:baki_khata/data/models/app_settings.dart';
import 'package:baki_khata/data/models/customer.dart';
import 'package:baki_khata/data/models/transaction.dart';
import 'package:baki_khata/data/repositories/settings_repository.dart';
import 'package:baki_khata/data/sync/sync_service.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    // Reset database state before each test
    final db = await LocalDatabase.instance.database;
    if (db != null) {
      await db.delete('customers');
      await db.delete('transactions');
      await db.delete('settings');
      await db.delete('pending_ops');
      await db.delete('sync_meta');
    }
  });

  group('LocalDatabase Guest Operations', () {
    test('hasAnySettings returns false when empty and true when row exists', () async {
      expect(await LocalDatabase.instance.hasAnySettings(), isFalse);

      final settings = AppSettings(
        userId: CurrentUserService.guestSentinel,
        shopName: 'Test Shop',
        currencySymbol: '৳',
        updatedAt: DateTime.now().toUtc(),
      );
      await LocalDatabase.instance.upsertSettings(settings.toMap());

      expect(await LocalDatabase.instance.hasAnySettings(), isTrue);
    });

    test('reassignCustomerUserId updates user_id from guestSentinel to newUserId', () async {
      final now = DateTime.now().toUtc();
      final customer = Customer(
        id: 'cust-1',
        userId: CurrentUserService.guestSentinel,
        name: 'Guest Customer',
        phone: '01700000000',
        address: 'Dhaka',
        createdAt: now,
        updatedAt: now,
      );

      await LocalDatabase.instance.upsertCustomer(customer.toMap());
      var rows = await LocalDatabase.instance.getCustomers(CurrentUserService.guestSentinel);
      expect(rows.first['user_id'], equals(CurrentUserService.guestSentinel));

      await LocalDatabase.instance.reassignCustomerUserId(
        CurrentUserService.guestSentinel,
        'user-real-123',
      );

      rows = await LocalDatabase.instance.getCustomers('user-real-123');
      expect(rows.first['user_id'], equals('user-real-123'));
    });

    test('reassignTransactionUserId updates user_id from guestSentinel to newUserId', () async {
      final now = DateTime.now().toUtc();
      final tx = AppTransaction(
        id: 'tx-1',
        userId: CurrentUserService.guestSentinel,
        customerId: 'cust-1',
        type: TransactionType.baki,
        amount: 500.0,
        date: now,
        createdAt: now,
        updatedAt: now,
      );

      await LocalDatabase.instance.upsertTransaction(tx.toMap());
      var rows = await LocalDatabase.instance.getTransactions(CurrentUserService.guestSentinel);
      expect(rows.first['user_id'], equals(CurrentUserService.guestSentinel));

      await LocalDatabase.instance.reassignTransactionUserId(
        CurrentUserService.guestSentinel,
        'user-real-123',
      );

      rows = await LocalDatabase.instance.getTransactions('user-real-123');
      expect(rows.first['user_id'], equals('user-real-123'));
    });

    test('clearGuestPendingOps removes only ops with local_guest in payload', () async {
      await LocalDatabase.instance.insertPendingOp(
        tableName: 'customers',
        recordId: 'cust-1',
        opType: 'insert',
        payload: jsonEncode({'id': 'cust-1', 'user_id': 'local_guest', 'name': 'A'}),
      );

      await LocalDatabase.instance.insertPendingOp(
        tableName: 'customers',
        recordId: 'cust-2',
        opType: 'insert',
        payload: jsonEncode({'id': 'cust-2', 'user_id': 'real_user', 'name': 'B'}),
      );

      var ops = await LocalDatabase.instance.getPendingOps();
      expect(ops.length, equals(2));

      await LocalDatabase.instance.clearGuestPendingOps();

      ops = await LocalDatabase.instance.getPendingOps();
      expect(ops.length, equals(1));
      expect(ops.first['record_id'], equals('cust-2'));
    });

    test('deleteSettings removes settings for specific userId', () async {
      final guestSettings = AppSettings(
        userId: CurrentUserService.guestSentinel,
        shopName: 'Guest Shop',
        currencySymbol: '৳',
        updatedAt: DateTime.now().toUtc(),
      );
      await LocalDatabase.instance.upsertSettings(guestSettings.toMap());
      expect(await LocalDatabase.instance.getSettings(CurrentUserService.guestSentinel), isNotNull);

      await LocalDatabase.instance.deleteSettings(CurrentUserService.guestSentinel);
      expect(await LocalDatabase.instance.getSettings(CurrentUserService.guestSentinel), isNull);
    });

    test('clearGuestSettingsPendingOps removes only settings ops with local_guest', () async {
      await LocalDatabase.instance.insertPendingOp(
        tableName: 'customers',
        recordId: 'cust-1',
        opType: 'insert',
        payload: jsonEncode({'id': 'cust-1', 'user_id': 'local_guest'}),
      );

      await LocalDatabase.instance.insertPendingOp(
        tableName: 'settings',
        recordId: 'local_guest',
        opType: 'update',
        payload: jsonEncode({'user_id': 'local_guest', 'shop_name': 'Guest Shop'}),
      );

      await LocalDatabase.instance.insertPendingOp(
        tableName: 'settings',
        recordId: 'real_user',
        opType: 'update',
        payload: jsonEncode({'user_id': 'real_user', 'shop_name': 'Real Shop'}),
      );

      var ops = await LocalDatabase.instance.getPendingOps();
      expect(ops.length, equals(3));

      await LocalDatabase.instance.clearGuestSettingsPendingOps();

      ops = await LocalDatabase.instance.getPendingOps();
      expect(ops.length, equals(2));
      expect(ops.any((op) => op['table_name'] == 'settings' && op['record_id'] == 'local_guest'), isFalse);
      expect(ops.any((op) => op['table_name'] == 'customers' && op['record_id'] == 'cust-1'), isTrue);
      expect(ops.any((op) => op['table_name'] == 'settings' && op['record_id'] == 'real_user'), isTrue);
    });
  });

  group('SyncService Guest Migration Logic', () {
    test('migrateGuestData is a clean no-op if no guest data exists', () async {
      final syncService = SyncService();
      // Should not throw or fail when DB is empty
      await syncService.migrateGuestData('new-user-123');

      final customers = await LocalDatabase.instance.getCustomers('new-user-123');
      expect(customers, isEmpty);
      final ops = await LocalDatabase.instance.getPendingOps();
      expect(ops, isEmpty);
    });

    test('migrateGuestData reassigns records and generates pending ops for new user', () async {
      final now = DateTime.now().toUtc();
      // Setup guest customer, transaction, and guest settings
      await LocalDatabase.instance.upsertCustomer(Customer(
        id: 'cust-g1',
        userId: CurrentUserService.guestSentinel,
        name: 'Guest Customer 1',
        createdAt: now,
        updatedAt: now,
      ).toMap());

      await LocalDatabase.instance.upsertTransaction(AppTransaction(
        id: 'tx-g1',
        userId: CurrentUserService.guestSentinel,
        customerId: 'cust-g1',
        type: TransactionType.baki,
        amount: 250.0,
        date: now,
        createdAt: now,
        updatedAt: now,
      ).toMap());

      await LocalDatabase.instance.upsertSettings(AppSettings(
        userId: CurrentUserService.guestSentinel,
        shopName: 'My Guest Shop',
        currencySymbol: '৳',
        updatedAt: now,
      ).toMap());

      // Add a stale guest pending op to verify it gets cleared
      await LocalDatabase.instance.insertPendingOp(
        tableName: 'customers',
        recordId: 'cust-g1',
        opType: 'insert',
        payload: jsonEncode({'id': 'cust-g1', 'user_id': 'local_guest'}),
      );

      final syncService = SyncService();
      await syncService.migrateGuestData('user-migrated-999');

      // 1. Verify customer and transaction re-assigned
      final customers = await LocalDatabase.instance.getCustomers('user-migrated-999');
      expect(customers.length, equals(1));
      expect(customers.first['user_id'], equals('user-migrated-999'));

      final txs = await LocalDatabase.instance.getTransactions('user-migrated-999');
      expect(txs.length, equals(1));
      expect(txs.first['user_id'], equals('user-migrated-999'));

      // 2. Verify pending ops: clean insert operations enqueued for migrated user
      final ops = await LocalDatabase.instance.getPendingOps();
      expect(ops.any((op) => op['table_name'] == 'customers' && op['record_id'] == 'cust-g1'), isTrue);
      expect(ops.any((op) => op['table_name'] == 'transactions' && op['record_id'] == 'tx-g1'), isTrue);
      expect(ops.any((op) => op['table_name'] == 'settings' && op['record_id'] == 'user-migrated-999'), isTrue);

      // Verify no pending ops contain local_guest
      for (final op in ops) {
        expect(op['payload'].toString().contains('local_guest'), isFalse);
      }
    });

    test('hasLocalGuestData detects settings while hasLocalGuestCustomerData only checks customers/transactions', () async {
      final syncService = SyncService();
      expect(await syncService.hasLocalGuestData(), isFalse);
      expect(await syncService.hasLocalGuestCustomerData(), isFalse);
      expect(await syncService.hasLocalGuestSettings(), isFalse);

      // Add only guest settings
      await LocalDatabase.instance.upsertSettings(AppSettings(
        userId: CurrentUserService.guestSentinel,
        shopName: 'Incognito Shop',
        currencySymbol: '৳',
        updatedAt: DateTime.now().toUtc(),
      ).toMap());

      expect(await syncService.hasLocalGuestData(), isTrue);
      expect(await syncService.hasLocalGuestSettings(), isTrue);
      expect(await syncService.hasLocalGuestCustomerData(), isFalse);

      // Add a guest customer
      await LocalDatabase.instance.upsertCustomer(Customer(
        id: 'cust-1',
        userId: CurrentUserService.guestSentinel,
        name: 'Guest Customer',
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      ).toMap());

      expect(await syncService.hasLocalGuestCustomerData(), isTrue);
    });

    test('resolveSettingsOnSignIn preserves remote settings and discards local guest settings', () async {
      final now = DateTime.now().toUtc();
      // Setup local guest settings and a guest pending op
      await LocalDatabase.instance.upsertSettings(AppSettings(
        userId: CurrentUserService.guestSentinel,
        shopName: 'Incognito Temporary Shop',
        currencySymbol: '৳',
        updatedAt: now,
      ).toMap());

      await LocalDatabase.instance.insertPendingOp(
        tableName: 'settings',
        recordId: 'local_guest',
        opType: 'update',
        payload: jsonEncode({'user_id': 'local_guest', 'shop_name': 'Incognito Temporary Shop'}),
      );

      final syncService = TestSyncServiceWithRemoteSettings(
        remoteSettingsMap: {
          'user-existing-1': {
            'user_id': 'user-existing-1',
            'shop_name': 'Original Cloud Shop',
            'currency_symbol': '৳',
            'updated_at': now.toIso8601String(),
          },
        },
      );

      await syncService.resolveSettingsOnSignIn('user-existing-1');

      // 1. Guest settings must be deleted
      expect(await LocalDatabase.instance.getSettings(CurrentUserService.guestSentinel), isNull);

      // 2. Guest settings pending op must be removed
      final ops = await LocalDatabase.instance.getPendingOps();
      expect(ops.any((op) => op['table_name'] == 'settings' && op['record_id'] == 'local_guest'), isFalse);

      // 3. Remote settings must be loaded for the user
      final userSettings = await LocalDatabase.instance.getSettings('user-existing-1');
      expect(userSettings, isNotNull);
      expect(userSettings!['shop_name'], equals('Original Cloud Shop'));
    });

    test('resolveSettingsOnSignIn migrates guest settings when user has no remote settings', () async {
      final now = DateTime.now().toUtc();
      // Setup local guest settings
      await LocalDatabase.instance.upsertSettings(AppSettings(
        userId: CurrentUserService.guestSentinel,
        shopName: 'Brand New Shop',
        currencySymbol: '৳',
        updatedAt: now,
      ).toMap());

      final syncService = TestSyncServiceWithRemoteSettings(
        remoteSettingsMap: {}, // No remote settings
      );

      await syncService.resolveSettingsOnSignIn('user-fresh-2');

      // 1. Guest settings must be deleted
      expect(await LocalDatabase.instance.getSettings(CurrentUserService.guestSentinel), isNull);

      // 2. Settings must be assigned to new user
      final userSettings = await LocalDatabase.instance.getSettings('user-fresh-2');
      expect(userSettings, isNotNull);
      expect(userSettings!['shop_name'], equals('Brand New Shop'));
    });
  });

  group('SettingsRepository Guest Settings Isolation', () {
    test('updateSettings for guest saves locally only and does NOT enqueue pending_ops', () async {
      final mockUserService = MockCurrentUserService(CurrentUserService.guestSentinel);
      final syncService = SyncService();
      final repo = SettingsRepository(
        localDb: LocalDatabase.instance,
        syncService: syncService,
        currentUserService: mockUserService,
      );

      await repo.updateSettings(
        shopName: 'Guest Shop Name',
        currencySymbol: '৳',
      );

      // Local DB has the settings
      final settings = await LocalDatabase.instance.getSettings(CurrentUserService.guestSentinel);
      expect(settings, isNotNull);
      expect(settings!['shop_name'], equals('Guest Shop Name'));

      // Pending ops must be EMPTY
      final ops = await LocalDatabase.instance.getPendingOps();
      expect(ops, isEmpty);
    });

    test('updateSettings for authenticated user enqueues pending_ops', () async {
      final mockUserService = MockCurrentUserService('auth-user-123');
      final syncService = SyncService();
      final repo = SettingsRepository(
        localDb: LocalDatabase.instance,
        syncService: syncService,
        currentUserService: mockUserService,
      );

      await repo.updateSettings(
        shopName: 'Real Shop Name',
        currencySymbol: '৳',
      );

      // Local DB has the settings
      final settings = await LocalDatabase.instance.getSettings('auth-user-123');
      expect(settings, isNotNull);
      expect(settings!['shop_name'], equals('Real Shop Name'));

      // Pending ops must have the update
      final ops = await LocalDatabase.instance.getPendingOps();
      expect(ops.length, equals(1));
      expect(ops.first['table_name'], equals('settings'));
      expect(ops.first['record_id'], equals('auth-user-123'));
    });
  });
}

class MockCurrentUserService extends CurrentUserService {
  final String _userId;
  MockCurrentUserService(this._userId);

  @override
  String get effectiveUserId => _userId;
}

class TestSyncServiceWithRemoteSettings extends SyncService {
  final Map<String, Map<String, dynamic>> remoteSettingsMap;

  TestSyncServiceWithRemoteSettings({
    required this.remoteSettingsMap,
    super.localDb,
  });

  @override
  Future<Map<String, dynamic>?> getRemoteSettings(String userId) async {
    return remoteSettingsMap[userId];
  }
}
