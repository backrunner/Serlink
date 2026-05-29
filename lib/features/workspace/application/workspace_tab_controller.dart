import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../app/app_dependencies.dart';
import '../../../core/failure/app_failure.dart';
import '../../../core/ids/entity_id.dart';
import '../../hosts/domain/host.dart';
import '../../ssh/application/connection_profile_resolver.dart';
import '../../ssh/application/ssh_session_service.dart';
import '../../ssh/data/dartssh2_ssh_session_service.dart';
import '../../ssh/domain/connection_profile.dart';
import '../../terminal/application/local_terminal_service.dart';
import '../../terminal/application/terminal_display_settings.dart';
import '../../terminal/data/flutter_pty_local_terminal_service.dart';
import '../../vault/application/vault_service.dart';
import '../domain/workspace_tab.dart';
import 'workspace_runtime_registry.dart';

final workspaceTabControllerProvider =
    NotifierProvider<WorkspaceTabController, WorkspaceState>(
      WorkspaceTabController.new,
    );

final connectionProfileResolverProvider = Provider<ConnectionProfileResolver>((
  ref,
) {
  final vault = ref.watch(vaultSessionControllerProvider).value;
  if (vault?.vaultState != VaultState.unlocked) {
    return const LockedVaultConnectionProfileResolver();
  }
  return ref.watch(encryptedConnectionProfileResolverProvider);
});

final sshSessionServiceProvider = Provider<SshSessionService>((ref) {
  return DartSsh2SessionService(
    confirmHostKey: ref
        .watch(hostKeyVerificationServiceProvider)
        .confirmHostKey,
  );
});

final localTerminalServiceProvider = Provider<LocalTerminalService>((ref) {
  return const FlutterPtyLocalTerminalService();
});

final workspaceRuntimeRegistryProvider = Provider<WorkspaceRuntimeRegistry>((
  ref,
) {
  final registry = WorkspaceRuntimeRegistry(
    confirmMultilinePaste: ref
        .watch(securityModalServiceProvider)
        .confirmMultilinePaste,
  );
  ref.onDispose(() {
    unawaited(registry.dispose());
  });
  return registry;
});

class WorkspaceTabController extends Notifier<WorkspaceState> {
  static const _uuid = Uuid();
  final Map<WorkspaceTabId, int> _connectionTokens = {};
  final Map<WorkspaceTabId, Timer> _reconnectTimers = {};
  final Map<WorkspaceTabId, int> _reconnectAttempts = {};

  @override
  WorkspaceState build() {
    ref.onDispose(() {
      for (final timer in _reconnectTimers.values) {
        timer.cancel();
      }
      _reconnectTimers.clear();
      _reconnectAttempts.clear();
      _connectionTokens.clear();
    });
    return const WorkspaceState(
      area: WorkspaceArea.hosts,
      tabs: [],
      activeTabId: null,
    );
  }

  void selectArea(WorkspaceArea area) {
    state = state.copyWith(area: area);
  }

  void openTerminal(HostSummary host) {
    final sessionId = _newSessionId();
    ref
        .read(workspaceRuntimeRegistryProvider)
        .createTerminal(sessionId: sessionId, title: host.displayName);
    final tab = _open(
      hostId: host.id,
      title: host.displayName,
      content: TerminalTabContent(
        panes: [
          TerminalPaneState(
            sessionId: sessionId,
            title: host.displayName,
            lifecycle: SessionLifecycleState.resolvingProfile,
          ),
        ],
      ),
      lifecycle: SessionLifecycleState.resolvingProfile,
      switchArea: WorkspaceArea.sessions,
    );
    unawaited(_loadTerminalDisplaySettings(tab.id, host.id));
    unawaited(_connect(tab, _nextConnectionToken(tab.id)));
  }

  void openTerminalFromTab(WorkspaceTabId tabId) {
    final source = state.tabs
        .where((candidate) => candidate.id == tabId)
        .firstOrNull;
    final hostId = source?.hostId;
    if (source == null || hostId == null) {
      return;
    }
    final title = _baseTabTitle(source.title);
    final sessionId = _newSessionId();
    ref
        .read(workspaceRuntimeRegistryProvider)
        .createTerminal(sessionId: sessionId, title: title);
    final tab = _open(
      hostId: hostId,
      title: title,
      content: TerminalTabContent(
        panes: [
          TerminalPaneState(
            sessionId: sessionId,
            title: title,
            lifecycle: SessionLifecycleState.resolvingProfile,
          ),
        ],
      ),
      lifecycle: SessionLifecycleState.resolvingProfile,
      switchArea: WorkspaceArea.sessions,
    );
    unawaited(_loadTerminalDisplaySettings(tab.id, hostId));
    unawaited(_connect(tab, _nextConnectionToken(tab.id)));
  }

