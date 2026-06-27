import 'package:flutter/widgets.dart';

import '../core/failure/app_failure.dart';
import '../features/vault/application/vault_service.dart';
import 'generated/app_localizations.dart';
import '../features/settings/application/app_language_settings.dart';

export 'generated/app_localizations.dart';

extension SerlinkLocalizations on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

AppLocalizations lookupSerlinkLocalizations(AppLanguage language) {
  final locale = switch (language) {
    AppLanguage.english => const Locale('en'),
    AppLanguage.japanese => const Locale('ja'),
    AppLanguage.simplifiedChinese => const Locale('zh'),
    AppLanguage.system => _supportedLocaleFor(
      WidgetsBinding.instance.platformDispatcher.locale,
    ),
  };
  return lookupAppLocalizations(locale);
}

Locale _supportedLocaleFor(Locale locale) {
  return switch (locale.languageCode) {
    'en' => const Locale('en'),
    'ja' => const Locale('ja'),
    'zh' => const Locale('zh'),
    _ => const Locale('en'),
  };
}

String localizedVaultExceptionMessage(AppLocalizations l10n, Object error) {
  if (error is! VaultException) {
    return error.toString();
  }
  return switch (error.code) {
    'vault.invalid_passphrase' => l10n.vaultInvalidPassphraseError,
    'vault.invalid_recovery_key' => l10n.vaultInvalidRecoveryKeyError,
    'vault.invalid_recovery_key_format' =>
      l10n.vaultInvalidRecoveryKeyFormatError,
    'vault.local_unlock_not_enabled' => l10n.vaultLocalUnlockNotEnabledError,
    'vault.local_unlock_failed' => l10n.vaultLocalUnlockFailedError,
    'vault.local_unlock_unavailable' => l10n.vaultLocalUnlockUnavailableError,
    'vault.empty_passphrase' => l10n.vaultEmptyPassphraseError,
    _ => error.message,
  };
}

String localizedSessionFailureMessage(
  AppLocalizations l10n,
  AppFailure failure,
) {
  return switch (failure.code) {
    'session.disconnected' => l10n.sessionDisconnectedMessage,
    'session.backgrounded' => l10n.sessionBackgroundedMessage,
    'connection.failed' => l10n.connectionFailedMessage,
    'connection_profile.vault_locked' =>
      l10n.connectionProfileVaultLockedMessage,
    'connection_profile.not_found' => l10n.connectionProfileNotFoundMessage,
    'connection_profile.host_not_found' =>
      l10n.connectionProfileHostNotFoundMessage,
    'connection_profile.identity_not_found' =>
      l10n.connectionProfileIdentityNotFoundMessage,
    'connection_profile.no_auth_methods' =>
      l10n.connectionProfileNoAuthMethodsMessage,
    'connection_profile.jump_chain_too_deep' =>
      l10n.connectionProfileJumpChainTooDeepMessage,
    'connection_profile.jump_cycle' => l10n.connectionProfileJumpCycleMessage,
    'connection_profile.ssh_agent_unsupported' =>
      l10n.connectionProfileSshAgentUnsupportedMessage,
    'connection_profile.hardware_key_unsupported' =>
      l10n.connectionProfileHardwareKeyUnsupportedMessage,
    'connection_profile.identity_secret_missing' =>
      l10n.connectionProfileIdentitySecretMissingMessage,
    'connection_profile.secret_not_found' =>
      l10n.connectionProfileSecretNotFoundMessage,
    'connection_profile.password_missing' =>
      l10n.connectionProfilePasswordMissingMessage,
    'connection_profile.private_key_missing' =>
      l10n.connectionProfilePrivateKeyMissingMessage,
    'connection_profile.certificate_missing' =>
      l10n.connectionProfileCertificateMissingMessage,
    'ssh_auth.agent_unavailable' => l10n.sshAuthAgentUnavailableMessage,
    'ssh_auth.hardware_key_unsupported' =>
      l10n.sshAuthHardwareKeyUnsupportedMessage,
    'ssh_auth.agent_empty' => l10n.sshAuthAgentEmptyMessage,
    'ssh_auth.empty' => l10n.sshAuthEmptyMessage,
    'ssh_auth.certificate_invalid' => l10n.sshAuthCertificateInvalidMessage,
    'local_terminal.exited' => l10n.localTerminalExitedMessage,
    'local_terminal.failed' => l10n.localTerminalFailedMessage,
    'local_terminal.shell_missing' => l10n.localTerminalShellMissingMessage,
    'local_terminal.start_failed' => l10n.localTerminalStartFailedMessage,
    _ => failure.message,
  };
}
