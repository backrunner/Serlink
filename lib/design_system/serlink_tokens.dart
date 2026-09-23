import 'package:flutter/material.dart';

/// Semantic color tokens for Serlink, exposed as a [ThemeExtension] so feature
/// code reads named roles (`surfaceRaised`, `textSecondary`, `accentPrimary`,
/// `statusDanger`, ...) instead of raw `colorScheme` slots or hardcoded hex.
///
/// Both [dark] and [light] are registered on the app themes. Access through
/// `context.tokens` (see serlink_context.dart).
@immutable
class SerlinkTokens extends ThemeExtension<SerlinkTokens> {
  const SerlinkTokens({
    required this.surfaceBase,
    required this.surfaceRaised,
    required this.surfaceSunken,
    required this.surfaceOverlay,
    required this.surfaceGlass,
    required this.borderSubtle,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.accentPrimary,
    required this.accentStrong,
    required this.accentSecondary,
    required this.onAccent,
    required this.statusSuccess,
    required this.statusWarning,
    required this.statusDanger,
    this.statusDangerFill = const Color(0xFFCF222E),
    required this.statusInfo,
    required this.shadowColor,
    required this.backdropTop,
    required this.backdropBottom,
  });

  /// App / window background — the deepest surface.
  final Color surfaceBase;

  /// Panels, dialogs, rows that sit above [surfaceBase].
  final Color surfaceRaised;

  /// Input fills and recessed wells.
  final Color surfaceSunken;

  /// Hover / pressed wash for interactive rows on raised surfaces.
  final Color surfaceOverlay;

  /// Translucent fill for frosted-glass panels (used over the backdrop).
  final Color surfaceGlass;

  /// Hairlines, dividers, default control borders.
  final Color borderSubtle;

  /// Emphasized borders (focused inputs, active edges).
  final Color borderStrong;

  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  /// Brand accent (teal). Used sparingly for selection and primary affordances.
  final Color accentPrimary;

  /// Deeper, saturated accent used as a solid fill behind white foreground
  /// (buttons, selected nav) so [onAccent] stays legible. Also the near stop of
  /// accent gradients.
  final Color accentStrong;

  /// Secondary accent used as the far stop of accent gradients (cyan/blue).
  final Color accentSecondary;

  /// Foreground placed on top of accent fills. White in both themes for a
  /// crisp, commercial look.
  final Color onAccent;

  final Color statusSuccess;
  final Color statusWarning;
  final Color statusDanger;

  /// Solid destructive controls use a deeper red behind [onAccent].
  final Color statusDangerFill;
  final Color statusInfo;

  /// Base color for soft drop shadows (alpha applied by the shadow helper).
  final Color shadowColor;

  /// Top color of the ambient app backdrop gradient.
  final Color backdropTop;

  /// Bottom color of the ambient app backdrop gradient.
  final Color backdropBottom;

  static const SerlinkTokens dark = SerlinkTokens(
    surfaceBase: Color(0xFF1C1C1E),
    surfaceRaised: Color(0xFF28282B),
    surfaceSunken: Color(0xFF171719),
    surfaceOverlay: Color(0x14FFFFFF),
    surfaceGlass: Color(0xE628282B),
    borderSubtle: Color(0xFF3A3A3D),
    borderStrong: Color(0xFF505054),
    textPrimary: Color(0xFFF2F2F4),
    textSecondary: Color(0xFFB1B1B7),
    textMuted: Color(0xFF909098),
    accentPrimary: Color(0xFF2DD4BF),
    accentStrong: Color(0xFF087D73),
    accentSecondary: Color(0xFF22A8E8),
    onAccent: Color(0xFFFFFFFF),
    statusSuccess: Color(0xFF3FB950),
    statusWarning: Color(0xFFD29922),
    statusDanger: Color(0xFFF85149),
    statusInfo: Color(0xFF58A6FF),
    shadowColor: Color(0xFF000000),
    backdropTop: Color(0xFF2C2C2F),
    backdropBottom: Color(0xFF232326),
  );

