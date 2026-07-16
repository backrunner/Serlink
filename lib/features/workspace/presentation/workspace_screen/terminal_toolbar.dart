part of '../workspace_screen.dart';

class _TerminalToolbar extends ConsumerWidget {
  const _TerminalToolbar({required this.snapshot});

  final _TerminalToolbarSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final compact = ref.watch(
      platformCapabilitiesProvider.select((capabilities) => capabilities.isIOS),
    );
    if (compact) {
      return _TerminalToolbarOverflowMenu(snapshot: snapshot);
    }
    return SizedBox(
      height: 44,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ToolbarSerlinkIconButton(
              key: const ValueKey('terminal-search-button'),
              tooltip: l10n.terminalSearchTooltip,
              icon: Icons.search,
              selected: snapshot.searchActive,
              onPressed: snapshot.onToggleSearch,
            ),
            if (snapshot.showForwarding)
              _ToolbarSerlinkIconButton(
                key: const ValueKey('terminal-forwarding-button'),
                tooltip: _forwardingTooltip(
                  l10n,
                  snapshot.activeLocalForward,
                  snapshot.activeRemoteForward,
                  snapshot.activeDynamicForward,
                  busy: snapshot.forwardBusy,
                ),
                icon: Icons.settings_ethernet_outlined,
                selected:
                    snapshot.activeLocalForward != null ||
                    snapshot.activeRemoteForward != null ||
                    snapshot.activeDynamicForward != null,
                onPressed: snapshot.forwardEnabled && !snapshot.forwardBusy
                    ? snapshot.onManageForwarding
                    : null,
              ),
            if (snapshot.showOpenSftp)
              _ToolbarSerlinkIconButton(
                key: const ValueKey('terminal-open-sftp-button'),
                tooltip: l10n.terminalOpenSftpTooltip,
                icon: Icons.folder_open_outlined,
                onPressed: snapshot.onOpenSftp,
              ),
            if (snapshot.showSplitControls) ...[
              _ToolbarSerlinkIconButton(
                key: const ValueKey('terminal-split-right-button'),
                tooltip: l10n.terminalSplitRightTooltip,
                icon: Icons.view_column_outlined,
                onPressed: snapshot.canSplitRight
                    ? snapshot.onSplitRight
                    : null,
              ),
              _ToolbarSerlinkIconButton(
                key: const ValueKey('terminal-split-down-button'),
                tooltip: l10n.terminalSplitDownTooltip,
                icon: Icons.view_agenda_outlined,
                onPressed: snapshot.canSplitDown ? snapshot.onSplitDown : null,
              ),
            ],
            _ToolbarSerlinkIconButton(
              key: const ValueKey('terminal-settings-button'),
              tooltip: l10n.terminalSettingsTitle,
              icon: Icons.tune_outlined,
              onPressed: snapshot.onSettings,
            ),
          ],
        ),
      ),
    );
  }
}

class _TerminalToolbarOverflowMenu extends StatelessWidget {
  const _TerminalToolbarOverflowMenu({required this.snapshot});

  final _TerminalToolbarSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final actions = <_TerminalToolbarMenuAction>[
      _TerminalToolbarMenuAction(
        key: const ValueKey('terminal-search-button'),
        label: l10n.terminalSearchTooltip,
        icon: Icons.search,
        selected: snapshot.searchActive,
        onPressed: snapshot.onToggleSearch,
      ),
      if (snapshot.showForwarding)
        _TerminalToolbarMenuAction(
          key: const ValueKey('terminal-forwarding-button'),
          label: _forwardingTooltip(
            l10n,
            snapshot.activeLocalForward,
            snapshot.activeRemoteForward,
            snapshot.activeDynamicForward,
            busy: snapshot.forwardBusy,
          ),
          icon: Icons.settings_ethernet_outlined,
          selected:
              snapshot.activeLocalForward != null ||
              snapshot.activeRemoteForward != null ||
              snapshot.activeDynamicForward != null,
          onPressed: snapshot.forwardEnabled && !snapshot.forwardBusy
              ? snapshot.onManageForwarding
              : null,
        ),
      if (snapshot.showOpenSftp)
        _TerminalToolbarMenuAction(
          key: const ValueKey('terminal-open-sftp-button'),
          label: l10n.terminalOpenSftpTooltip,
          icon: Icons.folder_open_outlined,
          onPressed: snapshot.onOpenSftp,
        ),
      if (snapshot.showSplitControls) ...[
        _TerminalToolbarMenuAction(
          key: const ValueKey('terminal-split-right-button'),
          label: l10n.terminalSplitRightTooltip,
          icon: Icons.view_column_outlined,
          onPressed: snapshot.canSplitRight ? snapshot.onSplitRight : null,
        ),
        _TerminalToolbarMenuAction(
          key: const ValueKey('terminal-split-down-button'),
          label: l10n.terminalSplitDownTooltip,
          icon: Icons.view_agenda_outlined,
          onPressed: snapshot.canSplitDown ? snapshot.onSplitDown : null,
        ),
      ],
      _TerminalToolbarMenuAction(
        key: const ValueKey('terminal-settings-button'),
        label: l10n.terminalSettingsTitle,
        icon: Icons.tune_outlined,
        onPressed: snapshot.onSettings,
      ),
    ];

