import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';
import '../../../data/models/app_settings.dart';
import '../../vouchers/voucher_model.dart';
import '../models/statement_models.dart';

class HtmlStatementBuilder {
  /// Converts an amount to formatted currency string (with Bengali numbers if [isBengali] is true).
  static String formatAmount(double amount, {bool isBengali = true, String currencySymbol = '৳'}) {
    final fmt = (amount.abs() % 1 == 0)
        ? NumberFormat('#,##0')
        : NumberFormat('#,##0.00');
    final formatted = fmt.format(amount.abs());
    final numStr = isBengali ? PhoneUtils.toBengaliNumber(formatted) : formatted;
    final sign = amount < 0 ? '-' : '';
    return '$sign$currencySymbol $numStr';
  }

  /// Converts a [DateTime] to a human-readable date.
  static String formatDate(DateTime dt, {bool isBengali = true, bool withTime = false}) {
    final pattern = withTime ? 'dd MMM yyyy, hh:mm a' : 'dd MMM yyyy';
    final fmt = DateFormat(pattern).format(dt.toLocal());
    return isBengali ? PhoneUtils.toBengaliNumber(fmt) : fmt;
  }

  /// Generates the HTML string for a single customer statement.
  static String buildCustomerStatementHtml(
    CustomerStatementData data, {
    bool isBengali = true,
  }) {
    final currency = data.settings.currencySymbol;
    final shopName = data.settings.shopName.trim().isEmpty ? 'My Shop' : data.settings.shopName.trim();
    final proprietor = data.settings.proprietorName?.trim();
    final shopPhone = data.settings.shopPhone?.trim();
    final shopAddress = data.settings.shopAddress?.trim();

    final logoDataUri = _getImageDataUri(data.settings.shopLogoPath);
    final customSealDataUri = data.settings.shopSealType == 'custom'
        ? _getImageDataUri(data.settings.customSealPath)
        : null;

    final openingFormatted = formatAmount(data.openingBalance, isBengali: isBengali, currencySymbol: currency);
    final bakiFormatted = formatAmount(data.totalBaki, isBengali: isBengali, currencySymbol: currency);
    final paymentFormatted = formatAmount(data.totalPayment, isBengali: isBengali, currencySymbol: currency);
    final closingFormatted = formatAmount(data.closingBalance, isBengali: isBengali, currencySymbol: currency);

    final periodLabel = data.period.getDateRangeFormatted(isBengali: isBengali);
    final generatedAtStr = formatDate(data.generatedAt, isBengali: isBengali, withTime: true);

    final entriesHtml = StringBuffer();

    // 1. Opening Balance Row
    entriesHtml.writeln('''
      <tr class="opening-row">
        <td style="text-align: center;">-</td>
        <td><strong>${isBengali ? 'প্রারম্ভিক জের' : 'Opening Balance'}</strong></td>
        <td>-</td>
        <td>${isBengali ? 'হিসাব শুরু করার পূর্বের বাকি/জের' : 'Balance carried forward prior to period'}</td>
        <td style="text-align: right;">${data.openingBalance > 0 ? openingFormatted : '-'}</td>
        <td style="text-align: right;">${data.openingBalance < 0 ? openingFormatted : '-'}</td>
        <td style="text-align: right; font-weight: bold;">$openingFormatted</td>
      </tr>
    ''');

    // 2. Transaction Rows
    for (int i = 0; i < data.entries.length; i++) {
      final entry = data.entries[i];
      final sl = isBengali ? PhoneUtils.toBengaliNumber((i + 1).toString()) : (i + 1).toString();
      final dateStr = formatDate(entry.date, isBengali: isBengali);
      final debitStr = entry.debit > 0
          ? formatAmount(entry.debit, isBengali: isBengali, currencySymbol: currency)
          : '-';
      final creditStr = entry.credit > 0
          ? formatAmount(entry.credit, isBengali: isBengali, currencySymbol: currency)
          : '-';
      final runningStr = formatAmount(entry.runningBalance, isBengali: isBengali, currencySymbol: currency);

      final descBuffer = StringBuffer();
      final typeBadge = entry.isBaki
          ? '<span class="badge badge-baki">${isBengali ? 'বাকি' : 'Baki'}</span>'
          : '<span class="badge badge-payment">${isBengali ? 'জমা' : 'Paid'}</span>';

      descBuffer.write('$typeBadge ');

      if (data.isDetailed && entry.items.isNotEmpty) {
        descBuffer.write('<ul class="item-list">');
        for (final it in entry.items) {
          final qty = it.quantity != null && it.quantity!.isNotEmpty ? ' (${it.quantity})' : '';
          final totalStr = formatAmount(it.total, isBengali: isBengali, currencySymbol: currency);
          descBuffer.write('<li>${it.name}$qty: $totalStr</li>');
        }
        descBuffer.write('</ul>');
        if (entry.notes != null && entry.notes!.trim().isNotEmpty) {
          descBuffer.write('<div class="note-text">📝 ${entry.notes!.trim()}</div>');
        }
      } else if (entry.notes != null && entry.notes!.trim().isNotEmpty) {
        descBuffer.write('<span class="note-text">${entry.notes!.trim()}</span>');
      } else {
        descBuffer.write(entry.isBaki
            ? (isBengali ? 'পণ্য বা সেবা বিক্রয়' : 'Credit Purchase')
            : (isBengali ? 'নগদ/অনলাইন জমা প্রদান' : 'Payment Settled'));
      }

      entriesHtml.writeln('''
        <tr>
          <td style="text-align: center;">$sl</td>
          <td>$dateStr</td>
          <td style="font-family: monospace; font-size: 11px;">${entry.voucherNumber}</td>
          <td>${descBuffer.toString()}</td>
          <td style="text-align: right; color: #b71c1c; font-weight: 500;">$debitStr</td>
          <td style="text-align: right; color: #1b5e20; font-weight: 500;">$creditStr</td>
          <td style="text-align: right; font-weight: 600;">$runningStr</td>
        </tr>
      ''');
    }

    final sealHtml = _buildSealHtml(
      shopName: shopName,
      customSealDataUri: customSealDataUri,
      isBengali: isBengali,
      dateStr: formatDate(data.generatedAt, isBengali: isBengali),
    );

    return '''
<!DOCTYPE html>
<html lang="${isBengali ? 'bn' : 'en'}">
<head>
  <meta charset="utf-8">
  <title>Customer Ledger Statement - $shopName</title>
  <style>
    ${_getCommonCss()}
  </style>
</head>
<body>
  <div class="page-container">
    <!-- Header -->
    <header class="header">
      <div class="shop-brand">
        ${logoDataUri != null ? '<img src="$logoDataUri" class="shop-logo" alt="Logo">' : ''}
        <div class="shop-details">
          <h1 class="shop-name">$shopName</h1>
          ${proprietor != null && proprietor.isNotEmpty ? '<div class="proprietor-text">${isBengali ? 'স্বত্বাধিকারী:' : 'Proprietor:'} $proprietor</div>' : ''}
          ${shopAddress != null && shopAddress.isNotEmpty ? '<div class="contact-info">📍 $shopAddress</div>' : ''}
          ${shopPhone != null && shopPhone.isNotEmpty ? '<div class="contact-info">📞 $shopPhone</div>' : ''}
          ${_buildDigitalPaymentsHtml(data.settings, isBengali)}
        </div>
      </div>
      <div class="doc-meta">
        <div class="doc-badge">${isBengali ? 'গ্রাহক হিসাব বিবরণী' : 'CUSTOMER STATEMENT'}</div>
        <div class="meta-row"><strong>${isBengali ? 'স্টেটমেন্ট নং:' : 'Statement #:'}</strong> ${data.statementNumber}</div>
        <div class="meta-row"><strong>${isBengali ? 'ইস্যুর তারিখ:' : 'Issue Date:'}</strong> $generatedAtStr</div>
        <div class="meta-row"><strong>${isBengali ? 'হিসাবের সময়কাল:' : 'Period:'}</strong> $periodLabel</div>
      </div>
    </header>

    <div class="divider"></div>

    <!-- Customer Card -->
    <div class="customer-card">
      <div class="customer-info-col">
        <div class="card-title">${isBengali ? 'গ্রাহকের তথ্য' : 'Customer Information'}</div>
        <div class="cust-name">👤 ${data.customer.name}</div>
        ${data.customer.phone != null && data.customer.phone!.isNotEmpty ? '<div class="cust-meta">📞 ${data.customer.phone}</div>' : ''}
        ${data.customer.address != null && data.customer.address!.isNotEmpty ? '<div class="cust-meta">📍 ${data.customer.address}</div>' : ''}
      </div>
      <div class="customer-summary-col">
        <div class="card-title">${isBengali ? 'হিসাব সারাংশ' : 'Account Overview'}</div>
        <div class="status-box ${data.closingBalance > 0 ? 'status-due' : (data.closingBalance < 0 ? 'status-advance' : 'status-settled')}">
          <div class="status-label">
            ${data.closingBalance > 0 ? (isBengali ? 'বর্তমান সর্বমোট বাকি' : 'Total Net Due') : (data.closingBalance < 0 ? (isBengali ? 'অগ্রিম জমা' : 'Advance Balance') : (isBengali ? 'হিসাব পরিশোধিত' : 'Fully Settled'))}
          </div>
          <div class="status-amount">$closingFormatted</div>
        </div>
      </div>
    </div>

    <!-- Financial KPI Summary Cards -->
    <div class="kpi-grid">
      <div class="kpi-card">
        <div class="kpi-label">${isBengali ? 'প্রারম্ভিক জের' : 'Opening Due'}</div>
        <div class="kpi-value">$openingFormatted</div>
      </div>
      <div class="kpi-card">
        <div class="kpi-label">${isBengali ? 'এই সময়ে মোট বাকি (+)' : 'Period Credit (+)'}</div>
        <div class="kpi-value baki-text">+$bakiFormatted</div>
      </div>
      <div class="kpi-card">
        <div class="kpi-label">${isBengali ? 'এই সময়ে মোট জমা (-)' : 'Period Paid (-)'}</div>
        <div class="kpi-value payment-text">-$paymentFormatted</div>
      </div>
      <div class="kpi-card kpi-highlight">
        <div class="kpi-label">${isBengali ? 'সমাপনী বাকি' : 'Closing Net Due'}</div>
        <div class="kpi-value">$closingFormatted</div>
      </div>
    </div>

    <!-- Ledger Table -->
    <table class="ledger-table">
      <thead>
        <tr>
          <th style="width: 5%; text-align: center;">${isBengali ? 'নং' : 'SL'}</th>
          <th style="width: 14%;">${isBengali ? 'তারিখ' : 'Date'}</th>
          <th style="width: 13%;">${isBengali ? 'চালান নং' : 'Voucher #'}</th>
          <th style="width: 32%;">${isBengali ? 'বিবরণ ও পণ্য' : 'Description'}</th>
          <th style="width: 12%; text-align: right;">${isBengali ? 'বাকি (+)' : 'Debit (+)'}</th>
          <th style="width: 12%; text-align: right;">${isBengali ? 'জমা (-)' : 'Credit (-)'}</th>
          <th style="width: 12%; text-align: right;">${isBengali ? 'চলতি জের' : 'Balance'}</th>
        </tr>
      </thead>
      <tbody>
        ${entriesHtml.toString()}
      </tbody>
      <tfoot>
        <tr class="total-row">
          <td colspan="4" style="text-align: right; font-weight: bold;">${isBengali ? 'সর্বমোট যোগফল:' : 'Total Sum:'}</td>
          <td style="text-align: right; color: #b71c1c; font-weight: bold;">$bakiFormatted</td>
          <td style="text-align: right; color: #1b5e20; font-weight: bold;">$paymentFormatted</td>
          <td style="text-align: right; font-weight: bold; background: #e0f2f1;">$closingFormatted</td>
        </tr>
      </tfoot>
    </table>

    <!-- Authentication and Signatures -->
    <div class="footer-signatures">
      <div class="sig-box">
        <div class="sig-line"></div>
        <div class="sig-label">${isBengali ? 'গ্রাহকের স্বাক্ষর' : 'Customer Signature'}</div>
      </div>
      <div class="seal-container">
        $sealHtml
      </div>
      <div class="sig-box">
        <div class="sig-line"></div>
        <div class="sig-label">${isBengali ? 'স্বত্বাধিকারীর স্বাক্ষর ও সিল' : 'Authorized Signature & Seal'}</div>
      </div>
    </div>

    <!-- Bottom Disclaimer -->
    <footer class="doc-footer">
      <div>${isBengali ? 'কম্পিউটার/মোবাইল জেনারেটেড ডিজিটাল খাতা স্টেটমেন্ট • কোনো কাটাকাটি গ্রহণযোগ্য নয়।' : 'Computer-generated digital ledger statement • No alterations valid.'}</div>
      <div style="margin-top: 3px; font-weight: 500;">${isBengali ? 'বাকি খাতা অ্যাপের মাধ্যমে তৈরি' : 'Generated via Baki Khata App'}</div>
    </footer>
  </div>
</body>
</html>
''';
  }

