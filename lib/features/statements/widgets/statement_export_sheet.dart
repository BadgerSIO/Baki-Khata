import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/locale_provider.dart';
import '../../../core/theme.dart';
import '../../../data/models/app_settings.dart';
import '../../../data/models/customer.dart';
import '../../../data/models/transaction.dart';
import '../../vouchers/voucher_model.dart';
import '../models/statement_models.dart';
import '../services/ledger_calculator_service.dart';
import '../services/pdf_statement_service.dart';

class StatementExportSheet extends ConsumerStatefulWidget {
  final Customer customer;
  final List<AppTransaction> transactions;
  final AppSettings settings;

  const StatementExportSheet({
    super.key,
    required this.customer,
    required this.transactions,
    required this.settings,
  });

  static Future<void> show(
    BuildContext context, {
    required Customer customer,
    required List<AppTransaction> transactions,
    required AppSettings settings,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatementExportSheet(
        customer: customer,
        transactions: transactions,
        settings: settings,
      ),
    );
  }

  @override
  ConsumerState<StatementExportSheet> createState() => _StatementExportSheetState();
}

class _StatementExportSheetState extends ConsumerState<StatementExportSheet> {
  StatementPeriodType _selectedPeriodType = StatementPeriodType.last3Months;
  DateTime? _customStart;
  DateTime? _customEnd;
  bool _isDetailed = true;
  bool _isGeneratingPrint = false;
  bool _isGeneratingShare = false;

  StatementPeriod get _currentPeriod {
    return StatementPeriod.fromType(
      _selectedPeriodType,
      customStart: _customStart,
      customEnd: _customEnd,
    );
  }

  CustomerStatementData get _currentStatementData {
    return LedgerCalculatorService.computeCustomerStatement(
      customer: widget.customer,
      allTransactions: widget.transactions,
      settings: widget.settings,
      period: _currentPeriod,
      isDetailed: _isDetailed,
    );
  }

  Future<void> _pickCustomDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: DateTimeRange(
        start: _customStart ?? DateTime(now.year, now.month, 1),
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

  Future<void> _handlePrintOrPreview(bool isBengali) async {
    if (_isGeneratingPrint || _isGeneratingShare) return;
    setState(() => _isGeneratingPrint = true);

    try {
      final statement = _currentStatementData;
      final success = await PdfStatementService.printOrPreviewCustomerStatement(
        statement,
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

  Future<void> _handleShare(bool isBengali) async {
    if (_isGeneratingPrint || _isGeneratingShare) return;
    setState(() => _isGeneratingShare = true);

    try {
      final statement = _currentStatementData;
      final success = await PdfStatementService.shareCustomerStatement(
        statement,
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
    final statementData = _currentStatementData;

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
                    Icons.picture_as_pdf_rounded,
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
                        isBengali ? 'অফিসিয়াল PDF স্টেটমেন্ট' : 'Official PDF Statement',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF191C1B),
                        ),
                      ),
                      Text(
                        '👤 ${widget.customer.name}',
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

            // 1. Period Selector Title
            Text(
              isBengali ? 'সময়কাল নির্বাচন করুন' : 'Select Statement Period',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF263238),
              ),
            ),
            const SizedBox(height: 10),

            // Filter Chips
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

            // Active Date Range Label
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF7FAF8),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE0E5E2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _currentPeriod.getDateRangeFormatted(isBengali: isBengali),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF37474F)),
                    ),
                  ),
                  Text(
                    '${isBengali ? PhoneUtils.toBengaliNumber(statementData.entries.length.toString()) : statementData.entries.length} ${isBengali ? "টি লেনদেন" : "txs"}',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF78909C)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 2. Financial Summary Preview Card
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
                        isBengali ? 'প্রারম্ভিক জের (পূর্বের বাকি):' : 'Opening Balance:',
                        style: const TextStyle(fontSize: 13, color: Color(0xFF546E7A)),
                      ),
                      Text(
                        formatMoney(statementData.openingBalance),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isBengali ? 'এই সময়ে মোট বাকি (+):' : 'Period Credit (+):',
                        style: const TextStyle(fontSize: 13, color: AppColors.debtText),
                      ),
                      Text(
                        '+${formatMoney(statementData.totalBaki)}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.debtText),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isBengali ? 'এই সময়ে মোট জমা (-):' : 'Period Payment (-):',
                        style: const TextStyle(fontSize: 13, color: AppColors.paymentText),
                      ),
                      Text(
                        '-${formatMoney(statementData.totalPayment)}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.paymentText),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isBengali ? 'সর্বমোট সমাপনী বাকি:' : 'Closing Net Balance:',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF191C1B)),
                      ),
                      Text(
                        formatMoney(statementData.closingBalance),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: statementData.closingBalance > 0
                              ? AppColors.debtText
                              : (statementData.closingBalance < 0 ? AppColors.advanceText : AppColors.paymentText),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // 3. Detailed Items Toggle
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF7FAF8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE0E5E2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long_rounded, size: 20, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isBengali ? 'পণ্যের বিস্তারিত চালান সহ' : 'Detailed Items Breakdown',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          isBengali
                              ? 'মালামালের নাম, পরিমাণ ও দর উল্লেখ থাকবে'
                              : 'Includes item names, quantity and unit rates',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF78909C)),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isDetailed,
                    onChanged: (val) => setState(() => _isDetailed = val),
                    activeThumbColor: AppColors.primary,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 4. Action Buttons
            Row(
              children: [
                // Print / Preview Button
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: (_isGeneratingPrint || _isGeneratingShare)
                        ? null
                        : () => _handlePrintOrPreview(isBengali),
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
                // Share PDF Button
                Expanded(
                  child: FilledButton(
                    onPressed: (_isGeneratingPrint || _isGeneratingShare)
                        ? null
                        : () => _handleShare(isBengali),
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
