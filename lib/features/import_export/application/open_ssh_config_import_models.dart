part of 'open_ssh_config_import_service.dart';

class _ProxyJumpResolution {
  const _ProxyJumpResolution({
    required this.hostIds,
    required this.unresolvedAliases,
  });

  final List<HostId> hostIds;
  final List<String> unresolvedAliases;
}

class _OpenSshConfigImportPlan {
  const _OpenSshConfigImportPlan({
    required this.entry,
    required this.username,
    required this.hostId,
    required this.identityIds,
    required this.authKinds,
  });

  final OpenSshConfigImportEntry entry;
  final String username;
  final HostId hostId;
  final List<IdentityId> identityIds;
  final Set<HostAuthKind> authKinds;
}

class _OpenSshHostBlock {
  _OpenSshHostBlock({required this.aliases, required this.lineNumber});

  final List<String> aliases;
  final int lineNumber;
  String? hostname;
  String? username;
  int? port;
  final List<String> identityFiles = [];
  final List<String> certificateFiles = [];
  String? proxyJump;
  String? proxyCommand;
  String? identityAgent;

  List<String> get importableAliases {
    return [
      for (final alias in aliases)
        if (!_isPatternAlias(alias) && alias != '*') alias,
    ];
  }

  int get skippedImportAliasCount {
    return aliases
        .where((alias) => _isPatternAlias(alias) && alias != '*')
        .length;
  }

  bool get hasUnsupportedImportPattern {
    return aliases.any((alias) => _isPatternAlias(alias) && alias != '*');
  }

  bool matchesAlias(String alias) {
    var matchedPositive = false;
    for (final pattern in aliases) {
      if (pattern.startsWith('!')) {
        final negated = pattern.substring(1);
        if (_hostPatternMatches(negated, alias)) {
          return false;
        }
        continue;
      }
      if (_hostPatternMatches(pattern, alias)) {
        matchedPositive = true;
      }
    }
    return matchedPositive;
  }
}

class _OpenSshEffectiveHost {
  _OpenSshEffectiveHost(this.alias);

  final String alias;
  String? hostname;
  String? username;
  int? port;
  final List<String> identityFiles = [];
  final List<String> certificateFiles = [];
  String? proxyJump;

  void apply(_OpenSshHostBlock block) {
    hostname ??= block.hostname;
    username ??= block.username;
    port ??= block.port;
    proxyJump ??= block.proxyJump;
    for (final identityFile in block.identityFiles) {
      if (!identityFiles.contains(identityFile)) {
        identityFiles.add(identityFile);
      }
    }
    for (final certificateFile in block.certificateFiles) {
      if (!certificateFiles.contains(certificateFile)) {
        certificateFiles.add(certificateFile);
      }
    }
  }

  OpenSshConfigImportEntry toEntry() {
    return OpenSshConfigImportEntry(
      alias: alias,
      hostname: hostname ?? alias,
      username: username,
      port: port ?? 22,
      identityFiles: List<String>.unmodifiable(identityFiles),
      certificateFiles: List<String>.unmodifiable(certificateFiles),
      proxyJump: proxyJump,
    );
  }
}

class _OpenSshIdentityResolution {
  const _OpenSshIdentityResolution({
    required this.identityIds,
    required this.authKinds,
    required this.importedCount,
  });

  const _OpenSshIdentityResolution.empty()
    : identityIds = const [],
      authKinds = const {},
      importedCount = 0;

  final List<IdentityId> identityIds;
  final Set<HostAuthKind> authKinds;
  final int importedCount;
}

class _ImportedOpenSshIdentity {
  const _ImportedOpenSshIdentity({required this.id, required this.authKind});

  final IdentityId id;
  final HostAuthKind authKind;
}
