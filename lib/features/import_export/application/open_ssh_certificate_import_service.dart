import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../../core/ids/entity_id.dart';
import '../../identities/application/identity_repository.dart';
import '../../identities/domain/identity.dart';
import '../../identities/domain/identity_secret.dart';
import '../../vault/application/vault_record_repository.dart';
import '../../vault/application/vault_service.dart';

class OpenSshCertificateImportDraft {
  const OpenSshCertificateImportDraft({
    required this.privateKeyPem,
    required this.certificateText,
    this.privateKeyPassphrase,
    this.displayName,
    this.usernameHint,
  });

  final String privateKeyPem;
  final String certificateText;
  final String? privateKeyPassphrase;
  final String? displayName;
  final String? usernameHint;
}

class OpenSshCertificateImportWarning {
  const OpenSshCertificateImportWarning({
    required this.code,
    required this.message,
  });

  final String code;
  final String message;
}

class OpenSshCertificateImportPreview {
  const OpenSshCertificateImportPreview({
    required this.algorithm,
    required this.comment,
    required this.warnings,
  });

  final String algorithm;
  final String? comment;
  final List<OpenSshCertificateImportWarning> warnings;
}

class OpenSshCertificateImportService {
  OpenSshCertificateImportService({
    required IdentityRepository identities,
    required VaultRecordRepository records,
    required VaultService vault,
    Uuid? uuid,
    DateTime Function()? now,
  }) : this._(
         identities,
         records,
         vault,
         uuid ?? const Uuid(),
         now ?? DateTime.now,
       );

  OpenSshCertificateImportService._(
    this._identities,
    this._records,
    this._vault,
    this._uuid,
    this._now,
  );

  final IdentityRepository _identities;
  final VaultRecordRepository _records;
  final VaultService _vault;
  final Uuid _uuid;
  final DateTime Function() _now;

  OpenSshCertificateImportPreview preview(OpenSshCertificateImportDraft draft) {
    final privateKeyPem = draft.privateKeyPem.trim();
    if (!_looksLikePrivateKey(privateKeyPem)) {
      throw const OpenSshCertificateImportException(
        'openssh_certificate.private_key_invalid',
        'Private key must be an OpenSSH or PEM private key.',
      );
    }
    final certificate = _parseCertificate(draft.certificateText);
    final warnings = <OpenSshCertificateImportWarning>[];
    if (certificate.comment == null || certificate.comment!.isEmpty) {
      warnings.add(
        const OpenSshCertificateImportWarning(
          code: 'openssh_certificate.comment_missing',
          message:
              'Certificate has no comment; use a clear display name before saving.',
        ),
      );
    }
    if (draft.privateKeyPassphrase != null &&
        draft.privateKeyPassphrase!.trim() != draft.privateKeyPassphrase) {
      warnings.add(
        const OpenSshCertificateImportWarning(
          code: 'openssh_certificate.passphrase_whitespace',
          message: 'Passphrase has leading or trailing whitespace.',
        ),
      );
    }
    return OpenSshCertificateImportPreview(
      algorithm: certificate.algorithm,
      comment: certificate.comment,
      warnings: List<OpenSshCertificateImportWarning>.unmodifiable(warnings),
    );
  }

  Future<IdentityConfig> importIdentity(
    OpenSshCertificateImportDraft draft,
  ) async {
    final preview = this.preview(draft);
    final privateKeyPem = draft.privateKeyPem.trim();
    final certificateText = _normalizeCertificateText(draft.certificateText);
    final now = _now().toUtc();
    final identityId = IdentityId(_uuid.v4());
    final secretRecordId = VaultRecordId('secret:${identityId.value}');
    final passphrase = draft.privateKeyPassphrase?.trim();

    final envelope = await _vault.encryptRecord(
      id: secretRecordId,
      type: 'identity_secret',
      plaintext: IdentitySecretMaterial(
        privateKeyPem: privateKeyPem,
        privateKeyPassphrase: passphrase == null || passphrase.isEmpty
            ? null
            : passphrase,
        openSshCertificate: certificateText,
      ).toBytes(),
    );
    await _records.upsert(envelope);

    final identity = IdentityConfig(
      id: identityId,
      displayName: _displayName(draft, preview),
      kind: IdentityKind.openSshCertificate,
      usernameHint: _blankToNull(draft.usernameHint),
      secretRecordId: secretRecordId,
      certificatePrincipal: preview.comment,
      createdAt: now,
      updatedAt: now,
    );
    await _identities.save(identity);
    return identity;
  }
}

class OpenSshCertificateImportException implements Exception {
  const OpenSshCertificateImportException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'OpenSshCertificateImportException($code): $message';
}

_OpenSshCertificateParts _parseCertificate(String value) {
  final normalized = _normalizeCertificateText(value);
  final parts = normalized.split(RegExp(r'\s+'));
  if (parts.length < 2 || !parts.first.endsWith('-cert-v01@openssh.com')) {
    throw const OpenSshCertificateImportException(
      'openssh_certificate.format_invalid',
      'Certificate must be an OpenSSH certificate public key line.',
    );
  }
  try {
    base64Decode(parts[1]);
  } on FormatException {
    throw const OpenSshCertificateImportException(
      'openssh_certificate.key_invalid',
      'Certificate key payload is not valid base64.',
    );
  }
  final comment = parts.length > 2 ? parts.skip(2).join(' ') : null;
  return _OpenSshCertificateParts(algorithm: parts.first, comment: comment);
}

String _normalizeCertificateText(String value) {
  return value.trim().split(RegExp(r'\s*\n\s*')).join(' ');
}

bool _looksLikePrivateKey(String value) {
  return value.contains('BEGIN') &&
      value.contains('PRIVATE KEY') &&
      value.contains('END');
}

String _displayName(
  OpenSshCertificateImportDraft draft,
  OpenSshCertificateImportPreview preview,
) {
  final explicit = _blankToNull(draft.displayName);
  if (explicit != null) {
    return explicit;
  }
  final comment = _blankToNull(preview.comment);
  return comment == null ? 'OpenSSH Certificate' : 'Certificate $comment';
}

String? _blankToNull(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

class _OpenSshCertificateParts {
  const _OpenSshCertificateParts({required this.algorithm, this.comment});

  final String algorithm;
  final String? comment;
}
