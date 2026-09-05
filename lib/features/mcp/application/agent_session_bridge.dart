import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_dependencies.dart';
import '../../../core/ids/entity_id.dart';
import '../../hosts/application/host_store.dart';
import '../../hosts/domain/host.dart';
import '../../security/application/security_modal_service.dart';
import '../../vault/application/vault_service.dart';
import '../../workspace/application/workspace_tab_controller.dart';
import '../../workspace/domain/workspace_tab.dart';
import '../data/command_risk_policy.dart';
import '../domain/agent_session.dart';
import '../domain/command_risk.dart';
import 'mcp_authorization_service.dart';

/// Error thrown by [AgentSessionBridge] with a machine-readable [code] such
/// as `vault_locked` or `authorization_denied`; surfaced to MCP clients as
/// `code: detail`.
class McpBridgeException implements Exception {
  const McpBridgeException(this.code, [this.detail]);

  final String code;
  final String? detail;

  @override
  String toString() => detail == null ? code : '$code: $detail';
}

class _AgentSessionEntry {
  _AgentSessionEntry({
    required this.handle,
    required this.tabId,
    required this.hostDisplayName,
  });

  AgentSessionHandle handle;
  final WorkspaceTabId tabId;
  final String hostDisplayName;

  /// Risk-rule ids the user approved with "allow for session".
  final Set<String> allowedRuleIds = {};
}

/// Coordinates MCP agent requests with app-owned SSH terminal sessions:
/// vault checks, per-host grants, opening workspace tabs, and running
/// commands through the live terminal.
///
/// The bridge reads app state through [ref] (workspace tab controller,
/// runtime registry, vault session, host store) so it always acts on the same
/// instances the UI uses. Grant bookkeeping lives in
/// [McpAuthorizationService]; the bridge only queries it and delegates
/// revocation to it.
class AgentSessionBridge {
  AgentSessionBridge({
    required Ref ref,
    required McpAuthorizationService authorization,
    required CommandRiskPolicy riskPolicy,
    required SecurityModalService securityModalService,
    this.attachTimeout = const Duration(seconds: 45),
    this.attachPollInterval = const Duration(milliseconds: 200),
    this.settleQuietPeriod = const Duration(milliseconds: 400),
    this.settlePollInterval = const Duration(milliseconds: 150),
    this.execOutputLines = 100,
    DateTime Function()? now,
    // Named parameters cannot be initializing formals for private fields.
    // ignore: prefer_initializing_formals
  }) : _ref = ref,
       // ignore: prefer_initializing_formals
       _authorization = authorization,
       // ignore: prefer_initializing_formals
       _riskPolicy = riskPolicy,
       // ignore: prefer_initializing_formals
       _securityModalService = securityModalService,
       _now = now ?? DateTime.now;

  final Ref _ref;
  final McpAuthorizationService _authorization;
  final CommandRiskPolicy _riskPolicy;
  final SecurityModalService _securityModalService;
  final DateTime Function() _now;

  /// How long [openSession] waits for the SSH channel to attach.
  final Duration attachTimeout;
  final Duration attachPollInterval;

  /// [exec] polls the screen every [settlePollInterval] and considers the
  /// command finished once the last screen lines stayed unchanged for
  /// [settleQuietPeriod]. This is a heuristic: interactive programs and very
  /// chatty commands may settle late or early, so [exec] returns the last
  /// [execOutputLines] screen lines rather than a strict command-output diff.
  final Duration settleQuietPeriod;
  final Duration settlePollInterval;
  final int execOutputLines;

  final Map<SessionId, _AgentSessionEntry> _sessions = {};
  final StreamController<List<AgentSessionHandle>> _sessionsChanged =
      StreamController<List<AgentSessionHandle>>.broadcast();

  List<AgentSessionHandle> get sessions => List.unmodifiable(
    _sessions.values.map((entry) => entry.handle),
  );

  /// Emits the current session list on every open/close/state change. New
  /// listeners only see later mutations; read [sessions] for the initial
  /// snapshot.
  Stream<List<AgentSessionHandle>> get watchSessions =>
      _sessionsChanged.stream;

  void _emitSessions() {
    _sessionsChanged.add(sessions);
  }

  List<AgentSessionHandle> sessionsFor(String clientName) {
    return List.unmodifiable(
      _sessions.values
          .where((entry) => entry.handle.clientName == clientName)
          .map((entry) => entry.handle),
    );
  }

