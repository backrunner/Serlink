import 'package:flutter/material.dart';

import 'serlink_context.dart';
import 'serlink_dimensions.dart';
import 'serlink_effects.dart';

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

/// A clean, web-style select control. Renders an input-shaped trigger and an
/// anchored popover list with hover + selected states, an optional inline
/// search box, and a soft shadow. Replaces Material's `DropdownMenu`, which is
/// awkward to theme and visually heavy.
class SerlinkSelect<T> extends StatefulWidget {
  const SerlinkSelect({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hintText = 'Select',
    this.searchable = false,
    this.searchHint = 'Search',
    this.menuMaxHeight = 320,
  });

  final T? value;
  final List<SerlinkSelectItem<T>> items;
  final ValueChanged<T> onChanged;
  final String hintText;
  final bool searchable;
  final String searchHint;
  final double menuMaxHeight;

  @override
  State<SerlinkSelect<T>> createState() => _SerlinkSelectState<T>();
}

class _SerlinkSelectState<T> extends State<SerlinkSelect<T>> {
  final LayerLink _link = LayerLink();
  final GlobalKey _triggerKey = GlobalKey();
  OverlayEntry? _entry;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _removeOverlay();
    _searchController.dispose();
    super.dispose();
  }

  SerlinkSelectItem<T>? get _selected {
    for (final item in widget.items) {
      if (item.value == widget.value) {
        return item;
      }
    }
    return null;
  }

  void _toggle() {
    if (_entry != null) {
      _removeOverlay();
    } else {
      _openOverlay();
    }
  }

  void _removeOverlay() {
    _entry?.remove();
    _entry = null;
    _searchController.clear();
  }

  void _openOverlay() {
    final box = _triggerKey.currentContext?.findRenderObject() as RenderBox?;
    final width = box?.size.width ?? 240;
    _entry = OverlayEntry(
      builder: (context) => _SerlinkSelectOverlay<T>(
        link: _link,
        width: width,
        items: widget.items,
        selected: widget.value,
        searchable: widget.searchable,
        searchHint: widget.searchHint,
        searchController: _searchController,
        menuMaxHeight: widget.menuMaxHeight,
        onDismiss: _removeOverlay,
        onPick: (value) {
          _removeOverlay();
          widget.onChanged(value);
        },
      ),
    );
    Overlay.of(context).insert(_entry!);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final selected = _selected;
    final open = _entry != null;
    return CompositedTransformTarget(
      link: _link,
      child: _SelectTrigger(
        key: _triggerKey,
        open: open,
        icon: selected?.icon,
        label: selected?.label ?? widget.hintText,
        placeholder: selected == null,
        onTap: _toggle,
        accent: t.accentPrimary,
      ),
    );
  }
}

class _SelectTrigger extends StatefulWidget {
  const _SelectTrigger({
    super.key,
    required this.open,
    required this.label,
    required this.placeholder,
    required this.onTap,
    required this.accent,
    this.icon,
  });

  final bool open;
  final String label;
  final bool placeholder;
  final VoidCallback onTap;
  final Color accent;
  final IconData? icon;

  @override
  State<_SelectTrigger> createState() => _SelectTriggerState();
}

