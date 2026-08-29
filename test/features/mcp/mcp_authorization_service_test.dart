import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/core/ids/entity_id.dart';
import 'package:serlink/features/mcp/application/mcp_authorization_service.dart';
import 'package:serlink/features/mcp/domain/agent_grant.dart';
import 'package:serlink/features/security/application/security_modal_service.dart';
import 'package:serlink/features/ssh/application/ssh_session_service.dart';
import 'package:serlink/features/sync/domain/webdav_tls_certificate_details.dart';

void main() {
  final hostId = HostId('host-1');
  final otherHostId = HostId('host-2');

  group('McpAuthorizationService', () {
    test('allow creates and stores a grant', () async {
      final modal = _FakeSecurityModalService();
      final service = McpAuthorizationService(securityModalService: modal);

      final grant = await service.ensureGrant(
        clientName: 'claude',
        hostId: hostId,
        hostDisplayName: 'Test Host',
      );

      expect(grant, isNotNull);
      expect(grant!.clientName, 'claude');
      expect(grant.hostId, hostId);
      expect(grant.grantId, isNotEmpty);
      expect(grant.expiresAt, isNull);
      expect(service.grants, [grant]);
      expect(modal.accessCallCount, 1);
      expect(modal.lastAccessPrompt?.hostDisplayName, 'Test Host');
    });

    test('existing valid grant short-circuits without a dialog', () async {
      final modal = _FakeSecurityModalService();
      final service = McpAuthorizationService(securityModalService: modal);

      final first = await service.ensureGrant(
        clientName: 'claude',
        hostId: hostId,
        hostDisplayName: 'Test Host',
      );
      final second = await service.ensureGrant(
        clientName: 'claude',
        hostId: hostId,
        hostDisplayName: 'Test Host',
      );

      expect(second, first);
      expect(modal.accessCallCount, 1);
    });

    test('grants are scoped to client and host', () async {
      final modal = _FakeSecurityModalService();
      final service = McpAuthorizationService(securityModalService: modal);
      await service.ensureGrant(
        clientName: 'claude',
        hostId: hostId,
        hostDisplayName: 'Test Host',
      );

      expect(
        service.findValidGrant(
          clientName: 'claude',
          hostId: hostId,
          now: DateTime.now(),
        ),
        isNotNull,
      );
      expect(
        service.findValidGrant(
          clientName: 'other-client',
          hostId: hostId,
          now: DateTime.now(),
        ),
        isNull,
      );
      expect(
        service.findValidGrant(
          clientName: 'claude',
          hostId: otherHostId,
          now: DateTime.now(),
        ),
        isNull,
      );
    });

    test('deny returns null and stores nothing', () async {
      final modal = _FakeSecurityModalService()
        ..accessDecision = AgentAccessDecision.deny;
      final service = McpAuthorizationService(securityModalService: modal);

      final grant = await service.ensureGrant(
        clientName: 'claude',
        hostId: hostId,
        hostDisplayName: 'Test Host',
      );

      expect(grant, isNull);
      expect(service.grants, isEmpty);
    });

    test('concurrent ensureGrant calls share one confirmation dialog', () async {
      final modal = _FakeSecurityModalService();
      final gate = Completer<AgentAccessDecision>();
      modal.accessGate = gate;
      final service = McpAuthorizationService(securityModalService: modal);

      final first = service.ensureGrant(
        clientName: 'claude',
        hostId: hostId,
        hostDisplayName: 'Test Host',
      );
      final second = service.ensureGrant(
        clientName: 'claude',
        hostId: hostId,
        hostDisplayName: 'Test Host',
      );
      await Future<void>.delayed(Duration.zero);
      gate.complete(AgentAccessDecision.allow);

      final results = await Future.wait([first, second]);
      expect(results[0], isNotNull);
      expect(results[0], results[1]);
      expect(modal.accessCallCount, 1);
      expect(service.grants, hasLength(1));
    });

    test('revokeGrant invalidates the grant', () async {
      final modal = _FakeSecurityModalService();
      final service = McpAuthorizationService(securityModalService: modal);
      final grant = await service.ensureGrant(
        clientName: 'claude',
        hostId: hostId,
        hostDisplayName: 'Test Host',
      );

      expect(service.revokeGrant(grant!.grantId), isTrue);
      expect(service.revokeGrant(grant.grantId), isFalse);
      expect(
        service.findValidGrant(
          clientName: 'claude',
          hostId: hostId,
          now: DateTime.now(),
        ),
        isNull,
      );

      // A new grant requires a fresh confirmation.
      await service.ensureGrant(
        clientName: 'claude',
        hostId: hostId,
        hostDisplayName: 'Test Host',
      );
      expect(modal.accessCallCount, 2);
    });

    test('revokeAll clears every grant', () async {
      final modal = _FakeSecurityModalService();
      final service = McpAuthorizationService(securityModalService: modal);
      await service.ensureGrant(
        clientName: 'claude',
        hostId: hostId,
        hostDisplayName: 'Test Host',
      );
      await service.ensureGrant(
        clientName: 'claude',
        hostId: otherHostId,
        hostDisplayName: 'Other Host',
      );
      expect(service.grants, hasLength(2));

      service.revokeAll();
      expect(service.grants, isEmpty);
    });

    test('watchGrants emits on grant and revoke mutations', () async {
      final modal = _FakeSecurityModalService();
      final service = McpAuthorizationService(securityModalService: modal);
      final emissions = <List<AgentGrant>>[];
      final subscription = service.watchGrants.listen(emissions.add);

      final grant = await service.ensureGrant(
        clientName: 'claude',
        hostId: hostId,
        hostDisplayName: 'Test Host',
      );
      service.revokeGrant(grant!.grantId);
      // Removing an unknown grant does not emit.
      service.revokeGrant('unknown-grant');
      service.revokeAll();
      await Future<void>.delayed(Duration.zero);

      expect(emissions, [
        [grant],
        <AgentGrant>[],
        <AgentGrant>[],
      ]);
      await subscription.cancel();
    });

    test('expired grants are not returned by findValidGrant', () {
      final now = DateTime.utc(2026, 8, 29, 12);
      final expired = AgentGrant(
        grantId: 'g1',
        clientName: 'claude',
        hostId: hostId,
        createdAt: now.subtract(const Duration(hours: 2)),
        expiresAt: now.subtract(const Duration(hours: 1)),
      );
      expect(expired.isExpired(now), isTrue);
      expect(expired.covers(hostId, now), isFalse);

      final service = McpAuthorizationService(
        securityModalService: _FakeSecurityModalService(),
      );
      expect(
        service.findValidGrant(
          clientName: 'claude',
          hostId: hostId,
          now: now,
        ),
        isNull,
      );
    });
  });
}

