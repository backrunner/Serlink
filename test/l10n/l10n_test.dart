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
      '请先解锁保险库，再启动新的连接',
    );
    expect(
      localizedSessionFailureMessage(
        lookupSerlinkLocalizations(AppLanguage.japanese),
        failure,
      ),
      '新しい接続を開始する前にボールトを解除してください。',
    );
  });

  test('keeps Chinese session failure messages without full stops', () {
    final l10n = lookupSerlinkLocalizations(AppLanguage.simplifiedChinese);
    const failures = [
      AppFailure(
        code: 'session.disconnected',
        message: 'Connection interrupted. Reconnect starts a new session.',
      ),
      AppFailure(
        code: 'session.backgrounded',
        message:
            'Session was disconnected when Serlink entered the background. Reconnect starts a new session.',
      ),
      AppFailure(code: 'connection.failed', message: 'Connection failed.'),
      AppFailure(
        code: 'connection_profile.vault_locked',
        message: 'Unlock the vault before starting a new connection.',
      ),
      AppFailure(
        code: 'connection_profile.not_found',
        message: 'Connection profile could not be found.',
      ),
      AppFailure(
        code: 'connection_profile.host_not_found',
        message: 'Host could not be found.',
      ),
      AppFailure(
        code: 'connection_profile.identity_not_found',
        message: 'Identity could not be found.',
      ),
      AppFailure(
        code: 'connection_profile.no_auth_methods',
        message: 'This host has no identity configured.',
      ),
      AppFailure(
        code: 'connection_profile.jump_chain_too_deep',
        message: 'Jump host chain is too deep.',
      ),
      AppFailure(
        code: 'connection_profile.jump_cycle',
        message: 'Jump host chain contains a cycle.',
      ),
      AppFailure(
        code: 'connection_profile.ssh_agent_unsupported',
        message: 'SSH agent authentication is not available on this platform.',
      ),
      AppFailure(
        code: 'connection_profile.hardware_key_unsupported',
        message: 'Hardware security key authentication needs platform support.',
      ),
      AppFailure(
        code: 'connection_profile.identity_secret_missing',
        message: 'Identity is not linked to a secret record.',
      ),
      AppFailure(
        code: 'connection_profile.secret_not_found',
        message: 'Secret record could not be found.',
      ),
      AppFailure(
        code: 'connection_profile.password_missing',
        message: 'Identity does not contain a password.',
      ),
      AppFailure(
        code: 'connection_profile.private_key_missing',
        message: 'Identity does not contain a private key.',
      ),
      AppFailure(
        code: 'connection_profile.certificate_missing',
        message: 'Identity does not contain an OpenSSH certificate.',
      ),
      AppFailure(
        code: 'ssh_auth.agent_unavailable',
        message: 'SSH agent is unavailable.',
      ),
      AppFailure(
        code: 'ssh_auth.hardware_key_unsupported',
        message: 'Hardware security key authentication needs platform support.',
      ),
      AppFailure(
        code: 'ssh_auth.agent_empty',
        message: 'SSH agent has no loaded identities.',
      ),
      AppFailure(
        code: 'ssh_auth.empty',
        message: 'Connection profile has no supported authentication method.',
      ),
      AppFailure(
        code: 'ssh_auth.certificate_invalid',
        message: 'OpenSSH certificate content is invalid.',
      ),
      AppFailure(
        code: 'local_terminal.exited',
        message: 'Local shell exited. Restart opens a new shell.',
      ),
      AppFailure(
        code: 'local_terminal.failed',
        message: 'Local terminal failed.',
      ),
      AppFailure(
        code: 'local_terminal.shell_missing',
        message: 'No local shell executable was found.',
      ),
      AppFailure(
        code: 'local_terminal.start_failed',
        message: 'Local terminal could not be started.',
      ),
    ];

    expect(l10n.localShellInactive, isNot(contains('。')));
    expect(l10n.connectionInactive, isNot(contains('。')));
    for (final failure in failures) {
      expect(
        localizedSessionFailureMessage(l10n, failure),
        isNot(contains('。')),
        reason: failure.code,
      );
    }
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