  void openSftp(HostSummary host) {
    final sessionId = _newSessionId();
    final tab = _open(
      hostId: host.id,
      title: '${host.displayName} /',
      content: SftpTabContent(sessionId: sessionId, currentPath: '/'),
      lifecycle: SessionLifecycleState.resolvingProfile,
      switchArea: WorkspaceArea.files,
    );
    unawaited(_connect(tab, _nextConnectionToken(tab.id)));
  }

  void openSftpFromTab(WorkspaceTabId tabId) {
    final source = state.tabs
        .where((candidate) => candidate.id == tabId)
        .firstOrNull;
    final hostId = source?.hostId;
    if (source == null || hostId == null) {
      return;
    }
    final sessionId = _newSessionId();
    final tab = _open(
      hostId: hostId,
      title: '${_baseTabTitle(source.title)} /',
      content: SftpTabContent(sessionId: sessionId, currentPath: '/'),
      lifecycle: SessionLifecycleState.resolvingProfile,
      switchArea: WorkspaceArea.files,
    );
    unawaited(_connect(tab, _nextConnectionToken(tab.id)));
  }

  void openTerminalAndSftp(HostSummary host) {
    openTerminal(host);
    openSftp(host);
  }

  void openLocalTerminal() {
    final sessionId = _newSessionId();
    ref
        .read(workspaceRuntimeRegistryProvider)
        .createTerminal(sessionId: sessionId, title: 'Local Shell');
    final tab = _open(
      hostId: null,
      title: 'Local Shell',
      content: LocalTerminalTabContent(sessionId: sessionId),
      lifecycle: SessionLifecycleState.connecting,
      switchArea: WorkspaceArea.sessions,
    );
    unawaited(_connectLocalTerminal(tab, _nextConnectionToken(tab.id)));
  }

  void setActiveTab(WorkspaceTabId tabId) {
    state = state.copyWith(activeTabId: tabId);
  }

  void reconnect(WorkspaceTabId tabId) {
    _clearReconnectState(tabId);
    _runReconnect(tabId);
  }

  void _runReconnect(WorkspaceTabId tabId, {bool automatic = false}) {
    final tab = state.tabs
        .where((candidate) => candidate.id == tabId)
        .firstOrNull;
    if (tab == null) {
      return;
    }
    if (tab.hostId == null) {
      if (tab.content is! LocalTerminalTabContent) {
        return;
      }
      final token = _nextConnectionToken(tab.id);
      unawaited(_closeTabSessions(tab));
      final reconnecting = tab.copyWith(
        lifecycle: SessionLifecycleState.reconnecting,
        clearFailure: true,
        lastActivityAt: DateTime.now(),
      );
      _replaceTab(reconnecting);
      state = state.copyWith(activeTabId: tabId);
      unawaited(
        _connectLocalTerminal(
          reconnecting,
          token,
          preserveReconnectAttempts: automatic,
        ),
      );
      return;
    }
    final token = _nextConnectionToken(tab.id);
    unawaited(_closeTabSessions(tab));
    final reconnecting = _copyTerminalTabLifecycle(
      tab,
      SessionLifecycleState.reconnecting,
      clearFailure: true,
    );
    _replaceTab(reconnecting.copyWith(lastActivityAt: DateTime.now()));
    state = state.copyWith(activeTabId: tabId);
    unawaited(
      _connect(reconnecting, token, preserveReconnectAttempts: automatic),
    );
  }

  void changeSftpDirectory(WorkspaceTabId tabId, String path) {
    final tab = state.tabs
        .where((candidate) => candidate.id == tabId)
        .firstOrNull;
    if (tab == null) {
      return;
    }
    final content = tab.content;
    if (content is! SftpTabContent) {
      return;
    }
    _replaceTab(
      tab.copyWith(
        title: _sftpTitle(tab.title, path),
        content: SftpTabContent(
          sessionId: content.sessionId,
          currentPath: _normalizeRemotePath(path),
        ),
        lastActivityAt: DateTime.now(),
      ),
    );
  }

  void markDisconnected(WorkspaceTabId tabId) {
    if (!ref.mounted) {
      return;
    }
    final updated = [
      for (final tab in state.tabs)
        if (tab.id == tabId)
          tab.copyWith(
            lifecycle: SessionLifecycleState.disconnected,
            failure: const AppFailure(
              code: 'session.disconnected',
              message:
                  'Connection interrupted. Reconnect starts a new session.',
            ),
          )
        else
          tab,
    ];
    state = state.copyWith(tabs: updated);
  }

