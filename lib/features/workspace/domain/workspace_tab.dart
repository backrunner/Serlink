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

sealed class TerminalPaneLayout {
  const TerminalPaneLayout();

  List<int> get paneIndexes;

  int get primaryPaneIndex => paneIndexes.first;

  Axis? get rootAxis => null;

  TerminalPaneLayout replaceLeaf(int paneIndex, TerminalPaneLayout replacement);

  TerminalPaneLayout? removeLeaf(int paneIndex);

  TerminalPaneLayout reindexAfterRemoving(int removedPaneIndex);

  TerminalPaneLayout withRootAxis(Axis axis);
}

class TerminalPaneLeaf extends TerminalPaneLayout {
  const TerminalPaneLeaf(this.paneIndex);

  final int paneIndex;

  @override
  List<int> get paneIndexes => [paneIndex];

  @override
  TerminalPaneLayout replaceLeaf(
    int paneIndex,
    TerminalPaneLayout replacement,
  ) {
    return this.paneIndex == paneIndex ? replacement : this;
  }

  @override
  TerminalPaneLayout? removeLeaf(int paneIndex) {
    return this.paneIndex == paneIndex ? null : this;
  }

  @override
  TerminalPaneLayout reindexAfterRemoving(int removedPaneIndex) {
    if (paneIndex <= removedPaneIndex) {
      return this;
    }
    return TerminalPaneLeaf(paneIndex - 1);
  }

  @override
  TerminalPaneLayout withRootAxis(Axis axis) => this;
}

class TerminalPaneSplit extends TerminalPaneLayout {
  const TerminalPaneSplit({
    required this.axis,
    required this.first,
    required this.second,
  });

  final Axis axis;
  final TerminalPaneLayout first;
  final TerminalPaneLayout second;

  @override
  Axis get rootAxis => axis;

  @override
  List<int> get paneIndexes => [...first.paneIndexes, ...second.paneIndexes];

  @override
  TerminalPaneLayout replaceLeaf(
    int paneIndex,
    TerminalPaneLayout replacement,
  ) {
    return TerminalPaneSplit(
      axis: axis,
      first: first.replaceLeaf(paneIndex, replacement),
      second: second.replaceLeaf(paneIndex, replacement),
    );
  }

  @override
  TerminalPaneLayout? removeLeaf(int paneIndex) {
    final nextFirst = first.removeLeaf(paneIndex);
    final nextSecond = second.removeLeaf(paneIndex);
    if (nextFirst == null && nextSecond == null) {
      return null;
    }
    if (nextFirst == null) {
      return nextSecond;
    }
    if (nextSecond == null) {
      return nextFirst;
    }
    return TerminalPaneSplit(axis: axis, first: nextFirst, second: nextSecond);
  }

  @override
  TerminalPaneLayout reindexAfterRemoving(int removedPaneIndex) {
    return TerminalPaneSplit(
      axis: axis,
      first: first.reindexAfterRemoving(removedPaneIndex),
      second: second.reindexAfterRemoving(removedPaneIndex),
    );
  }

  @override
  TerminalPaneLayout withRootAxis(Axis axis) {
    return TerminalPaneSplit(axis: axis, first: first, second: second);
  }
}

class TerminalTabContent extends WorkspaceTabContent {
  const TerminalTabContent({
    required this.panes,
    this.layout = const TerminalPaneLeaf(0),
    this.activePane = 0,
  });

  final List<TerminalPaneState> panes;
  final TerminalPaneLayout layout;
  final int activePane;

  @override
  WorkspaceTabKind get kind => WorkspaceTabKind.terminal;

  bool get showSplit => panes.length > 1;

  Axis get splitAxis => layout.rootAxis ?? Axis.horizontal;

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
    TerminalPaneLayout? layout,
    Axis? splitAxis,
    int? activePane,
  }) {
    return TerminalTabContent(
      panes: panes ?? this.panes,
      layout: layout ?? _nextLayout(this.layout, splitAxis),
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
  const LocalTerminalTabContent({
    required this.panes,
    this.layout = const TerminalPaneLeaf(0),
    this.activePane = 0,
  });

  final List<TerminalPaneState> panes;
  final TerminalPaneLayout layout;
  final int activePane;

  @override
  WorkspaceTabKind get kind => WorkspaceTabKind.localTerminal;

  bool get showSplit => panes.length > 1;

  Axis get splitAxis => layout.rootAxis ?? Axis.horizontal;

  TerminalPaneState get primaryPane => panes.first;

  TerminalPaneState? get activePaneState {
    if (panes.isEmpty) {
      return null;
    }
    final index = activePane.clamp(0, panes.length - 1);
    return panes[index];
  }

  SessionId get sessionId => primaryPane.sessionId;

  LocalTerminalTabContent copyWith({
    List<TerminalPaneState>? panes,
    TerminalPaneLayout? layout,
    Axis? splitAxis,
    int? activePane,
  }) {
    return LocalTerminalTabContent(
      panes: panes ?? this.panes,
      layout: layout ?? _nextLayout(this.layout, splitAxis),
      activePane: activePane ?? this.activePane,
    );
  }
}

TerminalPaneLayout _nextLayout(TerminalPaneLayout current, Axis? splitAxis) {
  if (splitAxis == null) {
    return current;
  }
  return current.withRootAxis(splitAxis);
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
