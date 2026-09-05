import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/app/app_dependencies.dart';
import 'package:serlink/features/settings/application/app_language_settings.dart';

void main() {
  test(
    'concurrent language and privacy writes preserve both settings',
    () async {
      final directory = await Directory.systemTemp.createTemp('serlink-prefs-');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/preferences.json');
      await file.writeAsString(jsonEncode({'futurePreference': 'preserved'}));
      final language = FileAppLanguageSettingsRepository(preferencesFile: file);
      final privacy = FileAppLanguageSettingsRepository(preferencesFile: file);

      await Future.wait([
        language.save(AppLanguage.japanese),
        privacy.saveProtectBackground(true),
      ]);

      expect(await language.read(), AppLanguage.japanese);
      expect(await privacy.readProtectBackground(), isTrue);
      expect(
        jsonDecode(await file.readAsString())['futurePreference'],
        'preserved',
      );
      expect(await File('${file.path}.tmp').exists(), isFalse);
    },
  );

  test('a failed preference write does not block later updates', () async {
    final directory = await Directory.systemTemp.createTemp('serlink-prefs-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/preferences.json');
    final repository = FileAppLanguageSettingsRepository(preferencesFile: file);
    final blocker = Directory('${file.path}.tmp');
    await blocker.create();

    await expectLater(
      repository.save(AppLanguage.japanese),
      throwsA(isA<FileSystemException>()),
    );
    await blocker.delete();
    await repository.saveProtectBackground(true);
    expect(await repository.readProtectBackground(), isTrue);
  });

  test(
    'app language controller reads and saves the selected language',
    () async {
      final repository = _FakeAppLanguageSettingsRepository(
        AppLanguage.japanese,
      );
      final container = ProviderContainer(
        overrides: [
          appLanguageSettingsRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      expect(
        await container.read(appLanguageProvider.future),
        AppLanguage.japanese,
      );

      await container
          .read(appLanguageProvider.notifier)
          .setLanguage(AppLanguage.simplifiedChinese);

      expect(
        container.read(appLanguageProvider).value,
        AppLanguage.simplifiedChinese,
      );
      expect(repository.saved, AppLanguage.simplifiedChinese);
    },
  );

  test(
    'app language controller falls back to system when reading fails',
    () async {
      final container = ProviderContainer(
        overrides: [
          appLanguageSettingsRepositoryProvider.overrideWithValue(
            const _ThrowingAppLanguageSettingsRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(
        await container.read(appLanguageProvider.future),
        AppLanguage.system,
      );
    },
  );

  test(
    'background privacy controller reads and saves the selected setting',
    () async {
      final repository = _FakeAppPrivacySettingsRepository(enabled: true);
      final container = ProviderContainer(
        overrides: [
          appPrivacySettingsRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      expect(await container.read(appProtectBackgroundProvider.future), isTrue);

      await container
          .read(appProtectBackgroundProvider.notifier)
          .setProtectBackground(false);

      expect(container.read(appProtectBackgroundProvider).value, isFalse);
      expect(repository.saved, isFalse);
    },
  );

  test(
    'background privacy controller defaults to off when reading fails',
    () async {
      final container = ProviderContainer(
        overrides: [
          appPrivacySettingsRepositoryProvider.overrideWithValue(
            const _ThrowingAppPrivacySettingsRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(
        await container.read(appProtectBackgroundProvider.future),
        isFalse,
      );
    },
  );
}

class _FakeAppLanguageSettingsRepository
    implements AppLanguageSettingsRepository {
  _FakeAppLanguageSettingsRepository(this.language);

  AppLanguage language;
  AppLanguage? saved;

  @override
  Future<AppLanguage> read() async {
    return language;
  }

  @override
  Future<void> save(AppLanguage language) async {
    saved = language;
    this.language = language;
  }
}

class _ThrowingAppLanguageSettingsRepository
    implements AppLanguageSettingsRepository {
  const _ThrowingAppLanguageSettingsRepository();

  @override
  Future<AppLanguage> read() {
    throw StateError('preferences unavailable');
  }

  @override
  Future<void> save(AppLanguage language) async {}
}

class _FakeAppPrivacySettingsRepository
    implements AppPrivacySettingsRepository {
  _FakeAppPrivacySettingsRepository({required this.enabled});

  bool enabled;
  bool? saved;

  @override
  Future<bool> readProtectBackground() async {
    return enabled;
  }

  @override
  Future<void> saveProtectBackground(bool enabled) async {
    saved = enabled;
    this.enabled = enabled;
  }
}

class _ThrowingAppPrivacySettingsRepository
    implements AppPrivacySettingsRepository {
  const _ThrowingAppPrivacySettingsRepository();

  @override
  Future<bool> readProtectBackground() {
    throw StateError('preferences unavailable');
  }

  @override
  Future<void> saveProtectBackground(bool enabled) async {}
}
