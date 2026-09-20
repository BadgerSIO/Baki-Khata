import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../data/models/customer.dart';
import '../../data/models/transaction.dart';
import '../../data/repositories/customer_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../shared/transaction_dialog.dart';

enum HistoryFilter {
  all,
  baki,
  payment,
}

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  HistoryFilter _currentFilter = HistoryFilter.all;

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(transactionsStreamProvider);
    final customersAsync = ref.watch(customersStreamProvider);
    final settings = ref.watch(settingsStreamProvider).value;
    final currency = settings?.currencySymbol ?? '৳';

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF8),
      body: transactionsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 48,
                  color: AppColors.debtText,
                ),
                const SizedBox(height: 12),
                Text(
                  'Failed to load transactions: $err',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF60706B)),
                ),
              ],
            ),
          ),
        ),
        data: (transactions) {
          final customers = customersAsync.value ?? [];
          final customerMap = {for (final c in customers) c.id: c};

          // Count per category for filter chip badges
          final bakiCount = transactions.where((t) => t.isBaki).length;
          final paymentCount = transactions.where((t) => t.isPayment).length;

          // Reverse chronological sorting: newest date first, fallback to newest createdAt
          final sorted = [...transactions]..sort((a, b) {
              final cmp = b.date.compareTo(a.date);
              if (cmp != 0) return cmp;
              return b.createdAt.compareTo(a.createdAt);
            });

          // Apply client-side filter
          final filtered = sorted.where((t) {
            switch (_currentFilter) {
              case HistoryFilter.all:
                return true;
              case HistoryFilter.baki:
                return t.isBaki;
              case HistoryFilter.payment:
                return t.isPayment;
            }
          }).toList();

          return Column(
            children: [
              // Top Filter Chips Bar
              _buildFilterChips(
                totalCount: transactions.length,
                bakiCount: bakiCount,
                paymentCount: paymentCount,
              ),

              // Transaction List or Empty States
              Expanded(
                child: filtered.isEmpty
                    ? _buildEmptyState(
                        isGlobalEmpty: transactions.isEmpty,
                        filter: _currentFilter,
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(top: 4, bottom: 80),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final tx = filtered[index];
                          final customer = customerMap[tx.customerId];
                          return _buildTransactionCard(
                            context: context,
                            tx: tx,
                            customer: customer,
                            currency: currency,
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterChips({
    required int totalCount,
    required int bakiCount,
    required int paymentCount,
  }) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          _buildChip(
            label: 'All ($totalCount)',
            filter: HistoryFilter.all,
            activeColor: AppColors.primary,
          ),
          const SizedBox(width: 8),
          _buildChip(
            label: 'Baki ($bakiCount)',
            filter: HistoryFilter.baki,
            activeColor: AppColors.debtText,
          ),
          const SizedBox(width: 8),
          _buildChip(
            label: 'Payment ($paymentCount)',
            filter: HistoryFilter.payment,
            activeColor: AppColors.paymentText,
          ),
        ],
      ),
    );
  }

  Widget _buildChip({
    required String label,
    required HistoryFilter filter,
    required Color activeColor,
  }) {
    final isSelected = _currentFilter == filter;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _currentFilter = filter);
        }
      },
      showCheckmark: false,
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        color: isSelected ? Colors.white : const Color(0xFF60706B),
      ),
      selectedColor: activeColor,
      backgroundColor: const Color(0xFFF1F5F3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? activeColor : const Color(0xFFE0E5E2),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    );
  }

  Widget _buildTransactionCard({
    required BuildContext context,
    required AppTransaction tx,
    required Customer? customer,
    required String currency,
  }) {
    final moneyFormat = NumberFormat('#,##0.00');
    final isBaki = tx.isBaki;
    final color = isBaki ? AppColors.debtText : AppColors.paymentText;
    final bgColor = isBaki ? AppColors.debtBg : AppColors.paymentBg;
    final sign = isBaki ? '+ ' : '- ';
    final customerName = customer?.name ?? 'Unknown Customer';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE0E5E2)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Type Icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isBaki
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                color: color,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),

            // Customer name, date & description
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    customerName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFF1E2925),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        DateFormat.yMMMd().format(tx.date.toLocal()),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF78909C),
                        ),
                      ),
                      if (tx.description != null &&
                          tx.description!.trim().isNotEmpty) ...[
                        const Text(
                          ' • ',
                          style: TextStyle(
                            color: Color(0xFFB0BEC5),
                            fontSize: 12,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            tx.description!.trim(),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF60706B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Amount number
            Text(
              '$sign$currency ${moneyFormat.format(tx.amount)}',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),

            const SizedBox(width: 4),

            // Dedicated Edit Icon
            IconButton(
              icon: const Icon(
                Icons.edit_outlined,
                color: Color(0xFF78909C),
                size: 20,
              ),
              tooltip: 'Edit Transaction',
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.all(6),
              constraints: const BoxConstraints(),
              onPressed: () {
                showTransactionDialog(
                  context,
                  ref,
                  existingTransaction: tx,
                );
              },
            ),

            const SizedBox(width: 2),

            // Delete Icon with confirmation dialog
            IconButton(
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: Color(0xFFB0BEC5),
                size: 20,
              ),
              tooltip: 'Delete Transaction',
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.all(6),
              constraints: const BoxConstraints(),
              onPressed: () => _confirmDeleteTransaction(
                tx,
                customerName,
                currency,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required bool isGlobalEmpty,
    required HistoryFilter filter,
  }) {
    if (isGlobalEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F5E9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.receipt_long_outlined,
                  size: 36,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'No Transactions Yet',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Color(0xFF1E2925),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'When you add baki or record payments, they will appear here in reverse chronological order.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF78909C),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Empty for selected filter
    final filterLabel = filter == HistoryFilter.baki ? 'Baki' : 'Payment';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.filter_list_off_rounded,
              size: 44,
              color: Color(0xFFB0BEC5),
            ),
            const SizedBox(height: 12),
            Text(
              'No $filterLabel Transactions',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Color(0xFF1E2925),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'There are no $filterLabel records matching the current filter.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF78909C),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteTransaction(
    AppTransaction tx,
    String customerName,
    String currency,
  ) async {
    final moneyFormat = NumberFormat('#,##0.00');
    final isBaki = tx.isBaki;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Transaction?'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        content: Text(
          'Are you sure you want to delete this ${isBaki ? "baki" : "payment"} of $currency ${moneyFormat.format(tx.amount)} for $customerName?',
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
                    'Delete',
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
      await ref.read(transactionRepositoryProvider).deleteTransaction(tx.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaction deleted')),
        );
      }
    }
  }
}

