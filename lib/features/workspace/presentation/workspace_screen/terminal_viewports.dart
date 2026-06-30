part of '../workspace_screen.dart';

const EdgeInsets _terminalViewportPadding = EdgeInsets.fromLTRB(10, 12, 10, 8);
const double _terminalMinPaneWidth = 320;
const double _terminalMinPaneHeight = 220;
const double _terminalPaneGap = 8;
const double _terminalDividerHitSize = 8;

class _SingleTerminalViewport extends StatelessWidget {
  const _SingleTerminalViewport({
    required this.terminal,
    required this.controller,
    required this.focusNode,
    required this.settings,
    required this.pane,
    required this.local,
    required this.onReconnect,
    this.onKeyEvent,
    this.onInsertText,
  });

  final Terminal terminal;
  final TerminalController controller;
  final FocusNode focusNode;
  final TerminalDisplaySettings settings;
  final TerminalPaneState pane;
  final bool local;
  final VoidCallback onReconnect;
  final FocusOnKeyEventCallback? onKeyEvent;
  final TerminalInsertTextInterceptor? onInsertText;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        TerminalView(
          terminal,
          controller: controller,
          focusNode: focusNode,
          autofocus: true,
          padding: _terminalViewportPadding,
          theme: settings.terminalTheme,
          textStyle: settings.textStyle,
          onKeyEvent: onKeyEvent,
          onInsertText: onInsertText,
        ),
        if (_terminalPaneNeedsOverlay(pane.lifecycle))
          _TerminalPaneRecoveryOverlay(
            pane: pane,
            local: local,
            onReconnect: onReconnect,
            onClose: null,
          ),
      ],
    );
  }
}

class _SplitTerminalViewport extends StatelessWidget {
  const _SplitTerminalViewport({
    required this.tabId,
    required this.panes,
    required this.terminals,
    required this.controllers,
    required this.focusNodes,
    required this.globalSettings,
    required this.layout,
    required this.activePane,
    required this.local,
    required this.onActivatePane,
    required this.onClosePane,
    required this.onReconnectPane,
    required this.onSwapPanes,
    required this.onDropTabPane,
    required this.onResizeSplit,
    this.onKeyEvent,
    this.onInsertText,
  });

  final WorkspaceTabId tabId;
  final List<TerminalPaneState> panes;
  final List<Terminal> terminals;
  final List<TerminalController> controllers;
  final List<FocusNode> focusNodes;
  final TerminalDisplaySettings globalSettings;
  final TerminalPaneLayout layout;
  final int activePane;
  final bool local;
  final ValueChanged<int> onActivatePane;
  final ValueChanged<int> onClosePane;
  final ValueChanged<int> onReconnectPane;
  final void Function(int fromPaneIndex, int toPaneIndex) onSwapPanes;
  final void Function(
    WorkspaceTabId sourceTabId,
    int targetPaneIndex,
    _TerminalPaneDropPlacement placement,
  )
  onDropTabPane;
  final void Function(List<int> splitPath, double ratio) onResizeSplit;
  final FocusOnKeyEventCallback? onKeyEvent;
  final TerminalInsertTextInterceptor? onInsertText;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(_terminalPaneGap),
      child: _buildLayout(context, layout, const []),
    );
  }

  Widget _buildLayout(
    BuildContext context,
    TerminalPaneLayout layout,
    List<int> path,
  ) {
    return switch (layout) {
      TerminalPaneLeaf(:final paneIndex) => _buildPane(context, paneIndex),
      TerminalPaneSplit(
        :final axis,
        :final first,
        :final second,
        :final ratio,
      ) =>
        _ResizableTerminalSplit(
          axis: axis,
          ratio: ratio,
          minFirstExtent: _minExtentForLayout(first, axis),
          minSecondExtent: _minExtentForLayout(second, axis),
          onRatioChanged: (nextRatio) => onResizeSplit(path, nextRatio),
          first: _buildLayout(context, first, [...path, 0]),
          second: _buildLayout(context, second, [...path, 1]),
        ),
    };
  }

  double _minExtentForLayout(TerminalPaneLayout layout, Axis axis) {
    return switch (layout) {
      TerminalPaneLeaf() =>
        axis == Axis.horizontal
            ? _terminalMinPaneWidth
            : _terminalMinPaneHeight,
      TerminalPaneSplit(axis: final splitAxis, :final first, :final second) =>
        splitAxis == axis
            ? _minExtentForLayout(first, axis) +
                  _terminalDividerHitSize +
                  _minExtentForLayout(second, axis)
            : math.max(
                _minExtentForLayout(first, axis),
                _minExtentForLayout(second, axis),
              ),
    };
  }

  Widget _buildPane(BuildContext context, int paneIndex) {
    final index = paneIndex.clamp(0, panes.length - 1);
    final pane = panes[index];
    final paneLocal = pane.endpoint?.isLocal ?? local;
    return _TerminalViewportPane(
      terminal: terminals[index],
      controller: controllers[index],
      focusNode: focusNodes[index],
      settings: pane.displaySettings ?? globalSettings,
      active: activePane == index || focusNodes[index].hasFocus,
      paneIndex: index,
      label: context.l10n.terminalPaneSessionLabel(index + 1),
      lifecycle: pane.lifecycle,
      local: paneLocal,
      pane: pane,
      canClose: panes.length > 1,
      onKeyEvent: onKeyEvent,
      onInsertText: onInsertText,
      onTap: () => onActivatePane(index),
      onClose: () => onClosePane(index),
      onReconnect: () => onReconnectPane(index),
      onSwapPanes: (fromPaneIndex) => onSwapPanes(fromPaneIndex, index),
      onDropTabPane: (sourceTabId, placement) =>
          onDropTabPane(sourceTabId, index, placement),
    );
  }
}

