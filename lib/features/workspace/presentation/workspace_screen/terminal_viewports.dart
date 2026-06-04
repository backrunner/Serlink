part of '../workspace_screen.dart';

class _SingleTerminalViewport extends StatelessWidget {
  const _SingleTerminalViewport({
    required this.terminal,
    required this.controller,
    required this.settings,
    this.onKeyEvent,
    this.onInsertText,
  });

  final Terminal terminal;
  final TerminalController controller;
  final TerminalDisplaySettings settings;
  final FocusOnKeyEventCallback? onKeyEvent;
  final TerminalInsertTextInterceptor? onInsertText;

  @override
  Widget build(BuildContext context) {
    return TerminalView(
      terminal,
      controller: controller,
      autofocus: true,
      padding: const EdgeInsets.all(12),
      theme: settings.terminalTheme,
      textStyle: settings.textStyle,
      onKeyEvent: onKeyEvent,
      onInsertText: onInsertText,
    );
  }
}

class _SplitTerminalViewport extends StatelessWidget {
  const _SplitTerminalViewport({
    required this.panes,
    required this.terminals,
    required this.controllers,
    required this.globalSettings,
    required this.layout,
    required this.activePane,
    required this.local,
    required this.onActivatePane,
    this.onKeyEvent,
    this.onInsertText,
  });

  final List<TerminalPaneState> panes;
  final List<Terminal> terminals;
  final List<TerminalController> controllers;
  final TerminalDisplaySettings globalSettings;
  final TerminalPaneLayout layout;
  final int activePane;
  final bool local;
  final ValueChanged<int> onActivatePane;
  final FocusOnKeyEventCallback? onKeyEvent;
  final TerminalInsertTextInterceptor? onInsertText;

  @override
  Widget build(BuildContext context) {
    return _buildLayout(context, layout);
  }

  Widget _buildLayout(BuildContext context, TerminalPaneLayout layout) {
    return switch (layout) {
      TerminalPaneLeaf(:final paneIndex) => _buildPane(paneIndex),
      TerminalPaneSplit(:final axis, :final first, :final second) =>
        axis == Axis.horizontal
            ? Row(
                children: [
                  Expanded(child: _buildLayout(context, first)),
                  _splitDivider(axis),
                  Expanded(child: _buildLayout(context, second)),
                ],
              )
            : Column(
                children: [
                  Expanded(child: _buildLayout(context, first)),
                  _splitDivider(axis),
                  Expanded(child: _buildLayout(context, second)),
                ],
              ),
    };
  }

  Widget _buildPane(int paneIndex) {
    final index = paneIndex.clamp(0, panes.length - 1);
    final pane = panes[index];
    return _TerminalViewportPane(
      terminal: terminals[index],
      controller: controllers[index],
      settings: pane.displaySettings ?? globalSettings,
      active: activePane == index,
      label: pane.title,
      lifecycle: pane.lifecycle,
      local: local,
      onKeyEvent: onKeyEvent,
      onInsertText: onInsertText,
      onTap: () => onActivatePane(index),
    );
  }

  Widget _splitDivider(Axis axis) {
    return axis == Axis.horizontal
        ? const VerticalDivider(width: 1, thickness: 1)
        : const Divider(height: 1, thickness: 1);
  }
}

class _TerminalViewportPane extends StatelessWidget {
  const _TerminalViewportPane({
    required this.terminal,
    required this.controller,
    required this.settings,
    required this.active,
    required this.label,
    required this.lifecycle,
    required this.local,
    this.onKeyEvent,
    this.onInsertText,
    required this.onTap,
  });

  final Terminal terminal;
  final TerminalController controller;
  final TerminalDisplaySettings settings;
  final bool active;
  final String label;
  final SessionLifecycleState lifecycle;
  final bool local;
  final FocusOnKeyEventCallback? onKeyEvent;
  final TerminalInsertTextInterceptor? onInsertText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: active ? t.accentPrimary : t.borderSubtle),
      ),
      child: SerlinkPressable(
        onTap: onTap,
        borderRadius: BorderRadius.zero,
        hoverColor: t.accentPrimary.withValues(alpha: 0.05),
        child: Column(
          children: [
            Container(
              height: 28,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              alignment: Alignment.centerLeft,
              color: active
                  ? t.accentPrimary.withValues(alpha: 0.12)
                  : t.surfaceBase,
              child: Text(
                '$label · ${_terminalPaneLifecycleLabel(context.l10n, lifecycle, local: local)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: active ? t.textPrimary : t.textSecondary,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
            Expanded(
              child: TerminalView(
                terminal,
                controller: controller,
                autofocus: active,
                padding: const EdgeInsets.all(12),
                theme: settings.terminalTheme,
                textStyle: settings.textStyle,
                onKeyEvent: onKeyEvent,
                onInsertText: onInsertText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _terminalPaneLifecycleLabel(
  AppLocalizations l10n,
  SessionLifecycleState lifecycle, {
  required bool local,
}) {
  if (local) {
    return switch (lifecycle) {
      SessionLifecycleState.connected => l10n.terminalLifecycleRunning,
      SessionLifecycleState.connecting ||
      SessionLifecycleState.reconnecting ||
      SessionLifecycleState.resolvingProfile => l10n.terminalLifecycleStarting,
      SessionLifecycleState.disconnected => l10n.terminalLifecycleExited,
      SessionLifecycleState.failed => l10n.terminalLifecycleFailed,
      SessionLifecycleState.disconnecting => l10n.terminalLifecycleStopping,
      SessionLifecycleState.verifyingHostKey ||
      SessionLifecycleState.authenticating ||
      SessionLifecycleState.idle => l10n.terminalLifecycleStarting,
    };
  }
  return switch (lifecycle) {
    SessionLifecycleState.connected => l10n.terminalLifecycleConnected,
    SessionLifecycleState.connecting => l10n.terminalLifecycleConnecting,
    SessionLifecycleState.reconnecting => l10n.terminalLifecycleReconnecting,
    SessionLifecycleState.disconnected => l10n.terminalLifecycleDisconnected,
    SessionLifecycleState.failed => l10n.terminalLifecycleFailed,
    SessionLifecycleState.resolvingProfile => l10n.terminalLifecyclePreparing,
    SessionLifecycleState.verifyingHostKey => l10n.terminalLifecycleVerifying,
    SessionLifecycleState.authenticating =>
      l10n.terminalLifecycleAuthenticating,
    SessionLifecycleState.disconnecting => l10n.terminalLifecycleDisconnecting,
    SessionLifecycleState.idle => l10n.terminalLifecycleIdle,
  };
}
