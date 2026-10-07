import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../data/models/app_settings.dart';
import '../../data/models/customer.dart';
import '../../data/repositories/customer_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import '../shared/quick_action_dialogs.dart';
import '../statements/widgets/store_statement_export_sheet.dart';
import 'customer_details_screen.dart';

/// Provider computing net balance for each customer:
/// balance = sum(baki) - sum(payment)
final customerBalancesProvider = Provider<Map<String, double>>((ref) {
  final transactions = ref.watch(transactionsStreamProvider).value ?? [];
  final Map<String, double> balances = {};
  for (final t in transactions) {
    final current = balances[t.customerId] ?? 0.0;
    if (t.isBaki) {
      balances[t.customerId] = current + t.amount;
    } else if (t.isPayment) {
      balances[t.customerId] = current - t.amount;
    }
  }
  return balances;
});

enum CustomerFilter {
  all,
  due,
  advance,
  settled,
}

enum CustomerSort {
  nameAsc,
  highestDue,
  recentlyAdded,
}

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  late final TextEditingController _searchController;
  String _searchQuery = '';
  CustomerFilter _currentFilter = CustomerFilter.all;
  CustomerSort _currentSort = CustomerSort.nameAsc;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customersStreamProvider);
    final balances = ref.watch(customerBalancesProvider);
    final settings = ref.watch(settingsStreamProvider).value;
    final currency = settings?.currencySymbol ?? '৳';
    final theme = Theme.of(context);

    return Scaffold(
      body: customersAsync.when(
        data: (customers) {
          if (customers.isEmpty) {
            return _buildEmptyState(context, theme);
          }

          int dueCount = 0;
          int advanceCount = 0;
          int settledCount = 0;
          double totalDueAmount = 0.0;
          double totalAdvanceAmount = 0.0;

          for (final c in customers) {
            final bal = balances[c.id] ?? 0.0;
            if (bal > 0) {
              dueCount++;
              totalDueAmount += bal;
            } else if (bal < 0) {
              advanceCount++;
              totalAdvanceAmount += bal.abs();
            } else {
              settledCount++;
            }
          }

          final statusFiltered = customers.where((c) {
            final bal = balances[c.id] ?? 0.0;
            switch (_currentFilter) {
              case CustomerFilter.all:
                return true;
              case CustomerFilter.due:
                return bal > 0;
              case CustomerFilter.advance:
                return bal < 0;
              case CustomerFilter.settled:
                return bal == 0;
            }
          }).toList();

          final query = _searchQuery.trim().toLowerCase();
          final searchFiltered = query.isEmpty
              ? statusFiltered
              : statusFiltered.where((c) {
                  final nameMatch = c.name.toLowerCase().contains(query);
                  final phoneMatch =
                      c.phone?.toLowerCase().contains(query) ?? false;
                  final addressMatch =
                      c.address?.toLowerCase().contains(query) ?? false;
                  return nameMatch || phoneMatch || addressMatch;
                }).toList();

          final sortedCustomers = [...searchFiltered]..sort((a, b) {
              switch (_currentSort) {
                case CustomerSort.nameAsc:
                  return a.name.toLowerCase().compareTo(b.name.toLowerCase());
                case CustomerSort.highestDue:
                  final balA = balances[a.id] ?? 0.0;
                  final balB = balances[b.id] ?? 0.0;
                  final cmp = balB.compareTo(balA);
                  if (cmp != 0) return cmp;
                  return a.name.toLowerCase().compareTo(b.name.toLowerCase());
                case CustomerSort.recentlyAdded:
                  return b.createdAt.compareTo(a.createdAt);
              }
            });

          return Column(
            children: [
              _buildSearchAndSortBar(theme, customers, settings),
              _buildFilterChips(
                totalCount: customers.length,
                dueCount: dueCount,
                advanceCount: advanceCount,
                settledCount: settledCount,
              ),
              _buildSummaryBanner(
                filter: _currentFilter,
                count: statusFiltered.length,
                totalDue: totalDueAmount,
                totalAdvance: totalAdvanceAmount,
                currency: currency,
              ),
              Expanded(
                child: query.isNotEmpty && searchFiltered.isEmpty
                    ? _buildNoSearchResults(theme)
                    : query.isEmpty && statusFiltered.isEmpty
                        ? _buildNoFilterResults(theme, _currentFilter)
                        : RefreshIndicator(
                            onRefresh: () async {
                              await ref.read(customerRepositoryProvider).refresh();
                              await ref.read(transactionRepositoryProvider).refresh();
                            },
                            child: ListView.builder(
                              padding: const EdgeInsets.only(top: 4, bottom: 84),
                              itemCount: sortedCustomers.length,
                              itemBuilder: (context, index) {
                                final customer = sortedCustomers[index];
                                final balance = balances[customer.id] ?? 0.0;
                                return _CustomerCard(
                                  customer: customer,
                                  balance: balance,
                                  currency: currency,
                                );
                              },
                            ),
                          ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              'Error loading customers: $error',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchAndSortBar(ThemeData theme, List<Customer> customers, AppSettings? settings) {
    final l10n = AppLocalizations.of(context);
    final effectiveSettings = settings ??
        AppSettings(
          userId: '',
          shopName: 'My Shop',
          currencySymbol: '৳',
          updatedAt: DateTime.now(),
        );

    return Container(
      color: theme.scaffoldBackgroundColor,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
              decoration: InputDecoration(
                hintText: l10n?.searchCustomersHint ?? 'Search by name, phone, or address...',
                hintStyle: const TextStyle(
                  color: Color(0xFF8C9E97),
                  fontSize: 14,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: Color(0xFF60706B),
                  size: 22,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        color: const Color(0xFF60706B),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFEFF3F1),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _buildSortButton(theme),
          const SizedBox(width: 8),
          Container(
            height: 48,
            width: 48,
            decoration: const BoxDecoration(
              color: Color(0xFFEFF3F1),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(
                Icons.picture_as_pdf_outlined,
                color: AppColors.primary,
                size: 22,
              ),
              tooltip: 'Store Master Ledger PDF',
              onPressed: () {
                StoreStatementExportSheet.show(
                  context,
                  customers: customers,
                  settings: effectiveSettings,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortButton(ThemeData theme) {
    final l10n = AppLocalizations.of(context);
    return Container(
      height: 48,
      width: 48,
      decoration: const BoxDecoration(
        color: Color(0xFFEFF3F1),
        shape: BoxShape.circle,
      ),
      child: PopupMenuButton<CustomerSort>(
        icon: const Icon(
          Icons.sort_rounded,
          color: Color(0xFF60706B),
          size: 22,
        ),
        tooltip: l10n?.sortBy ?? 'Sort customers',
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        initialValue: _currentSort,
        onSelected: (sort) {
          setState(() => _currentSort = sort);
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: CustomerSort.nameAsc,
            child: Row(
              children: [
                const Icon(Icons.sort_by_alpha_rounded,
                    size: 20, color: Color(0xFF60706B)),
                const SizedBox(width: 12),
                Text(l10n?.sortName ?? 'Name (A–Z)'),
              ],
            ),
          ),
          PopupMenuItem(
            value: CustomerSort.highestDue,
            child: Row(
              children: [
                const Icon(Icons.trending_up_rounded,
                    size: 20, color: AppColors.debtText),
                const SizedBox(width: 12),
                Text(l10n?.sortHighestDue ?? 'Highest Due'),
              ],
            ),
          ),
          PopupMenuItem(
            value: CustomerSort.recentlyAdded,
            child: Row(
              children: [
                const Icon(Icons.access_time_rounded,
                    size: 20, color: Color(0xFF60706B)),
                const SizedBox(width: 12),
                Text(l10n?.sortMostRecent ?? 'Recently Added'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips({
    required int totalCount,
    required int dueCount,
    required int advanceCount,
    required int settledCount,
  }) {
    final l10n = AppLocalizations.of(context);
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildChip(
              label: '${l10n?.filterAll ?? "All"} ($totalCount)',
              filter: CustomerFilter.all,
              activeColor: AppColors.primary,
            ),
            const SizedBox(width: 8),
            _buildChip(
              label: '${l10n?.filterDue ?? "Due"} ($dueCount)',
              filter: CustomerFilter.due,
              activeColor: AppColors.debtText,
            ),
            const SizedBox(width: 8),
            _buildChip(
              label: '${l10n?.filterAdvance ?? "Advance"} ($advanceCount)',
              filter: CustomerFilter.advance,
              activeColor: AppColors.advanceText,
            ),
            const SizedBox(width: 8),
            _buildChip(
              label: '${l10n?.filterSettled ?? "Settled"} ($settledCount)',
              filter: CustomerFilter.settled,
              activeColor: AppColors.settledText,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip({
    required String label,
    required CustomerFilter filter,
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

  Widget _buildSummaryBanner({
    required CustomerFilter filter,
    required int count,
    required double totalDue,
    required double totalAdvance,
    required String currency,
  }) {
    final moneyFormat = NumberFormat('#,##0.00');
    final l10n = AppLocalizations.of(context);

    final IconData icon;
    final Color bgColor;
    final Color textColor;
    final String text;

    switch (filter) {
      case CustomerFilter.due:
        icon = Icons.error_outline_rounded;
        bgColor = AppColors.debtBg;
        textColor = AppColors.debtText;
        text = '$count customer${count == 1 ? '' : 's'} owe${count == 1 ? 's' : ''} a total of $currency${moneyFormat.format(totalDue)}';
        break;
      case CustomerFilter.advance:
        icon = Icons.account_balance_wallet_outlined;
        bgColor = AppColors.advanceBg;
        textColor = AppColors.advanceText;
        text = '$count customer${count == 1 ? '' : 's'} ${count == 1 ? 'has' : 'have'} advance of $currency${moneyFormat.format(totalAdvance)}';
        break;
      case CustomerFilter.settled:
        icon = Icons.check_circle_outline_rounded;
        bgColor = AppColors.settledBg;
        textColor = AppColors.settledText;
        text = '$count customer${count == 1 ? '' : 's'} with settled account';
        break;
      case CustomerFilter.all:
        icon = Icons.info_outline_rounded;
        bgColor = const Color(0xFFEFF3F1);
        textColor = const Color(0xFF42524D);
        text = '$count customer${count == 1 ? '' : 's'} • ${l10n?.totalReceivable ?? "Total Due:"} $currency${moneyFormat.format(totalDue)}';
        break;
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: textColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ThemeData theme) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primaryContainer.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.people_outline_rounded,
                size: 40,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No customers yet',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first customer to start tracking credit and payments.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF60706B),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => showAddCustomerDialog(context, ref),
              icon: const Icon(Icons.person_add_rounded),
              label: const Text('Add First Customer'),
              style: FilledButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                minimumSize: const Size(0, 48),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoSearchResults(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0xFFECEFF1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search_off_rounded,
                size: 32,
                color: Color(0xFF78909C),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No matching customers',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'No results found for "$_searchQuery"',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: const Color(0xFF78909C),
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
              icon: const Icon(Icons.clear_rounded, size: 16),
              label: const Text('Clear Search'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoFilterResults(ThemeData theme, CustomerFilter filter) {
    final String title;
    final String subtitle;
    final IconData icon;

    switch (filter) {
      case CustomerFilter.due:
        title = 'No pending dues';
        subtitle = 'All customer accounts are settled or in advance.';
        icon = Icons.verified_outlined;
        break;
      case CustomerFilter.advance:
        title = 'No advance payments';
        subtitle = 'None of your customers have deposited advance credit.';
        icon = Icons.account_balance_wallet_outlined;
        break;
      case CustomerFilter.settled:
        title = 'No settled accounts';
        subtitle = 'All customers currently have pending dues or advance.';
        icon = Icons.receipt_long_outlined;
        break;
      case CustomerFilter.all:
        title = 'No customers found';
        subtitle = 'There are no customers to display.';
        icon = Icons.people_outline_rounded;
        break;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0xFFECEFF1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 32,
                color: const Color(0xFF78909C),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: const Color(0xFF78909C),
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () {
                setState(() => _currentFilter = CustomerFilter.all);
              },
              icon: const Icon(Icons.people_outline_rounded, size: 16),
              label: const Text('View All Customers'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomerCard extends StatelessWidget {
  final Customer customer;
  final double balance;
  final String currency;

  const _CustomerCard({
    required this.customer,
    required this.balance,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initial = customer.name.trim().isNotEmpty
        ? customer.name.trim()[0].toUpperCase()
        : '?';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE0E5E2)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CustomerDetailsScreen(customerId: customer.id),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor:
                    AppColors.primaryContainer.withValues(alpha: 0.6),
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      customer.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (customer.phone != null &&
                        customer.phone!.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.phone_outlined,
                            size: 13,
                            color: Color(0xFF78909C),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            customer.phone!.trim(),
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF60706B),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (customer.address != null &&
                        customer.address!.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 13,
                            color: Color(0xFF78909C),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              customer.address!.trim(),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF78909C),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _BalanceBadge(
                balance: balance,
                currency: currency,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BalanceBadge extends StatelessWidget {
  final double balance;
  final String currency;

  const _BalanceBadge({
    required this.balance,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final Color textColor;
    final Color bgColor;
    final String text;

    final formatter = (balance.abs() % 1 == 0)
        ? NumberFormat('#,##0')
        : NumberFormat('#,##0.00');

    if (balance > 0) {
      textColor = AppColors.debtText;
      bgColor = AppColors.debtBg;
      text = '${l10n?.netDue ?? "Due"} $currency${formatter.format(balance)}';
    } else if (balance < 0) {
      textColor = AppColors.advanceText;
      bgColor = AppColors.advanceBg;
      text = '${l10n?.advance ?? "Advance"} $currency${formatter.format(balance.abs())}';
    } else {
      textColor = AppColors.settledText;
      bgColor = AppColors.settledBg;
      text = l10n?.settled ?? 'Settled';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }
}
