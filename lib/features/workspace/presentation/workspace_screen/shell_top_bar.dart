part of '../workspace_screen.dart';

class _TopBar extends ConsumerStatefulWidget {
  const _TopBar({
    required this.showSearch,
    required this.searchPlaceholder,
    required this.showLocalTerminal,
    required this.onOpenLocalTerminal,
  });

  final bool showSearch;
  final String searchPlaceholder;
  final bool showLocalTerminal;
  final VoidCallback onOpenLocalTerminal;

  @override
  ConsumerState<_TopBar> createState() => _TopBarState();
}

class _TopBarState extends ConsumerState<_TopBar> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(_workspaceSearchQueryProvider);
    if (_searchController.text != query) {
      _searchController.value = TextEditingValue(
        text: query,
        selection: TextSelection.collapsed(offset: query.length),
      );
    }
    return SurfaceToolbar(
      child: Row(
        children: [
          if (widget.showSearch) ...[
            SizedBox(
              width: 320,
              child: _TopBarSearchPill(
                controller: _searchController,
                placeholder: widget.searchPlaceholder,
                hasQuery: query.trim().isNotEmpty,
                onChanged: (value) {
                  ref
                      .read(_workspaceSearchQueryProvider.notifier)
                      .setQuery(value);
                },
                onClear: () {
                  _searchController.clear();
                  ref.read(_workspaceSearchQueryProvider.notifier).clear();
                },
              ),
            ),
            const SizedBox(width: 12),
          ],
          const Expanded(child: _WindowDragRegion()),
          if (widget.showLocalTerminal)
            Tooltip(
              message: 'Open local terminal tab',
              child: IconButton(
                style: const ButtonStyle(
                  padding: WidgetStatePropertyAll(EdgeInsets.zero),
                  minimumSize: WidgetStatePropertyAll(Size.square(30)),
                  fixedSize: WidgetStatePropertyAll(Size.square(30)),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: WidgetStatePropertyAll(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                    ),
                  ),
                ),
                onPressed: widget.onOpenLocalTerminal,
                icon: const Icon(Icons.terminal_outlined, size: 18),
              ),
            ),
          if (AppWindow.usesTrailingWindowControls) ...[
            const SizedBox(width: 6),
            const _WindowControls(),
          ],
        ],
      ),
    );
  }
}

/// Compact pill-shaped search input used in the top bar. Borderless field with
/// hover/focus border states, prefix glyph, and an inline clear button.
class _TopBarSearchPill extends StatefulWidget {
  const _TopBarSearchPill({
    required this.controller,
    required this.placeholder,
    required this.hasQuery,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final String placeholder;
  final bool hasQuery;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  State<_TopBarSearchPill> createState() => _TopBarSearchPillState();
}

class _TopBarSearchPillState extends State<_TopBarSearchPill> {
  final FocusNode _focusNode = FocusNode();
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocus);
  }

  void _handleFocus() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocus);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final focused = _focusNode.hasFocus;
    final borderColor = focused
        ? t.accentPrimary
        : _hovered
        ? t.borderStrong
        : t.borderSubtle;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        height: 34,
        padding: const EdgeInsets.only(left: 11, right: 6),
        decoration: BoxDecoration(
          color: focused ? t.surfaceBase : t.surfaceSunken,
          borderRadius: SerlinkRadii.pill,
          border: Border.all(color: borderColor, width: focused ? 1.4 : 1),
        ),
        child: Row(
          children: [
            Icon(
              Icons.search,
              size: 15,
              color: focused ? t.accentPrimary : t.textMuted,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                key: const ValueKey('workspace-search-field'),
                controller: widget.controller,
                focusNode: _focusNode,
                style: TextStyle(color: t.textPrimary, fontSize: 13.5),
                decoration: InputDecoration(
                  isCollapsed: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 9),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  hintText: widget.placeholder,
                  hintStyle: TextStyle(color: t.textMuted, fontSize: 13.5),
                ),
                onChanged: widget.onChanged,
              ),
            ),
            if (widget.hasQuery)
              _ClearChip(onTap: widget.onClear)
            else
              const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}

class _ClearChip extends StatefulWidget {
  const _ClearChip({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_ClearChip> createState() => _ClearChipState();
}

class _ClearChipState extends State<_ClearChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: Tooltip(
        message: 'Clear search',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _hovered
                  ? t.surfaceOverlay
                  : t.surfaceOverlay.withValues(alpha: 0.6),
            ),
            child: Icon(Icons.close, size: 12, color: t.textSecondary),
          ),
        ),
      ),
    );
  }
}
