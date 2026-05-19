import 'package:flutter/material.dart';

class AppTheme {
  static const Color primary = Color(0xFF1B6B2E);      // deep green
  static const Color primaryLight = Color(0xFF4CAF50);
  static const Color secondary = Color(0xFFFF8F00);    // amber
  static const Color danger = Color(0xFFD32F2F);
  static const Color paid = Color(0xFF2E7D32);
  static const Color partial = Color(0xFFF57C00);
  static const Color unpaid = Color(0xFFC62828);
  static const Color surface = Color(0xFFF5F5F5);

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        secondary: secondary,
        surface: surface,
        brightness: Brightness.light,
      ),
      fontFamily: 'NotoSansKannada',
      appBarTheme: const AppBarTheme(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 2,
        titleTextStyle: TextStyle(
          fontFamily: 'NotoSansKannada',
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 56), // large touch target
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          minimumSize: const Size(double.infinity, 56),
          side: const BorderSide(color: primary, width: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFBDBDBD)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        labelStyle: const TextStyle(fontSize: 16),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: secondary,
        foregroundColor: Colors.white,
        extendedTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(fontSize: 17),
        bodyMedium: TextStyle(fontSize: 15),
        labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      listTileTheme: const ListTileThemeData(
        minVerticalPadding: 12,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }

  static Color statusColor(String status) {
    switch (status) {
      case 'fully_paid':
        return paid;
      case 'partially_paid':
        return partial;
      default:
        return unpaid;
    }
  }

  static String statusLabel(String status, {bool kannada = false}) {
    if (kannada) {
      switch (status) {
        case 'fully_paid': return 'ಸಂಪೂರ್ಣ ಪಾವತಿ';
        case 'partially_paid': return 'ಭಾಗಶಃ ಪಾವತಿ';
        default: return 'ಪಾವತಿ ಆಗಿಲ್ಲ';
      }
    }
    switch (status) {
      case 'fully_paid': return 'Fully Paid';
      case 'partially_paid': return 'Partially Paid';
      default: return 'Unpaid';
    }
  }
}
