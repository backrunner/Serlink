import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/security/local_file_security.dart';

class SshConfigImportSettings {
  const SshConfigImportSettings({
    this.autoImport = false,
    this.initialScanCompleted = false,
    this.observedAliases = const {},
  });

  final bool autoImport;
  final bool initialScanCompleted;
  final Set<String> observedAliases;

  SshConfigImportSettings copyWith({
    bool? autoImport,
    bool? initialScanCompleted,
    Set<String>? observedAliases,
  }) {
    return SshConfigImportSettings(
      autoImport: autoImport ?? this.autoImport,
      initialScanCompleted: initialScanCompleted ?? this.initialScanCompleted,
      observedAliases: observedAliases ?? this.observedAliases,
    );
  }
}

abstract interface class SshConfigImportSettingsRepository {
  Future<SshConfigImportSettings> read();
  Future<void> save(SshConfigImportSettings settings);
  Future<SshConfigImportSettings> update(
    SshConfigImportSettings Function(SshConfigImportSettings current) transform,
  );
}

class FileSshConfigImportSettingsRepository
    implements SshConfigImportSettingsRepository {
  const FileSshConfigImportSettingsRepository();

  static Future<void> _pendingUpdate = Future<void>.value();

  static const _autoImportKey = 'sshConfigAutoImport';
  static const _initialScanCompletedKey = 'sshConfigInitialScanCompleted';
  static const _observedAliasesKey = 'sshConfigObservedAliases';

  @override
  Future<SshConfigImportSettings> read() async {
    final preferences = await _readPreferences();
    return _decodeSettings(preferences);
  }

  @override
  Future<void> save(SshConfigImportSettings settings) async {
    await update((_) => settings);
  }

  @override
  Future<SshConfigImportSettings> update(
    SshConfigImportSettings Function(SshConfigImportSettings current) transform,
  ) {
    final result = _pendingUpdate.then((_) async {
      final preferences = await _readPreferences();
      final settings = transform(_decodeSettings(preferences));
      final aliases = settings.observedAliases.toList()..sort();
      preferences
        ..[_autoImportKey] = settings.autoImport
        ..[_initialScanCompletedKey] = settings.initialScanCompleted
        ..[_observedAliasesKey] = aliases;
      await _writePreferences(preferences);
      return settings;
    });
    _pendingUpdate = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  SshConfigImportSettings _decodeSettings(Map<String, Object?> preferences) {
    final aliases = preferences[_observedAliasesKey];
    return SshConfigImportSettings(
      autoImport: preferences[_autoImportKey] == true,
      initialScanCompleted: preferences[_initialScanCompletedKey] == true,
      observedAliases: {
        if (aliases is List)
          for (final alias in aliases)
            if (alias is String && alias.trim().isNotEmpty)
              alias.trim().toLowerCase(),
      },
    );
  }

  Future<Map<String, Object?>> _readPreferences() async {
    final file = await _preferencesFile();
    if (!await file.exists()) {
      return <String, Object?>{};
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(await file.readAsString());
    } on FormatException {
      return <String, Object?>{};
    }
    if (decoded is! Map) {
      return <String, Object?>{};
    }
    return <String, Object?>{
      for (final entry in decoded.entries)
        if (entry.key is String) entry.key as String: entry.value,
    };
  }

  Future<void> _writePreferences(Map<String, Object?> preferences) async {
    final file = await _preferencesFile();
    await file.writeAsString(jsonEncode(preferences), flush: true);
    await LocalFileSecurity.restrictExistingFile(file);
  }

  Future<File> _preferencesFile() async {
    final appDir = await getApplicationSupportDirectory();
    final directory = Directory(p.join(appDir.path, 'Serlink'));
    await LocalFileSecurity.preparePrivateDirectory(directory);
    return File(p.join(directory.path, 'ssh-config-import.json'));
  }
}
