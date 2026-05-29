import 'dart:convert';

import '../../identities/application/identity_repository.dart';
import '../../identities/domain/identity.dart';

class IdentityMetadataExportBundle {
  const IdentityMetadataExportBundle({
    required this.formatVersion,
    required this.exportedAt,
    required this.identities,
  });

  final int formatVersion;
  final DateTime exportedAt;
  final List<IdentityMetadataExportRecord> identities;

  Map<String, Object?> toJson() {
    return {
      'formatVersion': formatVersion,
      'exportedAt': exportedAt.toUtc().toIso8601String(),
      'identities': [for (final identity in identities) identity.toJson()],
    };
  }

  List<int> toBytes() => utf8.encode(jsonEncode(toJson()));

  factory IdentityMetadataExportBundle.fromJson(Map<String, Object?> json) {
    return IdentityMetadataExportBundle(
      formatVersion: json['formatVersion'] as int,
      exportedAt: DateTime.parse(json['exportedAt'] as String),
      identities: [
        for (final value in json['identities'] as List<Object?>)
          IdentityMetadataExportRecord.fromJson(value as Map<String, Object?>),
      ],
    );
  }

  factory IdentityMetadataExportBundle.fromBytes(List<int> bytes) {
    return IdentityMetadataExportBundle.fromJson(
      jsonDecode(utf8.decode(bytes)) as Map<String, Object?>,
    );
  }
}

class IdentityMetadataExportRecord {
  const IdentityMetadataExportRecord({
    required this.identityId,
    required this.displayName,
    required this.kind,
    required this.createdAt,
    required this.updatedAt,
    this.usernameHint,
    this.publicKeyFingerprint,
    this.certificatePrincipal,
  });

  final String identityId;
  final String displayName;
  final String kind;
  final String? usernameHint;
  final String? publicKeyFingerprint;
  final String? certificatePrincipal;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, Object?> toJson() {
    return {
      'identityId': identityId,
      'displayName': displayName,
      'kind': kind,
      'usernameHint': usernameHint,
      'publicKeyFingerprint': publicKeyFingerprint,
      'certificatePrincipal': certificatePrincipal,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
    };
  }

  factory IdentityMetadataExportRecord.fromJson(Map<String, Object?> json) {
    return IdentityMetadataExportRecord(
      identityId: json['identityId'] as String,
      displayName: json['displayName'] as String,
      kind: json['kind'] as String,
      usernameHint: json['usernameHint'] as String?,
      publicKeyFingerprint: json['publicKeyFingerprint'] as String?,
      certificatePrincipal: json['certificatePrincipal'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

class IdentityMetadataExportService {
  IdentityMetadataExportService({
    required IdentityRepository identities,
    DateTime Function()? now,
  }) : this._(identities, now ?? DateTime.now);

  IdentityMetadataExportService._(this._identities, this._now);

  final IdentityRepository _identities;
  final DateTime Function() _now;

  Future<IdentityMetadataExportBundle> export() async {
    final identities = await _identities.list();
    identities.sort(
      (left, right) => left.displayName.toLowerCase().compareTo(
        right.displayName.toLowerCase(),
      ),
    );
    return IdentityMetadataExportBundle(
      formatVersion: 1,
      exportedAt: _now().toUtc(),
      identities: [for (final identity in identities) _toRecord(identity)],
    );
  }

  IdentityMetadataExportRecord _toRecord(IdentityConfig identity) {
    return IdentityMetadataExportRecord(
      identityId: identity.id.value,
      displayName: identity.displayName,
      kind: identity.kind.name,
      usernameHint: identity.usernameHint,
      publicKeyFingerprint: identity.publicKeyFingerprint,
      certificatePrincipal: identity.certificatePrincipal,
      createdAt: identity.createdAt,
      updatedAt: identity.updatedAt,
    );
  }
}
