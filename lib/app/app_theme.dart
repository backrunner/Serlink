import 'package:flutter/material.dart';

class SerlinkTheme {
  const SerlinkTheme._();

  static ThemeData dark() {
    const accent = Color(0xFF58A6FF);
    const surface = Color(0xFF0F1318);
    const panel = Color(0xFF171B21);
    const outline = Color(0xFF2A3038);

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
      splashFactory: InkRipple.splashFactory,
      dividerTheme: const DividerThemeData(
        color: outline,
        thickness: 1,
        space: 1,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: const Color(0xFF20252C),
          borderRadius: BorderRadius.circular(6),
        ),
        textStyle: const TextStyle(
          color: Color(0xFFE6EDF3),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        waitDuration: const Duration(milliseconds: 450),
        showDuration: const Duration(milliseconds: 1800),
      ),
      cardTheme: CardThemeData(
        color: panel,
        elevation: 1,
        shadowColor: const Color(0x66000000),
        surfaceTintColor: const Color(0x1A58A6FF),
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: outline),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: panel,
        surfaceTintColor: const Color(0x1A58A6FF),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      inputDecorationTheme: _inputDecorationTheme(
        fillColor: const Color(0xFF20262E),
        borderColor: outline,
        focusColor: accent,
      ),
      iconButtonTheme: _iconButtonTheme(accent, Brightness.dark),
      filledButtonTheme: _filledButtonTheme(),
      elevatedButtonTheme: _elevatedButtonTheme(Brightness.dark),
      popupMenuTheme: _popupMenuTheme(panel, outline),
    );
  }

  static ThemeData light() {
    const accent = Color(0xFF0969DA);
    const panel = Color(0xFFFFFFFF);
    const outline = Color(0xFFD8DEE4);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        brightness: Brightness.light,
      ),
      visualDensity: VisualDensity.compact,
      splashFactory: InkRipple.splashFactory,
      dividerTheme: const DividerThemeData(
        color: outline,
        thickness: 1,
        space: 1,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: const Color(0xFF24292F),
          borderRadius: BorderRadius.circular(6),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1F000000),
              blurRadius: 14,
              offset: Offset(0, 6),
            ),
          ],
        ),
        textStyle: const TextStyle(
          color: Color(0xFFFFFFFF),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        waitDuration: const Duration(milliseconds: 450),
        showDuration: const Duration(milliseconds: 1800),
      ),
      cardTheme: CardThemeData(
        color: panel,
        elevation: 1,
        shadowColor: const Color(0x1F1F2937),
        surfaceTintColor: const Color(0x140969DA),
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: outline),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: panel,
        surfaceTintColor: const Color(0x140969DA),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      inputDecorationTheme: _inputDecorationTheme(
        fillColor: const Color(0xFFF6F8FA),
        borderColor: outline,
        focusColor: accent,
      ),
      iconButtonTheme: _iconButtonTheme(accent, Brightness.light),
      filledButtonTheme: _filledButtonTheme(),
      elevatedButtonTheme: _elevatedButtonTheme(Brightness.light),
      popupMenuTheme: _popupMenuTheme(panel, outline),
    );
  }
}

InputDecorationThemeData _inputDecorationTheme({
  required Color fillColor,
  required Color borderColor,
  required Color focusColor,
}) {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide(color: borderColor),
  );
  return InputDecorationThemeData(
    filled: true,
    fillColor: fillColor,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    border: border,
    enabledBorder: border,
    focusedBorder: border.copyWith(
      borderSide: BorderSide(color: focusColor, width: 1.2),
    ),
  );
}

IconButtonThemeData _iconButtonTheme(Color accent, Brightness brightness) {
  final foreground = brightness == Brightness.dark
      ? const Color(0xFFE6EDF3)
      : const Color(0xFF24292F);
  return IconButtonThemeData(
    style: ButtonStyle(
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return accent;
        }
        return foreground;
      }),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.pressed)) {
          return accent.withValues(alpha: 0.10);
        }
        return Colors.transparent;
      }),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
  );
}

FilledButtonThemeData _filledButtonTheme() {
  return FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size(0, 38),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  );
}

ElevatedButtonThemeData _elevatedButtonTheme(Brightness brightness) {
  return ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      elevation: 1,
      shadowColor: brightness == Brightness.dark
          ? const Color(0x99000000)
          : const Color(0x261F2937),
      minimumSize: const Size(0, 38),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  );
}

PopupMenuThemeData _popupMenuTheme(Color color, Color outline) {
  return PopupMenuThemeData(
    color: color,
    elevation: 8,
    shadowColor: const Color(0x33000000),
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      side: BorderSide(color: outline),
      borderRadius: BorderRadius.circular(8),
    ),
  );
}
