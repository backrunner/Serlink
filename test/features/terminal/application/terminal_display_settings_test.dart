import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:serlink/app/app_dependencies.dart';
import 'package:serlink/core/ids/entity_id.dart';
import 'package:serlink/features/terminal/application/terminal_display_settings.dart';
import 'package:serlink/features/terminal/application/terminal_font_discovery.dart';
import 'package:serlink/features/vault/application/in_memory_vault_service.dart';
import 'package:serlink/features/vault/application/vault_record_repository.dart';
import 'package:serlink/features/vault/application/vault_service.dart';

void main() {
  test('terminal display settings expose selected text style and theme', () {
    const settings = TerminalDisplaySettings(
      themeId: SerlinkTerminalThemeId.highContrast,
      fontSize: 15,
      lineHeight: 1.3,
      scrollbackLines: 20000,
    );

    expect(settings.textStyle.fontSize, 15);
    expect(settings.textStyle.height, 1.3);
    expect(settings.scrollbackLines, 20000);
    expect(settings.terminalTheme.background, const Color(0xFF000000));
  });

  test('terminal text style includes enhanced glyph fallbacks', () {
    const settings = TerminalDisplaySettings(
      fontFamily: 'JetBrainsMono Nerd Font',
    );

    expect(
      settings.textStyle.fontFamilyFallback,
      contains('Symbols Nerd Font Mono'),
    );
    expect(
      settings.textStyle.fontFamilyFallback,
      contains('Noto Sans Mono CJK SC'),
    );
    expect(
      settings.textStyle.fontFamilyFallback,
      isNot(contains('JetBrainsMono Nerd Font')),
    );
  });

  test('theme ids have human readable labels', () {
    expect(SerlinkTerminalThemeId.serlinkDark.label, 'Serlink Dark');
    expect(SerlinkTerminalThemeId.serlinkLight.label, 'Serlink Light');
    expect(SerlinkTerminalThemeId.highContrast.label, 'High Contrast');
  });

  test('font catalog prefers Nerd Fonts over ordinary monospace fonts', () {
    const catalog = TerminalFontCatalog(
      fonts: [
        TerminalFontCandidate(family: 'Menlo'),
        TerminalFontCandidate(family: 'Hack Nerd Font', isNerdFont: true),
        TerminalFontCandidate(family: 'monospace', isBuiltIn: true),
      ],
    );

    expect(catalog.hasNerdFont, isTrue);
    expect(catalog.preferredFontFamily, 'Hack Nerd Font');
  });

  test('font discovery detects Nerd Font file names', () async {
    final directory = await Directory.systemTemp.createTemp(
      'serlink_terminal_fonts_',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });
    await File(
      p.join(directory.path, 'JetBrainsMonoNerdFont-Regular.ttf'),
    ).create();

    final catalog = await TerminalFontDiscovery(
      fontDirectories: [directory.path],
    ).discover();

    expect(catalog.hasNerdFont, isTrue);
    expect(catalog.preferredFontFamily, 'JetBrainsMono Nerd Font');
  });

  test('global terminal settings default to discovered Nerd Font', () async {
    final directory = await Directory.systemTemp.createTemp(
      'serlink_terminal_fonts_',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });
    await File(p.join(directory.path, 'HackNerdFont-Regular.otf')).create();

    final container = ProviderContainer(
      overrides: [
        terminalDisplaySettingsRepositoryProvider.overrideWithValue(
          _FakeTerminalDisplaySettingsRepository(),
        ),
        terminalFontDiscoveryProvider.overrideWithValue(
          TerminalFontDiscovery(fontDirectories: [directory.path]),
        ),
      ],
    );
    addTearDown(container.dispose);

    final settings = await container.read(
      terminalDisplaySettingsProvider.future,
    );

    expect(settings.fontFamily, 'Hack Nerd Font');
  });

  test('terminal display settings round trip through json', () {
    const settings = TerminalDisplaySettings(
      themeId: SerlinkTerminalThemeId.serlinkLight,
      fontFamily: 'JetBrains Mono',
      fontSize: 16,
      lineHeight: 1.25,
      scrollbackLines: 40000,
    );

    final restored = TerminalDisplaySettings.fromJson(settings.toJson());

    expect(restored.themeId, settings.themeId);
    expect(restored.fontFamily, settings.fontFamily);
    expect(restored.fontSize, settings.fontSize);
    expect(restored.lineHeight, settings.lineHeight);
    expect(restored.scrollbackLines, settings.scrollbackLines);
  });

  test(
    'terminal display settings read legacy json with default scrollback',
    () {
      final restored = TerminalDisplaySettings.fromJson({
        'themeId': 'serlinkLight',
        'fontFamily': 'monospace',
        'fontSize': 14,
        'lineHeight': 1.2,
      });

      expect(restored.themeId, SerlinkTerminalThemeId.serlinkLight);
      expect(restored.scrollbackLines, 10000);
    },
  );

  test(
    'encrypted repository stores terminal settings without plaintext',
    () async {
      final vault = InMemoryVaultService(
        config: const VaultCryptoConfig.testing(),
      );
      await vault.initialize(passphrase: 'passphrase');
      final records = InMemoryVaultRecordRepository();
      final repository = EncryptedTerminalDisplaySettingsRepository(
        vault: vault,
        records: records,
      );
      const settings = TerminalDisplaySettings(
        themeId: SerlinkTerminalThemeId.highContrast,
        fontFamily: 'JetBrains Mono',
        fontSize: 18,
        lineHeight: 1.4,
        scrollbackLines: 50000,
      );

      await repository.save(settings);

      final restored = await repository.read();
      expect(restored!.themeId, SerlinkTerminalThemeId.highContrast);
      expect(restored.fontFamily, 'JetBrains Mono');
      expect(restored.fontSize, 18);
      expect(restored.lineHeight, 1.4);
      expect(restored.scrollbackLines, 50000);

      final envelopes = await records.list(
        type: EncryptedTerminalDisplaySettingsRepository.recordType,
      );
      expect(envelopes, hasLength(1));
      final serialized = jsonEncode(envelopes.single.toJson());
      expect(serialized, isNot(contains('JetBrains Mono')));
      expect(serialized, isNot(contains('highContrast')));
    },
  );

  test(
    'encrypted repository stores per-host profiles without plaintext',
    () async {
      final vault = InMemoryVaultService(
        config: const VaultCryptoConfig.testing(),
      );
      await vault.initialize(passphrase: 'passphrase');
      final records = InMemoryVaultRecordRepository();
      final repository = EncryptedTerminalDisplaySettingsRepository(
        vault: vault,
        records: records,
      );
      final hostId = HostId('host-1');
      const settings = TerminalDisplaySettings(
        themeId: SerlinkTerminalThemeId.serlinkLight,
        fontFamily: 'Serlink Test Mono',
        fontSize: 17,
        lineHeight: 1.35,
        scrollbackLines: 30000,
      );

      await repository.saveForHost(hostId, settings);

      final restored = await repository.readForHost(hostId);
      expect(restored, settings);

      final envelopes = await records.list(
        type: EncryptedTerminalDisplaySettingsRepository.hostProfileRecordType,
      );
      expect(envelopes, hasLength(1));
      final serialized = jsonEncode(envelopes.single.toJson());
      expect(serialized, isNot(contains('Serlink Test Mono')));
      expect(serialized, isNot(contains('serlinkLight')));

      await repository.deleteForHost(hostId);

      expect(await repository.readForHost(hostId), isNull);
    },
  );
}

class _FakeTerminalDisplaySettingsRepository
    implements TerminalDisplaySettingsRepository {
  TerminalDisplaySettings? settings;

  @override
  Future<void> delete() async {
    settings = null;
  }

  @override
  Future<TerminalDisplaySettings?> read() async {
    return settings;
  }

  @override
  Future<void> save(TerminalDisplaySettings settings) async {
    this.settings = settings;
  }
}