  void saveTerminalDisplaySettingsForHost(
    WorkspaceTabId tabId,
    TerminalDisplaySettings settings,
  ) {
    final tab = state.tabs
        .where((candidate) => candidate.id == tabId)
        .firstOrNull;
    final hostId = tab?.hostId;
    if (tab == null || hostId == null || tab.content is! TerminalTabContent) {
      return;
    }
    _replaceTerminalDisplaySettings(tabId, settings);
    unawaited(_saveTerminalDisplaySettingsForHost(hostId, settings));
  }

  void resetTerminalDisplaySettingsForHost(WorkspaceTabId tabId) {
    final tab = state.tabs
        .where((candidate) => candidate.id == tabId)
        .firstOrNull;
    final hostId = tab?.hostId;
    if (tab == null || hostId == null || tab.content is! TerminalTabContent) {
      return;
    }
    _replaceTerminalDisplaySettings(tabId, null, clear: true);
    unawaited(_deleteTerminalDisplaySettingsForHost(hostId));
  }

  void enableTerminalSplit(
    WorkspaceTabId tabId, {
    Axis axis = Axis.horizontal,
  }) {
    final tab = state.tabs
        .where((candidate) => candidate.id == tabId)
        .firstOrNull;
    final content = tab?.content;
    if (tab == null || content is! TerminalTabContent) {
      return;
    }
    _replaceTab(
      tab.copyWith(
        content: content.copyWith(
          splitAxis: axis,
          activePane: content.activePane.clamp(0, 1),
        ),
        lastActivityAt: DateTime.now(),
      ),
    );
    if (content.panes.length > 1) {
      return;
    }
    final paneTitle = tab.title;
    final sessionId = _newSessionId();
    ref
        .read(workspaceRuntimeRegistryProvider)
        .createTerminal(sessionId: sessionId, title: paneTitle);
    final next = (tab.content as TerminalTabContent).copyWith(
      panes: [
        ...content.panes,
        TerminalPaneState(
          sessionId: sessionId,
          title: paneTitle,
          lifecycle: tab.hostId == null
              ? SessionLifecycleState.connecting
              : SessionLifecycleState.resolvingProfile,
          displaySettings: content.primaryPane.displaySettings,
        ),
      ],
      splitAxis: axis,
      activePane: 1,
    );
    final updatedTab = tab.copyWith(
      content: next,
      lifecycle: _aggregateLifecycle(next),
      lastActivityAt: DateTime.now(),
    );
    _replaceTab(updatedTab);
    final paneToken = _nextConnectionToken(tab.id);
    if (tab.hostId == null) {
      unawaited(_connectLocalTerminalPane(updatedTab, 1, paneToken));
    } else {
      unawaited(_connectTerminalPane(updatedTab, 1, paneToken));
    }
  }

  void disableTerminalSplit(WorkspaceTabId tabId) {
    final tab = state.tabs
        .where((candidate) => candidate.id == tabId)
        .firstOrNull;
    final content = tab?.content;
    if (tab == null || content is! TerminalTabContent) {
      return;
    }
    if (content.panes.length > 1) {
      for (final pane in content.panes.skip(1)) {
        unawaited(
          ref
              .read(workspaceRuntimeRegistryProvider)
              .closeSession(pane.sessionId),
        );
      }
    }
    _replaceTab(
      tab.copyWith(
        content: content.copyWith(panes: [content.primaryPane], activePane: 0),
        lifecycle: content.primaryPane.lifecycle,
        failure: content.primaryPane.failure,
        lastActivityAt: DateTime.now(),
      ),
    );
  }

  void setTerminalSplitAxis(WorkspaceTabId tabId, Axis axis) {
    final tab = state.tabs
        .where((candidate) => candidate.id == tabId)
        .firstOrNull;
    final content = tab?.content;
    if (tab == null || content is! TerminalTabContent) {
      return;
    }
    _replaceTab(
      tab.copyWith(
        content: content.copyWith(splitAxis: axis),
        lastActivityAt: DateTime.now(),
      ),
    );
  }

  void setActiveTerminalPane(WorkspaceTabId tabId, int paneIndex) {
    final tab = state.tabs
        .where((candidate) => candidate.id == tabId)
        .firstOrNull;
    final content = tab?.content;
    if (tab == null || content is! TerminalTabContent) {
      return;
    }
    final normalizedIndex = paneIndex.clamp(0, content.panes.length - 1);
    _replaceTab(
      tab.copyWith(
        content: content.copyWith(activePane: normalizedIndex),
        lastActivityAt: DateTime.now(),
      ),
    );
  }

