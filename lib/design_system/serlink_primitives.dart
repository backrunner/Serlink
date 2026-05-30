import 'package:flutter/material.dart';

import 'serlink_context.dart';
import 'serlink_dimensions.dart';
import 'serlink_effects.dart';

/// A raised surface: filled with `surfaceRaised`, a hairline border, generous
/// rounding, and an optional soft drop shadow. The premium replacement for
/// Material `Card` chrome on primary work surfaces.
class SurfacePanel extends StatelessWidget {
  const SurfacePanel({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = SerlinkRadii.dialog,
    this.elevation = 0,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BorderRadius borderRadius;

  /// Soft-shadow depth. 0 keeps the surface flat (default for nested panels).
  final double elevation;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final material = Material(
      color: t.surfaceRaised,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius,
        side: BorderSide(color: t.borderSubtle),
      ),
      child: padding == null
          ? child
          : Padding(padding: padding!, child: child),
    );
    if (elevation <= 0) {
      return material;
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: serlinkShadow(t, elevation: elevation),
      ),
      child: material,
    );
  }
}

/// A titled group of rows used across Settings and the Import/Export dialog.
/// Replaces the duplicated `_SettingsSection` and `_DataExchangeSection`.
class SurfaceSection extends StatelessWidget {
  const SurfaceSection({
    super.key,
    required this.title,
    required this.children,
    this.dividerIndent = SerlinkSizes.dividerIndent,
  });

  final String title;
  final List<Widget> children;
  final double dividerIndent;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        rows.add(
          Divider(
            height: 1,
            thickness: 1,
            indent: dividerIndent,
            color: t.borderSubtle,
          ),
        );
      }
      rows.add(children[i]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: SerlinkSpacing.sm),
          child: Text(
            title,
            style: TextStyle(
              color: t.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ),
        SurfacePanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: rows,
          ),
        ),
      ],
    );
  }
}

/// A raised, optionally tappable list row used on primary surfaces (hosts,
/// snippets, transfers). Rounded card with a hairline border that lifts with a
/// soft shadow on hover and tints with the accent when selected.
class ListRow extends StatefulWidget {
  const ListRow({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(SerlinkSpacing.lg),
    this.selected = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final bool selected;

  @override
  State<ListRow> createState() => _ListRowState();
}

class _ListRowState extends State<ListRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final interactive = widget.onTap != null;
    final lifted = _hovered && interactive;
    final fill = widget.selected
        ? Color.alphaBlend(
            t.accentPrimary.withValues(alpha: 0.12),
            t.surfaceRaised,
          )
        : t.surfaceRaised;
    final borderColor = widget.selected
        ? t.accentPrimary.withValues(alpha: 0.6)
        : lifted
        ? t.borderStrong
        : t.borderSubtle;

    final content = Padding(padding: widget.padding, child: widget.child);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        transform: lifted
            ? (Matrix4.identity()..translateByDouble(0.0, -2.0, 0.0, 1.0))
            : Matrix4.identity(),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: SerlinkRadii.dialog,
          border: Border.all(color: borderColor),
          boxShadow: widget.selected
              ? serlinkShadow(t, elevation: 8, opacity: 0.7)
              : lifted
              ? serlinkShadow(t, elevation: 10)
              : null,
        ),
        child: !interactive
            ? content
            : Material(
                color: Colors.transparent,
                borderRadius: SerlinkRadii.dialog,
                child: InkWell(
                  borderRadius: SerlinkRadii.dialog,
                  onTap: widget.onTap,
                  child: content,
                ),
              ),
      ),
    );
  }
}

/// Compact status badge: tinted fill + border in a status color, pill radius.
/// Replaces `_SettingsStatusPill` and the inline trust/health markers.
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: SerlinkRadii.pill,
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Horizontal toolbar/header strip: fixed height, raised fill, bottom hairline.
class SurfaceToolbar extends StatelessWidget {
  const SurfaceToolbar({
    super.key,
    required this.child,
    this.height = SerlinkSizes.toolbarHeight,
    this.padding = const EdgeInsets.symmetric(horizontal: SerlinkSpacing.md),
  });

  final Widget child;
  final double height;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: t.surfaceRaised,
        border: Border(bottom: BorderSide(color: t.borderSubtle)),
      ),
      child: child,
    );
  }
}
