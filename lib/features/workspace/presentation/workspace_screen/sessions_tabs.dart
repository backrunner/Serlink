part of '../workspace_screen.dart';

class _WorkspaceTabs extends ConsumerWidget {
  const _WorkspaceTabs({required this.state});

  final WorkspaceState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(workspaceTabControllerProvider.notifier);
    final active = state.activeTab ?? state.tabs.firstOrNull;

    void openNewConnection() {
      ref.read(_workspaceSearchQueryProvider.notifier).clear();
      controller.selectArea(WorkspaceArea.hosts);
    }

    if (state.tabs.isEmpty || active == null) {
      return _PlaceholderSurface(
        title: 'No active tabs',
        body: 'Open a host from Hosts to create a terminal or SFTP tab.',
        action: IconButton.filledTonal(
          tooltip: 'New connection',
          onPressed: openNewConnection,
          icon: const Icon(Icons.add),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 42,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
        const Divider(height: 1),
        Expanded(child: _ActiveTabView(tab: active)),
      ],
    );
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
    final scheme = Theme.of(context).colorScheme;
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

    return Material(
      color: selected ? scheme.primary.withValues(alpha: 0.16) : scheme.surface,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.only(left: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 180),
                child: Text(tab.title, overflow: TextOverflow.ellipsis),
              ),
              if (stateIcon != null) ...[
                const SizedBox(width: 6),
                Icon(stateIcon, size: 14, color: scheme.error),
              ],
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Close tab',
                onPressed: onClose,
                icon: const Icon(Icons.close, size: 15),
              ),
            ],
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
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: 'New connection',
      child: Material(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onPressed,
          child: SizedBox.square(
            dimension: 30,
            child: Icon(Icons.add, size: 17, color: scheme.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}

class _ActiveTabView extends ConsumerWidget {
  const _ActiveTabView({required this.tab});

  final WorkspaceTabState tab;

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
              :final splitAxis,
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
                splitAxis: splitAxis,
                activePane: activePane,
                local: false,
                onOpenSftp: tab.hostId == null
                    ? null
                    : () => controller.openSftpFromTab(tab.id),
              ),
            LocalTerminalTabContent(:final sessionId) => _TerminalPane(
              key: ValueKey(sessionId.value),
              tabId: tab.id,
              hostId: null,
              title: 'Local Shell',
              panes: [
                TerminalPaneState(
                  sessionId: sessionId,
                  title: 'Local Shell',
                  lifecycle: tab.lifecycle,
                ),
              ],
              showSplit: false,
              splitAxis: Axis.horizontal,
              activePane: 0,
              local: true,
              onOpenSftp: null,
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
    return Material(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(child: Text(message)),
            TextButton(onPressed: onReconnect, child: Text(actionLabel)),
            TextButton(onPressed: onClose, child: const Text('Close')),
          ],
        ),
      ),
    );
  }
}
