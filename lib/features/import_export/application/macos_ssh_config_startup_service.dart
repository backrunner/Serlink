import 'dart:io';

import 'package:path/path.dart' as p;

import '../../hosts/application/host_repository.dart';
import '../../hosts/domain/host.dart';
import '../../settings/application/ssh_config_import_settings.dart';
import 'open_ssh_config_import_service.dart';

class OpenSshConfigDocument {
  const OpenSshConfigDocument({required this.path, required this.contents});

  final String path;
  final String contents;
}

abstract interface class OpenSshConfigDocumentReader {
  Future<OpenSshConfigDocument?> read();
}

class MacOsOpenSshConfigDocumentReader implements OpenSshConfigDocumentReader {
  MacOsOpenSshConfigDocumentReader({String? homeDirectory})
    : _homeDirectory = homeDirectory ?? Platform.environment['HOME'];

  final String? _homeDirectory;

  @override
  Future<OpenSshConfigDocument?> read() async {
    final homeDirectory = _homeDirectory?.trim();
    if (homeDirectory == null || homeDirectory.isEmpty) {
      return null;
    }
    final path = p.join(homeDirectory, '.ssh', 'config');
    final file = File(path);
    if (!await file.exists()) {
      return null;
    }
    return OpenSshConfigDocument(
      path: path,
      contents: await file.readAsString(),
    );
  }
}

class MacOsSshConfigStartupScan {
  const MacOsSshConfigStartupScan({
    required this.sourcePath,
    required this.preview,
    required this.importPreview,
    required this.observedAliases,
    required this.initialScan,
    required this.autoImport,
  });

  final String sourcePath;
  final OpenSshConfigImportResult preview;
  final OpenSshConfigImportResult importPreview;
  final Set<String> observedAliases;
  final bool initialScan;
  final bool autoImport;

  bool get hasNewHosts => importPreview.entries.isNotEmpty;

  bool get shouldImportAutomatically => initialScan || autoImport;

  String get promptKey {
    return importPreview.entries
        .map((entry) => _normalizedAlias(entry.alias))
        .join('\n');
  }
}

enum MacOsSshConfigStartupPhase { idle, pending, importing, failed }

class MacOsSshConfigStartupState {
  const MacOsSshConfigStartupState._({
    required this.phase,
    this.scan,
    this.error,
  });

  const MacOsSshConfigStartupState.idle()
    : this._(phase: MacOsSshConfigStartupPhase.idle);

  const MacOsSshConfigStartupState.pending(MacOsSshConfigStartupScan scan)
    : this._(phase: MacOsSshConfigStartupPhase.pending, scan: scan);

  const MacOsSshConfigStartupState.importing(MacOsSshConfigStartupScan scan)
    : this._(phase: MacOsSshConfigStartupPhase.importing, scan: scan);

  const MacOsSshConfigStartupState.failed(Object error)
    : this._(phase: MacOsSshConfigStartupPhase.failed, error: error);

  final MacOsSshConfigStartupPhase phase;
  final MacOsSshConfigStartupScan? scan;
  final Object? error;

  bool get hasPendingPrompt =>
      phase == MacOsSshConfigStartupPhase.pending && scan != null;
}

class MacOsSshConfigStartupService {
  const MacOsSshConfigStartupService({
    required this._reader,
    required this._importer,
    required this._hosts,
  });

  final OpenSshConfigDocumentReader _reader;
  final OpenSshConfigImportService _importer;
  final HostRepository _hosts;

  Future<MacOsSshConfigStartupScan?> scan(
    SshConfigImportSettings settings,
  ) async {
    final document = await _reader.read();
    if (document == null) {
      return null;
    }
    final preview = _importer.preview(
      document.contents,
      configSourcePath: document.path,
    );
    final observedAliases = {
      for (final entry in preview.entries) _normalizedAlias(entry.alias),
    };
    final existingHosts = await _hosts.list();
    final importEntries = <OpenSshConfigImportEntry>[];
    for (final entry in preview.entries) {
      final alias = _normalizedAlias(entry.alias);
      final addedToConfig =
          !settings.initialScanCompleted ||
          !settings.observedAliases.contains(alias);
      if (!addedToConfig || _matchesExistingHost(entry, existingHosts)) {
        continue;
      }
      importEntries.add(entry);
    }
    return MacOsSshConfigStartupScan(
      sourcePath: document.path,
      preview: preview,
      importPreview: OpenSshConfigImportResult(
        entries: List<OpenSshConfigImportEntry>.unmodifiable(importEntries),
        skippedHosts: preview.skippedHosts,
        warnings: preview.warnings,
      ),
      observedAliases: Set<String>.unmodifiable(observedAliases),
      initialScan: !settings.initialScanCompleted,
      autoImport: settings.autoImport,
    );
  }

  Future<OpenSshConfigApplyResult> apply(
    MacOsSshConfigStartupScan scan, {
    String? defaultUsername,
  }) {
    return _importer.applyPreview(
      scan.importPreview,
      defaultUsername: defaultUsername,
      configSourcePath: scan.sourcePath,
    );
  }
}

String _normalizedAlias(String alias) => alias.trim().toLowerCase();

bool _matchesExistingHost(
  OpenSshConfigImportEntry entry,
  List<HostConfig> existingHosts,
) {
  final alias = _normalizedAlias(entry.alias);
  final hostname = entry.hostname.trim().toLowerCase();
  return existingHosts.any(
    (host) =>
        host.displayName.trim().toLowerCase() == alias ||
        (host.hostname.trim().toLowerCase() == hostname &&
            host.port == entry.port),
  );
}
