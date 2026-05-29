import 'package:flutter/widgets.dart';

import '../../../core/failure/app_failure.dart';
import '../../../core/ids/entity_id.dart';
import '../../terminal/application/terminal_display_settings.dart';

enum WorkspaceArea { hosts, sessions, transfers, snippets, settings }

enum WorkspaceTabKind { terminal, sftp, localTerminal }

enum SessionLifecycleState {
  idle,
  resolvingProfile,
  connecting,
  verifyingHostKey,
  authenticating,
  connected,
  reconnecting,
  disconnecting,
  disconnected,
  failed,
}

sealed class WorkspaceTabContent {
  const WorkspaceTabContent();

  WorkspaceTabKind get kind;
}

class TerminalPaneState {
  const TerminalPaneState({
    required this.sessionId,
    required this.title,
    required this.lifecycle,
    this.failure,
    this.displaySettings,
  });

  final SessionId sessionId;
  final String title;
  final SessionLifecycleState lifecycle;
  final AppFailure? failure;
  final TerminalDisplaySettings? displaySettings;

  TerminalPaneState copyWith({
    SessionId? sessionId,
    String? title,
    SessionLifecycleState? lifecycle,
    AppFailure? failure,
    bool clearFailure = false,
    TerminalDisplaySettings? displaySettings,
    bool clearDisplaySettings = false,
  }) {
    return TerminalPaneState(
      sessionId: sessionId ?? this.sessionId,
      title: title ?? this.title,
      lifecycle: lifecycle ?? this.lifecycle,
      failure: clearFailure ? null : failure ?? this.failure,
      displaySettings: clearDisplaySettings
          ? null
          : displaySettings ?? this.displaySettings,
    );
  }
}

class TerminalTabContent extends WorkspaceTabContent {
  const TerminalTabContent({
    required this.panes,
    this.splitAxis = Axis.horizontal,
    this.activePane = 0,
  });

  final List<TerminalPaneState> panes;
  final Axis splitAxis;
  final int activePane;

  @override
  WorkspaceTabKind get kind => WorkspaceTabKind.terminal;

  bool get showSplit => panes.length > 1;

  TerminalPaneState get primaryPane => panes.first;

  TerminalPaneState? get activePaneState {
    if (panes.isEmpty) {
      return null;
    }
    final index = activePane.clamp(0, panes.length - 1);
    return panes[index];
  }

  TerminalTabContent copyWith({
    List<TerminalPaneState>? panes,
    Axis? splitAxis,
    int? activePane,
  }) {
    return TerminalTabContent(
      panes: panes ?? this.panes,
      splitAxis: splitAxis ?? this.splitAxis,
      activePane: activePane ?? this.activePane,
    );
  }
}

class SftpTabContent extends WorkspaceTabContent {
  const SftpTabContent({required this.sessionId, required this.currentPath});

  final SessionId sessionId;
  final String currentPath;

  @override
  WorkspaceTabKind get kind => WorkspaceTabKind.sftp;
}

class LocalTerminalTabContent extends WorkspaceTabContent {
  const LocalTerminalTabContent({required this.sessionId});

  final SessionId sessionId;

  @override
  WorkspaceTabKind get kind => WorkspaceTabKind.localTerminal;
}

class WorkspaceTabState {
  const WorkspaceTabState({
    required this.id,
    required this.hostId,
    required this.title,
    required this.content,
    required this.lifecycle,
    required this.createdAt,
    required this.lastActivityAt,
    this.failure,
    this.hasActiveTransfer = false,
  });

  final WorkspaceTabId id;
  final HostId? hostId;
  final String title;
  final WorkspaceTabContent content;
  final SessionLifecycleState lifecycle;
  final AppFailure? failure;
  final bool hasActiveTransfer;
  final DateTime createdAt;
  final DateTime lastActivityAt;

  WorkspaceTabState copyWith({
    String? title,
    WorkspaceTabContent? content,
    SessionLifecycleState? lifecycle,
    AppFailure? failure,
    bool clearFailure = false,
    bool? hasActiveTransfer,
    DateTime? lastActivityAt,
  }) {
    return WorkspaceTabState(
      id: id,
      hostId: hostId,
      title: title ?? this.title,
      content: content ?? this.content,
      lifecycle: lifecycle ?? this.lifecycle,
      failure: clearFailure ? null : failure ?? this.failure,
      hasActiveTransfer: hasActiveTransfer ?? this.hasActiveTransfer,
      createdAt: createdAt,
      lastActivityAt: lastActivityAt ?? this.lastActivityAt,
    );
  }
}

class WorkspaceState {
  const WorkspaceState({
    required this.area,
    required this.tabs,
    required this.activeTabId,
  });

  final WorkspaceArea area;
  final List<WorkspaceTabState> tabs;
  final WorkspaceTabId? activeTabId;

  WorkspaceTabState? get activeTab {
    for (final tab in tabs) {
      if (tab.id == activeTabId) {
        return tab;
      }
    }
    return tabs.isEmpty ? null : tabs.first;
  }

  WorkspaceState copyWith({
    WorkspaceArea? area,
    List<WorkspaceTabState>? tabs,
    WorkspaceTabId? activeTabId,
    bool clearActiveTab = false,
  }) {
    return WorkspaceState(
      area: area ?? this.area,
      tabs: tabs ?? this.tabs,
      activeTabId: clearActiveTab ? null : activeTabId ?? this.activeTabId,
    );
  }
}
