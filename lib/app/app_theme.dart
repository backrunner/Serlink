import 'package:flutter/material.dart';

class SerlinkTheme {
  const SerlinkTheme._();

  static ThemeData dark() {
    const accent = Color(0xFF58A6FF);
    const surface = Color(0xFF111418);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        brightness: Brightness.dark,
        surface: surface,
      ),
      scaffoldBackgroundColor: surface,
      visualDensity: VisualDensity.compact,
      dividerTheme: const DividerThemeData(
        color: Color(0xFF252A31),
        thickness: 1,
        space: 1,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: const Color(0xFF20252C),
          borderRadius: BorderRadius.circular(6),
        ),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF171B21),
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: Color(0xFF252A31)),
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
  }

  static ThemeData light() {
    const accent = Color(0xFF0969DA);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        brightness: Brightness.light,
      ),
      visualDensity: VisualDensity.compact,
      dividerTheme: const DividerThemeData(thickness: 1, space: 1),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: Color(0xFFD8DEE4)),
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
  }
}
