import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_dependencies.dart';
import '../../../core/ids/entity_id.dart';
import '../../vault/application/vault_record_repository.dart';
import '../../vault/application/vault_service.dart';
import '../domain/identity.dart';
import '../domain/identity_secret.dart';
import 'identity_repository.dart';

final identityWriteServiceProvider = Provider<IdentityWriteService>((ref) {
  return IdentityWriteService(
    identities: ref.watch(identityRepositoryProvider),
    records: ref.watch(vaultRecordRepositoryProvider),
    vault: ref.watch(vaultServiceProvider),
  );
});

class IdentityUpdateDraft {
  const IdentityUpdateDraft({
    required this.id,
    required this.displayName,
    this.usernameHint,
    this.password,
    this.privateKeyPem,
    this.privateKeyPassphrase,
    this.openSshCertificate,
    this.keyboardInteractiveResponses,
  });

  final IdentityId id;
  final String displayName;
  final String? usernameHint;
  final String? password;
  final String? privateKeyPem;
  final String? privateKeyPassphrase;
  final String? openSshCertificate;
  final List<String>? keyboardInteractiveResponses;
}

class IdentityWriteService {
  IdentityWriteService({
    required IdentityRepository identities,
    required VaultRecordRepository records,
    required VaultService vault,
  }) : this._(identities, records, vault);

  IdentityWriteService._(this._identities, this._records, this._vault);

  final IdentityRepository _identities;
  final VaultRecordRepository _records;
  final VaultService _vault;

  Future<IdentitySecretMaterial?> readSecretMaterial(
    IdentityConfig identity,
  ) async {
    final secretRecordId = identity.secretRecordId;
    if (secretRecordId == null) {
      return null;
    }
    final envelope = await _records.read(secretRecordId);
    if (envelope == null) {
      return null;
    }
    return IdentitySecretMaterial.fromBytes(
      await _vault.decryptRecord(envelope),
    );
  }

  Future<IdentityConfig> update(IdentityUpdateDraft draft) async {
    final existing = await _identities.read(draft.id);
    if (existing == null) {
      throw const IdentityWriteException(
        'identity.not_found',
        'Credential does not exist.',
      );
    }

    final displayName = draft.displayName.trim();
    if (displayName.isEmpty) {
      throw const IdentityWriteException(
        'identity.display_name_required',
        'Credential name is required.',
      );
    }

    final secret = _secretFor(existing.kind, draft);
    final secretRecordId = secret == null
        ? existing.secretRecordId
        : existing.secretRecordId ??
              VaultRecordId('secret:${existing.id.value}');
    if (secret != null) {
      final envelope = await _vault.encryptRecord(
        id: secretRecordId!,
        type: 'identity_secret',
        plaintext: secret.toBytes(),
      );
      await _records.upsert(envelope);
    }

    final updated = IdentityConfig(
      id: existing.id,
      displayName: displayName,
      kind: existing.kind,
      usernameHint: _blankToNull(draft.usernameHint),
      secretRecordId: secretRecordId,
      publicKeyFingerprint: existing.publicKeyFingerprint,
      certificatePrincipal: existing.kind == IdentityKind.openSshCertificate
          ? _certificateComment(draft.openSshCertificate)
          : existing.certificatePrincipal,
      createdAt: existing.createdAt,
      updatedAt: DateTime.now().toUtc(),
    );
    await _identities.save(updated);
    return updated;
  }

  IdentitySecretMaterial? _secretFor(
    IdentityKind kind,
    IdentityUpdateDraft draft,
  ) {
    return switch (kind) {
      IdentityKind.password => IdentitySecretMaterial(
        password: _requiredNonEmpty(
          draft.password,
          code: 'identity.password_required',
          message: 'Password is required.',
        ),
      ),
      IdentityKind.privateKey => IdentitySecretMaterial(
        privateKeyPem: _requiredPrivateKey(draft.privateKeyPem),
        privateKeyPassphrase: _blankToNull(draft.privateKeyPassphrase),
      ),
      IdentityKind.openSshCertificate => IdentitySecretMaterial(
        privateKeyPem: _requiredPrivateKey(draft.privateKeyPem),
        privateKeyPassphrase: _blankToNull(draft.privateKeyPassphrase),
        openSshCertificate: _requiredCertificate(draft.openSshCertificate),
      ),
      IdentityKind.keyboardInteractive => IdentitySecretMaterial(
        keyboardInteractiveResponses: _normalizeKeyboardResponses(
          draft.keyboardInteractiveResponses,
        ),
      ),
      IdentityKind.sshAgent || IdentityKind.hardwareKey => null,
    };
  }
}

List<String> _normalizeKeyboardResponses(List<String>? responses) {
  final normalized = [
    for (final response in responses ?? const <String>[])
      if (response.trim().isNotEmpty) response.trim(),
  ];
  if (normalized.isEmpty) {
    throw const IdentityWriteException(
      'identity.keyboard_responses_required',
      'At least one keyboard-interactive response is required.',
    );
  }
  return List<String>.unmodifiable(normalized);
}

String _requiredPrivateKey(String? value) {
  final privateKeyPem = value?.trim() ?? '';
  if (!_looksLikePrivateKey(privateKeyPem)) {
    throw const IdentityWriteException(
      'identity.private_key_invalid',
      'Private key must be an OpenSSH or PEM private key.',
    );
  }
  return privateKeyPem;
}

String _requiredCertificate(String? value) {
  final certificate = _normalizeCertificateText(value ?? '');
  final parts = certificate.split(RegExp(r'\s+'));
  if (parts.length < 2 || !parts.first.endsWith('-cert-v01@openssh.com')) {
    throw const IdentityWriteException(
      'identity.certificate_invalid',
      'Certificate must be an OpenSSH certificate public key line.',
    );
  }
  try {
    base64Decode(parts[1]);
  } on FormatException {
    throw const IdentityWriteException(
      'identity.certificate_invalid',
      'Certificate key payload is not valid base64.',
    );
  }
  return certificate;
}

String? _certificateComment(String? value) {
  final certificate = _normalizeCertificateText(value ?? '');
  if (certificate.isEmpty) {
    return null;
  }
  final parts = certificate.split(RegExp(r'\s+'));
  return parts.length > 2 ? parts.skip(2).join(' ') : null;
}

String _requiredNonEmpty(
  String? value, {
  required String code,
  required String message,
}) {
  if (value == null || value.isEmpty) {
    throw IdentityWriteException(code, message);
  }
  return value;
}

String? _blankToNull(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

String _normalizeCertificateText(String value) {
  return value.trim().split(RegExp(r'\s*\n\s*')).join(' ');
}

bool _looksLikePrivateKey(String value) {
  return value.contains('BEGIN') &&
      value.contains('PRIVATE KEY') &&
      value.contains('END');
}

class IdentityWriteException implements Exception {
  const IdentityWriteException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'IdentityWriteException($code): $message';
}
