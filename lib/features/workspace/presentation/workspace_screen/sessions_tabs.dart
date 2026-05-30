part of '../workspace_screen.dart';

class _WorkspaceTabs extends ConsumerStatefulWidget {
  const _WorkspaceTabs({required this.state});

  final WorkspaceState state;

  @override
  ConsumerState<_WorkspaceTabs> createState() => _WorkspaceTabsState();
}

class _WorkspaceTabsState extends ConsumerState<_WorkspaceTabs> {
  _TerminalToolbarSnapshot? _terminalToolbar;
  String? _terminalToolbarSignature;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final controller = ref.read(workspaceTabControllerProvider.notifier);
    final active = state.activeTab ?? state.tabs.firstOrNull;
    final toolbar = _toolbarFor(active);

    void openNewConnection() {
      ref.read(_workspaceSearchQueryProvider.notifier).clear();
      controller.selectArea(WorkspaceArea.hosts);
    }

    if (state.tabs.isEmpty || active == null) {
      return const _PlaceholderSurface(
        title: 'No active tabs',
        body: 'Open a host from Hosts to create a terminal or SFTP tab.',
      );
    }

    return Column(
      children: [
        Container(
          height: 44,
          decoration: BoxDecoration(
            color: context.tokens.surfaceBase,
            border: Border(
              bottom: BorderSide(color: context.tokens.borderSubtle),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 7,
                  ),
                  itemBuilder: (context, index) {
                    if (index == state.tabs.length) {
                      return _NewTabButton(onPressed: openNewConnection);
                    }
                    final tab = state.tabs[index];
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _TabPill(
                          tab: tab,
                          selected: tab.id == active.id,
                          onTap: () => controller.setActiveTab(tab.id),
                          onClose: () => controller.closeTab(tab.id),
                        ),
                        const SizedBox(width: 6),
                      ],
                    );
                  },
                  separatorBuilder: (context, index) => const SizedBox.shrink(),
                  itemCount: state.tabs.length + 1,
                ),
              ),
              if (toolbar != null) ...[
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: context.tokens.borderSubtle,
                ),
                _TerminalToolbar(snapshot: toolbar),
              ],
            ],
          ),
        ),
        Expanded(
          child: _ActiveTabView(
            tab: active,
            onTerminalToolbarChanged: _handleTerminalToolbarChanged,
          ),
        ),
      ],
    );
  }

  _TerminalToolbarSnapshot? _toolbarFor(WorkspaceTabState? active) {
    final toolbar = _terminalToolbar;
    if (active == null ||
        toolbar == null ||
        toolbar.tabId != active.id ||
        (active.content is! TerminalTabContent &&
            active.content is! LocalTerminalTabContent)) {
      return null;
    }
    return toolbar;
  }

  void _handleTerminalToolbarChanged(_TerminalToolbarSnapshot snapshot) {
    _terminalToolbar = snapshot;
    if (_terminalToolbarSignature == snapshot.signature || !mounted) {
      return;
    }
    setState(() {
      _terminalToolbarSignature = snapshot.signature;
    });
  }
}

class _TabPill extends StatelessWidget {
  const _TabPill({
    required this.tab,
    required this.selected,
    required this.onTap,
    required this.onClose,
  });

