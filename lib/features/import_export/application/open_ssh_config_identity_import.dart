part of 'open_ssh_config_import_service.dart';

extension on OpenSshConfigImportService {
  Future<_OpenSshIdentityResolution> _resolveIdentityFiles(
    List<String> identityFiles, {
    required List<String> certificateFiles,
    required String? configSourcePath,
    required Map<String, _ImportedOpenSshIdentity> importedIdentityFiles,
    required String alias,
    required String username,
    required List<OpenSshConfigImportWarning> warnings,
  }) async {
    if (identityFiles.isEmpty) {
      if (certificateFiles.isNotEmpty) {
        warnings.add(
          OpenSshConfigImportWarning(
            lineNumber: 0,
            code: 'ssh_config.certificate_file_without_identity',
            message:
                'Host $alias references CertificateFile without IdentityFile; import the certificate manually or add the paired private key.',
          ),
        );
      }
      return const _OpenSshIdentityResolution.empty();
    }
    final identities = _identities;
    final records = _records;
    final vault = _vault;
    if (identities == null || records == null || vault == null) {
      warnings.add(
        OpenSshConfigImportWarning(
          lineNumber: 0,
          code: 'ssh_config.identity_file_pending',
          message:
              'Host $alias references identity files; import credentials separately.',
        ),
      );
      return const _OpenSshIdentityResolution.empty();
    }

    final identityIds = <IdentityId>[];
    final authKinds = <HostAuthKind>{};
    var importedCount = 0;
    final certificatePairing = _certificatePairing(
      identityFiles: identityFiles,
      certificateFiles: certificateFiles,
      alias: alias,
      warnings: warnings,
    );
    for (final identityFile in identityFiles) {
      final resolvedPath = _resolveIdentityPath(
        identityFile,
        configSourcePath: configSourcePath,
      );
      if (resolvedPath == null) {
        warnings.add(
          OpenSshConfigImportWarning(
            lineNumber: 0,
            code: 'ssh_config.identity_file_unresolved',
            message:
                'Host $alias references $identityFile; provide the config file path to import it automatically.',
          ),
        );
        continue;
      }
      final certificateFile = certificatePairing[identityFile];
      final resolvedCertificatePath = certificateFile == null
          ? null
          : _resolveIdentityPath(
              certificateFile,
              configSourcePath: configSourcePath,
            );
      if (certificateFile != null && resolvedCertificatePath == null) {
        warnings.add(
          OpenSshConfigImportWarning(
            lineNumber: 0,
            code: 'ssh_config.certificate_file_unresolved',
            message:
                'Host $alias references $certificateFile; provide the config file path to import it automatically.',
          ),
        );
      }
      final file = File(resolvedPath);
      if (!await file.exists()) {
        warnings.add(
          OpenSshConfigImportWarning(
            lineNumber: 0,
            code: 'ssh_config.identity_file_missing',
            message:
                'Host $alias references missing identity file $identityFile.',
          ),
        );
        continue;
      }
      final privateKeyPem = (await file.readAsString()).trim();
      if (!_looksLikePrivateKey(privateKeyPem)) {
        warnings.add(
          OpenSshConfigImportWarning(
            lineNumber: 0,
            code: 'ssh_config.identity_file_invalid',
            message:
                'Host $alias references $identityFile, but it is not an OpenSSH or PEM private key.',
          ),
        );
        continue;
      }
      var identityKind = IdentityKind.privateKey;
      var hostAuthKind = HostAuthKind.privateKey;
      String? certificateText;
      if (certificateFile != null && resolvedCertificatePath != null) {
        final certificate = File(resolvedCertificatePath);
        if (!await certificate.exists()) {
          warnings.add(
            OpenSshConfigImportWarning(
              lineNumber: 0,
              code: 'ssh_config.certificate_file_missing',
              message:
                  'Host $alias references missing certificate file $certificateFile.',
            ),
          );
        } else {
          final candidate = _normalizeCertificateText(
            await certificate.readAsString(),
          );
          if (!_looksLikeOpenSshCertificate(candidate)) {
            warnings.add(
              OpenSshConfigImportWarning(
                lineNumber: 0,
                code: 'ssh_config.certificate_file_invalid',
                message:
                    'Host $alias references $certificateFile, but it is not an OpenSSH certificate public key line.',
              ),
            );
          } else {
            certificateText = candidate;
            identityKind = IdentityKind.openSshCertificate;
            hostAuthKind = HostAuthKind.openSshCertificate;
          }
        }
      }
      final cacheKey = _identityImportCacheKey(
        resolvedPath,
        certificateText == null ? null : resolvedCertificatePath,
      );
      final existingIdentity = importedIdentityFiles[cacheKey];
      if (existingIdentity != null) {
        identityIds.add(existingIdentity.id);
        authKinds.add(existingIdentity.authKind);
        continue;
      }

      final now = _now().toUtc();
      final identityId = IdentityId(_uuid.v4());
      final secretRecordId = VaultRecordId('secret:${identityId.value}');
      final envelope = await vault.encryptRecord(
        id: secretRecordId,
        type: 'identity_secret',
        plaintext: IdentitySecretMaterial(
          privateKeyPem: privateKeyPem,
          openSshCertificate: certificateText,
        ).toBytes(),
      );
      await records.upsert(envelope);
      await identities.save(
        IdentityConfig(
          id: identityId,
          displayName: certificateText == null
              ? '$alias ${p.basename(resolvedPath)}'
              : '$alias ${p.basename(resolvedCertificatePath ?? resolvedPath)}',
          kind: identityKind,
          usernameHint: username,
          secretRecordId: secretRecordId,
          createdAt: now,
          updatedAt: now,
        ),
      );
      importedIdentityFiles[cacheKey] = _ImportedOpenSshIdentity(
        id: identityId,
        authKind: hostAuthKind,
      );
      identityIds.add(identityId);
      authKinds.add(hostAuthKind);
      importedCount += 1;
    }
    return _OpenSshIdentityResolution(
      identityIds: List<IdentityId>.unmodifiable(identityIds),
      authKinds: Set<HostAuthKind>.unmodifiable(authKinds),
      importedCount: importedCount,
    );
  }
}

