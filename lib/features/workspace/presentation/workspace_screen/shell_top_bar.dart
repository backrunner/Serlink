part of '../workspace_screen.dart';

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return SurfaceToolbar(
      child: Row(
        children: [
          const Expanded(child: _WindowDragRegion()),
          if (AppWindow.usesTrailingWindowControls) ...[
            const _WindowControls(),
          ],
        ],
      ),
    );
  }
}

class _WorkspaceHeaderSearch extends ConsumerStatefulWidget {
  const _WorkspaceHeaderSearch({required this.placeholder});

  final String placeholder;

  @override
  ConsumerState<_WorkspaceHeaderSearch> createState() =>
      _WorkspaceHeaderSearchState();
}

class _WorkspaceHeaderSearchState
    extends ConsumerState<_WorkspaceHeaderSearch> {
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
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 180, maxWidth: 300),
      child: _WorkspaceSearchPill(
        fieldKey: const ValueKey('workspace-search-field'),
        controller: _searchController,
        placeholder: widget.placeholder,
        enabled: true,
        hasQuery: query.trim().isNotEmpty,
        onChanged: (value) {
          ref.read(_workspaceSearchQueryProvider.notifier).setQuery(value);
        },
        onClear: () {
          _searchController.clear();
          ref.read(_workspaceSearchQueryProvider.notifier).clear();
        },
      ),
    );
  }
}

/// Compact pill-shaped search input with hover/focus border states, prefix
/// glyph, and an inline clear button.
class _WorkspaceSearchPill extends StatefulWidget {
  const _WorkspaceSearchPill({
    required this.fieldKey,
    required this.controller,
    required this.placeholder,
    required this.enabled,
    required this.hasQuery,
    required this.onChanged,
    required this.onClear,
  });

  final Key fieldKey;
  final TextEditingController controller;
  final String placeholder;
  final bool enabled;
  final bool hasQuery;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  State<_WorkspaceSearchPill> createState() => _WorkspaceSearchPillState();
}

class _WorkspaceSearchPillState extends State<_WorkspaceSearchPill> {
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
    final focused = widget.enabled && _focusNode.hasFocus;
    final hovered = widget.enabled && _hovered;
    final borderColor = focused
        ? t.accentPrimary
        : hovered
        ? t.borderStrong
        : t.borderSubtle;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 130),
        opacity: widget.enabled ? 1 : 0.56,
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
                child: SerlinkTextField(
                  key: widget.fieldKey,
                  controller: widget.controller,
                  enabled: widget.enabled,
                  focusNode: _focusNode,
                  style: TextStyle(color: t.textPrimary, fontSize: 13.5),
                  decoration: InputDecoration(
                    isCollapsed: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 9),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    filled: false,
                    hintText: widget.placeholder,
                    hintStyle: TextStyle(color: t.textMuted, fontSize: 13.5),
                  ),
                  onChanged: widget.onChanged,
                ),
              ),
              if (widget.enabled && widget.hasQuery)
                _ClearChip(onTap: widget.onClear)
              else
                const SizedBox(width: 4),
            ],
          ),
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
    final l10n = context.l10n;
    final t = context.tokens;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: SerlinkTooltip(
        message: l10n.clearSearchTooltip,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _hovered
                  ? t.accentPrimary.withValues(alpha: 0.12)
                  : t.surfaceOverlay,
            ),
            child: Icon(Icons.close, size: 12, color: t.textSecondary),
          ),
        ),
      ),
    );
  }
}
