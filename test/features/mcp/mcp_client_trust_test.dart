import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/core/ids/entity_id.dart';
import 'package:serlink/features/mcp/application/mcp_authorization_service.dart';
import 'package:serlink/features/mcp/application/mcp_request_context.dart';
import 'package:serlink/features/security/application/security_modal_service.dart';
import 'package:serlink/platform/flutter_secure_storage_secret_store.dart';
import 'package:serlink/platform/secret_store.dart';

void main() {
  late _Store store;
  late _Modal modal;
  McpAuthorizationService service() {
    final value = McpAuthorizationService(
      securityModalService: modal,
      secretStore: store,
    );
    addTearDown(value.dispose);
    return value;
  }

  Future<Object?> connect(
    McpAuthorizationService service, [
    String client = 'agent',
  ]) => service.ensureGrant(
    clientName: client,
    hostId: HostId('host'),
    hostDisplayName: 'Host',
  );
  setUp(() {
    store = _Store();
    modal = _Modal();
  });

  test('remembered client survives restart across hosts, discovery and borrowed connections', () async {
    final first = service();
    final grant = await first.ensureGrant(
      clientName: 'agent',
      hostId: HostId('host'),
      hostDisplayName: 'Host',
    );
    expect(modal.lastPrompt!.rememberClient, isTrue);
    first.dispose();
    modal.decision = AgentAccessDecision.deny;
    final restored = service();
    await restored.initialize();
    expect(restored.grants.single, grant);
    expect(
      await restored.ensureDiscoveryGrant(clientName: 'agent', strict: false),
      grant,
    );
    expect(
      await restored.ensureGrant(
        clientName: 'agent',
        hostId: HostId('other'),
        hostDisplayName: 'Other',
        sessionId: SessionId('borrowed'),
      ),
      grant,
    );
    expect(modal.calls, 1);
    expect(await connect(restored, 'different-agent'), isNull);
    expect(modal.calls, 2);
  });

  test('revocation is persisted and the next connection asks again', () async {
    final first = service();
    await connect(first);
    await connect(first, 'other');
    final grant = first.grants.first;
    await first.revokeGrant(grant.grantId);
    final restored = service();
    await restored.initialize();
    expect(restored.grants.single.clientName, 'other');
    modal.decision = AgentAccessDecision.deny;
    expect(await connect(restored), isNull);
    expect(modal.calls, 3);
  });

  test(
    'simultaneous discovery and connection share one client approval',
    () async {
      modal.gate = Completer<AgentAccessDecision>();
      final value = service();
      final discovery = value.ensureDiscoveryGrant(
        clientName: 'agent',
        strict: true,
      );
      final connection = connect(value);
      await modal.started.future;
      modal.gate!.complete(AgentAccessDecision.allow);
      expect(await discovery, await connection);
      expect(modal.calls, 1);
    },
  );

  test(
    'cancelling while secure storage is pending removes persisted consent',
    () async {
      store.writeGate = Completer<void>();
      final value = service();
      final request = McpRequestContext();
      final future = request.run(() => connect(value));
      final expectation = expectLater(
        future,
        throwsA(
          isA<McpApprovalException>().having(
            (e) => e.code,
            'code',
            'request_cancelled',
          ),
        ),
      );
      await store.writeStarted.future;
      request.cancel();
      store.writeGate!.complete();
      await expectation;
      expect(value.grants, isEmpty);
      final restored = service();
      await restored.initialize();
      expect(restored.grants, isEmpty);
    },
  );

  test('revoke all during restore cannot resurrect old consent', () async {
    final first = service();
    await connect(first);
    store.readGate = Completer<void>();
    final restored = service();
    final loading = restored.initialize();
    await store.readStarted.future;
    await restored.revokeAll();
    store.readGate!.complete();
    await loading;
    expect(restored.grants, isEmpty);
    final next = service();
    await next.initialize();
    expect(next.grants, isEmpty);
  });

  test('storage failures never create usable consent', () async {
    store.failWrites = true;
    final value = service();
    await expectLater(
      connect(value),
      throwsA(
        isA<McpApprovalException>().having(
          (e) => e.code,
          'code',
          'authorization_unavailable',
        ),
      ),
    );
    expect(value.grants, isEmpty);
    store.failWrites = false;
    expect(await connect(value), isNotNull);
    expect(modal.calls, 2);
  });

  test(
    'malformed saved consent fails closed without showing a new approval',
    () async {
      await store.write(
        McpAuthorizationService.storageKey,
        utf8.encode('{broken'),
      );
      await expectLater(
        connect(service()),
        throwsA(
          isA<McpApprovalException>().having(
            (e) => e.code,
            'code',
            'authorization_unavailable',
          ),
        ),
      );
      expect(modal.calls, 0);
    },
  );
}

class _Modal extends Fake implements SecurityModalService {
  AgentAccessDecision decision = AgentAccessDecision.allow;
  AgentAccessPrompt? lastPrompt;
  int calls = 0;
  Completer<AgentAccessDecision>? gate;
  final started = Completer<void>();
  @override
  Future<AgentAccessDecision> confirmAgentAccess(AgentAccessPrompt prompt) {
    calls++;
    lastPrompt = prompt;
    if (!started.isCompleted) started.complete();
    return gate?.future ?? Future.value(decision);
  }
}

class _Store extends InMemorySecretStore {
  Completer<void>? readGate;
  Completer<void>? writeGate;
  final readStarted = Completer<void>();
  final writeStarted = Completer<void>();
  bool failWrites = false;
  @override
  Future<List<int>?> read(
    SecretRef ref, {
    SecretProtection protection = SecretProtection.deviceLocal,
  }) async {
    final snapshot = await super.read(ref, protection: protection);
    if (readGate != null) {
      if (!readStarted.isCompleted) readStarted.complete();
      await readGate!.future;
    }
    return snapshot;
  }

  @override
  Future<void> write(
    SecretRef ref,
    List<int> value, {
    SecretProtection protection = SecretProtection.deviceLocal,
  }) async {
    if (failWrites) throw StateError('unavailable');
    if (!writeStarted.isCompleted) writeStarted.complete();
    await writeGate?.future;
    await super.write(ref, value, protection: protection);
  }
}
