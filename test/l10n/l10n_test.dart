import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/features/settings/application/app_language_settings.dart';
import 'package:serlink/features/vault/application/vault_service.dart';
import 'package:serlink/l10n/l10n.dart';

void main() {
  test('localizes vault unlock failures by error code', () {
    const error = VaultException(
      'vault.invalid_passphrase',
      'Passphrase did not unlock the vault.',
    );

    expect(
      localizedVaultExceptionMessage(
        lookupSerlinkLocalizations(AppLanguage.english),
        error,
      ),
      'Passphrase did not unlock the vault.',
    );
    expect(
      localizedVaultExceptionMessage(
        lookupSerlinkLocalizations(AppLanguage.simplifiedChinese),
        error,
      ),
      '密码短语无法解锁保险库。',
    );
    expect(
      localizedVaultExceptionMessage(
        lookupSerlinkLocalizations(AppLanguage.japanese),
        error,
      ),
      'パスフレーズではボールトを解除できませんでした。',
    );
  });
}
