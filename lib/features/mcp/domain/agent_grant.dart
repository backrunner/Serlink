import '../../../core/ids/entity_id.dart';

/// Permission to discover metadata, open sessions on a host, or control one
/// existing connection. Discovery grants have no host ID.
///
/// A grant with a null [expiresAt] stays valid until the app quits.
class AgentGrant {
  const AgentGrant({
    required this.grantId,
    required this.clientName,
    required this.hostId,
    required this.createdAt,
    this.expiresAt,
    this.sessionId,
    this.discoveryStrict,
  });

  /// Unique grant identifier (uuid).
  final String grantId;

  /// MCP client implementation name that received this grant.
  final String clientName;

  /// Host this grant is scoped to.
  final HostId? hostId;

  /// Existing connections require their own grant, separate from new sessions.
  final SessionId? sessionId;

  /// Discovery grants have no host; consent is scoped to the privacy setting.
  final bool? discoveryStrict;

  bool get isDiscovery => hostId == null && discoveryStrict != null;

  final DateTime createdAt;

  /// Expiry instant; null means the grant lives until app quit.
  final DateTime? expiresAt;

  bool isExpired(DateTime now) {
    final expiry = expiresAt;
    return expiry != null && !now.isBefore(expiry);
  }

  bool covers(HostId id, DateTime now, {SessionId? sessionId}) {
    return id == hostId && this.sessionId == sessionId && !isExpired(now);
  }

  @override
  bool operator ==(Object other) {
    return other is AgentGrant &&
        other.grantId == grantId &&
        other.clientName == clientName &&
        other.hostId == hostId &&
        other.sessionId == sessionId &&
        other.discoveryStrict == discoveryStrict &&
        other.createdAt == createdAt &&
        other.expiresAt == expiresAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      grantId,
      clientName,
      hostId,
      createdAt,
      expiresAt,
      sessionId,
      discoveryStrict,
    );
  }
}
