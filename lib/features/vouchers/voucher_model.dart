import '../../data/models/app_settings.dart';
import '../../data/models/customer.dart';
import '../../data/models/transaction.dart';
import '../../data/repositories/transaction_repository.dart';

class VoucherItem {
  final String name;
  final String? quantity;
  final double? rate;
  final double total;

  const VoucherItem({
    required this.name,
    this.quantity,
    this.rate,
    required this.total,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'quantity': quantity,
        'rate': rate,
        'total': total,
      };

  factory VoucherItem.fromMap(Map<String, dynamic> map) {
    return VoucherItem(
      name: map['name'] as String,
      quantity: map['quantity'] as String?,
      rate: (map['rate'] as num?)?.toDouble(),
      total: (map['total'] as num).toDouble(),
    );
  }
}

class ItemParser {
  static const String itemsStartTag = '[ITEMS]';
  static const String itemsEndTag = '[/ITEMS]';

  /// Serializes a list of items and optional notes into a description string.
  static String serialize(List<VoucherItem> items, {String? notes}) {
    if (items.isEmpty) {
      return notes?.trim() ?? '';
    }

    final buffer = StringBuffer();
    buffer.writeln(itemsStartTag);
    for (final item in items) {
      final name = item.name.replaceAll('|', '-').trim();
      final qty = (item.quantity ?? '').replaceAll('|', '-').trim();
      final rateStr = item.rate != null ? item.rate.toString() : '';
      final totalStr = item.total.toString();
      buffer.writeln('$name|$qty|$rateStr|$totalStr');
    }
    buffer.write(itemsEndTag);

    if (notes != null && notes.trim().isNotEmpty) {
      buffer.writeln();
      buffer.write(notes.trim());
    }

    return buffer.toString();
  }

  /// Parses an existing description string into structured items and raw notes.
  static ({List<VoucherItem> items, String? notes}) parse(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return (items: <VoucherItem>[], notes: null);
    }

    final trimmed = raw.trim();
    if (!trimmed.contains(itemsStartTag) || !trimmed.contains(itemsEndTag)) {
      return (items: <VoucherItem>[], notes: trimmed);
    }

    final startIndex = trimmed.indexOf(itemsStartTag) + itemsStartTag.length;
    final endIndex = trimmed.indexOf(itemsEndTag);

    if (endIndex <= startIndex) {
      return (items: <VoucherItem>[], notes: trimmed);
    }

    final itemsBlock = trimmed.substring(startIndex, endIndex).trim();
    final notesPart = trimmed.substring(endIndex + itemsEndTag.length).trim();

    final items = <VoucherItem>[];
    for (final line in itemsBlock.split('\n')) {
      final lineTrim = line.trim();
      if (lineTrim.isEmpty) continue;
      final parts = lineTrim.split('|');
      if (parts.isNotEmpty) {
        final name = parts[0].trim();
        final qty = parts.length > 1 && parts[1].trim().isNotEmpty ? parts[1].trim() : null;
        final rate = parts.length > 2 && double.tryParse(parts[2].trim()) != null
            ? double.tryParse(parts[2].trim())
            : null;
        final total = parts.length > 3 && double.tryParse(parts[3].trim()) != null
            ? double.parse(parts[3].trim())
            : (rate ?? 0.0);

        if (name.isNotEmpty) {
          items.add(VoucherItem(
            name: name,
            quantity: qty,
            rate: rate,
            total: total,
          ));
        }
      }
    }

    return (
      items: items,
      notes: notesPart.isNotEmpty ? notesPart : null,
    );
  }
}

class PhoneUtils {
  /// Normalizes Bangladeshi phone numbers to international format without leading plus (e.g. 88017XXXXXXXX).
  static String? normalizeForWhatsApp(String? phone) {
    if (phone == null) return null;
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return null;

    if (digits.startsWith('880') && digits.length >= 13) {
      return digits;
    } else if (digits.startsWith('01') && digits.length == 11) {
      return '88$digits';
    } else if (digits.startsWith('1') && digits.length == 10) {
      return '880$digits';
    }

    // Return clean digits if at least 7 digits (international fallback)
    if (digits.length >= 7) {
      return digits;
    }
    return null;
  }

  /// Converts English digit characters to Bengali numerals.
  static String toBengaliNumber(String input) {
    const en = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const bn = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];
    String res = input;
    for (int i = 0; i < 10; i++) {
      res = res.replaceAll(en[i], bn[i]);
    }
    return res;
  }
}

class VoucherData {
  final AppTransaction transaction;
  final Customer customer;
  final AppSettings settings;
  final VoucherBalanceSnapshot balance;
  final List<VoucherItem> items;
  final String? notes;

  const VoucherData({
    required this.transaction,
    required this.customer,
    required this.settings,
    required this.balance,
    required this.items,
    this.notes,
  });

  factory VoucherData.fromTransaction({
    required AppTransaction transaction,
    required Customer customer,
    required AppSettings settings,
    required VoucherBalanceSnapshot balance,
  }) {
    final parsed = ItemParser.parse(transaction.description);
    return VoucherData(
      transaction: transaction,
      customer: customer,
      settings: settings,
      balance: balance,
      items: parsed.items,
      notes: parsed.notes,
    );
  }

  String get voucherNumber {
    final cleanId = transaction.id.replaceAll('-', '');
    final shortCode = cleanId.length >= 6
        ? cleanId.substring(0, 6).toUpperCase()
        : cleanId.toUpperCase();
    return '#BK-$shortCode';
  }
}
