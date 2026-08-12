import 'package:flutter/material.dart';

/// Theme tối (dark) duy nhất của toàn bộ ứng dụng.
///
/// Giữ nguyên màu nhấn (accent) hiện có của app (seed xanh dương
/// `0xFF3B5BDB`) để không phá vỡ nhận diện thương hiệu, chỉ đổi
/// nền/surface/chữ sang tông tối chuẩn Material Dark.
class AppTheme {
  const AppTheme._();

  static const Color _seedColor = Color(0xFF3B5BDB);
  static const Color _scaffoldBackground = Color(0xFF121212);
  static const Color _surfaceColor = Color(0xFF1E1E1E);

  static ThemeData get darkTheme {
    final ColorScheme colorScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.dark,
    ).copyWith(
      surface: _surfaceColor,
      surfaceContainerHighest: const Color(0xFF2A2A2E),
      outlineVariant: const Color(0xFF3A3A3E),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _scaffoldBackground,
      cardColor: _surfaceColor,
      dividerColor: const Color(0xFF3A3A3E),

      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _surfaceColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _seedColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 15,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _seedColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 15,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
