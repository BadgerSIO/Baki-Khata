import 'dart:io';
import 'package:flutter/services.dart';
import 'package:bangla_pdf_fixer/bangla_pdf_fixer.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

import '../../vouchers/voucher_model.dart';
import '../models/statement_models.dart';

class PdfDocumentBuilder {
  static ShapedFont? _cachedRegFont;
  static ShapedFont? _cachedBoldFont;
  static ShapedFont? _cachedLatinFont;

  /// Loads and caches the TrueType Bengali and Latin fonts.
  static Future<void> _ensureFontsLoaded() async {
    if (_cachedRegFont != null && _cachedBoldFont != null && _cachedLatinFont != null) {
      return;
    }

    try {
      Uint8List regBytes;
      Uint8List boldBytes;
      Uint8List latinBytes;

      try {
        final regData = await rootBundle.load('assets/fonts/NotoSansBengali-Regular.ttf');
        final boldData = await rootBundle.load('assets/fonts/NotoSansBengali-Bold.ttf');
        final latinData = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
        regBytes = regData.buffer.asUint8List();
        boldBytes = boldData.buffer.asUint8List();
        latinBytes = latinData.buffer.asUint8List();
      } catch (_) {
        // Fallback for tests or local execution
        regBytes = await File('assets/fonts/NotoSansBengali-Regular.ttf').readAsBytes();
        boldBytes = await File('assets/fonts/NotoSansBengali-Bold.ttf').readAsBytes();
        latinBytes = await File('assets/fonts/NotoSans-Regular.ttf').readAsBytes();
      }

      _cachedRegFont = ShapedFont.fromBytes(regBytes);
      _cachedBoldFont = ShapedFont.fromBytes(boldBytes);
      _cachedLatinFont = ShapedFont.fromBytes(latinBytes);
    } catch (e) {
      // ignore
    }
  }

  /// Formats currency with optional Bengali digits.
  static String formatAmount(double amount, {bool isBengali = true, String currencySymbol = '৳'}) {
    final fmt = (amount.abs() % 1 == 0)
        ? NumberFormat('#,##0')
        : NumberFormat('#,##0.00');
    final formatted = fmt.format(amount.abs());
    final numStr = isBengali ? PhoneUtils.toBengaliNumber(formatted) : formatted;
    final sign = amount < 0 ? '-' : '';
    return '$sign$currencySymbol $numStr';
  }

  /// Formats date.
  static String formatDate(DateTime dt, {bool isBengali = true, bool withTime = false}) {
    final pattern = withTime ? 'dd MMM yyyy, hh:mm a' : 'dd MMM yyyy';
    final fmt = DateFormat(pattern).format(dt.toLocal());
    return isBengali ? PhoneUtils.toBengaliNumber(fmt) : fmt;
  }

  /// Helper to create a shaped Bengali/English text widget.
  static pw.Widget text(
    String str, {
    bool bold = false,
    double size = 9,
    PdfColor? color,
    ShapedTextAlign align = ShapedTextAlign.start,
  }) {
    final primaryFont = bold ? (_cachedBoldFont ?? _cachedRegFont) : _cachedRegFont;
    final fallbacks = <ShapedFont>[
      ?_cachedLatinFont,
    ];

    if (primaryFont == null) {
      return pw.Text(
        str,
        style: pw.TextStyle(
          fontSize: size,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color,
        ),
      );
    }

    return BanglaText(
      str,
      font: primaryFont,
      fallbackFonts: fallbacks,
      fontSize: size,
      color: color ?? PdfColor.fromHex('#212121'),
      align: align,
    );
  }

