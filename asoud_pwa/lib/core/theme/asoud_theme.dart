import 'package:flutter/material.dart';

abstract final class AsoudColors {
  static const primary = Color(0xff155bd7);
  static const navy = Color(0xff12213d);
  static const canvas = Color(0xfff5f7fb);
  static const border = Color(0xffdfe5ee);
  static const muted = Color(0xff68758a);
  static const success = Color(0xff16a364);
  static const warning = Color(0xffed8b00);
  static const danger = Color(0xffdc3545);
  static const cyan = Color(0xff1ca7a8);
}

abstract final class AsoudTheme {
  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: AsoudColors.primary,
      brightness: Brightness.light,
      surface: Colors.white,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AsoudColors.canvas,
      fontFamilyFallback: const ['Vazirmatn', 'Tahoma', 'Segoe UI'],
      dividerColor: AsoudColors.border,
      cardTheme: const CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
          side: BorderSide(color: AsoudColors.border),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: AsoudColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: AsoudColors.border),
        ),
      ),
    );
  }
}
