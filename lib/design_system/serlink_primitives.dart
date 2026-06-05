import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import 'serlink_context.dart';
import 'serlink_dimensions.dart';
import 'serlink_effects.dart';
import 'serlink_tokens.dart';

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
    final card = FCard.raw(
      clipBehavior: Clip.antiAlias,
      style: FCardStyleDelta.delta(
        decoration: DecorationDelta.value(
          ShapeDecoration(
            color: t.surfaceRaised,
            shape: RoundedRectangleBorder(
              borderRadius: borderRadius,
              side: BorderSide(color: t.borderSubtle),
            ),
          ),
        ),
      ),
      child: padding == null ? child : Padding(padding: padding!, child: child),
    );
    if (elevation <= 0) {
      return card;
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: serlinkShadow(t, elevation: elevation),
      ),
      child: card,
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

/// Lightweight press target used where Material ink is too heavy for Serlink's
/// custom surfaces and Forui dialogs.
class SerlinkPressable extends StatefulWidget {
  const SerlinkPressable({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius = SerlinkRadii.control,
    this.hoverColor,
    this.pressedColor,
    this.padding = EdgeInsets.zero,
    this.behavior = HitTestBehavior.opaque,
  });

  final Widget child;
  final VoidCallback? onTap;
  final BorderRadiusGeometry borderRadius;
  final Color? hoverColor;
  final Color? pressedColor;
  final EdgeInsetsGeometry padding;
  final HitTestBehavior behavior;

  @override
  State<SerlinkPressable> createState() => _SerlinkPressableState();
}

class _SerlinkPressableState extends State<SerlinkPressable> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final interactive = widget.onTap != null;
    final overlay = !interactive
        ? Colors.transparent
        : _pressed
        ? widget.pressedColor ?? t.accentPrimary.withValues(alpha: 0.1)
        : _hovered
        ? widget.hoverColor ?? t.accentPrimary.withValues(alpha: 0.06)
        : Colors.transparent;

    return MouseRegion(
      cursor: interactive ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: GestureDetector(
        behavior: widget.behavior,
        onTap: widget.onTap,
        onTapDown: interactive ? (_) => setState(() => _pressed = true) : null,
        onTapUp: interactive ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: interactive
            ? () => setState(() => _pressed = false)
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: overlay,
            borderRadius: widget.borderRadius,
          ),
          child: Padding(padding: widget.padding, child: widget.child),
        ),
      ),
    );
  }
}

class SerlinkListTile extends StatelessWidget {
  const SerlinkListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.enabled = true,
    this.dense = false,
    this.minLeadingWidth = 0,
    this.contentPadding,
    this.subtitleGap = 3,
  });

  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool enabled;
  final bool dense;
  final double minLeadingWidth;
  final EdgeInsetsGeometry? contentPadding;
  final double subtitleGap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final titleStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: t.textPrimary,
      fontWeight: FontWeight.w600,
    );
    final subtitleStyle = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: t.textSecondary);
    final verticalPadding = dense ? 7.0 : 10.0;
    final child = Row(
      children: [
        if (leading != null) ...[
          ConstrainedBox(
            constraints: BoxConstraints(minWidth: minLeadingWidth),
            child: IconTheme.merge(
              data: IconThemeData(
                size: dense ? 18 : 20,
                color: t.textSecondary,
              ),
              child: leading!,
            ),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DefaultTextStyle.merge(style: titleStyle, child: title),
              if (subtitle != null) ...[
                SizedBox(height: subtitleGap),
                DefaultTextStyle.merge(style: subtitleStyle, child: subtitle!),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 12), trailing!],
      ],
    );

    return Opacity(
      opacity: enabled ? 1 : 0.54,
      child: SerlinkPressable(
        onTap: enabled ? onTap : null,
        borderRadius: SerlinkRadii.control,
        padding:
            contentPadding ??
            EdgeInsets.symmetric(horizontal: 12, vertical: verticalPadding),
        child: child,
      ),
    );
  }
}

