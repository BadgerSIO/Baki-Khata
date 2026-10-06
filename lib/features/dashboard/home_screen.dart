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
import '../../l10n/generated/app_localizations.dart';
import '../customers/customer_details_screen.dart';
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
    final sortedRecent = [...transactions]..sort((a, b) {
        final cmp = b.date.compareTo(a.date);
        if (cmp != 0) return cmp;
        return b.createdAt.compareTo(a.createdAt);
      });
    final recentTransactions = sortedRecent.take(5).toList();

    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

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
            // 1. Unified Hero Ledger Card (Clear, focused, no clutter)
            _HeroLedgerCard(
              totalOutstanding: formatMoney(totalOutstanding),
              totalCustomers: '${customers.length}',
              newBakiToday: formatMoney(newBakiToday),
              collectedToday: formatMoney(collectedToday),
              totalCollectedAllTime: formatMoney(totalCollectedAllTime),
              onTotalDueTap: () {
                ref.read(currentTabProvider.notifier).state = 2; // History Tab
              },
              onCustomersTap: () {
                ref.read(currentTabProvider.notifier).state = 1; // Customers Tab
              },
              onHistoryTap: () {
                ref.read(currentTabProvider.notifier).state = 2; // History Tab
              },
            ),
            const SizedBox(height: 16),

            // 2. High-Contrast Tactile Action Buttons
            _PrimaryActionButtons(
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
                  l10n?.recentTransactions ?? 'Recent Transactions',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    ref.read(currentTabProvider.notifier).state = 2; // History Tab
                  },
                  child: Text(l10n?.viewAll ?? 'View all'),
                ),
              ],
            ),
            const SizedBox(height: 8),

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
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CustomerDetailsScreen(customerId: tx.customerId),
                      ),
                    );
                  },
                );
              }),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _HeroLedgerCard extends StatelessWidget {
  final String totalOutstanding;
  final String totalCustomers;
  final String newBakiToday;
  final String collectedToday;
  final String totalCollectedAllTime;
  final VoidCallback onTotalDueTap;
  final VoidCallback onCustomersTap;
  final VoidCallback onHistoryTap;

  const _HeroLedgerCard({
    required this.totalOutstanding,
    required this.totalCustomers,
    required this.newBakiToday,
    required this.collectedToday,
    required this.totalCollectedAllTime,
    required this.onTotalDueTap,
    required this.onCustomersTap,
    required this.onHistoryTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE0E5E2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // 1. Primary Due Metric (Tappable to History)
          InkWell(
            onTap: onTotalDueTap,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.debtBg,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.account_balance_wallet_outlined,
                              size: 18,
                              color: AppColors.debtText,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            l10n?.totalDue ?? 'Total Due',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF546E7A),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: Color(0xFF90A4AE),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    totalOutstanding,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppColors.debtText,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Divider
          const Divider(height: 1, thickness: 1, color: Color(0xFFF0F4F2)),

          // 2. Today's Activity (New Credit & Collected)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAF9),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  // New Credit Today
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                            color: AppColors.debtBg,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_upward_rounded,
                            size: 18,
                            color: AppColors.debtText,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n?.newCreditToday ?? 'New Credit Today',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF546E7A),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                newBakiToday,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.debtText,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 36,
                    color: const Color(0xFFE0E5E2),
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  // Collected Today
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                            color: AppColors.paymentBg,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_downward_rounded,
                            size: 18,
                            color: AppColors.paymentText,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n?.collectedToday ?? 'Collected Today',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF546E7A),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                collectedToday,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.paymentText,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Compact Secondary Bar: Customers & All-Time Collections
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Row(
              children: [
                // Total Customers pill
                Expanded(
                  child: InkWell(
                    onTap: onCustomersTap,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAF9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: AppColors.primaryContainer.withValues(alpha: 0.7),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.people_alt_outlined,
                              size: 14,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  l10n?.totalCustomers ?? 'Total Customers',
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF546E7A),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  totalCustomers,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF191C1B),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Total Collected All-Time pill
                Expanded(
                  child: InkWell(
                    onTap: onHistoryTap,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAF9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: AppColors.paymentBg,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.payments_outlined,
                              size: 14,
                              color: AppColors.paymentText,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  l10n?.totalCollectedAllTime ?? 'Total Collected All-Time',
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF78909C),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  totalCollectedAllTime,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.paymentText,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryActionButtons extends StatelessWidget {
  final VoidCallback onAddCustomer;
  final VoidCallback onAddBaki;
  final VoidCallback onRecordPayment;

  const _PrimaryActionButtons({
    required this.onAddCustomer,
    required this.onAddBaki,
    required this.onRecordPayment,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      children: [
        Row(
          children: [
            // Left Big Button: Give Credit (Red)
            Expanded(
              child: _BigLedgerActionButton(
                title: l10n?.giveCredit ?? 'Give Credit',
                subtitle: l10n?.giveCreditSubtitle ?? 'Gave on credit',
                icon: Icons.add_circle_outline_rounded,
                iconColor: AppColors.debtText,
                textColor: AppColors.debtText,
                bgColor: AppColors.debtBg,
                borderColor: AppColors.debtText.withValues(alpha: 0.3),
                onTap: onAddBaki,
              ),
            ),
            const SizedBox(width: 12),
            // Right Big Button: Record Payment (Green)
            Expanded(
              child: _BigLedgerActionButton(
                title: l10n?.recordPayment ?? 'Record Payment',
                subtitle: l10n?.recordPaymentSubtitle ?? 'Received cash',
                icon: Icons.check_circle_outline_rounded,
                iconColor: AppColors.paymentText,
                textColor: AppColors.paymentText,
                bgColor: AppColors.paymentBg,
                borderColor: AppColors.paymentText.withValues(alpha: 0.3),
                onTap: onRecordPayment,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Secondary Full-Width Pill: Add Customer
        Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFCFD8DC), width: 1),
          ),
          child: InkWell(
            onTap: onAddCustomer,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.person_add_alt_1_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n?.addCustomer ?? 'Add Customer',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BigLedgerActionButton extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Color textColor;
  final Color bgColor;
  final Color borderColor;
  final VoidCallback onTap;

  const _BigLedgerActionButton({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.textColor,
    required this.bgColor,
    required this.borderColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor, width: 1.5),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: iconColor, size: 20),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  color: textColor.withValues(alpha: 0.8),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
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
  final VoidCallback onTap;

  const _RecentTransactionTile({
    required this.transaction,
    required this.customerName,
    required this.currencySymbol,
    required this.moneyFormat,
    required this.onTap,
  });

  String _formatRelativeDate(BuildContext context, DateTime dt) {
    final now = DateTime.now();
    final local = dt.toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final txDate = DateTime(local.year, local.month, local.day);
    final dayDiff = today.difference(txDate).inDays;
    final l10n = AppLocalizations.of(context);
    final localeName = Localizations.localeOf(context).toString();

    final timeStr = DateFormat.jm(localeName).format(local);

    if (dayDiff == 0) {
      final label = l10n?.relativeToday ?? 'Today';
      return '$label, $timeStr';
    } else if (dayDiff == 1) {
      final label = l10n?.relativeYesterday ?? 'Yesterday';
      return '$label, $timeStr';
    } else if (dayDiff > 1 && dayDiff < 7) {
      return l10n?.daysAgo(dayDiff) ?? '$dayDiff days ago';
    } else {
      return DateFormat.yMMMd(localeName).format(local);
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
        onTap: onTap,
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
              _formatRelativeDate(context, transaction.date),
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
            Text(
              AppLocalizations.of(context)?.noTransactionsYet ?? 'No Transactions Yet',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              AppLocalizations.of(context)?.noTransactionsDescription ??
                  'Record customer credit or received payments to see recent activity here.',
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
}
