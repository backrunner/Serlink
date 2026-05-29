import '../../ssh/application/ssh_session_service.dart';
import '../../sync/domain/webdav_tls_certificate_details.dart';

enum ExportDecision { cancel, confirm }

enum DestructiveDecision { cancel, confirm }

enum CertificateTrustDecision { cancel, trustAndSave }

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
}
