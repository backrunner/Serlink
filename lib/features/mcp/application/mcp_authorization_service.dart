import 'dart:async';
import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../../core/ids/entity_id.dart';
import '../../../platform/secret_store.dart';
import '../../security/application/security_modal_service.dart';
import '../domain/agent_grant.dart';
import 'mcp_request_context.dart';

/// Device-local, revocable client consent, shared by discovery and connections.
/// Session handles and command permits remain transient and separately checked.
class McpAuthorizationService {
  McpAuthorizationService({
    required SecurityModalService securityModalService,
    this.secretStore,
    Uuid uuid = const Uuid(),
    DateTime Function()? now,
    // Named parameters cannot initialize private fields directly.
    // ignore: prefer_initializing_formals
  }) : _securityModalService = securityModalService,
       // ignore: prefer_initializing_formals
       _uuid = uuid,
       _now = now ?? DateTime.now;

  static const storageKey = SecretRef('serlink.mcp.client-access.v1');
  final SecretStore? secretStore;
  final SecurityModalService _securityModalService;
  final Uuid _uuid;
  final DateTime Function() _now;
  final List<AgentGrant> _grants = [];
  final Map<String, Future<AgentGrant?>> _pendingGrants = {};
  final _grantsChanged = StreamController<List<AgentGrant>>.broadcast();
  int _generation = 0;
  bool _disposed = false;
  bool _loaded = false;
  Future<void>? _initialization;
  Future<void> _persistence = Future<void>.value();

  List<AgentGrant> get grants => List.unmodifiable(_grants);
  Stream<List<AgentGrant>> get watchGrants => _grantsChanged.stream;

  void _emitGrants() {
    if (!_disposed) _grantsChanged.add(grants);
  }

  Future<void> initialize() {
    if (_loaded || _disposed) return Future<void>.value();
    return _initialization ??= _restore();
  }

  Future<void> _restore() async {
    final generation = _generation;
    try {
      final bytes = await secretStore?.read(storageKey);
      final restored = <AgentGrant>[];
      if (bytes != null) {
        final decoded = jsonDecode(utf8.decode(bytes));
        if (decoded is! Map || decoded['clients'] is! List) {
          throw const FormatException('Invalid client consent');
        }
        final names = <String>{};
        for (final record in decoded['clients'] as List) {
          if (record is! Map ||
              record['clientName'] is! String ||
              (record['clientName'] as String).trim().isEmpty ||
              record['grantId'] is! String ||
              (record['grantId'] as String).isEmpty ||
              record['createdAt'] is! String ||
              !names.add(record['clientName'] as String)) {
            throw const FormatException('Invalid client consent record');
          }
          restored.add(
            AgentGrant(
              grantId: record['grantId'] as String,
              clientName: record['clientName'] as String,
              hostId: null,
              clientWide: true,
              createdAt: DateTime.parse(record['createdAt'] as String),
            ),
          );
        }
      }
      if (!_disposed && generation == _generation) {
        _grants.addAll(restored);
        _loaded = true;
        if (restored.isNotEmpty) _emitGrants();
      }
    } on Object {
      throw const McpApprovalException('authorization_unavailable');
    } finally {
      _initialization = null;
    }
  }

  Future<void> _save() {
    final result = _persistence.then((_) async {
      await secretStore?.write(
        storageKey,
        utf8.encode(
          jsonEncode({
            'clients': [
              for (final grant in _grants)
                if (grant.clientWide)
                  {
                    'grantId': grant.grantId,
                    'clientName': grant.clientName,
                    'createdAt': grant.createdAt.toUtc().toIso8601String(),
                  },
            ],
          }),
        ),
      );
    });
    _persistence = result.then<void>((_) {}, onError: (Object _) {});
    return result.catchError((Object _) {
      throw const McpApprovalException('authorization_unavailable');
    });
  }

