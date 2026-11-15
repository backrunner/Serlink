import '../../../core/ids/entity_id.dart';

/// Client-wide remembered consent, or a narrowly scoped transient grant.
class AgentGrant {
  const AgentGrant({
    required this.grantId,
    required this.clientName,
    required this.hostId,
    required this.createdAt,
    this.expiresAt,
    this.sessionId,
    this.discoveryStrict,
    this.clientWide = false,
  });

  /// Unique grant identifier (uuid).
  final String grantId;

  /// MCP client implementation name that received this grant.
  final String clientName;

  /// Host this grant is scoped to.
  final HostId? hostId;

  /// Restricts legacy scoped grants to one existing connection.
  final SessionId? sessionId;

  /// Discovery grants have no host; consent is scoped to the privacy setting.
  final bool? discoveryStrict;

  /// Remembered client consent covers discovery and all host connections.
  final bool clientWide;

  bool get isDiscovery => hostId == null && discoveryStrict != null;

  final DateTime createdAt;

  /// Expiry instant; null means no time limit. Client-wide consent is persisted.
  final DateTime? expiresAt;

  bool isExpired(DateTime now) {
    final expiry = expiresAt;
    return expiry != null && !now.isBefore(expiry);
  }

  bool covers(HostId id, DateTime now, {SessionId? sessionId}) {
    return !isExpired(now) &&
        (clientWide || (id == hostId && this.sessionId == sessionId));
  }

  @override
  bool operator ==(Object other) {
    return other is AgentGrant &&
        other.grantId == grantId &&
        other.clientName == clientName &&
        other.hostId == hostId &&
        other.sessionId == sessionId &&
        other.discoveryStrict == discoveryStrict &&
        other.clientWide == clientWide &&
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
      clientWide,
    );
  }
}