    return SizedBox(
      height: 44,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: FPopoverMenu(
          menuBuilder: (context, controller, _) => [
            FItemGroup(
              children: [
                for (final action in actions)
                  FItem(
                    key: action.key,
                    title: Text(action.label),
                    prefix: Icon(action.icon, size: 16),
                    enabled: action.onPressed != null,
                    selected: action.selected,
                    onPress: action.onPressed == null
                        ? null
                        : () {
                            controller.hide();
                            action.onPressed!();
                          },
                  ),
              ],
            ),
          ],
          builder: (context, controller, _) => Center(
            child: SerlinkIconButton(
              key: const ValueKey('terminal-toolbar-overflow-button'),
              tooltip: l10n.terminalToolbarMoreActionsTooltip,
              constraints: const BoxConstraints.tightFor(width: 30, height: 30),
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.more_horiz, size: 20),
              onPressed: controller.toggle,
            ),
          ),
        ),
      ),
    );
  }
}

class _TerminalToolbarMenuAction {
  const _TerminalToolbarMenuAction({
    required this.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.selected = false,
  });

  final Key key;
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool selected;
}

class _TerminalToolbarSnapshot {
  const _TerminalToolbarSnapshot({
    required this.tabId,
    required this.activePane,
    required this.activeHostId,
    required this.searchActive,
    required this.activeLocalForward,
    required this.activeRemoteForward,
    required this.activeDynamicForward,
    required this.forwardBusy,
    required this.forwardEnabled,
    required this.showForwarding,
    required this.showOpenSftp,
    required this.showSplitControls,
    required this.onToggleSearch,
    required this.onManageForwarding,
    required this.onOpenSftp,
    required this.canSplitRight,
    required this.canSplitDown,
    required this.onSplitRight,
    required this.onSplitDown,
    required this.onSettings,
  });

  final WorkspaceTabId tabId;
  final int activePane;
  final HostId? activeHostId;
  final bool searchActive;
  final _LocalForwardDraft? activeLocalForward;
  final _RemoteForwardDraft? activeRemoteForward;
  final _DynamicForwardDraft? activeDynamicForward;
  final bool forwardBusy;
  final bool forwardEnabled;
  final bool showForwarding;
  final bool showOpenSftp;
  final bool showSplitControls;
  final VoidCallback onToggleSearch;
  final VoidCallback onManageForwarding;
  final VoidCallback? onOpenSftp;
  final bool canSplitRight;
  final bool canSplitDown;
  final VoidCallback onSplitRight;
  final VoidCallback onSplitDown;
  final VoidCallback onSettings;

  String get signature {
    return [
      tabId.value,
      activePane,
      activeHostId?.value ?? '-',
      searchActive,
      _localForwardSignature(activeLocalForward),
      _remoteForwardSignature(activeRemoteForward),
      _dynamicForwardSignature(activeDynamicForward),
      forwardBusy,
      forwardEnabled,
      showForwarding,
      showOpenSftp,
      showSplitControls,
      canSplitRight,
      canSplitDown,
    ].join('|');
  }
}

class _ToolbarSerlinkIconButton extends StatelessWidget {
  const _ToolbarSerlinkIconButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.selected = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SerlinkTooltip(
      message: tooltip,
      child: SerlinkIconButton(
        isSelected: selected,
        selectedIcon: Icon(icon, size: 18),
        constraints: const BoxConstraints.tightFor(width: 30, height: 30),
        padding: EdgeInsets.zero,
        color: selected ? t.accentPrimary : t.textSecondary,
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
      ),
    );
  }
}

String _localForwardSignature(_LocalForwardDraft? draft) {
  if (draft == null) {
    return '-';
  }
  return '${draft.localPort},${draft.remoteHost},${draft.remotePort}';
}

String _remoteForwardSignature(_RemoteForwardDraft? draft) {
  if (draft == null) {
    return '-';
  }
  return '${draft.bindHost},${draft.bindPort},${draft.localHost},${draft.localPort}';
}

String _dynamicForwardSignature(_DynamicForwardDraft? draft) {
  if (draft == null) {
    return '-';
  }
  return '${draft.bindHost},${draft.bindPort}';
}

String _forwardingTooltip(
  AppLocalizations l10n,
  _LocalForwardDraft? activeForward,
  _RemoteForwardDraft? activeRemoteForward,
  _DynamicForwardDraft? activeDynamicForward, {
  required bool busy,
}) {
  if (busy) {
    return l10n.terminalForwardingUpdating;
  }
  final activeCount = [
    activeForward,
    activeRemoteForward,
    activeDynamicForward,
  ].whereType<Object>().length;
  if (activeCount == 0) {
    return l10n.terminalForwardingManage;
  }
  return l10n.terminalForwardingManageActive(activeCount);
}
