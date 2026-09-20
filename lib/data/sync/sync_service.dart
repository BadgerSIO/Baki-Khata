import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_client.dart';
import '../local/local_database.dart';

enum SyncStatus {
  guest,
  idle,
  syncing,
  offline,
  error,
}

final syncStatusProvider = StateProvider<SyncStatus>((ref) {
  return SyncStatus.guest;
});

final lastSyncedTimeProvider = StateProvider<DateTime?>((ref) => null);
final lastSyncErrorProvider = StateProvider<String?>((ref) => null);

class SyncService {
  final LocalDatabase _localDb;
  final SupabaseClient? _supabase;
  final Connectivity _connectivity;
  final Ref? ref;

  SyncStatus _status = SyncStatus.guest;
  bool _isSyncing = false;
  Future<bool>? _pushInFlight;
  bool _wasOnline = true;
  bool _isAppForeground = true;
  String? _lastError;
  final Map<int, int> _pendingOpFailures = {};

  RealtimeChannel? _realtimeChannel;
  StreamSubscription<AuthState>? _authSubscription;
  Timer? _periodicTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  AppLifecycleListener? _lifecycleListener;

  final List<Future<void> Function()> _refreshCallbacks = [];

  static SupabaseClient? _resolveSupabaseClient(SupabaseClient? client) {
    if (client != null) return client;
    try {
      return supabase;
    } catch (_) {
      return null;
    }
  }

