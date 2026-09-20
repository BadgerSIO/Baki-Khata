import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

class LocalDatabase {
  static final LocalDatabase instance = LocalDatabase._init();
  static Database? _database;

  static const String _webStorageKey = 'baki_khata_web_store_v1';

  // In-memory fallback and cache for web support without sqflite ffi
  static int _webPendingOpAutoInc = 1;
  static final Map<String, List<Map<String, dynamic>>> _webStore = {
    'customers': [],
    'transactions': [],
    'settings': [],
    'pending_ops': [],
    'sync_meta': [],
  };

  LocalDatabase._init();

  static void setDatabase(Database? db) {
    _database = db;
  }

  static Future<void> _loadWebStore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_webStorageKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          for (final key in _webStore.keys) {
            if (decoded.containsKey(key) && decoded[key] is List) {
              _webStore[key] = (decoded[key] as List)
                  .map((e) => Map<String, dynamic>.from(e as Map))
                  .toList();
            }
          }
          if (decoded.containsKey('_webPendingOpAutoInc')) {
            _webPendingOpAutoInc = (decoded['_webPendingOpAutoInc'] as num).toInt();
          }
        }
      }
    } catch (e) {
      debugPrint('[LocalDatabase] Error loading web store from SharedPreferences: $e');
    }
  }

  static Future<void> _saveWebStore() async {
    if (!kIsWeb) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = <String, dynamic>{
        for (final entry in _webStore.entries) entry.key: entry.value,
        '_webPendingOpAutoInc': _webPendingOpAutoInc,
      };
      await prefs.setString(_webStorageKey, jsonEncode(payload));
    } catch (e) {
      debugPrint('[LocalDatabase] Error saving web store to SharedPreferences: $e');
    }
  }

  Future<Database?> get database async {
    if (kIsWeb) return null;
    if (_database != null) return _database!;
    _database = await _initDB('baki_khata.db');
    return _database!;
  }

  Future<void> initialize() async {
    if (kIsWeb) {
      await _loadWebStore();
      debugPrint('Running on Web: Initialized persistent store for local operations.');
      return;
    }
    await database;
  }

  Future<Database> initDatabase({String? path}) async {
    if (path != null) {
      _database = await openDatabase(
        path,
        version: 2,
        onCreate: _createDB,
        onUpgrade: _onUpgrade,
      );
      return _database!;
    }
    final dbPath = await getDatabasesPath();
    final fullPath = p.join(dbPath, 'baki_khata.db');
    _database = await openDatabase(
      fullPath,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE customers (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        name TEXT,
        phone TEXT,
        address TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        customer_id TEXT,
        type TEXT,
        amount REAL,
        description TEXT,
        date TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE settings (
        user_id TEXT PRIMARY KEY,
        shop_name TEXT,
        currency_symbol TEXT,
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE pending_ops (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        table_name TEXT,
        record_id TEXT,
        op_type TEXT,
        payload TEXT,
        created_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE sync_meta (
        table_name TEXT PRIMARY KEY,
        last_synced_at TEXT
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Drop and recreate if needed for schema migration during development
    if (oldVersion < 2) {
      await db.execute('DROP TABLE IF EXISTS sync_meta');
      await db.execute('DROP TABLE IF EXISTS pending_ops');
      await db.execute('''
        CREATE TABLE pending_ops (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          table_name TEXT,
          record_id TEXT,
          op_type TEXT,
          payload TEXT,
          created_at TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE sync_meta (
          table_name TEXT PRIMARY KEY,
          last_synced_at TEXT
        )
      ''');
    }
  }

  // --- Customers Local Operations ---

  Future<void> upsertCustomer(Map<String, dynamic> data) async {
    if (kIsWeb) {
      _webStore['customers']!.removeWhere((item) => item['id'] == data['id']);
      _webStore['customers']!.add(Map<String, dynamic>.from(data));
      await _saveWebStore();
      return;
    }
    final db = await database;
    await db!.insert('customers', data, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getCustomers(String userId) async {
    if (kIsWeb) {
      final list = _webStore['customers']!.where((item) => item['user_id'] == userId).toList();
      list.sort((a, b) => (b['created_at'] as String? ?? '').compareTo(a['created_at'] as String? ?? ''));
      return list;
    }
    final db = await database;
    return await db!.query(
      'customers',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );
  }

  Future<Map<String, dynamic>?> getCustomerById(String id) async {
    if (kIsWeb) {
      final items = _webStore['customers']!.where((item) => item['id'] == id).toList();
      return items.isNotEmpty ? items.first : null;
    }
    final db = await database;
    final res = await db!.query('customers', where: 'id = ?', whereArgs: [id], limit: 1);
    return res.isNotEmpty ? res.first : null;
  }

  Future<void> deleteCustomer(String id) async {
    if (kIsWeb) {
      _webStore['customers']!.removeWhere((item) => item['id'] == id);
      _webStore['transactions']!.removeWhere((item) => item['customer_id'] == id);
      await _saveWebStore();
      return;
    }
    final db = await database;
    await db!.delete('customers', where: 'id = ?', whereArgs: [id]);
    await db.delete('transactions', where: 'customer_id = ?', whereArgs: [id]);
  }

  // --- Transactions Local Operations ---

  Future<void> upsertTransaction(Map<String, dynamic> data) async {
    if (kIsWeb) {
      _webStore['transactions']!.removeWhere((item) => item['id'] == data['id']);
      _webStore['transactions']!.add(Map<String, dynamic>.from(data));
      await _saveWebStore();
      return;
    }
    final db = await database;
    await db!.insert('transactions', data, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getTransactions(String userId, {String? customerId}) async {
    if (kIsWeb) {
      final list = _webStore['transactions']!.where((item) {
        if (item['user_id'] != userId) return false;
        if (customerId != null && item['customer_id'] != customerId) return false;
        return true;
      }).toList();
      list.sort((a, b) => (b['date'] as String? ?? '').compareTo(a['date'] as String? ?? ''));
      return list;
    }
    final db = await database;
    if (customerId != null) {
      return await db!.query(
        'transactions',
        where: 'user_id = ? AND customer_id = ?',
        whereArgs: [userId, customerId],
        orderBy: 'date DESC',
      );
    }
    return await db!.query('transactions', where: 'user_id = ?', whereArgs: [userId], orderBy: 'date DESC');
  }

  Future<Map<String, dynamic>?> getTransactionById(String id) async {
    if (kIsWeb) {
      final items = _webStore['transactions']!.where((item) => item['id'] == id).toList();
      return items.isNotEmpty ? items.first : null;
    }
    final db = await database;
    final res = await db!.query('transactions', where: 'id = ?', whereArgs: [id], limit: 1);
    return res.isNotEmpty ? res.first : null;
  }

  Future<void> deleteTransaction(String id) async {
    if (kIsWeb) {
      _webStore['transactions']!.removeWhere((item) => item['id'] == id);
      await _saveWebStore();
      return;
    }
    final db = await database;
    await db!.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  // --- Settings Local Operations ---

  Future<void> upsertSettings(Map<String, dynamic> data) async {
    if (kIsWeb) {
      _webStore['settings']!.removeWhere((item) => item['user_id'] == data['user_id']);
      _webStore['settings']!.add(Map<String, dynamic>.from(data));
      await _saveWebStore();
      return;
    }
    final db = await database;
    await db!.insert('settings', data, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, dynamic>?> getSettings(String userId) async {
    if (kIsWeb) {
      final list = _webStore['settings']!.where((item) => item['user_id'] == userId).toList();
      return list.isNotEmpty ? list.first : null;
    }
    final db = await database;
    final res = await db!.query('settings', where: 'user_id = ?', whereArgs: [userId], limit: 1);
    return res.isNotEmpty ? res.first : null;
  }

  Future<bool> hasAnySettings() async {
    if (kIsWeb) {
      return _webStore['settings']!.isNotEmpty;
    }
    final db = await database;
    if (db == null) return false;
    final res = await db.rawQuery('SELECT COUNT(*) as count FROM settings');
    if (res.isEmpty) return false;
    final count = Sqflite.firstIntValue(res) ?? 0;
    return count > 0;
  }

  Future<void> deleteSettings(String userId) async {
    if (kIsWeb) {
      _webStore['settings']!.removeWhere((item) => item['user_id'] == userId);
      await _saveWebStore();
      return;
    }
    final db = await database;
    await db!.delete('settings', where: 'user_id = ?', whereArgs: [userId]);
  }

  Future<void> reassignCustomerUserId(String oldUserId, String newUserId) async {
    if (kIsWeb) {
      for (final item in _webStore['customers']!) {
        if (item['user_id'] == oldUserId) {
          item['user_id'] = newUserId;
        }
      }
      await _saveWebStore();
      return;
    }
    final db = await database;
    await db!.update('customers', {'user_id': newUserId}, where: 'user_id = ?', whereArgs: [oldUserId]);
  }

  Future<void> reassignTransactionUserId(String oldUserId, String newUserId) async {
    if (kIsWeb) {
      for (final item in _webStore['transactions']!) {
        if (item['user_id'] == oldUserId) {
          item['user_id'] = newUserId;
        }
      }
      await _saveWebStore();
      return;
    }
    final db = await database;
    await db!.update('transactions', {'user_id': newUserId}, where: 'user_id = ?', whereArgs: [oldUserId]);
  }

  Future<void> reassignTransactionCustomerId(String oldCustomerId, String newCustomerId) async {
    if (kIsWeb) {
      for (final item in _webStore['transactions']!) {
        if (item['customer_id'] == oldCustomerId) {
          item['customer_id'] = newCustomerId;
        }
      }
      await _saveWebStore();
      return;
    }
    final db = await database;
    await db!.update(
      'transactions',
      {'customer_id': newCustomerId},
      where: 'customer_id = ?',
      whereArgs: [oldCustomerId],
    );
  }

  Future<void> clearGuestData() async {
    if (kIsWeb) {
      _webStore['customers']!.removeWhere((item) => item['user_id'] == 'local_guest');
      _webStore['transactions']!.removeWhere((item) => item['user_id'] == 'local_guest');
      _webStore['settings']!.removeWhere((item) => item['user_id'] == 'local_guest');
      await clearGuestPendingOps();
      await _saveWebStore();
      return;
    }
    final db = await database;
    await db!.delete('customers', where: 'user_id = ?', whereArgs: ['local_guest']);
    await db.delete('transactions', where: 'user_id = ?', whereArgs: ['local_guest']);
    await db.delete('settings', where: 'user_id = ?', whereArgs: ['local_guest']);
    await clearGuestPendingOps();
  }

  // --- Pending Operations Local Operations ---

  Future<int> insertPendingOp({
    required String tableName,
    required String recordId,
    required String opType,
    String? payload,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    if (kIsWeb) {
      final id = _webPendingOpAutoInc++;
      final op = {
        'id': id,
        'table_name': tableName,
        'record_id': recordId,
        'op_type': opType,
        'payload': payload,
        'created_at': now,
      };
      _webStore['pending_ops']!.add(op);
      await _saveWebStore();
      return id;
    }
    final db = await database;
    return await db!.insert('pending_ops', {
      'table_name': tableName,
      'record_id': recordId,
      'op_type': opType,
      'payload': payload,
      'created_at': now,
    });
  }

  Future<List<Map<String, dynamic>>> getPendingOps() async {
    if (kIsWeb) {
      final list = List<Map<String, dynamic>>.from(_webStore['pending_ops']!);
      list.sort((a, b) => (a['id'] as int).compareTo(b['id'] as int));
      return list;
    }
    final db = await database;
    return await db!.query('pending_ops', orderBy: 'id ASC');
  }

  Future<void> deletePendingOp(int id) async {
    if (kIsWeb) {
      _webStore['pending_ops']!.removeWhere((item) => item['id'] == id);
      await _saveWebStore();
      return;
    }
    final db = await database;
    await db!.delete('pending_ops', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearGuestPendingOps() async {
    if (kIsWeb) {
      _webStore['pending_ops']!.removeWhere((item) =>
          (item['payload'] as String? ?? '').contains('local_guest'));
      await _saveWebStore();
      return;
    }
    final db = await database;
    await db!.delete('pending_ops', where: 'payload LIKE ?', whereArgs: ['%local_guest%']);
  }

  // --- Sync Meta Operations ---

  Future<String?> getLastSyncedAt(String tableName) async {
    if (kIsWeb) {
      final match = _webStore['sync_meta']!.where((item) => item['table_name'] == tableName).toList();
      return match.isNotEmpty ? match.first['last_synced_at'] as String? : null;
    }
    final db = await database;
    final res = await db!.query('sync_meta', where: 'table_name = ?', whereArgs: [tableName], limit: 1);
    return res.isNotEmpty ? res.first['last_synced_at'] as String? : null;
  }

  Future<void> setLastSyncedAt(String tableName, String lastSyncedAt) async {
    if (kIsWeb) {
      _webStore['sync_meta']!.removeWhere((item) => item['table_name'] == tableName);
      _webStore['sync_meta']!.add({
        'table_name': tableName,
        'last_synced_at': lastSyncedAt,
      });
      await _saveWebStore();
      return;
    }
    final db = await database;
    await db!.insert(
      'sync_meta',
      {
        'table_name': tableName,
        'last_synced_at': lastSyncedAt,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> close() async {
    if (kIsWeb) {
      for (final key in _webStore.keys) {
        _webStore[key]!.clear();
      }
      _webPendingOpAutoInc = 1;
      return;
    }
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
