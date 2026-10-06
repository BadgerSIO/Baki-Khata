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
          final l10n = AppLocalizations.of(context);

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

          // Group chronologically by date
          final List<_HistoryListItem> items = [];
          final Map<String, List<AppTransaction>> groups = {};
          for (final tx in filtered) {
            final header = _getDateHeader(tx.date, l10n);
            groups.putIfAbsent(header, () => []).add(tx);
          }

          for (final entry in groups.entries) {
            items.add(_DateHeaderItem(entry.key, entry.value.length));
            for (final tx in entry.value) {
              items.add(_TransactionItem(tx));
            }
          }

          return Column(
            children: [
              // Top Filter Chips Bar
              _buildFilterChips(
                totalCount: transactions.length,
                bakiCount: bakiCount,
                paymentCount: paymentCount,
                l10n: l10n,
              ),

              // Transaction List or Empty States
              Expanded(
                child: filtered.isEmpty
                    ? _buildEmptyState(
                        isGlobalEmpty: transactions.isEmpty,
                        filter: _currentFilter,
                        l10n: l10n,
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(top: 4, bottom: 80),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          if (item is _DateHeaderItem) {
                            return _buildDateHeader(item.title, item.count);
                          } else if (item is _TransactionItem) {
                            final tx = item.tx;
                            final customer = customerMap[tx.customerId];
                            return _buildTransactionCard(
                              context: context,
                              tx: tx,
                              customer: customer,
                              currency: currency,
                              l10n: l10n,
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _getDateHeader(DateTime date, AppLocalizations? l10n) {
    final now = DateTime.now();
    final local = date.toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final txDay = DateTime(local.year, local.month, local.day);
    final difference = today.difference(txDay).inDays;

    if (difference == 0) {
      return l10n?.today ?? 'Today';
    } else if (difference == 1) {
      return l10n?.yesterday ?? 'Yesterday';
    } else if (local.year == now.year) {
      return DateFormat('MMMM d').format(local);
    } else {
      return DateFormat('MMMM d, yyyy').format(local);
    }
  }

  Widget _buildDateHeader(String title, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Row(
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: Color(0xFF60706B),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8E5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF42524D),
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Divider(
              color: Color(0xFFE0E5E2),
              thickness: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips({
    required int totalCount,
    required int bakiCount,
    required int paymentCount,
    required AppLocalizations? l10n,
  }) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          _buildChip(
            label: l10n?.historyFilterAll(totalCount) ?? 'All ($totalCount)',
            filter: HistoryFilter.all,
            activeColor: AppColors.primary,
          ),
          const SizedBox(width: 8),
          _buildChip(
            label: l10n?.historyFilterCredit(bakiCount) ?? 'Credit ($bakiCount)',
            filter: HistoryFilter.baki,
            activeColor: AppColors.debtText,
          ),
          const SizedBox(width: 8),
          _buildChip(
            label: l10n?.historyFilterPayment(paymentCount) ?? 'Payment ($paymentCount)',
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

  String _formatCleanDescription(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    var text = raw.trim();
    if (text.contains('[ITEMS]') && text.contains('[/ITEMS]')) {
      final startIndex = text.indexOf('[ITEMS]');
      final endIndex = text.indexOf('[/ITEMS]');
      final itemsBlock = text.substring(startIndex + 7, endIndex).trim();
      final outsideText = (text.substring(0, startIndex) + text.substring(endIndex + 8)).trim();

      final lines = itemsBlock.split('\n').where((l) => l.trim().isNotEmpty).toList();
      final names = <String>[];
      for (final line in lines) {
        final parts = line.split('|');
        if (parts.isNotEmpty && parts[0].trim().isNotEmpty) {
          names.add(parts[0].trim());
        }
      }

      final itemsSummary = names.isNotEmpty ? names.join(', ') : '';
      if (outsideText.isNotEmpty && itemsSummary.isNotEmpty) {
        return '$outsideText ($itemsSummary)';
      } else if (itemsSummary.isNotEmpty) {
        return itemsSummary;
      } else if (outsideText.isNotEmpty) {
        return outsideText;
      }
    }
    return text;
  }

  Widget _buildTransactionCard({
    required BuildContext context,
    required AppTransaction tx,
    required Customer? customer,
    required String currency,
    required AppLocalizations? l10n,
  }) {
    final moneyFormat = NumberFormat('#,##0.00');
    final isBaki = tx.isBaki;
    final color = isBaki ? AppColors.debtText : AppColors.paymentText;
    final bgColor = isBaki ? AppColors.debtBg : AppColors.paymentBg;
    final sign = isBaki ? '+ ' : '- ';
    final customerName = customer?.name ?? (l10n?.customerName ?? 'Customer');
    final cleanDescription = _formatCleanDescription(tx.description);

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
            // Type Icon (Vertically centered)
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

            // Main Details Column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Row 1: Customer Name and Amount
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          customerName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Color(0xFF1E2925),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$sign$currency ${moneyFormat.format(tx.amount)}',
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Row 2: Date, Description, and Action Buttons
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        DateFormat.yMMMd().format(tx.date.toLocal()),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF78909C),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (cleanDescription.isNotEmpty) ...[
                        const Text(
                          ' • ',
                          style: TextStyle(
                            color: Color(0xFFB0BEC5),
                            fontSize: 12,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            cleanDescription,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF60706B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ] else ...[
                        const Spacer(),
                      ],
                      const SizedBox(width: 8),

                      // Action Buttons
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            onTap: () => launchVoucherForTransaction(context, ref, tx, forceShow: true),
                            borderRadius: BorderRadius.circular(6),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              child: Icon(
                                Icons.receipt_long_rounded,
                                color: AppColors.primary,
                                size: 18,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: () => showTransactionDialog(
                              context,
                              ref,
                              existingTransaction: tx,
                            ),
                            borderRadius: BorderRadius.circular(6),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              child: Icon(
                                Icons.edit_outlined,
                                color: Color(0xFF78909C),
                                size: 18,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: () => _confirmDeleteTransaction(
                              tx,
                              customerName,
                              currency,
                              l10n,
                            ),
                            borderRadius: BorderRadius.circular(6),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              child: Icon(
                                Icons.delete_outline_rounded,
                                color: Color(0xFFB0BEC5),
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
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
    required AppLocalizations? l10n,
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
              Text(
                l10n?.noTransactionsYet ?? 'No Transactions Yet',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Color(0xFF1E2925),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                l10n?.noHistoryHint ??
                    'When you give credit or record payments, they will appear here in reverse chronological order.',
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

    // Empty for selected filter
    final filterLabel = filter == HistoryFilter.baki
        ? (l10n?.credit ?? 'Credit')
        : (l10n?.payment ?? 'Payment');
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
    AppLocalizations? l10n,
  ) async {
    final moneyFormat = NumberFormat('#,##0.00');
    final isBaki = tx.isBaki;
    final typeLabel = isBaki ? (l10n?.credit ?? 'Credit') : (l10n?.payment ?? 'Payment');
    final formattedAmount = '$currency ${moneyFormat.format(tx.amount)}';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n?.deleteTransactionTitle ?? 'Delete Transaction?'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        content: Text(
          l10n?.deleteHistoryConfirm(typeLabel, formattedAmount, customerName) ??
              'Are you sure you want to delete this $typeLabel of $formattedAmount for $customerName?',
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
                    l10n?.delete ?? 'Delete',
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
      await ref.read(transactionRepositoryProvider).deleteTransaction(tx.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaction deleted')),
        );
      }
    }
  }
}

sealed class _HistoryListItem {}

class _DateHeaderItem extends _HistoryListItem {
  final String title;
  final int count;

  _DateHeaderItem(this.title, this.count);
}

class _TransactionItem extends _HistoryListItem {
  final AppTransaction tx;

  _TransactionItem(this.tx);
}

