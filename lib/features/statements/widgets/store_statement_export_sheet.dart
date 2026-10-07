import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/locale_provider.dart';
import '../../../core/theme.dart';
import '../../../data/models/app_settings.dart';
import '../../../data/models/customer.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../vouchers/voucher_model.dart';
import '../models/statement_models.dart';
import '../services/ledger_calculator_service.dart';
import '../services/pdf_statement_service.dart';

class StoreStatementExportSheet extends ConsumerStatefulWidget {
  final List<Customer> customers;
  final AppSettings settings;

  const StoreStatementExportSheet({
    super.key,
    required this.customers,
    required this.settings,
  });

  static Future<void> show(
    BuildContext context, {
    required List<Customer> customers,
    required AppSettings settings,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StoreStatementExportSheet(
        customers: customers,
        settings: settings,
      ),
    );
  }

  @override
  ConsumerState<StoreStatementExportSheet> createState() => _StoreStatementExportSheetState();
}

class _StoreStatementExportSheetState extends ConsumerState<StoreStatementExportSheet> {
  StatementPeriodType _selectedPeriodType = StatementPeriodType.thisYear;
  DateTime? _customStart;
  DateTime? _customEnd;
  bool _isGeneratingPrint = false;
  bool _isGeneratingShare = false;

  StatementPeriod get _currentPeriod {
    return StatementPeriod.fromType(
      _selectedPeriodType,
      customStart: _customStart,
      customEnd: _customEnd,
    );
  }

