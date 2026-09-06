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
    final capabilities = ref.watch(platformCapabilitiesProvider);
    if (capabilities.prefersMobileWorkspaceShell) {
      return const MobileWorkspaceScreen();
    }
    final showTopBar = AppWindow.usesTrailingWindowControls;

    return _NativeTerminationGuard(
      child: _SshConfigImportPromptGate(
        child: Scaffold(
          body: SerlinkWindowBackdrop(
            backgroundColor: context.tokens.surfaceSunken,
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
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 8, 8, 8),
                    child: Material(
                      color: context.tokens.surfaceBase,
                      borderRadius: SerlinkRadii.workspace,
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          if (showTopBar) const _TopBar(),
                          Expanded(child: _MainSurface(state: state)),
                        ],
                      ),
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

bool _showsMobileWorkspaceSearch(WorkspaceArea area) {
  return switch (area) {
    WorkspaceArea.hosts ||
    WorkspaceArea.transfers ||
    WorkspaceArea.snippets => true,
    WorkspaceArea.sessions || WorkspaceArea.settings => false,
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
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
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
              letterSpacing: 0,
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
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: selected ? t.surfaceRaised : Colors.transparent,
          borderRadius: SerlinkRadii.control,
        ),
        child: SerlinkPressable(
          onTap: onTap,
          borderRadius: SerlinkRadii.control,
          hoverColor: selected ? Colors.transparent : t.surfaceOverlay,
          pressedColor: t.surfaceOverlay,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: selected ? t.accentPrimary : t.textSecondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: TextStyle(
                      color: selected ? t.textPrimary : t.textSecondary,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
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
    final vaultSession = ref.watch(vaultSessionControllerProvider);
    final session = vaultSession.value;
    if (session != null && !session.localDataHealthy) {
      return _VaultAccessSurface(session: session);
    }
    if (ref.watch(platformCapabilitiesProvider).prefersMobileWorkspaceShell) {
      return _buildWorkspaceArea(state.area, state);
    }
    return _WorkspaceAreaStack(
      state: state,
      vaultUnlocked: session?.vaultState == VaultState.unlocked,
    );
  }
}

Widget _buildWorkspaceArea(WorkspaceArea area, WorkspaceState state) {
  return switch (area) {
    WorkspaceArea.hosts => const _HostsSurface(),
    WorkspaceArea.sessions => _WorkspaceTabs(state: state),
    WorkspaceArea.transfers => const _TransfersSurface(),
    WorkspaceArea.snippets => const _SnippetsSurface(),
    WorkspaceArea.settings => const _SettingsSurface(),
  };
}

/// Mount each area on its first visit and retain its scroll, selection, and
/// terminal viewport state. Hidden areas neither animate nor receive input.
class _WorkspaceAreaStack extends StatefulWidget {
  const _WorkspaceAreaStack({required this.state, required this.vaultUnlocked});

  final WorkspaceState state;
  final bool vaultUnlocked;

  @override
  State<_WorkspaceAreaStack> createState() => _WorkspaceAreaStackState();
}

class _WorkspaceAreaStackState extends State<_WorkspaceAreaStack> {
  final _visited = <WorkspaceArea>{};
  final _focusScopes = <WorkspaceArea, FocusScopeNode>{};
  final _lastFocused = <WorkspaceArea, FocusNode>{};

  @override
  void didUpdateWidget(_WorkspaceAreaStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    final area = widget.state.area;
    if (oldWidget.state.area != area) {
      final previousFocus = _focusScopes[oldWidget.state.area]?.focusedChild;
      if (previousFocus != null) {
        _lastFocused[oldWidget.state.area] = previousFocus;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.state.area == area) {
          final focus = _lastFocused[area];
          if (focus?.context != null && focus!.canRequestFocus) {
            focus.requestFocus();
          } else {
            _focusScopes[area]?.requestFocus();
          }
        }
      });
    }
  }

  @override
  void dispose() {
    for (final scope in _focusScopes.values) {
      scope.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Never retain an inactive unlock form (including its passphrase), or
    // decrypted host/snippet views after the vault has been locked.
    if (!widget.vaultUnlocked) {
      _visited.removeAll([WorkspaceArea.hosts, WorkspaceArea.snippets]);
      _lastFocused.remove(WorkspaceArea.hosts);
      _lastFocused.remove(WorkspaceArea.snippets);
    }
    _visited.add(widget.state.area);
    return Stack(
      fit: StackFit.expand,
      children: [
        for (final area in WorkspaceArea.values)
          if (_visited.contains(area))
            Offstage(
              key: ValueKey('workspace-area-${area.name}'),
              offstage: area != widget.state.area,
              child: TickerMode(
                enabled: area == widget.state.area,
                child: FocusScope(
                  node: _focusScopes.putIfAbsent(
                    area,
                    () => FocusScopeNode(debugLabel: 'workspace-${area.name}'),
                  ),
                  canRequestFocus: area == widget.state.area,
                  descendantsAreFocusable: area == widget.state.area,
                  skipTraversal: area != widget.state.area,
                  child: _buildWorkspaceArea(area, widget.state),
                ),
              ),
            ),
      ],
    );
  }
}