  /// Generates the HTML string for store-wide master statement summary.
  static String buildStoreStatementHtml(
    StoreStatementData data, {
    bool isBengali = true,
  }) {
    final currency = data.settings.currencySymbol;
    final shopName = data.settings.shopName.trim().isEmpty ? 'My Shop' : data.settings.shopName.trim();
    final proprietor = data.settings.proprietorName?.trim();
    final shopPhone = data.settings.shopPhone?.trim();
    final shopAddress = data.settings.shopAddress?.trim();

    final logoDataUri = _getImageDataUri(data.settings.shopLogoPath);
    final customSealDataUri = data.settings.shopSealType == 'custom'
        ? _getImageDataUri(data.settings.customSealPath)
        : null;

    final totalOpening = formatAmount(data.totalOpeningBalance, isBengali: isBengali, currencySymbol: currency);
    final totalBaki = formatAmount(data.totalBaki, isBengali: isBengali, currencySymbol: currency);
    final totalPayment = formatAmount(data.totalPayment, isBengali: isBengali, currencySymbol: currency);
    final totalClosing = formatAmount(data.totalClosingBalance, isBengali: isBengali, currencySymbol: currency);

    final periodLabel = data.period.getDateRangeFormatted(isBengali: isBengali);
    final generatedAtStr = formatDate(data.generatedAt, isBengali: isBengali, withTime: true);

    final rowsHtml = StringBuffer();
    for (int i = 0; i < data.customerSummaries.length; i++) {
      final item = data.customerSummaries[i];
      final sl = isBengali ? PhoneUtils.toBengaliNumber((i + 1).toString()) : (i + 1).toString();
      final op = formatAmount(item.openingBalance, isBengali: isBengali, currencySymbol: currency);
      final bk = formatAmount(item.periodBaki, isBengali: isBengali, currencySymbol: currency);
      final pm = formatAmount(item.periodPayment, isBengali: isBengali, currencySymbol: currency);
      final cl = formatAmount(item.closingBalance, isBengali: isBengali, currencySymbol: currency);

      final phoneStr = item.customer.phone != null && item.customer.phone!.isNotEmpty
          ? '<br><small style="color: #607d8b;">📞 ${item.customer.phone}</small>'
          : '';

      rowsHtml.writeln('''
        <tr>
          <td style="text-align: center;">$sl</td>
          <td><strong>${item.customer.name}</strong>$phoneStr</td>
          <td style="text-align: right;">$op</td>
          <td style="text-align: right; color: #b71c1c;">$bk</td>
          <td style="text-align: right; color: #1b5e20;">$pm</td>
          <td style="text-align: right; font-weight: bold; ${item.closingBalance > 0 ? 'color: #c62828;' : 'color: #2e7d32;'}">$cl</td>
        </tr>
      ''');
    }

    final sealHtml = _buildSealHtml(
      shopName: shopName,
      customSealDataUri: customSealDataUri,
      isBengali: isBengali,
      dateStr: formatDate(data.generatedAt, isBengali: isBengali),
    );

    return '''
<!DOCTYPE html>
<html lang="${isBengali ? 'bn' : 'en'}">
<head>
  <meta charset="utf-8">
  <title>Store Master Ledger - $shopName</title>
  <style>
    ${_getCommonCss()}
  </style>
</head>
<body>
  <div class="page-container">
    <!-- Header -->
    <header class="header">
      <div class="shop-brand">
        ${logoDataUri != null ? '<img src="$logoDataUri" class="shop-logo" alt="Logo">' : ''}
        <div class="shop-details">
          <h1 class="shop-name">$shopName</h1>
          ${proprietor != null && proprietor.isNotEmpty ? '<div class="proprietor-text">${isBengali ? 'স্বত্বাধিকারী:' : 'Proprietor:'} $proprietor</div>' : ''}
          ${shopAddress != null && shopAddress.isNotEmpty ? '<div class="contact-info">📍 $shopAddress</div>' : ''}
          ${shopPhone != null && shopPhone.isNotEmpty ? '<div class="contact-info">📞 $shopPhone</div>' : ''}
        </div>
      </div>
      <div class="doc-meta">
        <div class="doc-badge">${isBengali ? 'দোকানের মহাজন মাস্টার লেজার' : 'STORE MASTER LEDGER'}</div>
        <div class="meta-row"><strong>${isBengali ? 'রিপোর্ট কোড:' : 'Report #:'}</strong> ${data.statementNumber}</div>
        <div class="meta-row"><strong>${isBengali ? 'তারিখ:' : 'Date:'}</strong> $generatedAtStr</div>
        <div class="meta-row"><strong>${isBengali ? 'সময়কাল:' : 'Period:'}</strong> $periodLabel</div>
      </div>
    </header>

    <div class="divider"></div>

    <!-- Financial KPI Summary Cards -->
    <div class="kpi-grid">
      <div class="kpi-card">
        <div class="kpi-label">${isBengali ? 'দোকানের প্রারম্ভিক বাকি' : 'Total Opening Due'}</div>
        <div class="kpi-value">$totalOpening</div>
      </div>
      <div class="kpi-card">
        <div class="kpi-label">${isBengali ? 'মোট নতুন বাকি (+)' : 'Total Credit (+)'}</div>
        <div class="kpi-value baki-text">+$totalBaki</div>
      </div>
      <div class="kpi-card">
        <div class="kpi-label">${isBengali ? 'মোট আদায়/জমা (-)' : 'Total Collected (-)'}</div>
        <div class="kpi-value payment-text">-$totalPayment</div>
      </div>
      <div class="kpi-card kpi-highlight">
        <div class="kpi-label">${isBengali ? 'দোকানের মোট পাওনা' : 'Net Closing Due'}</div>
        <div class="kpi-value">$totalClosing</div>
      </div>
    </div>

    <!-- Master Customers Table -->
    <table class="ledger-table">
      <thead>
        <tr>
          <th style="width: 6%; text-align: center;">${isBengali ? 'নং' : 'SL'}</th>
          <th style="width: 34%;">${isBengali ? 'গ্রাহকের নাম ও ফোন' : 'Customer Name'}</th>
          <th style="width: 15%; text-align: right;">${isBengali ? 'পূর্বের জের' : 'Opening'}</th>
          <th style="width: 15%; text-align: right;">${isBengali ? 'এই সময়ে বাকি' : 'Credit (+)'}</th>
          <th style="width: 15%; text-align: right;">${isBengali ? 'এই সময়ে জমা' : 'Payment (-)'}</th>
          <th style="width: 15%; text-align: right;">${isBengali ? 'বর্তমান বাকি' : 'Closing'}</th>
        </tr>
      </thead>
      <tbody>
        ${rowsHtml.toString()}
      </tbody>
      <tfoot>
        <tr class="total-row">
          <td colspan="2" style="text-align: right; font-weight: bold;">${isBengali ? 'দোকানের সর্বমোট হিসাব:' : 'Store Totals:'}</td>
          <td style="text-align: right; font-weight: bold;">$totalOpening</td>
          <td style="text-align: right; color: #b71c1c; font-weight: bold;">$totalBaki</td>
          <td style="text-align: right; color: #1b5e20; font-weight: bold;">$totalPayment</td>
          <td style="text-align: right; font-weight: bold; background: #e0f2f1;">$totalClosing</td>
        </tr>
      </tfoot>
    </table>

    <!-- Authentication and Signatures -->
    <div class="footer-signatures">
      <div class="seal-container" style="margin: 0 auto;">
        $sealHtml
      </div>
      <div class="sig-box">
        <div class="sig-line"></div>
        <div class="sig-label">${isBengali ? 'স্বত্বাধিকারীর স্বাক্ষর ও সিল' : 'Authorized Signature & Seal'}</div>
      </div>
    </div>

    <!-- Bottom Disclaimer -->
    <footer class="doc-footer">
      <div>${isBengali ? 'বাকি খাতা অ্যাপ দ্বারা সংকলিত গোপনীয় দোকান অডিট ও মহাজন খাতা।' : 'Confidential store audit ledger generated by Baki Khata App.'}</div>
    </footer>
  </div>
</body>
</html>
''';
  }

