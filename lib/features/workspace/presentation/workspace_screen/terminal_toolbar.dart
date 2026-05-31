part of '../workspace_screen.dart';

class _TerminalToolbar extends StatelessWidget {
  const _TerminalToolbar({required this.snapshot});

  final _TerminalToolbarSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ToolbarSerlinkIconButton(
              key: const ValueKey('terminal-search-button'),
              tooltip: 'Search terminal',
              icon: Icons.search,
              selected: snapshot.searchActive,
              onPressed: snapshot.onToggleSearch,
            ),
            if (snapshot.showForwarding)
              _ToolbarSerlinkIconButton(
                key: const ValueKey('terminal-forwarding-button'),
                tooltip: _forwardingTooltip(
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
                tooltip: 'Open SFTP tab',
                icon: Icons.folder_open_outlined,
                onPressed: snapshot.onOpenSftp,
              ),
            _ToolbarSerlinkIconButton(
              key: const ValueKey('terminal-split-right-button'),
              tooltip: 'Split right',
              icon: Icons.view_column_outlined,
              onPressed: snapshot.onSplitRight,
            ),
            _ToolbarSerlinkIconButton(
              key: const ValueKey('terminal-split-down-button'),
              tooltip: 'Split down',
              icon: Icons.view_agenda_outlined,
              onPressed: snapshot.onSplitDown,
            ),
            if (snapshot.showSplit)
              _ToolbarSerlinkIconButton(
                key: const ValueKey('terminal-close-pane-button'),
                tooltip: 'Close active pane',
                icon: Icons.close_fullscreen_outlined,
                onPressed: snapshot.onCloseActivePane,
              ),
            _ToolbarSerlinkIconButton(
              key: const ValueKey('terminal-settings-button'),
              tooltip: 'Terminal settings',
              icon: Icons.tune_outlined,
              onPressed: snapshot.onSettings,
            ),
          ],
        ),
      ),
    );
  }
}

class _TerminalToolbarSnapshot {
  const _TerminalToolbarSnapshot({
    required this.tabId,
    required this.searchActive,
    required this.activeLocalForward,
    required this.activeRemoteForward,
    required this.activeDynamicForward,
    required this.forwardBusy,
    required this.forwardEnabled,
    required this.showForwarding,
    required this.showOpenSftp,
    required this.onToggleSearch,
    required this.onManageForwarding,
    required this.onOpenSftp,
    required this.showSplit,
    required this.onSplitRight,
    required this.onSplitDown,
    required this.onCloseActivePane,
    required this.onSettings,
  });

  final WorkspaceTabId tabId;
  final bool searchActive;
  final _LocalForwardDraft? activeLocalForward;
  final _RemoteForwardDraft? activeRemoteForward;
  final _DynamicForwardDraft? activeDynamicForward;
  final bool forwardBusy;
  final bool forwardEnabled;
  final bool showForwarding;
  final bool showOpenSftp;
  final VoidCallback onToggleSearch;
  final VoidCallback onManageForwarding;
  final VoidCallback? onOpenSftp;
  final bool showSplit;
  final VoidCallback onSplitRight;
  final VoidCallback onSplitDown;
  final VoidCallback onCloseActivePane;
  final VoidCallback onSettings;

  String get signature {
    return [
      tabId.value,
      searchActive,
      _localForwardSignature(activeLocalForward),
      _remoteForwardSignature(activeRemoteForward),
      _dynamicForwardSignature(activeDynamicForward),
      forwardBusy,
      forwardEnabled,
      showForwarding,
      showOpenSftp,
      showSplit,
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
  _LocalForwardDraft? activeForward,
  _RemoteForwardDraft? activeRemoteForward,
  _DynamicForwardDraft? activeDynamicForward, {
  required bool busy,
}) {
  if (busy) {
    return 'Updating port forwarding';
  }
  final activeCount = [
    activeForward,
    activeRemoteForward,
    activeDynamicForward,
  ].whereType<Object>().length;
  if (activeCount == 0) {
    return 'Manage port forwarding';
  }
  return 'Manage port forwarding ($activeCount active)';
}
