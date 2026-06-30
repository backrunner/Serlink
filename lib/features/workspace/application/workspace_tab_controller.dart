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
import '../../terminal/data/file_selector_terminal_zmodem_transfer_handler.dart';
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
    diagnosticLogger: ref.watch(offlineDiagnosticLoggerProvider),
  );
});

final localTerminalServiceProvider = Provider<LocalTerminalService>((ref) {
  return const FlutterPtyLocalTerminalService();
});

final workspaceRuntimeRegistryProvider = Provider<WorkspaceRuntimeRegistry>((
  ref,
) {
  final capabilities = ref.watch(platformCapabilitiesProvider);
  final registry = WorkspaceRuntimeRegistry(
    confirmMultilinePaste: ref
        .watch(securityModalServiceProvider)
        .confirmMultilinePaste,
    zmodemTransferHandler: capabilities.terminalZmodemTransfers
        ? const FileSelectorTerminalZModemTransferHandler()
        : null,
  );
  ref.onDispose(() {
    unawaited(registry.dispose());
  });
  return registry;
});

class WorkspaceTabController extends Notifier<WorkspaceState> {
  static const _uuid = Uuid();
  static const _backgroundFailure = AppFailure(
    code: 'session.backgrounded',
    message:
        'Session was disconnected when Serlink entered the background. Reconnect starts a new session.',
  );
  final Map<WorkspaceTabId, int> _connectionTokens = {};
  final Map<SessionId, int> _paneConnectionTokens = {};
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
      _paneConnectionTokens.clear();
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

  Future<void> openTerminal(HostSummary host) async {
    final reusableTab = state.tabs
        .where(
          (tab) =>
              tab.hostId == host.id &&
              tab.content is TerminalTabContent &&
              _canReuseFailedTerminalTab(tab),
        )
        .firstOrNull;
    if (reusableTab != null) {
      await _reuseFailedTerminalTab(reusableTab, host);
      return;
    }
    final hostSettings = await _readTerminalDisplaySettingsForHost(host.id);
    final effectiveSettings =
        hostSettings ?? await _readGlobalTerminalDisplaySettings();
    final sessionId = _newSessionId();
    ref
        .read(workspaceRuntimeRegistryProvider)
        .createTerminal(
          sessionId: sessionId,
          maxLines: effectiveSettings.scrollbackLines,
        );
    final tab = _open(
      hostId: host.id,
      title: host.displayName,
      sftpDefaultDirectory: host.sftpDefaultDirectory,
      content: TerminalTabContent(
        panes: [
          TerminalPaneState(
            sessionId: sessionId,
            title: host.displayName,
            lifecycle: SessionLifecycleState.resolvingProfile,
            endpoint: TerminalPaneEndpoint.remote(
              hostId: host.id,
              sftpDefaultDirectory: _normalizeRemotePath(
                host.sftpDefaultDirectory,
              ),
            ),
            displaySettings: hostSettings,
          ),
        ],
      ),
      lifecycle: SessionLifecycleState.resolvingProfile,
      switchArea: WorkspaceArea.sessions,
    );
    unawaited(_connect(tab, _nextConnectionToken(tab.id)));
  }

  bool _canReuseFailedTerminalTab(WorkspaceTabState tab) {
    final content = tab.content;
    if (tab.lifecycle != SessionLifecycleState.failed ||
        content is! TerminalTabContent ||
        content.panes.length != 1) {
      return false;
    }
    return !ref
        .read(workspaceRuntimeRegistryProvider)
        .hasAttachedTerminal(content.primaryPane.sessionId);
  }

  Future<void> _reuseFailedTerminalTab(
    WorkspaceTabState tab,
    HostSummary host,
  ) async {
    final hostSettings = await _readTerminalDisplaySettingsForHost(host.id);
    final effectiveSettings =
        hostSettings ?? await _readGlobalTerminalDisplaySettings();
    final current = state.tabs
        .where((candidate) => candidate.id == tab.id)
        .firstOrNull;
    if (current == null || !_canReuseFailedTerminalTab(current)) {
      return;
    }
    final content = current.content as TerminalTabContent;
    final pane = content.primaryPane;
    final sessionId = _newSessionId();
    final runtime = ref.read(workspaceRuntimeRegistryProvider);
    runtime.createTerminal(
      sessionId: sessionId,
      maxLines: effectiveSettings.scrollbackLines,
    );

    final retrying = current.copyWith(
      title: host.displayName,
      sftpDefaultDirectory: _normalizeRemotePath(host.sftpDefaultDirectory),
      content: TerminalTabContent(
        panes: [
          TerminalPaneState(
            sessionId: sessionId,
            title: host.displayName,
            lifecycle: SessionLifecycleState.resolvingProfile,
            endpoint: TerminalPaneEndpoint.remote(
              hostId: host.id,
              sftpDefaultDirectory: _normalizeRemotePath(
                host.sftpDefaultDirectory,
              ),
            ),
            displaySettings: hostSettings,
          ),
        ],
      ),
      lifecycle: SessionLifecycleState.resolvingProfile,
      clearFailure: true,
      lastActivityAt: DateTime.now(),
    );
    _replaceTab(retrying);
    unawaited(runtime.discardSession(pane.sessionId));
    state = state.copyWith(
      area: WorkspaceArea.sessions,
      activeTabId: retrying.id,
    );
    unawaited(_connect(retrying, _nextConnectionToken(retrying.id)));
  }

  Future<void> openTerminalFromTab(WorkspaceTabId tabId) async {
    final source = state.tabs
        .where((candidate) => candidate.id == tabId)
        .firstOrNull;
    final hostId = source?.hostId;
    if (source == null || hostId == null) {
      return;
    }
    final title = _baseTabTitle(source.title);
    final hostSettings = await _readTerminalDisplaySettingsForHost(hostId);
    final effectiveSettings =
        hostSettings ?? await _readGlobalTerminalDisplaySettings();
    final sessionId = _newSessionId();
    ref
        .read(workspaceRuntimeRegistryProvider)
        .createTerminal(
          sessionId: sessionId,
          maxLines: effectiveSettings.scrollbackLines,
        );
    final tab = _open(
      hostId: hostId,
      title: title,
      sftpDefaultDirectory: source.sftpDefaultDirectory,
      content: TerminalTabContent(
        panes: [
          TerminalPaneState(
            sessionId: sessionId,
            title: title,
            lifecycle: SessionLifecycleState.resolvingProfile,
            endpoint: TerminalPaneEndpoint.remote(
              hostId: hostId,
              sftpDefaultDirectory: _normalizeRemotePath(
                source.sftpDefaultDirectory,
              ),
            ),
            displaySettings: hostSettings,
          ),
        ],
      ),
      lifecycle: SessionLifecycleState.resolvingProfile,
      switchArea: WorkspaceArea.sessions,
    );
    unawaited(_connect(tab, _nextConnectionToken(tab.id)));
  }