class _SelectTriggerState extends State<_SelectTrigger> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final borderColor = widget.open
        ? widget.accent
        : _hovered
        ? t.borderStrong
        : t.borderSubtle;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: t.surfaceSunken,
            borderRadius: SerlinkRadii.control,
            border: Border.all(
              color: borderColor,
              width: widget.open ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 17, color: t.textSecondary),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: widget.placeholder ? t.textMuted : t.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              AnimatedRotation(
                turns: widget.open ? 0.5 : 0,
                duration: const Duration(milliseconds: 160),
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: t.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The anchored popover for [SerlinkSelect]: a full-screen barrier (to catch
/// outside taps) plus a positioned, shadowed list following the trigger.
class _SerlinkSelectOverlay<T> extends StatefulWidget {
  const _SerlinkSelectOverlay({
    required this.link,
    required this.width,
    required this.items,
    required this.selected,
    required this.searchable,
    required this.searchHint,
    required this.searchController,
    required this.menuMaxHeight,
    required this.onDismiss,
    required this.onPick,
  });

  final LayerLink link;
  final double width;
  final List<SerlinkSelectItem<T>> items;
  final T? selected;
  final bool searchable;
  final String searchHint;
  final TextEditingController searchController;
  final double menuMaxHeight;
  final VoidCallback onDismiss;
  final ValueChanged<T> onPick;

  @override
  State<_SerlinkSelectOverlay<T>> createState() =>
      _SerlinkSelectOverlayState<T>();
}

class _SerlinkSelectOverlayState<T> extends State<_SerlinkSelectOverlay<T>> {
  String _query = '';

  List<SerlinkSelectItem<T>> get _filtered {
    if (_query.trim().isEmpty) {
      return widget.items;
    }
    final q = _query.toLowerCase();
    return widget.items.where((item) {
      final hay = (item.searchText ?? item.label).toLowerCase();
      return hay.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final items = _filtered;
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: widget.onDismiss,
          ),
        ),
        CompositedTransformFollower(
          link: widget.link,
          showWhenUnlinked: false,
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          offset: const Offset(0, 6),
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: widget.width,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: SerlinkRadii.dialog,
                  boxShadow: serlinkShadow(t, elevation: 18),
                ),
                child: ClipRRect(
                  borderRadius: SerlinkRadii.dialog,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: t.surfaceRaised,
                      borderRadius: SerlinkRadii.dialog,
                      border: Border.all(color: t.borderSubtle),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.searchable)
                          _OverlaySearch(
                            controller: widget.searchController,
                            hint: widget.searchHint,
                            onChanged: (v) => setState(() => _query = v),
                          ),
                        Flexible(
                          child: items.isEmpty
                              ? Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 18,
                                  ),
                                  child: Text(
                                    'No matches',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: t.textMuted),
                                  ),
                                )
                              : ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxHeight: widget.menuMaxHeight,
                                  ),
                                  child: ListView.builder(
                                    padding: const EdgeInsets.all(6),
                                    shrinkWrap: true,
                                    itemCount: items.length,
                                    itemBuilder: (context, index) {
                                      final item = items[index];
                                      return _OverlayOption<T>(
                                        item: item,
                                        selected: item.value == widget.selected,
                                        onTap: () => widget.onPick(item.value),
                                      );
                                    },
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _OverlaySearch extends StatelessWidget {
  const _OverlaySearch({
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: TextField(
        controller: controller,
        autofocus: true,
        onChanged: onChanged,
        style: TextStyle(color: t.textPrimary, fontSize: 13.5),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: t.surfaceSunken,
          hintText: hint,
          prefixIcon: Icon(Icons.search, size: 16, color: t.textMuted),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 10,
          ),
          border: OutlineInputBorder(
            borderRadius: SerlinkRadii.control,
            borderSide: BorderSide(color: t.borderSubtle),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: SerlinkRadii.control,
            borderSide: BorderSide(color: t.borderSubtle),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: SerlinkRadii.control,
            borderSide: BorderSide(color: t.accentPrimary, width: 1.4),
          ),
        ),
      ),
    );
  }
}

class _OverlayOption<T> extends StatefulWidget {
  const _OverlayOption({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final SerlinkSelectItem<T> item;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_OverlayOption<T>> createState() => _OverlayOptionState<T>();
}

class _OverlayOptionState<T> extends State<_OverlayOption<T>> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final bg = widget.selected
        ? t.accentPrimary.withValues(alpha: 0.14)
        : _hovered
        ? t.surfaceOverlay
        : Colors.transparent;
    final fg = widget.selected ? t.accentPrimary : t.textPrimary;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 1),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: SerlinkRadii.control,
          ),
          child: Row(
            children: [
              if (widget.item.icon != null) ...[
                Icon(widget.item.icon, size: 16, color: fg),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  widget.item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: fg,
                    fontWeight: widget.selected
                        ? FontWeight.w600
                        : FontWeight.w500,
                  ),
                ),
              ),
              if (widget.selected)
                Icon(Icons.check_rounded, size: 17, color: t.accentPrimary),
            ],
          ),
        ),
      ),
    );
  }
}

