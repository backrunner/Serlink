import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/app/app_dependencies.dart';
import 'package:serlink/features/settings/application/app_language_settings.dart';

void main() {
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
