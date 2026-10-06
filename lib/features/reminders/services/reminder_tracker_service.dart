import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../vouchers/voucher_model.dart';

const String _reminderKeyPrefix = 'last_reminder_';

/// Riverpod family provider providing the last reminder [DateTime] for a specific customer.
final customerLastReminderProvider =
    FutureProvider.family<DateTime?, String>((ref, customerId) async {
  return ReminderTrackerService.getLastReminderDate(customerId);
});

class ReminderTrackerService {
  /// Records the current timestamp as the last reminder time for [customerId].
  static Future<void> recordReminderSent(String customerId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '$_reminderKeyPrefix$customerId',
        DateTime.now().toUtc().toIso8601String(),
      );
    } catch (_) {
      // Non-critical persistence error
    }
  }

  /// Fetches the last reminder timestamp for [customerId], or null if never recorded.
  static Future<DateTime?> getLastReminderDate(String customerId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_reminderKeyPrefix$customerId');
      if (raw == null || raw.isEmpty) return null;
      return DateTime.tryParse(raw)?.toLocal();
    } catch (_) {
      return null;
    }
  }

  /// Formats a past reminder timestamp into human-readable relative text in Bengali or English.
  static String? formatRelativeTime(
    DateTime? dt, {
    bool isBengali = true,
  }) {
    if (dt == null) return null;
    final now = DateTime.now();
    final local = dt.toLocal();
    final diff = now.difference(local);

    if (diff.inSeconds < 60) {
      return isBengali ? 'এইমাত্র' : 'Just now';
    }

    if (diff.inMinutes < 60) {
      final mins = diff.inMinutes;
      final numStr = isBengali ? PhoneUtils.toBengaliNumber('$mins') : '$mins';
      return isBengali ? '$numStr মিনিট আগে' : '$numStr mins ago';
    }

    final isSameDay =
        now.year == local.year && now.month == local.month && now.day == local.day;
    if (isSameDay) {
      final timeStr = DateFormat('h:mm a').format(local);
      final bnTime = isBengali ? PhoneUtils.toBengaliNumber(timeStr) : timeStr;
      return isBengali ? 'আজ $bnTime' : 'Today $timeStr';
    }

    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = yesterday.year == local.year &&
        yesterday.month == local.month &&
        yesterday.day == local.day;
    if (isYesterday) {
      return isBengali ? 'গতকাল' : 'Yesterday';
    }

    if (diff.inDays < 7) {
      final days = diff.inDays;
      final numStr = isBengali ? PhoneUtils.toBengaliNumber('$days') : '$days';
      return isBengali ? '$numStr দিন আগে' : '$numStr days ago';
    }

    final dateStr = DateFormat('dd MMM').format(local);
    return isBengali ? PhoneUtils.toBengaliNumber(dateStr) : dateStr;
  }
}