class _ResizableTerminalSplit extends StatelessWidget {
  const _ResizableTerminalSplit({
    required this.axis,
    required this.ratio,
    required this.minFirstExtent,
    required this.minSecondExtent,
    required this.first,
    required this.second,
    required this.onRatioChanged,
  });

  final Axis axis;
  final double ratio;
  final double minFirstExtent;
  final double minSecondExtent;
  final Widget first;
  final Widget second;
  final ValueChanged<double> onRatioChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalExtent = axis == Axis.horizontal
            ? constraints.maxWidth
            : constraints.maxHeight;
        final dividerExtent = _terminalDividerHitSize;
        final availableExtent = math.max(0, totalExtent - dividerExtent);
        final minRatio = availableExtent <= 0
            ? 0.1
            : (minFirstExtent / availableExtent).clamp(0.1, 0.9).toDouble();
        final maxRatio = availableExtent <= 0
            ? 0.9
            : (1 - minSecondExtent / availableExtent)
                  .clamp(minRatio, 0.9)
                  .toDouble();
        final effectiveRatio = ratio.clamp(minRatio, maxRatio).toDouble();
        final firstExtent = (availableExtent * effectiveRatio).toDouble();
        final secondExtent = math
            .max(0, availableExtent - firstExtent)
            .toDouble();
        final divider = _TerminalSplitDivider(
          axis: axis,
          onDragDelta: (delta) {
            if (availableExtent <= 0) {
              return;
            }
            final logicalDelta = axis == Axis.horizontal ? delta.dx : delta.dy;
            final nextRatio = (firstExtent + logicalDelta) / availableExtent;
            onRatioChanged(nextRatio.clamp(minRatio, maxRatio).toDouble());
          },
        );
        if (axis == Axis.horizontal) {
          return Row(
            children: [
              SizedBox(width: firstExtent, child: first),
              divider,
              SizedBox(width: secondExtent, child: second),
            ],
          );
        }
        return Column(
          children: [
            SizedBox(height: firstExtent, child: first),
            divider,
            SizedBox(height: secondExtent, child: second),
          ],
        );
      },
    );
  }
}

class _TerminalSplitDivider extends StatelessWidget {
  const _TerminalSplitDivider({required this.axis, required this.onDragDelta});

  final Axis axis;
  final ValueChanged<Offset> onDragDelta;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return MouseRegion(
      cursor: axis == Axis.horizontal
          ? SystemMouseCursors.resizeColumn
          : SystemMouseCursors.resizeRow,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanUpdate: (details) => onDragDelta(details.delta),
        child: SizedBox(
          width: axis == Axis.horizontal ? _terminalDividerHitSize : null,
          height: axis == Axis.vertical ? _terminalDividerHitSize : null,
          child: Center(
            child: Container(
              width: axis == Axis.horizontal ? 1 : double.infinity,
              height: axis == Axis.horizontal ? double.infinity : 1,
              color: t.borderSubtle,
            ),
          ),
        ),
      ),
    );
  }
}