  bool insertIntoActiveTerminal(String text, {bool submit = false}) {
    final tab = state.activeTab;
    if (tab == null || tab.lifecycle != SessionLifecycleState.connected) {
      return false;
    }
    final sessionId = switch (tab.content) {
      TerminalTabContent(:final activePaneState) => activePaneState?.sessionId,
      LocalTerminalTabContent(:final sessionId) => sessionId,
      SftpTabContent() => null,
    };
    if (sessionId == null) {
      return false;
    }
    final payload = submit ? _ensureTrailingNewline(text) : text;
    final inserted = ref
        .read(workspaceRuntimeRegistryProvider)
        .sendTerminalInput(sessionId, payload);
    if (inserted) {
      _replaceTab(tab.copyWith(lastActivityAt: DateTime.now()));
    }
    return inserted;
  }

  void closeTab(WorkspaceTabId tabId) {
    final closingTab = state.tabs
        .where((candidate) => candidate.id == tabId)
        .firstOrNull;
    if (closingTab != null) {
      _clearReconnectState(tabId);
      _connectionTokens.remove(tabId);
      unawaited(_closeTabSessions(closingTab));
    }
    final remaining = [
      for (final tab in state.tabs)
        if (tab.id != tabId) tab,
    ];
    final nextActive = state.activeTabId == tabId
        ? (remaining.isEmpty ? null : remaining.last.id)
        : state.activeTabId;
    state = state.copyWith(
      tabs: remaining,
      activeTabId: nextActive,
      clearActiveTab: nextActive == null,
    );
  }

  void _clearReconnectState(WorkspaceTabId tabId) {
    _reconnectTimers.remove(tabId)?.cancel();
    _reconnectAttempts.remove(tabId);
  }

  void _clearReconnectTimer(WorkspaceTabId tabId) {
    _reconnectTimers.remove(tabId)?.cancel();
  }

  void _scheduleReconnect({
    required WorkspaceTabId tabId,
    required SshReconnectPolicy policy,
  }) {
    if (!policy.isAutomatic || policy.maxAttempts <= 0) {
      return;
    }
    final attempts = _reconnectAttempts[tabId] ?? 0;
    if (attempts >= policy.maxAttempts) {
      return;
    }
    _clearReconnectTimer(tabId);
    _reconnectAttempts[tabId] = attempts + 1;
    _reconnectTimers[tabId] = Timer(policy.backoff, () {
      if (!ref.mounted) {
        return;
      }
      if (!_connectionTokens.containsKey(tabId)) {
        return;
      }
      _clearReconnectTimer(tabId);
      _runReconnect(tabId, automatic: true);
    });
  }

  Future<void> _loadTerminalDisplaySettings(
    WorkspaceTabId tabId,
    HostId hostId,
  ) async {
    try {
      final settings = await ref
          .read(terminalHostDisplaySettingsRepositoryProvider)
          .readForHost(hostId);
      if (settings == null) {
        return;
      }
      _replaceTerminalDisplaySettings(tabId, settings);
    } on Object {
      // Host-specific display settings are best effort. A locked vault or
      // malformed profile must never interrupt the connection attempt.
    }
  }

  Future<void> _saveTerminalDisplaySettingsForHost(
    HostId hostId,
    TerminalDisplaySettings settings,
  ) async {
    try {
      await ref
          .read(terminalHostDisplaySettingsRepositoryProvider)
          .saveForHost(hostId, settings);
    } on Object {
      // The live tab keeps its in-memory settings even if encrypted persistence
      // is unavailable, matching global terminal settings behavior.
    }
  }

  Future<void> _deleteTerminalDisplaySettingsForHost(HostId hostId) async {
    try {
      await ref
          .read(terminalHostDisplaySettingsRepositoryProvider)
          .deleteForHost(hostId);
    } on Object {
      // Resetting the active tab should remain non-disruptive if the vault was
      // locked after the SSH session was established.
    }
  }

  void _replaceTerminalDisplaySettings(
    WorkspaceTabId tabId,
    TerminalDisplaySettings? settings, {
    bool clear = false,
  }) {
    if (!ref.mounted) {
      return;
    }
    final tab = state.tabs
        .where((candidate) => candidate.id == tabId)
        .firstOrNull;
    if (tab == null) {
      return;
    }
    final content = tab.content;
    if (content is! TerminalTabContent) {
      return;
    }
    final panes = [
      for (final pane in content.panes)
        pane.copyWith(displaySettings: settings, clearDisplaySettings: clear),
    ];
    _replaceTab(tab.copyWith(content: content.copyWith(panes: panes)));
  }