  static String _buildSealHtml({
    required String shopName,
    required String? customSealDataUri,
    required bool isBengali,
    required String dateStr,
  }) {
    if (customSealDataUri != null) {
      return '''
        <div class="custom-seal-box">
          <img src="$customSealDataUri" class="custom-seal-img" alt="Seal">
        </div>
      ''';
    }

    // Auto-generated SVG Vector Official Seal
    return '''
      <div class="auto-seal">
        <svg viewBox="0 0 140 140" width="105" height="105">
          <!-- Outer circle -->
          <circle cx="70" cy="70" r="66" fill="none" stroke="#004d40" stroke-width="2.5" stroke-dasharray="4,2"/>
          <!-- Inner circle -->
          <circle cx="70" cy="70" r="58" fill="none" stroke="#00695c" stroke-width="1.8"/>
          <!-- Inner decorative circle -->
          <circle cx="70" cy="70" r="42" fill="#e0f2f1" fill-opacity="0.3" stroke="#00695c" stroke-width="1"/>
          
          <!-- Shop Name text curved/centered -->
          <text x="70" y="32" text-anchor="middle" font-size="9" font-weight="bold" fill="#004d40">$shopName</text>
          
          <!-- Center Badge -->
          <circle cx="70" cy="58" r="10" fill="#00695c"/>
          <path d="M65 58 L68 62 L75 54" fill="none" stroke="#ffffff" stroke-width="2" stroke-linecap="round"/>
          
          <text x="70" y="80" text-anchor="middle" font-size="9" font-weight="bold" fill="#004d40">${isBengali ? 'অনুমোদিত হিসাব' : 'VERIFIED'}</text>
          <text x="70" y="93" text-anchor="middle" font-size="7" fill="#00796b">${isBengali ? 'যাচাইকৃত লেজার' : 'APPROVED'}</text>
          <text x="70" y="112" text-anchor="middle" font-size="7" fill="#546e7a">$dateStr</text>
        </svg>
      </div>
    ''';
  }

