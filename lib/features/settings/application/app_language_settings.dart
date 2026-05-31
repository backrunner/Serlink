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

class FileAppLanguageSettingsRepository
    implements AppLanguageSettingsRepository {
  const FileAppLanguageSettingsRepository();

  static const _languageKey = 'language';

  @override
  Future<AppLanguage> read() async {
    final file = await _preferencesFile();
    if (!await file.exists()) {
      return AppLanguage.system;
    }
    final json = jsonDecode(await file.readAsString());
    if (json is! Map<String, Object?>) {
      return AppLanguage.system;
    }
    return AppLanguage.fromJson(json[_languageKey]);
  }

  @override
  Future<void> save(AppLanguage language) async {
    final file = await _preferencesFile();
    await file.writeAsString(
      jsonEncode(<String, Object?>{_languageKey: language.name}),
      flush: true,
    );
    await LocalFileSecurity.restrictExistingFile(file);
  }

  Future<File> _preferencesFile() async {
    final appDir = await getApplicationSupportDirectory();
    final directory = Directory(p.join(appDir.path, 'Serlink'));
    await LocalFileSecurity.preparePrivateDirectory(directory);
    return File(p.join(directory.path, 'preferences.json'));
  }
}