  void openSftp(HostSummary host) {
    final rootPath = _normalizeRemotePath(host.sftpDefaultDirectory);
    final sessionId = _newSessionId();
    final tab = _open(
      hostId: host.id,
      title: _sftpTitle(host.displayName, rootPath),
      sftpDefaultDirectory: rootPath,
      content: SftpTabContent(
        sessionId: sessionId,
        currentPath: rootPath,
        rootPath: rootPath,
      ),
      lifecycle: SessionLifecycleState.resolvingProfile,
      switchArea: WorkspaceArea.sessions,
    );
    unawaited(_connect(tab, _nextConnectionToken(tab.id)));
  }

  void openSftpFromTab(WorkspaceTabId tabId) {
    final source = state.tabs
        .where((candidate) => candidate.id == tabId)
        .firstOrNull;
    if (source == null) {
      return;
    }
    final content = source.content;
    if (content is TerminalTabContent || content is LocalTerminalTabContent) {
      openSftpFromTerminalPane(tabId, _activePaneIndexOf(content));
      return;
    }
    final hostId = source.hostId;
    if (hostId == null) {
      return;
    }
    final rootPath = _normalizeRemotePath(source.sftpDefaultDirectory);
    final sessionId = _newSessionId();
    final tab = _open(
      hostId: hostId,
      title: _sftpTitle(_baseTabTitle(source.title), rootPath),
      sftpDefaultDirectory: rootPath,
      content: SftpTabContent(
        sessionId: sessionId,
        currentPath: rootPath,
        rootPath: rootPath,
      ),
      lifecycle: SessionLifecycleState.resolvingProfile,
      switchArea: WorkspaceArea.sessions,
    );
    unawaited(_connect(tab, _nextConnectionToken(tab.id)));
  }

  void openSftpFromTerminalPane(WorkspaceTabId tabId, int paneIndex) {
    final source = state.tabs
        .where((candidate) => candidate.id == tabId)
        .firstOrNull;
    final content = source?.content;
    final panes = content == null ? null : _terminalPanesOf(content);
    if (source == null || content == null || panes == null || panes.isEmpty) {
      return;
    }
    final normalizedIndex = paneIndex.clamp(0, panes.length - 1);
    final pane = _paneWithEndpoint(source, normalizedIndex);
    final endpoint = pane.endpoint;
    final hostId = endpoint?.hostId ?? source.hostId;
    if (hostId == null || endpoint?.isLocal == true) {
      return;
    }
    final rootPath = _normalizeRemotePath(
      endpoint?.sftpDefaultDirectory ?? source.sftpDefaultDirectory,
    );
    final sessionId = _newSessionId();
    final tab = _open(
      hostId: hostId,
      title: _sftpTitle(_baseTabTitle(pane.title), rootPath),
      sftpDefaultDirectory: rootPath,
      content: SftpTabContent(
        sessionId: sessionId,
        currentPath: rootPath,
        rootPath: rootPath,
      ),
      lifecycle: SessionLifecycleState.resolvingProfile,
      switchArea: WorkspaceArea.sessions,
    );
    unawaited(_connect(tab, _nextConnectionToken(tab.id)));
  }

  Future<void> openTerminalAndSftp(HostSummary host) async {
    await openTerminal(host);
    openSftp(host);
  }

