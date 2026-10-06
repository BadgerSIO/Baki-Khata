import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../data/models/customer.dart';
import '../../data/models/transaction.dart';
import '../../data/repositories/customer_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import '../customers/customers_screen.dart';
import 'customer_dialog.dart';

/// Shows the Add/Edit Transaction dialog.
///
/// Returns the created or updated [AppTransaction], or `null` if cancelled.
Future<AppTransaction?> showTransactionDialog(
  BuildContext context,
  WidgetRef ref, {
  TransactionType? type,
  String? preselectedCustomerId,
  AppTransaction? existingTransaction,
}) {
  return showDialog<AppTransaction>(
    context: context,
    builder: (ctx) => TransactionDialog(
      type: type,
      preselectedCustomerId: preselectedCustomerId,
      existingTransaction: existingTransaction,
    ),
  );
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

    _descriptionController = TextEditingController(
      text: widget.existingTransaction?.description ?? '',
    );
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
      final desc = _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim();
      final dateUtc = _selectedDate.toUtc();
      final txRepo = ref.read(transactionRepositoryProvider);

      final AppTransaction result;
      if (isEditing) {
        final updated = widget.existingTransaction!.copyWith(
          customerId: _selectedCustomerId!,
          type: _currentType,
          amount: amount,
          description: desc,
          date: dateUtc,
        );
        result = await txRepo.updateTransaction(updated);
      } else {
        result = await txRepo.addTransaction(
          customerId: _selectedCustomerId!,
          type: _currentType,
          amount: amount,
          description: desc,
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

  @override
  Widget build(BuildContext context) {
    final customers = ref.watch(customersStreamProvider).value ?? [];
    final settings = ref.watch(settingsStreamProvider).value;
    final currency = settings?.currencySymbol ?? '৳';

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

    return AlertDialog(
      titlePadding: EdgeInsets.zero,
      contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      actionsPadding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      title: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 12, 14),
        decoration: BoxDecoration(
          color: accentBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Row(
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
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 20),
              color: const Color(0xFF78909C),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Customer Selection Section
              _buildCustomerSection(customers, l10n, isBn),

              // 2. Segmented Type Toggle (only when editing existing transaction)
              if (showTypeToggle) ...[
                const SizedBox(height: 16),
                _buildSegmentedTypeToggle(l10n),
              ],

              const SizedBox(height: 16),

              // 3. Hero Amount Input Field
              TextFormField(
                controller: _amountController,
                autofocus: widget.preselectedCustomerId != null,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: _validateAmount,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: accentColor,
                ),
                decoration: InputDecoration(
                  labelText: '${l10n?.amount ?? "Amount"} *',
                  hintText: '0.00',
                  prefixText: '$currency ',
                  prefixStyle: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                    color: accentColor,
                  ),
                  errorText: _amountError,
                  fillColor: accentBg.withValues(alpha: 0.25),
                  filled: true,
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: accentColor, width: 2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: accentColor.withValues(alpha: 0.3)),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Quick Amount Preset Chips
              _buildQuickAmountChips(currency, accentColor, accentBg, isBn),

              const SizedBox(height: 14),

              // 4. Description Field (optional)
              TextFormField(
                controller: _descriptionController,
                maxLines: 1,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: l10n?.notesDescription ?? 'Description (optional)',
                  hintText: l10n?.notesHint ?? 'e.g. Rice sacks, cash partial, etc.',
                  prefixIcon: const Icon(Icons.notes_rounded, size: 20),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),

              const SizedBox(height: 14),

              // 5. Date Picker (with localized formatted date)
              InkWell(
                borderRadius: BorderRadius.circular(12),
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
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7FAF8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFCFD8DC)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_rounded, size: 18, color: accentColor),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _formatSelectedDate(context, _selectedDate),
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
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
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
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
                  minimumSize: const Size.fromHeight(46),
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
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
              ),
            ),
          ],
        ),
      ],
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
    AppLocalizations? l10n,
    bool isBn,
  ) {
    if (_selectedCustomerId != null) {
      final customer = _selectedCustomer ??
          customers.where((c) => c.id == _selectedCustomerId).firstOrNull;

      if (customer != null) {
        final balances = ref.watch(customerBalancesProvider);
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
            fillColor: const Color(0xFFF7FAF8),
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
              color: const Color(0xFFF7FAF8),
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
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFE0E5E2)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final c in filteredCustomers.take(4)) ...[
                  ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 14,
                      backgroundColor: AppColors.primaryContainer,
                      child: Text(
                        c.name.trim().isNotEmpty
                            ? c.name.trim()[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    title: Text(
                      c.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    subtitle: (c.phone != null && c.phone!.isNotEmpty)
                        ? Text(
                            c.phone!,
                            style: const TextStyle(fontSize: 11),
                          )
                        : null,
                    onTap: () {
                      setState(() {
                        _selectedCustomerId = c.id;
                        _selectedCustomer = c;
                        _searchController.clear();
                        _customerSearchQuery = '';
                      });
                    },
                  ),
                  const Divider(height: 1, indent: 12, endIndent: 12),
                ],
                if (filteredCustomers.length > 4) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      '+${filteredCustomers.length - 4} more, refine search above',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF78909C),
                      ),
                    ),
                  ),
                  const Divider(height: 1, indent: 12, endIndent: 12),
                ],
                ListTile(
                  dense: true,
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
