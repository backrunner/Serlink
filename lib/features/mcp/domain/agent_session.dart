import '../../../core/ids/entity_id.dart';

enum AgentSessionState { connecting, connected, disconnected, failed, closed }

enum AgentSessionKind { terminal, sftp }

/// Handle for an SSH session opened on behalf of an MCP client grant.
class AgentSessionHandle {
  const AgentSessionHandle({
    required this.sessionId,
    required this.hostId,
    required this.grantId,
    required this.clientName,
    required this.state,
    required this.openedAt,
    this.kind = AgentSessionKind.terminal,
    this.borrowed = false,
  });

  final SessionId sessionId;
  final HostId hostId;
  final String grantId;
  final String clientName;
  final AgentSessionState state;
  final DateTime openedAt;
  final AgentSessionKind kind;

  /// An existing user connection: releasing the handle leaves its tab open.
  final bool borrowed;

  AgentSessionHandle copyWith({AgentSessionState? state}) {
    return AgentSessionHandle(
      sessionId: sessionId,
      hostId: hostId,
      grantId: grantId,
      clientName: clientName,
      state: state ?? this.state,
      openedAt: openedAt,
      kind: kind,
      borrowed: borrowed,
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
        other.kind == kind &&
        other.borrowed == borrowed &&
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
      kind,
      borrowed,
    );
  }
}
