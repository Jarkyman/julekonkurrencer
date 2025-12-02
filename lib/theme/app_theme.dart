import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF0E4D3D); // buttons / accents
  static const Color selection = Color(0xFFD9E7E2);
  static const Color surface = Color(0xFFDCE5E1); // secondary background + inputs
  static const Color text = Color(0xFF001F28);
}

class AppTheme {
  const AppTheme._();

  static ThemeData light() {
    final colorScheme = ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.selection,
      onSecondary: AppColors.text,
      surface: AppColors.surface,
      onSurface: AppColors.text,
      error: Colors.red,
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.surface,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      cardColor: Colors.white,
      inputDecorationTheme: InputDecorationTheme(
        fillColor: AppColors.surface,
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.selection),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
      chipTheme: const ChipThemeData(
        selectedColor: AppColors.selection,
        backgroundColor: Colors.white,
        labelStyle: TextStyle(color: AppColors.text),
      ),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: AppColors.text),
        bodyLarge: TextStyle(color: AppColors.text),
        titleMedium: TextStyle(color: AppColors.text),
        titleLarge: TextStyle(color: AppColors.text),
      ),
    );
  }
}
