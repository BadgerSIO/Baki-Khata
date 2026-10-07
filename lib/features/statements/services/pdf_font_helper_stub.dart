import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

enum AppPdfTextAlign {
  start,
  center,
  end,
}

class PdfFontHelper {
  static pw.Font? _cachedRegFont;
  static pw.Font? _cachedBoldFont;

  static Future<void> ensureFontsLoaded() async {
    if (_cachedRegFont != null && _cachedBoldFont != null) return;
    try {
      final regData = await rootBundle.load('assets/fonts/NotoSansBengali-Regular.ttf');
      final boldData = await rootBundle.load('assets/fonts/NotoSansBengali-Bold.ttf');
      _cachedRegFont = pw.Font.ttf(regData);
      _cachedBoldFont = pw.Font.ttf(boldData);
    } catch (_) {}
  }

  static pw.Widget text(
    String str, {
    bool bold = false,
    double size = 9,
    PdfColor? color,
    AppPdfTextAlign align = AppPdfTextAlign.start,
  }) {
    final font = bold ? (_cachedBoldFont ?? _cachedRegFont) : _cachedRegFont;
    pw.TextAlign textAlign;
    switch (align) {
      case AppPdfTextAlign.center:
        textAlign = pw.TextAlign.center;
        break;
      case AppPdfTextAlign.end:
        textAlign = pw.TextAlign.right;
        break;
      case AppPdfTextAlign.start:
        textAlign = pw.TextAlign.left;
        break;
    }

    return pw.Text(
      str,
      textAlign: textAlign,
      style: pw.TextStyle(
        font: font,
        fontSize: size,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        color: color ?? PdfColor.fromHex('#212121'),
      ),
    );
  }
}