class _TerminalViewportPane extends StatelessWidget {
  const _TerminalViewportPane({
    required this.terminal,
    required this.controller,
    required this.focusNode,
    required this.settings,
    required this.active,
    required this.paneIndex,
    required this.label,
    required this.lifecycle,
    required this.local,
    required this.pane,
    required this.canClose,
    this.onKeyEvent,
    this.onInsertText,
    required this.onTap,
    required this.onClose,
    required this.onReconnect,
    required this.onSwapPanes,
    required this.onDropTabPane,
  });

  final Terminal terminal;
  final TerminalController controller;
  final FocusNode focusNode;
  final TerminalDisplaySettings settings;
  final bool active;
  final int paneIndex;
  final String label;
  final SessionLifecycleState lifecycle;
  final bool local;
  final TerminalPaneState pane;
  final bool canClose;
  final FocusOnKeyEventCallback? onKeyEvent;
  final TerminalInsertTextInterceptor? onInsertText;
  final VoidCallback onTap;
  final VoidCallback onClose;
  final VoidCallback onReconnect;
  final ValueChanged<int> onSwapPanes;
  final void Function(WorkspaceTabId sourceTabId, _TerminalPaneDropPlacement)
  onDropTabPane;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final status = _terminalPaneStatusLabel(context.l10n, lifecycle, local);
    return DragTarget<Object>(
      onWillAcceptWithDetails: (details) => _acceptsPaneDrop(details.data),
      onAcceptWithDetails: (details) {
        final data = details.data;
        if (data is _TerminalPaneDragData && data.paneIndex != paneIndex) {
          onSwapPanes(data.paneIndex);
        } else if (data is _TerminalTabDragData) {
          onDropTabPane(
            data.tabId,
            _placementForOffset(context, details.offset),
          );
        }
      },
      builder: (context, candidates, _) {
        final dropActive = candidates.isNotEmpty;
        return Material(
          color: t.surfaceSunken,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: SerlinkRadii.dialog,
            side: BorderSide(
              color: dropActive || active ? t.accentPrimary : t.borderSubtle,
              width: dropActive || active ? 1.5 : 1,
            ),
          ),
          child: SerlinkPressable(
            onTap: onTap,
            borderRadius: SerlinkRadii.dialog,
            hoverColor: t.accentPrimary.withValues(alpha: 0.05),
            child: Column(
              children: [
                Draggable<_TerminalPaneDragData>(
                  data: _TerminalPaneDragData(paneIndex: paneIndex),
                  feedback: _TerminalDragFeedback(label: label),
                  allowedButtonsFilter: _primaryPointerButton,
                  childWhenDragging: Opacity(
                    opacity: 0.5,
                    child: _TerminalPaneHeader(
                      label: label,
                      status: status,
                      active: active,
                      canClose: canClose,
                      onClose: onClose,
                    ),
                  ),
                  child: _TerminalPaneHeader(
                    label: label,
                    status: status,
                    active: active,
                    canClose: canClose,
                    onClose: onClose,
                  ),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      TerminalView(
                        terminal,
                        controller: controller,
                        focusNode: focusNode,
                        autofocus: active,
                        padding: _terminalViewportPadding,
                        theme: settings.terminalTheme,
                        textStyle: settings.textStyle,
                        onKeyEvent: onKeyEvent,
                        onInsertText: onInsertText,
                      ),
                      if (_terminalPaneNeedsOverlay(lifecycle))
                        _TerminalPaneRecoveryOverlay(
                          pane: pane,
                          local: local,
                          onReconnect: onReconnect,
                          onClose: canClose ? onClose : null,
                        ),
                      if (dropActive) const _TerminalPaneDropScrim(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  bool _acceptsPaneDrop(Object? data) {
    if (data is _TerminalPaneDragData) {
      return data.paneIndex != paneIndex;
    }
    return data is _TerminalTabDragData;
  }

  _TerminalPaneDropPlacement _placementForOffset(
    BuildContext context,
    Offset globalOffset,
  ) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      return _TerminalPaneDropPlacement.right;
    }
    final localOffset = box.globalToLocal(globalOffset);
    final horizontalEdge = math.min(
      localOffset.dx,
      box.size.width - localOffset.dx,
    );
    final verticalEdge = math.min(
      localOffset.dy,
      box.size.height - localOffset.dy,
    );
    if (horizontalEdge < verticalEdge) {
      return localOffset.dx < box.size.width / 2
          ? _TerminalPaneDropPlacement.left
          : _TerminalPaneDropPlacement.right;
    }
    return localOffset.dy < box.size.height / 2
        ? _TerminalPaneDropPlacement.top
        : _TerminalPaneDropPlacement.bottom;
  }
}

class _TerminalPaneHeader extends StatelessWidget {
  const _TerminalPaneHeader({
    required this.label,
    required this.status,
    required this.active,
    required this.canClose,
    required this.onClose,
  });

  final String label;
  final String? status;
  final bool active;
  final bool canClose;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      height: 32,
      width: double.infinity,
      padding: const EdgeInsets.only(left: 10, right: 6),
      decoration: BoxDecoration(
        color: active ? t.accentPrimary.withValues(alpha: 0.12) : t.surfaceBase,
        border: Border(bottom: BorderSide(color: t.borderSubtle)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              status == null ? label : '$label · $status',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: active ? t.textPrimary : t.textSecondary,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          if (canClose)
            SerlinkTooltip(
              message: context.l10n.terminalClosePaneTooltip,
              child: SerlinkIconButton(
                constraints: const BoxConstraints.tightFor(
                  width: 24,
                  height: 24,
                ),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                onPressed: onClose,
                icon: Icon(Icons.close, size: 15, color: t.textSecondary),
              ),
            ),
        ],
      ),
    );
  }
}

class _TerminalPaneDropScrim extends StatelessWidget {
  const _TerminalPaneDropScrim();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Positioned.fill(
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: t.accentPrimary.withValues(alpha: 0.10),
            border: Border.all(color: t.accentPrimary),
          ),
        ),
      ),
    );
  }
}