  Future<void> openLocalTerminal() async {
    if (!ref.read(platformCapabilitiesProvider).localTerminal) {
      return;
    }
    final settings = await _readGlobalTerminalDisplaySettings();
    final sessionId = _newSessionId();
    ref
        .read(workspaceRuntimeRegistryProvider)
        .createTerminal(
          sessionId: sessionId,
          maxLines: settings.scrollbackLines,
        );
    final tab = _open(
      hostId: null,
      title: 'Local Shell',
      content: LocalTerminalTabContent(
        panes: [
          TerminalPaneState(
            sessionId: sessionId,
            title: 'Local Shell',
            lifecycle: SessionLifecycleState.connecting,
            endpoint: const TerminalPaneEndpoint.local(),
          ),
        ],
      ),
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

  void reconnectTerminalPane(WorkspaceTabId tabId, int paneIndex) {
    final tab = state.tabs
        .where((candidate) => candidate.id == tabId)
        .firstOrNull;
    final content = tab?.content;
    final panes = content == null ? null : _terminalPanesOf(content);
    if (tab == null || content == null || panes == null || panes.isEmpty) {
      return;
    }
    final normalizedIndex = paneIndex.clamp(0, panes.length - 1);
    final pane = _paneWithEndpoint(tab, normalizedIndex);
    final endpoint = pane.endpoint;
    final lifecycle = endpoint?.isLocal == true
        ? SessionLifecycleState.connecting
        : SessionLifecycleState.reconnecting;
    _setTerminalPaneLifecycle(
      tab.id,
      normalizedIndex,
      lifecycle,
      clearFailure: true,
    );
    final reconnecting = _currentTab(tab.id);
    state = state.copyWith(activeTabId: tab.id);
    unawaited(_restartTerminalPane(reconnecting, normalizedIndex));
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
      if (!ref.read(platformCapabilitiesProvider).localTerminal) {
        return;
      }
      final token = _nextConnectionToken(tab.id);
      _invalidateTerminalPaneConnections(tab);
      final reconnecting = tab.copyWith(
        lifecycle: SessionLifecycleState.reconnecting,
        clearFailure: true,
        lastActivityAt: DateTime.now(),
      );
      _replaceTab(reconnecting);
      state = state.copyWith(activeTabId: tabId);
      unawaited(
        _restartTabSessions(tab, reconnecting, token, automatic: automatic),
      );
      return;
    }
    final token = _nextConnectionToken(tab.id);
    _invalidateTerminalPaneConnections(tab);
    final reconnecting = _copyTerminalTabLifecycle(
      tab,
      SessionLifecycleState.reconnecting,
      clearFailure: true,
    );
    _replaceTab(reconnecting.copyWith(lastActivityAt: DateTime.now()));
    state = state.copyWith(activeTabId: tabId);
    unawaited(
      _restartTabSessions(tab, reconnecting, token, automatic: automatic),
    );
  }

  Future<void> _restartTabSessions(
    WorkspaceTabState closingTab,
    WorkspaceTabState reconnecting,
    int token, {
    required bool automatic,
  }) async {
    await _closeTabSessions(closingTab);
    if (!_isCurrent(reconnecting.id, token)) {
      return;
    }
    if (reconnecting.content is LocalTerminalTabContent) {
      await _connectLocalTerminal(
        reconnecting,
        token,
        preserveReconnectAttempts: automatic,
      );
      return;
    }
    await _connect(reconnecting, token, preserveReconnectAttempts: automatic);
  }

  Future<void> _restartTerminalPane(
    WorkspaceTabState tab,
    int paneIndex,
  ) async {
    final panes = _terminalPanesOf(tab.content);
    if (panes == null || paneIndex >= panes.length) {
      return;
    }
    final sessionId = panes[paneIndex].sessionId;
    _nextPaneConnectionToken(sessionId);
    await ref.read(workspaceRuntimeRegistryProvider).closeSession(sessionId);
    final location = _paneLocationForSession(sessionId);
    if (location == null) {
      return;
    }
    final currentTab = _currentTab(location.tabId);
    final currentPanes = _terminalPanesOf(currentTab.content);
    if (currentPanes == null || location.paneIndex >= currentPanes.length) {
      return;
    }
    final pane = _paneWithEndpoint(currentTab, location.paneIndex);
    final token = _nextPaneConnectionToken(sessionId);
    if (_paneUsesLocalShell(currentTab.content, pane)) {
      await _connectLocalTerminalPane(currentTab, location.paneIndex, token);
    } else {
      await _connectTerminalPane(currentTab, location.paneIndex, token);
    }
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
    final rootPath = _normalizeRemotePath(content.rootPath);
    final nextPath = _clampRemotePathToRoot(
      _normalizeRemotePath(path),
      rootPath,
    );
    _replaceTab(
      tab.copyWith(
        title: _sftpTitle(tab.title, nextPath),
        content: SftpTabContent(
          sessionId: content.sessionId,
          currentPath: nextPath,
          rootPath: rootPath,
        ),
        lastActivityAt: DateTime.now(),
      ),
    );
  }

  void setSftpRootDirectory(WorkspaceTabId tabId, String path) {
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
    final rootPath = _normalizeRemotePath(path);
    _replaceTab(
      tab.copyWith(
        title: _sftpTitle(tab.title, rootPath),
        content: SftpTabContent(
          sessionId: content.sessionId,
          currentPath: rootPath,
          rootPath: rootPath,
        ),
        sftpDefaultDirectory: rootPath,
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

  void suspendForBackground() {
    final capabilities = ref.read(platformCapabilitiesProvider);
    if (!capabilities.suspendSessionsOnBackground) {
      return;
    }
    final runtime = ref.read(workspaceRuntimeRegistryProvider);
    final tabsToClose = <WorkspaceTabState>[];
    final updatedTabs = <WorkspaceTabState>[];
    for (final tab in state.tabs) {
      if (!_tabHasLiveSessions(tab)) {
        updatedTabs.add(tab);
        continue;
      }
      tabsToClose.add(tab);
      _clearReconnectState(tab.id);
      _connectionTokens.remove(tab.id);
      final panes = _terminalPanesOf(tab.content);
      if (panes != null) {
        for (final pane in panes) {
          _paneConnectionTokens.remove(pane.sessionId);
        }
      }
      _writeBackgroundNotice(runtime, tab);
      updatedTabs.add(_backgroundSuspendedTab(tab));
    }
    if (tabsToClose.isEmpty) {
      return;
    }
    for (final tab in tabsToClose) {
      unawaited(_closeTabSessions(tab));
    }
    state = state.copyWith(tabs: updatedTabs);
  }

  void saveTerminalDisplaySettingsForHost(
    WorkspaceTabId tabId,
    TerminalDisplaySettings settings, {
    int? paneIndex,
  }) {
    final tab = state.tabs
        .where((candidate) => candidate.id == tabId)
        .firstOrNull;
    if (tab == null) {
      return;
    }
    final hostId = _hostIdForTerminalPane(tab, paneIndex);
    if (hostId == null) {
      return;
    }
    _replaceTerminalDisplaySettings(tabId, settings, hostId: hostId);
    unawaited(_saveTerminalDisplaySettingsForHost(hostId, settings));
  }

  void resetTerminalDisplaySettingsForHost(
    WorkspaceTabId tabId, {
    int? paneIndex,
  }) {
    final tab = state.tabs
        .where((candidate) => candidate.id == tabId)
        .firstOrNull;
    if (tab == null) {
      return;
    }
    final hostId = _hostIdForTerminalPane(tab, paneIndex);
    if (hostId == null) {
      return;
    }
    _replaceTerminalDisplaySettings(tabId, null, clear: true, hostId: hostId);
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
    final panes = content == null ? null : _terminalPanesOf(content);
    final layout = content == null ? null : _terminalLayoutOf(content);
    if (tab == null ||
        content == null ||
        panes == null ||
        panes.isEmpty ||
        layout == null) {
      return;
    }
    final activePane = _activePaneIndexOf(content).clamp(0, panes.length - 1);
    final sessionId = _newSessionId();
    final paneIndex = panes.length;
    final sourcePane = _paneWithEndpoint(tab, activePane);
    final paneTitle = _baseTabTitle(sourcePane.title);
    final endpoint = sourcePane.endpoint;
    final effectiveSettings =
        sourcePane.displaySettings ?? _globalTerminalDisplaySettingsSnapshot();
    ref
        .read(workspaceRuntimeRegistryProvider)
        .createTerminal(
          sessionId: sessionId,
          maxLines: effectiveSettings.scrollbackLines,
        );
    final connectLocal = _paneUsesLocalShell(content, sourcePane);
    final nextLayout = layout.replaceLeaf(
      activePane,
      TerminalPaneSplit(
        axis: axis,
        first: TerminalPaneLeaf(activePane),
        second: TerminalPaneLeaf(paneIndex),
      ),
    );
    final next = _copyTerminalPaneContent(
      content,
      panes: [
        ...panes,
        TerminalPaneState(
          sessionId: sessionId,
          title: paneTitle,
          lifecycle: connectLocal
              ? SessionLifecycleState.connecting
              : SessionLifecycleState.resolvingProfile,
          endpoint: endpoint,
          displaySettings: sourcePane.displaySettings,
        ),
      ],
      layout: nextLayout,
      activePane: paneIndex,
    );
    final updatedTab = tab.copyWith(
      content: next,
      lifecycle: _aggregateLifecycle(next),
      lastActivityAt: DateTime.now(),
    );
    _replaceTab(updatedTab);
    final paneToken = _nextPaneConnectionToken(sessionId);
    if (connectLocal) {
      unawaited(_connectLocalTerminalPane(updatedTab, paneIndex, paneToken));
    } else {
      unawaited(_connectTerminalPane(updatedTab, paneIndex, paneToken));
    }
  }

  void disableTerminalSplit(WorkspaceTabId tabId) {
    final tab = state.tabs
        .where((candidate) => candidate.id == tabId)
        .firstOrNull;
    final content = tab?.content;
    final panes = content == null ? null : _terminalPanesOf(content);
    if (tab == null || content == null || panes == null || panes.isEmpty) {
      return;
    }
    if (panes.length > 1) {
      for (final pane in panes.skip(1)) {
        _paneConnectionTokens.remove(pane.sessionId);
        unawaited(
          ref
              .read(workspaceRuntimeRegistryProvider)
              .closeSession(pane.sessionId),
        );
      }
    }
    _replaceTab(
      tab.copyWith(
        content: _copyTerminalPaneContent(
          content,
          panes: [panes.first],
          layout: const TerminalPaneLeaf(0),
          activePane: 0,
        ),
        lifecycle: panes.first.lifecycle,
        failure: panes.first.failure,
        lastActivityAt: DateTime.now(),
      ),
    );
  }

  void setTerminalSplitAxis(WorkspaceTabId tabId, Axis axis) {
    final tab = state.tabs
        .where((candidate) => candidate.id == tabId)
        .firstOrNull;
    final content = tab?.content;
    if (tab == null || content == null || _terminalPanesOf(content) == null) {
      return;
    }
    _replaceTab(
      tab.copyWith(
        content: _copyTerminalPaneContent(content, splitAxis: axis),
        lastActivityAt: DateTime.now(),
      ),
    );
  }

  void closeActiveTerminalPane(WorkspaceTabId tabId) {
    final tab = state.tabs
        .where((candidate) => candidate.id == tabId)
        .firstOrNull;
    final content = tab?.content;
    if (content == null) {
      return;
    }
    closeTerminalPane(tabId, _activePaneIndexOf(content));
  }

  void closeTerminalPane(WorkspaceTabId tabId, int paneIndex) {
    final tab = state.tabs
        .where((candidate) => candidate.id == tabId)
        .firstOrNull;
    final content = tab?.content;
    final panes = content == null ? null : _terminalPanesOf(content);
    final layout = content == null ? null : _terminalLayoutOf(content);
    if (tab == null ||
        content == null ||
        panes == null ||
        panes.length <= 1 ||
        layout == null) {
      return;
    }
    final normalizedIndex = paneIndex.clamp(0, panes.length - 1);
    final nextPanes = [...panes]..removeAt(normalizedIndex);
    final nextLayout =
        layout
            .removeLeaf(normalizedIndex)
            ?.reindexAfterRemoving(normalizedIndex) ??
        const TerminalPaneLeaf(0);
    final currentActive = _activePaneIndexOf(
      content,
    ).clamp(0, panes.length - 1);
    final nextActivePane = currentActive == normalizedIndex
        ? normalizedIndex.clamp(0, nextPanes.length - 1)
        : currentActive > normalizedIndex
        ? currentActive - 1
        : currentActive;
    _paneConnectionTokens.remove(panes[normalizedIndex].sessionId);
    unawaited(
      ref
          .read(workspaceRuntimeRegistryProvider)
          .closeSession(panes[normalizedIndex].sessionId),
    );
    final nextContent = _copyTerminalPaneContent(
      content,
      panes: nextPanes,
      layout: nextLayout,
      activePane: nextActivePane,
    );
    _replaceTab(
      tab.copyWith(
        content: nextContent,
        lifecycle: _aggregateLifecycle(nextContent),
        failure: _aggregateFailure(nextContent),
        lastActivityAt: DateTime.now(),
      ),
    );
  }

  void resizeTerminalSplit(
    WorkspaceTabId tabId,
    List<int> splitPath,
    double ratio,
  ) {
    final tab = state.tabs
        .where((candidate) => candidate.id == tabId)
        .firstOrNull;
    final content = tab?.content;
    final layout = content == null ? null : _terminalLayoutOf(content);
    if (tab == null || content == null || layout == null) {
      return;
    }
    _replaceTab(
      tab.copyWith(
        content: _copyTerminalPaneContent(
          content,
          layout: layout.updateSplitRatio(splitPath, ratio),
        ),
        lastActivityAt: DateTime.now(),
      ),
    );
  }

  void swapTerminalPanes(
    WorkspaceTabId tabId,
    int firstPaneIndex,
    int secondPaneIndex,
  ) {
    if (firstPaneIndex == secondPaneIndex) {
      return;
    }
    final tab = state.tabs
        .where((candidate) => candidate.id == tabId)
        .firstOrNull;
    final content = tab?.content;
    final panes = content == null ? null : _terminalPanesOf(content);
    final layout = content == null ? null : _terminalLayoutOf(content);
    if (tab == null ||
        content == null ||
        panes == null ||
        layout == null ||
        panes.isEmpty) {
      return;
    }
    final first = firstPaneIndex.clamp(0, panes.length - 1);
    final second = secondPaneIndex.clamp(0, panes.length - 1);
    if (first == second) {
      return;
    }
    _replaceTab(
      tab.copyWith(
        content: _copyTerminalPaneContent(
          content,
          layout: layout.swapLeafIndexes(first, second),
          activePane: second,
        ),
        lastActivityAt: DateTime.now(),
      ),
    );
  }

  void mergeSinglePaneTabIntoSplit({
    required WorkspaceTabId sourceTabId,
    required WorkspaceTabId targetTabId,
    required int targetPaneIndex,
    required Axis axis,
    required bool before,
  }) {
    if (sourceTabId == targetTabId) {
      return;
    }
    final sourceTab = state.tabs
        .where((candidate) => candidate.id == sourceTabId)
        .firstOrNull;
    final targetTab = state.tabs
        .where((candidate) => candidate.id == targetTabId)
        .firstOrNull;
    final sourceContent = sourceTab?.content;
    final targetContent = targetTab?.content;
    final sourcePanes = sourceContent == null
        ? null
        : _terminalPanesOf(sourceContent);
    final targetPanes = targetContent == null
        ? null
        : _terminalPanesOf(targetContent);
    final targetLayout = targetContent == null
        ? null
        : _terminalLayoutOf(targetContent);
    if (sourceTab == null ||
        targetTab == null ||
        sourceContent == null ||
        targetContent == null ||
        sourcePanes == null ||
        targetPanes == null ||
        targetLayout == null ||
        sourcePanes.length != 1 ||
        targetPanes.isEmpty) {
      return;
    }
    final sourcePane = _paneWithEndpoint(sourceTab, 0);
    final targetIndex = targetPaneIndex.clamp(0, targetPanes.length - 1);
    final insertedIndex = targetPanes.length;
    final nextPanes = [...targetPanes, sourcePane];
    final sourceLeaf = TerminalPaneLeaf(insertedIndex);
    final targetLeaf = TerminalPaneLeaf(targetIndex);
    final replacement = TerminalPaneSplit(
      axis: axis,
      first: before ? sourceLeaf : targetLeaf,
      second: before ? targetLeaf : sourceLeaf,
    );
    final nextLayout = targetLayout.replaceLeaf(targetIndex, replacement);
    final nextContent = _copyTerminalPaneContent(
      targetContent,
      panes: nextPanes,
      layout: nextLayout,
      activePane: insertedIndex,
    );
    final remaining = [
      for (final tab in state.tabs)
        if (tab.id == targetTabId)
          targetTab.copyWith(
            content: nextContent,
            lifecycle: _aggregateLifecycle(nextContent),
            failure: _aggregateFailure(nextContent),
            lastActivityAt: DateTime.now(),
          )
        else if (tab.id != sourceTabId)
          tab,
    ];
    state = state.copyWith(
      area: WorkspaceArea.sessions,
      tabs: remaining,
      activeTabId: targetTabId,
    );
    _clearReconnectState(sourceTabId);
    _connectionTokens.remove(sourceTabId);
  }

  void setActiveTerminalPane(WorkspaceTabId tabId, int paneIndex) {
    final tab = state.tabs
        .where((candidate) => candidate.id == tabId)
        .firstOrNull;
    final content = tab?.content;
    final panes = content == null ? null : _terminalPanesOf(content);
    if (tab == null || content == null || panes == null || panes.isEmpty) {
      return;
    }
    final normalizedIndex = paneIndex.clamp(0, panes.length - 1);
    _replaceTab(
      tab.copyWith(
        content: _copyTerminalPaneContent(content, activePane: normalizedIndex),
        lastActivityAt: DateTime.now(),
      ),
    );
  }

  bool insertIntoActiveTerminal(String text, {bool submit = false}) {
    final tab = state.activeTab;
    if (tab == null) {
      return false;
    }
    final activePaneState = switch (tab.content) {
      TerminalTabContent(:final activePaneState) => activePaneState,
      LocalTerminalTabContent(:final activePaneState) => activePaneState,
      SftpTabContent() => null,
    };
    if (activePaneState == null ||
        activePaneState.lifecycle != SessionLifecycleState.connected) {
      return false;
    }
    final payload = submit ? _ensureTrailingNewline(text) : text;
    final inserted = ref
        .read(workspaceRuntimeRegistryProvider)
        .sendTerminalInput(activePaneState.sessionId, payload);
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
      final panes = _terminalPanesOf(closingTab.content);
      if (panes != null) {
        for (final pane in panes) {
          _paneConnectionTokens.remove(pane.sessionId);
        }
      }
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

  Future<TerminalDisplaySettings?> _readTerminalDisplaySettingsForHost(
    HostId hostId,
  ) async {
    try {
      return await ref
          .read(terminalHostDisplaySettingsRepositoryProvider)
          .readForHost(hostId);
    } on Object {
      // Host-specific display settings are best effort. A locked vault or
      // malformed profile must never interrupt the connection attempt.
      return null;
    }
  }

  TerminalDisplaySettings _globalTerminalDisplaySettingsSnapshot() {
    return ref.read(terminalDisplaySettingsProvider).value ??
        const TerminalDisplaySettings();
  }

  Future<TerminalDisplaySettings> _readGlobalTerminalDisplaySettings() async {
    try {
      return await ref.read(terminalDisplaySettingsProvider.future);
    } on Object {
      return const TerminalDisplaySettings();
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
    HostId? hostId,
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
    final panes = _terminalPanesOf(content);
    if (panes == null) {
      return;
    }
    final nextPanes = [
      for (var index = 0; index < panes.length; index += 1)
        _terminalPaneMatchesHost(tab, index, hostId)
            ? panes[index].copyWith(
                displaySettings: settings,
                clearDisplaySettings: clear,
              )
            : panes[index],
    ];
    _replaceTab(
      tab.copyWith(
        content: _copyTerminalPaneContent(content, panes: nextPanes),
      ),
    );
  }

  HostId? _hostIdForTerminalPane(WorkspaceTabState tab, int? paneIndex) {
    final panes = _terminalPanesOf(tab.content);
    if (panes == null || panes.isEmpty) {
      return null;
    }
    final activeIndex = _activePaneIndexOf(tab.content);
    final normalizedIndex = (paneIndex ?? activeIndex).clamp(
      0,
      panes.length - 1,
    );
    final pane = _paneWithEndpoint(tab, normalizedIndex);
    if (pane.endpoint?.isLocal == true) {
      return null;
    }
    return pane.endpoint?.hostId ?? tab.hostId;
  }

  bool _terminalPaneMatchesHost(
    WorkspaceTabState tab,
    int paneIndex,
    HostId? hostId,
  ) {
    if (hostId == null) {
      return true;
    }
    final pane = _paneWithEndpoint(tab, paneIndex);
    return pane.endpoint?.hostId == hostId ||
        (pane.endpoint == null && tab.hostId == hostId);
  }

  bool _paneUsesLocalShell(
    WorkspaceTabContent content,
    TerminalPaneState pane,
  ) {
    if (pane.endpoint != null) {
      return pane.endpoint!.isLocal;
    }
    return content is LocalTerminalTabContent;
  }

  void _invalidateTerminalPaneConnections(WorkspaceTabState tab) {
    final panes = _terminalPanesOf(tab.content);
    if (panes == null) {
      return;
    }
    for (final pane in panes) {
      _nextPaneConnectionToken(pane.sessionId);
    }
  }

  List<TerminalPaneState>? _terminalPanesOf(WorkspaceTabContent content) {
    return switch (content) {
      TerminalTabContent(:final panes) => panes,
      LocalTerminalTabContent(:final panes) => panes,
      SftpTabContent() => null,
    };
  }

  TerminalPaneState? _activePaneStateOf(WorkspaceTabContent content) {
    return switch (content) {
      TerminalTabContent(:final activePaneState) => activePaneState,
      LocalTerminalTabContent(:final activePaneState) => activePaneState,
      SftpTabContent() => null,
    };
  }

  TerminalPaneState _paneWithEndpoint(WorkspaceTabState tab, int paneIndex) {
    final panes = _terminalPanesOf(tab.content);
    if (panes == null || panes.isEmpty) {
      throw StateError('Tab ${tab.id.value} does not contain terminal panes.');
    }
    final normalizedIndex = paneIndex.clamp(0, panes.length - 1);
    final pane = panes[normalizedIndex];
    if (pane.endpoint != null) {
      return pane;
    }
    final endpoint = switch (tab.content) {
      LocalTerminalTabContent() => const TerminalPaneEndpoint.local(),
      TerminalTabContent() when tab.hostId != null =>
        TerminalPaneEndpoint.remote(
          hostId: tab.hostId!,
          sftpDefaultDirectory: _normalizeRemotePath(tab.sftpDefaultDirectory),
        ),
      _ => null,
    };
    return endpoint == null ? pane : pane.copyWith(endpoint: endpoint);
  }

  int _activePaneIndexOf(WorkspaceTabContent content) {
    return switch (content) {
      TerminalTabContent(:final activePane) => activePane,
      LocalTerminalTabContent(:final activePane) => activePane,
      SftpTabContent() => 0,
    };
  }

  TerminalPaneLayout _terminalLayoutOf(WorkspaceTabContent content) {
    return switch (content) {
      TerminalTabContent(:final layout) => layout,
      LocalTerminalTabContent(:final layout) => layout,
      SftpTabContent() => const TerminalPaneLeaf(0),
    };
  }

  WorkspaceTabContent _copyTerminalPaneContent(
    WorkspaceTabContent content, {
    List<TerminalPaneState>? panes,
    TerminalPaneLayout? layout,
    Axis? splitAxis,
    int? activePane,
  }) {
    return switch (content) {
      TerminalTabContent() => content.copyWith(
        panes: panes,
        layout: layout,
        splitAxis: splitAxis,
        activePane: activePane,
      ),
      LocalTerminalTabContent() => content.copyWith(
        panes: panes,
        layout: layout,
        splitAxis: splitAxis,
        activePane: activePane,
      ),
      SftpTabContent() => content,
    };
  }

  WorkspaceTabState _open({
    required HostId? hostId,
    required String title,
    required WorkspaceTabContent content,
    required SessionLifecycleState lifecycle,
    required WorkspaceArea switchArea,
    String sftpDefaultDirectory = '/',
  }) {
    final now = DateTime.now();
    final tab = WorkspaceTabState(
      id: WorkspaceTabId(_uuid.v4()),
      hostId: hostId,
      title: title,
      content: content,
      lifecycle: lifecycle,
      sftpDefaultDirectory: _normalizeRemotePath(sftpDefaultDirectory),
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
            final currentTab = _currentTab(tab.id);
            final pane = _paneWithEndpoint(currentTab, paneIndex);
            final paneHostId = pane.endpoint?.hostId ?? hostId;
            final paneToken = _nextPaneConnectionToken(pane.sessionId);
            if (_paneUsesLocalShell(currentTab.content, pane)) {
              await _connectLocalTerminalPane(currentTab, paneIndex, paneToken);
              continue;
            }
            try {
              final profile = await ref
                  .read(connectionProfileResolverProvider)
                  .resolve(hostId: paneHostId, sessionId: pane.sessionId);
              _ensureOpenPaneCurrent(pane.sessionId, paneToken);
              _setTerminalPaneLifecycleByOpenSession(
                pane.sessionId,
                SessionLifecycleState.connecting,
                clearFailure: true,
              );
              final shell = await ref
                  .read(sshSessionServiceProvider)
                  .openShell(profile);
              _ensureOpenPaneCurrent(pane.sessionId, paneToken);
              runtime.attachTerminal(sessionId: pane.sessionId, session: shell);
              await _runStartupCommands(shell, profile.startupCommands);
              _setTerminalPaneLifecycleByOpenSession(
                pane.sessionId,
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
                      if (_isOpenPaneCurrent(pane.sessionId, paneToken)) {
                        _markTerminalPaneDisconnectedByOpenSession(
                          pane.sessionId,
                        );
                        if (_currentTerminalPaneCount(tab.id) == 1) {
                          _scheduleReconnect(
                            tabId: tab.id,
                            policy: profile.reconnectPolicy,
                          );
                        }
                      }
                    })
                    .catchError((Object error) {
                      if (_isOpenPaneCurrent(pane.sessionId, paneToken)) {
                        _markTerminalPaneFailedByOpenSession(
                          pane.sessionId,
                          error,
                        );
                      }
                    }),
              );
            } on _StaleConnectionAttempt {
              return;
            } on Object catch (error) {
              if (_isOpenPaneCurrent(pane.sessionId, paneToken)) {
                runtime.writeTerminal(
                  pane.sessionId,
                  'Connection failed: ${_failureFrom(error).message}\r\n',
                );
                _markTerminalPaneFailedByOpenSession(pane.sessionId, error);
              }
            }
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
    final content = tab.content;
    final panes = _terminalPanesOf(content);
    if (panes == null || paneIndex >= panes.length) {
      return;
    }
    final pane = _paneWithEndpoint(tab, paneIndex);
    if (_paneUsesLocalShell(content, pane)) {
      return;
    }
    final hostId = pane.endpoint?.hostId ?? tab.hostId;
    if (hostId == null) {
      return;
    }
    final runtime = ref.read(workspaceRuntimeRegistryProvider);
    try {
      final profile = await ref
          .read(connectionProfileResolverProvider)
          .resolve(hostId: hostId, sessionId: pane.sessionId);
      _ensureOpenPaneCurrent(pane.sessionId, token);
      _setTerminalPaneLifecycleByOpenSession(
        pane.sessionId,
        SessionLifecycleState.connecting,
        clearFailure: true,
      );
      final shell = await ref
          .read(sshSessionServiceProvider)
          .openShell(profile);
      _ensureOpenPaneCurrent(pane.sessionId, token);
      runtime.attachTerminal(sessionId: pane.sessionId, session: shell);
      await _runStartupCommands(shell, profile.startupCommands);
      _setTerminalPaneLifecycleByOpenSession(
        pane.sessionId,
        SessionLifecycleState.connected,
        clearFailure: true,
      );
      unawaited(
        shell.done
            .then((_) {
              if (_isOpenPaneCurrent(pane.sessionId, token)) {
                _markTerminalPaneDisconnectedByOpenSession(pane.sessionId);
              }
            })
            .catchError((Object error) {
              if (_isOpenPaneCurrent(pane.sessionId, token)) {
                _markTerminalPaneFailedByOpenSession(pane.sessionId, error);
              }
            }),
      );
    } on _StaleConnectionAttempt {
      return;
    } on Object catch (error) {
      if (_isOpenPaneCurrent(pane.sessionId, token)) {
        runtime.writeTerminal(
          pane.sessionId,
          'Connection failed: ${_failureFrom(error).message}\r\n',
        );
        _markTerminalPaneFailedByOpenSession(pane.sessionId, error);
      }
    }
  }

  Future<void> _connectLocalTerminal(
    WorkspaceTabState tab,
    int token, {
    bool preserveReconnectAttempts = false,
  }) async {
    final content = tab.content;
    if (content is! LocalTerminalTabContent) {
      return;
    }
    final runtime = ref.read(workspaceRuntimeRegistryProvider);
    try {
      final connecting = _copyTerminalTabLifecycle(
        tab,
        SessionLifecycleState.connecting,
        clearFailure: true,
      );
      _replaceTab(connecting.copyWith(lastActivityAt: DateTime.now()));
      for (
        var paneIndex = 0;
        paneIndex < content.panes.length;
        paneIndex += 1
      ) {
        final currentTab = _currentTab(tab.id);
        final pane = _paneWithEndpoint(currentTab, paneIndex);
        final paneToken = _nextPaneConnectionToken(pane.sessionId);
        if (!_paneUsesLocalShell(currentTab.content, pane)) {
          await _connectTerminalPane(currentTab, paneIndex, paneToken);
          continue;
        }
        try {
          final shell = await ref
              .read(localTerminalServiceProvider)
              .openShell();
          _ensureOpenPaneCurrent(pane.sessionId, paneToken);
          runtime.attachTerminal(sessionId: pane.sessionId, session: shell);
          _setTerminalPaneLifecycleByOpenSession(
            pane.sessionId,
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
                  if (_isOpenPaneCurrent(pane.sessionId, paneToken)) {
                    _markLocalTerminalPaneExitedByOpenSession(pane.sessionId);
                  }
                })
                .catchError((Object error) {
                  if (_isOpenPaneCurrent(pane.sessionId, paneToken)) {
                    _markLocalTerminalPaneFailedByOpenSession(
                      pane.sessionId,
                      error,
                    );
                  }
                }),
          );
        } on _StaleConnectionAttempt {
          return;
        } on Object catch (error) {
          if (_isOpenPaneCurrent(pane.sessionId, paneToken)) {
            runtime.writeTerminal(
              pane.sessionId,
              'Local terminal failed: ${_localTerminalFailureFrom(error).message}\r\n',
            );
            _markLocalTerminalPaneFailedByOpenSession(pane.sessionId, error);
          }
        }
      }
    } on _StaleConnectionAttempt {
      return;
    } on Object catch (error) {
      if (_isCurrent(tab.id, token)) {
        for (var i = 0; i < content.panes.length; i += 1) {
          runtime.writeTerminal(
            content.panes[i].sessionId,
            'Local terminal failed: ${_localTerminalFailureFrom(error).message}\r\n',
          );
          if (content.panes.length == 1) {
            _markLocalTerminalFailed(tab.id, error);
          } else {
            _markLocalTerminalPaneFailed(tab.id, i, error);
          }
        }
      }
    }
  }

  Future<void> _connectLocalTerminalPane(
    WorkspaceTabState tab,
    int paneIndex,
    int token,
  ) async {
    final content = tab.content;
    final panes = _terminalPanesOf(content);
    if (panes == null || paneIndex >= panes.length) {
      return;
    }
    final pane = _paneWithEndpoint(tab, paneIndex);
    if (!_paneUsesLocalShell(content, pane)) {
      return;
    }
    final runtime = ref.read(workspaceRuntimeRegistryProvider);
    try {
      _ensureOpenPaneCurrent(pane.sessionId, token);
      _setTerminalPaneLifecycleByOpenSession(
        pane.sessionId,
        SessionLifecycleState.connecting,
        clearFailure: true,
      );
      final shell = await ref.read(localTerminalServiceProvider).openShell();
      _ensureOpenPaneCurrent(pane.sessionId, token);
      runtime.attachTerminal(sessionId: pane.sessionId, session: shell);
      _setTerminalPaneLifecycleByOpenSession(
        pane.sessionId,
        SessionLifecycleState.connected,
        clearFailure: true,
      );
      unawaited(
        shell.done
            .then((_) {
              if (_isOpenPaneCurrent(pane.sessionId, token)) {
                _markLocalTerminalPaneExitedByOpenSession(pane.sessionId);
              }
            })
            .catchError((Object error) {
              if (_isOpenPaneCurrent(pane.sessionId, token)) {
                _markLocalTerminalPaneFailedByOpenSession(
                  pane.sessionId,
                  error,
                );
              }
            }),
      );
    } on _StaleConnectionAttempt {
      return;
    } on Object catch (error) {
      if (_isOpenPaneCurrent(pane.sessionId, token)) {
        runtime.writeTerminal(
          pane.sessionId,
          'Local terminal failed: ${_localTerminalFailureFrom(error).message}\r\n',
        );
        _markLocalTerminalPaneFailedByOpenSession(pane.sessionId, error);
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

  void _markLocalTerminalFailed(WorkspaceTabId tabId, Object error) {
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
        failure: _localTerminalFailureFrom(error),
        lastActivityAt: DateTime.now(),
      ),
    );
  }

  void _markLocalTerminalPaneExitedByOpenSession(SessionId sessionId) {
    final location = _paneLocationForSession(sessionId);
    if (location == null) {
      return;
    }
    _markLocalTerminalPaneExited(location.tabId, location.paneIndex);
  }

  void _markTerminalPaneDisconnectedByOpenSession(SessionId sessionId) {
    final location = _paneLocationForSession(sessionId);
    if (location == null) {
      return;
    }
    _markTerminalPaneDisconnected(location.tabId, location.paneIndex);
  }

  void _markTerminalPaneFailedByOpenSession(SessionId sessionId, Object error) {
    final location = _paneLocationForSession(sessionId);
    if (location == null) {
      return;
    }
    _markTerminalPaneFailed(location.tabId, location.paneIndex, error);
  }

  void _markLocalTerminalPaneFailedByOpenSession(
    SessionId sessionId,
    Object error,
  ) {
    final location = _paneLocationForSession(sessionId);
    if (location == null) {
      return;
    }
    _markLocalTerminalPaneFailed(location.tabId, location.paneIndex, error);
  }

  void _markLocalTerminalPaneExited(WorkspaceTabId tabId, int paneIndex) {
    _setTerminalPaneLifecycle(
      tabId,
      paneIndex,
      SessionLifecycleState.disconnected,
      failure: const AppFailure(
        code: 'local_terminal.exited',
        message: 'Local shell exited. Restart opens a new shell.',
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

  void _markLocalTerminalPaneFailed(
    WorkspaceTabId tabId,
    int paneIndex,
    Object error,
  ) {
    _setTerminalPaneLifecycle(
      tabId,
      paneIndex,
      SessionLifecycleState.failed,
      failure: _localTerminalFailureFrom(error),
    );
  }

  ({WorkspaceTabId tabId, int paneIndex})? _paneLocationForSession(
    SessionId sessionId,
  ) {
    if (!ref.mounted) {
      return null;
    }
    for (final tab in state.tabs) {
      final panes = _terminalPanesOf(tab.content);
      if (panes == null) {
        continue;
      }
      for (var index = 0; index < panes.length; index += 1) {
        if (panes[index].sessionId == sessionId) {
          return (tabId: tab.id, paneIndex: index);
        }
      }
    }
    return null;
  }

  int? _currentTerminalPaneCount(WorkspaceTabId tabId) {
    if (!ref.mounted) {
      return null;
    }
    final tab = state.tabs
        .where((candidate) => candidate.id == tabId)
        .firstOrNull;
    final content = tab?.content;
    return content == null ? null : _terminalPanesOf(content)?.length;
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
    final panes = content == null ? null : _terminalPanesOf(content);
    if (tab == null ||
        content == null ||
        panes == null ||
        paneIndex >= panes.length) {
      return;
    }
    final nextPanes = [...panes];
    nextPanes[paneIndex] = nextPanes[paneIndex].copyWith(
      lifecycle: lifecycle,
      failure: failure,
      clearFailure: clearFailure,
    );
    final nextContent = _copyTerminalPaneContent(content, panes: nextPanes);
    _replaceTab(
      tab.copyWith(
        content: nextContent,
        lifecycle: _aggregateLifecycle(nextContent),
        failure: _aggregateFailure(nextContent),
        lastActivityAt: DateTime.now(),
      ),
    );
  }

  void _setTerminalPaneLifecycleByOpenSession(
    SessionId sessionId,
    SessionLifecycleState lifecycle, {
    AppFailure? failure,
    bool clearFailure = false,
  }) {
    final location = _paneLocationForSession(sessionId);
    if (location == null) {
      return;
    }
    _setTerminalPaneLifecycle(
      location.tabId,
      location.paneIndex,
      lifecycle,
      failure: failure,
      clearFailure: clearFailure,
    );
  }

  WorkspaceTabState _copyTerminalTabLifecycle(
    WorkspaceTabState tab,
    SessionLifecycleState lifecycle, {
    bool clearFailure = false,
  }) {
    final content = tab.content;
    final panes = _terminalPanesOf(content);
    if (panes == null) {
      return tab.copyWith(lifecycle: lifecycle, clearFailure: clearFailure);
    }
    final nextPanes = [
      for (final pane in panes)
        pane.copyWith(lifecycle: lifecycle, clearFailure: clearFailure),
    ];
    final nextContent = _copyTerminalPaneContent(content, panes: nextPanes);
    return tab.copyWith(
      content: nextContent,
      lifecycle: _aggregateLifecycle(nextContent),
      failure: _aggregateFailure(nextContent),
      clearFailure: clearFailure,
    );
  }

  SessionLifecycleState _aggregateLifecycle(WorkspaceTabContent content) {
    final panes = _terminalPanesOf(content);
    if (panes == null || panes.isEmpty) {
      return SessionLifecycleState.idle;
    }
    final lifecycles = panes.map((pane) => pane.lifecycle).toSet();
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
    return panes.first.lifecycle;
  }

  AppFailure? _aggregateFailure(WorkspaceTabContent content) {
    final panes = _terminalPanesOf(content);
    if (panes == null) {
      return null;
    }
    return _activePaneStateOf(content)?.failure ??
        panes
            .map((pane) => pane.failure)
            .firstWhere((failure) => failure != null, orElse: () => null);
  }

  bool _tabHasLiveSessions(WorkspaceTabState tab) {
    return switch (tab.content) {
      TerminalTabContent(:final panes) ||
      LocalTerminalTabContent(
        :final panes,
      ) => panes.any((pane) => pane.lifecycle.keepsTerminalAlive),
      SftpTabContent() => tab.lifecycle.keepsTerminalAlive,
    };
  }

  WorkspaceTabState _backgroundSuspendedTab(WorkspaceTabState tab) {
    return switch (tab.content) {
      TerminalTabContent(:final panes) => _backgroundSuspendedTerminalTab(
        tab,
        tab.content,
        panes,
      ),
      LocalTerminalTabContent(:final panes) => _backgroundSuspendedTerminalTab(
        tab,
        tab.content,
        panes,
      ),
      SftpTabContent() => tab.copyWith(
        lifecycle: SessionLifecycleState.disconnected,
        failure: _backgroundFailure,
        lastActivityAt: DateTime.now(),
      ),
    };
  }

  WorkspaceTabState _backgroundSuspendedTerminalTab(
    WorkspaceTabState tab,
    WorkspaceTabContent content,
    List<TerminalPaneState> panes,
  ) {
    final nextContent = _copyTerminalPaneContent(
      content,
      panes: [
        for (final pane in panes)
          pane.lifecycle.keepsTerminalAlive
              ? pane.copyWith(
                  lifecycle: SessionLifecycleState.disconnected,
                  failure: _backgroundFailure,
                )
              : pane,
      ],
    );
    return tab.copyWith(
      content: nextContent,
      lifecycle: _aggregateLifecycle(nextContent),
      failure: _aggregateFailure(nextContent),
      lastActivityAt: DateTime.now(),
    );
  }

  void _writeBackgroundNotice(
    WorkspaceRuntimeRegistry runtime,
    WorkspaceTabState tab,
  ) {
    final panes = _terminalPanesOf(tab.content);
    if (panes == null) {
      return;
    }
    for (final pane in panes) {
      if (pane.lifecycle.keepsTerminalAlive) {
        runtime.writeTerminal(
          pane.sessionId,
          '\r\n${_backgroundFailure.message}\r\n',
        );
      }
    }
  }

  Future<void> _closeTabSessions(WorkspaceTabState tab) async {
    final sessionIds = switch (tab.content) {
      TerminalTabContent(:final panes) => [
        for (final pane in panes) pane.sessionId,
      ],
      SftpTabContent(:final sessionId) => [sessionId],
      LocalTerminalTabContent(:final panes) => [
        for (final pane in panes) pane.sessionId,
      ],
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

  AppFailure _localTerminalFailureFrom(Object error) {
    return switch (error) {
      LocalTerminalException(:final code, :final message) => AppFailure(
        code: code,
        message: message,
      ),
      _ => AppFailure(
        code: 'local_terminal.failed',
        message: 'Local terminal failed.',
        diagnostic: error.toString(),
      ),
    };
  }

  int _nextConnectionToken(WorkspaceTabId tabId) {
    final token = (_connectionTokens[tabId] ?? 0) + 1;
    _connectionTokens[tabId] = token;
    return token;
  }

  int _nextPaneConnectionToken(SessionId sessionId) {
    final token = (_paneConnectionTokens[sessionId] ?? 0) + 1;
    _paneConnectionTokens[sessionId] = token;
    return token;
  }

  bool _isCurrent(WorkspaceTabId tabId, int token) {
    if (!ref.mounted) {
      return false;
    }
    return _connectionTokens[tabId] == token &&
        state.tabs.any((tab) => tab.id == tabId);
  }

  bool _isOpenPaneCurrent(SessionId sessionId, int token) {
    if (!ref.mounted) {
      return false;
    }
    return _paneConnectionTokens[sessionId] == token &&
        _paneLocationForSession(sessionId) != null;
  }

  void _ensureCurrent(WorkspaceTabId tabId, int token) {
    if (!_isCurrent(tabId, token)) {
      throw _StaleConnectionAttempt();
    }
  }

  void _ensureOpenPaneCurrent(SessionId sessionId, int token) {
    if (!_isOpenPaneCurrent(sessionId, token)) {
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

String _clampRemotePathToRoot(String path, String rootPath) {
  final normalizedPath = _normalizeRemotePath(path);
  final normalizedRoot = _normalizeRemotePath(rootPath);
  if (normalizedRoot == '/' ||
      normalizedPath == normalizedRoot ||
      normalizedPath.startsWith('$normalizedRoot/')) {
    return normalizedPath;
  }
  return normalizedRoot;
}

class _StaleConnectionAttempt implements Exception {}
