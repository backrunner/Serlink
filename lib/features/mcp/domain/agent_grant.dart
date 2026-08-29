import '../../../core/ids/entity_id.dart';

/// Permission granted to an MCP client to drive SSH sessions on one host.
///
/// A grant with a null [expiresAt] stays valid until the app quits.
class AgentGrant {
  const AgentGrant({
    required this.grantId,
    required this.clientName,
    required this.hostId,
    required this.createdAt,
    this.expiresAt,
  });

  /// Unique grant identifier (uuid).
  final String grantId;

  /// MCP client implementation name that received this grant.
  final String clientName;

  /// Host this grant is scoped to.
  final HostId hostId;

  final DateTime createdAt;

  /// Expiry instant; null means the grant lives until app quit.
  final DateTime? expiresAt;

  bool isExpired(DateTime now) {
    final expiry = expiresAt;
    return expiry != null && !now.isBefore(expiry);
  }

  bool covers(HostId id, DateTime now) {
    return id == hostId && !isExpired(now);
  }

  @override
  bool operator ==(Object other) {
    return other is AgentGrant &&
        other.grantId == grantId &&
        other.clientName == clientName &&
        other.hostId == hostId &&
        other.createdAt == createdAt &&
        other.expiresAt == expiresAt;
  }

  @override
  int get hashCode {
    return Object.hash(grantId, clientName, hostId, createdAt, expiresAt);
  }
}