class _TerminalDragFeedback extends StatelessWidget {
  const _TerminalDragFeedback({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: t.surfaceRaised,
          borderRadius: SerlinkRadii.control,
          border: Border.all(color: t.accentPrimary),
          boxShadow: serlinkShadow(t, elevation: 12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: t.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _TerminalPaneDragData {
  const _TerminalPaneDragData({required this.paneIndex});

  final int paneIndex;
}

class _TerminalTabDragData {
  const _TerminalTabDragData({required this.tabId});

  final WorkspaceTabId tabId;
}

enum _TerminalPaneDropPlacement { left, right, top, bottom }

bool _primaryPointerButton(int buttons) {
  return buttons == kPrimaryButton;
}

class _TerminalPaneRecoveryOverlay extends StatelessWidget {
  const _TerminalPaneRecoveryOverlay({
    required this.pane,
    required this.local,
    required this.onReconnect,
    required this.onClose,
  });

  final TerminalPaneState pane;
  final bool local;
  final VoidCallback onReconnect;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = context.l10n;
    final message =
        (pane.failure == null
            ? null
            : localizedSessionFailureMessage(l10n, pane.failure!)) ??
        (local ? l10n.localShellInactive : l10n.connectionInactive);
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: t.surfaceSunken.withValues(alpha: 0.88),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.link_off, size: 24, color: t.statusDanger),
                  const SizedBox(height: 10),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: t.textPrimary,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      SerlinkFilledButton(
                        onPressed: onReconnect,
                        size: SerlinkButtonSize.sm,
                        child: Text(
                          local ? l10n.restartAction : l10n.reconnectAction,
                        ),
                      ),
                      if (onClose != null)
                        SerlinkTextButton(
                          onPressed: onClose,
                          size: SerlinkButtonSize.sm,
                          child: Text(l10n.closeAction),
                        ),
                    ],
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

bool _terminalPaneNeedsOverlay(SessionLifecycleState lifecycle) {
  return lifecycle == SessionLifecycleState.disconnected ||
      lifecycle == SessionLifecycleState.failed;
}

String? _terminalPaneStatusLabel(
  AppLocalizations l10n,
  SessionLifecycleState lifecycle,
  bool local,
) {
  return switch (lifecycle) {
    SessionLifecycleState.connected => null,
    _ => _terminalPaneLifecycleLabel(l10n, lifecycle, local: local),
  };
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
