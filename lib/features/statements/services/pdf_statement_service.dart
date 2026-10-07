import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../models/statement_models.dart';
import 'pdf_document_builder.dart';

class PdfStatementService {
  /// Converts [CustomerStatementData] to high-fidelity PDF bytes.
  static Future<Uint8List> generateCustomerStatementPdf(
    CustomerStatementData data, {
    bool isBengali = true,
  }) async {
    try {
      final doc = await PdfDocumentBuilder.buildCustomerStatementDoc(
        data,
        isBengali: isBengali,
      );
      return await doc.save();
    } catch (e) {
      debugPrint('[PdfStatementService] Failed to generate Customer PDF: $e');
      rethrow;
    }
  }

  /// Converts [StoreStatementData] to high-fidelity PDF bytes.
  static Future<Uint8List> generateStoreStatementPdf(
    StoreStatementData data, {
    bool isBengali = true,
  }) async {
    try {
      final doc = await PdfDocumentBuilder.buildStoreStatementDoc(
        data,
        isBengali: isBengali,
      );
      return await doc.save();
    } catch (e) {
      debugPrint('[PdfStatementService] Failed to generate Store PDF: $e');
      rethrow;
    }
  }

  /// Opens the system print preview or connects to WiFi / Bluetooth POS printers directly.
  static Future<bool> printOrPreviewCustomerStatement(
    CustomerStatementData data, {
    bool isBengali = true,
  }) async {
    try {
      final sanitizedName = data.customer.name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final fileName = 'Statement_${sanitizedName}_${DateTime.now().millisecondsSinceEpoch}.pdf';

      return await Printing.layoutPdf(
        name: fileName,
        onLayout: (PdfPageFormat format) async {
          return await generateCustomerStatementPdf(data, isBengali: isBengali);
        },
      );
    } catch (e) {
      debugPrint('[PdfStatementService] Print failed: $e');
      return false;
    }
  }

  /// Shares the generated customer statement PDF directly via WhatsApp, Telegram, Gmail, etc.
  static Future<bool> shareCustomerStatement(
    CustomerStatementData data, {
    bool isBengali = true,
  }) async {
    try {
      final sanitizedName = data.customer.name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final fileName = 'Statement_${sanitizedName}_${data.statementNumber}.pdf';

      final bytes = await generateCustomerStatementPdf(data, isBengali: isBengali);

      final subject = isBengali
          ? '${data.settings.shopName} - ${data.customer.name} হিসাব বিবরণী'
          : '${data.settings.shopName} - Ledger Statement for ${data.customer.name}';

      return await Printing.sharePdf(
        bytes: bytes,
        filename: fileName,
        subject: subject,
      );
    } catch (e) {
      debugPrint('[PdfStatementService] Share PDF failed: $e');
      return false;
    }
  }

  /// Opens system print dialog for store master statement.
  static Future<bool> printOrPreviewStoreStatement(
    StoreStatementData data, {
    bool isBengali = true,
  }) async {
    try {
      final fileName = 'Store_Master_Ledger_${DateTime.now().millisecondsSinceEpoch}.pdf';

      return await Printing.layoutPdf(
        name: fileName,
        onLayout: (PdfPageFormat format) async {
          return await generateStoreStatementPdf(data, isBengali: isBengali);
        },
      );
    } catch (e) {
      debugPrint('[PdfStatementService] Print store ledger failed: $e');
      return false;
    }
  }

  /// Shares the store-wide master statement PDF.
  static Future<bool> shareStoreStatement(
    StoreStatementData data, {
    bool isBengali = true,
  }) async {
    try {
      final fileName = 'Store_Master_Ledger_${data.statementNumber}.pdf';
      final bytes = await generateStoreStatementPdf(data, isBengali: isBengali);

      final subject = isBengali
          ? '${data.settings.shopName} - দোকানের সর্বমোট মহাজন লেজার'
          : '${data.settings.shopName} - Store Master Ledger Report';

      return await Printing.sharePdf(
        bytes: bytes,
        filename: fileName,
        subject: subject,
      );
    } catch (e) {
      debugPrint('[PdfStatementService] Share store PDF failed: $e');
      return false;
    }
  }
}
