import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/core/ids/entity_id.dart';
import 'package:serlink/features/workspace/domain/workspace_tab.dart';

void main() {
  test(
    'activeTerminalPaneCount counts live remote and local terminal panes',
    () {
      final now = DateTime(2026);
      final state = WorkspaceState(
        area: WorkspaceArea.sessions,
        activeTabId: WorkspaceTabId('remote'),
        tabs: [
          _tab(
            id: 'remote',
            now: now,
            content: TerminalTabContent(
              panes: [
                _pane('remote-1', SessionLifecycleState.connected),
                _pane('remote-2', SessionLifecycleState.authenticating),
                _pane('remote-3', SessionLifecycleState.failed),
              ],
              layout: const TerminalPaneSplit(
                axis: Axis.horizontal,
                first: TerminalPaneLeaf(0),
                second: TerminalPaneSplit(
                  axis: Axis.vertical,
                  first: TerminalPaneLeaf(1),
                  second: TerminalPaneLeaf(2),
                ),
              ),
            ),
            lifecycle: SessionLifecycleState.connected,
          ),
          _tab(
            id: 'local',
            now: now,
            content: LocalTerminalTabContent(
              panes: [
                _pane('local-1', SessionLifecycleState.reconnecting),
                _pane('local-2', SessionLifecycleState.disconnected),
              ],
            ),
            lifecycle: SessionLifecycleState.reconnecting,
          ),
          _tab(
            id: 'sftp',
            now: now,
            content: SftpTabContent(
              sessionId: SessionId('sftp-1'),
              currentPath: '/',
              rootPath: '/',
            ),
            lifecycle: SessionLifecycleState.connected,
          ),
        ],
      );

      expect(state.activeTerminalPaneCount, 3);
      expect(state.hasActiveTerminalPanes, isTrue);
    },
  );

  test(
    'activeTerminalPaneCount ignores terminal panes that already stopped',
    () {
      final now = DateTime(2026);
      final state = WorkspaceState(
        area: WorkspaceArea.sessions,
        activeTabId: WorkspaceTabId('remote'),
        tabs: [
          _tab(
            id: 'remote',
            now: now,
            content: TerminalTabContent(
              panes: [
                _pane('remote-1', SessionLifecycleState.idle),
                _pane('remote-2', SessionLifecycleState.disconnected),
                _pane('remote-3', SessionLifecycleState.failed),
              ],
            ),
            lifecycle: SessionLifecycleState.disconnected,
          ),
        ],
      );

      expect(state.activeTerminalPaneCount, 0);
      expect(state.hasActiveTerminalPanes, isFalse);
    },
  );

  test('terminal pane layout updates ratios and swaps leaves', () {
    const layout = TerminalPaneSplit(
      axis: Axis.horizontal,
      ratio: 0.35,
      first: TerminalPaneLeaf(0),
      second: TerminalPaneSplit(
        axis: Axis.vertical,
        ratio: 0.7,
        first: TerminalPaneLeaf(1),
        second: TerminalPaneLeaf(2),
      ),
    );

    final resizedRoot = layout.updateSplitRatio(const [], 0.25);
    final rootSplit = _expectSplit(resizedRoot, Axis.horizontal);
    expect(rootSplit.ratio, 0.25);
    final nestedBeforeResize = _expectSplit(rootSplit.second, Axis.vertical);
    expect(nestedBeforeResize.ratio, 0.7);

    final resizedNested = resizedRoot.updateSplitRatio(const [1], 0.8);
    final rootAfterNestedResize = _expectSplit(resizedNested, Axis.horizontal);
    expect(rootAfterNestedResize.ratio, 0.25);
    final nestedAfterResize = _expectSplit(
      rootAfterNestedResize.second,
      Axis.vertical,
    );
    expect(nestedAfterResize.ratio, 0.8);

    final swapped = resizedNested.swapLeafIndexes(0, 2);
    expect(swapped.paneIndexes, [2, 1, 0]);
  });

  test('terminal pane layout removes and reindexes leaves', () {
    const layout = TerminalPaneSplit(
      axis: Axis.horizontal,
      ratio: 0.4,
      first: TerminalPaneLeaf(0),
      second: TerminalPaneSplit(
        axis: Axis.vertical,
        ratio: 0.65,
        first: TerminalPaneLeaf(1),
        second: TerminalPaneLeaf(2),
      ),
    );

    final removed = layout.removeLeaf(1)!.reindexAfterRemoving(1);
    final root = _expectSplit(removed, Axis.horizontal);

    expect(root.ratio, 0.4);
    _expectLeaf(root.first, 0);
    _expectLeaf(root.second, 1);
    expect(root.paneIndexes, [0, 1]);
  });
}

TerminalPaneSplit _expectSplit(TerminalPaneLayout layout, Axis axis) {
  final split = layout as TerminalPaneSplit;
  expect(split.axis, axis);
  return split;
}

void _expectLeaf(TerminalPaneLayout layout, int paneIndex) {
  final leaf = layout as TerminalPaneLeaf;
  expect(leaf.paneIndex, paneIndex);
}

TerminalPaneState _pane(String id, SessionLifecycleState lifecycle) {
  return TerminalPaneState(
    sessionId: SessionId(id),
    title: id,
    lifecycle: lifecycle,
  );
}

WorkspaceTabState _tab({
  required String id,
  required DateTime now,
  required WorkspaceTabContent content,
  required SessionLifecycleState lifecycle,
}) {
  return WorkspaceTabState(
    id: WorkspaceTabId(id),
    hostId: null,
    title: id,
    content: content,
    lifecycle: lifecycle,
    createdAt: now,
    lastActivityAt: now,
  );
}
