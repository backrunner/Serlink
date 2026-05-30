import 'package:flutter/widgets.dart';

/// Spacing scale built on a 4px base unit. Use these named steps instead of
/// ad-hoc `SizedBox` / `EdgeInsets` magic numbers so spacing stays consistent
/// across every surface.
abstract final class SerlinkSpacing {
  /// 4px — tight gaps between closely related glyphs/controls.
  static const double xs = 4;

  /// 8px — default gap between rows and small clusters.
  static const double sm = 8;

  /// 12px — list/row inner padding, control gaps.
  static const double md = 12;

  /// 16px — block separation.
  static const double lg = 16;

  /// 24px — section padding / dialog insets.
  static const double xl = 24;

  /// 32px — large section separation.
  static const double xxl = 32;
}

/// Corner radii. Serlink leans into a soft, premium web aesthetic with
/// generous rounding:
///
/// * [control] (10px) — buttons, inputs, list rows, nav items, tabs.
/// * [dialog]  (14px) — dialogs, popovers, sections.
/// * [card]    (20px) — floating shell panels and feature cards.
/// * [pill]    (full) — status pills only.
abstract final class SerlinkRadii {
  static const Radius controlR = Radius.circular(10);
  static const Radius dialogR = Radius.circular(14);
  static const Radius cardR = Radius.circular(20);
  static const Radius pillR = Radius.circular(999);

  static const BorderRadius control = BorderRadius.all(controlR);
  static const BorderRadius dialog = BorderRadius.all(dialogR);
  static const BorderRadius card = BorderRadius.all(cardR);
  static const BorderRadius pill = BorderRadius.all(pillR);
}

/// Fixed structural sizes for the desktop shell. Values follow the spacing
/// guidance in the UI design system spec (sidebar 220-280px, toolbar 44px,
/// compact control 28px, standard control 32px).
abstract final class SerlinkSizes {
  static const double sidebarWidth = 240;
  static const double toolbarHeight = 44;
  static const double controlHeight = 32;
  static const double compactControlHeight = 28;

  /// Indent applied to in-section dividers so they align past the leading icon.
  static const double dividerIndent = 48;
}