  final WorkspaceTabState tab;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final icon = switch (tab.content.kind) {
      WorkspaceTabKind.terminal => Icons.terminal,
      WorkspaceTabKind.sftp => Icons.folder_open,
      WorkspaceTabKind.localTerminal => Icons.computer,
    };
    final stateIcon = switch (tab.lifecycle) {
      SessionLifecycleState.connected => null,
      SessionLifecycleState.connecting ||
      SessionLifecycleState.authenticating ||
      SessionLifecycleState.verifyingHostKey ||
      SessionLifecycleState.resolvingProfile ||
      SessionLifecycleState.reconnecting => Icons.sync,
      SessionLifecycleState.disconnected => Icons.link_off,
      SessionLifecycleState.failed => Icons.error_outline,
      _ => null,
    };
    final stateColor = switch (tab.lifecycle) {
      SessionLifecycleState.failed ||
      SessionLifecycleState.disconnected => t.statusDanger,
      _ => t.statusWarning,
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: selected ? t.accentPrimary.withValues(alpha: 0.16) : null,
        borderRadius: SerlinkRadii.control,
        border: Border.all(
          color: selected
              ? t.accentPrimary.withValues(alpha: 0.5)
              : t.borderSubtle,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: SerlinkRadii.control,
        child: InkWell(
          borderRadius: SerlinkRadii.control,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.only(left: 10, right: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 15,
                  color: selected ? t.accentPrimary : t.textSecondary,
                ),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 180),
                  child: Text(
                    tab.title,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? t.textPrimary : t.textSecondary,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
                if (stateIcon != null) ...[
                  const SizedBox(width: 6),
                  Icon(stateIcon, size: 14, color: stateColor),
                ],
                IconButton(
                  visualDensity: VisualDensity.compact,
                  style: const ButtonStyle(
                    padding: WidgetStatePropertyAll(EdgeInsets.zero),
                    minimumSize: WidgetStatePropertyAll(Size.square(24)),
                    fixedSize: WidgetStatePropertyAll(Size.square(24)),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: WidgetStatePropertyAll(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(7)),
                      ),
                    ),
                  ),
                  tooltip: 'Close tab',
                  onPressed: onClose,
                  icon: const Icon(Icons.close, size: 15),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NewTabButton extends StatelessWidget {
  const _NewTabButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Tooltip(
      message: 'New connection',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: t.surfaceSunken,
          borderRadius: SerlinkRadii.control,
          border: Border.all(color: t.borderSubtle),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: SerlinkRadii.control,
          child: InkWell(
            borderRadius: SerlinkRadii.control,
            onTap: onPressed,
            child: SizedBox.square(
              dimension: 30,
              child: Icon(Icons.add, size: 17, color: t.textSecondary),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActiveTabView extends ConsumerWidget {
  const _ActiveTabView({
    required this.tab,
    required this.onTerminalToolbarChanged,
  });

  final WorkspaceTabState tab;
  final ValueChanged<_TerminalToolbarSnapshot> onTerminalToolbarChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(workspaceTabControllerProvider.notifier);
    final isLocalTerminal = tab.content is LocalTerminalTabContent;
    final showBanner =
        tab.lifecycle == SessionLifecycleState.disconnected ||
        tab.lifecycle == SessionLifecycleState.failed;
    final banner = showBanner
        ? _RecoverableFailureBanner(
            message:
                tab.failure?.message ??
                (isLocalTerminal
                    ? 'Local shell is not running.'
                    : 'Connection is not active.'),
            actionLabel: isLocalTerminal ? 'Restart' : 'Reconnect',
            onReconnect: () => controller.reconnect(tab.id),
            onClose: () => controller.closeTab(tab.id),
          )
        : const SizedBox.shrink();

    return Column(
      children: [
        banner,
        Expanded(
          child: switch (tab.content) {
            TerminalTabContent(
              :final panes,
              :final showSplit,
              :final layout,
              :final activePane,
            ) =>
              _TerminalPane(
                key: ValueKey(
                  panes.map((pane) => pane.sessionId.value).join(':'),
                ),
                tabId: tab.id,
                hostId: tab.hostId,
                title: tab.title,
                panes: panes,
                showSplit: showSplit,
                layout: layout,
                activePane: activePane,
                local: false,
                onOpenSftp: tab.hostId == null
                    ? null
                    : () => controller.openSftpFromTab(tab.id),
                onToolbarSnapshotChanged: onTerminalToolbarChanged,
              ),
            LocalTerminalTabContent(
              :final panes,
              :final showSplit,
              :final layout,
              :final activePane,
            ) =>
              _TerminalPane(
                key: ValueKey(
                  panes.map((pane) => pane.sessionId.value).join(':'),
                ),
                tabId: tab.id,
                hostId: null,
                title: 'Local Shell',
                panes: panes,
                showSplit: showSplit,
                layout: layout,
                activePane: activePane,
                local: true,
                onOpenSftp: null,
                onToolbarSnapshotChanged: onTerminalToolbarChanged,
              ),
            SftpTabContent(:final sessionId, :final currentPath) => _SftpPane(
              key: ValueKey('${sessionId.value}:$currentPath'),
              tabId: tab.id,
              sessionId: sessionId,
              path: currentPath,
              lifecycle: tab.lifecycle,
              onOpenTerminal: tab.hostId == null
                  ? null
                  : () => controller.openTerminalFromTab(tab.id),
            ),
          },
        ),
      ],
    );
  }
}

class _RecoverableFailureBanner extends StatelessWidget {
  const _RecoverableFailureBanner({
    required this.message,
    required this.actionLabel,
    required this.onReconnect,
    required this.onClose,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onReconnect;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.statusDanger.withValues(alpha: 0.12),
        border: Border(bottom: BorderSide(color: t.borderSubtle)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.error_outline, size: 17, color: t.statusDanger),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message, style: TextStyle(color: t.textPrimary)),
            ),
            TextButton(onPressed: onReconnect, child: Text(actionLabel)),
            TextButton(onPressed: onClose, child: const Text('Close')),
          ],
        ),
      ),
    );
  }
}
