import 'package:flutter/material.dart';

import '../design_system/design_system.dart';

/// Standard interactive height for buttons — taller than the old 32px so
/// actions read as substantial, commercial-grade controls.
const double _buttonHeight = 40;

class SerlinkTheme {
  const SerlinkTheme._();

  static ThemeData dark() => _build(SerlinkTokens.dark, Brightness.dark);

  static ThemeData light() => _build(SerlinkTokens.light, Brightness.light);
}

ThemeData _build(SerlinkTokens t, Brightness brightness) {
  final scheme = serlinkColorScheme(t, brightness);
  final isDark = brightness == Brightness.dark;

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: t.surfaceBase,
    canvasColor: t.surfaceBase,
    visualDensity: VisualDensity.compact,
    splashFactory: InkRipple.splashFactory,
    extensions: [t],
    dividerTheme: DividerThemeData(
      color: t.borderSubtle,
      thickness: 1,
      space: 1,
    ),
    sliderTheme: SliderThemeData(
      trackHeight: 4,
      activeTrackColor: t.accentPrimary,
      inactiveTrackColor: t.surfaceOverlay,
      thumbColor: t.accentPrimary,
      overlayColor: t.accentPrimary.withValues(alpha: 0.16),
      valueIndicatorColor: t.accentStrong,
      valueIndicatorTextStyle: TextStyle(
        color: t.onAccent,
        fontWeight: FontWeight.w600,
      ),
      trackShape: const RoundedRectSliderTrackShape(),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF20252C) : const Color(0xFF24292F),
        borderRadius: SerlinkRadii.control,
      ),
      textStyle: TextStyle(
        color: isDark ? t.textPrimary : const Color(0xFFFFFFFF),
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      waitDuration: const Duration(milliseconds: 450),
      showDuration: const Duration(milliseconds: 1800),
    ),
    cardTheme: CardThemeData(
      color: t.surfaceRaised,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: t.borderSubtle),
        borderRadius: SerlinkRadii.dialog,
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: t.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      elevation: 24,
      shadowColor: t.shadowColor,
      shape: RoundedRectangleBorder(
        borderRadius: SerlinkRadii.dialog,
        side: BorderSide(color: t.borderSubtle),
      ),
    ),
    inputDecorationTheme: _inputDecorationTheme(t),
    iconButtonTheme: _iconButtonTheme(t),
    filledButtonTheme: _filledButtonTheme(t),
    outlinedButtonTheme: _outlinedButtonTheme(t),
    textButtonTheme: _textButtonTheme(t),
    elevatedButtonTheme: _elevatedButtonTheme(t),
    popupMenuTheme: _popupMenuTheme(t),
    chipTheme: _chipTheme(t),
  );
}

InputDecorationThemeData _inputDecorationTheme(SerlinkTokens t) {
  final border = OutlineInputBorder(
    borderRadius: SerlinkRadii.control,
    borderSide: BorderSide(color: t.borderSubtle),
  );
  return InputDecorationThemeData(
    filled: true,
    fillColor: t.surfaceSunken,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: border,
    enabledBorder: border,
    focusedBorder: border.copyWith(
      borderSide: BorderSide(color: t.accentPrimary, width: 1.6),
    ),
    hoverColor: t.surfaceOverlay,
    hintStyle: TextStyle(color: t.textMuted),
    labelStyle: TextStyle(color: t.textSecondary),
    floatingLabelStyle: TextStyle(color: t.accentPrimary),
  );
}

IconButtonThemeData _iconButtonTheme(SerlinkTokens t) {
  return IconButtonThemeData(
    style: ButtonStyle(
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return t.accentPrimary;
        }
        return t.textSecondary;
      }),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.pressed)) {
          return t.accentPrimary.withValues(alpha: 0.12);
        }
        return Colors.transparent;
      }),
      shape: const WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: SerlinkRadii.control),
      ),
    ),
  );
}

FilledButtonThemeData _filledButtonTheme(SerlinkTokens t) {
  return FilledButtonThemeData(
    style: ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return t.accentStrong.withValues(alpha: 0.4);
        }
        if (states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.pressed)) {
          return t.accentPrimary;
        }
        return t.accentStrong;
      }),
      foregroundColor: WidgetStatePropertyAll(t.onAccent),
      overlayColor: WidgetStatePropertyAll(Colors.white.withValues(alpha: 0.1)),
      elevation: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return 0;
        }
        if (states.contains(WidgetState.hovered)) {
          return 6;
        }
        return 2;
      }),
      shadowColor: WidgetStatePropertyAll(t.accentStrong.withValues(alpha: 0.6)),
      minimumSize: const WidgetStatePropertyAll(Size(0, _buttonHeight)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 20),
      ),
      textStyle: const WidgetStatePropertyAll(
        TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      shape: const WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: SerlinkRadii.control),
      ),
    ),
  );
}

OutlinedButtonThemeData _outlinedButtonTheme(SerlinkTokens t) {
  return OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: t.textPrimary,
      backgroundColor: t.surfaceRaised,
      side: BorderSide(color: t.borderStrong),
      minimumSize: const Size(0, _buttonHeight),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      shape: const RoundedRectangleBorder(borderRadius: SerlinkRadii.control),
    ).copyWith(
      overlayColor: WidgetStatePropertyAll(
        t.accentPrimary.withValues(alpha: 0.08),
      ),
    ),
  );
}

TextButtonThemeData _textButtonTheme(SerlinkTokens t) {
  return TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: t.accentPrimary,
      minimumSize: const Size(0, _buttonHeight),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      shape: const RoundedRectangleBorder(borderRadius: SerlinkRadii.control),
    ).copyWith(
      overlayColor: WidgetStatePropertyAll(
        t.accentPrimary.withValues(alpha: 0.1),
      ),
    ),
  );
}

ElevatedButtonThemeData _elevatedButtonTheme(SerlinkTokens t) {
  return ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      elevation: 1,
      shadowColor: t.shadowColor,
      backgroundColor: t.surfaceRaised,
      foregroundColor: t.textPrimary,
      side: BorderSide(color: t.borderStrong),
      minimumSize: const Size(0, _buttonHeight),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      shape: const RoundedRectangleBorder(borderRadius: SerlinkRadii.control),
    ),
  );
}

PopupMenuThemeData _popupMenuTheme(SerlinkTokens t) {
  return PopupMenuThemeData(
    color: t.surfaceRaised,
    elevation: 16,
    shadowColor: t.shadowColor,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      side: BorderSide(color: t.borderSubtle),
      borderRadius: SerlinkRadii.dialog,
    ),
  );
}

ChipThemeData _chipTheme(SerlinkTokens t) {
  return ChipThemeData(
    backgroundColor: t.surfaceSunken,
    side: BorderSide(color: t.borderSubtle),
    labelStyle: TextStyle(color: t.textSecondary, fontSize: 12),
    shape: const RoundedRectangleBorder(borderRadius: SerlinkRadii.control),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
  );
}
