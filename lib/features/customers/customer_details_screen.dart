import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme.dart';
import '../../data/models/customer.dart';
import '../../data/models/transaction.dart';
import '../../data/repositories/customer_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../shared/quick_action_dialogs.dart';

class CustomerDetailsScreen extends ConsumerWidget {
  final String customerId;

  const CustomerDetailsScreen({
    super.key,
    required this.customerId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customersAsync = ref.watch(customersStreamProvider);
    final transactionsAsync =
        ref.watch(customerTransactionsStreamProvider(customerId));
    final settings = ref.watch(settingsStreamProvider).value;
    final currency = settings?.currencySymbol ?? '৳';
    final theme = Theme.of(context);

    return customersAsync.when(
      data: (customers) {
        final customer =
            customers.where((c) => c.id == customerId).firstOrNull;

        if (customer == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Customer Details')),
            body: const Center(
              child: Text(
                'Customer not found or has been deleted.',
                style: TextStyle(fontSize: 16, color: Color(0xFF78909C)),
              ),
            ),
          );
        }

        final transactions = transactionsAsync.value ?? [];
        final sortedTransactions = List<AppTransaction>.from(transactions)
          ..sort((a, b) => b.date.compareTo(a.date));

        // Compute net balance: sum(baki) - sum(payment)
        double balance = 0.0;
        for (final t in transactions) {
          if (t.isBaki) {
            balance += t.amount;
          } else if (t.isPayment) {
            balance -= t.amount;
          }
        }

        final badgeFormat = (balance.abs() % 1 == 0)
            ? NumberFormat('#,##0')
            : NumberFormat('#,##0.00');

        final Color balanceTextColor;
        final Color balanceBgColor;
        final String balanceStatusLabel;
        final String balanceText;

        if (balance > 0) {
          balanceTextColor = AppColors.debtText;
          balanceBgColor = AppColors.debtBg;
          balanceStatusLabel = 'Due';
          balanceText = 'Due $currency${badgeFormat.format(balance)}';
        } else if (balance < 0) {
          balanceTextColor = AppColors.advanceText;
          balanceBgColor = AppColors.advanceBg;
          balanceStatusLabel = 'Advance';
          balanceText = 'Advance $currency${badgeFormat.format(balance.abs())}';
        } else {
          balanceTextColor = AppColors.settledText;
          balanceBgColor = AppColors.settledBg;
          balanceStatusLabel = 'Settled';
          balanceText = 'Settled';
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(customer.name),
            actions: [
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (val) {
                  if (val == 'edit') {
                    showEditCustomerDialog(context, ref, customer);
                  } else if (val == 'delete') {
                    _confirmDeleteCustomer(
                      context,
                      ref,
                      customer,
                      balance,
                      currency,
                    );
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 20),
                        SizedBox(width: 10),
                        Text('Edit Customer'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_outline,
                          size: 20,
                          color: AppColors.debtText,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Delete Customer',
                          style: TextStyle(color: AppColors.debtText),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              await ref.read(customerRepositoryProvider).refresh();
              await ref.read(transactionRepositoryProvider).refresh();
            },
            child: ListView(
              padding: const EdgeInsets.only(bottom: 40),
              children: [
                // 1. Header Card
                _buildHeaderCard(context, ref, customer, theme),

                // 2. Balance Summary Card
                _buildBalanceSummaryCard(
                  balanceStatusLabel: balanceStatusLabel,
                  balanceText: balanceText,
                  balanceTextColor: balanceTextColor,
                  balanceBgColor: balanceBgColor,
                ),

                // 3. Action Buttons: Add Baki & Record Payment
                _buildActionButtons(context, ref, customer),

                // 4. Transaction History Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Transaction History',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${sortedTransactions.length} records',
                        style: const TextStyle(
                          color: Color(0xFF78909C),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                // 5. Transaction History List
                if (sortedTransactions.isEmpty)
                  _buildEmptyTransactionsCard()
                else
                  ...sortedTransactions.map((tx) {
                    return _buildTransactionCard(
                      context,
                      ref,
                      tx,
                      currency,
                    );
                  }),
              ],
            ),
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => Scaffold(
        appBar: AppBar(title: const Text('Customer Details')),
        body: Center(
          child: Text('Error loading customer details: $error'),
        ),
      ),
    );
  }

  Widget _buildHeaderCard(
    BuildContext context,
    WidgetRef ref,
    Customer customer,
    ThemeData theme,
  ) {
    final initial = customer.name.trim().isNotEmpty
        ? customer.name.trim()[0].toUpperCase()
        : '?';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE0E5E2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor:
                      AppColors.primaryContainer.withValues(alpha: 0.6),
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customer.name,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                      if (customer.address != null &&
                          customer.address!.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 15,
                              color: Color(0xFF78909C),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                customer.address!.trim(),
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF60706B),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
                  tooltip: 'Edit Customer',
                  onPressed: () =>
                      showEditCustomerDialog(context, ref, customer),
                ),
              ],
            ),
            if (customer.phone != null &&
                customer.phone!.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 6),
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () async {
                  final phoneDigits =
                      customer.phone!.replaceAll(RegExp(r'\s+'), '');
                  final phoneUri = Uri(scheme: 'tel', path: phoneDigits);
                  if (await canLaunchUrl(phoneUri)) {
                    await launchUrl(phoneUri);
                  } else if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Could not open dialer for ${customer.phone}',
                        ),
                      ),
                    );
                  }
                },
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color:
                              AppColors.primaryContainer.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.phone_rounded,
                          size: 16,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        customer.phone!.trim(),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                      const Spacer(),
                      const Text(
                        'Call',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF78909C),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: Color(0xFF78909C),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceSummaryCard({
    required String balanceStatusLabel,
    required String balanceText,
    required Color balanceTextColor,
    required Color balanceBgColor,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE0E5E2)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Current Balance',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF546E7A),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: balanceBgColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    balanceStatusLabel,
                    style: TextStyle(
                      color: balanceTextColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              balanceText,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: balanceTextColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    WidgetRef ref,
    Customer customer,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.debtText,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => showAddTransactionDialog(
                context,
                ref,
                type: TransactionType.baki,
                preselectedCustomerId: customer.id,
              ),
              icon: const Icon(Icons.arrow_upward_rounded, size: 20),
              label: const Text(
                'Add Baki',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.paymentText,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => showAddTransactionDialog(
                context,
                ref,
                type: TransactionType.payment,
                preselectedCustomerId: customer.id,
              ),
              icon: const Icon(Icons.arrow_downward_rounded, size: 20),
              label: const Text(
                'Record Payment',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(
    BuildContext context,
    WidgetRef ref,
    AppTransaction tx,
    String currency,
  ) {
    final moneyFormat = NumberFormat('#,##0.00');
    final isBaki = tx.isBaki;
    final color = isBaki ? AppColors.debtText : AppColors.paymentText;
    final bgColor = isBaki ? AppColors.debtBg : AppColors.paymentBg;
    final sign = isBaki ? '+ ' : '- ';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE0E5E2)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        isBaki ? 'Baki (Due)' : 'Payment',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const Spacer(),
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
                  const SizedBox(height: 3),
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
            const SizedBox(width: 6),
            IconButton(
              icon: const Icon(
                Icons.delete_outline,
                color: Color(0xFFB0BEC5),
                size: 20,
              ),
              tooltip: 'Delete Transaction',
              onPressed: () =>
                  _confirmDeleteTransaction(context, ref, tx, currency),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyTransactionsCard() {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE0E5E2)),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 32),
        child: Column(
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 40,
              color: Color(0xFFB0BEC5),
            ),
            SizedBox(height: 12),
            Text(
              'No Transactions Yet',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Use Add Baki or Record Payment above to add the first transaction for this customer.',
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

  Future<void> _confirmDeleteTransaction(
    BuildContext context,
    WidgetRef ref,
    AppTransaction tx,
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
          'Are you sure you want to delete this ${isBaki ? "baki" : "payment"} of $currency${moneyFormat.format(tx.amount)}?',
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
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaction deleted')),
        );
      }
    }
  }

  Future<void> _confirmDeleteCustomer(
    BuildContext context,
    WidgetRef ref,
    Customer customer,
    double balance,
    String currency,
  ) async {
    final badgeFormat = (balance.abs() % 1 == 0)
        ? NumberFormat('#,##0')
        : NumberFormat('#,##0.00');

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Customer?'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete ${customer.name}? All associated transaction records will also be permanently deleted.',
            ),
            if (balance != 0) ...[
              const SizedBox(height: 14),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.debtBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.debtText.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: AppColors.debtText,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        balance > 0
                            ? 'This customer has an outstanding balance of $currency${badgeFormat.format(balance)}'
                            : 'This customer has an advance balance of $currency${badgeFormat.format(balance.abs())}',
                        style: const TextStyle(
                          color: AppColors.debtText,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
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
                    'Delete Customer',
                    style: TextStyle(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(customerRepositoryProvider).deleteCustomer(customer.id);
      await ref.read(transactionRepositoryProvider).refresh();
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${customer.name} deleted')),
        );
      }
    }
  }
}