  /// Builds a complete single customer statement [pw.Document].
  static Future<pw.Document> buildCustomerStatementDoc(
    CustomerStatementData data, {
    bool isBengali = true,
  }) async {
    await _ensureFontsLoaded();

    final currency = data.settings.currencySymbol;
    final shopName = data.settings.shopName.trim().isEmpty ? 'My Shop' : data.settings.shopName.trim();
    final proprietor = data.settings.proprietorName?.trim();
    final shopPhone = data.settings.shopPhone?.trim();
    final shopAddress = data.settings.shopAddress?.trim();

    final openingFormatted = formatAmount(data.openingBalance, isBengali: isBengali, currencySymbol: currency);
    final bakiFormatted = formatAmount(data.totalBaki, isBengali: isBengali, currencySymbol: currency);
    final paymentFormatted = formatAmount(data.totalPayment, isBengali: isBengali, currencySymbol: currency);
    final closingFormatted = formatAmount(data.closingBalance, isBengali: isBengali, currencySymbol: currency);

    final periodLabel = data.period.getDateRangeFormatted(isBengali: isBengali);
    final generatedAtStr = formatDate(data.generatedAt, isBengali: isBengali, withTime: true);

    // Optional logo image
    pw.MemoryImage? logoImage;
    if (data.settings.shopLogoPath != null && data.settings.shopLogoPath!.isNotEmpty) {
      try {
        final f = File(data.settings.shopLogoPath!);
        if (f.existsSync()) {
          logoImage = pw.MemoryImage(f.readAsBytesSync());
        }
      } catch (_) {}
    }

    // Optional custom seal image
    pw.MemoryImage? customSealImage;
    if (data.settings.shopSealType == 'custom' && data.settings.customSealPath != null) {
      try {
        final f = File(data.settings.customSealPath!);
        if (f.existsSync()) {
          customSealImage = pw.MemoryImage(f.readAsBytesSync());
        }
      } catch (_) {}
    }

    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        build: (pw.Context context) {
          final tableRows = <pw.TableRow>[];

          // 1. Table Header
          tableRows.add(
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColor.fromHex('#004d40')),
              children: [
                _cell(text(isBengali ? 'নং' : 'SL', bold: true, size: 8.5, color: PdfColors.white, align: ShapedTextAlign.center)),
                _cell(text(isBengali ? 'তারিখ' : 'Date', bold: true, size: 8.5, color: PdfColors.white)),
                _cell(text(isBengali ? 'চালান #' : 'Voucher #', bold: true, size: 8.5, color: PdfColors.white)),
                _cell(text(isBengali ? 'বিবরণ ও পণ্য' : 'Description', bold: true, size: 8.5, color: PdfColors.white)),
                _cell(text(isBengali ? 'বাকি (+)' : 'Debit (+)', bold: true, size: 8.5, color: PdfColors.white, align: ShapedTextAlign.end)),
                _cell(text(isBengali ? 'জমা (-)' : 'Credit (-)', bold: true, size: 8.5, color: PdfColors.white, align: ShapedTextAlign.end)),
                _cell(text(isBengali ? 'চলতি জের' : 'Balance', bold: true, size: 8.5, color: PdfColors.white, align: ShapedTextAlign.end)),
              ],
            ),
          );

