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
    final l10n = context.l10n;
    final state = ref.watch(workspaceTabControllerProvider);
    final controller = ref.read(workspaceTabControllerProvider.notifier);
    final capabilities = ref.watch(platformCapabilitiesProvider);
    if (capabilities.prefersMobileWorkspaceShell) {
      return const MobileWorkspaceScreen();
    }
    final showSearch = _showsWorkspaceSearch(state.area);
    final showLocalTerminal =
        capabilities.localTerminal && _showsLocalTerminalAction(state.area);
    final showTopBar =
        showSearch || showLocalTerminal || AppWindow.usesTrailingWindowControls;

    return Scaffold(
      body: DecoratedBox(
        decoration: serlinkBackdrop(context.tokens),
        child: Stack(
          children: [
            const Positioned.fill(child: _BackdropGlow()),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              child: Row(
                children: [
                  _Sidebar(
                    selected: state.area,
                    onSelected: (area) {
                      if (area != state.area) {
                        ref
                            .read(vaultSessionControllerProvider.notifier)
                            .resetUnlockFailureState();
                      }
                      controller.selectArea(area);
                    },
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: SerlinkRadii.card,
                        boxShadow: serlinkShadow(context.tokens, elevation: 20),
                      ),
                      child: Material(
                        color: context.tokens.surfaceRaised,
                        elevation: 0,
                        clipBehavior: Clip.antiAlias,
                        shape: RoundedRectangleBorder(
                          borderRadius: SerlinkRadii.card,
                          side: BorderSide(color: context.tokens.borderSubtle),
                        ),
                        child: Column(
                          children: [
                            if (showTopBar)
                              _TopBar(
                                showSearch: showSearch,
                                searchPlaceholder: _workspaceSearchPlaceholder(
                                  l10n,
                                  state.area,
                                ),
                                showLocalTerminal: showLocalTerminal,
                                onOpenLocalTerminal:
                                    controller.openLocalTerminal,
                              ),
                            Expanded(child: _MainSurface(state: state)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A soft, blurred accent glow anchored to the top-left of the window, giving
/// the backdrop a subtle sense of light and depth behind the panels.
class _BackdropGlow extends StatelessWidget {
  const _BackdropGlow();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -160,
            left: -120,
            child: _GlowBlob(color: t.accentPrimary, size: 460),
          ),
          Positioned(
            bottom: -200,
            right: -140,
            child: _GlowBlob(color: t.accentSecondary, size: 520),
          ),
        ],
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  const _GlowBlob({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withValues(alpha: 0.16), color.withValues(alpha: 0)],
        ),
      ),
    );
  }
}

bool _showsWorkspaceSearch(WorkspaceArea area) {
  return switch (area) {
    WorkspaceArea.hosts || WorkspaceArea.snippets => true,
    WorkspaceArea.sessions ||
    WorkspaceArea.transfers ||
    WorkspaceArea.settings => false,
  };
}

bool _showsMobileWorkspaceSearch(WorkspaceArea area) {
  return switch (area) {
    WorkspaceArea.hosts ||
    WorkspaceArea.transfers ||
    WorkspaceArea.snippets => true,
    WorkspaceArea.sessions || WorkspaceArea.settings => false,
  };
}

bool _showsLocalTerminalAction(WorkspaceArea area) {
  return switch (area) {
    WorkspaceArea.hosts || WorkspaceArea.snippets => true,
    WorkspaceArea.sessions ||
    WorkspaceArea.transfers ||
    WorkspaceArea.settings => false,
  };
}

String _workspaceSearchPlaceholder(AppLocalizations l10n, WorkspaceArea area) {
  return switch (area) {
    WorkspaceArea.hosts => l10n.searchHostsPlaceholder,
    WorkspaceArea.snippets => l10n.searchSnippetsPlaceholder,
    WorkspaceArea.sessions => l10n.searchSessionsPlaceholder,
    WorkspaceArea.transfers => l10n.searchTransfersPlaceholder,
    WorkspaceArea.settings => l10n.searchSettingsPlaceholder,
  };
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.selected, required this.onSelected});

  final WorkspaceArea selected;
  final ValueChanged<WorkspaceArea> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SizedBox(
      width: SerlinkSizes.sidebarWidth,
      child: GlassPanel(
        elevation: 20,
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _BrandHeader(),
            _NavItem(
              icon: Icons.dns_outlined,
              label: l10n.navHosts,
              selected: selected == WorkspaceArea.hosts,
              onTap: () => onSelected(WorkspaceArea.hosts),
            ),
            _NavItem(
              icon: Icons.terminal_outlined,
              label: l10n.navSessions,
              selected: selected == WorkspaceArea.sessions,
              onTap: () => onSelected(WorkspaceArea.sessions),
            ),
            _NavItem(
              icon: Icons.sync_alt_outlined,
              label: l10n.navTransfers,
              selected: selected == WorkspaceArea.transfers,
              onTap: () => onSelected(WorkspaceArea.transfers),
            ),
            _NavItem(
              icon: Icons.code_outlined,
              label: l10n.navSnippets,
              selected: selected == WorkspaceArea.snippets,
              onTap: () => onSelected(WorkspaceArea.snippets),
            ),
            const Spacer(),
            _NavItem(
              icon: Icons.settings_outlined,
              label: l10n.navSettings,
              selected: selected == WorkspaceArea.settings,
              onTap: () => onSelected(WorkspaceArea.settings),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    final content = AppWindow.usesMacStyleChrome
        ? SizedBox(
            height: SerlinkSizes.toolbarHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
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
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
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
    final t = context.tokens;
    const iconSize = 30.0;
    return Row(
      children: [
        Container(
          width: iconSize,
          height: iconSize,
          decoration: BoxDecoration(
            gradient: serlinkAccentGradient(t),
            borderRadius: SerlinkRadii.control,
            boxShadow: [
              BoxShadow(
                color: t.accentPrimary.withValues(alpha: 0.4),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Icon(Icons.hub_outlined, size: 18, color: t.onAccent),
        ),
        const SizedBox(width: 11),
        Flexible(
          child: Text(
            'Serlink',
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: t.textPrimary,
              letterSpacing: 0.2,
            ),
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
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          gradient: selected ? serlinkAccentGradient(t) : null,
          borderRadius: SerlinkRadii.control,
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: t.accentPrimary.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: SerlinkPressable(
          onTap: onTap,
          borderRadius: SerlinkRadii.control,
          hoverColor: selected
              ? t.accentSecondary.withValues(alpha: 0.1)
              : t.accentPrimary.withValues(alpha: 0.06),
          pressedColor: selected
              ? t.accentStrong.withValues(alpha: 0.14)
              : t.accentPrimary.withValues(alpha: 0.1),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: selected ? t.onAccent : t.textSecondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: TextStyle(
                      color: selected ? t.onAccent : t.textSecondary,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
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