  static String _buildDigitalPaymentsHtml(AppSettings settings, bool isBengali) {
    if (!settings.hasDigitalPaymentMethods) return '';
    final buffer = StringBuffer();
    buffer.write('<div class="contact-info" style="margin-top: 4px; font-size: 11px;">💳 ');
    final parts = <String>[];
    if (settings.bkashNumber != null && settings.bkashNumber!.isNotEmpty) {
      parts.add('বিকাশ: ${settings.bkashNumber}');
    }
    if (settings.nagadNumber != null && settings.nagadNumber!.isNotEmpty) {
      parts.add('নগদ: ${settings.nagadNumber}');
    }
    if (settings.rocketNumber != null && settings.rocketNumber!.isNotEmpty) {
      parts.add('রকেট: ${settings.rocketNumber}');
    }
    buffer.write(parts.join(' | '));
    buffer.write('</div>');
    return buffer.toString();
  }

  static String? _getImageDataUri(String? path) {
    if (path == null || path.isEmpty) return null;
    try {
      final file = File(path);
      if (file.existsSync()) {
        final bytes = file.readAsBytesSync();
        final ext = path.toLowerCase().endsWith('.png') ? 'png' : 'jpeg';
        final b64 = base64Encode(bytes);
        return 'data:image/$ext;base64,$b64';
      }
    } catch (_) {}
    return null;
  }