  static const SerlinkTokens light = SerlinkTokens(
    surfaceBase: Color(0xFFF2F2F4),
    surfaceRaised: Color(0xFFFFFFFF),
    surfaceSunken: Color(0xFFE9E9ED),
    surfaceOverlay: Color(0x0F1F2328),
    surfaceGlass: Color(0xE6FFFFFF),
    borderSubtle: Color(0xFFDEDEE3),
    borderStrong: Color(0xFFBDBDC5),
    textPrimary: Color(0xFF242426),
    textSecondary: Color(0xFF606067),
    textMuted: Color(0xFF74747D),
    accentPrimary: Color(0xFF0D9488),
    accentStrong: Color(0xFF0B7E74),
    accentSecondary: Color(0xFF0EA5E9),
    onAccent: Color(0xFFFFFFFF),
    statusSuccess: Color(0xFF1A7F37),
    statusWarning: Color(0xFF9A6700),
    statusDanger: Color(0xFFCF222E),
    statusInfo: Color(0xFF0969DA),
    shadowColor: Color(0xFF000000),
    backdropTop: Color(0xFFF5F5F7),
    backdropBottom: Color(0xFFE8E8EC),
  );

  @override
  SerlinkTokens copyWith({
    Color? surfaceBase,
    Color? surfaceRaised,
    Color? surfaceSunken,
    Color? surfaceOverlay,
    Color? surfaceGlass,
    Color? borderSubtle,
    Color? borderStrong,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? accentPrimary,
    Color? accentStrong,
    Color? accentSecondary,
    Color? onAccent,
    Color? statusSuccess,
    Color? statusWarning,
    Color? statusDanger,
    Color? statusDangerFill,
    Color? statusInfo,
    Color? shadowColor,
    Color? backdropTop,
    Color? backdropBottom,
  }) {
    return SerlinkTokens(
      surfaceBase: surfaceBase ?? this.surfaceBase,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      surfaceSunken: surfaceSunken ?? this.surfaceSunken,
      surfaceOverlay: surfaceOverlay ?? this.surfaceOverlay,
      surfaceGlass: surfaceGlass ?? this.surfaceGlass,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      borderStrong: borderStrong ?? this.borderStrong,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      accentPrimary: accentPrimary ?? this.accentPrimary,
      accentStrong: accentStrong ?? this.accentStrong,
      accentSecondary: accentSecondary ?? this.accentSecondary,
      onAccent: onAccent ?? this.onAccent,
      statusSuccess: statusSuccess ?? this.statusSuccess,
      statusWarning: statusWarning ?? this.statusWarning,
      statusDanger: statusDanger ?? this.statusDanger,
      statusDangerFill: statusDangerFill ?? this.statusDangerFill,
      statusInfo: statusInfo ?? this.statusInfo,
      shadowColor: shadowColor ?? this.shadowColor,
      backdropTop: backdropTop ?? this.backdropTop,
      backdropBottom: backdropBottom ?? this.backdropBottom,
    );
  }

  @override
  SerlinkTokens lerp(ThemeExtension<SerlinkTokens>? other, double t) {
    if (other is! SerlinkTokens) {
      return this;
    }
    return SerlinkTokens(
      surfaceBase: Color.lerp(surfaceBase, other.surfaceBase, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      surfaceSunken: Color.lerp(surfaceSunken, other.surfaceSunken, t)!,
      surfaceOverlay: Color.lerp(surfaceOverlay, other.surfaceOverlay, t)!,
      surfaceGlass: Color.lerp(surfaceGlass, other.surfaceGlass, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      accentPrimary: Color.lerp(accentPrimary, other.accentPrimary, t)!,
      accentStrong: Color.lerp(accentStrong, other.accentStrong, t)!,
      accentSecondary: Color.lerp(accentSecondary, other.accentSecondary, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      statusSuccess: Color.lerp(statusSuccess, other.statusSuccess, t)!,
      statusWarning: Color.lerp(statusWarning, other.statusWarning, t)!,
      statusDanger: Color.lerp(statusDanger, other.statusDanger, t)!,
      statusDangerFill: Color.lerp(
        statusDangerFill,
        other.statusDangerFill,
        t,
      )!,
      statusInfo: Color.lerp(statusInfo, other.statusInfo, t)!,
      shadowColor: Color.lerp(shadowColor, other.shadowColor, t)!,
      backdropTop: Color.lerp(backdropTop, other.backdropTop, t)!,
      backdropBottom: Color.lerp(backdropBottom, other.backdropBottom, t)!,
    );
  }
}