          // 2. Opening Balance Row
          tableRows.add(
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColor.fromHex('#f5f5f5')),
              children: [
                _cell(text('-', size: 8.5, align: ShapedTextAlign.center)),
                _cell(text(isBengali ? 'প্রারম্ভিক জের' : 'Opening Bal', bold: true, size: 8.5)),
                _cell(text('-', size: 8.5)),
                _cell(text(isBengali ? 'হিসাব শুরু করার পূর্বের জের' : 'Balance carried forward', size: 8.5)),
                _cell(text(data.openingBalance > 0 ? openingFormatted : '-', size: 8.5, align: ShapedTextAlign.end)),
                _cell(text(data.openingBalance < 0 ? openingFormatted : '-', size: 8.5, align: ShapedTextAlign.end)),
                _cell(text(openingFormatted, bold: true, size: 8.5, align: ShapedTextAlign.end)),
              ],
            ),
          );

          // 3. Transactions Rows
          for (int i = 0; i < data.entries.length; i++) {
            final entry = data.entries[i];
            final sl = isBengali ? PhoneUtils.toBengaliNumber((i + 1).toString()) : (i + 1).toString();
            final dateStr = formatDate(entry.date, isBengali: isBengali);
            final debitStr = entry.isBaki
                ? formatAmount(entry.debit, isBengali: isBengali, currencySymbol: currency)
                : '-';
            final creditStr = !entry.isBaki
                ? formatAmount(entry.credit, isBengali: isBengali, currencySymbol: currency)
                : '-';
            final runningStr = formatAmount(entry.runningBalance, isBengali: isBengali, currencySymbol: currency);

            String descText = '';
            if (data.isDetailed && entry.items.isNotEmpty) {
              final itemSummary = entry.items.map((it) {
                final qty = it.quantity != null && it.quantity!.isNotEmpty ? ' (${it.quantity})' : '';
                return '${it.name}$qty';
              }).join(', ');
              descText = itemSummary;
              if (entry.notes != null && entry.notes!.trim().isNotEmpty) {
                descText += ' | ${entry.notes!.trim()}';
              }
            } else if (entry.notes != null && entry.notes!.trim().isNotEmpty) {
              descText = entry.notes!.trim();
            } else {
              descText = entry.isBaki
                  ? (isBengali ? 'পণ্য/সেবা বিক্রয়' : 'Credit Purchase')
                  : (isBengali ? 'নগদ/অনলাইন জমা' : 'Payment Received');
            }

            final isAlt = i % 2 == 1;
            tableRows.add(
              pw.TableRow(
                decoration: isAlt ? pw.BoxDecoration(color: PdfColor.fromHex('#fbfcfb')) : null,
                children: [
                  _cell(text(sl, size: 8.5, align: ShapedTextAlign.center)),
                  _cell(text(dateStr, size: 8.5)),
                  _cell(text(entry.voucherNumber, size: 8.5)),
                  _cell(text(descText, size: 8.5)),
                  _cell(text(debitStr, bold: entry.isBaki, size: 8.5, color: entry.isBaki ? PdfColor.fromHex('#b71c1c') : null, align: ShapedTextAlign.end)),
                  _cell(text(creditStr, bold: !entry.isBaki, size: 8.5, color: !entry.isBaki ? PdfColor.fromHex('#1b5e20') : null, align: ShapedTextAlign.end)),
                  _cell(text(runningStr, bold: true, size: 8.5, align: ShapedTextAlign.end)),
                ],
              ),
            );
          }

          // 4. Footer Total Row
          tableRows.add(
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColor.fromHex('#e0f2f1')),
              children: [
                _cell(text('', size: 8.5)),
                _cell(text('', size: 8.5)),
                _cell(text('', size: 8.5)),
                _cell(text(isBengali ? 'সর্বমোট যোগফল:' : 'Total Sum:', bold: true, size: 8.5, align: ShapedTextAlign.end)),
                _cell(text(bakiFormatted, bold: true, size: 8.5, color: PdfColor.fromHex('#b71c1c'), align: ShapedTextAlign.end)),
                _cell(text(paymentFormatted, bold: true, size: 8.5, color: PdfColor.fromHex('#1b5e20'), align: ShapedTextAlign.end)),
                _cell(text(closingFormatted, bold: true, size: 8.5, align: ShapedTextAlign.end)),
              ],
            ),
          );

          // Payment badges line
          final paymentBadges = <String>[];
          if (data.settings.bkashNumber != null && data.settings.bkashNumber!.isNotEmpty) {
            paymentBadges.add('বিকাশ: ${data.settings.bkashNumber}');
          }
          if (data.settings.nagadNumber != null && data.settings.nagadNumber!.isNotEmpty) {
            paymentBadges.add('নগদ: ${data.settings.nagadNumber}');
          }
          if (data.settings.rocketNumber != null && data.settings.rocketNumber!.isNotEmpty) {
            paymentBadges.add('রকেট: ${data.settings.rocketNumber}');
          }
          final paymentLine = paymentBadges.join(' | ');

          return [
            // Header Row
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (logoImage != null) ...[
                      pw.Container(
                        width: 48,
                        height: 48,
                        margin: const pw.EdgeInsets.only(right: 10),
                        decoration: pw.BoxDecoration(
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                          image: pw.DecorationImage(image: logoImage, fit: pw.BoxFit.contain),
                        ),
                      ),
                    ],
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        text(shopName, bold: true, size: 17, color: PdfColor.fromHex('#004d40')),
                        if (proprietor != null && proprietor.isNotEmpty) ...[
                          pw.SizedBox(height: 1),
                          text('${isBengali ? 'স্বত্বাধিকারী:' : 'Proprietor:'} $proprietor', bold: true, size: 9.5, color: PdfColor.fromHex('#37474f')),
                        ],
                        if (shopAddress != null && shopAddress.isNotEmpty) ...[
                          text(shopAddress, size: 8.5, color: PdfColor.fromHex('#546e7a')),
                        ],
                        if (shopPhone != null && shopPhone.isNotEmpty) ...[
                          text('${isBengali ? 'ফোন:' : 'Phone:'} $shopPhone', size: 8.5, color: PdfColor.fromHex('#546e7a')),
                        ],
                        if (paymentLine.isNotEmpty) ...[
                          pw.SizedBox(height: 2),
                          text(paymentLine, bold: true, size: 8.5, color: PdfColor.fromHex('#00695c')),
                        ],
                      ],
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromHex('#00695c'),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                      ),
                      child: text(isBengali ? 'গ্রাহক হিসাব বিবরণী' : 'CUSTOMER STATEMENT', bold: true, size: 10.5, color: PdfColors.white),
                    ),
                    pw.SizedBox(height: 4),
                    text('${isBengali ? 'স্টেটমেন্ট নং:' : 'Statement #:'} ${data.statementNumber}', size: 8.5, color: PdfColor.fromHex('#546e7a')),
                    text('${isBengali ? 'তারিখ:' : 'Date:'} $generatedAtStr', size: 8.5, color: PdfColor.fromHex('#546e7a')),
                    text('${isBengali ? 'সময়কাল:' : 'Period:'} $periodLabel', size: 8.5, color: PdfColor.fromHex('#546e7a')),
                  ],
                ),
              ],
            ),

            pw.SizedBox(height: 8),
            pw.Divider(color: PdfColor.fromHex('#b0bec5'), thickness: 0.8),
            pw.SizedBox(height: 8),

            // Customer Details & Overivew Card
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#f4fbf7'),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                border: pw.Border.all(color: PdfColor.fromHex('#c8e6c9'), width: 1),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      text('${isBengali ? 'গ্রাহকের নাম:' : 'Customer:'} ${data.customer.name}', bold: true, size: 12, color: PdfColor.fromHex('#1b5e20')),
                      pw.SizedBox(height: 2),
                      text(
                        '${data.customer.phone != null ? '${isBengali ? 'ফোন:' : 'Phone:'} ${data.customer.phone}' : ''}${data.customer.address != null && data.customer.address!.isNotEmpty ? ' | ${data.customer.address}' : ''}',
                        size: 9,
                        color: PdfColor.fromHex('#37474f'),
                      ),
                    ],
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: pw.BoxDecoration(
                      color: data.closingBalance > 0
                          ? PdfColor.fromHex('#ffebee')
                          : (data.closingBalance < 0 ? PdfColor.fromHex('#e8f5e9') : PdfColor.fromHex('#e0f2f1')),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                      border: pw.Border.all(
                        color: data.closingBalance > 0
                            ? PdfColor.fromHex('#ef9a9a')
                            : (data.closingBalance < 0 ? PdfColor.fromHex('#a5d6a7') : PdfColor.fromHex('#80cbc4')),
                        width: 1,
                      ),
                    ),
                    child: pw.Column(
                      children: [
                        text(
                          data.closingBalance > 0
                              ? (isBengali ? 'বর্তমান সর্বমোট বাকি' : 'Total Net Due')
                              : (data.closingBalance < 0
                                  ? (isBengali ? 'অগ্রিম জমা' : 'Advance Balance')
                                  : (isBengali ? 'হিসাব পরিশোধিত' : 'Fully Settled')),
                          size: 8.5,
                          color: data.closingBalance > 0
                              ? PdfColor.fromHex('#b71c1c')
                              : (data.closingBalance < 0 ? PdfColor.fromHex('#1b5e20') : PdfColor.fromHex('#004d40')),
                        ),
                        text(
                          closingFormatted,
                          bold: true,
                          size: 13,
                          color: data.closingBalance > 0
                              ? PdfColor.fromHex('#b71c1c')
                              : (data.closingBalance < 0 ? PdfColor.fromHex('#1b5e20') : PdfColor.fromHex('#004d40')),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 10),

            // KPI Grid
            pw.Row(
              children: [
                _kpiBox(isBengali ? 'পূর্বের জের' : 'Opening', openingFormatted, '#e0f2f1', '#004d40'),
                pw.SizedBox(width: 8),
                _kpiBox(isBengali ? 'মোট বাকি (+)' : 'Total Debit (+)', bakiFormatted, '#ffebee', '#b71c1c'),
                pw.SizedBox(width: 8),
                _kpiBox(isBengali ? 'মোট জমা (-)' : 'Total Credit (-)', paymentFormatted, '#e8f5e9', '#1b5e20'),
                pw.SizedBox(width: 8),
                _kpiBox(isBengali ? 'বর্তমান জের' : 'Net Balance', closingFormatted, '#ffebee', '#b71c1c'),
              ],
            ),

            pw.SizedBox(height: 12),

            // Table
            pw.Table(
              border: pw.TableBorder.all(color: PdfColor.fromHex('#cfd8dc'), width: 0.5),
              children: tableRows,
            ),

            pw.Spacer(),

            // Signatures & Official Seal
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Column(
                  children: [
                    pw.Container(width: 120, height: 1, color: PdfColor.fromHex('#90a4ae')),
                    pw.SizedBox(height: 4),
                    text(isBengali ? 'গ্রাহকের স্বাক্ষর' : 'Customer Signature', size: 9, color: PdfColor.fromHex('#546e7a')),
                  ],
                ),
                // Official Seal Box
                if (customSealImage != null) ...[
                  pw.Container(
                    width: 80,
                    height: 80,
                    child: pw.Image(customSealImage, fit: pw.BoxFit.contain),
                  ),
                ] else ...[
                  pw.Container(
                    width: 85,
                    height: 85,
                    decoration: pw.BoxDecoration(
                      shape: pw.BoxShape.circle,
                      border: pw.Border.all(color: PdfColor.fromHex('#00695c'), width: 1.8),
                      color: PdfColor.fromHex('#f0fdf4'),
                    ),
                    child: pw.Center(
                      child: pw.Column(
                        mainAxisAlignment: pw.MainAxisAlignment.center,
                        children: [
                          text(isBengali ? '[ অনুমোদিত ]' : '[ VERIFIED ]', bold: true, size: 7.5, color: PdfColor.fromHex('#004d40'), align: ShapedTextAlign.center),
                          text(shopName, bold: true, size: 8.5, color: PdfColor.fromHex('#004d40'), align: ShapedTextAlign.center),
                          text(isBengali ? 'যাচাইকৃত খতিয়ান' : 'Audited Ledger', size: 6.5, color: PdfColor.fromHex('#00695c'), align: ShapedTextAlign.center),
                          text(formatDate(data.generatedAt, isBengali: isBengali), size: 6.5, color: PdfColor.fromHex('#546e7a'), align: ShapedTextAlign.center),
                        ],
                      ),
                    ),
                  ),
                ],
                pw.Column(
                  children: [
                    pw.Container(width: 120, height: 1, color: PdfColor.fromHex('#90a4ae')),
                    pw.SizedBox(height: 4),
                    text(isBengali ? 'স্বত্বাধিকারীর স্বাক্ষর ও সিল' : 'Authorized Signature & Seal', size: 9, color: PdfColor.fromHex('#546e7a')),
                  ],
                ),
              ],
            ),

            pw.SizedBox(height: 10),
            pw.Center(
              child: text(
                isBengali
                    ? 'কম্পিউটার/মোবাইল জেনারেটেড ডিজিটাল খাতা স্টেটমেন্ট | কোনো কাটাকাটি গ্রহণযোগ্য নয় | বাকি খাতা অ্যাপ'
                    : 'Computer-generated digital ledger statement | No alterations valid | Baki Khata App',
                size: 7.5,
                color: PdfColor.fromHex('#78909c'),
                align: ShapedTextAlign.center,
              ),
            ),
          ];
        },
      ),
    );

    return doc;
  }

  /// Builds a complete store-wide master statement [pw.Document].
  static Future<pw.Document> buildStoreStatementDoc(
    StoreStatementData data, {
    bool isBengali = true,
  }) async {
    await _ensureFontsLoaded();

    final currency = data.settings.currencySymbol;
    final shopName = data.settings.shopName.trim().isEmpty ? 'My Shop' : data.settings.shopName.trim();
    final proprietor = data.settings.proprietorName?.trim();
    final shopPhone = data.settings.shopPhone?.trim();
    final shopAddress = data.settings.shopAddress?.trim();

    final totalOpening = formatAmount(data.totalOpeningBalance, isBengali: isBengali, currencySymbol: currency);
    final totalBaki = formatAmount(data.totalBaki, isBengali: isBengali, currencySymbol: currency);
    final totalPayment = formatAmount(data.totalPayment, isBengali: isBengali, currencySymbol: currency);
    final totalClosing = formatAmount(data.totalClosingBalance, isBengali: isBengali, currencySymbol: currency);

    final periodLabel = data.period.getDateRangeFormatted(isBengali: isBengali);
    final generatedAtStr = formatDate(data.generatedAt, isBengali: isBengali, withTime: true);

    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        build: (pw.Context context) {
          final tableRows = <pw.TableRow>[];

          // 1. Table Header
          tableRows.add(
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColor.fromHex('#004d40')),
              children: [
                _cell(text(isBengali ? 'নং' : 'SL', bold: true, size: 8.5, color: PdfColors.white, align: ShapedTextAlign.center)),
                _cell(text(isBengali ? 'খরিদ্দারের নাম ও ফোন' : 'Customer Name & Phone', bold: true, size: 8.5, color: PdfColors.white)),
                _cell(text(isBengali ? 'পূর্বের জের' : 'Opening Bal', bold: true, size: 8.5, color: PdfColors.white, align: ShapedTextAlign.end)),
                _cell(text(isBengali ? 'বাকি (+)' : 'Period Debit (+)', bold: true, size: 8.5, color: PdfColors.white, align: ShapedTextAlign.end)),
                _cell(text(isBengali ? 'জমা (-)' : 'Period Credit (-)', bold: true, size: 8.5, color: PdfColors.white, align: ShapedTextAlign.end)),
                _cell(text(isBengali ? 'বর্তমান বাকি' : 'Closing Balance', bold: true, size: 8.5, color: PdfColors.white, align: ShapedTextAlign.end)),
              ],
            ),
          );

          // 2. Customer rows
          for (int i = 0; i < data.customerSummaries.length; i++) {
            final item = data.customerSummaries[i];
            final sl = isBengali ? PhoneUtils.toBengaliNumber((i + 1).toString()) : (i + 1).toString();
            final op = formatAmount(item.openingBalance, isBengali: isBengali, currencySymbol: currency);
            final bk = formatAmount(item.periodBaki, isBengali: isBengali, currencySymbol: currency);
            final pm = formatAmount(item.periodPayment, isBengali: isBengali, currencySymbol: currency);
            final cl = formatAmount(item.closingBalance, isBengali: isBengali, currencySymbol: currency);

            final namePhone = item.customer.phone != null && item.customer.phone!.isNotEmpty
                ? '${item.customer.name} (${item.customer.phone})'
                : item.customer.name;

            final isAlt = i % 2 == 1;
            tableRows.add(
              pw.TableRow(
                decoration: isAlt ? pw.BoxDecoration(color: PdfColor.fromHex('#fbfcfb')) : null,
                children: [
                  _cell(text(sl, size: 8.5, align: ShapedTextAlign.center)),
                  _cell(text(namePhone, bold: true, size: 8.5)),
                  _cell(text(op, size: 8.5, align: ShapedTextAlign.end)),
                  _cell(text(bk, size: 8.5, color: PdfColor.fromHex('#b71c1c'), align: ShapedTextAlign.end)),
                  _cell(text(pm, size: 8.5, color: PdfColor.fromHex('#1b5e20'), align: ShapedTextAlign.end)),
                  _cell(text(cl, bold: true, size: 8.5, color: item.closingBalance > 0 ? PdfColor.fromHex('#b71c1c') : PdfColor.fromHex('#1b5e20'), align: ShapedTextAlign.end)),
                ],
              ),
            );
          }

          // 3. Summary row
          tableRows.add(
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColor.fromHex('#e0f2f1')),
              children: [
                _cell(text('', size: 8.5)),
                _cell(text(isBengali ? 'সর্বমোট দোকান জের:' : 'Total Store Balance:', bold: true, size: 8.5)),
                _cell(text(totalOpening, bold: true, size: 8.5, align: ShapedTextAlign.end)),
                _cell(text(totalBaki, bold: true, size: 8.5, color: PdfColor.fromHex('#b71c1c'), align: ShapedTextAlign.end)),
                _cell(text(totalPayment, bold: true, size: 8.5, color: PdfColor.fromHex('#1b5e20'), align: ShapedTextAlign.end)),
                _cell(text(totalClosing, bold: true, size: 8.5, color: PdfColor.fromHex('#b71c1c'), align: ShapedTextAlign.end)),
              ],
            ),
          );

          return [
            // Store Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    text(shopName, bold: true, size: 18, color: PdfColor.fromHex('#004d40')),
                    if (proprietor != null && proprietor.isNotEmpty) ...[
                      pw.SizedBox(height: 1),
                      text('${isBengali ? 'স্বত্বাধিকারী:' : 'Proprietor:'} $proprietor', bold: true, size: 10, color: PdfColor.fromHex('#37474f')),
                    ],
                    if (shopAddress != null && shopAddress.isNotEmpty) ...[
                      text(shopAddress, size: 8.5, color: PdfColor.fromHex('#546e7a')),
                    ],
                    if (shopPhone != null && shopPhone.isNotEmpty) ...[
                      text('${isBengali ? 'ফোন:' : 'Phone:'} $shopPhone', size: 8.5, color: PdfColor.fromHex('#546e7a')),
                    ],
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromHex('#00695c'),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                      ),
                      child: text(isBengali ? 'দোকানের মাস্টার খতিয়ান' : 'STORE MASTER LEDGER', bold: true, size: 10.5, color: PdfColors.white),
                    ),
                    pw.SizedBox(height: 4),
                    text('${isBengali ? 'তারিখ:' : 'Date:'} $generatedAtStr', size: 8.5, color: PdfColor.fromHex('#546e7a')),
                    text('${isBengali ? 'সময়কাল:' : 'Period:'} $periodLabel', size: 8.5, color: PdfColor.fromHex('#546e7a')),
                    text(
                      '${isBengali ? 'মোট খরিদ্দার:' : 'Total Debtors:'} ${isBengali ? PhoneUtils.toBengaliNumber(data.customerSummaries.length.toString()) : data.customerSummaries.length}',
                      bold: true,
                      size: 8.5,
                      color: PdfColor.fromHex('#004d40'),
                    ),
                  ],
                ),
              ],
            ),

            pw.SizedBox(height: 8),
            pw.Divider(color: PdfColor.fromHex('#b0bec5'), thickness: 0.8),
            pw.SizedBox(height: 8),

            // Store KPI Grid
            pw.Row(
              children: [
                _kpiBox(isBengali ? 'পূর্বের মোট জের' : 'Opening Dues', totalOpening, '#e0f2f1', '#004d40'),
                pw.SizedBox(width: 8),
                _kpiBox(isBengali ? 'সর্বমোট বাকি (+)' : 'Total Debit (+)', totalBaki, '#ffebee', '#b71c1c'),
                pw.SizedBox(width: 8),
                _kpiBox(isBengali ? 'সর্বমোট জমা (-)' : 'Total Credit (-)', totalPayment, '#e8f5e9', '#1b5e20'),
                pw.SizedBox(width: 8),
                _kpiBox(isBengali ? 'মোট বর্তমান বাকি' : 'Net Store Due', totalClosing, '#ffebee', '#b71c1c'),
              ],
            ),

            pw.SizedBox(height: 12),

            // Store Table
            pw.Table(
              border: pw.TableBorder.all(color: PdfColor.fromHex('#cfd8dc'), width: 0.5),
              children: tableRows,
            ),

            pw.Spacer(),

            // Signature & Verification
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Container(
                  width: 80,
                  height: 80,
                  decoration: pw.BoxDecoration(
                    shape: pw.BoxShape.circle,
                    border: pw.Border.all(color: PdfColor.fromHex('#00695c'), width: 1.8),
                    color: PdfColor.fromHex('#f0fdf4'),
                  ),
                  child: pw.Center(
                    child: pw.Column(
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: [
                        text(isBengali ? '[ মাস্টার খতিয়ান ]' : '[ MASTER AUDIT ]', bold: true, size: 7, color: PdfColor.fromHex('#004d40'), align: ShapedTextAlign.center),
                        text(shopName, bold: true, size: 8, color: PdfColor.fromHex('#004d40'), align: ShapedTextAlign.center),
                        text(formatDate(data.generatedAt, isBengali: isBengali), size: 6.5, color: PdfColor.fromHex('#546e7a'), align: ShapedTextAlign.center),
                      ],
                    ),
                  ),
                ),
                pw.Column(
                  children: [
                    pw.Container(width: 140, height: 1, color: PdfColor.fromHex('#90a4ae')),
                    pw.SizedBox(height: 4),
                    text(isBengali ? 'স্বত্বাধিকারীর স্বাক্ষর ও অফিসিয়াল সিল' : 'Authorized Signature & Seal', size: 9, color: PdfColor.fromHex('#546e7a')),
                  ],
                ),
              ],
            ),

            pw.SizedBox(height: 10),
            pw.Center(
              child: text(
                isBengali
                    ? 'বাকি খাতা অ্যাপ দ্বারা সংকলিত গোপনীয় দোকান অডিট ও মহাজন খাতা'
                    : 'Confidential store audit ledger generated by Baki Khata App',
                size: 7.5,
                color: PdfColor.fromHex('#78909c'),
                align: ShapedTextAlign.center,
              ),
            ),
          ];
        },
      ),
    );

    return doc;
  }

  static pw.Widget _kpiBox(String title, String value, String bgHex, String textHex) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 6),
        decoration: pw.BoxDecoration(
          color: PdfColor.fromHex(bgHex),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          border: pw.Border.all(color: PdfColor.fromHex(textHex), width: 0.5),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            text(title, size: 8, color: PdfColor.fromHex(textHex), align: ShapedTextAlign.center),
            pw.SizedBox(height: 2),
            text(value, bold: true, size: 10.5, color: PdfColor.fromHex(textHex), align: ShapedTextAlign.center),
          ],
        ),
      ),
    );
  }

  static pw.Widget _cell(pw.Widget child) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: child,
    );
  }
}
