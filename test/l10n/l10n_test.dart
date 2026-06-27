import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/core/failure/app_failure.dart';
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

  test('localizes session connection failures by error code', () {
    const failure = AppFailure(
      code: 'connection_profile.vault_locked',
      message: 'Unlock the vault before starting a new connection.',
    );

    expect(
      localizedSessionFailureMessage(
        lookupSerlinkLocalizations(AppLanguage.english),
        failure,
      ),
      'Unlock the vault before starting a new connection.',
    );
    expect(
      localizedSessionFailureMessage(
        lookupSerlinkLocalizations(AppLanguage.simplifiedChinese),
        failure,
      ),
      '请先解锁保险库，再启动新的连接。',
    );
    expect(
      localizedSessionFailureMessage(
        lookupSerlinkLocalizations(AppLanguage.japanese),
        failure,
      ),
      '新しい接続を開始する前にボールトを解除してください。',
    );
  });

  test('falls back to failure message for unknown session failure codes', () {
    const failure = AppFailure(
      code: 'custom.failure',
      message: 'Custom error.',
    );

    expect(
      localizedSessionFailureMessage(
        lookupSerlinkLocalizations(AppLanguage.english),
        failure,
      ),
      'Custom error.',
    );
  });
}
