import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Primary Theme Colors
  static const Color primary = Color(0xFF00695C);
  static const Color primaryContainer = Color(0xFFB2DFDB);
  static const Color secondary = Color(0xFF00796B);
  static const Color tertiary = Color(0xFFB78103);
  static const Color background = Color(0xFFF7FAF8);
  static const Color surface = Color(0xFFFFFFFF);

  // Semantic Colors
  // Baki / Debt
  static const Color debtText = Color(0xFFD32F2F);
  static const Color debtBg = Color(0xFFFFEBEE);

  // Payment
  static const Color paymentText = Color(0xFF2E7D32);
  static const Color paymentBg = Color(0xFFE8F5E9);

  // Advance
  static const Color advanceText = Color(0xFF00838F);
  static const Color advanceBg = Color(0xFFE0F7FA);

  // Settled
  static const Color settledText = Color(0xFF607D8B);
  static const Color settledBg = Color(0xFFECEFF1);
}

class AppTheme {
  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.light(
      primary: AppColors.primary,
      primaryContainer: AppColors.primaryContainer,
      onPrimary: Colors.white,
      onPrimaryContainer: const Color(0xFF00201A),
      secondary: AppColors.secondary,
      onSecondary: Colors.white,
      tertiary: AppColors.tertiary,
      onTertiary: Colors.white,
      surface: AppColors.surface,
      onSurface: const Color(0xFF191C1B),
      outline: const Color(0xFF6F7975),
      outlineVariant: const Color(0xFFBFC9C4),
    );

    final baseTextTheme = const TextTheme(
      displayLarge: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF191C1B)),
      displayMedium: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF191C1B)),
      displaySmall: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF191C1B)),
      headlineLarge: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF191C1B)),
      headlineMedium: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF191C1B)),
      headlineSmall: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF191C1B)),
      titleLarge: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF191C1B), fontSize: 18),
      titleMedium: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF191C1B), fontSize: 16),
      titleSmall: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF546E7A), fontSize: 14),
      bodyLarge: TextStyle(fontWeight: FontWeight.normal, color: Color(0xFF263238), fontSize: 16),
      bodyMedium: TextStyle(fontWeight: FontWeight.normal, color: Color(0xFF37474F), fontSize: 14),
      bodySmall: TextStyle(fontWeight: FontWeight.normal, color: Color(0xFF78909C), fontSize: 12),
      labelLarge: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      labelMedium: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: GoogleFonts.ibmPlexSans().fontFamily,
      textTheme: GoogleFonts.ibmPlexSansTextTheme(baseTextTheme),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE0E5E2), width: 1),
        ),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFCFD8DC)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFCFD8DC)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.debtText, width: 1.5),
        ),
        labelStyle: GoogleFonts.ibmPlexSans(
          fontWeight: FontWeight.w600,
          color: const Color(0xFF546E7A),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.ibmPlexSans(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.ibmPlexSans(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size.fromHeight(48),
          side: const BorderSide(color: AppColors.primary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.ibmPlexSans(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: GoogleFonts.ibmPlexSans(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.ibmPlexSans(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: AppColors.primary,
            );
          }
          return GoogleFonts.ibmPlexSans(
            fontWeight: FontWeight.w600,
            fontSize: 12,
            color: const Color(0xFF78909C),
          );
        }),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: const Color(0xFF191C1B),
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: GoogleFonts.ibmPlexSans(
          color: const Color(0xFF191C1B),
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