  Future<void> _pickCustomDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: DateTimeRange(
        start: _customStart ?? DateTime(now.year, 1, 1),
        end: _customEnd ?? now,
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.primary,
                  onPrimary: Colors.white,
                ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedPeriodType = StatementPeriodType.custom;
        _customStart = picked.start;
        _customEnd = picked.end;
      });
    }
  }

  Future<void> _handlePrintOrPreview(StoreStatementData data, bool isBengali) async {
    if (_isGeneratingPrint || _isGeneratingShare) return;
    setState(() => _isGeneratingPrint = true);

    try {
      final success = await PdfStatementService.printOrPreviewStoreStatement(
        data,
        isBengali: isBengali,
      );

      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isBengali ? 'প্রিন্ট সম্পন্ন করা যায়নি' : 'Could not complete print'),
            backgroundColor: AppColors.debtText,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.debtText,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGeneratingPrint = false);
      }
    }
  }

  Future<void> _handleShare(StoreStatementData data, bool isBengali) async {
    if (_isGeneratingPrint || _isGeneratingShare) return;
    setState(() => _isGeneratingShare = true);

    try {
      final success = await PdfStatementService.shareStoreStatement(
        data,
        isBengali: isBengali,
      );

      if (success && mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.debtText,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGeneratingShare = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBengali = ref.watch(localeProvider).languageCode == 'bn';
    final currency = widget.settings.currencySymbol;
    final transactions = ref.watch(transactionsStreamProvider).value ?? [];

    final storeStatementData = LedgerCalculatorService.computeStoreStatement(
      customers: widget.customers,
      allTransactions: transactions,
      settings: widget.settings,
      period: _currentPeriod,
    );

    String formatMoney(double val) {
      final fmt = (val.abs() % 1 == 0)
          ? NumberFormat('#,##0')
          : NumberFormat('#,##0.00');
      final formatted = fmt.format(val.abs());
      final numStr = isBengali ? PhoneUtils.toBengaliNumber(formatted) : formatted;
      return '$currency $numStr';
    }

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.menu_book_rounded,
                    color: AppColors.primary,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isBengali ? 'দোকানের মাস্টার লেজার এক্সপোর্ট' : 'Store Master Ledger Export',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF191C1B),
                        ),
                      ),
                      Text(
                        '🏪 ${widget.settings.shopName} • ${widget.customers.length} ${isBengali ? "জন কাস্টমার" : "customers"}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF546E7A),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF78909C)),
                ),
              ],
            ),

            const SizedBox(height: 18),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // Period Selection
            Text(
              isBengali ? 'সময়কাল নির্বাচন করুন' : 'Select Statement Period',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF263238),
              ),
            ),
            const SizedBox(height: 10),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildPeriodChip(
                  label: isBengali ? 'গত ৩০ দিন' : 'Last 30 Days',
                  type: StatementPeriodType.last30Days,
                ),
                _buildPeriodChip(
                  label: isBengali ? 'গত ৩ মাস' : 'Last 3 Months',
                  type: StatementPeriodType.last3Months,
                ),
                _buildPeriodChip(
                  label: isBengali ? 'গত ৬ মাস' : 'Last 6 Months',
                  type: StatementPeriodType.last6Months,
                ),
                _buildPeriodChip(
                  label: isBengali ? 'চলতি বছর' : 'This Year',
                  type: StatementPeriodType.thisYear,
                ),
                _buildPeriodChip(
                  label: isBengali ? 'শুরু থেকে সব' : 'All Time',
                  type: StatementPeriodType.allTime,
                ),
                ActionChip(
                  avatar: const Icon(Icons.date_range_rounded, size: 16, color: AppColors.primary),
                  label: Text(
                    _selectedPeriodType == StatementPeriodType.custom
                        ? (isBengali ? 'কাস্টম তারিখ (নির্বাচিত)' : 'Custom (Selected)')
                        : (isBengali ? 'কাস্টম তারিখ' : 'Custom Period'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: _selectedPeriodType == StatementPeriodType.custom
                          ? FontWeight.bold
                          : FontWeight.w500,
                      color: _selectedPeriodType == StatementPeriodType.custom
                          ? AppColors.primary
                          : const Color(0xFF37474F),
                    ),
                  ),
                  backgroundColor: _selectedPeriodType == StatementPeriodType.custom
                      ? AppColors.primaryContainer.withValues(alpha: 0.5)
                      : const Color(0xFFF1F5F3),
                  side: BorderSide(
                    color: _selectedPeriodType == StatementPeriodType.custom
                        ? AppColors.primary
                        : Colors.transparent,
                  ),
                  onPressed: _pickCustomDateRange,
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Summary Info
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F7F5),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFCFD8DC)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isBengali ? 'প্রারম্ভিক বাকি:' : 'Opening Due:',
                        style: const TextStyle(fontSize: 13, color: Color(0xFF546E7A)),
                      ),
                      Text(
                        formatMoney(storeStatementData.totalOpeningBalance),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isBengali ? 'এই সময়ে নতুন বাকি (+):' : 'Period Credit (+):',
                        style: const TextStyle(fontSize: 13, color: AppColors.debtText),
                      ),
                      Text(
                        '+${formatMoney(storeStatementData.totalBaki)}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.debtText),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isBengali ? 'এই সময়ে মোট আদায় (-):' : 'Period Collection (-):',
                        style: const TextStyle(fontSize: 13, color: AppColors.paymentText),
                      ),
                      Text(
                        '-${formatMoney(storeStatementData.totalPayment)}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.paymentText),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isBengali ? 'দোকানের মোট বাকি (পাওনা):' : 'Total Store Due:',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF191C1B)),
                      ),
                      Text(
                        formatMoney(storeStatementData.totalClosingBalance),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.debtText,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Actions
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: (_isGeneratingPrint || _isGeneratingShare)
                        ? null
                        : () => _handlePrintOrPreview(storeStatementData, isBengali),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isGeneratingPrint
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.print_rounded, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                isBengali ? 'প্রিন্ট ও প্রিভিউ' : 'Print & Preview',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: (_isGeneratingPrint || _isGeneratingShare)
                        ? null
                        : () => _handleShare(storeStatementData, isBengali),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isGeneratingShare
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.share_rounded, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                isBengali ? 'PDF শেয়ার' : 'Share PDF',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodChip({
    required String label,
    required StatementPeriodType type,
  }) {
    final isSelected = _selectedPeriodType == type;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedPeriodType = type;
            _customStart = null;
            _customEnd = null;
          });
        }
      },
      selectedColor: AppColors.primaryContainer.withValues(alpha: 0.5),
      backgroundColor: const Color(0xFFF1F5F3),
      checkmarkColor: AppColors.primary,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        color: isSelected ? AppColors.primary : const Color(0xFF37474F),
      ),
      side: BorderSide(
        color: isSelected ? AppColors.primary : Colors.transparent,
      ),
    );
  }
}