  WorkspaceTabState _open({
    required HostId? hostId,
    required String title,
    required WorkspaceTabContent content,
    required SessionLifecycleState lifecycle,
    required WorkspaceArea switchArea,
  }) {
    final now = DateTime.now();
    final tab = WorkspaceTabState(
      id: WorkspaceTabId(_uuid.v4()),
      hostId: hostId,
      title: title,
      content: content,
      lifecycle: lifecycle,
      createdAt: now,
      lastActivityAt: now,
    );
    state = state.copyWith(
      area: switchArea,
      tabs: [...state.tabs, tab],
      activeTabId: tab.id,
    );
    return tab;
  }

  SessionId _newSessionId() => SessionId(_uuid.v4());

  Future<void> _connect(
    WorkspaceTabState tab,
    int token, {
    bool preserveReconnectAttempts = false,
  }) async {
    final hostId = tab.hostId;
    if (hostId == null) {
      return;
    }
    final runtime = ref.read(workspaceRuntimeRegistryProvider);

    try {
      _replaceTab(
        tab.copyWith(
          lifecycle: SessionLifecycleState.resolvingProfile,
          clearFailure: true,
          lastActivityAt: DateTime.now(),
        ),
      );
      switch (tab.content) {
        case TerminalTabContent(:final panes):
          for (var paneIndex = 0; paneIndex < panes.length; paneIndex += 1) {
            final pane = panes[paneIndex];
            final profile = await ref
                .read(connectionProfileResolverProvider)
                .resolve(hostId: hostId, sessionId: pane.sessionId);
            _ensureCurrent(tab.id, token);
            _setTerminalPaneLifecycle(
              tab.id,
              paneIndex,
              SessionLifecycleState.connecting,
              clearFailure: true,
            );
            final shell = await ref
                .read(sshSessionServiceProvider)
                .openShell(profile);
            _ensureCurrent(tab.id, token);
            runtime.attachTerminal(sessionId: pane.sessionId, session: shell);
            await _runStartupCommands(shell, profile.startupCommands);
            _setTerminalPaneLifecycle(
              tab.id,
              paneIndex,
              SessionLifecycleState.connected,
              clearFailure: true,
            );
            if (preserveReconnectAttempts) {
              _clearReconnectTimer(tab.id);
            } else {
              _clearReconnectState(tab.id);
            }
            unawaited(
              shell.done
                  .then((_) {
                    if (_isCurrent(tab.id, token)) {
                      _markTerminalPaneDisconnected(tab.id, paneIndex);
                      if (panes.length == 1) {
                        _scheduleReconnect(
                          tabId: tab.id,
                          policy: profile.reconnectPolicy,
                        );
                      }
                    }
                  })
                  .catchError((Object error) {
                    if (_isCurrent(tab.id, token)) {
                      _markTerminalPaneFailed(tab.id, paneIndex, error);
                    }
                  }),
            );
          }
        case SftpTabContent(:final sessionId):
          final profile = await ref
              .read(connectionProfileResolverProvider)
              .resolve(hostId: hostId, sessionId: sessionId);
          _ensureCurrent(tab.id, token);
          _replaceTab(
            _currentTab(tab.id).copyWith(
              lifecycle: SessionLifecycleState.connecting,
              clearFailure: true,
              lastActivityAt: DateTime.now(),
            ),
          );
          final sftp = await ref
              .read(sshSessionServiceProvider)
              .openSftp(profile);
          _ensureCurrent(tab.id, token);
          runtime.attachSftp(sessionId: sessionId, connection: sftp);
          _replaceTab(
            _currentTab(tab.id).copyWith(
              lifecycle: SessionLifecycleState.connected,
              clearFailure: true,
              lastActivityAt: DateTime.now(),
            ),
          );
          if (preserveReconnectAttempts) {
            _clearReconnectTimer(tab.id);
          } else {
            _clearReconnectState(tab.id);
          }
          unawaited(
            sftp.done
                .then((_) {
                  if (_isCurrent(tab.id, token)) {
                    markDisconnected(tab.id);
                    _scheduleReconnect(
                      tabId: tab.id,
                      policy: profile.reconnectPolicy,
                    );
                  }
                })
                .catchError((Object error) {
                  if (_isCurrent(tab.id, token)) {
                    _markFailed(tab.id, error);
                  }
                }),
          );
        case LocalTerminalTabContent():
          break;
      }
    } on _StaleConnectionAttempt {
      return;
    } on Object catch (error) {
      if (_isCurrent(tab.id, token)) {
        if (tab.content case TerminalTabContent(:final panes)) {
          for (var i = 0; i < panes.length; i += 1) {
            runtime.writeTerminal(
              panes[i].sessionId,
              'Connection failed: ${_failureFrom(error).message}\r\n',
            );
            _markTerminalPaneFailed(tab.id, i, error);
          }
        } else {
          _markFailed(tab.id, error);
        }
      }
    }
  }

