import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../app.dart';
import '../../core/theme.dart';
import '../../data/models/app_settings.dart';
import '../../data/models/transaction.dart';
import '../../data/repositories/customer_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../shared/quick_action_dialogs.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customersAsync = ref.watch(customersStreamProvider);
    final transactionsAsync = ref.watch(transactionsStreamProvider);
    final settingsAsync = ref.watch(settingsStreamProvider);

    final customers = customersAsync.value ?? [];
    final transactions = transactionsAsync.value ?? [];
    final settings = settingsAsync.value ??
        AppSettings(
          userId: '',
          shopName: 'My Shop',
          currencySymbol: '৳',
          updatedAt: DateTime.now(),
        );

    final currency = settings.currencySymbol;
    final moneyFormat = NumberFormat('#,##0.00');
    String formatMoney(double amount) => '$currency ${moneyFormat.format(amount)}';

    // 1. Calculate Balances & Total Outstanding
    final Map<String, double> customerBalances = {};
    for (final t in transactions) {
      final current = customerBalances[t.customerId] ?? 0.0;
      if (t.isBaki) {
        customerBalances[t.customerId] = current + t.amount;
      } else if (t.isPayment) {
        customerBalances[t.customerId] = current - t.amount;
      }
    }

    double totalOutstanding = 0.0;
    for (final balance in customerBalances.values) {
      if (balance > 0) {
        totalOutstanding += balance;
      }
    }

    // 2. Calculate Today's Stats & All-Time Collections
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    bool isToday(DateTime dt) {
      final local = dt.toLocal();
      return !local.isBefore(todayStart) && local.isBefore(todayEnd);
    }

    double newBakiToday = 0.0;
    double collectedToday = 0.0;
    double totalCollectedAllTime = 0.0;

    for (final t in transactions) {
      if (t.isBaki) {
        if (isToday(t.date)) {
          newBakiToday += t.amount;
        }
      } else if (t.isPayment) {
        totalCollectedAllTime += t.amount;
        if (isToday(t.date)) {
          collectedToday += t.amount;
        }
      }
    }

    // Customer Lookup Map
    final customerNameMap = {for (final c in customers) c.id: c.name};

    // 5 Most Recent Transactions
    final recentTransactions = transactions.take(5).toList();

    final theme = Theme.of(context);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(customerRepositoryProvider).refresh();
          await ref.read(transactionRepositoryProvider).refresh();
          await ref.read(settingsRepositoryProvider).refresh();
        },
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          children: [
            // 1. Overview Stat Cards (5 Cards)
            _buildStatCards(
              context: context,
              ref: ref,
              totalOutstanding: formatMoney(totalOutstanding),
              totalCustomers: '${customers.length}',
              newBakiToday: formatMoney(newBakiToday),
              collectedToday: formatMoney(collectedToday),
              totalCollectedAllTime: formatMoney(totalCollectedAllTime),
            ),
            const SizedBox(height: 16),

            // 2. Quick Actions Row
            _QuickActionsRow(
              onAddCustomer: () => showAddCustomerDialog(context, ref),
              onAddBaki: () => showAddBakiDialog(context, ref),
              onRecordPayment: () => showRecordPaymentDialog(context, ref),
            ),
            const SizedBox(height: 20),

            // 3. Recent Transactions Header & List
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Transactions',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    ref.read(currentTabProvider.notifier).state = 2; // History Tab
                  },
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 6),

            if (recentTransactions.isEmpty)
              _EmptyRecentTransactions(
                onAddBaki: () => showAddBakiDialog(context, ref),
                onRecordPayment: () => showRecordPaymentDialog(context, ref),
              )
            else
              ...recentTransactions.map((tx) {
                final customerName =
                    customerNameMap[tx.customerId] ?? 'Unknown Customer';
                return _RecentTransactionTile(
                  transaction: tx,
                  customerName: customerName,
                  currencySymbol: currency,
                  moneyFormat: moneyFormat,
                );
              }),
            const SizedBox(height: 80), // Extra space so bottom-most items clear FAB
          ],
        ),
      ),
    );
  }

  Widget _buildStatCards({
    required BuildContext context,
    required WidgetRef ref,
    required String totalOutstanding,
    required String totalCustomers,
    required String newBakiToday,
    required String collectedToday,
    required String totalCollectedAllTime,
  }) {
    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _StatCard(
                  title: 'Total Outstanding',
                  value: totalOutstanding,
                  icon: Icons.account_balance_wallet_outlined,
                  iconColor: AppColors.debtText,
                  iconBgColor: AppColors.debtBg,
                  valueColor: AppColors.debtText,
                  onTap: () {
                    ref.read(currentTabProvider.notifier).state = 2; // History
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  title: 'Total Customers',
                  value: totalCustomers,
                  icon: Icons.people_outline,
                  iconColor: AppColors.primary,
                  iconBgColor: AppColors.primaryContainer,
                  onTap: () {
                    ref.read(currentTabProvider.notifier).state = 1; // Customers
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _StatCard(
                  title: 'New Baki Today',
                  value: newBakiToday,
                  icon: Icons.arrow_upward_rounded,
                  iconColor: AppColors.debtText,
                  iconBgColor: AppColors.debtBg,
                  valueColor: AppColors.debtText,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  title: 'Collected Today',
                  value: collectedToday,
                  icon: Icons.arrow_downward_rounded,
                  iconColor: AppColors.paymentText,
                  iconBgColor: AppColors.paymentBg,
                  valueColor: AppColors.paymentText,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _StatCard(
          title: 'Total Collected All-Time',
          value: totalCollectedAllTime,
          icon: Icons.payments_outlined,
          iconColor: AppColors.paymentText,
          iconBgColor: AppColors.paymentBg,
          valueColor: AppColors.paymentText,
          onTap: () {
            ref.read(currentTabProvider.notifier).state = 2; // History
          },
        ),
      ],
    );
  }
}


class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final Color? valueColor;
  final VoidCallback? onTap;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    this.valueColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE0E5E2)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: iconBgColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 20, color: iconColor),
                  ),
                  if (onTap != null)
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: Color(0xFF90A4AE),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF546E7A),
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: valueColor ?? theme.textTheme.headlineMedium?.color,
                  letterSpacing: -0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionsRow extends StatelessWidget {
  final VoidCallback onAddCustomer;
  final VoidCallback onAddBaki;
  final VoidCallback onRecordPayment;

  const _QuickActionsRow({
    required this.onAddCustomer,
    required this.onAddBaki,
    required this.onRecordPayment,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickActionButton(
            label: 'Add Customer',
            icon: Icons.person_add_alt_1_outlined,
            color: AppColors.primary,
            bgColor: AppColors.primaryContainer.withValues(alpha: 0.5),
            onTap: onAddCustomer,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _QuickActionButton(
            label: 'Add Baki',
            icon: Icons.arrow_upward_rounded,
            color: AppColors.debtText,
            bgColor: AppColors.debtBg,
            onTap: onAddBaki,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _QuickActionButton(
            label: 'Record Payment',
            icon: Icons.arrow_downward_rounded,
            color: AppColors.paymentText,
            bgColor: AppColors.paymentBg,
            onTap: onRecordPayment,
          ),
        ),
      ],
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentTransactionTile extends StatelessWidget {
  final AppTransaction transaction;
  final String customerName;
  final String currencySymbol;
  final NumberFormat moneyFormat;

  const _RecentTransactionTile({
    required this.transaction,
    required this.customerName,
    required this.currencySymbol,
    required this.moneyFormat,
  });

  String _formatRelativeDate(DateTime dt) {
    final now = DateTime.now();
    final local = dt.toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final txDate = DateTime(local.year, local.month, local.day);
    final dayDiff = today.difference(txDate).inDays;

    if (dayDiff == 0) {
      return 'Today, ${DateFormat.jm().format(local)}';
    } else if (dayDiff == 1) {
      return 'Yesterday, ${DateFormat.jm().format(local)}';
    } else if (dayDiff > 1 && dayDiff < 7) {
      return '$dayDiff days ago';
    } else {
      return DateFormat.yMMMd().format(local);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBaki = transaction.isBaki;
    final color = isBaki ? AppColors.debtText : AppColors.paymentText;
    final bgColor = isBaki ? AppColors.debtBg : AppColors.paymentBg;
    final sign = isBaki ? '+ ' : '- ';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE0E5E2)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
          ),
          child: Icon(
            isBaki ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
            color: color,
            size: 20,
          ),
        ),
        title: Text(
          customerName,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        subtitle: Row(
          children: [
            Text(
              _formatRelativeDate(transaction.date),
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF78909C),
              ),
            ),
            if (transaction.description != null &&
                transaction.description!.isNotEmpty) ...[
              const Text(' • ', style: TextStyle(color: Color(0xFFB0BEC5))),
              Expanded(
                child: Text(
                  transaction.description!,
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
        trailing: Text(
          '$sign$currencySymbol ${moneyFormat.format(transaction.amount)}',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}

class _EmptyRecentTransactions extends StatelessWidget {
  final VoidCallback onAddBaki;
  final VoidCallback onRecordPayment;

  const _EmptyRecentTransactions({
    required this.onAddBaki,
    required this.onRecordPayment,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE0E5E2)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.receipt_long_outlined,
                size: 28,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'No Transactions Yet',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Record customer credit (baki) or received payments to see recent activity here.',
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
}
