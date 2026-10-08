import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/ads/ad_service.dart';
import '../../core/theme.dart';
import '../../data/models/customer.dart';
import '../../data/models/transaction.dart';
import '../../data/repositories/customer_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import '../customers/customers_screen.dart';
import '../vouchers/voucher_model.dart';
import '../vouchers/voucher_preview_sheet.dart';
import 'customer_dialog.dart';

/// Launches the branded voucher preview sheet for any transaction.
Future<void> launchVoucherForTransaction(
  BuildContext context,
  WidgetRef ref,
  AppTransaction tx, {
  bool forceShow = false,
}) async {
  try {
    final customers = await ref.read(customerRepositoryProvider).getAll();
    final customer = customers.where((c) => c.id == tx.customerId).firstOrNull ??
        Customer(
          id: tx.customerId,
          userId: tx.userId,
          name: 'Customer',
          createdAt: tx.createdAt,
          updatedAt: tx.updatedAt,
        );

    final settings = await ref.read(settingsRepositoryProvider).getSettings();
    final balance = await ref
        .read(transactionRepositoryProvider)
        .getTransactionBalanceSnapshot(tx.customerId, tx);

    final voucherData = VoucherData.fromTransaction(
      transaction: tx,
      customer: customer,
      settings: settings,
      balance: balance,
    );

    if (context.mounted) {
      await showVoucherPreviewSheet(context, voucherData);
    }
  } catch (e) {
    debugPrint('[launchVoucherForTransaction] Error: $e');
  }
}

/// Shows the Add/Edit Transaction dialog.
///
/// Returns the created or updated [AppTransaction], or `null` if cancelled.
Future<AppTransaction?> showTransactionDialog(
  BuildContext context,
  WidgetRef ref, {
  TransactionType? type,
  String? preselectedCustomerId,
  AppTransaction? existingTransaction,
}) async {
  final result = await showDialog<AppTransaction>(
    context: context,
    barrierDismissible: false,
    useSafeArea: false,
    builder: (ctx) => TransactionDialog(
      type: type,
      preselectedCustomerId: preselectedCustomerId,
      existingTransaction: existingTransaction,
    ),
  );

  if (result != null && context.mounted) {
    try {
      final settings = await ref.read(settingsRepositoryProvider).getSettings();
      if (settings.autoShowReceipt && context.mounted) {
        await launchVoucherForTransaction(context, ref, result);
      }
    } catch (e) {
      debugPrint('[showTransactionDialog] Auto voucher error: $e');
    }

    // Trigger interstitial ad check (capped at every 3rd transaction save)
    AdService.instance.showInterstitialOnTransactionSave();
  }

  return result;
}

class TransactionDialog extends ConsumerStatefulWidget {
  final TransactionType? type;
  final String? preselectedCustomerId;
  final AppTransaction? existingTransaction;

  const TransactionDialog({
    super.key,
    this.type,
    this.preselectedCustomerId,
    this.existingTransaction,
  });

  @override
  ConsumerState<TransactionDialog> createState() => _TransactionDialogState();
}

class _TransactionDialogState extends ConsumerState<TransactionDialog> {
  final _formKey = GlobalKey<FormState>();

  String? _selectedCustomerId;
  Customer? _selectedCustomer;
  late TransactionType _currentType;
  late final TextEditingController _amountController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _searchController;
  late DateTime _selectedDate;

  double? _parsedAmount;
  String? _amountError;
  bool _isSaving = false;
  String _customerSearchQuery = '';
  final List<VoucherItem> _items = [];

  bool get isEditing => widget.existingTransaction != null;