class SerlinkTag extends StatelessWidget {
  const SerlinkTag({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: t.surfaceOverlay,
        borderRadius: SerlinkRadii.pill,
        border: Border.all(color: t.borderSubtle),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: t.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class SerlinkChoiceChip extends StatefulWidget {
  const SerlinkChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.enabled = true,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool>? onSelected;
  final bool enabled;

  @override
  State<SerlinkChoiceChip> createState() => _SerlinkChoiceChipState();
}

class _SerlinkChoiceChipState extends State<SerlinkChoiceChip> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final interactive = widget.enabled && widget.onSelected != null;
    final foreground = widget.selected
        ? t.accentPrimary
        : _hovered && interactive
        ? t.textPrimary
        : t.textSecondary;
    final background = widget.selected
        ? t.accentPrimary.withValues(
            alpha: _pressed ? 0.22 : (_hovered ? 0.18 : 0.14),
          )
        : Color.alphaBlend(
            t.accentPrimary.withValues(
              alpha: _pressed ? 0.12 : (_hovered ? 0.07 : 0),
            ),
            t.surfaceSunken,
          );
    final border = widget.selected
        ? t.accentPrimary.withValues(alpha: 0.56)
        : _hovered && interactive
        ? t.accentPrimary.withValues(alpha: 0.34)
        : t.borderSubtle;

    return Opacity(
      opacity: interactive ? 1 : 0.52,
      child: MouseRegion(
        cursor: interactive ? SystemMouseCursors.click : MouseCursor.defer,
        onEnter: (_) {
          if (interactive) setState(() => _hovered = true);
        },
        onExit: (_) {
          if (interactive) {
            setState(() {
              _hovered = false;
              _pressed = false;
            });
          }
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: interactive
              ? () => widget.onSelected!(!widget.selected)
              : null,
          onTapDown: interactive
              ? (_) => setState(() => _pressed = true)
              : null,
          onTapUp: interactive ? (_) => setState(() => _pressed = false) : null,
          onTapCancel: interactive
              ? () => setState(() => _pressed = false)
              : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: background,
              borderRadius: SerlinkRadii.pill,
              border: Border.all(color: border),
            ),
            child: Text(
              widget.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SerlinkSegment<T> {
  const SerlinkSegment({
    required this.value,
    required this.label,
    required this.icon,
  });

  final T value;
  final String label;
  final IconData icon;
}

class SerlinkSegmentedControl<T> extends StatelessWidget {
  const SerlinkSegmentedControl({
    super.key,
    required this.value,
    required this.segments,
    required this.onChanged,
    this.enabled = true,
    this.compact = false,
  });

  final T value;
  final List<SerlinkSegment<T>> segments;
  final ValueChanged<T>? onChanged;
  final bool enabled;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final interactive = enabled && onChanged != null;
    return ClipRRect(
      borderRadius: SerlinkRadii.control,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: t.surfaceSunken,
          borderRadius: SerlinkRadii.control,
          border: Border.all(color: t.borderSubtle),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < segments.length; index += 1) ...[
              _SerlinkSegmentButton<T>(
                segment: segments[index],
                selected: segments[index].value == value,
                enabled: interactive,
                onSelected: onChanged,
                compact: compact,
              ),
              if (index < segments.length - 1)
                Container(width: 1, height: 26, color: t.borderSubtle),
            ],
          ],
        ),
      ),
    );
  }
}

class _SerlinkSegmentButton<T> extends StatelessWidget {
  const _SerlinkSegmentButton({
    required this.segment,
    required this.selected,
    required this.enabled,
    required this.onSelected,
    required this.compact,
  });

