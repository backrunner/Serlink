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
