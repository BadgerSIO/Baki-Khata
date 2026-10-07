import 'dart:io';
import 'package:bangla_pdf_fixer/bangla_pdf_fixer.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

enum AppPdfTextAlign {
  start,
  center,
  end,
}

class PdfFontHelper {
  static ShapedFont? _cachedRegFont;
  static ShapedFont? _cachedBoldFont;
  static ShapedFont? _cachedLatinFont;

  static Future<void> ensureFontsLoaded() async {
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
    } catch (_) {}
  }

  static pw.Widget text(
    String str, {
    bool bold = false,
    double size = 9,
    PdfColor? color,
    AppPdfTextAlign align = AppPdfTextAlign.start,
  }) {
    final primaryFont = bold ? (_cachedBoldFont ?? _cachedRegFont) : _cachedRegFont;
    final fallbacks = <ShapedFont>[
      ?_cachedLatinFont,
    ];

    ShapedTextAlign shapedAlign;
    switch (align) {
      case AppPdfTextAlign.center:
        shapedAlign = ShapedTextAlign.center;
        break;
      case AppPdfTextAlign.end:
        shapedAlign = ShapedTextAlign.end;
        break;
      case AppPdfTextAlign.start:
        shapedAlign = ShapedTextAlign.start;
        break;
    }

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
      align: shapedAlign,
    );
  }
}
