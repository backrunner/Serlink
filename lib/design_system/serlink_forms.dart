import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import 'serlink_context.dart';

/// A form field wrapper that places a small uppercase-ish label above the
/// control, web-form style. Keeps spacing/typography consistent across the app
/// instead of relying on Material's floating labels.
class SerlinkLabeledField extends StatelessWidget {
  const SerlinkLabeledField({
    super.key,
    required this.label,
    required this.child,
    this.helper,
    this.trailing,
  });

  final String label;
  final Widget child;
  final String? helper;

  /// Optional widget shown at the far right of the label row (e.g. a status).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 7),
          child: Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  color: t.textSecondary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
              if (trailing != null) ...[const Spacer(), trailing!],
            ],
          ),
        ),
        child,
        if (helper != null)
          Padding(
            padding: const EdgeInsets.only(left: 2, top: 6),
            child: Text(
              helper!,
              style: TextStyle(color: t.textMuted, fontSize: 11.5, height: 1.3),
            ),
          ),
      ],
    );
  }
}

/// One option in a [SerlinkSelect].
class SerlinkSelectItem<T> {
  const SerlinkSelectItem({
    required this.value,
    required this.label,
    this.icon,
    this.searchText,
  });

  final T value;
  final String label;
  final IconData? icon;

  /// Extra text matched when filtering (defaults to [label]).
  final String? searchText;
}

/// Serlink-flavored Forui select. The public API stays intentionally small so
/// feature code does not need to know Forui's menu/search implementation.
class SerlinkSelect<T> extends StatelessWidget {
  const SerlinkSelect({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hintText = 'Select',
    this.searchable = false,
    this.searchHint = 'Search',
    this.menuMaxHeight = 320,
    this.menuMinWidth,
    this.size = FTextFieldSizeVariant.lg,
    this.compact = false,
  });

  final T? value;
  final List<SerlinkSelectItem<T>> items;
  final ValueChanged<T> onChanged;
  final String hintText;
  final bool searchable;
  final String searchHint;
  final double menuMaxHeight;
  final double? menuMinWidth;
  final FTextFieldSizeVariant size;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final compactStyle = compact ? _compactSelectStyle(context) : null;
    final contentConstraints = menuMinWidth == null
        ? FAutoWidthPortalConstraints(maxHeight: menuMaxHeight)
        : FPortalConstraints(
            minWidth: menuMinWidth!,
            maxWidth: menuMinWidth!,
            maxHeight: menuMaxHeight,
          );
    final children = [
      for (final item in items)
        FSelectItem<T>(
          value: item.value,
          prefix: item.icon == null ? null : Icon(item.icon, size: 16),
          title: Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
    ];

    if (searchable) {
      return FSelect<T>.searchBuilder(
        control: FSelectControl.lifted(
          value: value,
          onChange: (value) {
            if (value != null) {
              onChanged(value);
            }
          },
        ),
        size: size,
        style: compactStyle ?? const FSelectStyleDelta.context(),
        hint: hintText,
        searchFieldProperties: FSelectSearchFieldProperties(hint: searchHint),
        contentConstraints: contentConstraints,
        filter: (query) {
          final normalized = query.trim().toLowerCase();
          if (normalized.isEmpty) {
            return items.map((item) => item.value);
          }
          return items
              .where(
                (item) => (item.searchText ?? item.label)
                    .toLowerCase()
                    .contains(normalized),
              )
              .map((item) => item.value);
        },
        contentBuilder: (_, _, values) {
          final visible = values.toSet();
          return [
            for (final child in children)
              if (visible.contains(child.value)) child,
          ];
        },
        format: _format,
      );
    }

    return FSelect<T>.rich(
      control: FSelectControl.lifted(
        value: value,
        onChange: (value) {
          if (value != null) {
            onChanged(value);
          }
        },
      ),
      size: size,
      style: compactStyle ?? const FSelectStyleDelta.context(),
      hint: hintText,
      contentConstraints: contentConstraints,
      format: _format,
      children: children,
    );
  }

  FSelectStyleDelta _compactSelectStyle(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      fontSize: 12.5,
      fontWeight: FontWeight.w600,
      height: 1.1,
    );
    return FSelectStyleDelta.delta(
      fieldStyles: FVariantsDelta.delta([
        FVariantOperation.all(
          FTextFieldStyleDelta.delta(
            constraints: const BoxConstraints(minHeight: 32),
            contentPadding: const EdgeInsetsGeometryDelta.value(
              EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            ),
            contentTextStyle: textStyle == null
                ? null
                : FVariantsDelta.delta([
                    FVariantOperation.all(TextStyleDelta.value(textStyle)),
                  ]),
            hintTextStyle: textStyle == null
                ? null
                : FVariantsDelta.delta([
                    FVariantOperation.all(TextStyleDelta.value(textStyle)),
                  ]),
          ),
        ),
      ]),
    );
  }

  String _format(T value) {
    for (final item in items) {
      if (item.value == value) {
        return item.label;
      }
    }
    return value.toString();
  }
}