  static String _getCommonCss() {
    return '''
    @page {
      size: A4;
      margin: 10mm 10mm 12mm 10mm;
    }
    * {
      box-sizing: border-box;
      margin: 0;
      padding: 0;
    }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Hind Siliguri", "Noto Sans Bengali", Kalpurush, sans-serif;
      font-size: 12px;
      line-height: 1.4;
      color: #1a1a1a;
      background: #ffffff;
      -webkit-print-color-adjust: exact;
      print-color-adjust: exact;
    }
    .page-container {
      width: 100%;
      padding: 4px;
    }
    .header {
      display: flex;
      justify-content: space-between;
      align-items: flex-start;
      margin-bottom: 12px;
    }
    .shop-brand {
      display: flex;
      align-items: flex-start;
      gap: 12px;
      max-width: 60%;
    }
    .shop-logo {
      width: 65px;
      height: 65px;
      object-fit: contain;
      border-radius: 8px;
      border: 1px solid #cfd8dc;
    }
    .shop-name {
      font-size: 20px;
      font-weight: 800;
      color: #004d40;
      margin-bottom: 2px;
    }
    .proprietor-text {
      font-size: 12px;
      font-weight: 600;
      color: #37474f;
      margin-bottom: 2px;
    }
    .contact-info {
      font-size: 11px;
      color: #546e7a;
    }
    .doc-meta {
      text-align: right;
      max-width: 40%;
    }
    .doc-badge {
      display: inline-block;
      background: #00695c;
      color: #ffffff;
      font-size: 12px;
      font-weight: 700;
      padding: 4px 12px;
      border-radius: 4px;
      margin-bottom: 8px;
      letter-spacing: 0.5px;
    }
    .meta-row {
      font-size: 11px;
      color: #37474f;
      margin-bottom: 2px;
    }
    .divider {
      height: 2px;
      background: #00695c;
      margin-bottom: 12px;
    }
    .customer-card {
      display: flex;
      justify-content: space-between;
      background: #f4f7f5;
      border: 1px solid #cfd8dc;
      border-radius: 6px;
      padding: 10px 14px;
      margin-bottom: 12px;
    }
    .card-title {
      font-size: 10px;
      text-transform: uppercase;
      font-weight: bold;
      color: #78909c;
      margin-bottom: 4px;
      letter-spacing: 0.5px;
    }
    .cust-name {
      font-size: 15px;
      font-weight: bold;
      color: #191c1b;
    }
    .cust-meta {
      font-size: 11px;
      color: #546e7a;
    }
    .status-box {
      text-align: right;
    }
    .status-label {
      font-size: 10px;
      font-weight: bold;
      text-transform: uppercase;
    }
    .status-amount {
      font-size: 16px;
      font-weight: 800;
    }
    .status-due .status-label { color: #c62828; }
    .status-due .status-amount { color: #b71c1c; }
    .status-advance .status-label { color: #00838f; }
    .status-advance .status-amount { color: #006064; }
    .status-settled .status-label { color: #2e7d32; }
    .status-settled .status-amount { color: #1b5e20; }

    .kpi-grid {
      display: grid;
      grid-template-columns: repeat(4, 1fr);
      gap: 8px;
      margin-bottom: 14px;
    }
    .kpi-card {
      background: #ffffff;
      border: 1px solid #cfd8dc;
      border-radius: 6px;
      padding: 8px;
      text-align: center;
    }
    .kpi-highlight {
      background: #e0f2f1;
      border-color: #80cbc4;
    }
    .kpi-label {
      font-size: 10px;
      color: #607d8b;
      margin-bottom: 2px;
    }
    .kpi-value {
      font-size: 14px;
      font-weight: bold;
      color: #263238;
    }
    .baki-text { color: #c62828; }
    .payment-text { color: #2e7d32; }

    .ledger-table {
      width: 100%;
      border-collapse: collapse;
      margin-bottom: 20px;
      font-size: 11px;
    }
    .ledger-table th {
      background: #00695c;
      color: #ffffff;
      padding: 7px 6px;
      text-align: left;
      font-weight: 600;
      border: 1px solid #004d40;
    }
    .ledger-table td {
      padding: 6px;
      border: 1px solid #e0e0e0;
      vertical-align: top;
    }
    .ledger-table tbody tr:nth-child(even) {
      background: #f9fbfb;
    }
    .opening-row {
      background: #f1f8e9 !important;
      font-style: italic;
    }
    .total-row td {
      padding: 8px 6px;
      background: #eceff1;
      border-top: 2px solid #00695c;
      font-size: 12px;
    }
    .badge {
      display: inline-block;
      font-size: 9px;
      font-weight: bold;
      padding: 1px 5px;
      border-radius: 3px;
      margin-right: 3px;
    }
    .badge-baki {
      background: #ffebee;
      color: #c62828;
      border: 1px solid #ffcdd2;
    }
    .badge-payment {
      background: #e8f5e9;
      color: #2e7d32;
      border: 1px solid #c8e6c9;
    }
    .item-list {
      margin: 3px 0 0 14px;
      padding: 0;
      color: #37474f;
      font-size: 10px;
    }
    .note-text {
      color: #546e7a;
      font-size: 10px;
      margin-top: 2px;
    }

    .footer-signatures {
      display: flex;
      justify-content: space-between;
      align-items: flex-end;
      margin-top: 30px;
      padding: 0 10px;
      page-break-inside: avoid;
    }
    .sig-box {
      text-align: center;
      width: 170px;
    }
    .sig-line {
      border-top: 1px dashed #78909c;
      margin-bottom: 6px;
    }
    .sig-label {
      font-size: 11px;
      font-weight: 600;
      color: #37474f;
    }
    .seal-container {
      text-align: center;
    }
    .auto-seal {
      display: inline-block;
    }
    .custom-seal-box {
      width: 90px;
      height: 90px;
      display: inline-block;
    }
    .custom-seal-img {
      max-width: 100%;
      max-height: 100%;
      object-fit: contain;
    }

    .doc-footer {
      margin-top: 24px;
      border-top: 1px solid #e0e0e0;
      padding-top: 6px;
      text-align: center;
      font-size: 10px;
      color: #78909c;
      page-break-inside: avoid;
    }
    ''';
  }
}