  @override
  void initState() {
    super.initState();
    _selectedCustomerId =
        widget.preselectedCustomerId ?? widget.existingTransaction?.customerId;
    _currentType = widget.existingTransaction?.type ??
        widget.type ??
        TransactionType.baki;

    _amountController = TextEditingController();
    if (widget.existingTransaction != null) {
      final amt = widget.existingTransaction!.amount;
      _amountController.text =
          (amt % 1 == 0) ? amt.toInt().toString() : amt.toStringAsFixed(2);
      _parsedAmount = amt;
    }

    if (widget.existingTransaction?.description != null) {
      final parsed = ItemParser.parse(widget.existingTransaction!.description);
      _items.addAll(parsed.items);
      _descriptionController = TextEditingController(text: parsed.notes ?? '');
    } else {
      _descriptionController = TextEditingController();
    }

    _searchController = TextEditingController();
    _selectedDate = widget.existingTransaction?.date.toLocal() ?? DateTime.now();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _validateAmount(String val) {
    final trimmed = val.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _amountError = 'Amount is required';
        _parsedAmount = null;
      });
      return;
    }

    final parsed = double.tryParse(trimmed);
    if (parsed == null || parsed <= 0) {
      setState(() {
        _amountError = 'Amount must be greater than 0';
        _parsedAmount = null;
      });
    } else {
      setState(() {
        _amountError = null;
        _parsedAmount = parsed;
      });
    }
  }

  void _addQuickAmount(double delta) {
    final current = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final updated = current + delta;
    final text = (updated % 1 == 0) ? updated.toInt().toString() : updated.toStringAsFixed(2);
    _amountController.text = text;
    _validateAmount(text);
  }

  Future<void> _handleSave() async {
    if (_selectedCustomerId == null || _parsedAmount == null || _isSaving) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      final amount = _parsedAmount!;
      final rawDesc = _descriptionController.text.trim();
      final desc = ItemParser.serialize(
        _items,
        notes: rawDesc.isEmpty ? null : rawDesc,
      );
      final finalDesc = desc.trim().isEmpty ? null : desc.trim();
      final dateUtc = _selectedDate.toUtc();
      final txRepo = ref.read(transactionRepositoryProvider);

      final AppTransaction result;
      if (isEditing) {
        final updated = widget.existingTransaction!.copyWith(
          customerId: _selectedCustomerId!,
          type: _currentType,
          amount: amount,
          description: finalDesc,
          date: dateUtc,
        );
        result = await txRepo.updateTransaction(updated);
      } else {
        result = await txRepo.addTransaction(
          customerId: _selectedCustomerId!,
          type: _currentType,
          amount: amount,
          description: finalDesc,
          date: dateUtc,
        );
      }

      if (mounted) {
        Navigator.of(context).pop(result);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  String _formatSelectedDate(BuildContext context, DateTime dt) {
    final now = DateTime.now();
    final local = dt.toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final txDate = DateTime(local.year, local.month, local.day);
    final dayDiff = today.difference(txDate).inDays;
    final l10n = AppLocalizations.of(context);
    final localeName = Localizations.localeOf(context).toString();

    final dateStr = DateFormat.yMMMd(localeName).format(local);

    if (dayDiff == 0) {
      return '${l10n?.relativeToday ?? "Today"}, $dateStr';
    } else if (dayDiff == 1) {
      return '${l10n?.relativeYesterday ?? "Yesterday"}, $dateStr';
    } else {
      return dateStr;
    }
  }

  String _toBengaliNumber(String input) {
    const en = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const bn = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];
    String res = input;
    for (int i = 0; i < 10; i++) {
      res = res.replaceAll(en[i], bn[i]);
    }
    return res;
  }

  bool get _isDirty {
    final amt = _amountController.text.trim();
    final desc = _descriptionController.text.trim();
    return amt.isNotEmpty || desc.isNotEmpty || _items.isNotEmpty;
  }

  Future<bool> _confirmDiscard() async {
    if (!_isDirty) return true;
    final isBn = Localizations.localeOf(context).languageCode == 'bn';
    final shouldDiscard = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isBn ? 'বাতিল করতে চান?' : 'Discard Changes?'),
        content: Text(
          isBn
              ? 'আপনার লেখা তথ্য সংরক্ষণ করা হয়নি। আপনি কি নিশ্চিত যে আপনি এটি বাতিল করবেন?'
              : 'You have unsaved changes. Are you sure you want to discard them?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(isBn ? 'না, রাখুন' : 'Keep Editing'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.debtText),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(isBn ? 'হ্যাঁ, বাতিল করুন' : 'Discard'),
          ),
        ],
      ),
    );
    return shouldDiscard ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final rawCustomers = ref.watch(customersStreamProvider).value ?? [];
    final balances = ref.watch(customerBalancesProvider);
    final settings = ref.watch(settingsStreamProvider).value;
    final currency = settings?.currencySymbol ?? '৳';

    // Smart sort customers:
    // 1. Customers with active due balances first (highest due to lowest)
    // 2. Other customers sorted alphabetically by name
    final customers = List<Customer>.from(rawCustomers)
      ..sort((a, b) {
        final balA = balances[a.id] ?? 0.0;
        final balB = balances[b.id] ?? 0.0;
        if (balA > 0 && balB <= 0) return -1;
        if (balB > 0 && balA <= 0) return 1;
        if (balA > 0 && balB > 0) {
          final cmp = balB.compareTo(balA);
          if (cmp != 0) return cmp;
        }
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

    final isBaki = _currentType == TransactionType.baki;
    final accentColor = isBaki ? AppColors.debtText : AppColors.paymentText;
    final accentBg = isBaki ? AppColors.debtBg : AppColors.paymentBg;
    final l10n = AppLocalizations.of(context);
    final isBn = Localizations.localeOf(context).languageCode == 'bn';

    // Show toggle only when editing an existing transaction
    final showTypeToggle = isEditing;

    final isCustomerSelected = _selectedCustomerId != null;
    final isAmountValid = _parsedAmount != null && _parsedAmount! > 0;
    final canSave = isCustomerSelected && isAmountValid && !_isSaving;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _confirmDiscard();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Dialog.fullscreen(
        child: Scaffold(
          backgroundColor: const Color(0xFFF7FAF8),
          appBar: AppBar(
            automaticallyImplyLeading: false,
            elevation: 0,
            backgroundColor: accentBg,
            surfaceTintColor: Colors.transparent,
            toolbarHeight: 64,
            titleSpacing: 16,
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.15),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    isBaki ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                    size: 20,
                    color: accentColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isEditing
                            ? (l10n?.editTransaction ?? 'Edit Transaction')
                            : (isBaki
                                ? (l10n?.giveCreditTitle ?? 'Give Credit')
                                : (l10n?.recordPaymentTitle ?? 'Record Payment')),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: accentColor,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isBaki
                            ? (l10n?.giveCreditSubtitle ?? 'Gave on credit')
                            : (l10n?.recordPaymentSubtitle ?? 'Received cash'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: accentColor.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 24),
                color: const Color(0xFF546E7A),
                tooltip: l10n?.close ?? 'Close',
                onPressed: () async {
                  final shouldPop = await _confirmDiscard();
                  if (shouldPop && context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: SafeArea(
            top: false,
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Customer Selection Section
                    _buildCustomerSection(customers, balances, l10n, isBn),

                    // 2. Segmented Type Toggle (only when editing existing transaction)
                    if (showTypeToggle) ...[
                      const SizedBox(height: 16),
                      _buildSegmentedTypeToggle(l10n),
                    ],

                    const SizedBox(height: 16),

                    // 3. Hero Amount Input Field
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _amountError != null
                              ? AppColors.debtText
                              : accentColor.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: accentColor.withValues(alpha: 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            controller: _amountController,
                            autofocus: widget.preselectedCustomerId != null,
                            keyboardType:
                                const TextInputType.numberWithOptions(decimal: true),
                            onChanged: _validateAmount,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: accentColor,
                            ),
                            decoration: InputDecoration(
                              labelText: '${l10n?.amount ?? "Amount"} *',
                              labelStyle: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF546E7A),
                              ),
                              hintText: '0.00',
                              prefixText: '$currency ',
                              prefixStyle: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 26,
                                color: accentColor,
                              ),
                              errorText: _amountError,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              errorBorder: InputBorder.none,
                              focusedErrorBorder: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Divider(height: 1, color: Color(0xFFECEFF1)),
                          const SizedBox(height: 10),

                          // Quick Amount Preset Chips
                          _buildQuickAmountChips(currency, accentColor, accentBg, isBn),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Itemized Entry Section (Optional line items)
                    _buildItemizedSection(currency, accentColor, accentBg, l10n, isBn),

                    const SizedBox(height: 16),

                    // 4. Description Field (optional)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFCFD8DC)),
                      ),
                      child: TextFormField(
                        controller: _descriptionController,
                        maxLines: 2,
                        minLines: 1,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          labelText: l10n?.notesDescription ?? 'Description (optional)',
                          hintText: l10n?.notesHint ?? 'e.g. Rice sacks, cash partial, etc.',
                          prefixIcon: const Icon(Icons.notes_rounded, size: 20),
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 5. Date Picker (with localized formatted date)
                    InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setState(() {
                            _selectedDate = DateTime(
                              picked.year,
                              picked.month,
                              picked.day,
                              _selectedDate.hour,
                              _selectedDate.minute,
                              _selectedDate.second,
                            );
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFCFD8DC)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today_rounded, size: 18, color: accentColor),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _formatSelectedDate(context, _selectedDate),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                            ),
                            Text(
                              isBn ? 'পরিবর্তন' : (l10n?.edit ?? 'Change'),
                              style: TextStyle(
                                color: accentColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          bottomNavigationBar: SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    offset: const Offset(0, -3),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSaving
                          ? null
                          : () async {
                              final shouldPop = await _confirmDiscard();
                              if (shouldPop && context.mounted) {
                                Navigator.of(context).pop();
                              }
                            },
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
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
                        backgroundColor: accentColor,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      onPressed: canSave ? _handleSave : null,
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              l10n?.save ?? 'Save',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAmountChips(
    String currencySymbol,
    Color accentColor,
    Color accentBg,
    bool isBn,
  ) {
    const chips = [100.0, 500.0, 1000.0, 2000.0];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: chips.map((val) {
          final raw = (val % 1 == 0) ? val.toInt().toString() : val.toStringAsFixed(0);
          final label = isBn ? _toBengaliNumber(raw) : raw;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Material(
              color: accentBg.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                onTap: () => _addQuickAmount(val),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: Text(
                    '+$currencySymbol$label',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildItemizedSection(
    String currencySymbol,
    Color accentColor,
    Color accentBg,
    AppLocalizations? l10n,
    bool isBn,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAF8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E5E2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.format_list_bulleted_rounded, size: 18, color: accentColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isBn
                      ? 'পণ্যের বিবরণ / আইটেম (${_items.length})'
                      : 'Itemized List (${_items.length})',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Color(0xFF37474F),
                  ),
                ),
              ),
              InkWell(
                onTap: () => _showAddItemDialog(isBn, currencySymbol),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_circle_outline_rounded, size: 15, color: accentColor),
                      const SizedBox(width: 4),
                      Text(
                        isBn ? '+ আইটেম যোগ' : '+ Add Item',
                        style: TextStyle(
                          color: accentColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_items.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Divider(height: 1, color: Color(0xFFECEFF1)),
            const SizedBox(height: 6),
            for (int i = 0; i < _items.length; i++) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _items[i].name,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (_items[i].quantity != null && _items[i].quantity!.isNotEmpty)
                            Text(
                              _items[i].quantity!,
                              style: const TextStyle(fontSize: 11, color: Color(0xFF78909C)),
                            ),
                        ],
                      ),
                    ),
                    Text(
                      '$currencySymbol${(_items[i].total % 1 == 0) ? _items[i].total.toInt() : _items[i].total.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF90A4AE)),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                      onPressed: () {
                        setState(() {
                          _items.removeAt(i);
                          if (_items.isNotEmpty) {
                            final sum = _items.fold<double>(0.0, (acc, it) => acc + it.total);
                            final text = (sum % 1 == 0) ? sum.toInt().toString() : sum.toStringAsFixed(2);
                            _amountController.text = text;
                            _validateAmount(text);
                          }
                        });
                      },
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Future<void> _showAddItemDialog(bool isBn, String currencySymbol) async {
    final nameCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    String? priceError;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            isBn ? 'নতুন আইটেম যোগ করুন' : 'Add Line Item',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: isBn ? 'পণ্যের নাম *' : 'Item Name *',
                  hintText: isBn ? 'যেমন: চাল, ডাল, তেল' : 'e.g. Rice, Oil',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: qtyCtrl,
                decoration: InputDecoration(
                  labelText: isBn ? 'পরিমাণ (ঐচ্ছিক)' : 'Quantity (optional)',
                  hintText: isBn ? 'যেমন: ৫ কেজি, ২ পিস' : 'e.g. 5 kg, 2 pcs',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: isBn ? 'মূল্য / টাকা *' : 'Price / Total *',
                  hintText: '0.00',
                  prefixText: '$currencySymbol ',
                  errorText: priceError,
                  isDense: true,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(isBn ? 'বাতিল' : 'Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                final price = double.tryParse(priceCtrl.text.trim());
                if (name.isEmpty) return;
                if (price == null || price <= 0) {
                  setDialogState(() {
                    priceError = isBn ? 'সঠিক টাকা লিখুন' : 'Enter valid price';
                  });
                  return;
                }
                setState(() {
                  _items.add(VoucherItem(
                    name: name,
                    quantity: qtyCtrl.text.trim().isEmpty ? null : qtyCtrl.text.trim(),
                    total: price,
                  ));
                  final sum = _items.fold<double>(0.0, (acc, it) => acc + it.total);
                  final text = (sum % 1 == 0) ? sum.toInt().toString() : sum.toStringAsFixed(2);
                  _amountController.text = text;
                  _validateAmount(text);
                });
                Navigator.pop(ctx);
              },
              child: Text(isBn ? 'যোগ করুন' : 'Add'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentedTypeToggle(AppLocalizations? l10n) {
    return SegmentedButton<TransactionType>(
      segments: [
        ButtonSegment<TransactionType>(
          value: TransactionType.baki,
          label: Text(l10n?.credit ?? 'Credit'),
          icon: const Icon(Icons.arrow_upward_rounded),
        ),
        ButtonSegment<TransactionType>(
          value: TransactionType.payment,
          label: Text(l10n?.payment ?? 'Payment'),
          icon: const Icon(Icons.arrow_downward_rounded),
        ),
      ],
      selected: {_currentType},
      onSelectionChanged: (newSelection) {
        setState(() {
          _currentType = newSelection.first;
        });
      },
    );
  }

  Widget _buildCustomerSection(
    List<Customer> customers,
    Map<String, double> balances,
    AppLocalizations? l10n,
    bool isBn,
  ) {
    if (_selectedCustomerId != null) {
      final customer = _selectedCustomer ??
          customers.where((c) => c.id == _selectedCustomerId).firstOrNull;

      if (customer != null) {
        final currentBal = balances[customer.id] ?? 0.0;
        final hasDue = currentBal > 0;
        final hasAdvance = currentBal < 0;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.3),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primaryContainer,
                child: Text(
                  customer.name.trim().isNotEmpty
                      ? customer.name.trim()[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Color(0xFF191C1B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (customer.phone != null &&
                            customer.phone!.trim().isNotEmpty)
                          Text(
                            customer.phone!.trim(),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF78909C),
                            ),
                          ),
                        if (hasDue)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.debtBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isBn
                                  ? 'বাকি: ৳${_toBengaliNumber(currentBal.toStringAsFixed(0))}'
                                  : 'Due: ৳${currentBal.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppColors.debtText,
                              ),
                            ),
                          )
                        else if (hasAdvance)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.paymentBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isBn
                                  ? 'অগ্রিম: ৳${_toBengaliNumber(currentBal.abs().toStringAsFixed(0))}'
                                  : 'Advance: ৳${currentBal.abs().toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppColors.paymentText,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (widget.preselectedCustomerId == null) ...[
                const SizedBox(width: 8),
                InkWell(
                  onTap: () {
                    setState(() {
                      _selectedCustomerId = null;
                      _selectedCustomer = null;
                    });
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.sync_alt_rounded,
                          size: 13,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isBn ? 'বদলান' : (l10n?.edit ?? 'Change'),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      }
    }

    // No customer selected -> Searchable Customer Picker
    final query = _customerSearchQuery.trim().toLowerCase();
    final filteredCustomers = customers.where((c) {
      if (query.isEmpty) return true;
      final nameMatch = c.name.toLowerCase().contains(query);
      final phoneMatch = c.phone?.toLowerCase().contains(query) ?? false;
      final addressMatch = c.address?.toLowerCase().contains(query) ?? false;
      return nameMatch || phoneMatch || addressMatch;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _searchController,
          onChanged: (val) {
            setState(() {
              _customerSearchQuery = val;
            });
          },
          decoration: InputDecoration(
            labelText: '${l10n?.selectCustomer ?? "Select Customer"} *',
            hintText: l10n?.searchCustomersHint ?? 'Search name, phone, address...',
            prefixIcon: const Icon(Icons.person_search_outlined),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFCFD8DC)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFCFD8DC)),
            ),
            suffixIcon: _customerSearchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _customerSearchQuery = '');
                    },
                  )
                : null,
          ),
        ),
        const SizedBox(height: 8),
        if (filteredCustomers.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE0E5E2)),
            ),
            child: Column(
              children: [
                Text(
                  _customerSearchQuery.isEmpty
                      ? (l10n?.noCustomersFound ?? 'No customers created yet')
                      : (l10n != null
                          ? '${l10n.noCustomersFound}: "$_customerSearchQuery"'
                          : 'No customer found for "$_customerSearchQuery"'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF78909C),
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: () async {
                    final created = await showCustomerDialog(
                      context,
                      ref,
                      initialName: _customerSearchQuery.isNotEmpty
                          ? _searchController.text.trim()
                          : null,
                    );
                    if (created != null && mounted) {
                      setState(() {
                        _selectedCustomerId = created.id;
                        _selectedCustomer = created;
                        _searchController.clear();
                        _customerSearchQuery = '';
                      });
                    }
                  },
                  icon: const Icon(Icons.person_add_rounded, size: 18),
                  label: Text(l10n?.addNewCustomer ?? 'Add New Customer'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          Material(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: Color(0xFFE0E5E2)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 240),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: filteredCustomers.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, indent: 14, endIndent: 14),
                    itemBuilder: (context, idx) {
                      final c = filteredCustomers[idx];
                      final bal = balances[c.id] ?? 0.0;
                      final hasDue = bal > 0;
                      final hasAdvance = bal < 0;

                      return ListTile(
                        dense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: AppColors.primaryContainer,
                          child: Text(
                            c.name.trim().isNotEmpty
                                ? c.name.trim()[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        title: Text(
                          c.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Color(0xFF191C1B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: (c.phone != null && c.phone!.isNotEmpty)
                            ? Text(
                                c.phone!,
                                style: const TextStyle(
                                    fontSize: 12, color: Color(0xFF78909C)),
                              )
                            : null,
                        trailing: hasDue
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.debtBg,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  isBn
                                      ? 'বাকি: ৳${_toBengaliNumber(bal.toStringAsFixed(0))}'
                                      : 'Due: ৳${bal.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.debtText,
                                  ),
                                ),
                              )
                            : (hasAdvance
                                ? Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.paymentBg,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      isBn
                                          ? 'অগ্রিম: ৳${_toBengaliNumber(bal.abs().toStringAsFixed(0))}'
                                          : 'Advance: ৳${bal.abs().toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.paymentText,
                                      ),
                                    ),
                                  )
                                : null),
                        onTap: () {
                          setState(() {
                            _selectedCustomerId = c.id;
                            _selectedCustomer = c;
                            _searchController.clear();
                            _customerSearchQuery = '';
                          });
                        },
                      );
                    },
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFECEFF1)),
                ListTile(
                  dense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                  leading: const Icon(
                    Icons.person_add_alt_1_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  title: Text(
                    l10n?.addNewCustomer ?? 'Add New Customer',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  onTap: () async {
                    final created = await showCustomerDialog(
                      context,
                      ref,
                      initialName: _customerSearchQuery.isNotEmpty
                          ? _searchController.text.trim()
                          : null,
                    );
                    if (created != null && mounted) {
                      setState(() {
                        _selectedCustomerId = created.id;
                        _selectedCustomer = created;
                        _searchController.clear();
                        _customerSearchQuery = '';
                      });
                    }
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }
}