  Future<List<HostSummary>> listHosts() {
    final vault = _requireUnlockedVault();
    return _ref.read(hostSummariesProvider(vault.unlockGeneration).future);
  }

  /// Opens an SSH terminal tab for [hostId] on behalf of [clientName].
  ///
  /// Throws [McpBridgeException] with codes `vault_locked`, `host_not_found`,
  /// `authorization_denied`, `connect_failed`, or `connect_timeout`.
  Future<AgentSessionHandle> openSession({
    required String clientName,
    required HostId hostId,
  }) async {
    final vault = _requireUnlockedVault();
    final hosts = await _ref.read(
      hostSummariesProvider(vault.unlockGeneration).future,
    );
    HostSummary? host;
    for (final candidate in hosts) {
      if (candidate.id == hostId) {
        host = candidate;
        break;
      }
    }
    if (host == null) {
      throw const McpBridgeException('host_not_found');
    }
    final grant = await _authorization.ensureGrant(
      clientName: clientName,
      hostId: hostId,
      hostDisplayName: host.displayName,
    );
    if (grant == null) {
      throw const McpBridgeException('authorization_denied');
    }

    final tab = await _ref
        .read(workspaceTabControllerProvider.notifier)
        .openTerminal(host);
    final content = tab?.content;
    if (tab == null || tab.hostId != hostId || content is! TerminalTabContent) {
      throw const McpBridgeException(
        'connect_failed',
        'workspace did not open a terminal tab for the granted host',
      );
    }
    final tabId = tab.id;
    final sessionId = content.primaryPane.sessionId;
    await _waitForAttach(tabId, sessionId);

    final handle = AgentSessionHandle(
      sessionId: sessionId,
      hostId: hostId,
      grantId: grant.grantId,
      clientName: clientName,
      state: AgentSessionState.connected,
      openedAt: _now(),
    );
    _sessions[sessionId] = _AgentSessionEntry(
      handle: handle,
      tabId: tabId,
      hostDisplayName: host.displayName,
    );
    _emitSessions();
    return handle;
  }

