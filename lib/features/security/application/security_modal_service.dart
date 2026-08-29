import '../../ssh/application/ssh_session_service.dart';
import '../../sync/domain/webdav_tls_certificate_details.dart';

enum ExportDecision { cancel, confirm }

enum DestructiveDecision { cancel, confirm }

enum CertificateTrustDecision { cancel, trustAndSave }

enum AgentAccessDecision { deny, allow }

enum AgentCommandDecision { deny, allowOnce, allowSession }

class AgentAccessPrompt {
  const AgentAccessPrompt({
    required this.clientName,
    required this.hostDisplayName,
    required this.hostId,
  });

  final String clientName;
  final String hostDisplayName;
  final String hostId;
}

class AgentCommandPrompt {
  const AgentCommandPrompt({
    required this.clientName,
    required this.hostDisplayName,
    required this.command,
    required this.ruleDescription,
  });

  final String clientName;
  final String hostDisplayName;
  final String command;
  final String ruleDescription;
}

class ExportPreview {
  const ExportPreview({
    required this.title,
    required this.encrypted,
    required this.sensitiveFields,
  });

  final String title;
  final bool encrypted;
  final List<String> sensitiveFields;
}

abstract interface class SecurityModalService {
  Future<HostKeyDecision> confirmHostKey(HostKeyPrompt prompt);
  Future<CertificateTrustDecision> confirmWebDavCertificate(
    WebDavTlsCertificateDetails certificate,
  );
  Future<ExportDecision> confirmExport(ExportPreview preview);
  Future<DestructiveDecision> confirmDestructiveAction(String title);
  Future<bool> confirmMultilinePaste(String preview);
  Future<AgentAccessDecision> confirmAgentAccess(AgentAccessPrompt prompt);
  Future<AgentCommandDecision> confirmAgentCommand(AgentCommandPrompt prompt);
}
