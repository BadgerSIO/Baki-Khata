import 'package:intl/intl.dart';

import '../../../data/models/app_settings.dart';
import '../../../data/models/customer.dart';
import '../../vouchers/voucher_model.dart';

enum ReminderTone {
  polite,
  urgent,
  statement,
}

class ReminderMessageBuilder {
  /// Generates human-friendly, personalized WhatsApp message for a customer reminder or statement.
  static String build({
    required Customer customer,
    required double balance,
    required AppSettings settings,
    DateTime? lastTransactionDate,
    required ReminderTone tone,
    bool isBengali = true,
  }) {
    final currency = settings.currencySymbol;

    String formatMoney(double amount) {
      final fmt = (amount.abs() % 1 == 0)
          ? NumberFormat('#,##0')
          : NumberFormat('#,##0.00');
      final formatted = fmt.format(amount.abs());
      return isBengali ? PhoneUtils.toBengaliNumber(formatted) : formatted;
    }

    String formatDate(DateTime dt) {
      final local = dt.toLocal();
      final fmt = DateFormat('dd MMM yyyy');
      final formatted = fmt.format(local);
      return isBengali ? PhoneUtils.toBengaliNumber(formatted) : formatted;
    }

    final buffer = StringBuffer();
    final shopName = settings.shopName.trim().isEmpty
        ? 'My Shop'
        : settings.shopName.trim();
    buffer.writeln('🏪 *$shopName*');

    final address = settings.shopAddress?.trim();
    final phone = settings.shopPhone?.trim();
    if (address != null && address.isNotEmpty) {
      buffer.write('📍 $address');
    }
    if (phone != null && phone.isNotEmpty) {
      if (address != null && address.isNotEmpty) buffer.write(' | ');
      buffer.write('📞 $phone');
    }
    if ((address != null && address.isNotEmpty) ||
        (phone != null && phone.isNotEmpty)) {
      buffer.writeln();
    }

    buffer.writeln('─────────────────────────');

    final headerTitle = balance > 0
        ? (tone == ReminderTone.urgent
            ? (isBengali ? '🚨 জরুরি তাগাদা' : '🚨 URGENT DUE REMINDER')
            : (isBengali ? '🔔 বাকি তাগাদা' : '🔔 DUE REMINDER'))
        : (isBengali ? '📋 হিসাব বিবরণী' : '📋 ACCOUNT STATEMENT');

    buffer.writeln(headerTitle);
    buffer.writeln(
        '👤 *${isBengali ? "গ্রাহক" : "Customer"}:* ${customer.name.trim()}');
    buffer.writeln(
        '📅 *${isBengali ? "তারিখ" : "Date"}:* ${formatDate(DateTime.now())}');
    buffer.writeln('─────────────────────────');

    // Balance Display
    if (balance > 0) {
      final dueLabel = isBengali ? 'বর্তমান মোট বাকি:' : 'Total Net Due:';
      buffer.writeln('🔴 *$dueLabel $currency ${formatMoney(balance)}*');
    } else if (balance < 0) {
      final advLabel = isBengali ? 'অগ্রিম জমা:' : 'Advance Balance:';
      buffer.writeln('🔵 *$advLabel $currency ${formatMoney(balance.abs())}*');
    } else {
      buffer.writeln('🟢 *${isBengali ? "হিসাব সম্পূর্ণ পরিশোধিত" : "Fully Settled Account"}*');
    }

    // Last Transaction Date (if available)
    if (lastTransactionDate != null) {
      final lastTxLabel = isBengali ? 'সর্বশেষ লেনদেন:' : 'Last Transaction:';
      buffer.writeln('⏳ $lastTxLabel ${formatDate(lastTransactionDate)}');
    }

    buffer.writeln();

    // Payment prompt
    if (balance > 0) {
      if (settings.hasDigitalPaymentMethods) {
        final payHeader = isBengali
            ? '💳 *পরিশোধের মাধ্যম:*'
            : '💳 *Payment Methods:*';
        buffer.writeln(payHeader);

        if (settings.bkashNumber != null &&
            settings.bkashNumber!.trim().isNotEmpty) {
          final bName = isBengali ? 'বিকাশ' : 'bKash';
          final bType = settings.bkashIsMerchant
              ? (isBengali ? 'মার্চেন্ট - Make Payment' : 'Merchant - Make Payment')
              : (isBengali ? 'পার্সোনাল - Send Money' : 'Personal - Send Money');
          buffer.writeln('• $bName ($bType): ${settings.bkashNumber!.trim()}');
        }

        if (settings.nagadNumber != null &&
            settings.nagadNumber!.trim().isNotEmpty) {
          final nName = isBengali ? 'নগদ' : 'Nagad';
          final nType = settings.nagadIsMerchant
              ? (isBengali ? 'মার্চেন্ট - Make Payment' : 'Merchant - Make Payment')
              : (isBengali ? 'পার্সোনাল - Send Money' : 'Personal - Send Money');
          buffer.writeln('• $nName ($nType): ${settings.nagadNumber!.trim()}');
        }

        if (settings.rocketNumber != null &&
            settings.rocketNumber!.trim().isNotEmpty) {
          final rName = isBengali ? 'রকেট' : 'Rocket';
          final rType = settings.rocketIsMerchant
              ? (isBengali ? 'মার্চেন্ট - Make Payment' : 'Merchant - Make Payment')
              : (isBengali ? 'পার্সোনাল - Send Money' : 'Personal - Send Money');
          buffer.writeln('• $rName ($rType): ${settings.rocketNumber!.trim()}');
        }

        final trxNote = isBengali
            ? '📌 টাকা পাঠিয়ে ট্রানজেকশন আইডি (TrxID) বা স্ক্রিনশট পাঠিয়ে নিশ্চিত করুন।'
            : '📌 After payment, please reply with TrxID or screenshot to confirm.';
        buffer.writeln(trxNote);
        buffer.writeln();
      } else if (phone != null && phone.isNotEmpty) {
        final payLabel = isBengali
            ? '💳 *পরিশোধের মাধ্যম (বিকাশ/নগদ/দোকান):* $phone'
            : '💳 *Payment Method (bKash/Nagad/Shop):* $phone';
        buffer.writeln(payLabel);
        buffer.writeln();
      }
    }

    // Tone-specific message body
    if (balance > 0) {
      switch (tone) {
        case ReminderTone.polite:
          buffer.writeln(isBengali
              ? 'আসসালামু আলাইকুম। আপনার সুবিধাজনক সময়ে বকেয়া টাকা পরিশোধের বিনীত অনুরোধ রইল।'
              : 'Greetings! Kindly request to settle the outstanding balance at your earliest convenience.');
          break;
        case ReminderTone.urgent:
          buffer.writeln(isBengali
              ? 'জরুরি নোটিশ: আপনার বাকি হিসাবটি বকেয়া রয়েছে। অনুগ্রহ করে দ্রুত পরিশোধ করে হিসাব নিষ্পত্তির অনুরোধ জানাচ্ছি।'
              : 'Urgent Notice: Your credit balance is overdue. Please settle this amount promptly to clear your account.');
          break;
        case ReminderTone.statement:
          buffer.writeln(isBengali
              ? 'এটি আপনার বর্তমান বকেয়া হিসাব বিবরণী। কোনো জিজ্ঞাসা থাকলে আমাদের সাথে যোগাযোগ করুন।'
              : 'This is your current account statement. Please reach out if you have any questions.');
          break;
      }
    } else if (balance < 0) {
      buffer.writeln(isBengali
          ? 'আপনার অগ্রিম টাকা জমা আছে। পরবর্তী কেনাকাটায় এটি সমন্বয় করা হবে। ধন্যবাদ!'
          : 'You have advance credit on file with us. It will be adjusted on your next purchase. Thank you!');
    } else {
      buffer.writeln(isBengali
          ? 'আপনার কোনো বকেয়া বাকি নেই। নিয়মিত হিসাব রাখার জন্য ধন্যবাদ!'
          : 'Your account is fully settled. Thank you for doing business with us!');
    }

    buffer.writeln('─────────────────────────');
    buffer.write(isBengali
        ? '_বাকি খাতা অ্যাপের মাধ্যমে প্রেরিত_'
        : '_Sent via Baki Khata App_');

    return buffer.toString();
  }
}