class _FakeSecurityModalService implements SecurityModalService {
  AgentAccessDecision accessDecision = AgentAccessDecision.allow;
  AgentCommandDecision commandDecision = AgentCommandDecision.deny;
  Completer<AgentAccessDecision>? accessGate;
  AgentAccessPrompt? lastAccessPrompt;
  var accessCallCount = 0;
  var commandCallCount = 0;

  @override
  Future<AgentAccessDecision> confirmAgentAccess(AgentAccessPrompt prompt) {
    accessCallCount += 1;
    lastAccessPrompt = prompt;
    final gate = accessGate;
    if (gate != null) {
      return gate.future;
    }
    return Future.value(accessDecision);
  }

  @override
  Future<AgentCommandDecision> confirmAgentCommand(AgentCommandPrompt prompt) {
    commandCallCount += 1;
    return Future.value(commandDecision);
  }

  @override
  Future<HostKeyDecision> confirmHostKey(HostKeyPrompt prompt) {
    throw UnimplementedError();
  }

  @override
  Future<CertificateTrustDecision> confirmWebDavCertificate(
    WebDavTlsCertificateDetails certificate,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<ExportDecision> confirmExport(ExportPreview preview) {
    throw UnimplementedError();
  }

  @override
  Future<DestructiveDecision> confirmDestructiveAction(String title) {
    throw UnimplementedError();
  }

  @override
  Future<bool> confirmMultilinePaste(String preview) {
    throw UnimplementedError();
  }
}
