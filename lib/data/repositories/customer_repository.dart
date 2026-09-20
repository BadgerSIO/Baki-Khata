import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../core/current_user_service.dart';
import '../local/local_database.dart';
import '../models/customer.dart';
import '../sync/sync_service.dart';

class CustomerRepository {
  final LocalDatabase _localDb;
  final SyncService syncService;
  final CurrentUserService _currentUserService;

  final StreamController<List<Customer>> _controller =
      StreamController<List<Customer>>.broadcast();

  CustomerRepository({
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

  /// Exposes a broadcast Stream of customers starting with current local DB contents
  /// and re-emitting every time a local write or sync happens.
  Stream<List<Customer>> watchAll() {
    return Stream.multi((controller) async {
      controller.add(await getAll());
      await for (final customers in _controller.stream) {
        controller.add(customers);
      }
    }, isBroadcast: true);
  }

  Future<List<Customer>> getAll() async {
    final userId = _currentUserId;
    if (userId.isEmpty) return [];
    final rows = await _localDb.getCustomers(userId);
    return rows.map((e) => Customer.fromMap(e)).toList();
  }

  Future<Customer?> getById(String id) async {
    final row = await _localDb.getCustomerById(id);
    return row != null ? Customer.fromMap(row) : null;
  }

  Future<Customer> addCustomer({
    required String name,
    String? phone,
    String? address,
    String? id,
  }) async {
    final now = DateTime.now().toUtc();
    final customer = Customer(
      id: id ?? const Uuid().v4(),
      userId: _currentUserId,
      name: name,
      phone: phone,
      address: address,
      createdAt: now,
      updatedAt: now,
    );

    // 1. Write to local SQLite table
    await _localDb.upsertCustomer(customer.toMap());

    // 2. Insert row into pending_ops
    await _localDb.insertPendingOp(
      tableName: 'customers',
      recordId: customer.id,
      opType: 'insert',
      payload: jsonEncode(customer.toJson()),
    );

    // 3. Push new list to stream
    _controller.add(await getAll());

    // 4. Fire-and-forget sync call
    syncService.pushNow();

    return customer;
  }

  Future<Customer> updateCustomer(Customer customer) async {
    final now = DateTime.now().toUtc();
    final updated = customer.copyWith(updatedAt: now);

    // 1. Write to local SQLite table
    await _localDb.upsertCustomer(updated.toMap());

    // 2. Insert row into pending_ops
    await _localDb.insertPendingOp(
      tableName: 'customers',
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

  Future<void> deleteCustomer(String id) async {
    // 1. Delete from local SQLite table
    await _localDb.deleteCustomer(id);

    // 2. Insert row into pending_ops
    await _localDb.insertPendingOp(
      tableName: 'customers',
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

final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  final syncService = ref.watch(syncServiceProvider);
  final currentUserService = ref.watch(currentUserServiceProvider);
  final repo = CustomerRepository(
    syncService: syncService,
    currentUserService: currentUserService,
  );
  ref.onDispose(() => repo.dispose());
  return repo;
});

final customersStreamProvider = StreamProvider<List<Customer>>((ref) {
  final repo = ref.watch(customerRepositoryProvider);
  return repo.watchAll();
});
