import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/current_user_service.dart';
import '../../core/supabase_client.dart';
import '../local/local_database.dart';
import '../models/app_settings.dart';
import '../sync/sync_service.dart';

class SettingsRepository {
  final LocalDatabase _localDb;
  final SupabaseClient? _supabase;
  final SyncService syncService;
  final CurrentUserService _currentUserService;

  final StreamController<AppSettings> _controller =
      StreamController<AppSettings>.broadcast();
  final Set<String> _initializedUsers = {};

  static SupabaseClient? _resolveSupabaseClient(SupabaseClient? client) {
    if (client != null) return client;
    try {
      return supabase;
    } catch (_) {
      return null;
    }
  }

  SettingsRepository({
    LocalDatabase? localDb,
    SupabaseClient? supabaseClient,
    required this.syncService,
    CurrentUserService? currentUserService,
  })  : _localDb = localDb ?? LocalDatabase.instance,
        _supabase = _resolveSupabaseClient(supabaseClient),
        _currentUserService = currentUserService ?? CurrentUserService() {
    syncService.registerRefreshCallback(refresh);
  }

  String get _currentUserId => _currentUserService.effectiveUserId;

  /// Exposes a broadcast Stream of app settings starting with current local DB contents
  Stream<AppSettings> watchSettings() {
    return Stream.multi((controller) async {
      controller.add(await getSettings());
      await for (final settings in _controller.stream) {
        controller.add(settings);
      }
    }, isBroadcast: true);
  }

  Future<AppSettings> getSettings() async {
    final userId = _currentUserId;
    if (userId.isEmpty) {
      return AppSettings(userId: '', updatedAt: DateTime.now().toUtc());
    }

    final localData = await _localDb.getSettings(userId);
    if (localData != null) {
      return AppSettings.fromMap(localData);
    }

    // Default settings for user
    final defaultSettings = AppSettings(
      userId: userId,
      shopName: 'My Shop',
      currencySymbol: '৳',
      updatedAt: DateTime.now().toUtc(),
    );
    await _localDb.upsertSettings(defaultSettings.toMap());
    return defaultSettings;
  }

  Future<AppSettings> updateSettings({
    required String shopName,
    required String currencySymbol,
  }) async {
    final now = DateTime.now().toUtc();
    final settings = AppSettings(
      userId: _currentUserId,
      shopName: shopName,
      currencySymbol: currencySymbol,
      updatedAt: now,
    );

    // 1. Write to local SQLite table
    await _localDb.upsertSettings(settings.toMap());

    // 2. Insert row into pending_ops
    await _localDb.insertPendingOp(
      tableName: 'settings',
      recordId: settings.userId,
      opType: 'update',
      payload: jsonEncode(settings.toJson()),
    );

    // 3. Push new settings to stream
    _controller.add(settings);

    // 4. Fire-and-forget sync call
    syncService.pushNow();

    return settings;
  }

  /// Ensures a newly authenticated user has default settings in both stores.
  /// When offline, the remote create is preserved in the pending queue.
  Future<void> ensureSettingsForCurrentUser() async {
    final userId = _currentUserId;
    if (userId.isEmpty ||
        userId == CurrentUserService.guestSentinel ||
        _initializedUsers.contains(userId)) {
      return;
    }

    try {
      if (_supabase != null) {
        final remoteSettings = await _supabase
            .from('settings')
            .select()
            .eq('user_id', userId)
            .maybeSingle();

        if (remoteSettings != null) {
          await _localDb.upsertSettings(remoteSettings);
        } else {
          final defaults = AppSettings(
            userId: userId,
            shopName: 'My Shop',
            currencySymbol: '৳',
            updatedAt: DateTime.now().toUtc(),
          );
          await _localDb.upsertSettings(defaults.toMap());
          await _supabase.from('settings').upsert(defaults.toJson());
        }
      } else {
        final defaults = AppSettings(
          userId: userId,
          shopName: 'My Shop',
          currencySymbol: '৳',
          updatedAt: DateTime.now().toUtc(),
        );
        await _localDb.upsertSettings(defaults.toMap());
      }

      _initializedUsers.add(userId);
      await refresh();
    } catch (error) {
      debugPrint('[SettingsRepository] Could not initialize settings: $error');

      final defaults = AppSettings(
        userId: userId,
        shopName: 'My Shop',
        currencySymbol: '৳',
        updatedAt: DateTime.now().toUtc(),
      );
      await _localDb.upsertSettings(defaults.toMap());
      await _localDb.insertPendingOp(
        tableName: 'settings',
        recordId: userId,
        opType: 'insert',
        payload: jsonEncode(defaults.toJson()),
      );
      _initializedUsers.add(userId);
      await refresh();
      syncService.pushNow();
    }
  }

  /// Refreshes the stream from local DB (called by SyncService after pull)
  Future<void> refresh() async {
    _controller.add(await getSettings());
  }

  void dispose() {
    _controller.close();
  }
}

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  final syncService = ref.watch(syncServiceProvider);
  final currentUserService = ref.watch(currentUserServiceProvider);
  final repo = SettingsRepository(
    syncService: syncService,
    currentUserService: currentUserService,
  );
  ref.onDispose(() => repo.dispose());
  return repo;
});

final settingsStreamProvider = StreamProvider<AppSettings>((ref) {
  final repo = ref.watch(settingsRepositoryProvider);
  return repo.watchSettings();
});
