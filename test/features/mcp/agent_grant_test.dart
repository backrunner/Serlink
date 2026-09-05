import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/core/ids/entity_id.dart';
import 'package:serlink/features/mcp/domain/agent_grant.dart';

void main() {
  final hostId = HostId('host-1');
  final otherHostId = HostId('host-2');
  final createdAt = DateTime.utc(2026, 8, 29, 10);
  final expiresAt = DateTime.utc(2026, 8, 29, 12);

  AgentGrant grant({DateTime? expiry}) {
    return AgentGrant(
      grantId: 'grant-1',
      clientName: 'claude-code',
      hostId: hostId,
      createdAt: createdAt,
      expiresAt: expiry ?? expiresAt,
    );
  }

  AgentGrant neverExpiringGrant() {
    return AgentGrant(
      grantId: 'grant-1',
      clientName: 'claude-code',
      hostId: hostId,
      createdAt: createdAt,
    );
  }

  group('isExpired', () {
    test('is not expired before expiresAt', () {
      expect(grant().isExpired(DateTime.utc(2026, 8, 29, 11)), isFalse);
    });

    test('is expired exactly at expiresAt', () {
      expect(grant().isExpired(expiresAt), isTrue);
    });

    test('is expired after expiresAt', () {
      expect(grant().isExpired(DateTime.utc(2026, 8, 29, 13)), isTrue);
    });

    test('never expires when expiresAt is null', () {
      expect(
        neverExpiringGrant().isExpired(DateTime.utc(2099, 1, 1)),
        isFalse,
      );
    });
  });

  group('covers', () {
    test('covers the granted host before expiry', () {
      expect(grant().covers(hostId, DateTime.utc(2026, 8, 29, 11)), isTrue);
    });

    test('does not cover a different host', () {
      expect(
        grant().covers(otherHostId, DateTime.utc(2026, 8, 29, 11)),
        isFalse,
      );
    });

    test('does not cover the granted host after expiry', () {
      expect(grant().covers(hostId, DateTime.utc(2026, 8, 29, 13)), isFalse);
    });

    test('covers the granted host indefinitely when expiresAt is null', () {
      expect(
        neverExpiringGrant().covers(hostId, DateTime.utc(2099, 1, 1)),
        isTrue,
      );
    });

    test('still does not cover a different host when expiresAt is null', () {
      expect(
        neverExpiringGrant().covers(otherHostId, DateTime.utc(2026, 8, 29)),
        isFalse,
      );
    });
  });

  group('equality', () {
    test('equal when all fields match', () {
      expect(grant(), grant());
      expect(grant().hashCode, grant().hashCode);
    });

    test('not equal when any field differs', () {
      final base = grant();
      expect(
        base,
        isNot(
          AgentGrant(
            grantId: 'grant-2',
            clientName: base.clientName,
            hostId: base.hostId,
            createdAt: base.createdAt,
            expiresAt: base.expiresAt,
          ),
        ),
      );
      expect(
        base,
        isNot(
          AgentGrant(
            grantId: base.grantId,
            clientName: 'other-client',
            hostId: base.hostId,
            createdAt: base.createdAt,
            expiresAt: base.expiresAt,
          ),
        ),
      );
      expect(
        base,
        isNot(
          AgentGrant(
            grantId: base.grantId,
            clientName: base.clientName,
            hostId: otherHostId,
            createdAt: base.createdAt,
            expiresAt: base.expiresAt,
          ),
        ),
      );
      expect(base, isNot(neverExpiringGrant()));
    });
  });
}