  /// Sends [command] to the session and returns the settled screen text.
  ///
  /// Output heuristic: after the last screen lines stay unchanged for
  /// [settleQuietPeriod] (polled every [settlePollInterval], capped by
  /// [timeout]), the last [execOutputLines] screen lines are returned. This
  /// covers typical command output including the echoed command itself; it
  /// does not isolate the exact bytes the command produced.
  Future<String> exec({
    required String clientName,
    required SessionId sessionId,
    required String command,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final entry = _requireAuthorizedSession(clientName, sessionId);
    _requireConnectedPane(sessionId);
    await _enforceRiskPolicy(
      clientName: clientName,
      entry: entry,
      command: command,
    );
    final sent = _ref
        .read(workspaceRuntimeRegistryProvider)
        .sendTerminalInput(sessionId, '$command\r');
    if (!sent) {
      throw const McpBridgeException(
        'session_not_attached',
        'terminal is no longer attached to an SSH channel',
      );
    }
    await _waitForOutputSettled(sessionId, timeout: timeout);
    return _readScreenText(sessionId, lines: execOutputLines);
  }

  Future<String> readScreen({
    required String clientName,
    required SessionId sessionId,
    int lines = 50,
  }) async {
    _requireAuthorizedSession(clientName, sessionId);
    return _readScreenText(sessionId, lines: lines);
  }

  /// Sends raw [text] (keystrokes) for interactive programs. Text containing
  /// newlines can submit commands, so it goes through the same risk policy
  /// and confirmation flow as [exec].
  Future<void> sendInput({
    required String clientName,
    required SessionId sessionId,
    required String text,
  }) async {
    final entry = _requireAuthorizedSession(clientName, sessionId);
    _requireConnectedPane(sessionId);
    if (text.contains('\n') || text.contains('\r')) {
      await _enforceRiskPolicy(
        clientName: clientName,
        entry: entry,
        command: text,
      );
    }
    final sent = _ref
        .read(workspaceRuntimeRegistryProvider)
        .sendTerminalInput(sessionId, text);
    if (!sent) {
      throw const McpBridgeException(
        'session_not_attached',
        'terminal is no longer attached to an SSH channel',
      );
    }
  }

  /// Closes the workspace pane that hosts [sessionId] and forgets the
  /// handle. Unknown session ids are a no-op so agents can safely retry
  /// cleanup. When the tab hosts other panes, only the agent pane is closed
  /// so user-owned sibling panes survive.
  Future<void> closeSession(SessionId sessionId) async {
    final entry = _sessions.remove(sessionId);
    if (entry == null) {
      return;
    }
    _emitSessions();
    final workspace = _ref.read(workspaceTabControllerProvider);
    for (final tab in workspace.tabs) {
      if (tab.id != entry.tabId) {
        continue;
      }
      final content = tab.content;
      if (content is TerminalTabContent && content.panes.length > 1) {
        for (var index = 0; index < content.panes.length; index += 1) {
          if (content.panes[index].sessionId == sessionId) {
            _ref
                .read(workspaceTabControllerProvider.notifier)
                .closeTerminalPane(entry.tabId, index);
            return;
          }
        }
      }
      break;
    }
    _ref.read(workspaceTabControllerProvider.notifier).closeTab(entry.tabId);
  }

  /// Drops handles whose workspace tab or pane no longer exists (e.g. the
  /// user closed the tab manually). Emits a session-list change when
  /// anything was removed.
  void reconcileWithWorkspace(WorkspaceState workspace) {
    if (_pruneStaleHandles(workspace)) {
      _emitSessions();
    }
  }

  bool _pruneStaleHandles(WorkspaceState workspace) {
    final stale = [
      for (final entry in _sessions.entries)
        if (!_workspaceHasSession(workspace, entry.value.tabId, entry.key))
          entry.key,
    ];
    for (final sessionId in stale) {
      _sessions.remove(sessionId);
    }
    return stale.isNotEmpty;
  }

  bool _workspaceHasSession(
    WorkspaceState workspace,
    WorkspaceTabId tabId,
    SessionId sessionId,
  ) {
    for (final tab in workspace.tabs) {
      if (tab.id != tabId) {
        continue;
      }
      final content = tab.content;
      if (content is! TerminalTabContent) {
        return false;
      }
      return content.panes.any((pane) => pane.sessionId == sessionId);
    }
    return false;
  }

  /// Closes the session-list broadcast stream. Called by the provider on
  /// dispose; the bridge must not be used afterwards.
  void dispose() {
    unawaited(_sessionsChanged.close());
  }

  /// Revokes a grant; in-flight sessions stay open but their next call fails
  /// with `authorization_required`.
  void revokeGrant(String grantId) {
    _authorization.revokeGrant(grantId);
  }

  _AgentSessionEntry _requireAuthorizedSession(
    String clientName,
    SessionId sessionId,
  ) {
    // Lazy backstop for reconcileWithWorkspace: drop handles whose tab or
    // pane vanished since the last workspace notification.
    _pruneStaleHandles(_ref.read(workspaceTabControllerProvider));
    final entry = _sessions[sessionId];
    if (entry == null) {
      throw const McpBridgeException('session_not_found');
    }
    _requireUnlockedVault();
    final grant = _authorization.findValidGrant(
      clientName: clientName,
      hostId: entry.handle.hostId,
      now: _now(),
    );
    if (grant == null) {
      throw const McpBridgeException('authorization_required');
    }
    return entry;
  }

  /// Throws `session_not_attached` unless the pane hosting [sessionId] still
  /// exists and is `connected`. The runtime registry keeps dead adapters
  /// around after a disconnect, so its `sendTerminalInput` returning true is
  /// not proof the session is alive.
  void _requireConnectedPane(SessionId sessionId) {
    for (final tab in _ref.read(workspaceTabControllerProvider).tabs) {
      final content = tab.content;
      if (content is! TerminalTabContent) {
        continue;
      }
      for (final pane in content.panes) {
        if (pane.sessionId == sessionId) {
          if (pane.lifecycle != SessionLifecycleState.connected) {
            throw const McpBridgeException(
              'session_not_attached',
              'terminal pane is no longer connected',
            );
          }
          return;
        }
      }
    }
    throw const McpBridgeException(
      'session_not_attached',
      'terminal pane for the session no longer exists',
    );
  }

  VaultSessionState _requireUnlockedVault() {    final vault = _ref.read(vaultSessionControllerProvider).value;
    if (vault == null || vault.vaultState != VaultState.unlocked) {
      throw const McpBridgeException('vault_locked');
    }
    return vault;
  }

  Future<void> _enforceRiskPolicy({
    required String clientName,
    required _AgentSessionEntry entry,
    required String command,
  }) async {
    final assessment = _riskPolicy.assess(command);
    switch (assessment.level) {
      case CommandRiskLevel.safe:
        return;
      case CommandRiskLevel.blocked:
        throw McpBridgeException('command_blocked', assessment.matchedRule);
      case CommandRiskLevel.needsConfirm:
        final rule = assessment.matchedRule ?? 'unknown_rule';
        if (entry.allowedRuleIds.contains(rule)) {
          return;
        }
        final decision = await _securityModalService.confirmAgentCommand(
          AgentCommandPrompt(
            clientName: clientName,
            hostDisplayName: entry.hostDisplayName,
            command: command,
            ruleDescription: rule,
          ),
        );
        switch (decision) {
          case AgentCommandDecision.deny:
            throw McpBridgeException('command_denied', rule);
          case AgentCommandDecision.allowOnce:
            return;
          case AgentCommandDecision.allowSession:
            entry.allowedRuleIds.add(rule);
            return;
        }
    }
  }

  Future<void> _waitForAttach(WorkspaceTabId tabId, SessionId sessionId) async {
    final registry = _ref.read(workspaceRuntimeRegistryProvider);
    final deadline = _now().add(attachTimeout);
    while (true) {
      if (registry.hasAttachedTerminal(sessionId)) {
        return;
      }
      final failure = _paneFailure(tabId, sessionId);
      if (failure != null) {
        throw McpBridgeException('connect_failed', failure);
      }
      if (!_now().isBefore(deadline)) {
        throw const McpBridgeException('connect_timeout');
      }
      await Future<void>.delayed(attachPollInterval);
    }
  }

  /// Returns a failure description when the tab's pane can no longer attach.
  String? _paneFailure(WorkspaceTabId tabId, SessionId sessionId) {
    for (final tab in _ref.read(workspaceTabControllerProvider).tabs) {
      if (tab.id != tabId) {
        continue;
      }
      final content = tab.content;
      if (content is! TerminalTabContent) {
        return 'workspace tab is no longer a terminal';
      }
      for (final pane in content.panes) {
        if (pane.sessionId != sessionId) {
          continue;
        }
        switch (pane.lifecycle) {
          case SessionLifecycleState.failed:
            return pane.failure?.message ?? 'connection failed';
          case SessionLifecycleState.idle:
          case SessionLifecycleState.disconnected:
          case SessionLifecycleState.disconnecting:
            return 'connection closed before the agent session attached';
          case SessionLifecycleState.resolvingProfile:
          case SessionLifecycleState.connecting:
          case SessionLifecycleState.verifyingHostKey:
          case SessionLifecycleState.authenticating:
          case SessionLifecycleState.connected:
          case SessionLifecycleState.reconnecting:
            return null;
        }
      }
      return 'terminal pane for the agent session disappeared';
    }
    return 'workspace tab for the agent session disappeared';
  }

  Future<void> _waitForOutputSettled(
    SessionId sessionId, {
    required Duration timeout,
  }) async {
    final deadline = _now().add(timeout);
    var last = _readScreenText(sessionId, lines: 30);
    var changedAt = _now();
    while (true) {
      await Future<void>.delayed(settlePollInterval);
      final current = _readScreenText(sessionId, lines: 30);
      final now = _now();
      if (current != last) {
        last = current;
        changedAt = now;
      } else if (now.difference(changedAt) >= settleQuietPeriod) {
        return;
      }
      if (!now.isBefore(deadline)) {
        return;
      }
    }
  }

  String _readScreenText(SessionId sessionId, {required int lines}) {
    final terminal = _ref
        .read(workspaceRuntimeRegistryProvider)
        .terminalFor(sessionId);
    if (terminal == null) {
      throw const McpBridgeException(
        'terminal_not_found',
        'no terminal buffer exists for this session',
      );
    }
    final buffer = terminal.lines;
    final count = buffer.length;
    final start = count > lines ? count - lines : 0;
    final texts = <String>[
      for (var index = start; index < count; index += 1)
        buffer[index].getText().trimRight(),
    ];
    while (texts.isNotEmpty && texts.last.isEmpty) {
      texts.removeLast();
    }
    return texts.join('\n');
  }
}
