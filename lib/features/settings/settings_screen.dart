import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/current_user_service.dart';
import '../../core/locale_provider.dart';
import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../data/models/app_settings.dart';
import '../../data/models/transaction.dart';
import '../../data/repositories/customer_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../data/sync/sync_service.dart';
import '../../l10n/generated/app_localizations.dart';
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
  final _proprietorNameController = TextEditingController();
  final _shopPhoneController = TextEditingController();
  final _shopAddressController = TextEditingController();
  final _currencyController = TextEditingController();
  bool _autoShowReceipt = true;

  final _bkashController = TextEditingController();
  final _nagadController = TextEditingController();
  final _rocketController = TextEditingController();
  bool _bkashIsMerchant = false;
  bool _nagadIsMerchant = false;
  bool _rocketIsMerchant = false;

  bool _initialized = false;
  bool _isEditing = false;
  bool _isSaving = false;
  bool _isEditingPayments = false;
  bool _isSavingPayments = false;
  bool _isManualSyncing = false;

  @override
  void dispose() {
    _shopNameController.dispose();
    _proprietorNameController.dispose();
    _shopPhoneController.dispose();
    _shopAddressController.dispose();
    _currencyController.dispose();
    _bkashController.dispose();
    _nagadController.dispose();
    _rocketController.dispose();
    super.dispose();
  }

  void _populate(AppSettings settings) {
    if (!_initialized) {
      _shopNameController.text = settings.shopName;
      _proprietorNameController.text = settings.proprietorName ?? '';
      _shopPhoneController.text = settings.shopPhone ?? '';
      _shopAddressController.text = settings.shopAddress ?? '';
      _currencyController.text = settings.currencySymbol;
      _autoShowReceipt = settings.autoShowReceipt;
      _bkashController.text = settings.bkashNumber ?? '';
      _bkashIsMerchant = settings.bkashIsMerchant;
      _nagadController.text = settings.nagadNumber ?? '';
      _nagadIsMerchant = settings.nagadIsMerchant;
      _rocketController.text = settings.rocketNumber ?? '';
      _rocketIsMerchant = settings.rocketIsMerchant;
      _initialized = true;
    } else {
      if (!_isEditing) {
        _shopNameController.text = settings.shopName;
        _proprietorNameController.text = settings.proprietorName ?? '';
        _shopPhoneController.text = settings.shopPhone ?? '';
        _shopAddressController.text = settings.shopAddress ?? '';
        _currencyController.text = settings.currencySymbol;
        _autoShowReceipt = settings.autoShowReceipt;
      }
      if (!_isEditingPayments) {
        _bkashController.text = settings.bkashNumber ?? '';
        _bkashIsMerchant = settings.bkashIsMerchant;
        _nagadController.text = settings.nagadNumber ?? '';
        _nagadIsMerchant = settings.nagadIsMerchant;
        _rocketController.text = settings.rocketNumber ?? '';
        _rocketIsMerchant = settings.rocketIsMerchant;
      }
    }
  }

  void _startEditingPayments() {
    final settings = ref.read(settingsStreamProvider).value;
    if (settings != null) {
      _bkashController.text = settings.bkashNumber ?? '';
      _bkashIsMerchant = settings.bkashIsMerchant;
      _nagadController.text = settings.nagadNumber ?? '';
      _nagadIsMerchant = settings.nagadIsMerchant;
      _rocketController.text = settings.rocketNumber ?? '';
      _rocketIsMerchant = settings.rocketIsMerchant;
    }
    setState(() => _isEditingPayments = true);
  }

  void _cancelEditingPayments() {
    FocusScope.of(context).unfocus();
    final settings = ref.read(settingsStreamProvider).value;
    if (settings != null) {
      _bkashController.text = settings.bkashNumber ?? '';
      _bkashIsMerchant = settings.bkashIsMerchant;
      _nagadController.text = settings.nagadNumber ?? '';
      _nagadIsMerchant = settings.nagadIsMerchant;
      _rocketController.text = settings.rocketNumber ?? '';
      _rocketIsMerchant = settings.rocketIsMerchant;
    }
    setState(() => _isEditingPayments = false);
  }

  Future<void> _savePayments() async {
    FocusScope.of(context).unfocus();
    if (!mounted) return;
    setState(() => _isSavingPayments = true);
    try {
      final settings = ref.read(settingsStreamProvider).value;
      final bkash = _bkashController.text.trim();
      final nagad = _nagadController.text.trim();
      final rocket = _rocketController.text.trim();

      await ref.read(settingsRepositoryProvider).updateSettings(
            shopName: settings?.shopName ?? 'My Shop',
            currencySymbol: settings?.currencySymbol ?? '৳',
            shopPhone: settings?.shopPhone,
            shopAddress: settings?.shopAddress,
            autoShowReceipt: settings?.autoShowReceipt,
            bkashNumber: bkash.isEmpty ? null : bkash,
            bkashIsMerchant: _bkashIsMerchant,
            nagadNumber: nagad.isEmpty ? null : nagad,
            nagadIsMerchant: _nagadIsMerchant,
            rocketNumber: rocket.isEmpty ? null : rocket,
            rocketIsMerchant: _rocketIsMerchant,
            overridePaymentMethods: true,
          );

      if (mounted) {
        setState(() => _isEditingPayments = false);
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n?.shopInfoSaved ?? 'Shop information saved'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('[SettingsScreen] Save payments failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save payment methods: $e'),
            backgroundColor: AppColors.debtText,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingPayments = false);
      }
    }
  }

  void _startEditing() {
    final settings = ref.read(settingsStreamProvider).value;
    if (settings != null) {
      _shopNameController.text = settings.shopName;
      _proprietorNameController.text = settings.proprietorName ?? '';
      _shopPhoneController.text = settings.shopPhone ?? '';
      _shopAddressController.text = settings.shopAddress ?? '';
      _currencyController.text = settings.currencySymbol;
      _autoShowReceipt = settings.autoShowReceipt;
    }
    setState(() => _isEditing = true);
  }

  void _cancelEditing() {
    FocusScope.of(context).unfocus();
    final settings = ref.read(settingsStreamProvider).value;
    if (settings != null) {
      _shopNameController.text = settings.shopName;
      _proprietorNameController.text = settings.proprietorName ?? '';
      _shopPhoneController.text = settings.shopPhone ?? '';
      _shopAddressController.text = settings.shopAddress ?? '';
      _currencyController.text = settings.currencySymbol;
      _autoShowReceipt = settings.autoShowReceipt;
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

  Future<void> _updateAutoShowReceipt(bool val) async {
    setState(() => _autoShowReceipt = val);
    final settings = ref.read(settingsStreamProvider).value;
    if (settings != null) {
      await ref.read(settingsRepositoryProvider).updateSettings(
            shopName: settings.shopName,
            currencySymbol: settings.currencySymbol,
            shopPhone: settings.shopPhone,
            shopAddress: settings.shopAddress,
            proprietorName: settings.proprietorName,
            autoShowReceipt: val,
          );
    }
  }

  Future<bool> _saveSettings({bool showFeedback = false}) async {
    if (!mounted) return false;
    setState(() => _isSaving = true);
    try {
      final name = _shopNameController.text.trim();
      final proprietor = _proprietorNameController.text.trim();
      final phone = _shopPhoneController.text.trim();
      final addr = _shopAddressController.text.trim();
      final curr = _currencyController.text.trim();
      await ref.read(settingsRepositoryProvider).updateSettings(
            shopName: name.isEmpty ? 'My Shop' : name,
            currencySymbol: curr.isEmpty ? '৳' : curr,
            shopPhone: phone.isEmpty ? null : phone,
            shopAddress: addr.isEmpty ? null : addr,
            proprietorName: proprietor.isEmpty ? null : proprietor,
            autoShowReceipt: _autoShowReceipt,
          );
      if (showFeedback && mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n?.shopInfoSaved ?? 'Shop information saved'),
            duration: const Duration(seconds: 2),
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
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n?.guestWarning ?? 'Please sign in to back up and sync your data with the cloud.'),
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

  String _getStatusLabel(SyncStatus status, AppLocalizations? l10n) {
    switch (status) {
      case SyncStatus.guest:
        return l10n?.guestMode ?? 'Guest Mode';
      case SyncStatus.idle:
        return l10n?.synced ?? 'Synced';
      case SyncStatus.syncing:
        return l10n?.syncing ?? 'Syncing...';
      case SyncStatus.offline:
        return l10n?.offline ?? 'Offline';
      case SyncStatus.error:
        return l10n?.syncError ?? 'Sync Error';
    }
  }

  String _formatLastSynced(DateTime? dt, AppLocalizations? l10n) {
    if (dt == null) return l10n?.neverSynced ?? 'Never synced';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) {
      return l10n?.justNow ?? 'Just now';
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

  Future<void> _confirmSignOut(AppLocalizations? l10n) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n?.signOutTitle ?? 'Sign Out?'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        content: Text(
          l10n?.signOutConfirm ??
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
                  child: Text(
                    l10n?.cancel ?? 'Cancel',
                    style: const TextStyle(fontWeight: FontWeight.w600),
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
                  child: Text(
                    l10n?.signOut ?? 'Sign Out',
                    style: const TextStyle(fontWeight: FontWeight.bold),
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
    final l10n = AppLocalizations.of(context);
    final currentLocale = ref.watch(localeNotifierProvider);
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
                        _getStatusLabel(syncStatus, l10n),
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
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.sync_rounded, size: 18),
                                  const SizedBox(width: 6),
                                  Text(l10n?.syncNow ?? 'Sync Now'),
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
                    l10n?.lastSynced(_formatLastSynced(lastSynced, l10n)) ??
                        'Last synced: ${_formatLastSynced(lastSynced, l10n)}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF60706B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n?.syncHelpText ??
                        'Your records are automatically saved on this device and synced to your cloud account when online.',
                    style: const TextStyle(
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
                        l10n?.shopInfo ?? 'Shop Information',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      if (!_isEditing)
                        FilledButton.tonalIcon(
                          onPressed: _startEditing,
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          label: Text(l10n?.edit ?? 'Edit'),
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
                        Row(
                          children: [
                            const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              l10n?.loading ?? 'Saving...',
                              style: const TextStyle(
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
                  Text(
                    l10n?.customizeShopDetails ?? 'Customize your shop name and currency symbol.',
                    style: const TextStyle(
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
                                Text(
                                  l10n?.shopName ?? 'Shop Name',
                                  style: const TextStyle(
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
                              Icons.person_outline_rounded,
                              size: 20,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  currentLocale.languageCode == 'bn' ? 'স্বত্বাধিকারীর নাম' : 'Proprietor Name',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF78909C),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _proprietorNameController.text.isEmpty
                                      ? (currentLocale.languageCode == 'bn' ? 'যুক্ত করা নেই' : 'Not set')
                                      : _proprietorNameController.text,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: _proprietorNameController.text.isEmpty
                                        ? const Color(0xFF90A4AE)
                                        : const Color(0xFF191C1B),
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
                              Icons.phone_outlined,
                              size: 20,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  currentLocale.languageCode == 'bn' ? 'দোকানের ফোন নম্বর' : 'Shop Phone',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF78909C),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _shopPhoneController.text.isEmpty
                                      ? (currentLocale.languageCode == 'bn' ? 'যুক্ত করা নেই' : 'Not set')
                                      : _shopPhoneController.text,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: _shopPhoneController.text.isEmpty
                                        ? const Color(0xFF90A4AE)
                                        : const Color(0xFF191C1B),
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
                              Icons.location_on_outlined,
                              size: 20,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  currentLocale.languageCode == 'bn' ? 'দোকানের ঠিকানা' : 'Shop Address',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF78909C),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _shopAddressController.text.isEmpty
                                      ? (currentLocale.languageCode == 'bn' ? 'যুক্ত করা নেই' : 'Not set')
                                      : _shopAddressController.text,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: _shopAddressController.text.isEmpty
                                        ? const Color(0xFF90A4AE)
                                        : const Color(0xFF191C1B),
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
                                Text(
                                  l10n?.currencySymbol ?? 'Currency Symbol',
                                  style: const TextStyle(
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
                      decoration: InputDecoration(
                        labelText: l10n?.shopName ?? 'Shop Name',
                        hintText: 'e.g. Bhai Bhai Store',
                        prefixIcon: const Icon(Icons.storefront_rounded),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _proprietorNameController,
                      decoration: InputDecoration(
                        labelText: currentLocale.languageCode == 'bn' ? 'স্বত্বাধিকারীর নাম' : 'Proprietor Name',
                        hintText: 'e.g. Md. Rafiqul Islam',
                        prefixIcon: const Icon(Icons.person_outline_rounded),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _shopPhoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: currentLocale.languageCode == 'bn' ? 'দোকানের ফোন নম্বর' : 'Shop Phone',
                        hintText: 'e.g. 01712-345678',
                        prefixIcon: const Icon(Icons.phone_outlined),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _shopAddressController,
                      decoration: InputDecoration(
                        labelText: currentLocale.languageCode == 'bn' ? 'দোকানের ঠিকানা' : 'Shop Address',
                        hintText: 'e.g. Shop 12, New Market, Dhaka',
                        prefixIcon: const Icon(Icons.location_on_outlined),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _currencyController,
                      decoration: InputDecoration(
                        labelText: l10n?.currencySymbol ?? 'Currency Symbol',
                        hintText: 'e.g. ৳, \$, ₹, €',
                        prefixIcon: const Icon(Icons.currency_exchange_rounded),
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
                            label: Text(l10n?.cancel ?? 'Cancel'),
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
                            label: Text(_isSaving ? (l10n?.loading ?? 'Saving...') : (l10n?.save ?? 'Save')),
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

          // 2.5 Digital Payment Methods Card
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
                        l10n?.paymentMethods ?? 'Digital Payment Methods',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      if (!_isEditingPayments)
                        FilledButton.tonalIcon(
                          onPressed: _startEditingPayments,
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          label: Text(l10n?.edit ?? 'Edit'),
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
                      else if (_isSavingPayments)
                        Row(
                          children: [
                            const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              l10n?.loading ?? 'Saving...',
                              style: const TextStyle(
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
                  Text(
                    l10n?.paymentMethodsSubtitle ??
                        'Configure bKash, Nagad & Rocket for reminders',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF78909C),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (!_isEditingPayments) ...[
                    // View mode
                    _buildPaymentChannelViewRow(
                      brand: l10n?.bkash ?? 'bKash',
                      number: _bkashController.text,
                      isMerchant: _bkashIsMerchant,
                      brandColor: const Color(0xFFE2136E),
                      l10n: l10n,
                    ),
                    const SizedBox(height: 10),
                    _buildPaymentChannelViewRow(
                      brand: l10n?.nagad ?? 'Nagad',
                      number: _nagadController.text,
                      isMerchant: _nagadIsMerchant,
                      brandColor: const Color(0xFFF7941D),
                      l10n: l10n,
                    ),
                    const SizedBox(height: 10),
                    _buildPaymentChannelViewRow(
                      brand: l10n?.rocket ?? 'Rocket',
                      number: _rocketController.text,
                      isMerchant: _rocketIsMerchant,
                      brandColor: const Color(0xFF8C3494),
                      l10n: l10n,
                    ),
                  ] else ...[
                    // Edit mode
                    _buildPaymentChannelEditSection(
                      brand: l10n?.bkash ?? 'bKash',
                      controller: _bkashController,
                      isMerchant: _bkashIsMerchant,
                      brandColor: const Color(0xFFE2136E),
                      onTypeChanged: (isMerchant) {
                        setState(() => _bkashIsMerchant = isMerchant);
                      },
                      l10n: l10n,
                    ),
                    const SizedBox(height: 14),
                    _buildPaymentChannelEditSection(
                      brand: l10n?.nagad ?? 'Nagad',
                      controller: _nagadController,
                      isMerchant: _nagadIsMerchant,
                      brandColor: const Color(0xFFF7941D),
                      onTypeChanged: (isMerchant) {
                        setState(() => _nagadIsMerchant = isMerchant);
                      },
                      l10n: l10n,
                    ),
                    const SizedBox(height: 14),
                    _buildPaymentChannelEditSection(
                      brand: l10n?.rocket ?? 'Rocket',
                      controller: _rocketController,
                      isMerchant: _rocketIsMerchant,
                      brandColor: const Color(0xFF8C3494),
                      onTypeChanged: (isMerchant) {
                        setState(() => _rocketIsMerchant = isMerchant);
                      },
                      l10n: l10n,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isSavingPayments ? null : _cancelEditingPayments,
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            icon: const Icon(Icons.close_rounded, size: 18),
                            label: Text(l10n?.cancel ?? 'Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _isSavingPayments ? null : _savePayments,
                            style: FilledButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            icon: _isSavingPayments
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.check_rounded, size: 18),
                            label: Text(_isSavingPayments
                                ? (l10n?.loading ?? 'Saving...')
                                : (l10n?.save ?? 'Save')),
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

          // 3. Receipt & Voucher Preferences Card
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
                  Text(
                    currentLocale.languageCode == 'bn'
                        ? 'রসিদ ও ভাউচার সেটিংস'
                        : 'Receipt & Voucher Preferences',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    currentLocale.languageCode == 'bn'
                        ? 'লেনদেন সেভের পর ডিজিটাল মেমোর প্রদর্শন নিয়ন্ত্রণ করুন।'
                        : 'Control automatic display of digital cash memos after recording entries.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF78909C),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                            Icons.receipt_long_rounded,
                            size: 20,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                currentLocale.languageCode == 'bn'
                                    ? 'স্বয়ংক্রিয় ভাউচার প্রদর্শন'
                                    : 'Auto-show Voucher',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF191C1B),
                                ),
                              ),
                              Text(
                                currentLocale.languageCode == 'bn'
                                    ? 'লেনদেন সেভের পর ডিজিটাল রসিদ প্রদর্শন করবে'
                                    : 'Displays receipt memo immediately after save',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF78909C),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _autoShowReceipt,
                          onChanged: _updateAutoShowReceipt,
                          activeThumbColor: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 3. App Language Card
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
                  Text(
                    l10n?.appLanguage ?? 'App Language',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n?.selectLanguage ?? 'Select Language',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF78909C),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _buildLanguageOption(
                          title: 'English',
                          subtitle: 'Default',
                          isSelected: currentLocale.languageCode == 'en',
                          onTap: () {
                            ref.read(localeNotifierProvider.notifier).setLocale(const Locale('en'));
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildLanguageOption(
                          title: 'বাংলা',
                          subtitle: 'Bangla',
                          isSelected: currentLocale.languageCode == 'bn',
                          onTap: () {
                            ref.read(localeNotifierProvider.notifier).setLocale(const Locale('bn'));
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 4. Account Card
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
                            l10n?.guestWarning ?? 'Sign in to back up and sync your data to the cloud';
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n?.accountAndSync ?? 'Account',
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
                              label: Text(l10n?.signInOrCreateAccount ?? 'Sign In / Create Account'),
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
                          l10n?.accountAndSync ?? 'Account',
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
                            label: Text(
                              l10n?.signOut ?? 'Sign Out',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            onPressed: () => _confirmSignOut(l10n),
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

  Widget _buildLanguageOption({
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE8F5E9) : const Color(0xFFF0F4F2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : const Color(0xFFE0E5E2),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              size: 20,
              color: isSelected ? AppColors.primary : const Color(0xFF78909C),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: isSelected ? AppColors.primary : const Color(0xFF191C1B),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelected
                          ? AppColors.primary.withValues(alpha: 0.8)
                          : const Color(0xFF78909C),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentChannelViewRow({
    required String brand,
    required String number,
    required bool isMerchant,
    required Color brandColor,
    required AppLocalizations? l10n,
  }) {
    final hasNumber = number.trim().isNotEmpty;
    final typeLabel = isMerchant
        ? '${l10n?.merchant ?? "Merchant"} (${l10n?.makePayment ?? "Make Payment"})'
        : '${l10n?.personal ?? "Personal"} (${l10n?.sendMoney ?? "Send Money"})';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4F2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: brandColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              brand,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: brandColor,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasNumber ? number : (l10n?.neverSynced ?? 'Not set'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: hasNumber
                        ? const Color(0xFF191C1B)
                        : const Color(0xFF90A4AE),
                  ),
                ),
                if (hasNumber) ...[
                  const SizedBox(height: 2),
                  Text(
                    typeLabel,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF60706B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentChannelEditSection({
    required String brand,
    required TextEditingController controller,
    required bool isMerchant,
    required Color brandColor,
    required ValueChanged<bool> onTypeChanged,
    required AppLocalizations? l10n,
  }) {
    final personalLabel =
        '${l10n?.personal ?? "Personal"} (${l10n?.sendMoney ?? "Send Money"})';
    final merchantLabel =
        '${l10n?.merchant ?? "Merchant"} (${l10n?.makePayment ?? "Make Payment"})';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FBF9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E5E2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: brandColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  brand,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: brandColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                l10n?.phoneOptional ?? 'Phone Number',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF60706B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              hintText: 'e.g. 01712345678',
              isDense: true,
              prefixIcon: const Icon(Icons.phone_android_rounded, size: 20),
              suffixIcon: controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        controller.clear();
                        setState(() {});
                      },
                    )
                  : null,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          Text(
            l10n?.accountType ?? 'Account Type',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF78909C),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: Center(
                    child: Text(
                      personalLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight:
                            !isMerchant ? FontWeight.bold : FontWeight.w500,
                        color:
                            !isMerchant ? Colors.white : const Color(0xFF60706B),
                      ),
                    ),
                  ),
                  selected: !isMerchant,
                  onSelected: (selected) {
                    if (selected) onTypeChanged(false);
                  },
                  selectedColor: AppColors.primary,
                  backgroundColor: const Color(0xFFEFF3F1),
                  showCheckmark: false,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: !isMerchant
                          ? AppColors.primary
                          : const Color(0xFFE0E5E2),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChoiceChip(
                  label: Center(
                    child: Text(
                      merchantLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight:
                            isMerchant ? FontWeight.bold : FontWeight.w500,
                        color:
                            isMerchant ? Colors.white : const Color(0xFF60706B),
                      ),
                    ),
                  ),
                  selected: isMerchant,
                  onSelected: (selected) {
                    if (selected) onTypeChanged(true);
                  },
                  selectedColor: AppColors.primary,
                  backgroundColor: const Color(0xFFEFF3F1),
                  showCheckmark: false,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: isMerchant
                          ? AppColors.primary
                          : const Color(0xFFE0E5E2),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
