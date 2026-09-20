import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/current_user_service.dart';
import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../data/models/app_settings.dart';
import '../../data/models/transaction.dart';
import '../../data/repositories/customer_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../data/sync/sync_service.dart';
import '../auth/account_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  final Future<void> Function()? onSignOut;

  const SettingsScreen({
    super.key,
    this.onSignOut,
  });

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _shopNameController = TextEditingController();
  final _currencyController = TextEditingController();

  bool _initialized = false;
  bool _isEditing = false;
  bool _isSaving = false;
  bool _isManualSyncing = false;

  @override
  void dispose() {
    _shopNameController.dispose();
    _currencyController.dispose();
    super.dispose();
  }

  void _populate(AppSettings settings) {
    if (!_initialized) {
      _shopNameController.text = settings.shopName;
      _currencyController.text = settings.currencySymbol;
      _initialized = true;
    } else if (!_isEditing) {
      _shopNameController.text = settings.shopName;
      _currencyController.text = settings.currencySymbol;
    }
  }

  void _startEditing() {
    final settings = ref.read(settingsStreamProvider).value;
    if (settings != null) {
      _shopNameController.text = settings.shopName;
      _currencyController.text = settings.currencySymbol;
    }
    setState(() => _isEditing = true);
  }

  void _cancelEditing() {
    FocusScope.of(context).unfocus();
    final settings = ref.read(settingsStreamProvider).value;
    if (settings != null) {
      _shopNameController.text = settings.shopName;
      _currencyController.text = settings.currencySymbol;
    }
    setState(() => _isEditing = false);
  }

  Future<void> _handleManualSave() async {
    FocusScope.of(context).unfocus();
    final success = await _saveSettings(showFeedback: true);
    if (success && mounted) {
      setState(() => _isEditing = false);
    }
  }

  Future<bool> _saveSettings({bool showFeedback = false}) async {
    if (!mounted) return false;
    setState(() => _isSaving = true);
    try {
      final name = _shopNameController.text.trim();
      final curr = _currencyController.text.trim();
      await ref.read(settingsRepositoryProvider).updateSettings(
            shopName: name.isEmpty ? 'My Shop' : name,
            currencySymbol: curr.isEmpty ? '৳' : curr,
          );
      if (showFeedback && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Shop information saved'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return true;
    } catch (e) {
      debugPrint('[SettingsScreen] Save failed: $e');
      if (showFeedback && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save settings: $e'),
            backgroundColor: AppColors.debtText,
          ),
        );
      }
      return false;
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _handleManualSync() async {
    final syncStatus = ref.read(syncStatusProvider);
    if (syncStatus == SyncStatus.guest) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in to back up and sync your data with the cloud.'),
        ),
      );
      return;
    }

    setState(() => _isManualSyncing = true);
    try {
      await ref.read(syncServiceProvider).fullSync();
    } finally {
      if (mounted) {
        setState(() => _isManualSyncing = false);
      }
    }
  }

  Color _getStatusColor(SyncStatus status) {
    switch (status) {
      case SyncStatus.guest:
        return const Color(0xFF78909C); // Grey (guest)
      case SyncStatus.idle:
        return const Color(0xFF2E7D32); // Green (synced)
      case SyncStatus.syncing:
        return const Color(0xFFF57C00); // Orange (syncing)
      case SyncStatus.offline:
        return const Color(0xFF78909C); // Grey (offline)
      case SyncStatus.error:
        return AppColors.debtText; // Red (error)
    }
  }

  String _getStatusLabel(SyncStatus status) {
    switch (status) {
      case SyncStatus.guest:
        return 'Guest Mode';
      case SyncStatus.idle:
        return 'Synced';
      case SyncStatus.syncing:
        return 'Syncing...';
      case SyncStatus.offline:
        return 'Offline';
      case SyncStatus.error:
        return 'Sync Error';
    }
  }

  String _formatLastSynced(DateTime? dt) {
    if (dt == null) return 'Not synced yet';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (now.day == dt.day &&
        now.month == dt.month &&
        now.year == dt.year) {
      return DateFormat('h:mm a').format(dt);
    } else {
      return DateFormat.yMMMd().add_jm().format(dt);
    }
  }

  String _getUserEmail() {
    try {
      return supabase.auth.currentUser?.email ?? 'Signed in with Google';
    } catch (_) {
      return 'user@example.com';
    }
  }

  Future<void> _confirmSignOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out?'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        content: const Text(
          'Are you sure you want to sign out of Baki Khata? Any pending offline data remains safely stored on this device.',
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: const BorderSide(color: Color(0xFFCFD8DC)),
                    foregroundColor: const Color(0xFF546E7A),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.debtText,
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text(
                    'Sign Out',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (widget.onSignOut != null) {
        await widget.onSignOut!();
        return;
      }
      try {
        await supabase.auth.signOut();
        await ref.read(customerRepositoryProvider).refresh();
        await ref.read(transactionRepositoryProvider).refresh();
        await ref.read(settingsRepositoryProvider).refresh();
      } catch (e) {
        debugPrint('[SettingsScreen] Sign out: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsStreamProvider);
    final syncStatus = ref.watch(syncStatusProvider);
    final lastSynced = ref.watch(lastSyncedTimeProvider);
    final lastSyncError = ref.watch(lastSyncErrorProvider);
    final theme = Theme.of(context);
    final statusColor = _getStatusColor(syncStatus);
    final currentUserId = ref.watch(currentUserIdProvider).value ?? CurrentUserService.guestSentinel;
    final isGuest = currentUserId == CurrentUserService.guestSentinel;

    settingsAsync.whenData((settings) => _populate(settings));

    final isSyncBusy = _isManualSyncing || syncStatus == SyncStatus.syncing;

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF8),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // 1. Cloud Sync Status Card
          Card(
            margin: EdgeInsets.zero,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFFE0E5E2)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Colored status dot
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _getStatusLabel(syncStatus),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                      const Spacer(),
                      FilledButton.tonal(
                        onPressed: isSyncBusy ? null : _handleManualSync,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 36),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: isSyncBusy
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.sync_rounded, size: 18),
                                  SizedBox(width: 6),
                                  Text('Sync Now'),
                                ],
                              ),
                      ),
                    ],
                  ),
                  if (syncStatus == SyncStatus.error && lastSyncError != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.debtBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.debtText.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            size: 16,
                            color: AppColors.debtText,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              lastSyncError,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.debtText,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    'Last synced: ${_formatLastSynced(lastSynced)}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF60706B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Your records are automatically saved on this device and synced to your cloud account when online.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF78909C),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 2. Shop Information Card
          Card(
            margin: EdgeInsets.zero,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFFE0E5E2)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Shop Information',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      if (!_isEditing)
                        FilledButton.tonalIcon(
                          onPressed: _startEditing,
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          label: const Text('Edit'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 36),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        )
                      else if (_isSaving)
                        const Row(
                          children: [
                            SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                              ),
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Saving...',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Customize your shop name and currency symbol.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF78909C),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (!_isEditing) ...[
                    // View Mode Display
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F4F2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.storefront_rounded,
                              size: 20,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Shop Name',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF78909C),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _shopNameController.text.isEmpty
                                      ? 'My Shop'
                                      : _shopNameController.text,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF191C1B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F4F2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.currency_exchange_rounded,
                              size: 20,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Currency Symbol',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF78909C),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _currencyController.text.isEmpty
                                      ? '৳'
                                      : _currencyController.text,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF191C1B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // Edit Mode Form Fields
                    TextFormField(
                      controller: _shopNameController,
                      decoration: const InputDecoration(
                        labelText: 'Shop Name',
                        hintText: 'e.g. Bhai Bhai Store',
                        prefixIcon: Icon(Icons.storefront_rounded),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _currencyController,
                      decoration: const InputDecoration(
                        labelText: 'Currency Symbol',
                        hintText: 'e.g. ৳, \$, ₹, €',
                        prefixIcon: Icon(Icons.currency_exchange_rounded),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isSaving ? null : _cancelEditing,
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            icon: const Icon(Icons.close_rounded, size: 18),
                            label: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _isSaving ? null : _handleManualSave,
                            style: FilledButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            icon: _isSaving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.check_rounded, size: 18),
                            label: Text(_isSaving ? 'Saving...' : 'Save'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 3. Account Card
          Card(
            margin: EdgeInsets.zero,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFFE0E5E2)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: isGuest
                  ? Builder(builder: (context) {
                      // Gather live totals for the nudge copy
                      final customers =
                          ref.watch(customersStreamProvider).value ?? [];
                      final transactions =
                          ref.watch(transactionsStreamProvider).value ?? [];
                      final currency =
                          ref.watch(settingsStreamProvider).value?.currencySymbol ?? '৳';

                      final totalOutstanding = customers.fold<double>(
                        0,
                        (sum, c) {
                          final paid = transactions
                              .where((t) =>
                                  t.customerId == c.id &&
                                  t.type == TransactionType.payment)
                              .fold<double>(0, (s, t) => s + t.amount);
                          final owed = transactions
                              .where((t) =>
                                  t.customerId == c.id &&
                                  t.type == TransactionType.baki)
                              .fold<double>(0, (s, t) => s + t.amount);
                          return sum + (owed - paid).clamp(0, double.infinity);
                        },
                      );

                      const amberColor = Color(0xFFB78103);
                      const amberBg = Color(0xFFF3E6B0);

                      final String nudgeMessage;
                      if (customers.isNotEmpty) {
                        final moneyFmt = NumberFormat('#,##0.##');
                        nudgeMessage =
                            '$currency${moneyFmt.format(totalOutstanding)} across ${customers.length} customer${customers.length == 1 ? '' : 's'} isn\'t backed up';
                      } else {
                        nudgeMessage =
                            'Sign in to back up and sync your data to the cloud';
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Account',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            decoration: BoxDecoration(
                              color: amberBg,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.info_outline_rounded,
                                  color: amberColor,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    nudgeMessage,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: amberColor,
                                      fontWeight: FontWeight.w600,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              icon: const Icon(Icons.login_rounded, size: 18),
                              label: const Text('Sign In / Create Account'),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(44),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const AccountScreen(),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    })
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Account',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.account_circle_outlined,
                              color: Color(0xFF78909C),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _getUserEmail(),
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF1E2925),
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.debtText,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(44),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: const Icon(Icons.logout_rounded, size: 18),
                            label: const Text(
                              'Sign Out',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            onPressed: _confirmSignOut,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
