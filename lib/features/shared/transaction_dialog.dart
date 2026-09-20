import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../data/models/customer.dart';
import '../../data/models/transaction.dart';
import '../../data/repositories/customer_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/transaction_repository.dart';
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

  @override
  Widget build(BuildContext context) {
    final customers = ref.watch(customersStreamProvider).value ?? [];
    final settings = ref.watch(settingsStreamProvider).value;
    final currency = settings?.currencySymbol ?? '৳';

    final isBaki = _currentType == TransactionType.baki;
    final accentColor = isBaki ? AppColors.debtText : AppColors.paymentText;
    final accentBg = isBaki ? AppColors.debtBg : AppColors.paymentBg;

    // Show toggle only when editing an existing transaction
    final showTypeToggle = isEditing;

    final isCustomerSelected = _selectedCustomerId != null;
    final isAmountValid = _parsedAmount != null && _parsedAmount! > 0;
    final canSave = isCustomerSelected && isAmountValid && !_isSaving;

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
      actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accentBg,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isBaki
                  ? Icons.arrow_upward_rounded
                  : Icons.arrow_downward_rounded,
              size: 20,
              color: accentColor,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            isEditing
                ? 'Edit Transaction'
                : (isBaki ? 'Add Baki (Credit)' : 'Record Payment'),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: accentColor,
              fontSize: 18,
            ),
          ),
        ],
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),

              // 1. Customer Picker / Selected Customer Display
              _buildCustomerSection(customers),

              // 2. Segmented Type Toggle (only when editing existing transaction)
              if (showTypeToggle) ...[
                const SizedBox(height: 16),
                _buildSegmentedTypeToggle(),
              ],

              const SizedBox(height: 16),

              // 3. Amount Field
              TextFormField(
                controller: _amountController,
                autofocus: widget.preselectedCustomerId != null,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: _validateAmount,
                decoration: InputDecoration(
                  labelText: 'Amount *',
                  hintText: '0.00',
                  prefixText: '$currency ',
                  prefixStyle: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: accentColor,
                  ),
                  errorText: _amountError,
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: accentColor, width: 2),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // 4. Description Field (optional, single line)
              TextFormField(
                controller: _descriptionController,
                maxLines: 1,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  hintText: 'e.g. Rice sacks, cash partial, etc.',
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
              ),

              const SizedBox(height: 14),

              // 5. Date Picker (defaults to today, internal UTC)
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
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Transaction Date',
                    prefixIcon: Icon(Icons.calendar_today_outlined),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        DateFormat.yMMMd().format(_selectedDate),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const Text(
                        'Change',
                        style: TextStyle(
                          color: AppColors.primary,
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
                  backgroundColor: accentColor,
                  minimumSize: const Size.fromHeight(44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
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
                    : const Text(
                        'Save',
                        style: TextStyle(fontWeight: FontWeight.bold),
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

  Widget _buildSegmentedTypeToggle() {
    return SegmentedButton<TransactionType>(
      segments: const [
        ButtonSegment<TransactionType>(
          value: TransactionType.baki,
          label: Text('Baki (Credit)'),
          icon: Icon(Icons.arrow_upward_rounded),
        ),
        ButtonSegment<TransactionType>(
          value: TransactionType.payment,
          label: Text('Payment'),
          icon: Icon(Icons.arrow_downward_rounded),
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

  Widget _buildCustomerSection(List<Customer> customers) {
    if (_selectedCustomerId != null) {
      final customer = _selectedCustomer ??
          customers.where((c) => c.id == _selectedCustomerId).firstOrNull;

      if (customer != null) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.primaryContainer.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primaryContainer,
                child: Text(
                  customer.name.trim().isNotEmpty
                      ? customer.name.trim()[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (customer.phone != null &&
                        customer.phone!.trim().isNotEmpty)
                      Text(
                        customer.phone!.trim(),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF60706B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (widget.preselectedCustomerId == null)
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  tooltip: 'Change customer',
                  onPressed: () {
                    setState(() {
                      _selectedCustomerId = null;
                      _selectedCustomer = null;
                    });
                  },
                ),
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
            labelText: 'Select Customer *',
            hintText: 'Search name, phone, address...',
            prefixIcon: const Icon(Icons.person_search_outlined),
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
                      ? 'No customers created yet'
                      : 'No customer found for "$_customerSearchQuery"',
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
                  label: const Text('Add New Customer'),
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
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE0E5E2)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final c in filteredCustomers.take(5)) ...[
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
                if (filteredCustomers.length > 5) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      '+${filteredCustomers.length - 5} more, refine search above',
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
                  title: const Text(
                    'Add New Customer',
                    style: TextStyle(
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
