import 'package:intl/intl.dart';
import '../../../data/models/app_settings.dart';
import '../../../data/models/customer.dart';
import '../../../data/models/transaction.dart';
import '../../vouchers/voucher_model.dart';

enum StatementPeriodType {
  last30Days,
  last3Months,
  last6Months,
  thisYear,
  allTime,
  custom,
}

class StatementPeriod {
  final StatementPeriodType type;
  final DateTime? startDate;
  final DateTime? endDate;

  const StatementPeriod({
    required this.type,
    this.startDate,
    this.endDate,
  });

  factory StatementPeriod.fromType(StatementPeriodType type, {DateTime? customStart, DateTime? customEnd}) {
    final now = DateTime.now();
    switch (type) {
      case StatementPeriodType.last30Days:
        final start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 30));
        return StatementPeriod(type: type, startDate: start, endDate: now);
      case StatementPeriodType.last3Months:
        final start = DateTime(now.year, now.month - 3, now.day);
        return StatementPeriod(type: type, startDate: start, endDate: now);
      case StatementPeriodType.last6Months:
        final start = DateTime(now.year, now.month - 6, now.day);
        return StatementPeriod(type: type, startDate: start, endDate: now);
      case StatementPeriodType.thisYear:
        final start = DateTime(now.year, 1, 1);
        return StatementPeriod(type: type, startDate: start, endDate: now);
      case StatementPeriodType.allTime:
        return StatementPeriod(type: type, startDate: null, endDate: now);
      case StatementPeriodType.custom:
        return StatementPeriod(
          type: type,
          startDate: customStart ?? DateTime(now.year, now.month, 1),
          endDate: customEnd ?? now,
        );
    }
  }

  String getLabel({bool isBengali = true}) {
    switch (type) {
      case StatementPeriodType.last30Days:
        return isBengali ? 'গত ৩০ দিন' : 'Last 30 Days';
      case StatementPeriodType.last3Months:
        return isBengali ? 'গত ৩ মাস' : 'Last 3 Months';
      case StatementPeriodType.last6Months:
        return isBengali ? 'গত ৬ মাস' : 'Last 6 Months';
      case StatementPeriodType.thisYear:
        return isBengali ? 'চলতি বছর' : 'This Year';
      case StatementPeriodType.allTime:
        return isBengali ? 'শুরু থেকে আজ পর্যন্ত' : 'All Time';
      case StatementPeriodType.custom:
        return isBengali ? 'কাস্টম তারিখ' : 'Custom Period';
    }
  }

  String getDateRangeFormatted({bool isBengali = true}) {
    final df = DateFormat('dd MMM yyyy');
    if (startDate == null) {
      final endStr = df.format(endDate ?? DateTime.now());
      final safeEnd = isBengali ? PhoneUtils.toBengaliNumber(endStr) : endStr;
      return isBengali ? 'শুরু থেকে $safeEnd পর্যন্ত' : 'From inception to $safeEnd';
    }

    final startStr = df.format(startDate!);
    final endStr = df.format(endDate ?? DateTime.now());
    final safeStart = isBengali ? PhoneUtils.toBengaliNumber(startStr) : startStr;
    final safeEnd = isBengali ? PhoneUtils.toBengaliNumber(endStr) : endStr;

    return isBengali ? '$safeStart হতে $safeEnd' : '$safeStart to $safeEnd';
  }
}

class LedgerEntry {
  final AppTransaction transaction;
  final String voucherNumber;
  final List<VoucherItem> items;
  final String? notes;
  final double debit; // Baki given in this tx
  final double credit; // Payment received in this tx
  final double runningBalance; // Net balance after this tx

  const LedgerEntry({
    required this.transaction,
    required this.voucherNumber,
    required this.items,
    this.notes,
    required this.debit,
    required this.credit,
    required this.runningBalance,
  });

  DateTime get date => transaction.date;
  bool get isBaki => transaction.isBaki;
  bool get isPayment => transaction.isPayment;
}

class CustomerStatementData {
  final Customer customer;
  final AppSettings settings;
  final StatementPeriod period;
  final double openingBalance;
  final List<LedgerEntry> entries;
  final double totalBaki;
  final double totalPayment;
  final double closingBalance;
  final bool isDetailed;
  final DateTime generatedAt;

  const CustomerStatementData({
    required this.customer,
    required this.settings,
    required this.period,
    required this.openingBalance,
    required this.entries,
    required this.totalBaki,
    required this.totalPayment,
    required this.closingBalance,
    this.isDetailed = true,
    required this.generatedAt,
  });

  String get statementNumber {
    final cleanId = customer.id.replaceAll('-', '');
    final shortCode = cleanId.length >= 6
        ? cleanId.substring(0, 6).toUpperCase()
        : cleanId.toUpperCase();
    final epoch = generatedAt.millisecondsSinceEpoch.toString();
    final suffix = epoch.substring(epoch.length - 4);
    return 'STM-$shortCode-$suffix';
  }
}

class StoreCustomerSummary {
  final Customer customer;
  final double openingBalance;
  final double periodBaki;
  final double periodPayment;
  final double closingBalance;
  final DateTime? lastTxDate;

  const StoreCustomerSummary({
    required this.customer,
    required this.openingBalance,
    required this.periodBaki,
    required this.periodPayment,
    required this.closingBalance,
    this.lastTxDate,
  });
}

class StoreStatementData {
  final AppSettings settings;
  final StatementPeriod period;
  final List<StoreCustomerSummary> customerSummaries;
  final double totalOpeningBalance;
  final double totalBaki;
  final double totalPayment;
  final double totalClosingBalance;
  final DateTime generatedAt;

  const StoreStatementData({
    required this.settings,
    required this.period,
    required this.customerSummaries,
    required this.totalOpeningBalance,
    required this.totalBaki,
    required this.totalPayment,
    required this.totalClosingBalance,
    required this.generatedAt,
  });

  String get statementNumber {
    final epoch = generatedAt.millisecondsSinceEpoch.toString();
    final suffix = epoch.substring(epoch.length - 6);
    return 'STORE-$suffix';
  }
}