String? _resolveIdentityPath(
  String identityFile, {
  required String? configSourcePath,
}) {
  final expanded = _expandHome(identityFile.trim());
  if (expanded.isEmpty) {
    return null;
  }
  if (p.isAbsolute(expanded)) {
    return p.normalize(expanded);
  }
  if (configSourcePath == null || configSourcePath.trim().isEmpty) {
    return null;
  }
  return p.normalize(p.join(p.dirname(configSourcePath), expanded));
}

List<String>? _resolveIncludePaths(
  String includePattern, {
  required String? configSourcePath,
}) {
  final expanded = _expandHome(includePattern.trim());
  if (expanded.isEmpty) {
    return const [];
  }
  if (!p.isAbsolute(expanded) &&
      (configSourcePath == null || configSourcePath.trim().isEmpty)) {
    return null;
  }
  final pattern = p.normalize(
    p.isAbsolute(expanded)
        ? expanded
        : p.join(p.dirname(configSourcePath!), expanded),
  );
  if (!_hasGlob(pattern)) {
    return File(pattern).existsSync() ? [pattern] : const [];
  }

  final baseDir = _globBaseDirectory(pattern);
  final directory = Directory(baseDir);
  if (!directory.existsSync()) {
    return const [];
  }
  final regex = _globPathRegex(pattern);
  final matches = <String>[];
  for (final entity in directory.listSync(
    recursive: true,
    followLinks: false,
  )) {
    if (entity is! File) {
      continue;
    }
    final normalized = p.normalize(entity.path);
    if (regex.hasMatch(normalized)) {
      matches.add(normalized);
    }
  }
  matches.sort();
  return List<String>.unmodifiable(matches);
}

String _expandHome(String path) {
  if (path == '~') {
    return Platform.environment['HOME'] ?? path;
  }
  if (path.startsWith('~/')) {
    final home = Platform.environment['HOME'];
    if (home == null || home.isEmpty) {
      return path;
    }
    return p.join(home, path.substring(2));
  }
  return path;
}

bool _looksLikePrivateKey(String value) {
  return value.contains('BEGIN') &&
      value.contains('PRIVATE KEY') &&
      value.contains('END');
}

bool _hasGlob(String path) => path.contains('*') || path.contains('?');

String _globBaseDirectory(String pattern) {
  final parts = p.split(pattern);
  final baseParts = <String>[];
  for (final part in parts) {
    if (part.contains('*') || part.contains('?')) {
      break;
    }
    baseParts.add(part);
  }
  if (baseParts.isEmpty) {
    return p.rootPrefix(pattern).isEmpty ? '.' : p.rootPrefix(pattern);
  }
  final joined = p.joinAll(baseParts);
  return joined.isEmpty ? p.current : joined;
}

RegExp _globPathRegex(String pattern) {
  final buffer = StringBuffer('^');
  for (var index = 0; index < pattern.length; index += 1) {
    final char = pattern[index];
    switch (char) {
      case '*':
        buffer.write(r'[^/\\]*');
      case '?':
        buffer.write(r'[^/\\]');
      default:
        buffer.write(RegExp.escape(char));
    }
  }
  buffer.write(r'$');
  return RegExp(buffer.toString(), caseSensitive: false);
}

Map<String, String> _certificatePairing({
  required List<String> identityFiles,
  required List<String> certificateFiles,
  required String alias,
  required List<OpenSshConfigImportWarning> warnings,
}) {
  if (certificateFiles.isEmpty || identityFiles.isEmpty) {
    return const {};
  }
  if (identityFiles.length == 1 && certificateFiles.length == 1) {
    return {identityFiles.single: certificateFiles.single};
  }
  if (identityFiles.length == certificateFiles.length) {
    return {
      for (var index = 0; index < identityFiles.length; index += 1)
        identityFiles[index]: certificateFiles[index],
    };
  }
  warnings.add(
    OpenSshConfigImportWarning(
      lineNumber: 0,
      code: 'ssh_config.certificate_file_ambiguous',
      message:
          'Host $alias has ${identityFiles.length} IdentityFile entries and ${certificateFiles.length} CertificateFile entries; import certificate credentials manually.',
    ),
  );
  return const {};
}

String _identityImportCacheKey(
  String identityFilePath,
  String? certificateFilePath,
) {
  return certificateFilePath == null
      ? identityFilePath
      : '$identityFilePath\n$certificateFilePath';
}

String _normalizeCertificateText(String value) {
  return value.trim().split(RegExp(r'\s*\n\s*')).join(' ');
}

bool _looksLikeOpenSshCertificate(String value) {
  final parts = value.split(RegExp(r'\s+'));
  if (parts.length < 2 || !parts.first.endsWith('-cert-v01@openssh.com')) {
    return false;
  }
  try {
    base64Decode(parts[1]);
    return true;
  } on FormatException {
    return false;
  }
}