  Future<void> _connectTerminalPane(
    WorkspaceTabState tab,
    int paneIndex,
    int token,
  ) async {
    final hostId = tab.hostId;
    final content = tab.content;
    if (hostId == null || content is! TerminalTabContent) {
      return;
    }
    final pane = content.panes[paneIndex];
    final runtime = ref.read(workspaceRuntimeRegistryProvider);
    try {
      final profile = await ref
          .read(connectionProfileResolverProvider)
          .resolve(hostId: hostId, sessionId: pane.sessionId);
      _ensureCurrent(tab.id, token);
      _setTerminalPaneLifecycle(
        tab.id,
        paneIndex,
        SessionLifecycleState.connecting,
        clearFailure: true,
      );
      final shell = await ref
          .read(sshSessionServiceProvider)
          .openShell(profile);
      _ensureCurrent(tab.id, token);
      runtime.attachTerminal(sessionId: pane.sessionId, session: shell);
      await _runStartupCommands(shell, profile.startupCommands);
      _setTerminalPaneLifecycle(
        tab.id,
        paneIndex,
        SessionLifecycleState.connected,
        clearFailure: true,
      );
      unawaited(
        shell.done
            .then((_) {
              if (_isCurrent(tab.id, token)) {
                _markTerminalPaneDisconnected(tab.id, paneIndex);
              }
            })
            .catchError((Object error) {
              if (_isCurrent(tab.id, token)) {
                _markTerminalPaneFailed(tab.id, paneIndex, error);
              }
            }),
      );
    } on _StaleConnectionAttempt {
      return;
    } on Object catch (error) {
      if (_isCurrent(tab.id, token)) {
        runtime.writeTerminal(
          pane.sessionId,
          'Connection failed: ${_failureFrom(error).message}\r\n',
        );
        _markTerminalPaneFailed(tab.id, paneIndex, error);
      }
    }
  }

  Future<void> _connectLocalTerminal(
    WorkspaceTabState tab,
    int token, {
    bool preserveReconnectAttempts = false,
  }) async {
    if (tab.content is! LocalTerminalTabContent) {
      return;
    }
    final sessionId = _sessionIdOf(tab.content);
    final runtime = ref.read(workspaceRuntimeRegistryProvider);
    try {
      _replaceTab(
        tab.copyWith(
          lifecycle: SessionLifecycleState.connecting,
          clearFailure: true,
          lastActivityAt: DateTime.now(),
        ),
      );
      final shell = await ref.read(localTerminalServiceProvider).openShell();
      _ensureCurrent(tab.id, token);
      runtime.attachTerminal(sessionId: sessionId, session: shell);
      _replaceTab(
        _currentTab(tab.id).copyWith(
          lifecycle: SessionLifecycleState.connected,
          clearFailure: true,
          lastActivityAt: DateTime.now(),
        ),
      );
      if (preserveReconnectAttempts) {
        _clearReconnectTimer(tab.id);
      } else {
        _clearReconnectState(tab.id);
      }
      unawaited(
        shell.done
            .then((_) {
              if (_isCurrent(tab.id, token)) {
                markDisconnected(tab.id);
              }
            })
            .catchError((Object error) {
              if (_isCurrent(tab.id, token)) {
                _markFailed(tab.id, error);
              }
            }),
      );
    } on _StaleConnectionAttempt {
      return;
    } on Object catch (error) {
      if (_isCurrent(tab.id, token)) {
        runtime.writeTerminal(
          sessionId,
          'Local terminal failed: ${_failureFrom(error).message}\r\n',
        );
        _markFailed(tab.id, error);
      }
    }
  }

