import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

class AppColors {
  // Gray palette (Tailwind)
  static const Color gray50 = Color(0xFFF9FAFB);
  static const Color gray100 = Color(0xFFF3F4F6);
  static const Color gray200 = Color(0xFFE5E7EB);
  static const Color gray300 = Color(0xFFD1D5DB);
  static const Color gray400 = Color(0xFF9CA3AF);
  static const Color gray500 = Color(0xFF6B7280);
  static const Color gray600 = Color(0xFF4B5563);
  static const Color gray700 = Color(0xFF374151);
  static const Color gray800 = Color(0xFF1F2937);
  static const Color gray900 = Color(0xFF111827);

  // Status colors
  static const Color success = Color(0xFF22C55E);
  static const Color successBg = Color(0xFFDCFCE7);
  static const Color warning = Color(0xFFEAB308);
  static const Color warningBg = Color(0xFFFEF3C7);
  static const Color error = Color(0xFFEF4444);
  static const Color errorBg = Color(0xFFFEE2E2);
  static const Color info = Color(0xFF3B82F6);
  static const Color infoBg = Color(0xFFDBEAFE);

  // Sidebar default
  static const Color sidebarDefault = Color(0xFF1E293B);

  // Legacy static primary (fallback)
  static const Color primary500 = Color(0xFF6246EA);
}

class AppTheme {
  static String get fontFamily {
    if (kIsWeb) return 'Microsoft YaHei';
    if (Platform.isMacOS || Platform.isIOS) return 'PingFang SC';
    return 'Microsoft YaHei';
  }

  /// Create light theme with dynamic primary color (matching sidebar_color)
  static ThemeData lightThemeWith(Color primary) {
    return ThemeData(
      brightness: Brightness.light,
      fontFamily: fontFamily,
      colorScheme: ColorScheme.light(
        primary: primary,
        secondary: primary.withValues(alpha: 0.8),
        surface: Colors.white,
        error: AppColors.error,
      ),
      scaffoldBackgroundColor: AppColors.gray50,
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.05),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white, elevation: 0, centerTitle: true,
        foregroundColor: AppColors.gray900,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary, foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, fontFamily: fontFamily),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: BorderSide(color: primary),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, fontFamily: fontFamily),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: AppColors.gray100,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.gray200)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.gray200)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primary, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        hintStyle: const TextStyle(color: AppColors.gray400, fontSize: 14),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.gray900),
        headlineMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.gray900),
        bodyLarge: TextStyle(fontSize: 14, color: AppColors.gray900),
        bodyMedium: TextStyle(fontSize: 14, color: AppColors.gray500),
        bodySmall: TextStyle(fontSize: 12, color: AppColors.gray400),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.gray200, thickness: 1),
    );
  }

  static ThemeData darkThemeWith(Color primary) {
    return ThemeData(
      brightness: Brightness.dark,
      fontFamily: fontFamily,
      colorScheme: ColorScheme.dark(
        primary: primary,
        secondary: primary.withValues(alpha: 0.8),
        surface: AppColors.gray800,
        error: AppColors.error,
      ),
      scaffoldBackgroundColor: AppColors.gray900,
      cardTheme: CardThemeData(
        color: AppColors.gray800, elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary, foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, fontFamily: fontFamily),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: AppColors.gray700,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.gray600)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.gray600)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primary, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        hintStyle: const TextStyle(color: AppColors.gray400, fontSize: 14),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
        headlineMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
        bodyLarge: TextStyle(fontSize: 14, color: Colors.white),
        bodyMedium: TextStyle(fontSize: 14, color: AppColors.gray400),
        bodySmall: TextStyle(fontSize: 12, color: AppColors.gray500),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.gray700, thickness: 1),
    );
  }

  // Legacy static themes (kept for backwards compat)
  static ThemeData get lightTheme => lightThemeWith(AppColors.primary500);
  static ThemeData get darkTheme => darkThemeWith(AppColors.primary500);
}
