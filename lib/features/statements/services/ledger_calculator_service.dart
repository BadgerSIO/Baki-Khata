import '../../../data/models/app_settings.dart';
import '../../../data/models/customer.dart';
import '../../../data/models/transaction.dart';
import '../../vouchers/voucher_model.dart';
import '../models/statement_models.dart';

class LedgerCalculatorService {
  /// Computes a comprehensive [CustomerStatementData] for a single customer.
  static CustomerStatementData computeCustomerStatement({
    required Customer customer,
    required List<AppTransaction> allTransactions,
    required AppSettings settings,
    required StatementPeriod period,
    bool isDetailed = true,
  }) {
    // 1. Separate transactions before period start date vs within period
    final startDate = period.startDate;
    final endDate = period.endDate ?? DateTime.now();
    // Normalize endDate to end of that day (23:59:59.999) so same-day transactions are included
    final normalizedEndDate = DateTime(
      endDate.year,
      endDate.month,
      endDate.day,
      23,
      59,
      59,
      999,
    );

    double openingBalance = 0.0;
    final List<AppTransaction> inPeriodTxs = [];

    for (final tx in allTransactions) {
      if (tx.customerId != customer.id) continue;

      if (startDate != null && tx.date.isBefore(startDate)) {
        if (tx.isBaki) {
          openingBalance += tx.amount;
        } else if (tx.isPayment) {
          openingBalance -= tx.amount;
        }
      } else if (startDate == null || (tx.date.isAfter(startDate.subtract(const Duration(milliseconds: 1))) &&
          tx.date.isBefore(normalizedEndDate.add(const Duration(milliseconds: 1))))) {
        inPeriodTxs.add(tx);
      }
    }

    // 2. Sort in-period transactions chronologically (oldest first for ledger)
    inPeriodTxs.sort((a, b) {
      final cmp = a.date.compareTo(b.date);
      if (cmp != 0) return cmp;
      return a.createdAt.compareTo(b.createdAt);
    });

    // 3. Build ledger entries with cumulative running balances
    double currentRunning = openingBalance;
    double periodTotalBaki = 0.0;
    double periodTotalPayment = 0.0;
    final List<LedgerEntry> entries = [];

    for (final tx in inPeriodTxs) {
      final double debit;
      final double credit;

      if (tx.isBaki) {
        debit = tx.amount;
        credit = 0.0;
        currentRunning += tx.amount;
        periodTotalBaki += tx.amount;
      } else {
        debit = 0.0;
        credit = tx.amount;
        currentRunning -= tx.amount;
        periodTotalPayment += tx.amount;
      }

      final parsed = ItemParser.parse(tx.description);
      final cleanId = tx.id.replaceAll('-', '');
      final shortVoucher = cleanId.length >= 6
          ? '#BK-${cleanId.substring(0, 6).toUpperCase()}'
          : '#BK-${cleanId.toUpperCase()}';

      entries.add(LedgerEntry(
        transaction: tx,
        voucherNumber: shortVoucher,
        items: parsed.items,
        notes: parsed.notes,
        debit: debit,
        credit: credit,
        runningBalance: currentRunning,
      ));
    }

    final closingBalance = openingBalance + periodTotalBaki - periodTotalPayment;

    return CustomerStatementData(
      customer: customer,
      settings: settings,
      period: period,
      openingBalance: openingBalance,
      entries: entries,
      totalBaki: periodTotalBaki,
      totalPayment: periodTotalPayment,
      closingBalance: closingBalance,
      isDetailed: isDetailed,
      generatedAt: DateTime.now(),
    );
  }

  /// Computes store-wide master statement summary for all customers.
  static StoreStatementData computeStoreStatement({
    required List<Customer> customers,
    required List<AppTransaction> allTransactions,
    required AppSettings settings,
    required StatementPeriod period,
  }) {
    final startDate = period.startDate;
    final endDate = period.endDate ?? DateTime.now();
    final normalizedEndDate = DateTime(
      endDate.year,
      endDate.month,
      endDate.day,
      23,
      59,
      59,
      999,
    );

    // Group transactions by customerId
    final Map<String, List<AppTransaction>> txsByCustomer = {};
    for (final tx in allTransactions) {
      txsByCustomer.putIfAbsent(tx.customerId, () => []).add(tx);
    }

    final List<StoreCustomerSummary> summaries = [];
    double storeOpening = 0.0;
    double storeBaki = 0.0;
    double storePayment = 0.0;

    for (final c in customers) {
      final txList = txsByCustomer[c.id] ?? [];
      double custOpening = 0.0;
      double custPeriodBaki = 0.0;
      double custPeriodPayment = 0.0;
      DateTime? lastTx;

      for (final tx in txList) {
        if (lastTx == null || tx.date.isAfter(lastTx)) {
          lastTx = tx.date;
        }

        if (startDate != null && tx.date.isBefore(startDate)) {
          if (tx.isBaki) {
            custOpening += tx.amount;
          } else if (tx.isPayment) {
            custOpening -= tx.amount;
          }
        } else if (startDate == null ||
            (tx.date.isAfter(startDate.subtract(const Duration(milliseconds: 1))) &&
                tx.date.isBefore(normalizedEndDate.add(const Duration(milliseconds: 1))))) {
          if (tx.isBaki) {
            custPeriodBaki += tx.amount;
          } else if (tx.isPayment) {
            custPeriodPayment += tx.amount;
          }
        }
      }

      final custClosing = custOpening + custPeriodBaki - custPeriodPayment;

      // Only include customers who have active balances or activity
      if (custOpening.abs() > 0.001 ||
          custPeriodBaki > 0.001 ||
          custPeriodPayment > 0.001 ||
          custClosing.abs() > 0.001) {
        summaries.add(StoreCustomerSummary(
          customer: c,
          openingBalance: custOpening,
          periodBaki: custPeriodBaki,
          periodPayment: custPeriodPayment,
          closingBalance: custClosing,
          lastTxDate: lastTx,
        ));

        storeOpening += custOpening;
        storeBaki += custPeriodBaki;
        storePayment += custPeriodPayment;
      }
    }

    // Sort customers descending by closing balance (highest debtors first)
    summaries.sort((a, b) => b.closingBalance.compareTo(a.closingBalance));

    return StoreStatementData(
      settings: settings,
      period: period,
      customerSummaries: summaries,
      totalOpeningBalance: storeOpening,
      totalBaki: storeBaki,
      totalPayment: storePayment,
      totalClosingBalance: storeOpening + storeBaki - storePayment,
      generatedAt: DateTime.now(),
    );
  }
}
