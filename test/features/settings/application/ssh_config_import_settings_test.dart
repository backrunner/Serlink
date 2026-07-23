import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/app/app_dependencies.dart';
import 'package:serlink/features/settings/application/ssh_config_import_settings.dart';

void main() {
  test('auto-import controller reads and saves the selected setting', () async {
    final repository = _FakeRepository(
      const SshConfigImportSettings(autoImport: true),
    );
    final container = ProviderContainer(
      overrides: [
        sshConfigImportSettingsRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    expect(await container.read(appSshConfigAutoImportProvider.future), isTrue);

    await container
        .read(appSshConfigAutoImportProvider.notifier)
        .setAutoImport(false);

    expect(container.read(appSshConfigAutoImportProvider).value, isFalse);
    expect((await repository.read()).autoImport, isFalse);
  });

  test(
    'auto-import controller restores its previous value when saving fails',
    () async {
      final repository = _ThrowingRepository();
      final container = ProviderContainer(
        overrides: [
          sshConfigImportSettingsRepositoryProvider.overrideWithValue(
            repository,
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(
        await container.read(appSshConfigAutoImportProvider.future),
        isFalse,
      );

      await expectLater(
        container
            .read(appSshConfigAutoImportProvider.notifier)
            .setAutoImport(true),
        throwsStateError,
      );
      expect(container.read(appSshConfigAutoImportProvider).value, isFalse);
    },
  );

  test(
    'publishes auto-import changes only after persistence completes',
    () async {
      final repository = _GatedRepository();
      final container = ProviderContainer(
        overrides: [
          sshConfigImportSettingsRepositoryProvider.overrideWithValue(
            repository,
          ),
        ],
      );
      addTearDown(container.dispose);
      expect(
        await container.read(appSshConfigAutoImportProvider.future),
        isFalse,
      );

      final update = container
          .read(appSshConfigAutoImportProvider.notifier)
          .setAutoImport(true);
      await repository.updateStarted.future;

      expect(container.read(appSshConfigAutoImportProvider).value, isFalse);
      repository.allowUpdate.complete();
      await update;

      expect((await repository.read()).autoImport, isTrue);
      expect(container.read(appSshConfigAutoImportProvider).value, isTrue);
    },
  );
}

class _FakeRepository implements SshConfigImportSettingsRepository {
  _FakeRepository(this._settings);

  SshConfigImportSettings _settings;

  @override
  Future<SshConfigImportSettings> read() async => _settings;

  @override
  Future<void> save(SshConfigImportSettings settings) async {
    _settings = settings;
  }

  @override
  Future<SshConfigImportSettings> update(
    SshConfigImportSettings Function(SshConfigImportSettings current) transform,
  ) async {
    _settings = transform(_settings);
    return _settings;
  }
}

class _ThrowingRepository implements SshConfigImportSettingsRepository {
  @override
  Future<SshConfigImportSettings> read() async =>
      const SshConfigImportSettings();

  @override
  Future<void> save(SshConfigImportSettings settings) {
    throw StateError('preferences unavailable');
  }

  @override
  Future<SshConfigImportSettings> update(
    SshConfigImportSettings Function(SshConfigImportSettings current) transform,
  ) {
    throw StateError('preferences unavailable');
  }
}

class _GatedRepository implements SshConfigImportSettingsRepository {
  final Completer<void> updateStarted = Completer<void>();
  final Completer<void> allowUpdate = Completer<void>();
  SshConfigImportSettings _settings = const SshConfigImportSettings();

  @override
  Future<SshConfigImportSettings> read() async => _settings;

  @override
  Future<void> save(SshConfigImportSettings settings) async {
    _settings = settings;
  }

  @override
  Future<SshConfigImportSettings> update(
    SshConfigImportSettings Function(SshConfigImportSettings current) transform,
  ) async {
    updateStarted.complete();
    await allowUpdate.future;
    _settings = transform(_settings);
    return _settings;
  }
}
