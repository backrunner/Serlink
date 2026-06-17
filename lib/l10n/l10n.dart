import 'package:flutter/widgets.dart';

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
