import 'package:flutter/material.dart';

import 'serlink_dimensions.dart';
import 'serlink_tokens.dart';

/// Ergonomic access to the design system from any [BuildContext].
///
/// `context.tokens` returns the active [SerlinkTokens]; it falls back to the
/// dark palette if the extension is somehow missing (it is always registered
/// in [SerlinkTheme]).
extension SerlinkContextX on BuildContext {
  SerlinkTokens get tokens =>
      Theme.of(this).extension<SerlinkTokens>() ?? SerlinkTokens.dark;
}

/// Builds a Material [ColorScheme] whose slots agree with the semantic tokens,
/// so stock Material widgets (Switch, Chip, dialogs, progress indicators,
/// FilledButton) render in the same palette as token-driven feature code.
ColorScheme serlinkColorScheme(SerlinkTokens t, Brightness brightness) {
  final base = ColorScheme.fromSeed(
    seedColor: t.accentPrimary,
    brightness: brightness,
  );
  return base.copyWith(
    primary: t.accentPrimary,
    onPrimary: t.onAccent,
    primaryContainer: t.accentPrimary.withValues(alpha: 0.16),
    onPrimaryContainer: t.accentPrimary,
    surface: t.surfaceRaised,
    onSurface: t.textPrimary,
    surfaceContainerHighest: t.surfaceSunken,
    onSurfaceVariant: t.textSecondary,
    outline: t.borderStrong,
    outlineVariant: t.borderSubtle,
    error: t.statusDanger,
    onError: t.onAccent,
    errorContainer: t.statusDanger.withValues(alpha: 0.16),
    onErrorContainer: t.statusDanger,
  );
}

/// Standard 1px hairline border used by panels and sections.
Border serlinkHairline(SerlinkTokens t) =>
    Border.all(color: t.borderSubtle, width: 1);

/// Convenience for the standard panel/dialog shape.
RoundedRectangleBorder serlinkPanelShape(SerlinkTokens t) =>
    RoundedRectangleBorder(
      borderRadius: SerlinkRadii.dialog,
      side: BorderSide(color: t.borderSubtle),
    );