  Future<void> _connectLocalTerminalPane(
    WorkspaceTabState tab,
    int paneIndex,
    int token,
  ) async {
    final content = tab.content;
    if (content is! TerminalTabContent) {
      return;
    }
    final pane = content.panes[paneIndex];
    final runtime = ref.read(workspaceRuntimeRegistryProvider);
    try {
      _setTerminalPaneLifecycle(
        tab.id,
        paneIndex,
        SessionLifecycleState.connecting,
        clearFailure: true,
      );
      final shell = await ref.read(localTerminalServiceProvider).openShell();
      _ensureCurrent(tab.id, token);
      runtime.attachTerminal(sessionId: pane.sessionId, session: shell);
      _setTerminalPaneLifecycle(
        tab.id,
        paneIndex,
        SessionLifecycleState.connected,
        clearFailure: true,
      );
      unawaited(
        shell.done
            .then((_) {
              if (_isCurrent(tab.id, token)) {
                _markTerminalPaneDisconnected(tab.id, paneIndex);
              }
            })
            .catchError((Object error) {
              if (_isCurrent(tab.id, token)) {
                _markTerminalPaneFailed(tab.id, paneIndex, error);
              }
            }),
      );
    } on _StaleConnectionAttempt {
      return;
    } on Object catch (error) {
      if (_isCurrent(tab.id, token)) {
        runtime.writeTerminal(
          pane.sessionId,
          'Local terminal failed: ${_failureFrom(error).message}\r\n',
        );
        _markTerminalPaneFailed(tab.id, paneIndex, error);
      }
    }
  }

  void _replaceTab(WorkspaceTabState tab) {
    if (!ref.mounted) {
      return;
    }
    state = state.copyWith(
      tabs: [
        for (final existing in state.tabs)
          if (existing.id == tab.id) tab else existing,
      ],
    );
  }

  WorkspaceTabState _currentTab(WorkspaceTabId tabId) {
    if (!ref.mounted) {
      throw _StaleConnectionAttempt();
    }
    final tab = state.tabs
        .where((candidate) => candidate.id == tabId)
        .firstOrNull;
    if (tab == null) {
      throw _StaleConnectionAttempt();
    }
    return tab;
  }

  void _markFailed(WorkspaceTabId tabId, Object error) {
    if (!ref.mounted) {
      return;
    }
    final tab = state.tabs
        .where((candidate) => candidate.id == tabId)
        .firstOrNull;
    if (tab == null) {
      return;
    }
    _replaceTab(
      tab.copyWith(
        lifecycle: SessionLifecycleState.failed,
        failure: _failureFrom(error),
        lastActivityAt: DateTime.now(),
      ),
    );
  }

  void _markTerminalPaneDisconnected(WorkspaceTabId tabId, int paneIndex) {
    _setTerminalPaneLifecycle(
      tabId,
      paneIndex,
      SessionLifecycleState.disconnected,
      failure: const AppFailure(
        code: 'session.disconnected',
        message: 'Connection interrupted. Reconnect starts a new session.',
      ),
    );
  }

  void _markTerminalPaneFailed(
    WorkspaceTabId tabId,
    int paneIndex,
    Object error,
  ) {
    _setTerminalPaneLifecycle(
      tabId,
      paneIndex,
      SessionLifecycleState.failed,
      failure: _failureFrom(error),
    );
  }

  void _setTerminalPaneLifecycle(
    WorkspaceTabId tabId,
    int paneIndex,
    SessionLifecycleState lifecycle, {
    AppFailure? failure,
    bool clearFailure = false,
  }) {
    if (!ref.mounted) {
      return;
    }
    final tab = state.tabs
        .where((candidate) => candidate.id == tabId)
        .firstOrNull;
    final content = tab?.content;
    if (tab == null ||
        content is! TerminalTabContent ||
        paneIndex >= content.panes.length) {
      return;
    }
    final panes = [...content.panes];
    panes[paneIndex] = panes[paneIndex].copyWith(
      lifecycle: lifecycle,
      failure: failure,
      clearFailure: clearFailure,
    );
    final nextContent = content.copyWith(panes: panes);
    _replaceTab(
      tab.copyWith(
        content: nextContent,
        lifecycle: _aggregateLifecycle(nextContent),
        failure: _aggregateFailure(nextContent),
        lastActivityAt: DateTime.now(),
      ),
    );
  }

  WorkspaceTabState _copyTerminalTabLifecycle(
    WorkspaceTabState tab,
    SessionLifecycleState lifecycle, {
    bool clearFailure = false,
  }) {
    final content = tab.content;
    if (content is! TerminalTabContent) {
      return tab.copyWith(lifecycle: lifecycle, clearFailure: clearFailure);
    }
    final panes = [
      for (final pane in content.panes)
        pane.copyWith(lifecycle: lifecycle, clearFailure: clearFailure),
    ];
    final nextContent = content.copyWith(panes: panes);
    return tab.copyWith(
      content: nextContent,
      lifecycle: _aggregateLifecycle(nextContent),
      failure: _aggregateFailure(nextContent),
      clearFailure: clearFailure,
    );
  }

