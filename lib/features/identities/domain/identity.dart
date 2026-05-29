import '../../../core/ids/entity_id.dart';

enum IdentityKind {
  password,
  privateKey,
  keyboardInteractive,
  openSshCertificate,
  sshAgent,
  hardwareKey,
}

class IdentityConfig {
  const IdentityConfig({
    required this.id,
    required this.displayName,
    required this.kind,
    required this.createdAt,
    required this.updatedAt,
    this.usernameHint,
    this.secretRecordId,
    this.publicKeyFingerprint,
    this.certificatePrincipal,
  });

  final IdentityId id;
  final String displayName;
  final IdentityKind kind;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? usernameHint;
  final VaultRecordId? secretRecordId;
  final String? publicKeyFingerprint;
  final String? certificatePrincipal;

  Map<String, Object?> toJson() {
    return {
      'id': id.value,
      'displayName': displayName,
      'kind': kind.name,
      'usernameHint': usernameHint,
      'secretRecordId': secretRecordId?.value,
      'publicKeyFingerprint': publicKeyFingerprint,
      'certificatePrincipal': certificatePrincipal,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
    };
  }

  factory IdentityConfig.fromJson(Map<String, Object?> json) {
    return IdentityConfig(
      id: IdentityId(json['id'] as String),
      displayName: json['displayName'] as String,
      kind: IdentityKind.values.byName(json['kind'] as String),
      usernameHint: json['usernameHint'] as String?,
      secretRecordId: switch (json['secretRecordId']) {
        final String value => VaultRecordId(value),
        _ => null,
      },
      publicKeyFingerprint: json['publicKeyFingerprint'] as String?,
      certificatePrincipal: json['certificatePrincipal'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}
