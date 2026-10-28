import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../app/app_dependencies.dart';
import '../../../core/ids/entity_id.dart';
import '../../../core/logging/offline_diagnostic_logger.dart';
import '../../../core/security/local_file_security.dart';
import '../../hosts/application/host_store.dart';
import '../../hosts/domain/host.dart';
import '../../security/application/security_modal_service.dart';
import '../../sftp/application/sftp_connection.dart';
import '../../transfers/application/transfer_queue_controller.dart';
import '../../vault/application/vault_service.dart';
import '../../workspace/application/workspace_tab_controller.dart';
import '../../workspace/domain/workspace_tab.dart';
import '../data/command_risk_policy.dart';
import '../domain/agent_session.dart';
import '../domain/command_risk.dart';
import 'mcp_authorization_service.dart';
import 'command_decision_guard.dart';
import 'mcp_host_visibility.dart';
import 'mcp_request_context.dart';

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
  Future<void> inputQueue = Future<void>.value();
  bool hasUnsubmittedInput = false;
  int inputGeneration = 0;
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
    CommandDecisionGuard? decisionGuard,
    this.attachTimeout = const Duration(minutes: 2),
    this.attachPollInterval = const Duration(milliseconds: 200),
    this.settleQuietPeriod = const Duration(milliseconds: 400),
    this.settlePollInterval = const Duration(milliseconds: 150),
    this.execOutputLines = 100,
    DateTime Function()? now,
    Future<Directory> Function()? downloadDirectory,
    // Named parameters cannot be initializing formals for private fields.
    // ignore: prefer_initializing_formals
  }) : _ref = ref,
       // ignore: prefer_initializing_formals
       _authorization = authorization,
       // ignore: prefer_initializing_formals
       _riskPolicy = riskPolicy,
       // ignore: prefer_initializing_formals
       _securityModalService = securityModalService,
       // Named parameters cannot initialize private fields directly.
       // ignore: prefer_initializing_formals
       _decisionGuard = decisionGuard,
       _now = now ?? DateTime.now,
       _downloadDirectory = downloadDirectory ?? _defaultDownloadDirectory;

  final Ref _ref;
  final McpAuthorizationService _authorization;
  final CommandRiskPolicy _riskPolicy;
  final SecurityModalService _securityModalService;
  final CommandDecisionGuard? _decisionGuard;
  final DateTime Function() _now;
  final Future<Directory> Function() _downloadDirectory;
  final Map<TransferTaskId, SessionId> _transfers = {};

  static Future<Directory> _defaultDownloadDirectory() async =>
      await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();

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

  List<AgentSessionHandle> get sessions =>
      List.unmodifiable(_sessions.values.map((entry) => entry.handle));

  /// Emits the current session list on every open/close/state change. New
  /// listeners only see later mutations; read [sessions] for the initial
  /// snapshot.
  Stream<List<AgentSessionHandle>> get watchSessions => _sessionsChanged.stream;

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

  Future<List<Map<String, Object?>>> describeHosts() async {
    final generation = _requireUnlockedVault().unlockGeneration;
    final hosts = await _ref.read(hostRepositoryProvider).list();
    final strict = await _ref.read(mcpHostVisibilityProvider).readStrict();
    if (_requireUnlockedVault().unlockGeneration != generation) {
      throw const McpBridgeException('vault_locked');
    }
    return [
      for (final host in hosts)
        McpHostVisibility.describe(host, strict: strict),
    ];
  }

  /// Lists app-owned remote panes, without reading terminal contents or
  /// exposing endpoint/key metadata. Listing never grants control.
  Future<List<Map<String, Object?>>> listConnections(String clientName) async {
    final vault = _requireUnlockedVault();
    final hosts = await listHosts();
    if (_requireUnlockedVault().unlockGeneration != vault.unlockGeneration) {
      throw const McpBridgeException('vault_locked');
    }
    McpRequestContext.current?.checkActive();
    final names = {for (final host in hosts) host.id: host.displayName};
    final workspace = _ref.read(workspaceTabControllerProvider);
    _pruneStaleHandles(workspace);
    return [
      for (final tab in workspace.tabs)
        for (final connection in _connectionsIn(tab))
          {
            'sessionId': connection.sessionId.value,
            'tabId': tab.id.value,
            'hostId': connection.hostId.value,
            'displayName': names[connection.hostId] ?? 'Unknown host',
            'kind': connection.kind.name,
            'state': connection.state.name,
            'controlledByThisClient':
                _sessions[connection.sessionId]?.handle.clientName ==
                clientName,
            'attachable':
                connection.state == SessionLifecycleState.connected &&
                !_sessions.containsKey(connection.sessionId),
          },
    ];
  }

  Iterable<
    ({
      SessionId sessionId,
      HostId hostId,
      AgentSessionKind kind,
      SessionLifecycleState state,
    })
  >
  _connectionsIn(WorkspaceTabState tab) sync* {
    final content = tab.content;
    if (content is SftpTabContent) {
      final hostId = tab.hostId;
      if (hostId != null) {
        yield (
          sessionId: content.sessionId,
          hostId: hostId,
          kind: AgentSessionKind.sftp,
          state: tab.lifecycle,
        );
      }
      return;
    }
    final panes = switch (content) {
      TerminalTabContent(:final panes) => panes,
      LocalTerminalTabContent(:final panes) => panes,
      _ => const <TerminalPaneState>[],
    };
    for (final pane in panes) {
      if (pane.endpoint?.isLocal ?? content is LocalTerminalTabContent) {
        continue;
      }
      final hostId = pane.endpoint?.hostId ?? tab.hostId;
      if (hostId == null) continue;
      yield (
        sessionId: pane.sessionId,
        hostId: hostId,
        kind: AgentSessionKind.terminal,
        state: pane.lifecycle,
      );
    }
  }

  /// Borrows an existing connected pane after the same per-host approval
  /// used by openSession. No SSH authentication or new tab is involved.
  Future<AgentSessionHandle> attachSession({
    required String clientName,
    required SessionId sessionId,
  }) async {
    final vault = _requireUnlockedVault();
    final workspace = _ref.read(workspaceTabControllerProvider);
    _pruneStaleHandles(workspace);
    if (_sessions.containsKey(sessionId)) {
      throw const McpBridgeException('session_in_use');
    }
    final matches = [
      for (final tab in workspace.tabs)
        for (final connection in _connectionsIn(tab))
          if (connection.sessionId == sessionId) (tab, connection),
    ];
    if (matches.isEmpty) throw const McpBridgeException('session_not_found');
    final (tab, connection) = matches.single;
    if (connection.state != SessionLifecycleState.connected) {
      throw const McpBridgeException('session_not_attached');
    }
    final hosts = await listHosts();
    final host = hosts
        .where((host) => host.id == connection.hostId)
        .firstOrNull;
    if (host == null) throw const McpBridgeException('host_not_found');
    void validate() {
      if (_requireUnlockedVault().unlockGeneration != vault.unlockGeneration) {
        throw const McpBridgeException('vault_locked');
      }
    }

    final request = McpRequestContext.current;
    request?.validate = validate;
    request?.checkActive();
    validate();
    final grant = await _authorization.ensureGrant(
      clientName: clientName,
      hostId: host.id,
      hostDisplayName: host.displayName,
    );
    if (grant == null) throw const McpBridgeException('authorization_denied');
    request?.checkActive();
    validate();
    if (_authorization.findValidGrant(
          clientName: clientName,
          hostId: host.id,
          now: _now(),
        ) !=
        grant) {
      throw const McpBridgeException('authorization_required');
    }
    if (_sessions.containsKey(sessionId)) {
      throw const McpBridgeException('session_in_use');
    }
    final current = _ref
        .read(workspaceTabControllerProvider)
        .tabs
        .where((candidate) => candidate.id == tab.id)
        .firstOrNull;
    if (current == null || !_connectionsIn(current).contains(connection)) {
      throw const McpBridgeException('session_not_attached');
    }
    final registry = _ref.read(workspaceRuntimeRegistryProvider);
    if (connection.kind == AgentSessionKind.terminal
        ? !registry.hasAttachedTerminal(sessionId)
        : registry.sftpFor(sessionId) == null) {
      throw const McpBridgeException('session_not_attached');
    }
    final handle = AgentSessionHandle(
      sessionId: sessionId,
      hostId: host.id,
      grantId: grant.grantId,
      clientName: clientName,
      state: AgentSessionState.connected,
      openedAt: _now(),
      kind: connection.kind,
      borrowed: true,
    );
    _sessions[sessionId] = _AgentSessionEntry(
      handle: handle,
      tabId: tab.id,
      hostDisplayName: host.displayName,
    );
    _emitSessions();
    return handle;
  }

  /// Opens an SSH terminal tab for [hostId] on behalf of [clientName].
  ///
  /// Throws [McpBridgeException] with codes `vault_locked`, `host_not_found`,
  /// `authorization_denied`, `connect_failed`, or `connect_timeout`.
  Future<AgentSessionHandle> openSession({
    required String clientName,
    required HostId hostId,
    AgentSessionKind kind = AgentSessionKind.terminal,
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
    final request = McpRequestContext.current;
    request?.validate = () {
      if (_requireUnlockedVault().unlockGeneration != vault.unlockGeneration) {
        throw const McpBridgeException('vault_locked');
      }
    };
    request?.checkActive();
    final grant = await _authorization.ensureGrant(
      clientName: clientName,
      hostId: hostId,
      hostDisplayName: host.displayName,
    );
    if (grant == null) {
      throw const McpBridgeException('authorization_denied');
    }

    McpRequestContext.current?.checkActive();
    if (_requireUnlockedVault().unlockGeneration != vault.unlockGeneration) {
      throw const McpBridgeException('vault_locked');
    }
    if (_authorization.findValidGrant(
          clientName: clientName,
          hostId: hostId,
          now: _now(),
        ) !=
        grant) {
      throw const McpBridgeException('authorization_denied');
    }
    final controller = _ref.read(workspaceTabControllerProvider.notifier);
    final tab = kind == AgentSessionKind.sftp
        ? controller.openSftp(host)
        : await controller.openTerminal(host, reuseFailedTab: false);
    final content = tab?.content;
    final sessionId = switch (content) {
      TerminalTabContent(:final primaryPane)
          when kind == AgentSessionKind.terminal =>
        primaryPane.sessionId,
      SftpTabContent(:final sessionId) when kind == AgentSessionKind.sftp =>
        sessionId,
      _ => null,
    };
    if (tab == null || tab.hostId != hostId || sessionId == null) {
      throw const McpBridgeException(
        'connect_failed',
        'workspace did not open the requested tab for the granted host',
      );
    }
    final tabId = tab.id;
    final logger = _ref.read(offlineDiagnosticLoggerProvider);
    final details = {'sessionId': sessionId.value, 'hostId': hostId.value};
    await logger.record('mcp.session.open.start', details: details);
    try {
      McpRequestContext.current?.onConnecting?.call();
      await _waitForAttach(
        tabId,
        sessionId,
        kind: kind,
        validate: () {
          if (_requireUnlockedVault().unlockGeneration !=
              vault.unlockGeneration) {
            throw const McpBridgeException('vault_locked');
          }
          if (_authorization.findValidGrant(
                clientName: clientName,
                hostId: hostId,
                now: _now(),
              ) !=
              grant) {
            throw const McpBridgeException('authorization_required');
          }
        },
      );
      McpRequestContext.current?.checkActive();
      if (_requireUnlockedVault().unlockGeneration != vault.unlockGeneration) {
        throw const McpBridgeException('vault_locked');
      }
      if (_authorization.findValidGrant(
            clientName: clientName,
            hostId: hostId,
            now: _now(),
          ) !=
          grant) {
        throw const McpBridgeException('authorization_required');
      }
    } on Object catch (error) {
      _closeWorkspaceSession(tabId, sessionId);
      await logger.record(
        'mcp.session.open.failure',
        level: DiagnosticLogLevel.error,
        details: {
          ...details,
          'code': switch (error) {
            McpBridgeException(:final code) => code,
            McpApprovalException(:final code) => code,
            _ => 'connect_failed',
          },
        },
      );
      rethrow;
    }
    await logger.record('mcp.session.open.success', details: details);

    final handle = AgentSessionHandle(
      sessionId: sessionId,
      hostId: hostId,
      grantId: grant.grantId,
      clientName: clientName,
      state: AgentSessionState.connected,
      openedAt: _now(),
      kind: kind,
    );
    _sessions[sessionId] = _AgentSessionEntry(
      handle: handle,
      tabId: tabId,
      hostDisplayName: host.displayName,
    );
    _emitSessions();
    return handle;
  }

  SftpConnection _requireSftp(String clientName, SessionId sessionId) {
    final entry = _requireAuthorizedSession(clientName, sessionId);
    if (entry.handle.kind != AgentSessionKind.sftp) {
      throw const McpBridgeException('not_sftp_session');
    }
    final tab = _ref
        .read(workspaceTabControllerProvider)
        .tabs
        .where((tab) => tab.id == entry.tabId)
        .firstOrNull;
    final connection = _ref
        .read(workspaceRuntimeRegistryProvider)
        .sftpFor(sessionId);
    if (tab?.lifecycle != SessionLifecycleState.connected ||
        connection == null) {
      throw const McpBridgeException('session_not_attached');
    }
    McpRequestContext.current?.checkActive();
    return connection;
  }

  static void _validateRemotePath(String path) {
    if (!p.posix.isAbsolute(path) ||
        path.contains(RegExp(r'[\x00-\x1f\x7f]'))) {
      throw const McpBridgeException('invalid_remote_path');
    }
  }

  Future<List<Map<String, Object?>>> listSftp({
    required String clientName,
    required SessionId sessionId,
    required String path,
  }) async {
    _validateRemotePath(path);
    final entries = await _requireSftp(clientName, sessionId).list(path);
    _requireSftp(clientName, sessionId);
    return [
      for (final entry in entries)
        {
          'name': entry.name,
          'path': entry.path,
          'type': entry.type.name,
          'size': entry.size,
          'modifiedAt': entry.modifiedAt?.toUtc().toIso8601String(),
        },
    ];
  }

  /// Downloads into a fresh private directory in Downloads. Never overwrites
  /// an agent-selected local path or returns remote file contents through MCP.
  Future<Map<String, Object?>> downloadSftp({
    required String clientName,
    required SessionId sessionId,
    required String remotePath,
  }) async {
    _validateRemotePath(remotePath);
    final name = p.posix.basename(remotePath);
    if (name == '.' || name == '..' || name == '/' || name.contains('\\')) {
      throw const McpBridgeException('invalid_remote_path');
    }
    final entry = _requireAuthorizedSession(clientName, sessionId);
    _requireSftp(clientName, sessionId);
    final root = await _downloadDirectory();
    _requireSftp(clientName, sessionId);
    final directory = await root.createTemp('Serlink-');
    await LocalFileSecurity.preparePrivateDirectory(directory);
    final file = File(p.join(directory.path, name));
    await LocalFileSecurity.restrictFile(file);
    final connection = _requireSftp(clientName, sessionId);
    final taskId = _ref
        .read(transferQueueControllerProvider)
        .enqueueDownload(
          connection: connection,
          sourceHostId: entry.handle.hostId,
          sourceMachineName: entry.hostDisplayName,
          remotePath: remotePath,
          localPath: file.path,
        );
    _transfers[taskId] = sessionId;
    return {'taskId': taskId.value, 'localPath': file.path};
  }

  Map<String, Object?> transferStatus({
    required String clientName,
    required SessionId sessionId,
    required TransferTaskId taskId,
  }) {
    _requireAuthorizedSession(clientName, sessionId);
    if (_transfers[taskId] != sessionId) {
      throw const McpBridgeException('transfer_not_found');
    }
    final task = _ref.read(transferQueueControllerProvider).state.byId(taskId);
    if (task == null) throw const McpBridgeException('transfer_not_found');
    return {
      'taskId': task.id.value,
      'state': task.state.name,
      'localPath': task.localPath,
      'remotePath': task.remotePath,
      'transferredBytes': task.transferredBytes,
      'totalBytes': task.totalBytes,
      if (task.failure != null) 'error': task.failure!.code,
    };
  }

  Future<void> cancelTransfer({
    required String clientName,
    required SessionId sessionId,
    required TransferTaskId taskId,
  }) async {
    transferStatus(
      clientName: clientName,
      sessionId: sessionId,
      taskId: taskId,
    );
    await _ref.read(transferQueueControllerProvider).cancel(taskId);
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
    final generation = entry.inputGeneration;
    return _serializeInput(entry, () async {
      if (entry.inputGeneration != generation) {
        throw const McpBridgeException(
          'command_blocked',
          'command_input_interrupted',
        );
      }
      _requireAuthorizedSession(clientName, sessionId);
      _requireConnectedPane(sessionId);
      final permit = await _enforceRiskPolicy(
        clientName: clientName,
        entry: entry,
        command: command,
      );
      await _validateBeforeSend(
        clientName,
        sessionId,
        entry,
        permit,
        generation,
      );
      McpRequestContext.current?.checkActive();
      final sent = _ref
          .read(workspaceRuntimeRegistryProvider)
          .sendTerminalInput(sessionId, '$command\r');
      if (!sent) {
        throw const McpBridgeException('session_not_attached');
      }
      entry.hasUnsubmittedInput = false;
      await _waitForOutputSettled(sessionId, timeout: timeout);
      return _readScreenText(sessionId, lines: execOutputLines);
    });
  }

  Future<String> readScreen({
    required String clientName,
    required SessionId sessionId,
    int lines = 50,
  }) async {
    _requireAuthorizedSession(clientName, sessionId);
    return _readScreenText(sessionId, lines: lines);
  }

  /// With model protection, accept whole submitted commands or Ctrl-C only.
  /// Partial keystrokes, history/editing controls and bare Enter cannot be
  /// reliably assessed as commands in arbitrary shells or interactive programs.
  Future<void> sendInput({
    required String clientName,
    required SessionId sessionId,
    required String text,
  }) async {
    final entry = _requireAuthorizedSession(clientName, sessionId);
    // Interrupts must not wait behind a model request or long-running exec.
    // Invalidate queued/pending submissions so a late safe result cannot run.
    if (text == '\x03') {
      McpRequestContext.current?.checkActive();
      _requireConnectedPane(sessionId);
      McpRequestContext.current?.checkActive();
      final sent = _ref
          .read(workspaceRuntimeRegistryProvider)
          .sendTerminalInput(sessionId, text);
      if (!sent) throw const McpBridgeException('session_not_attached');
      entry.inputGeneration += 1;
      entry.hasUnsubmittedInput = false;
      return;
    }
    final generation = entry.inputGeneration;
    return _serializeInput(entry, () async {
      if (entry.inputGeneration != generation) {
        throw const McpBridgeException(
          'command_blocked',
          'command_input_interrupted',
        );
      }
      _requireAuthorizedSession(clientName, sessionId);
      _requireConnectedPane(sessionId);
      final permit = await _enforceRiskPolicy(
        clientName: clientName,
        entry: entry,
        command: text,
        rawInput: true,
      );
      await _validateBeforeSend(
        clientName,
        sessionId,
        entry,
        permit,
        generation,
      );
      McpRequestContext.current?.checkActive();
      final sent = _ref
          .read(workspaceRuntimeRegistryProvider)
          .sendTerminalInput(sessionId, text);
      if (!sent) throw const McpBridgeException('session_not_attached');
      if (text.isNotEmpty) {
        final newline = text.lastIndexOf('\n');
        final carriageReturn = text.lastIndexOf('\r');
        final lastSubmit = newline > carriageReturn ? newline : carriageReturn;
        entry.hasUnsubmittedInput = lastSubmit < text.length - 1;
      }
    });
  }

  Future<T> _serializeInput<T>(
    _AgentSessionEntry entry,
    Future<T> Function() operation,
  ) {
    final result = entry.inputQueue.then((_) => operation());
    entry.inputQueue = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  Future<void> _validateBeforeSend(
    String clientName,
    SessionId sessionId,
    _AgentSessionEntry entry,
    CommandDecisionPermit? permit,
    int generation,
  ) async {
    if (permit != null) {
      try {
        await _decisionGuard!.validate(permit);
      } on CommandDecisionException catch (error) {
        throw McpBridgeException('command_blocked', error.code);
      }
    }
    McpRequestContext.current?.checkActive();
    // Model requests and confirmation dialogs are asynchronous. Never send
    // after a grant was revoked, the vault locked, or the pane closed meanwhile.
    if (!identical(_requireAuthorizedSession(clientName, sessionId), entry)) {
      throw const McpBridgeException('session_not_found');
    }
    _requireConnectedPane(sessionId);
    if (entry.inputGeneration != generation) {
      throw const McpBridgeException(
        'command_blocked',
        'command_input_interrupted',
      );
    }
  }

  /// Closes the workspace pane that hosts [sessionId] and forgets the
  /// handle. Unknown session ids are a no-op so agents can safely retry
  /// cleanup. When the tab hosts other panes, only the agent pane is closed
  /// so user-owned sibling panes survive.
  Future<void> closeSession(
    SessionId sessionId, {
    String? clientName,
    bool keepConnection = false,
  }) async {
    final existing = _sessions[sessionId];
    if (existing != null &&
        clientName != null &&
        existing.handle.clientName != clientName) {
      throw const McpBridgeException('authorization_required');
    }
    for (final taskId
        in _transfers.entries
            .where((entry) => entry.value == sessionId)
            .map((entry) => entry.key)
            .toList()) {
      await _ref.read(transferQueueControllerProvider).cancel(taskId);
      _transfers.remove(taskId);
    }
    final entry = _sessions.remove(sessionId);
    if (entry == null) {
      return;
    }
    _emitSessions();
    if (entry.handle.borrowed || keepConnection) return;
    _closeWorkspaceSession(entry.tabId, sessionId);
  }

  void _closeWorkspaceSession(WorkspaceTabId tabId, SessionId sessionId) {
    final workspace = _ref.read(workspaceTabControllerProvider);
    for (final tab in workspace.tabs) {
      if (tab.id != tabId) {
        continue;
      }
      final content = tab.content;
      if (content is TerminalTabContent && content.panes.length > 1) {
        for (var index = 0; index < content.panes.length; index += 1) {
          if (content.panes[index].sessionId == sessionId) {
            _ref
                .read(workspaceTabControllerProvider.notifier)
                .closeTerminalPane(tabId, index);
            return;
          }
        }
      }
      if (!_workspaceHasSession(workspace, tabId, sessionId)) return;
      _ref.read(workspaceTabControllerProvider.notifier).closeTab(tabId);
      return;
    }
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
      if (content is SftpTabContent) return content.sessionId == sessionId;
      return _connectionsIn(tab).any((c) => c.sessionId == sessionId);
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
    if (entry.handle.clientName != clientName) {
      throw const McpBridgeException('authorization_required');
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
      final panes = switch (content) {
        TerminalTabContent(:final panes) => panes,
        LocalTerminalTabContent(:final panes) => panes,
        _ => const <TerminalPaneState>[],
      };
      for (final pane in panes) {
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

  VaultSessionState _requireUnlockedVault() {
    final vault = _ref.read(vaultSessionControllerProvider).value;
    if (vault == null || vault.vaultState != VaultState.unlocked) {
      throw const McpBridgeException('vault_locked');
    }
    return vault;
  }

  Future<CommandDecisionPermit?> _enforceRiskPolicy({
    required String clientName,
    required _AgentSessionEntry entry,
    required String command,
    bool rawInput = false,
  }) async {
    final request = McpRequestContext.current;
    final generation = entry.inputGeneration;
    request?.validate = () {
      final sessionId = entry.handle.sessionId;
      if (!identical(_requireAuthorizedSession(clientName, sessionId), entry)) {
        throw const McpBridgeException('session_not_found');
      }
      _requireConnectedPane(sessionId);
      if (generation != entry.inputGeneration) {
        throw const McpBridgeException(
          'command_blocked',
          'command_input_interrupted',
        );
      }
    };
    request?.checkActive();
    final assessment = _riskPolicy.assess(command);
    if (assessment.level == CommandRiskLevel.blocked) {
      throw McpBridgeException('command_blocked', assessment.matchedRule);
    }
    CommandDecisionPermit? permit;
    try {
      permit = await _decisionGuard?.check(
        command: command,
        rawInput: rawInput,
        hasUnsubmittedInput: entry.hasUnsubmittedInput,
      );
    } on CommandDecisionException catch (error) {
      throw McpBridgeException('command_blocked', error.code);
    }
    // In legacy mode, non-submitting input retains its interactive behavior.
    if (rawInput && !command.contains('\n') && !command.contains('\r')) {
      return permit;
    }
    switch (assessment.level) {
      case CommandRiskLevel.safe:
        return permit;
      case CommandRiskLevel.blocked:
        throw McpBridgeException('command_blocked', assessment.matchedRule);
      case CommandRiskLevel.needsConfirm:
        final rule = assessment.matchedRule ?? 'unknown_rule';
        if (entry.allowedRuleIds.contains(rule)) return permit;
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
            return permit;
          case AgentCommandDecision.allowSession:
            entry.allowedRuleIds.add(rule);
            return permit;
        }
    }
  }

  Future<void> _waitForAttach(
    WorkspaceTabId tabId,
    SessionId sessionId, {
    AgentSessionKind kind = AgentSessionKind.terminal,
    void Function()? validate,
  }) async {
    final registry = _ref.read(workspaceRuntimeRegistryProvider);
    final deadline = _now().add(attachTimeout);
    while (true) {
      McpRequestContext.current?.checkActive();
      validate?.call();
      if (kind == AgentSessionKind.sftp
          ? registry.sftpFor(sessionId) != null
          : registry.hasAttachedTerminal(sessionId)) {
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
      if (content is SftpTabContent && content.sessionId == sessionId) {
        if (tab.lifecycle == SessionLifecycleState.failed) {
          return tab.failure?.message ?? 'connection failed';
        }
        if (tab.lifecycle == SessionLifecycleState.disconnected) {
          return 'connection closed before the SFTP session attached';
        }
        return null;
      }
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