  AgentGrant? findValidGrant({
    required String clientName,
    required HostId hostId,
    required DateTime now,
    SessionId? sessionId,
  }) {
    if (_disposed) return null;
    for (final grant in _grants) {
      if (grant.clientName == clientName &&
          grant.covers(hostId, now, sessionId: sessionId)) {
        return grant;
      }
    }
    return null;
  }

  Future<AgentGrant?> ensureGrant({
    required String clientName,
    required HostId hostId,
    required String hostDisplayName,
    SessionId? sessionId,
  }) => _ensureClient(
    clientName: clientName,
    hostId: hostId,
    hostDisplayName: hostDisplayName,
    sessionId: sessionId,
  );

  Future<AgentGrant?> ensureDiscoveryGrant({
    required String clientName,
    required bool strict,
  }) => _ensureClient(clientName: clientName, discoveryStrict: strict);

  bool isValid(AgentGrant grant) =>
      !_disposed && _grants.contains(grant) && !grant.isExpired(_now());

  Future<AgentGrant?> _ensureClient({
    required String clientName,
    HostId? hostId,
    String hostDisplayName = '',
    SessionId? sessionId,
    bool? discoveryStrict,
  }) {
    final pending = _pendingGrants[clientName];
    if (pending != null) return pending;
    final future = _requestGrant(
      clientName: clientName,
      hostId: hostId,
      hostDisplayName: hostDisplayName,
      sessionId: sessionId,
      discoveryStrict: discoveryStrict,
    );
    _pendingGrants[clientName] = future;
    unawaited(
      future.then<void>(
        (_) => _pendingGrants.remove(clientName),
        onError: (Object _) {
          _pendingGrants.remove(clientName);
        },
      ),
    );
    return future;
  }

  Future<AgentGrant?> _requestGrant({
    required String clientName,
    HostId? hostId,
    required String hostDisplayName,
    SessionId? sessionId,
    bool? discoveryStrict,
  }) async {
    final generation = _generation;
    await initialize();
    McpRequestContext.current?.checkActive();
    if (_disposed || generation != _generation) return null;
    for (final grant in _grants) {
      if (grant.clientName == clientName &&
          grant.clientWide &&
          isValid(grant)) {
        return grant;
      }
    }
    final decision = await _securityModalService.confirmAgentAccess(
      AgentAccessPrompt(
        clientName: clientName,
        hostDisplayName: hostDisplayName,
        hostId: hostId?.value ?? '',
        existingSessionId: sessionId?.value,
        discoveryStrict: discoveryStrict,
        rememberClient: true,
      ),
    );
    McpRequestContext.current?.checkActive();
    if (_disposed ||
        generation != _generation ||
        decision != AgentAccessDecision.allow) {
      return null;
    }
    final grant = AgentGrant(
      grantId: _uuid.v4(),
      clientName: clientName,
      hostId: null,
      clientWide: true,
      createdAt: _now().toUtc(),
    );
    _grants.add(grant);
    try {
      await _save();
      McpRequestContext.current?.checkActive();
      if (_disposed || generation != _generation) {
        _grants.remove(grant);
        await _save();
        return null;
      }
    } on Object {
      _grants.remove(grant);
      // Undo a consent write if the request expired while storage was pending.
      try {
        await _save();
      } on Object {
        /* The original failure remains visible. */
      }
      rethrow;
    }
    _emitGrants();
    return grant;
  }

  Future<bool> revokeGrant(String grantId) async {
    final before = _grants.length;
    _grants.removeWhere((grant) => grant.grantId == grantId);
    if (_grants.length == before) return false;
    _generation++;
    _emitGrants();
    try {
      await _save();
    } on Object {
      throw const McpApprovalException('authorization_unavailable');
    }
    return true;
  }

  Future<void> revokeAll() async {
    _generation++;
    _loaded =
        true; // Invalidate an in-flight restore before clearing persistence.
    _grants.clear();
    _emitGrants();
    try {
      await _save();
    } on Object {
      throw const McpApprovalException('authorization_unavailable');
    }
  }

  void dispose() {
    _disposed = true;
    _generation++;
    unawaited(_grantsChanged.close());
  }
}
