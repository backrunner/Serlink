import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../design_system/design_system.dart';

/// Standard interactive height for buttons. Explicitly paired with standard
/// density so desktop Material compact density does not shrink dialog actions.
const double _buttonHeight = 42;

class SerlinkTheme {
  const SerlinkTheme._();

  static ThemeData dark() => _build(SerlinkTokens.dark, Brightness.dark);

  static ThemeData light() => _build(SerlinkTokens.light, Brightness.light);

  static FThemeData foruiDark() => _buildForui(
    tokens: SerlinkTokens.dark,
    baseColors: FThemes.neutral.dark.desktop.colors,
    debugLabel: 'Serlink Dark Desktop',
    touch: false,
  );

  static FThemeData foruiLight() => _buildForui(
    tokens: SerlinkTokens.light,
    baseColors: FThemes.neutral.light.desktop.colors,
    debugLabel: 'Serlink Light Desktop',
    touch: false,
  );

  static FThemeData foruiDarkTouch() => _buildForui(
    tokens: SerlinkTokens.dark,
    baseColors: FThemes.neutral.dark.touch.colors,
    debugLabel: 'Serlink Dark Touch',
    touch: true,
  );

  static FThemeData foruiLightTouch() => _buildForui(
    tokens: SerlinkTokens.light,
    baseColors: FThemes.neutral.light.touch.colors,
    debugLabel: 'Serlink Light Touch',
    touch: true,
  );
}

FThemeData _buildForui({
  required SerlinkTokens tokens,
  required FColors baseColors,
  required String debugLabel,
  required bool touch,
}) {
  final colors = baseColors.copyWith(
    barrier: tokens.shadowColor.withValues(alpha: 0.52),
    background: tokens.surfaceBase,
    foreground: tokens.textPrimary,
    primary: tokens.accentPrimary,
    primaryForeground: tokens.onAccent,
    secondary: tokens.surfaceSunken,
    secondaryForeground: tokens.textPrimary,
    muted: tokens.surfaceSunken,
    mutedForeground: tokens.textMuted,
    destructive: tokens.statusDanger,
    destructiveForeground: tokens.onAccent,
    error: tokens.statusDanger,
    errorForeground: tokens.onAccent,
    card: tokens.surfaceRaised,
    border: tokens.borderSubtle,
  );
  final typography = FTypography.inherit(colors: colors, touch: touch);
  final style =
      FStyle.inherit(
        colors: colors,
        typography: typography,
        touch: touch,
      ).copyWith(
        borderRadius: const FBorderRadius(
          xs2: BorderRadius.all(Radius.circular(4)),
          xs: BorderRadius.all(Radius.circular(6)),
          sm: BorderRadius.all(Radius.circular(8)),
          md: SerlinkRadii.control,
          lg: SerlinkRadii.dialog,
          xl: SerlinkRadii.card,
          xl2: SerlinkRadii.card,
          xl3: SerlinkRadii.card,
          pill: SerlinkRadii.pill,
        ),
        shadow: serlinkShadow(tokens, elevation: 18),
      );
  return FThemeData(
    touch: touch,
    debugLabel: debugLabel,
    colors: colors,
    typography: typography,
    style: style,
    cardStyle: _foruiCardStyle(tokens, colors, typography, style, touch),
    dialogStyle: _foruiDialogStyle(tokens, colors, typography, style, touch),
  );
}

FCardStyle _foruiCardStyle(
  SerlinkTokens tokens,
  FColors colors,
  FTypography typography,
  FStyle style,
  bool touch,
) {
  return FCardStyle.inherit(
    colors: colors,
    typography: typography,
    style: style,
    touch: touch,
  ).copyWith(
    decoration: DecorationDelta.value(
      ShapeDecoration(
        color: tokens.surfaceRaised,
        shape: RoundedRectangleBorder(
          borderRadius: SerlinkRadii.dialog,
          side: BorderSide(color: tokens.borderSubtle),
        ),
      ),
    ),
  );
}

FDialogStyle _foruiDialogStyle(
  SerlinkTokens tokens,
  FColors colors,
  FTypography typography,
  FStyle style,
  bool touch,
) {
  return FDialogStyle.inherit(
    colors: colors,
    typography: typography,
    style: style,
    hapticFeedback: const FHapticFeedback(),
    touch: touch,
  ).copyWith(
    decoration: DecorationDelta.value(
      ShapeDecoration(
        color: tokens.surfaceRaised,
        shape: RoundedRectangleBorder(
          borderRadius: SerlinkRadii.dialog,
          side: BorderSide(color: tokens.borderSubtle),
        ),
        shadows: serlinkShadow(tokens, elevation: 24),
      ),
    ),
    insetPadding: EdgeInsetsGeometryDelta.value(
      const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
    ),
  );
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
      actionsPadding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
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
      minimumSize: const WidgetStatePropertyAll(Size.square(34)),
      padding: const WidgetStatePropertyAll(EdgeInsets.zero),
      iconSize: const WidgetStatePropertyAll(18),
      visualDensity: VisualDensity.standard,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      alignment: Alignment.center,
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
      shadowColor: WidgetStatePropertyAll(
        t.accentStrong.withValues(alpha: 0.6),
      ),
      minimumSize: const WidgetStatePropertyAll(Size(0, _buttonHeight)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 22),
      ),
      iconSize: const WidgetStatePropertyAll(18),
      iconAlignment: IconAlignment.start,
      visualDensity: VisualDensity.standard,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      alignment: Alignment.center,
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
    style:
        OutlinedButton.styleFrom(
          foregroundColor: t.textPrimary,
          backgroundColor: t.surfaceRaised,
          side: BorderSide(color: t.borderStrong),
          minimumSize: const Size(0, _buttonHeight),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          iconSize: 18,
          iconAlignment: IconAlignment.start,
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          shape: const RoundedRectangleBorder(
            borderRadius: SerlinkRadii.control,
          ),
        ).copyWith(
          overlayColor: WidgetStatePropertyAll(
            t.accentPrimary.withValues(alpha: 0.08),
          ),
          visualDensity: VisualDensity.standard,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          alignment: Alignment.center,
        ),
  );
}

TextButtonThemeData _textButtonTheme(SerlinkTokens t) {
  return TextButtonThemeData(
    style:
        TextButton.styleFrom(
          foregroundColor: t.accentPrimary,
          minimumSize: const Size(0, _buttonHeight),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          iconSize: 18,
          iconAlignment: IconAlignment.start,
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          shape: const RoundedRectangleBorder(
            borderRadius: SerlinkRadii.control,
          ),
        ).copyWith(
          overlayColor: WidgetStatePropertyAll(
            t.accentPrimary.withValues(alpha: 0.1),
          ),
          visualDensity: VisualDensity.standard,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          alignment: Alignment.center,
        ),
  );
}

ElevatedButtonThemeData _elevatedButtonTheme(SerlinkTokens t) {
  return ElevatedButtonThemeData(
    style:
        ElevatedButton.styleFrom(
          elevation: 1,
          shadowColor: t.shadowColor,
          backgroundColor: t.surfaceRaised,
          foregroundColor: t.textPrimary,
          side: BorderSide(color: t.borderStrong),
          minimumSize: const Size(0, _buttonHeight),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          iconSize: 18,
          iconAlignment: IconAlignment.start,
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          shape: const RoundedRectangleBorder(
            borderRadius: SerlinkRadii.control,
          ),
        ).copyWith(
          visualDensity: VisualDensity.standard,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          alignment: Alignment.center,
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
