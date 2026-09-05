import 'dart:async';

import 'package:uuid/uuid.dart';

import '../../../core/ids/entity_id.dart';
import '../../security/application/security_modal_service.dart';
import '../domain/agent_grant.dart';

/// Tracks in-memory [AgentGrant]s and asks the user before creating new ones.
///
/// Grants are intentionally not persisted: every MCP client must be approved
/// again after the app restarts.
class McpAuthorizationService {
  McpAuthorizationService({
    required SecurityModalService securityModalService,
    Uuid uuid = const Uuid(),
    DateTime Function()? now,
    // Named parameters cannot be initializing formals for private fields.
    // ignore: prefer_initializing_formals
  }) : _securityModalService = securityModalService,
       // ignore: prefer_initializing_formals
       _uuid = uuid,
       _now = now ?? DateTime.now;

  final SecurityModalService _securityModalService;
  final Uuid _uuid;
  final DateTime Function() _now;

  final List<AgentGrant> _grants = [];
  final Map<String, Future<AgentGrant?>> _pendingGrants = {};
  final StreamController<List<AgentGrant>> _grantsChanged =
      StreamController<List<AgentGrant>>.broadcast();

  /// All currently stored grants, including expired ones.
  List<AgentGrant> get grants => List.unmodifiable(_grants);

  /// Emits the current grant list on every mutation. New listeners only see
  /// later mutations; read [grants] for the initial snapshot.
  Stream<List<AgentGrant>> get watchGrants => _grantsChanged.stream;

  void _emitGrants() {
    _grantsChanged.add(grants);
  }

  /// Returns the stored grant for (clientName, hostId) when it is still valid
  /// at [now].
  AgentGrant? findValidGrant({
    required String clientName,
    required HostId hostId,
    required DateTime now,
  }) {
    for (final grant in _grants) {
      if (grant.clientName == clientName && grant.covers(hostId, now)) {
        return grant;
      }
    }
    return null;
  }

  /// Returns an existing valid grant, or asks the user to approve a new one.
  ///
  /// Concurrent calls for the same (clientName, hostId) share one in-flight
  /// confirmation so the user only ever sees a single dialog.
  Future<AgentGrant?> ensureGrant({
    required String clientName,
    required HostId hostId,
    required String hostDisplayName,
  }) {
    final existing = findValidGrant(
      clientName: clientName,
      hostId: hostId,
      now: _now(),
    );
    if (existing != null) {
      return Future.value(existing);
    }
    final key = '$clientName|${hostId.value}';
    final pending = _pendingGrants[key];
    if (pending != null) {
      return pending;
    }
    final future = _requestGrant(
      clientName: clientName,
      hostId: hostId,
      hostDisplayName: hostDisplayName,
    );
    _pendingGrants[key] = future;
    future.whenComplete(() => _pendingGrants.remove(key));
    return future;
  }

  Future<AgentGrant?> _requestGrant({
    required String clientName,
    required HostId hostId,
    required String hostDisplayName,
  }) async {
    final decision = await _securityModalService.confirmAgentAccess(
      AgentAccessPrompt(
        clientName: clientName,
        hostDisplayName: hostDisplayName,
        hostId: hostId.value,
      ),
    );
    if (decision != AgentAccessDecision.allow) {
      return null;
    }
    final grant = AgentGrant(
      grantId: _uuid.v4(),
      clientName: clientName,
      hostId: hostId,
      createdAt: _now(),
      expiresAt: null,
    );
    _grants.add(grant);
    _emitGrants();
    return grant;
  }

  /// Closes the grant-list broadcast stream. Called by the provider on
  /// dispose; the service must not be used afterwards.
  void dispose() {
    unawaited(_grantsChanged.close());
  }

  /// Removes the grant with [grantId]; returns true when one was removed.
  bool revokeGrant(String grantId) {
    final before = _grants.length;
    _grants.removeWhere((grant) => grant.grantId == grantId);
    final removed = _grants.length != before;
    if (removed) {
      _emitGrants();
    }
    return removed;
  }

  void revokeAll() {
    _grants.clear();
    _emitGrants();
  }
}
