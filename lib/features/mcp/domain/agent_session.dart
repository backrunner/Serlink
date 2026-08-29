import '../../../core/ids/entity_id.dart';

enum AgentSessionState { connecting, connected, disconnected, failed, closed }

/// Handle for an SSH session opened on behalf of an MCP client grant.
class AgentSessionHandle {
  const AgentSessionHandle({
    required this.sessionId,
    required this.hostId,
    required this.grantId,
    required this.clientName,
    required this.state,
    required this.openedAt,
  });

  final SessionId sessionId;
  final HostId hostId;
  final String grantId;
  final String clientName;
  final AgentSessionState state;
  final DateTime openedAt;

  AgentSessionHandle copyWith({AgentSessionState? state}) {
    return AgentSessionHandle(
      sessionId: sessionId,
      hostId: hostId,
      grantId: grantId,
      clientName: clientName,
      state: state ?? this.state,
      openedAt: openedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AgentSessionHandle &&
        other.sessionId == sessionId &&
        other.hostId == hostId &&
        other.grantId == grantId &&
        other.clientName == clientName &&
        other.state == state &&
        other.openedAt == openedAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      sessionId,
      hostId,
      grantId,
      clientName,
      state,
      openedAt,
    );
  }
}
