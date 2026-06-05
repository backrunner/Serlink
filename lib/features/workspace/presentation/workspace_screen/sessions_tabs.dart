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
    final mobile = ref.watch(
      platformCapabilitiesProvider.select(
        (capabilities) => capabilities.prefersMobileWorkspaceShell,
      ),
    );

    void openNewConnection() {
      ref.read(_workspaceSearchQueryProvider.notifier).clear();
      controller.selectArea(WorkspaceArea.hosts);
    }

    if (state.tabs.isEmpty || active == null) {
      return _PlaceholderSurface(
        title: context.l10n.sessionsEmptyTitle,
        body: context.l10n.sessionsEmptyBody,
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
                    if (!mobile && index == state.tabs.length) {
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
                  itemCount: state.tabs.length + (mobile ? 0 : 1),
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
      child: SerlinkPressable(
        onTap: onTap,
        borderRadius: SerlinkRadii.control,
        hoverColor: selected
            ? t.accentPrimary.withValues(alpha: 0.08)
            : t.accentPrimary.withValues(alpha: 0.06),
        pressedColor: selected
            ? t.accentPrimary.withValues(alpha: 0.14)
            : t.accentPrimary.withValues(alpha: 0.1),
        child: SizedBox(
          height: 30,
          child: Padding(
            padding: const EdgeInsets.only(left: 10, right: 6),
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
                _TabCloseButton(onPressed: onClose),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TabCloseButton extends StatelessWidget {
  const _TabCloseButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: SerlinkTooltip(
        message: context.l10n.tabsCloseTooltip,
        child: SerlinkPressable(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(4),
          hoverColor: t.accentPrimary.withValues(alpha: 0.08),
          pressedColor: t.accentPrimary.withValues(alpha: 0.14),
          child: SizedBox.square(
            dimension: 18,
            child: Icon(Icons.close, size: 14, color: t.textSecondary),
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
    return SerlinkTooltip(
      message: context.l10n.tabsNewConnectionTooltip,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: t.surfaceSunken,
          borderRadius: SerlinkRadii.control,
          border: Border.all(color: t.borderSubtle),
        ),
        child: SerlinkPressable(
          onTap: onPressed,
          borderRadius: SerlinkRadii.control,
          child: SizedBox.square(
            dimension: 30,
            child: Icon(Icons.add, size: 17, color: t.textSecondary),
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
    final l10n = context.l10n;
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
                    ? l10n.localShellInactive
                    : l10n.connectionInactive),
            actionLabel: isLocalTerminal
                ? l10n.restartAction
                : l10n.reconnectAction,
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
                title: l10n.localShellTitle,
                panes: panes,
                showSplit: showSplit,
                layout: layout,
                activePane: activePane,
                local: true,
                onOpenSftp: null,
                onToolbarSnapshotChanged: onTerminalToolbarChanged,
              ),
            SftpTabContent(
              :final sessionId,
              :final currentPath,
              :final rootPath,
            ) =>
              _SftpPane(
                key: ValueKey('${sessionId.value}:$rootPath'),
                tabId: tab.id,
                hostId: tab.hostId,
                sourceMachineName: _sourceMachineNameFromTabTitle(
                  l10n,
                  tab.title,
                ),
                sessionId: sessionId,
                path: currentPath,
                rootPath: rootPath,
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
            SerlinkTextButton(onPressed: onReconnect, child: Text(actionLabel)),
            SerlinkTextButton(
              onPressed: onClose,
              child: Text(context.l10n.closeAction),
            ),
          ],
        ),
      ),
    );
  }
}
