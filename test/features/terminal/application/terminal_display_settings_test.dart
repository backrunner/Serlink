import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/core/ids/entity_id.dart';
import 'package:serlink/features/terminal/application/terminal_display_settings.dart';
import 'package:serlink/features/vault/application/in_memory_vault_service.dart';
import 'package:serlink/features/vault/application/vault_record_repository.dart';
import 'package:serlink/features/vault/application/vault_service.dart';

void main() {
  test('terminal display settings expose selected text style and theme', () {
    const settings = TerminalDisplaySettings(
      themeId: SerlinkTerminalThemeId.highContrast,
      fontSize: 15,
      lineHeight: 1.3,
    );

    expect(settings.textStyle.fontSize, 15);
    expect(settings.textStyle.height, 1.3);
    expect(settings.terminalTheme.background, const Color(0xFF000000));
  });

  test('theme ids have human readable labels', () {
    expect(SerlinkTerminalThemeId.serlinkDark.label, 'Serlink Dark');
    expect(SerlinkTerminalThemeId.serlinkLight.label, 'Serlink Light');
    expect(SerlinkTerminalThemeId.highContrast.label, 'High Contrast');
  });

  test('terminal display settings round trip through json', () {
    const settings = TerminalDisplaySettings(
      themeId: SerlinkTerminalThemeId.serlinkLight,
      fontFamily: 'JetBrains Mono',
      fontSize: 16,
      lineHeight: 1.25,
    );

    final restored = TerminalDisplaySettings.fromJson(settings.toJson());

    expect(restored.themeId, settings.themeId);
    expect(restored.fontFamily, settings.fontFamily);
    expect(restored.fontSize, settings.fontSize);
    expect(restored.lineHeight, settings.lineHeight);
  });

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
      );

      await repository.save(settings);

      final restored = await repository.read();
      expect(restored!.themeId, SerlinkTerminalThemeId.highContrast);
      expect(restored.fontFamily, 'JetBrains Mono');
      expect(restored.fontSize, 18);
      expect(restored.lineHeight, 1.4);

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
