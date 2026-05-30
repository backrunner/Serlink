part of '../workspace_screen.dart';

final _workspaceSearchQueryProvider =
    NotifierProvider<_WorkspaceSearchQueryController, String>(
      _WorkspaceSearchQueryController.new,
    );

class _WorkspaceSearchQueryController extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) {
    state = query;
  }

  void clear() {
    state = '';
  }
}

class WorkspaceScreen extends ConsumerWidget {
  const WorkspaceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(workspaceTabControllerProvider);
    final controller = ref.read(workspaceTabControllerProvider.notifier);
    final showSearch = _showsWorkspaceSearch(state.area);
    final showLocalTerminal = _showsLocalTerminalAction(state.area);
    final showTopBar =
        showSearch || showLocalTerminal || AppWindow.usesTrailingWindowControls;

    return Scaffold(
      body: DecoratedBox(
        decoration: _workspaceBackdrop(context),
        child: Row(
          children: [
            _Sidebar(selected: state.area, onSelected: controller.selectArea),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 10, 10, 10),
                child: Material(
                  color: _workspacePanelColor(context),
                  elevation: _workspacePanelElevation(context),
                  shadowColor: _workspacePanelShadowColor(context),
                  shape: _workspacePanelShape(context),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Column(
                      children: [
                        if (showTopBar) ...[
                          _TopBar(
                            showSearch: showSearch,
                            searchPlaceholder: _workspaceSearchPlaceholder(
                              state.area,
                            ),
                            showLocalTerminal: showLocalTerminal,
                            onOpenLocalTerminal: controller.openLocalTerminal,
                          ),
                          const Divider(height: 1),
                        ],
                        Expanded(child: _MainSurface(state: state)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

BoxDecoration _workspaceBackdrop(BuildContext context) {
  final scheme = Theme.of(context).colorScheme;
  final dark = scheme.brightness == Brightness.dark;
  return BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: dark
          ? const [Color(0xFF10151C), Color(0xFF0D1117), Color(0xFF141821)]
          : const [Color(0xFFF6F8FA), Color(0xFFEFF4FB), Color(0xFFFDFEFF)],
    ),
  );
}

Color _workspacePanelColor(BuildContext context) {
  final scheme = Theme.of(context).colorScheme;
  final dark = scheme.brightness == Brightness.dark;
  return scheme.surface.withValues(alpha: dark ? 0.86 : 0.92);
}

double _workspacePanelElevation(BuildContext context) {
  return Theme.of(context).colorScheme.brightness == Brightness.dark ? 10 : 7;
}

Color _workspacePanelShadowColor(BuildContext context) {
  return Theme.of(context).colorScheme.brightness == Brightness.dark
      ? const Color(0x66000000)
      : const Color(0x1F1F2937);
}

ShapeBorder _workspacePanelShape(BuildContext context) {
  final dark = Theme.of(context).colorScheme.brightness == Brightness.dark;
  return RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(8),
    side: BorderSide(
      color: dark ? const Color(0xFF2A3038) : const Color(0xFFD8DEE4),
    ),
  );
}

bool _showsWorkspaceSearch(WorkspaceArea area) {
  return switch (area) {
    WorkspaceArea.hosts || WorkspaceArea.snippets => true,
    WorkspaceArea.sessions ||
    WorkspaceArea.transfers ||
    WorkspaceArea.settings => false,
  };
}

bool _showsLocalTerminalAction(WorkspaceArea area) {
  return switch (area) {
    WorkspaceArea.hosts ||
    WorkspaceArea.sessions ||
    WorkspaceArea.snippets => true,
    WorkspaceArea.transfers || WorkspaceArea.settings => false,
  };
}

String _workspaceSearchPlaceholder(WorkspaceArea area) {
  return switch (area) {
    WorkspaceArea.hosts => 'Search hosts by name, host, user, tag',
    WorkspaceArea.snippets => 'Search snippets by name, command, tag',
    WorkspaceArea.sessions => 'Search sessions',
    WorkspaceArea.transfers => 'Search transfers',
    WorkspaceArea.settings => 'Search settings',
  };
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.selected, required this.onSelected});

  final WorkspaceArea selected;
  final ValueChanged<WorkspaceArea> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 196,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: DecoratedBox(
            decoration: _sidebarDecoration(context),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 0, 6, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _BrandHeader(),
                  _NavItem(
                    icon: Icons.dns_outlined,
                    label: 'Hosts',
                    selected: selected == WorkspaceArea.hosts,
                    onTap: () => onSelected(WorkspaceArea.hosts),
                  ),
                  _NavItem(
                    icon: Icons.terminal_outlined,
                    label: 'Sessions',
                    selected: selected == WorkspaceArea.sessions,
                    onTap: () => onSelected(WorkspaceArea.sessions),
                  ),
                  _NavItem(
                    icon: Icons.sync_alt_outlined,
                    label: 'Transfers',
                    selected: selected == WorkspaceArea.transfers,
                    onTap: () => onSelected(WorkspaceArea.transfers),
                  ),
                  _NavItem(
                    icon: Icons.code_outlined,
                    label: 'Snippets',
                    selected: selected == WorkspaceArea.snippets,
                    onTap: () => onSelected(WorkspaceArea.snippets),
                  ),
                  const Spacer(),
                  _NavItem(
                    icon: Icons.settings_outlined,
                    label: 'Settings',
                    selected: selected == WorkspaceArea.settings,
                    onTap: () => onSelected(WorkspaceArea.settings),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

BoxDecoration _sidebarDecoration(BuildContext context) {
  final scheme = Theme.of(context).colorScheme;
  final dark = scheme.brightness == Brightness.dark;
  return BoxDecoration(
    color: scheme.surface.withValues(alpha: dark ? 0.46 : 0.62),
    border: Border(
      right: BorderSide(
        color: dark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.white.withValues(alpha: 0.72),
      ),
    ),
  );
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    final content = AppWindow.usesMacStyleChrome
        ? SizedBox(
            height: 48,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  const _MacWindowControls(),
                  const SizedBox(width: 12),
                  const Expanded(child: _WindowDragRegion()),
                ],
              ),
            ),
          )
        : Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: const _BrandMark(),
          );

    if (!AppWindow.usesCustomChrome) {
      return content;
    }
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (_) => unawaited(AppWindow.startDrag()),
      onDoubleTap: () => unawaited(AppWindow.toggleMaximize()),
      child: content,
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const iconSize = 28.0;
    return Row(
      children: [
        Container(
          width: iconSize,
          height: iconSize,
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.hub_outlined,
            size: 18,
            color: scheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            'Serlink',
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected
              ? scheme.primary.withValues(alpha: dark ? 0.18 : 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? scheme.primary.withValues(alpha: dark ? 0.30 : 0.20)
                : Colors.transparent,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: dark ? 0.18 : 0.10),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: selected ? scheme.primary : scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: TextStyle(
                        color: selected ? scheme.primary : scheme.onSurface,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    return SizedBox(
      height: 48,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(
            alpha: dark ? 0.18 : 0.46,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              if (widget.showSearch) ...[
                SizedBox(
                  width: 312,
                  child: TextField(
                    key: const ValueKey('workspace-search-field'),
                    controller: _searchController,
                    decoration: InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: scheme.surface.withValues(
                        alpha: dark ? 0.72 : 0.86,
                      ),
                      hintText: widget.searchPlaceholder,
                      prefixIcon: const Icon(Icons.search, size: 18),
                      suffixIcon: query.trim().isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              onPressed: () {
                                _searchController.clear();
                                ref
                                    .read(
                                      _workspaceSearchQueryProvider.notifier,
                                    )
                                    .clear();
                              },
                              icon: const Icon(Icons.close, size: 16),
                            ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 11,
                      ),
                      border: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(999)),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(999)),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(999),
                        borderSide: BorderSide(color: scheme.primary, width: 1),
                      ),
                    ),
                    onChanged: (value) {
                      ref
                          .read(_workspaceSearchQueryProvider.notifier)
                          .setQuery(value);
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
                    onPressed: widget.onOpenLocalTerminal,
                    icon: const Icon(Icons.terminal_outlined),
                  ),
                ),
              if (AppWindow.usesTrailingWindowControls) ...[
                const SizedBox(width: 6),
                const _WindowControls(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MacWindowControls extends StatefulWidget {
  const _MacWindowControls();

  @override
  State<_MacWindowControls> createState() => _MacWindowControlsState();
}

class _MacWindowControlsState extends State<_MacWindowControls> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() {
        _hovered = true;
      }),
      onExit: (_) => setState(() {
        _hovered = false;
      }),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MacWindowControlButton(
            label: 'Close window',
            color: const Color(0xFFFF5F57),
            borderColor: const Color(0xFFE0443E),
            icon: Icons.close_rounded,
            showIcon: _hovered,
            onPressed: () => unawaited(AppWindow.close()),
          ),
          const SizedBox(width: 8),
          _MacWindowControlButton(
            label: 'Minimize window',
            color: const Color(0xFFFFBD2E),
            borderColor: const Color(0xFFDEA123),
            icon: Icons.remove_rounded,
            showIcon: _hovered,
            onPressed: () => unawaited(AppWindow.minimize()),
          ),
          const SizedBox(width: 8),
          _MacWindowControlButton(
            label: 'Zoom window',
            color: const Color(0xFF28C840),
            borderColor: const Color(0xFF1DAC2B),
            icon: Icons.add_rounded,
            showIcon: _hovered,
            onPressed: () => unawaited(AppWindow.toggleMaximize()),
          ),
        ],
      ),
    );
  }
}

class _MacWindowControlButton extends StatelessWidget {
  const _MacWindowControlButton({
    required this.label,
    required this.color,
    required this.borderColor,
    required this.icon,
    required this.showIcon,
    required this.onPressed,
  });

  final String label;
  final Color color;
  final Color borderColor;
  final IconData icon;
  final bool showIcon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: SizedBox.square(
          dimension: 14,
          child: Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: borderColor, width: 0.7),
              ),
              child: SizedBox.square(
                dimension: 12,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 90),
                  opacity: showIcon ? 1 : 0,
                  child: Icon(
                    icon,
                    size: 8.5,
                    color: const Color(0xFF4E1111).withValues(alpha: 0.82),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WindowDragRegion extends StatelessWidget {
  const _WindowDragRegion();

  @override
  Widget build(BuildContext context) {
    if (!AppWindow.usesCustomChrome) {
      return const SizedBox.shrink();
    }
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (_) => unawaited(AppWindow.startDrag()),
      onDoubleTap: () => unawaited(AppWindow.toggleMaximize()),
      child: const SizedBox.expand(),
    );
  }
}

class _WindowControls extends StatefulWidget {
  const _WindowControls();

  @override
  State<_WindowControls> createState() => _WindowControlsState();
}

class _WindowControlsState extends State<_WindowControls> {
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    unawaited(_refreshMaximized());
  }

  Future<void> _refreshMaximized() async {
    final maximized = await AppWindow.isMaximized();
    if (!mounted) {
      return;
    }
    setState(() {
      _isMaximized = maximized;
    });
  }

  Future<void> _toggleMaximize() async {
    final maximized = await AppWindow.toggleMaximize();
    if (!mounted) {
      return;
    }
    setState(() {
      _isMaximized = maximized;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _WindowControlButton(
          icon: Icons.remove_rounded,
          onPressed: () => unawaited(AppWindow.minimize()),
        ),
        _WindowControlButton(
          icon: _isMaximized
              ? Icons.filter_none_rounded
              : Icons.crop_square_rounded,
          onPressed: () => unawaited(_toggleMaximize()),
        ),
        _WindowControlButton(
          icon: Icons.close_rounded,
          isClose: true,
          onPressed: () => unawaited(AppWindow.close()),
        ),
      ],
    );
  }
}

class _WindowControlButton extends StatefulWidget {
  const _WindowControlButton({
    required this.icon,
    required this.onPressed,
    this.isClose = false,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final bool isClose;

  @override
  State<_WindowControlButton> createState() => _WindowControlButtonState();
}

class _WindowControlButtonState extends State<_WindowControlButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = _hovered
        ? widget.isClose
              ? const Color(0xFFE81123)
              : scheme.onSurface.withValues(alpha: 0.08)
        : Colors.transparent;
    final foreground = _hovered && widget.isClose
        ? Colors.white
        : scheme.onSurfaceVariant;

    return MouseRegion(
      onEnter: (_) => setState(() {
        _hovered = true;
      }),
      onExit: (_) => setState(() {
        _hovered = false;
      }),
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: widget.onPressed,
          child: SizedBox.square(
            dimension: 34,
            child: Icon(widget.icon, size: 16, color: foreground),
          ),
        ),
      ),
    );
  }
}

class _MainSurface extends ConsumerWidget {
  const _MainSurface({required this.state});

  final WorkspaceState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (state.area) {
      WorkspaceArea.hosts => const _HostsSurface(),
      WorkspaceArea.sessions => _WorkspaceTabs(state: state),
      WorkspaceArea.transfers => const _TransfersSurface(),
      WorkspaceArea.snippets => const _SnippetsSurface(),
      WorkspaceArea.settings => const _SettingsSurface(),
    };
  }
}