  final SerlinkSegment<T> segment;
  final bool selected;
  final bool enabled;
  final ValueChanged<T>? onSelected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final foreground = selected ? t.accentPrimary : t.textSecondary;
    return SerlinkPressable(
      onTap: enabled ? () => onSelected?.call(segment.value) : null,
      borderRadius: BorderRadius.zero,
      hoverColor: selected
          ? t.accentPrimary.withValues(alpha: 0.12)
          : t.accentPrimary.withValues(alpha: 0.06),
      pressedColor: selected
          ? t.accentPrimary.withValues(alpha: 0.18)
          : t.accentPrimary.withValues(alpha: 0.1),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        height: compact ? 32 : 34,
        padding: EdgeInsets.symmetric(horizontal: compact ? 9 : 12),
        color: selected
            ? t.accentPrimary.withValues(alpha: 0.12)
            : Colors.transparent,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(segment.icon, size: compact ? 15 : 16, color: foreground),
            SizedBox(width: compact ? 5 : 7),
            Text(
              segment.label,
              style:
                  (compact
                          ? Theme.of(context).textTheme.labelSmall
                          : Theme.of(context).textTheme.labelMedium)
                      ?.copyWith(
                        color: foreground,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w600,
                      ),
            ),
          ],
        ),
      ),
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
            : SerlinkPressable(
                onTap: widget.onTap,
                borderRadius: SerlinkRadii.dialog,
                hoverColor: Colors.transparent,
                child: content,
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

enum SerlinkAlertTone { info, success, warning, danger }

/// Unified inline alert used inside dialogs and forms. Keeps status color,
/// icon, spacing, and typography consistent while allowing richer bodies when
/// a destructive flow needs more than one sentence.
class SerlinkAlert extends StatelessWidget {
  const SerlinkAlert({
    super.key,
    this.tone = SerlinkAlertTone.info,
    this.title,
    this.message,
    this.child,
    this.icon,
    this.compact = false,
  }) : assert(message != null || child != null);

  const SerlinkAlert.info({
    super.key,
    this.title,
    this.message,
    this.child,
    this.icon,
    this.compact = false,
  }) : tone = SerlinkAlertTone.info,
       assert(message != null || child != null);

  const SerlinkAlert.success({
    super.key,
    this.title,
    this.message,
    this.child,
    this.icon,
    this.compact = false,
  }) : tone = SerlinkAlertTone.success,
       assert(message != null || child != null);

  const SerlinkAlert.warning({
    super.key,
    this.title,
    this.message,
    this.child,
    this.icon,
    this.compact = false,
  }) : tone = SerlinkAlertTone.warning,
       assert(message != null || child != null);

  const SerlinkAlert.danger({
    super.key,
    this.title,
    this.message,
    this.child,
    this.icon,
    this.compact = false,
  }) : tone = SerlinkAlertTone.danger,
       assert(message != null || child != null);

  final SerlinkAlertTone tone;
  final String? title;
  final String? message;
  final Widget? child;
  final IconData? icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final toneColor = _alertToneColor(t, tone);
    final resolvedIcon = icon ?? _alertToneIcon(tone);
    final padding = compact
        ? const EdgeInsets.all(12)
        : const EdgeInsets.symmetric(horizontal: 14, vertical: 13);
    final decoration = BoxDecoration(
      color: Color.alphaBlend(
        toneColor.withValues(alpha: 0.08),
        t.surfaceSunken,
      ),
      borderRadius: SerlinkRadii.dialog,
      border: Border.all(color: toneColor.withValues(alpha: 0.34)),
    );

    if (child == null) {
      final hasTitle = title != null;
      return FAlert(
        variant: tone == SerlinkAlertTone.danger
            ? FAlertVariant.destructive
            : FAlertVariant.primary,
        icon: Icon(resolvedIcon),
        title: Text(hasTitle ? title! : message!),
        subtitle: hasTitle && message != null ? Text(message!) : null,
        style: FAlertStyleDelta.delta(
          decoration: DecorationDelta.value(decoration),
          padding: EdgeInsetsGeometryDelta.value(padding),
          iconStyle: IconThemeDataDelta.value(
            IconThemeData(color: toneColor, size: compact ? 18 : 20),
          ),
          titleTextStyle: TextStyleDelta.value(
            TextStyle(
              color: hasTitle ? t.textPrimary : t.textSecondary,
              fontSize: compact ? 13 : 13.5,
              fontWeight: hasTitle ? FontWeight.w700 : FontWeight.w500,
              height: hasTitle ? 1.25 : 1.4,
            ),
          ),
          subtitleTextStyle: TextStyleDelta.value(
            TextStyle(
              color: t.textSecondary,
              fontSize: compact ? 12.5 : 13,
              height: 1.4,
            ),
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: decoration,
      child: Padding(
        padding: padding,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(top: title == null ? 1 : 2),
              child: Icon(
                resolvedIcon,
                size: compact ? 18 : 20,
                color: toneColor,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (title != null) ...[
                    Text(
                      title!,
                      style: TextStyle(
                        color: t.textPrimary,
                        fontSize: compact ? 13 : 13.5,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    SizedBox(height: compact ? 4 : 6),
                  ],
                  if (message != null)
                    Text(
                      message!,
                      style: TextStyle(
                        color: t.textSecondary,
                        fontSize: compact ? 12.5 : 13,
                        height: 1.4,
                      ),
                    ),
                  if (child != null) ...[
                    if (message != null) SizedBox(height: compact ? 6 : 8),
                    child!,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Color _alertToneColor(SerlinkTokens t, SerlinkAlertTone tone) {
  return switch (tone) {
    SerlinkAlertTone.info => t.statusInfo,
    SerlinkAlertTone.success => t.statusSuccess,
    SerlinkAlertTone.warning => t.statusWarning,
    SerlinkAlertTone.danger => t.statusDanger,
  };
}

IconData _alertToneIcon(SerlinkAlertTone tone) {
  return switch (tone) {
    SerlinkAlertTone.info => Icons.info_outline_rounded,
    SerlinkAlertTone.success => Icons.check_circle_outline_rounded,
    SerlinkAlertTone.warning => Icons.warning_amber_rounded,
    SerlinkAlertTone.danger => Icons.error_outline_rounded,
  };
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

/// macOS-style continuous slider that does not depend on a [Material] ancestor
/// (Material `Slider` throws "No Material widget found" inside forui dialogs).
/// Thin rounded track, accent active fill, and a circular knob with a soft
/// shadow, snapping to [divisions] when provided.
class SerlinkSlider extends StatelessWidget {
  const SerlinkSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.divisions,
  });

  final double value;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double> onChanged;

  static const double _knob = 18;
  static const double _track = 4;
  static const double _height = 24;

  double _quantize(double raw) {
    final clamped = raw.clamp(min, max);
    final divisions = this.divisions;
    if (divisions == null || divisions <= 0) {
      return clamped;
    }
    final step = (max - min) / divisions;
    return min + ((clamped - min) / step).round() * step;
  }

  void _emit(double localX, double width) {
    final usable = width - _knob;
    if (usable <= 0) {
      return;
    }
    final fraction = ((localX - _knob / 2) / usable).clamp(0.0, 1.0);
    onChanged(_quantize(min + fraction * (max - min)));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final fraction = max > min
        ? ((value - min) / (max - min)).clamp(0.0, 1.0)
        : 0.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final usable = width - _knob;
        final knobLeft = _knob / 2 + usable * fraction - _knob / 2;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) => _emit(details.localPosition.dx, width),
          onHorizontalDragStart: (details) =>
              _emit(details.localPosition.dx, width),
          onHorizontalDragUpdate: (details) =>
              _emit(details.localPosition.dx, width),
          child: SizedBox(
            height: _height,
            width: double.infinity,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Container(
                  height: _track,
                  decoration: BoxDecoration(
                    color: t.surfaceSunken,
                    borderRadius: SerlinkRadii.pill,
                    border: Border.all(color: t.borderSubtle),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: fraction,
                  child: Container(
                    height: _track,
                    decoration: BoxDecoration(
                      gradient: serlinkAccentGradient(t),
                      borderRadius: SerlinkRadii.pill,
                    ),
                  ),
                ),
                Positioned(
                  left: knobLeft.clamp(0.0, usable),
                  child: Container(
                    width: _knob,
                    height: _knob,
                    decoration: BoxDecoration(
                      color: t.surfaceRaised,
                      shape: BoxShape.circle,
                      border: Border.all(color: t.borderStrong),
                      boxShadow: serlinkShadow(t, elevation: 4),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