  User? get _currentUser {
    try {
      return _supabase?.auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  final bool _enablePeriodicSync;

  SyncService({
    LocalDatabase? localDb,
    SupabaseClient? supabaseClient,
    Connectivity? connectivity,
    this.ref,
    this._enablePeriodicSync = true,
  })  : _localDb = localDb ?? LocalDatabase.instance,
        _supabase = _resolveSupabaseClient(supabaseClient),
        _connectivity = connectivity ?? Connectivity() {
    _init();
  }

  SyncStatus get status => _status;
  String? get lastError => _lastError;

  void registerRefreshCallback(Future<void> Function() callback) {
    _refreshCallbacks.add(callback);
  }

  void _updateStatus(SyncStatus newStatus) {
    _status = newStatus;
    final r = ref;
    if (r != null) {
      r.read(syncStatusProvider.notifier).state = newStatus;
    }
  }

  void _setError(String? error) {
    _lastError = error;
    final r = ref;
    if (r != null) {
      r.read(lastSyncErrorProvider.notifier).state = error;
    }
  }

  Future<bool> isOnline() async {
    try {
      final results = await _connectivity.checkConnectivity();
      return !results.contains(ConnectivityResult.none);
    } catch (_) {
      return true;
    }
  }

  Future<void> _init() async {
    final user = _currentUser;
    if (user == null) {
      _updateStatus(SyncStatus.guest);
    } else {
      final initialResults = await _connectivity.checkConnectivity();
      _wasOnline = !initialResults.contains(ConnectivityResult.none);
      if (!_wasOnline) {
        _updateStatus(SyncStatus.offline);
      } else {
        _updateStatus(SyncStatus.idle);
      }
      _setupRealtimeSubscription(user.id);
      _startPeriodicSync();
    }

    try {
      final lastSyncStr = await _localDb.getLastSyncedAt('settings') ??
          await _localDb.getLastSyncedAt('customers') ??
          await _localDb.getLastSyncedAt('transactions');
      if (lastSyncStr != null) {
        final parsed = DateTime.tryParse(lastSyncStr);
        final r = ref;
        if (parsed != null && r != null) {
          r.read(lastSyncedTimeProvider.notifier).state = parsed.toLocal();
        }
      }
    } catch (_) {}

    // 1. Listen for auth state changes
    try {
      _authSubscription = _supabase?.auth.onAuthStateChange.listen((data) {
        final sessionUser = data.session?.user;
        if (sessionUser != null && sessionUser.id.isNotEmpty) {
          _onUserSignedIn(sessionUser);
        } else if (data.event == AuthChangeEvent.signedOut) {
          _onUserSignedOut();
        }
      });
    } catch (_) {}

    // 2. Listen for connectivity transitions (offline -> online)
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((results) {
      final isNowOnline = !results.contains(ConnectivityResult.none);
      if (!_wasOnline && isNowOnline) {
        debugPrint('[SyncService] Device transitioned to online -> triggering fullSync()');
        fullSync();
      } else if (!isNowOnline) {
        if (!_isSyncing) {
          _updateStatus(SyncStatus.offline);
        }
      }
      _wasOnline = isNowOnline;
    });

    // 3. Track App Lifecycle (Foreground / Background)
    _lifecycleListener = AppLifecycleListener(
      onResume: () {
        _isAppForeground = true;
        if (_currentUser != null) {
          _setupRealtimeSubscription(_currentUser!.id);
          fullSync();
        }
      },
      onPause: () {
        _isAppForeground = false;
      },
      onDetach: () {
        _isAppForeground = false;
      },
    );
  }

  void _onUserSignedIn(User user) {
    _updateStatus(SyncStatus.idle);
    _setupRealtimeSubscription(user.id);
    _startPeriodicSync();
    fullSync();
  }

  void _onUserSignedOut() {
    _teardownRealtimeSubscription();
    _stopPeriodicSync();
    _setError(null);
    _updateStatus(SyncStatus.guest);
  }

  void _startPeriodicSync() {
    _periodicTimer?.cancel();
    if (!_enablePeriodicSync) return;
    _periodicTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_isAppForeground && _currentUser != null) {
        fullSync();
      }
    });
  }

  void _stopPeriodicSync() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }

  void _setupRealtimeSubscription(String userId) {
    final client = _supabase;
    if (client == null) return;

    _teardownRealtimeSubscription();

    try {
      final channel = client.channel('public:baki_khata_sync_$userId');
      channel
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'customers',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: (payload) => _handleRealtimeCustomer(payload),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'transactions',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: (payload) => _handleRealtimeTransaction(payload),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'settings',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: (payload) => _handleRealtimeSettings(payload),
          )
          .subscribe();

      _realtimeChannel = channel;
      debugPrint('[SyncService] Subscribed to Supabase Realtime for user $userId');
    } catch (e) {
      debugPrint('[SyncService] Failed to subscribe to Realtime: $e');
    }
  }

  void _teardownRealtimeSubscription() {
    if (_realtimeChannel != null) {
      try {
        _supabase?.removeChannel(_realtimeChannel!);
      } catch (_) {}
      _realtimeChannel = null;
    }
  }

  Future<void> _handleRealtimeCustomer(PostgresChangePayload payload) async {
    try {
      if (payload.eventType == PostgresChangeEvent.delete) {
        final id = payload.oldRecord['id'] as String?;
        if (id != null) {
          await _localDb.deleteCustomer(id);
        }
      } else {
        final record = payload.newRecord;
        if (record.isNotEmpty) {
          await _localDb.upsertCustomer(record);
        }
      }
      _notifyRefresh();
    } catch (e) {
      debugPrint('[SyncService] Error handling realtime customer: $e');
    }
  }

  Future<void> _handleRealtimeTransaction(PostgresChangePayload payload) async {
    try {
      if (payload.eventType == PostgresChangeEvent.delete) {
        final id = payload.oldRecord['id'] as String?;
        if (id != null) {
          await _localDb.deleteTransaction(id);
        }
      } else {
        final record = payload.newRecord;
        if (record.isNotEmpty) {
          await _localDb.upsertTransaction(record);
        }
      }
      _notifyRefresh();
    } catch (e) {
      debugPrint('[SyncService] Error handling realtime transaction: $e');
    }
  }

  Future<void> _handleRealtimeSettings(PostgresChangePayload payload) async {
    try {
      if (payload.eventType == PostgresChangeEvent.delete) {
        final userId = payload.oldRecord['user_id'] as String?;
        if (userId != null) {
          await _localDb.deleteSettings(userId);
        }
      } else {
        final record = payload.newRecord;
        if (record.isNotEmpty) {
          await _localDb.upsertSettings(record);
        }
      }
      _notifyRefresh();
    } catch (e) {
      debugPrint('[SyncService] Error handling realtime settings: $e');
    }
  }

  void _notifyRefresh() {
    for (final callback in _refreshCallbacks) {
      try {
        callback();
      } catch (e) {
        debugPrint('[SyncService] Refresh callback error: $e');
      }
    }
  }

  Future<bool> _ensureValidSession() async {
    final client = _supabase;
    if (client == null) return true;

    try {
      final session = client.auth.currentSession;
      if (session == null) return false;

      if (session.isExpired) {
        debugPrint('[SyncService] Session expired, refreshing token...');
        final res = await client.auth.refreshSession();
        if (res.session == null) {
          _setError('Session expired. Please sign in again.');
          return false;
        }
      }
      return true;
    } catch (e) {
      debugPrint('[SyncService] Session validation error: $e');
      _setError('Authentication error: ${e.toString()}');
      return false;
    }
  }

  bool _isPermanentError(dynamic error) {
    if (error is PostgrestException) {
      final code = error.code;
      if (code != null) {
        if (code.startsWith('23') ||
            code.startsWith('22') ||
            code == '42501' ||
            code.startsWith('42')) {
          return true;
        }
      }
      final msg = error.message.toLowerCase();
      if (msg.contains('violates foreign key') ||
          msg.contains('row-level security') ||
          msg.contains('invalid input syntax') ||
          msg.contains('violates check constraint')) {
        return true;
      }
    }
    final str = error.toString().toLowerCase();
    if (str.contains('violates foreign key') ||
        str.contains('row-level security') ||
        str.contains('invalid input syntax') ||
        str.contains('violates check constraint')) {
      return true;
    }
    return false;
  }

  @visibleForTesting
  bool isPermanentErrorForTesting(dynamic error) => _isPermanentError(error);

  @visibleForTesting
  Future<void> handleRealtimeCustomerForTesting({
    required String eventType,
    Map<String, dynamic>? newRecord,
    Map<String, dynamic>? oldRecord,
  }) async {
    if (eventType == 'DELETE') {
      final id = oldRecord?['id'] as String?;
      if (id != null) await _localDb.deleteCustomer(id);
    } else if (newRecord != null && newRecord.isNotEmpty) {
      await _localDb.upsertCustomer(newRecord);
    }
    _notifyRefresh();
  }

  @visibleForTesting
  Future<void> handleRealtimeTransactionForTesting({
    required String eventType,
    Map<String, dynamic>? newRecord,
    Map<String, dynamic>? oldRecord,
  }) async {
    if (eventType == 'DELETE') {
      final id = oldRecord?['id'] as String?;
      if (id != null) await _localDb.deleteTransaction(id);
    } else if (newRecord != null && newRecord.isNotEmpty) {
      await _localDb.upsertTransaction(newRecord);
    }
    _notifyRefresh();
  }

  /// Fire-and-forget push called by repositories upon local write
  void pushNow() {
    if (_currentUser == null) {
      _updateStatus(SyncStatus.guest);
      return;
    }
    unawaited(() async {
      final online = await isOnline();
      if (!online) return;
      if (_isSyncing) return;
      final success = await push();
      if (!success && _status != SyncStatus.offline) {
        _updateStatus(SyncStatus.error);
      }
    }());
  }

  /// PUSH: Reads all pending_ops in insertion order, sends to Supabase, and
  /// deletes on success. Concurrent callers share one operation so rows cannot
  /// be sent out of order or removed by two push loops at once.
  Future<bool> push() async {
    if (_currentUser == null) {
      _updateStatus(SyncStatus.guest);
      return false;
    }

    final inFlight = _pushInFlight;
    if (inFlight != null) return inFlight;

    late final Future<bool> pushFuture;
    pushFuture = _pushPendingOperations().whenComplete(() {
      if (identical(_pushInFlight, pushFuture)) {
        _pushInFlight = null;
      }
    });
    _pushInFlight = pushFuture;
    return pushFuture;
  }

  Future<bool> _pushPendingOperations() async {
    final user = _currentUser;
    if (user == null) return false;

    while (true) {
      final ops = await _localDb.getPendingOps();
      if (ops.isEmpty) return true;

      final client = _supabase;
      if (client == null) return false;

      debugPrint('[SyncService] Pushing ${ops.length} pending operation(s)...');

      for (final op in ops) {
        final id = op['id'] as int;
        final tableName = op['table_name'] as String;
        final recordId = op['record_id'] as String;
        final opType = op['op_type'] as String;
        final payloadStr = op['payload'] as String?;
        Map<String, dynamic>? payload = payloadStr != null
            ? jsonDecode(payloadStr) as Map<String, dynamic>
            : null;

        if (payload != null) {
          if (payload['user_id'] == 'local_guest' || payload['user_id'] == null) {
            payload = Map<String, dynamic>.from(payload);
            payload['user_id'] = user.id;
          } else if (payload['user_id'] != user.id) {
            debugPrint(
              '[SyncService] Discarding op #$id for mismatched user ${payload['user_id']}',
            );
            await _localDb.deletePendingOp(id);
            _pendingOpFailures.remove(id);
            continue;
          }
        }

        try {
          if (opType == 'insert' || opType == 'update') {
            if (payload != null) {
              await client.from(tableName).upsert(payload);
            }
          } else if (opType == 'delete') {
            final idColumn = tableName == 'settings' ? 'user_id' : 'id';
            await client.from(tableName).delete().eq(idColumn, recordId);
          }

          // Successfully pushed -> remove from queue.
          await _localDb.deletePendingOp(id);
          _pendingOpFailures.remove(id);
        } catch (e) {
          final errorMsg = e.toString();
          debugPrint(
            '[SyncService] Error pushing pending op #$id for '
            '$tableName ($opType): $errorMsg',
          );
          _setError('Push error ($tableName): $errorMsg');

          final failures = (_pendingOpFailures[id] ?? 0) + 1;
          _pendingOpFailures[id] = failures;

          final isPermanent = _isPermanentError(e);
          if (isPermanent || failures >= 3) {
            debugPrint(
              '[SyncService] Dropping failed pending op #$id after '
              '$failures failure(s) (isPermanent: $isPermanent) to avoid queue deadlock.',
            );
            await _localDb.deletePendingOp(id);
            _pendingOpFailures.remove(id);
            continue;
          }

          // Stop pushing for temporary/network errors to preserve ordering.
          return false;
        }
      }
    }
  }

  /// PULL: Reconciles all remote records for the authenticated user into local DB.
  Future<bool> pull() async {
    final user = _currentUser;
    if (user == null) {
      _updateStatus(SyncStatus.guest);
      return false;
    }

    final client = _supabase;
    if (client == null) return false;

    final syncStartTime = DateTime.now().toUtc().toIso8601String();

    try {
      final pendingOps = await _localDb.getPendingOps();

      // 1. Reconcile Customers
      final customersRes = await client
          .from('customers')
          .select()
          .eq('user_id', user.id);
      final remoteCustomers = (customersRes as List<dynamic>).cast<Map<String, dynamic>>();
      final remoteCustomerIds = <String>{};

      for (final row in remoteCustomers) {
        final id = row['id'] as String?;
        if (id != null) remoteCustomerIds.add(id);
        await _localDb.upsertCustomer(row);
      }

      final localCustomers = await _localDb.getCustomers(user.id);
      final pendingCustomerIds = pendingOps
          .where((op) => op['table_name'] == 'customers')
          .map((op) => op['record_id'] as String)
          .toSet();

      for (final local in localCustomers) {
        final id = local['id'] as String?;
        if (id != null && !remoteCustomerIds.contains(id) && !pendingCustomerIds.contains(id)) {
          await _localDb.deleteCustomer(id);
        }
      }

      // 2. Reconcile Transactions
      final txRes = await client
          .from('transactions')
          .select()
          .eq('user_id', user.id);
      final remoteTransactions = (txRes as List<dynamic>).cast<Map<String, dynamic>>();
      final remoteTxIds = <String>{};

      for (final row in remoteTransactions) {
        final id = row['id'] as String?;
        if (id != null) remoteTxIds.add(id);
        await _localDb.upsertTransaction(row);
      }

      final localTx = await _localDb.getTransactions(user.id);
      final pendingTxIds = pendingOps
          .where((op) => op['table_name'] == 'transactions')
          .map((op) => op['record_id'] as String)
          .toSet();

      for (final local in localTx) {
        final id = local['id'] as String?;
        if (id != null && !remoteTxIds.contains(id) && !pendingTxIds.contains(id)) {
          await _localDb.deleteTransaction(id);
        }
      }

      // 3. Reconcile Settings
      final settingsRes = await client
          .from('settings')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();
      if (settingsRes != null) {
        await _localDb.upsertSettings(Map<String, dynamic>.from(settingsRes));
      }

      // Update last_synced_at
      for (final table in ['customers', 'transactions', 'settings']) {
        await _localDb.setLastSyncedAt(table, syncStartTime);
      }

      return true;
    } catch (e) {
      final errorMsg = e.toString();
      debugPrint('[SyncService] Error pulling data: $errorMsg');
      _setError('Pull error: $errorMsg');
      return false;
    }
  }

  /// FULL SYNC: Push then pull, then notify all repositories to refresh local streams
  Future<void> fullSync() async {
    if (_isSyncing) return;

    final user = _currentUser;
    if (user == null) {
      _updateStatus(SyncStatus.guest);
      return;
    }

    final online = await isOnline();
    if (!online) {
      _updateStatus(SyncStatus.offline);
      return;
    }

    final validSession = await _ensureValidSession();
    if (!validSession) {
      _updateStatus(SyncStatus.error);
      return;
    }

    _isSyncing = true;
    _updateStatus(SyncStatus.syncing);

    try {
      final pushSuccess = await push();
      final pullSuccess = await pull();

      _notifyRefresh();

      if (pushSuccess && pullSuccess) {
        _setError(null);
        _updateStatus(SyncStatus.idle);
        final r = ref;
        if (r != null) {
          r.read(lastSyncedTimeProvider.notifier).state = DateTime.now();
        }
      } else {
        _updateStatus(SyncStatus.error);
      }
    } catch (e) {
      final errorMsg = e.toString();
      debugPrint('[SyncService] fullSync failed: $errorMsg');
      _setError('Sync failed: $errorMsg');
      final currentOnline = await isOnline();
      _updateStatus(currentOnline ? SyncStatus.error : SyncStatus.offline);
    } finally {
      _isSyncing = false;
    }
  }

  /// Checks if any local guest customers or transactions exist.
  Future<bool> hasLocalGuestData() async {
    final customers = await _localDb.getCustomers('local_guest');
    final transactions = await _localDb.getTransactions('local_guest');
    return customers.isNotEmpty || transactions.isNotEmpty;
  }

  /// Returns count of local guest customers.
  Future<int> getLocalGuestCustomerCount() async {
    final customers = await _localDb.getCustomers('local_guest');
    return customers.length;
  }

  /// Returns count of local guest transactions.
  Future<int> getLocalGuestTransactionCount() async {
    final transactions = await _localDb.getTransactions('local_guest');
    return transactions.length;
  }

  /// Returns the number of existing remote customers for [userId] in Supabase.
  /// Returns 0 if none found or on error.
  Future<int> getRemoteCustomerCount(String userId) async {
    try {
      final client = _supabase;
      if (client == null) return 0;
      final response = await client
          .from('customers')
          .select('id')
          .eq('user_id', userId);
      final list = response as List<dynamic>?;
      return list?.length ?? 0;
    } catch (e) {
      debugPrint('[SyncService] getRemoteCustomerCount error: $e');
      return 0;
    }
  }

  /// Completely discards any local guest data and pending operations.
  Future<void> discardGuestData() async {
    debugPrint('[SyncService] Discarding local guest data.');
    await _localDb.clearGuestData();
    for (final callback in _refreshCallbacks) {
      try {
        await callback();
      } catch (e) {
        debugPrint('[SyncService] Discard refresh callback error: $e');
      }
    }
  }

  /// Migrates local guest data (stamped with 'local_guest') to the newly authenticated user.
  /// If [smartMerge] is true, checks if existing remote customers share the same phone number
  /// and merges transactions under the existing customer instead of creating duplicate profiles.
  Future<void> migrateGuestData(String newUserId, {bool smartMerge = true}) async {
    // 1. Fast check if any guest data exists
    final guestCustomers = await _localDb.getCustomers('local_guest');
    final guestTransactions = await _localDb.getTransactions('local_guest');
    final guestSettings = await _localDb.getSettings('local_guest');

    if (guestCustomers.isEmpty &&
        guestTransactions.isEmpty &&
        guestSettings == null) {
      debugPrint('[SyncService] No guest data to migrate.');
      return;
    }

    debugPrint(
      '[SyncService] Migrating guest data to $newUserId: '
      '${guestCustomers.length} customer(s), ${guestTransactions.length} transaction(s), '
      'hasSettings: ${guestSettings != null}, smartMerge: $smartMerge',
    );

    // 2. Clear stale guest pending operations
    await _localDb.clearGuestPendingOps();

    // 3. Optional smart merge: fetch remote customers to match by phone
    final Map<String, String> remotePhoneToCustomerId = {};
    if (smartMerge && _supabase != null) {
      try {
        final res = await _supabase
            .from('customers')
            .select('id, phone')
            .eq('user_id', newUserId);
        for (final row in res) {
          final phone = (row['phone'] as String?)?.trim();
          final id = row['id'] as String?;
          if (phone != null && phone.isNotEmpty && id != null) {
            remotePhoneToCustomerId[phone] = id;
          }
        }
      } catch (e) {
        debugPrint('[SyncService] Fetch remote customers for smart merge error: $e');
      }
    }

    final Set<String> deduplicatedGuestCustomerIds = {};
    final Map<String, String> guestToRemoteCustomerIdMap = {};

    for (final c in guestCustomers) {
      final guestCustomerId = c['id'] as String;
      final guestPhone = (c['phone'] as String?)?.trim();

      if (guestPhone != null &&
          guestPhone.isNotEmpty &&
          remotePhoneToCustomerId.containsKey(guestPhone)) {
        final existingRemoteCustomerId = remotePhoneToCustomerId[guestPhone]!;
        deduplicatedGuestCustomerIds.add(guestCustomerId);
        guestToRemoteCustomerIdMap[guestCustomerId] = existingRemoteCustomerId;

        // Reassign transactions of this customer to existing remote customer
        await _localDb.reassignTransactionCustomerId(
          guestCustomerId,
          existingRemoteCustomerId,
        );
        // Delete guest customer row locally so no duplicate customer card appears
        await _localDb.deleteCustomer(guestCustomerId);
        debugPrint(
          '[SyncService] Deduplicated guest customer ${c['name']} ($guestPhone) -> merged into remote customer $existingRemoteCustomerId',
        );
      }
    }

    // 4. Reassign remaining guest customers locally & enqueue as insert pending_ops
    await _localDb.reassignCustomerUserId('local_guest', newUserId);
    final remainingCustomers = await _localDb.getCustomers(newUserId);
    for (final c in remainingCustomers) {
      // Only enqueue customers that were part of this guest migration and not deduplicated
      if (guestCustomers.any((gc) => gc['id'] == c['id']) &&
          !deduplicatedGuestCustomerIds.contains(c['id'])) {
        final migrated = Map<String, dynamic>.from(c);
        migrated['user_id'] = newUserId;
        await _localDb.insertPendingOp(
          tableName: 'customers',
          recordId: migrated['id'] as String,
          opType: 'insert',
          payload: jsonEncode(migrated),
        );
      }
    }

    // 5. Reassign transactions locally & enqueue as insert pending_ops
    if (guestTransactions.isNotEmpty) {
      await _localDb.reassignTransactionUserId('local_guest', newUserId);
      final nowUserTransactions = await _localDb.getTransactions(newUserId);
      for (final t in nowUserTransactions) {
        if (guestTransactions.any((gt) => gt['id'] == t['id'])) {
          final migrated = Map<String, dynamic>.from(t);
          migrated['user_id'] = newUserId;
          if (guestToRemoteCustomerIdMap.containsKey(migrated['customer_id'])) {
            migrated['customer_id'] = guestToRemoteCustomerIdMap[migrated['customer_id']];
          }
          await _localDb.insertPendingOp(
            tableName: 'transactions',
            recordId: migrated['id'] as String,
            opType: 'insert',
            payload: jsonEncode(migrated),
          );
        }
      }
    }

    // 6. Migrate settings
    if (guestSettings != null) {
      Map<String, dynamic>? remoteSettings;
      try {
        if (_supabase != null) {
          final res = await _supabase
              .from('settings')
              .select()
              .eq('user_id', newUserId)
              .maybeSingle();
          if (res != null) {
            remoteSettings = Map<String, dynamic>.from(res);
          }
        }
      } catch (e) {
        debugPrint('[SyncService] Check remote settings error: $e');
      }

      if (remoteSettings != null) {
        // Keep remote settings, discard local guest one
        await _localDb.deleteSettings('local_guest');
        await _localDb.upsertSettings(remoteSettings);
      } else {
        // Push the guest's shop name/currency
        final now = DateTime.now().toUtc().toIso8601String();
        final migratedSettings = {
          'user_id': newUserId,
          'shop_name': guestSettings['shop_name'],
          'currency_symbol': guestSettings['currency_symbol'],
          'updated_at': now,
        };
        await _localDb.deleteSettings('local_guest');
        await _localDb.upsertSettings(migratedSettings);
        await _localDb.insertPendingOp(
          tableName: 'settings',
          recordId: newUserId,
          opType: 'insert',
          payload: jsonEncode(migratedSettings),
        );
      }
    }

    // 7. Notify repositories to refresh their local streams
    for (final callback in _refreshCallbacks) {
      try {
        await callback();
      } catch (e) {
        debugPrint('[SyncService] Migration refresh callback error: $e');
      }
    }
  }

  void dispose() {
    _teardownRealtimeSubscription();
    _authSubscription?.cancel();
    _periodicTimer?.cancel();
    _connectivitySubscription?.cancel();
    _lifecycleListener?.dispose();
  }
}

final syncServiceProvider = Provider<SyncService>((ref) {
  final service = SyncService(ref: ref);
  ref.onDispose(() => service.dispose());
  return service;
});