  SessionLifecycleState _aggregateLifecycle(TerminalTabContent content) {
    final lifecycles = content.panes.map((pane) => pane.lifecycle).toSet();
    if (lifecycles.every((value) => value == SessionLifecycleState.connected)) {
      return SessionLifecycleState.connected;
    }
    if (lifecycles.contains(SessionLifecycleState.failed)) {
      return SessionLifecycleState.failed;
    }
    if (lifecycles.contains(SessionLifecycleState.disconnected)) {
      return SessionLifecycleState.disconnected;
    }
    if (lifecycles.contains(SessionLifecycleState.reconnecting)) {
      return SessionLifecycleState.reconnecting;
    }
    if (lifecycles.contains(SessionLifecycleState.connecting)) {
      return SessionLifecycleState.connecting;
    }
    return content.primaryPane.lifecycle;
  }

  AppFailure? _aggregateFailure(TerminalTabContent content) {
    return content.activePaneState?.failure ??
        content.panes
            .map((pane) => pane.failure)
            .firstWhere((failure) => failure != null, orElse: () => null);
  }

  Future<void> _closeTabSessions(WorkspaceTabState tab) async {
    final sessionIds = switch (tab.content) {
      TerminalTabContent(:final panes) => [
        for (final pane in panes) pane.sessionId,
      ],
      SftpTabContent(:final sessionId) => [sessionId],
      LocalTerminalTabContent(:final sessionId) => [sessionId],
    };
    for (final sessionId in sessionIds) {
      await ref.read(workspaceRuntimeRegistryProvider).closeSession(sessionId);
    }
  }

  AppFailure _failureFrom(Object error) {
    return switch (error) {
      ConnectionProfileResolutionException(:final code, :final message) =>
        AppFailure(code: code, message: message),
      UnsupportedSshAuthException(:final code, :final message) => AppFailure(
        code: code,
        message: message,
      ),
      LocalTerminalException(:final code, :final message) => AppFailure(
        code: code,
        message: message,
      ),
      _ => AppFailure(
        code: 'connection.failed',
        message: 'Connection failed.',
        diagnostic: error.toString(),
      ),
    };
  }

  int _nextConnectionToken(WorkspaceTabId tabId) {
    final token = (_connectionTokens[tabId] ?? 0) + 1;
    _connectionTokens[tabId] = token;
    return token;
  }

  bool _isCurrent(WorkspaceTabId tabId, int token) {
    if (!ref.mounted) {
      return false;
    }
    return _connectionTokens[tabId] == token &&
        state.tabs.any((tab) => tab.id == tabId);
  }

  void _ensureCurrent(WorkspaceTabId tabId, int token) {
    if (!_isCurrent(tabId, token)) {
      throw _StaleConnectionAttempt();
    }
  }

  Future<void> _runStartupCommands(
    SshShellSession shell,
    List<String> commands,
  ) async {
    for (final command in commands) {
      final trimmed = command.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      await shell.write(utf8.encode('$command\n'));
    }
  }
}

String _ensureTrailingNewline(String text) {
  return text.endsWith('\n') || text.endsWith('\r') ? text : '$text\n';
}

SessionId _sessionIdOf(WorkspaceTabContent content) {
  return switch (content) {
    TerminalTabContent(:final primaryPane) => primaryPane.sessionId,
    SftpTabContent(:final sessionId) => sessionId,
    LocalTerminalTabContent(:final sessionId) => sessionId,
  };
}

String _sftpTitle(String currentTitle, String path) {
  final hostName = _baseTabTitle(currentTitle);
  final normalized = _normalizeRemotePath(path);
  return '$hostName $normalized';
}

String _baseTabTitle(String title) {
  return title.split(' /').first.trim();
}

String _normalizeRemotePath(String path) {
  if (path.trim().isEmpty) {
    return '/';
  }
  final segments = <String>[];
  for (final segment in path.split('/')) {
    if (segment.isEmpty || segment == '.') {
      continue;
    }
    if (segment == '..') {
      if (segments.isNotEmpty) {
        segments.removeLast();
      }
      continue;
    }
    segments.add(segment);
  }
  return '/${segments.join('/')}';
}

class _StaleConnectionAttempt implements Exception {}
