import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../data/models/customer.dart';
import '../../data/repositories/customer_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../shared/quick_action_dialogs.dart';
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

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  late final TextEditingController _searchController;
  String _searchQuery = '';

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

          final query = _searchQuery.trim().toLowerCase();
          final filteredCustomers = query.isEmpty
              ? customers
              : customers.where((c) {
                  final nameMatch = c.name.toLowerCase().contains(query);
                  final phoneMatch =
                      c.phone?.toLowerCase().contains(query) ?? false;
                  final addressMatch =
                      c.address?.toLowerCase().contains(query) ?? false;
                  return nameMatch || phoneMatch || addressMatch;
                }).toList();

          return Column(
            children: [
              _buildSearchField(),
              Expanded(
                child: filteredCustomers.isEmpty
                    ? _buildNoSearchResults(theme)
                    : RefreshIndicator(
                        onRefresh: () async {
                          await ref.read(customerRepositoryProvider).refresh();
                          await ref.read(transactionRepositoryProvider).refresh();
                        },
                        child: ListView.builder(
                          padding: const EdgeInsets.only(top: 4, bottom: 84),
                          itemCount: filteredCustomers.length,
                          itemBuilder: (context, index) {
                            final customer = filteredCustomers[index];
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

  Widget _buildSearchField() {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        controller: _searchController,
        onChanged: (val) {
          setState(() {
            _searchQuery = val;
          });
        },
        decoration: InputDecoration(
          hintText: 'Search by name, phone, or address...',
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
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
        ),
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
    final Color textColor;
    final Color bgColor;
    final String text;

    final formatter = (balance.abs() % 1 == 0)
        ? NumberFormat('#,##0')
        : NumberFormat('#,##0.00');

    if (balance > 0) {
      textColor = AppColors.debtText;
      bgColor = AppColors.debtBg;
      text = 'Due $currency${formatter.format(balance)}';
    } else if (balance < 0) {
      textColor = AppColors.advanceText;
      bgColor = AppColors.advanceBg;
      text = 'Advance $currency${formatter.format(balance.abs())}';
    } else {
      textColor = AppColors.settledText;
      bgColor = AppColors.settledBg;
      text = 'Settled';
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
