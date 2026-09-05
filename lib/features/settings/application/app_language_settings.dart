import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/security/local_file_security.dart';

enum AppLanguage {
  system(null),
  english(Locale('en')),
  simplifiedChinese(Locale('zh')),
  japanese(Locale('ja'));

  const AppLanguage(this.locale);

  final Locale? locale;

  static AppLanguage fromJson(Object? value) {
    if (value is! String) {
      return AppLanguage.system;
    }
    return AppLanguage.values.firstWhere(
      (language) => language.name == value,
      orElse: () => AppLanguage.system,
    );
  }
}

abstract interface class AppLanguageSettingsRepository {
  Future<AppLanguage> read();
  Future<void> save(AppLanguage language);
}

abstract interface class AppPrivacySettingsRepository {
  Future<bool> readProtectBackground();
  Future<void> saveProtectBackground(bool enabled);
}

class FileAppLanguageSettingsRepository
    implements AppLanguageSettingsRepository, AppPrivacySettingsRepository {
  const FileAppLanguageSettingsRepository({this.preferencesFile});

  final File? preferencesFile;

  static const _languageKey = 'language';
  static const _protectBackgroundKey = 'protectBackground';
  static Future<void> _pendingUpdate = Future<void>.value();

  @override
  Future<AppLanguage> read() async {
    await _pendingUpdate;
    final preferences = await _readPreferences();
    return AppLanguage.fromJson(preferences[_languageKey]);
  }

  @override
  Future<void> save(AppLanguage language) {
    return _updatePreference(_languageKey, language.name);
  }

  @override
  Future<bool> readProtectBackground() async {
    await _pendingUpdate;
    final preferences = await _readPreferences();
    return preferences[_protectBackgroundKey] == true;
  }

  @override
  Future<void> saveProtectBackground(bool enabled) {
    return _updatePreference(_protectBackgroundKey, enabled);
  }

  Future<void> _updatePreference(String key, Object value) {
    // Both repositories share this file, so serialize the entire read/update.
    final result = _pendingUpdate.then((_) async {
      final preferences = await _readPreferences();
      preferences[key] = value;
      await _writePreferences(preferences);
    });
    _pendingUpdate = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
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
    final temporary = File('${file.path}.tmp');
    try {
      await temporary.writeAsString(jsonEncode(preferences), flush: true);
      await LocalFileSecurity.restrictExistingFile(temporary);
      await temporary.rename(file.path);
    } finally {
      if (await temporary.exists()) {
        await temporary.delete();
      }
    }
  }

  Future<File> _preferencesFile() async {
    if (preferencesFile case final file?) {
      await LocalFileSecurity.preparePrivateDirectory(file.parent);
      return file;
    }
    final appDir = await getApplicationSupportDirectory();
    final directory = Directory(p.join(appDir.path, 'Serlink'));
    await LocalFileSecurity.preparePrivateDirectory(directory);
    return File(p.join(directory.path, 'preferences.json'));
  }
}
