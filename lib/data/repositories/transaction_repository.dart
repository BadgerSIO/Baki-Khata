import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../core/current_user_service.dart';
import '../local/local_database.dart';
import '../models/transaction.dart';
import '../sync/sync_service.dart';

class TransactionRepository {
  final LocalDatabase _localDb;
  final SyncService syncService;
  final CurrentUserService _currentUserService;

  final StreamController<List<AppTransaction>> _controller =
      StreamController<List<AppTransaction>>.broadcast();

  TransactionRepository({
    LocalDatabase? localDb,
    SupabaseClient? supabaseClient,
    required this.syncService,
    CurrentUserService? currentUserService,
  })  : _localDb = localDb ?? LocalDatabase.instance,
        _currentUserService = currentUserService ??
            CurrentUserService(supabaseClient: supabaseClient) {
    syncService.registerRefreshCallback(refresh);
  }

  String get _currentUserId => _currentUserService.effectiveUserId;

  /// Exposes a broadcast Stream of all transactions
  Stream<List<AppTransaction>> watchAll() {
    return Stream.multi((controller) async {
      controller.add(await getAll());
      await for (final transactions in _controller.stream) {
        controller.add(transactions);
      }
    }, isBroadcast: true);
  }

  /// Exposes a broadcast Stream of transactions for a specific customer
  Stream<List<AppTransaction>> watchByCustomer(String customerId) {
    return Stream.multi((controller) async {
      controller.add(await getAll(customerId: customerId));
      await for (final transactions in _controller.stream) {
        controller.add(
          transactions
              .where((transaction) => transaction.customerId == customerId)
              .toList(),
        );
      }
    }, isBroadcast: true);
  }

  Future<List<AppTransaction>> getAll({String? customerId}) async {
    final userId = _currentUserId;
    if (userId.isEmpty) return [];
    final rows = await _localDb.getTransactions(userId, customerId: customerId);
    return rows.map((e) => AppTransaction.fromMap(e)).toList();
  }

  Future<AppTransaction?> getById(String id) async {
    final row = await _localDb.getTransactionById(id);
    return row != null ? AppTransaction.fromMap(row) : null;
  }

  Future<AppTransaction> addTransaction({
    required String customerId,
    required TransactionType type,
    required double amount,
    String? description,
    DateTime? date,
    String? id,
  }) async {
    final now = DateTime.now().toUtc();
    final transaction = AppTransaction(
      id: id ?? const Uuid().v4(),
      userId: _currentUserId,
      customerId: customerId,
      type: type,
      amount: amount,
      description: description,
      date: date?.toUtc() ?? now,
      createdAt: now,
      updatedAt: now,
    );

    // 1. Write to local SQLite table
    await _localDb.upsertTransaction(transaction.toMap());

    // 2. Insert row into pending_ops
    await _localDb.insertPendingOp(
      tableName: 'transactions',
      recordId: transaction.id,
      opType: 'insert',
      payload: jsonEncode(transaction.toJson()),
    );

    // 3. Push new list to stream
    _controller.add(await getAll());

    // 4. Fire-and-forget sync call
    syncService.pushNow();

    return transaction;
  }

  Future<AppTransaction> updateTransaction(AppTransaction transaction) async {
    final now = DateTime.now().toUtc();
    final updated = transaction.copyWith(updatedAt: now);

    // 1. Write to local SQLite table
    await _localDb.upsertTransaction(updated.toMap());

    // 2. Insert row into pending_ops
    await _localDb.insertPendingOp(
      tableName: 'transactions',
      recordId: updated.id,
      opType: 'update',
      payload: jsonEncode(updated.toJson()),
    );

    // 3. Push new list to stream
    _controller.add(await getAll());

    // 4. Fire-and-forget sync call
    syncService.pushNow();

    return updated;
  }

  Future<void> deleteTransaction(String id) async {
    // 1. Delete from local SQLite table
    await _localDb.deleteTransaction(id);

    // 2. Insert row into pending_ops
    await _localDb.insertPendingOp(
      tableName: 'transactions',
      recordId: id,
      opType: 'delete',
      payload: null,
    );

    // 3. Push new list to stream
    _controller.add(await getAll());

    // 4. Fire-and-forget sync call
    syncService.pushNow();
  }

  /// Refreshes the stream from local DB (called by SyncService after pull)
  Future<void> refresh() async {
    _controller.add(await getAll());
  }

  void dispose() {
    _controller.close();
  }
}

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  final syncService = ref.watch(syncServiceProvider);
  final currentUserService = ref.watch(currentUserServiceProvider);
  final repo = TransactionRepository(
    syncService: syncService,
    currentUserService: currentUserService,
  );
  ref.onDispose(() => repo.dispose());
  return repo;
});

final transactionsStreamProvider = StreamProvider<List<AppTransaction>>((ref) {
  final repo = ref.watch(transactionRepositoryProvider);
  return repo.watchAll();
});

final customerTransactionsStreamProvider =
    StreamProvider.family<List<AppTransaction>, String>((ref, customerId) {
  final repo = ref.watch(transactionRepositoryProvider);
  return repo.watchByCustomer(customerId);
});
