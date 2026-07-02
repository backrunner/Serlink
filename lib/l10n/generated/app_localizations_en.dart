// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Serlink';

  @override
  String get navHosts => 'Hosts';

  @override
  String get navSessions => 'Sessions';

  @override
  String get navTransfers => 'Transfers';

  @override
  String get navSnippets => 'Snippets';

  @override
  String get navSettings => 'Settings';

  @override
  String get searchHostsPlaceholder => 'Search hosts, addresses, or tags';

  @override
  String get searchSnippetsPlaceholder => 'Search snippets and commands';

  @override
  String get searchSessionsPlaceholder => 'Search active sessions';

  @override
  String get searchTransfersPlaceholder => 'Search transfers';

  @override
  String get searchSettingsPlaceholder => 'Search settings';

  @override
  String get openLocalTerminalTooltip => 'Open local terminal tab';

  @override
  String get clearSearchTooltip => 'Clear search';

  @override
  String get vaultTitle => 'Vault';

  @override
  String get hostsTitle => 'Hosts';

  @override
  String get hostsLoading => 'Loading encrypted host records';

  @override
  String get hostsNoMatchesTitle => 'No Matches';

  @override
  String get hostsNoMatchesBody =>
      'No hosts match the current workspace search.';

  @override
  String get hostsDeleteTitle => 'Delete host?';

  @override
  String get hostsDeleteBody =>
      'This removes the host and any credentials that are not used by another host.';

  @override
  String get hostsDeleteAction => 'Delete';

  @override
  String get hostsDeletedSnack => 'Host deleted.';

  @override
  String get hostsDeleteFailedSnack => 'Host could not be deleted.';

  @override
  String get hostsAddTooltip => 'Add host';

  @override
  String get hostsSortTooltip => 'Sort hosts';

  @override
  String get hostsSortByName => 'Sort by name';

  @override
  String get hostsSortByLastConnected => 'Sort by last connection';

  @override
  String get hostsSortByAdded => 'Sort by date added';

  @override
  String get hostsEmptyTitle => 'No Hosts';

  @override
  String get hostsEmptyBody =>
      'Import SSH config or add hosts to start a session.';

  @override
  String get hostsAddAction => 'Add Host';

  @override
  String get sessionsEmptyTitle => 'No active tabs';

  @override
  String get sessionsEmptyBody =>
      'Open a host from Hosts to create a terminal or SFTP tab.';

  @override
  String get snippetsTitle => 'Snippets';

  @override
  String get snippetsLockedBody =>
      'Unlock the vault to manage command snippets.';

  @override
  String get snippetsLoading => 'Loading encrypted snippets.';

  @override
  String get snippetsNoMatchesBody =>
      'No snippets match the current workspace search.';

  @override
  String get snippetsAddTooltip => 'Add snippet';

  @override
  String get snippetsEmptyTitle => 'No Snippets';

  @override
  String get snippetsEmptyBody =>
      'Add command snippets to reuse frequent terminal commands.';

  @override
  String get snippetsAddAction => 'Add Snippet';

  @override
  String get transfersTitle => 'Transfers';

  @override
  String get transfersPreparing => 'Preparing transfer queue.';

  @override
  String get transfersEmptyTitle => 'No Transfers';

  @override
  String get transfersEmptyBody =>
      'SFTP uploads and downloads will appear here.';

  @override
  String get transfersNoMatchesBody =>
      'No transfer tasks match the current workspace search.';

  @override
  String transfersItemCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String transfersActiveCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count active',
      one: '1 active',
    );
    return '$_temp0';
  }

  @override
  String get transfersClearAction => 'Clear';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsSubtitle =>
      'Security, sync, import/export, and runtime controls.';

  @override
  String get settingsGeneralSection => 'General';

  @override
  String get settingsLanguageTitle => 'Language';

  @override
  String get settingsLanguageSubtitle => 'Choose the app display language.';

  @override
  String get settingsLanguageSystem => 'System';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsLanguageChinese => 'Simplified Chinese';

  @override
  String get settingsLanguageJapanese => 'Japanese';

  @override
  String get settingsLanguageSaved => 'Language updated.';

  @override
  String get settingsLanguageSaveFailed => 'Language could not be updated.';

  @override
  String get settingsSecuritySection => 'Security';

  @override
  String get settingsVaultTitle => 'Vault';

  @override
  String get settingsVaultPreparing => 'Preparing encrypted storage';

  @override
  String get settingsVaultWaitingICloud =>
      'Waiting for iCloud sync. Please wait.';

  @override
  String get settingsVaultNotCreatedPill => 'Vault not created';

  @override
  String get settingsVaultLockedPill => 'Vault locked';

  @override
  String get settingsVaultUnlockedPill => 'Vault unlocked';

  @override
  String get settingsVaultLoadingPill => 'Vault loading';

  @override
  String get settingsVaultNotCreated => 'Not created.';

  @override
  String get settingsVaultLocked =>
      'Locked. Existing connections keep running.';

  @override
  String get settingsVaultUnlocked =>
      'Unlocked for new connection profile resolution.';

  @override
  String get settingsLockAction => 'Lock';

  @override
  String get settingsRecoverResetAction => 'Recover / Reset';

  @override
  String get settingsLocalUnlockTitle => 'Face ID unlock';

  @override
  String get settingsLocalUnlockSemantics => 'Enable Face ID unlock';

  @override
  String get settingsLocalUnlockNeedsVault =>
      'Create the vault before enabling Face ID unlock.';

  @override
  String get settingsLocalUnlockEnabled =>
      'Enabled. Lock the vault to unlock with Face ID.';

  @override
  String get settingsLocalUnlockUnavailable =>
      'Face ID is not available on this device.';

  @override
  String get settingsLocalUnlockDisabled =>
      'Disabled. Passphrase or recovery key is required after lock.';

  @override
  String get settingsUnlockWithDeviceAction => 'Use Face ID';

  @override
  String get settingsBackgroundPrivacyTitle => 'Background privacy';

  @override
  String get settingsBackgroundPrivacySemantics =>
      'Show privacy screen in the background';

  @override
  String get settingsBackgroundPrivacyEnabled =>
      'On. Show a lock screen when Serlink is backgrounded.';

  @override
  String get settingsBackgroundPrivacyDisabled =>
      'Off. Keep the current screen visible in the background.';

  @override
  String get settingsBackgroundPrivacySaved => 'Background privacy updated.';

  @override
  String get settingsBackgroundPrivacySaveFailed =>
      'Background privacy could not be updated.';

  @override
  String get settingsCredentialsTitle => 'Credentials';

  @override
  String get settingsCredentialsLocked =>
      'Unlock the vault to review encrypted credentials.';

  @override
  String get settingsKnownHostsTitle => 'Known hosts';

  @override
  String get settingsKnownHostsLocked =>
      'Unlock the vault to review trusted host fingerprints.';

  @override
  String get settingsManageAction => 'Manage';

  @override
  String get settingsDataSection => 'Data';

  @override
  String get settingsImportExportTitle => 'Import / Export';

  @override
  String get settingsImportExportSubtitle =>
      'Backups, OpenSSH files, certificates, known_hosts, and metadata.';

  @override
  String get settingsOpenAction => 'Open';

  @override
  String get settingsRuntimeSection => 'Runtime';

  @override
  String get settingsDiagnosticBundleTitle => 'Diagnostic logs';

  @override
  String get settingsExportAction => 'Export';

  @override
  String get settingsAboutSection => 'About';

  @override
  String get settingsRepositoryOpenFailed =>
      'Repository link could not be opened.';

  @override
  String settingsAppVersionOnly(String version) {
    return 'Version $version';
  }

  @override
  String settingsAppVersionLabel(String version, String buildNumber) {
    return 'Version $version ($buildNumber)';
  }

  @override
  String get settingsAppVersionLoading => 'Loading version';

  @override
  String get settingsAppVersionUnavailable => 'Version unavailable';

  @override
  String get settingsEnableLocalUnlockTitle => 'Enable Face ID unlock?';

  @override
  String get settingsDisableLocalUnlockTitle => 'Disable Face ID unlock?';

  @override
  String get settingsEnableLocalUnlockBody =>
      'Serlink will store a random device key protected by Face ID. Your vault passphrase is not stored.';

  @override
  String get settingsDisableLocalUnlockBody =>
      'This removes this device key from Face ID protection. Existing connections keep running.';

  @override
  String get vaultEnableFaceIdUnlockTitle => 'Enable Face ID unlock?';

  @override
  String get vaultEnableFaceIdUnlockBody =>
      'Use Face ID to unlock this vault on this device. Serlink stores a random device key protected by Face ID, not your vault passphrase.';

  @override
  String get settingsEnableAction => 'Enable';

  @override
  String get settingsDisableAction => 'Disable';

  @override
  String get settingsLocalUnlockEnabledSnack =>
      'Face ID unlock enabled. Lock the vault to use Face ID.';

  @override
  String get settingsLocalUnlockVerifyFailedSnack =>
      'Face ID unlock could not be verified.';

  @override
  String get settingsLocalUnlockDisabledSnack => 'Face ID unlock disabled.';

  @override
  String get settingsLocalUnlockStillAvailableSnack =>
      'Face ID unlock is still available on this device.';

  @override
  String get settingsLocalUnlockUpdateFailed =>
      'Face ID unlock could not be updated.';

  @override
  String get copyAction => 'Copy';

  @override
  String get syncSectionTitle => 'Sync';

  @override
  String get syncLoadingSettings => 'Loading sync settings.';

  @override
  String get syncLoadingEncryptedSettings => 'Loading encrypted sync settings.';

  @override
  String get syncConfigureAction => 'Configure';

  @override
  String get syncEditAction => 'Edit';

  @override
  String get syncWebDavLocked =>
      'Unlock the vault to configure encrypted sync.';

  @override
  String get syncICloudChecking => 'Checking iCloud availability.';

  @override
  String get syncICloudLocked => 'Unlock the vault to sync through iCloud.';

  @override
  String get syncDevicesTitle => 'Devices';

  @override
  String get syncDevicesLoading => 'Loading encrypted device records.';

  @override
  String get syncViewAction => 'View';

  @override
  String get syncResetAction => 'Reset';

  @override
  String get syncRepairTitle => 'Sync repair';

  @override
  String get syncRepairAction => 'Repair';

  @override
  String get syncRepairClockTitle => 'Check local clock';

  @override
  String get syncRepairClockBody =>
      'The WebDAV certificate is not valid yet. Check this device clock and time zone, then let automatic sync retry.';

  @override
  String get syncRepairTrustCertificateTitle => 'Trust WebDAV certificate?';

  @override
  String get syncRepairTrustCertificateBody =>
      'The WebDAV server uses an untrusted certificate. Review the fingerprint before saving trust for this endpoint.';

  @override
  String get syncRepairRemoteRebuildTitle => 'Repair remote sync?';

  @override
  String get syncRepairRemoteRebuildBody =>
      'The remote manifest or record objects are incomplete or corrupted. Serlink can rebuild them from local encrypted records.';

  @override
  String get syncRepairInitializeRemoteTitle => 'Initialize remote sync?';

  @override
  String get syncRepairInitializeRemoteBody =>
      'The remote location has no Serlink manifest. Serlink can create one from this encrypted vault.';

  @override
  String get syncRepairReplaceRemoteTitle => 'Replace remote vault?';

  @override
  String get syncRepairReplaceRemoteBody =>
      'The remote location belongs to another vault. Replacing it will overwrite that remote Serlink sync set with this encrypted vault.';

  @override
  String get syncRepairRestoreLocalTitle => 'Restore local sync data?';

  @override
  String get syncRepairRestoreLocalBody =>
      'Local vault data needs recovery before remote sync can be rebuilt. Serlink can restore local encrypted records from the current remote sync set.';

  @override
  String get syncRemoteRepaired => 'Remote sync repaired.';

  @override
  String get syncWebDavCertificateTrustSaved =>
      'WebDAV certificate trust saved.';

  @override
  String get syncICloudEnabledSnack => 'iCloud sync enabled.';

  @override
  String get syncICloudPausedSnack => 'iCloud sync paused.';

  @override
  String get syncICloudRemoteVaultAdoptedSnack =>
      'iCloud already has a Serlink vault. Use that vault passphrase to finish syncing.';

  @override
  String syncConflictsResolvedSnack(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Resolved sync conflicts. Synced $count encrypted records.',
      one: 'Resolved sync conflicts. Synced 1 encrypted record.',
    );
    return '$_temp0';
  }

  @override
  String get syncSettingsLoadFailed => 'Sync settings could not be loaded.';

  @override
  String syncLocalTimeLabel(String time) {
    return 'Local time: $time';
  }

  @override
  String syncEndpointLabel(String endpoint) {
    return 'Endpoint: $endpoint';
  }

  @override
  String syncValidFromLabel(String time) {
    return 'Valid from: $time';
  }

  @override
  String syncValidUntilLabel(String time) {
    return 'Valid until: $time';
  }

  @override
  String get doneAction => 'Done';

  @override
  String get syncConflictsTitle => 'Sync conflicts';

  @override
  String syncConflictsSubtitle(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count encrypted records need review.',
      one: '1 encrypted record needs review.',
    );
    return '$_temp0';
  }

  @override
  String get syncReviewAction => 'Review';

  @override
  String get syncUseRemoteAction => 'Use remote';

  @override
  String get syncKeepLocalAction => 'Keep local';

  @override
  String get syncUseRemoteTitle => 'Use remote records?';

  @override
  String get syncKeepLocalTitle => 'Keep local records?';

  @override
  String get syncUseRemoteBody =>
      'Remote encrypted records will replace conflicting local records before syncing.';

  @override
  String get syncKeepLocalBody =>
      'Local encrypted records will overwrite conflicting remote records.';

  @override
  String get syncPausedICloudSubtitle =>
      'Paused. Encrypted records sync through your private iCloud database.';

  @override
  String get syncEnabledStatus => 'Enabled';

  @override
  String get syncPausedStatus => 'Paused';

  @override
  String get syncWebDavNotConfiguredSubtitle =>
      'Not configured. Encrypted manifest and records only.';

  @override
  String get syncHttpAllowedStatus => 'HTTP allowed';

  @override
  String get syncHttpsStatus => 'HTTPS';

  @override
  String get syncAutoSyncWaiting => 'auto-sync waiting';

  @override
  String get syncAutoSyncNeedsVault => 'create a vault to start syncing';

  @override
  String get syncAutoSyncNeedsUnlock => 'unlock the vault to continue syncing';

  @override
  String get syncAutoSyncReady => 'auto-sync ready';

  @override
  String syncLastSynced(String time) {
    return 'last synced $time';
  }

  @override
  String syncLastFailed(String time) {
    return 'sync failed at $time';
  }

  @override
  String get syncAutoSyncQueued => 'auto-sync queued';

  @override
  String get syncSyncingAutomatically => 'syncing automatically';

  @override
  String syncConflictCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count conflicts',
      one: '1 conflict',
    );
    return '$_temp0';
  }

  @override
  String get syncAutoSyncFailed => 'auto-sync failed';

  @override
  String get saveAction => 'Save';

  @override
  String get savingAction => 'Saving';

  @override
  String get closeAction => 'Close';

  @override
  String get removeAction => 'Remove';

  @override
  String get importAction => 'Import';

  @override
  String get deleteAction => 'Delete';

  @override
  String get renameAction => 'Rename';

  @override
  String get skipAction => 'Skip';

  @override
  String get pasteAction => 'Paste';

  @override
  String get confirmAction => 'Confirm';

  @override
  String get applyAction => 'Apply';

  @override
  String get createAction => 'Create';

  @override
  String get runAction => 'Run';

  @override
  String get pauseAction => 'Pause';

  @override
  String get resumeAction => 'Resume';

  @override
  String get retryAction => 'Retry';

  @override
  String get connectAction => 'Connect';

  @override
  String get chooseFolderAction => 'Choose Folder';

  @override
  String get loadingSemantics => 'Loading';

  @override
  String get securityWebDavCertificateChangedTitle =>
      'WebDAV Certificate Changed';

  @override
  String get securityTrustWebDavCertificateTitle => 'Trust WebDAV Certificate?';

  @override
  String get securityHostKeyChangedTitle => 'Host Key Changed';

  @override
  String get securityConfirmFingerprintTitle => 'Confirm Fingerprint';

  @override
  String securityAlgorithmLabel(String value) {
    return 'Algorithm: $value';
  }

  @override
  String securityPreviousLabel(String value) {
    return 'Previous: $value';
  }

  @override
  String securitySubjectLabel(String value) {
    return 'Subject: $value';
  }

  @override
  String securityIssuerLabel(String value) {
    return 'Issuer: $value';
  }

  @override
  String securityValidRangeLabel(String from, String to) {
    return 'Valid: $from to $to';
  }

  @override
  String get securityCertificateClockWarning =>
      'This certificate is not valid yet. Check this device clock before trusting it.';

  @override
  String get securityTrustOnceAction => 'Trust Once';

  @override
  String get securityTrustAndSaveAction => 'Trust and Save';

  @override
  String get securityEncryptedExport => 'Encrypted export';

  @override
  String get securityUnencryptedExport => 'Unencrypted export';

  @override
  String securitySensitiveFields(String fields) {
    return 'Sensitive fields: $fields';
  }

  @override
  String get securityCannotBeUndone => 'This action cannot be undone.';

  @override
  String get securityPasteMultipleLinesTitle => 'Paste multiple lines?';

  @override
  String securityPasteMultipleLinesBody(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lines will be sent to the active terminal.',
      one: '1 line will be sent to the active terminal.',
    );
    return '$_temp0';
  }

  @override
  String get hostEditTitle => 'Edit Host';

  @override
  String get hostAddTitle => 'Add Host';

  @override
  String get hostSectionConnection => 'Connection';

  @override
  String get hostSectionAuthentication => 'Authentication';

  @override
  String get hostSectionStartup => 'Startup';

  @override
  String get hostRemoteSessionTitle => 'Remote session';

  @override
  String get hostSectionRouting => 'Routing';

  @override
  String get hostSectionPortForwarding => 'Port forwarding';

  @override
  String get hostDisplayNameLabel => 'Display name';

  @override
  String get hostDisplayNameOptionalLabel => 'Display name (optional)';

  @override
  String get hostDisplayNameHostnameHint => 'Same as hostname';

  @override
  String get hostDisplayNameHostnameHelper =>
      'Leave blank to use the hostname.';

  @override
  String get hostHostnameLabel => 'Hostname';

  @override
  String get hostPortLabel => 'Port';

  @override
  String get hostUsernameLabel => 'Username';

  @override
  String get hostStartupCommandsLabel => 'Startup commands';

  @override
  String get hostRemoteSessionEnableTitle => 'Attach to tmux/screen';

  @override
  String get hostRemoteSessionManagerAuto => 'Auto';

  @override
  String get hostRemoteSessionManagerTmux => 'tmux';

  @override
  String get hostRemoteSessionManagerScreen => 'screen';

  @override
  String get hostRemoteSessionNameLabel => 'Session name';

  @override
  String get hostRemoteSessionCreateIfMissing => 'Create when missing';

  @override
  String get hostRemoteSessionFallbackToShell => 'Fall back to shell';

  @override
  String get hostTagsLabel => 'Tags';

  @override
  String get hostStartFolderLabel => 'Start folder';

  @override
  String get hostPrivateKeyLabel => 'Private key';

  @override
  String get hostImportPrivateKeyTooltip => 'Import private key';

  @override
  String get hostKeyPassphraseLabel => 'Key passphrase';

  @override
  String get hostAdvancedConnectionTitle => 'Connection options';

  @override
  String get hostPortForwardingLocalHint =>
      'Start these local forwards with every SSH session.';

  @override
  String get hostPortForwardingRemoteHint =>
      'Start these remote forwards with every SSH session.';

  @override
  String get hostPortForwardingDynamicHint =>
      'Start these SOCKS proxies with every SSH session.';

  @override
  String get hostTimeoutLabel => 'Timeout (s)';

  @override
  String get hostKeepaliveLabel => 'Keepalive (s)';

  @override
  String get hostAutoReconnectLabel => 'Auto reconnect';

  @override
  String get hostBackoffLabel => 'Backoff (s)';

  @override
  String get hostAuthPasswordSegment => 'Password';

  @override
  String get hostAuthKeySegment => 'Key';

  @override
  String get hostAuthAgentSegment => 'Agent';

  @override
  String get hostAuthSavedSegment => 'Saved';

  @override
  String get hostPasswordLabel => 'Password';

  @override
  String get hostShowPasswordTooltip => 'Show password';

  @override
  String get hostHidePasswordTooltip => 'Hide password';

  @override
  String get hostSshAgentNote =>
      'Uses identities from the local SSH agent. On macOS, keys loaded into ssh-agent can be backed by Keychain.';

  @override
  String get hostNoSavedCredentials =>
      'No saved credentials are available yet.';

  @override
  String get hostCredentialsHeading => 'Credentials';

  @override
  String get hostEditCredentialTooltip => 'Edit credential';

  @override
  String get hostCredentialOptionalNote =>
      'You can save the host without credentials and add one later.';

  @override
  String get hostJumpHostsHeading => 'Jump hosts';

  @override
  String get hostPortNumberError => 'Port must be a number.';

  @override
  String get hostSaveFailed => 'Host could not be saved.';

  @override
  String get hostConfigurationLoadFailed =>
      'Host configuration could not be loaded.';

  @override
  String get hostConnectionSettingsWholeNumbers =>
      'Connection settings must be whole numbers.';

  @override
  String get identityKindPassword => 'Password';

  @override
  String get identityKindPrivateKey => 'Private Key';

  @override
  String get identityKindKeyboard => 'Keyboard';

  @override
  String get identityKindCertificate => 'Certificate';

  @override
  String get identityKindSshAgent => 'SSH Agent';

  @override
  String get identityKindHardwareKey => 'Hardware Key';

  @override
  String identityUserLabel(String username) {
    return 'user $username';
  }

  @override
  String identityPrincipalLabel(String principal) {
    return 'principal $principal';
  }

  @override
  String get snippetInsertTooltip => 'Insert into active terminal';

  @override
  String get snippetRunTooltip => 'Run in active terminal';

  @override
  String get snippetEditTooltip => 'Edit snippet';

  @override
  String get snippetDeleteTooltip => 'Delete snippet';

  @override
  String get snippetDialogEditTitle => 'Edit Snippet';

  @override
  String get snippetDialogAddTitle => 'Add Snippet';

  @override
  String get snippetNameLabel => 'Name';

  @override
  String get snippetCommandLabel => 'Command';

  @override
  String get snippetTagsLabel => 'Tags';

  @override
  String get snippetConfirmBeforeRun => 'Confirm before run';

  @override
  String get snippetAddTagsHint => 'Add tags';

  @override
  String get snippetAddTagHint => 'Add tag';

  @override
  String get snippetRemoveTagTooltip => 'Remove tag';

  @override
  String get snippetRunTitle => 'Run snippet?';

  @override
  String get snippetDeleteTitle => 'Delete snippet?';

  @override
  String get snippetSaveFailed => 'Snippet could not be saved.';

  @override
  String get snippetSentSnack => 'Snippet sent to terminal.';

  @override
  String get snippetInsertedSnack => 'Snippet inserted into terminal.';

  @override
  String get snippetNoTerminalSnack => 'Open a connected terminal tab first.';

  @override
  String get snippetDeletedSnack => 'Snippet deleted.';

  @override
  String get snippetDeleteFailedSnack => 'Snippet could not be deleted.';

  @override
  String get syncDevicesDialogTitle => 'Sync Devices';

  @override
  String syncDeviceRemoveTitle(String name) {
    return 'Remove $name?';
  }

  @override
  String get syncDeviceRemoveBody =>
      'This removes the encrypted sync device record from this vault.';

  @override
  String get syncDeviceRemovedSnack => 'Sync device removed.';

  @override
  String get syncDeviceRemoveFailedSnack => 'Sync device could not be removed.';

  @override
  String get syncDeviceResetTitle => 'Reset sync device?';

  @override
  String get syncDeviceResetBody =>
      'This removes the current device registration from encrypted sync and creates a new local device identity. Other devices will see the old device as removed.';

  @override
  String get syncDeviceResetSnack =>
      'Sync device reset. A new registration will be created on the next sync.';

  @override
  String get syncDeviceResetFailedSnack => 'Sync device could not be reset.';

  @override
  String get syncDevicesEmptyTitle => 'No sync devices yet';

  @override
  String get syncDevicesEmptyBody =>
      'This device will be registered here after the first successful encrypted sync.';

  @override
  String get syncDeviceRemoveTooltip => 'Remove device';

  @override
  String get syncDevicesWillRegister =>
      'This device will be registered on first sync.';

  @override
  String syncDeviceSingleSubtitle(String name) {
    return '$name registered for encrypted sync.';
  }

  @override
  String syncDevicesRegisteredSubtitle(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count devices registered.',
      one: '1 device registered.',
    );
    return '$_temp0';
  }

  @override
  String syncDevicesMultipleSubtitle(num count, String name) {
    return '$count devices registered. Last writer: $name.';
  }

  @override
  String syncDeviceThisDevice(String name) {
    return '$name (this device)';
  }

  @override
  String syncDeviceSubtitle(String platform, String time) {
    return '$platform / last seen $time';
  }

  @override
  String get webDavSyncTitle => 'WebDAV Sync';

  @override
  String get webDavEndpointLabel => 'Endpoint';

  @override
  String get webDavEndpointHint => 'https://example.com/webdav';

  @override
  String get webDavUsernameLabel => 'Username';

  @override
  String get webDavPasswordLabel => 'Password';

  @override
  String get webDavPasswordKeepLabel => 'Password (leave blank to keep)';

  @override
  String get webDavBasePathLabel => 'Base path';

  @override
  String get webDavEnableTitle => 'Enable WebDAV sync';

  @override
  String get webDavAllowHttpTitle => 'Allow HTTP endpoint';

  @override
  String get webDavUseHttpTitle => 'Use HTTP WebDAV?';

  @override
  String get webDavUseHttpBody =>
      'HTTP sync can expose metadata and credentials in transit. Use only for trusted local test servers.';

  @override
  String get webDavAllowHttpAction => 'Allow HTTP';

  @override
  String get webDavSavedSnack => 'WebDAV sync settings saved.';

  @override
  String get webDavRemoveTitle => 'Remove WebDAV sync?';

  @override
  String get webDavRemoveBody =>
      'This removes the local WebDAV configuration and stored password.';

  @override
  String get webDavRemovedSnack => 'WebDAV sync settings removed.';

  @override
  String get credentialsDialogTitle => 'Credentials';

  @override
  String get credentialsEmptyTitle => 'No credentials stored';

  @override
  String get credentialsEmptyBody =>
      'Imported passwords, private keys, certificates, and identity metadata will appear here.';

  @override
  String get credentialsEditTooltip => 'Edit credential';

  @override
  String get credentialsDeleteTooltip => 'Delete credential';

  @override
  String get credentialUpdatedSnack => 'Credential updated.';

  @override
  String get credentialDeleteTitle => 'Delete credential?';

  @override
  String get credentialDeleteBody =>
      'This removes the credential and its encrypted secret material.';

  @override
  String credentialDeleteLinkedBody(String hosts) {
    return 'This credential is still linked to: $hosts. Delete it only after removing those host links.';
  }

  @override
  String get credentialDeletedSnack => 'Credential deleted.';

  @override
  String get credentialDeleteFailedSnack => 'Credential could not be deleted.';

  @override
  String get knownHostsDialogTitle => 'Known Hosts';

  @override
  String get knownHostsEmptyTitle => 'No trusted fingerprints';

  @override
  String get knownHostsEmptyBody =>
      'Host fingerprints accepted during connection review will be listed here.';

  @override
  String get knownHostDeleteTooltip => 'Delete known host';

  @override
  String get knownHostDeleteTitle => 'Delete known host?';

  @override
  String knownHostDeleteBody(String host) {
    return 'This removes the stored fingerprint for $host. The next connection will require confirmation again.';
  }

  @override
  String get knownHostDeletedSnack => 'Known host deleted.';

  @override
  String get knownHostDeleteFailedSnack => 'Known host could not be deleted.';

  @override
  String get startAction => 'Start';

  @override
  String get stopAction => 'Stop';

  @override
  String get uploadAction => 'Upload';

  @override
  String get downloadAction => 'Download';

  @override
  String get moveAction => 'Move';

  @override
  String get replaceAction => 'Replace';

  @override
  String get mergeAction => 'Merge';

  @override
  String get copiedAction => 'Copied';

  @override
  String get clearAllAction => 'Clear all';

  @override
  String get selectAllAction => 'Select all';

  @override
  String get restartAction => 'Restart';

  @override
  String get reconnectAction => 'Reconnect';

  @override
  String get windowCloseActiveTerminalsTitle => 'Close active terminals?';

  @override
  String windowCloseActiveTerminalsBody(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count active terminal panes are still running. Closing this window will disconnect them.',
      one:
          '1 active terminal pane is still running. Closing this window will disconnect it.',
    );
    return '$_temp0';
  }

  @override
  String get windowCloseWindowAction => 'Close Window';

  @override
  String get windowCloseLabel => 'Close window';

  @override
  String get windowMinimizeLabel => 'Minimize window';

  @override
  String get windowZoomLabel => 'Zoom window';

  @override
  String get hostEditMenu => 'Edit host';

  @override
  String get hostDuplicateMenu => 'Duplicate session';

  @override
  String get hostDuplicateTitle => 'Duplicate session';

  @override
  String get hostDeleteMenu => 'Delete host';

  @override
  String get hostTerminalAction => 'Terminal';

  @override
  String get hostSftpAction => 'SFTP';

  @override
  String get hostTrustTrusted => 'trusted';

  @override
  String get hostTrustVerify => 'verify';

  @override
  String get hostTrustChanged => 'changed';

  @override
  String get tabsCloseTooltip => 'Close tab';

  @override
  String get tabsNewConnectionTooltip => 'New connection';

  @override
  String get localShellInactive => 'Local shell is not running.';

  @override
  String get connectionInactive => 'Connection is not active.';

  @override
  String get sessionDisconnectedMessage =>
      'Connection interrupted. Reconnect starts a new session.';

  @override
  String get sessionBackgroundedMessage =>
      'Session was disconnected when Serlink entered the background. Reconnect starts a new session.';

  @override
  String get connectionFailedMessage => 'Connection failed.';

  @override
  String get connectionProfileVaultLockedMessage =>
      'Unlock the vault before starting a new connection.';

  @override
  String get connectionProfileNotFoundMessage =>
      'Connection profile could not be found.';

  @override
  String get connectionProfileHostNotFoundMessage => 'Host could not be found.';

  @override
  String get connectionProfileIdentityNotFoundMessage =>
      'Identity could not be found.';

  @override
  String get connectionProfileNoAuthMethodsMessage =>
      'This host has no identity configured.';

  @override
  String get connectionProfileJumpChainTooDeepMessage =>
      'Jump host chain has too many hops.';

  @override
  String get connectionProfileJumpCycleMessage =>
      'Jump host chain contains a cycle.';

  @override
  String get connectionProfileSshAgentUnsupportedMessage =>
      'SSH agent authentication is not available on this platform.';

  @override
  String get connectionProfileHardwareKeyUnsupportedMessage =>
      'Hardware key authentication is not available on this platform.';

  @override
  String get connectionProfileIdentitySecretMissingMessage =>
      'Identity does not reference a secret record.';

  @override
  String get connectionProfileSecretNotFoundMessage =>
      'Secret record could not be found.';

  @override
  String get connectionProfilePasswordMissingMessage =>
      'Identity does not contain a password.';

  @override
  String get connectionProfilePrivateKeyMissingMessage =>
      'Identity does not contain a private key.';

  @override
  String get connectionProfileCertificateMissingMessage =>
      'Identity does not contain an OpenSSH certificate.';

  @override
  String get sshAuthAgentUnavailableMessage => 'SSH agent is not available.';

  @override
  String get sshAuthHardwareKeyUnsupportedMessage =>
      'Hardware security key authentication requires platform support.';

  @override
  String get sshAuthAgentEmptyMessage => 'SSH agent has no loaded identities.';

  @override
  String get sshAuthEmptyMessage =>
      'Connection profile does not contain a supported authentication method.';

  @override
  String get sshAuthCertificateInvalidMessage =>
      'OpenSSH certificate material is invalid.';

  @override
  String get localTerminalExitedMessage =>
      'Local shell exited. Restart opens a new shell.';

  @override
  String get localTerminalFailedMessage => 'Local terminal failed.';

  @override
  String get localTerminalShellMissingMessage =>
      'No local shell executable was found.';

  @override
  String get localTerminalStartFailedMessage =>
      'Local terminal could not start.';

  @override
  String get localShellTitle => 'Local Shell';

  @override
  String get terminalSearchTooltip => 'Search terminal';

  @override
  String get terminalOpenSftpTooltip => 'Open SFTP tab';

  @override
  String get terminalSplitRightTooltip => 'Split right';

  @override
  String get terminalSplitDownTooltip => 'Split down';

  @override
  String get terminalClosePaneTooltip => 'Close pane';

  @override
  String terminalPaneSessionLabel(int index) {
    return 'Session $index';
  }

  @override
  String get terminalSettingsTitle => 'Terminal Settings';

  @override
  String get terminalForwardingUpdating => 'Updating port forwarding';

  @override
  String get terminalForwardingManage => 'Manage port forwarding';

  @override
  String terminalForwardingManageActive(num count) {
    return 'Manage port forwarding ($count active)';
  }

  @override
  String get terminalNoSearchResults => 'No results';

  @override
  String get terminalPreviousMatchTooltip => 'Previous match';

  @override
  String get terminalNextMatchTooltip => 'Next match';

  @override
  String get terminalCloseSearchTooltip => 'Close search';

  @override
  String get terminalAppearanceSection => 'Appearance';

  @override
  String get terminalThemeLabel => 'Theme';

  @override
  String get terminalLayoutSection => 'Layout';

  @override
  String get terminalFontSizeLabel => 'Font size';

  @override
  String get terminalLineHeightLabel => 'Line height';

  @override
  String get terminalScrollbackLabel => 'Scrollback';

  @override
  String get terminalSaveForHostAction => 'Save for host';

  @override
  String get terminalUseGlobalAction => 'Use global';

  @override
  String get terminalFontLabel => 'Font';

  @override
  String get terminalSearchFontsHint => 'Search fonts';

  @override
  String get terminalSelectFontHint => 'Select a font';

  @override
  String get terminalCustomFamilyLabel => 'Custom family';

  @override
  String get terminalCustomFamilyHelper =>
      'Type an installed font family, then apply.';

  @override
  String get terminalCustomFamilyHint => 'e.g. JetBrains Mono';

  @override
  String get terminalApplyCustomFontTooltip => 'Apply custom font';

  @override
  String get terminalScanningFonts => 'Scanning fonts';

  @override
  String get terminalNerdFontReady => 'Nerd Font ready';

  @override
  String get terminalNoNerdFont => 'No Nerd Font';

  @override
  String get terminalLifecycleRunning => 'Running';

  @override
  String get terminalLifecycleStarting => 'Starting';

  @override
  String get terminalLifecycleExited => 'Exited';

  @override
  String get terminalLifecycleFailed => 'Failed';

  @override
  String get terminalLifecycleStopping => 'Stopping';

  @override
  String get terminalLifecycleConnected => 'Connected';

  @override
  String get terminalLifecycleConnecting => 'Connecting';

  @override
  String get terminalLifecycleReconnecting => 'Reconnecting';

  @override
  String get terminalLifecycleDisconnected => 'Disconnected';

  @override
  String get terminalLifecyclePreparing => 'Preparing';

  @override
  String get terminalLifecycleVerifying => 'Verifying';

  @override
  String get terminalLifecycleAuthenticating => 'Authenticating';

  @override
  String get terminalLifecycleDisconnecting => 'Disconnecting';

  @override
  String get terminalLifecycleIdle => 'Idle';

  @override
  String get forwardingDialogTitle => 'Port Forwarding';

  @override
  String get forwardingLocalTitle => 'Local';

  @override
  String get forwardingLocalSubtitle =>
      'Expose a remote service on this device.';

  @override
  String get forwardingRemoteTitle => 'Remote';

  @override
  String get forwardingRemoteSubtitle =>
      'Expose a local service on the remote host.';

  @override
  String get forwardingSocksTitle => 'SOCKS Proxy';

  @override
  String get forwardingSocksSubtitle =>
      'Start a local dynamic proxy for this SSH session.';

  @override
  String get forwardingLocalPortLabel => 'Local port';

  @override
  String get forwardingRemoteHostLabel => 'Remote host';

  @override
  String get forwardingRemotePortLabel => 'Remote port';

  @override
  String get forwardingBindHostLabel => 'Bind host';

  @override
  String get forwardingBindPortLabel => 'Bind port';

  @override
  String get forwardingLocalHostLabel => 'Local host';

  @override
  String get forwardingLocalValidationError =>
      'Ports must be 1-65535 and remote host is required.';

  @override
  String get forwardingRemoteValidationError =>
      'Bind host, local host, and ports must be valid.';

  @override
  String get forwardingDynamicValidationError =>
      'Bind host and port must be valid.';

  @override
  String get forwardingLocalStartedSnack => 'Local port forward started.';

  @override
  String get forwardingLocalStartFailedSnack =>
      'Local port forward could not start.';

  @override
  String get forwardingLocalStoppedSnack => 'Local port forward stopped.';

  @override
  String get forwardingLocalStopFailedSnack =>
      'Local port forward could not stop.';

  @override
  String get forwardingRemoteStartedSnack => 'Remote port forward started.';

  @override
  String get forwardingRemoteStartFailedSnack =>
      'Remote port forward could not start.';

  @override
  String get forwardingRemoteStoppedSnack => 'Remote port forward stopped.';

  @override
  String get forwardingRemoteStopFailedSnack =>
      'Remote port forward could not stop.';

  @override
  String get forwardingSocksStartedSnack => 'SOCKS proxy started.';

  @override
  String get forwardingSocksStartFailedSnack => 'SOCKS proxy could not start.';

  @override
  String get forwardingSocksStoppedSnack => 'SOCKS proxy stopped.';

  @override
  String get forwardingSocksStopFailedSnack => 'SOCKS proxy could not stop.';

  @override
  String get vaultCreateTitle => 'Create Vault';

  @override
  String get vaultUnlockTitle => 'Unlock Vault';

  @override
  String get vaultCreateSubtitle =>
      'Use a strong passphrase for hosts and keys.';

  @override
  String get vaultUnlockSubtitle =>
      'Enter your passphrase to decrypt your workspace.';

  @override
  String get vaultNewPassphraseLabel => 'New passphrase';

  @override
  String get vaultPassphraseLabel => 'Passphrase';

  @override
  String get vaultCreateAction => 'Create Vault';

  @override
  String get vaultUnlockAction => 'Unlock';

  @override
  String get vaultUnlockWithDeviceAction => 'Use Face ID';

  @override
  String get vaultUseRecoveryCodeAction => 'Use recovery code';

  @override
  String get vaultPassphraseRequired => 'Enter a vault passphrase to continue.';

  @override
  String get vaultInvalidPassphraseError =>
      'Passphrase did not unlock the vault.';

  @override
  String get vaultInvalidRecoveryKeyError =>
      'Recovery key did not unlock the vault.';

  @override
  String get vaultInvalidRecoveryKeyFormatError =>
      'Recovery key format is not supported.';

  @override
  String get vaultLocalUnlockNotEnabledError =>
      'Face ID vault unlock is not enabled on this device.';

  @override
  String get vaultLocalUnlockFailedError =>
      'Face ID unlock failed. Use the vault passphrase.';

  @override
  String get vaultLocalUnlockUnavailableError =>
      'Face ID is not available on this device.';

  @override
  String get vaultEmptyPassphraseError => 'Vault passphrase cannot be empty.';

  @override
  String get vaultRecoveryKeyTitle => 'Recovery Key';

  @override
  String get vaultRecoveryKeySaveInstruction =>
      'Save this key before continuing.';

  @override
  String get vaultRecoveryKeyWarningTitle => 'Save this key now';

  @override
  String get vaultRecoveryKeyWarningBody =>
      'This key is shown only once. If it is lost, Serlink cannot retrieve it for you.';

  @override
  String get vaultCopyRecoveryKeyAction => 'Copy Recovery Key';

  @override
  String get vaultRecoveryKeySavedAction => 'I have saved it';

  @override
  String get vaultRecoveryTitle => 'Vault recovery';

  @override
  String get vaultRecoveryBody => 'Vault recovery tools are available.';

  @override
  String get vaultRecoveryDatabaseTitle => 'Database recovery';

  @override
  String get vaultRecoveryDatabaseBody =>
      'Serlink could not open this local database safely.';

  @override
  String get vaultRecoveryHeaderTitle => 'Vault header recovery';

  @override
  String get vaultRecoveryHeaderBody =>
      'The local vault header is invalid or incomplete.';

  @override
  String get vaultRecoveryRecordsTitle => 'Record recovery';

  @override
  String vaultRecoveryRecordsBody(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# encrypted records failed authentication.',
      one: '# encrypted record failed authentication.',
    );
    return '$_temp0';
  }

  @override
  String get vaultRecoveryRemoteTitle => 'Remote sync recovery';

  @override
  String get vaultRecoveryRemoteBody =>
      'The remote sync set needs repair before it can be used.';

  @override
  String get vaultRestoreLatestBackupAction => 'Restore latest backup';

  @override
  String get vaultQuarantineRecordsAction => 'Quarantine corrupt records';

  @override
  String get vaultCorruptRecordsQuarantinedSnack =>
      'Corrupt records quarantined.';

  @override
  String get vaultResetTitle => 'Reset Vault';

  @override
  String get vaultRecoveryCodeTitle => 'Recovery Code';

  @override
  String get vaultResetSubtitle =>
      'Reset only if you cannot unlock this vault with your passphrase or recovery code.';

  @override
  String get vaultRecoveryCodeSubtitle =>
      'Enter your recovery code to unlock this vault.';

  @override
  String get vaultRecoveryCodeLabel => 'Recovery code';

  @override
  String get vaultRecoveryCodeHelper => 'Paste the full recovery code.';

  @override
  String get vaultResetVaultAction => 'Reset vault';

  @override
  String get vaultResetPermanentlyAction => 'Reset Vault Permanently';

  @override
  String get vaultRecoveryCodeRequired => 'Enter a recovery code to continue.';

  @override
  String vaultResetTypePhraseError(String phrase) {
    return 'Type $phrase to confirm reset.';
  }

  @override
  String vaultResetTypePhraseLabel(String phrase) {
    return 'Type $phrase';
  }

  @override
  String get vaultResetPhraseHelper =>
      'The phrase is case-sensitive and required to reset.';

  @override
  String get vaultResetWarningTitle => 'This is permanent on this device';

  @override
  String get vaultResetWarningRecords =>
      'Encrypted hosts, identities, snippets, transfer history, sync settings, and recovery data will be deleted.';

  @override
  String get vaultResetWarningSyncedDevices =>
      'If this vault is synced, other devices using the same synced vault will also be reset and cleared.';

  @override
  String get vaultResetWarningSecrets =>
      'Reset does not recover your passphrase or reveal existing secrets.';

  @override
  String get vaultResetWarningBackup =>
      'You will need a backup or a new vault before continuing.';

  @override
  String get credentialEditTitle => 'Edit Credential';

  @override
  String get credentialLoadingSecretSemantics => 'Loading credential secret';

  @override
  String get credentialNameLabel => 'Credential name';

  @override
  String get credentialUsernameHintLabel => 'Username hint';

  @override
  String get credentialPasswordLabel => 'Password';

  @override
  String get credentialKeyboardResponsesLabel => 'Keyboard responses';

  @override
  String get credentialKeyboardResponsesHelper => 'One response per line.';

  @override
  String get credentialNoSecretMaterial =>
      'This credential has no stored secret material.';

  @override
  String get credentialSecretLoadFailed =>
      'Credential secret could not be loaded.';

  @override
  String get credentialSaveFailed => 'Credential could not be saved.';

  @override
  String get credentialSshPrivateKeyTypeLabel => 'SSH Private Key';

  @override
  String get credentialOpenSshCertificateTypeLabel => 'OpenSSH Certificate';

  @override
  String get credentialCertificateLabel => 'Certificate';

  @override
  String get credentialImportCertificateTooltip => 'Import certificate';

  @override
  String get syncConflictReviewDialogTitle => 'Review sync conflicts';

  @override
  String get syncConflictApplying => 'Applying';

  @override
  String get syncConflictApplyMergeAction => 'Apply merge';

  @override
  String get syncConflictLocalLabel => 'Local';

  @override
  String get syncConflictRemoteLabel => 'Remote';

  @override
  String get syncConflictUnsupportedBody =>
      'This record type currently requires whole-record resolution. Use the existing local or remote action for this conflict.';

  @override
  String get sftpParentFolderTooltip => 'Go to parent folder';

  @override
  String get sftpSearchPlaceholder => 'Search files';

  @override
  String get sftpHideHiddenFilesTooltip => 'Hide hidden files';

  @override
  String get sftpShowHiddenFilesTooltip => 'Show hidden files';

  @override
  String get sftpOpenTerminalTooltip => 'Open terminal tab';

  @override
  String get sftpUploadFileAction => 'Upload file';

  @override
  String get sftpUploadFolderAction => 'Upload folder';

  @override
  String get sftpNewFolderTooltip => 'New folder';

  @override
  String get sftpRefreshTooltip => 'Refresh';

  @override
  String get sftpWaitingTitle => 'SFTP';

  @override
  String get sftpWaitingBody => 'Waiting for the SFTP connection.';

  @override
  String get sftpStartFolderTitle => 'SFTP Start Folder';

  @override
  String sftpStartFolderBody(String path) {
    return 'Serlink could not list $path. Choose a folder this account can access.';
  }

  @override
  String get sftpErrorTitle => 'SFTP Error';

  @override
  String get sftpEmptyFolderTitle => 'Empty Folder';

  @override
  String get sftpNoEntriesFilter => 'No entries match the current filter.';

  @override
  String get sftpHiddenOnly =>
      'This remote directory only contains hidden entries.';

  @override
  String get sftpNoVisible => 'This remote directory has no visible entries.';

  @override
  String get sftpDirectoryLabel => 'Directory';

  @override
  String get sftpFileLabel => 'File';

  @override
  String get sftpSymlinkLabel => 'Symlink';

  @override
  String get sftpUnknownLabel => 'Unknown';

  @override
  String get sftpNewFolderTitle => 'New Folder';

  @override
  String get sftpFolderNameLabel => 'Folder name';

  @override
  String get sftpFolderCreatedSnack => 'Folder created.';

  @override
  String get sftpSelectedFileNoPathSnack => 'Selected file has no local path.';

  @override
  String get sftpUploadQueuedSnack => 'Upload queued.';

  @override
  String get sftpFolderUploadQueuedSnack => 'Folder upload queued.';

  @override
  String get sftpFolderDownloadQueuedSnack => 'Folder download queued.';

  @override
  String get sftpDownloadQueuedSnack => 'Download queued.';

  @override
  String get sftpMergeRemoteFolderTitle => 'Merge remote folder?';

  @override
  String get sftpReplaceRemoteFileTitle => 'Replace remote file?';

  @override
  String sftpRemoteExistsOverwriteBody(String path) {
    return '$path already exists on the server. Matching files may be overwritten.';
  }

  @override
  String sftpRemoteExistsBody(String path) {
    return '$path already exists on the server.';
  }

  @override
  String get sftpMergeLocalFolderTitle => 'Merge local folder?';

  @override
  String get sftpReplaceLocalFileTitle => 'Replace local file?';

  @override
  String sftpLocalExistsOverwriteBody(String path) {
    return '$path already exists on this device. Matching files may be overwritten.';
  }

  @override
  String sftpLocalExistsBody(String path) {
    return '$path already exists on this device.';
  }

  @override
  String get sftpNewNameLabel => 'New name';

  @override
  String get sftpTargetPathLabel => 'Target path';

  @override
  String get sftpTargetExistsSnack => 'Target path already exists.';

  @override
  String get sftpEntryRenamedSnack => 'Entry renamed.';

  @override
  String get sftpEntryMovedSnack => 'Entry moved.';

  @override
  String get sftpChangePermissionsTitle => 'Change permissions';

  @override
  String get sftpOctalPermissionsLabel => 'Permissions (octal or symbolic)';

  @override
  String get sftpPermissionsOctalError =>
      'Permissions must be octal, like 0644, or symbolic, like rw-r--r--.';

  @override
  String get sftpPermissionsUpdatedSnack => 'Permissions updated.';

  @override
  String sftpDeleteEntryTitle(String name) {
    return 'Delete $name?';
  }

  @override
  String get sftpDeleteDirectoryBody =>
      'This deletes the remote directory and its contents.';

  @override
  String get sftpDeleteFileBody => 'This deletes the remote file.';

  @override
  String get sftpEntryDeletedSnack => 'Entry deleted.';

  @override
  String get sftpFileSavedSnack => 'File saved.';

  @override
  String remoteFilePreviewLimited(String bytes) {
    return 'Preview limited to $bytes.';
  }

  @override
  String get sftpDefaultDirectoryDialogTitle => 'Choose SFTP Start Folder';

  @override
  String sftpDefaultDirectoryFailedMessage(String path, String reason) {
    return '$path could not be listed. $reason';
  }

  @override
  String get sftpStartFolderLabel => 'Start folder';

  @override
  String get sftpStartFolderHint => '/home/user';

  @override
  String get sftpAbsolutePathError => 'Enter an absolute remote path.';

  @override
  String get transferDeleteMenu => 'Delete transfer';

  @override
  String transferEtaLeft(String time) {
    return '$time left';
  }

  @override
  String get transferClearTitle => 'Clear transfers?';

  @override
  String transferClearBody(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Remove $count transfer records from history.',
      one: 'Remove 1 transfer record from history.',
    );
    return '$_temp0';
  }

  @override
  String transferClearActiveBody(num count, num activeCount) {
    return 'Remove $count transfer records from history and cancel $activeCount active transfers.';
  }

  @override
  String get transferClearedSnack => 'Transfers cleared.';

  @override
  String get transferRemoveLocalFailedSnack =>
      'Transfer removed, but the local file could not be deleted.';

  @override
  String get transferAndLocalDeletedSnack => 'Transfer and local file deleted.';

  @override
  String get transferDeletedSnack => 'Transfer deleted.';

  @override
  String get transferCompletedMissingSnack =>
      'Completed item is no longer available locally.';

  @override
  String get transferOpenFailedSnack => 'Completed item could not be opened.';

  @override
  String get transferDeleteTitle => 'Delete transfer?';

  @override
  String transferDeleteLocalBody(String kind, String path) {
    return 'A local $kind still exists at $path. Remove the transfer only, or also delete the local $kind?';
  }

  @override
  String get transferRemoveOnlyAction => 'Remove transfer';

  @override
  String transferDeleteLocalTooAction(String kind) {
    return 'Delete $kind too';
  }

  @override
  String transferMachineFrom(String name) {
    return 'From $name';
  }

  @override
  String transferMachineTo(String name) {
    return 'To $name';
  }

  @override
  String get transferRemoteMachineFallback => 'Remote machine';

  @override
  String get transferFolderKind => 'folder';

  @override
  String get transferLinkKind => 'link';

  @override
  String get transferFileKind => 'file';

  @override
  String transferBytesTransferred(String bytes) {
    return '$bytes transferred';
  }

  @override
  String get transferStateQueued => 'queued';

  @override
  String get transferStateRunning => 'running';

  @override
  String get transferStatePaused => 'paused';

  @override
  String get transferStateCompleted => 'completed';

  @override
  String get transferStateFailed => 'failed';

  @override
  String get transferStateCanceled => 'canceled';

  @override
  String get dataExchangeLockedSubtitle =>
      'Unlock the vault to use this action.';

  @override
  String get dataExchangeTitle => 'Import / Export';

  @override
  String get dataExchangeSubtitle =>
      'Backups stay available anytime. Host, identity, and SSH data require an unlocked vault.';

  @override
  String get dataExchangeExportSection => 'Export';

  @override
  String get dataExchangeImportSection => 'Import';

  @override
  String get dataExchangeExportBackupTitle => 'Export encrypted backup';

  @override
  String get dataExchangeExportBackupSubtitle =>
      'Encrypted vault records and header.';

  @override
  String get dataExchangeExportDiagnosticBundleTitle =>
      'Export diagnostic logs';

  @override
  String get dataExchangeExportDiagnosticBundleSubtitle =>
      'Redacted runtime details and failure clues.';

  @override
  String get dataExchangeExportHostMetadataTitle => 'Export host metadata';

  @override
  String get dataExchangeExportHostMetadataSubtitle =>
      'Host names, addresses, tags, and options.';

  @override
  String get dataExchangeExportOpenSshConfigTitle => 'Export OpenSSH config';

  @override
  String get dataExchangeExportOpenSshConfigSubtitle =>
      'Selected hosts as an OpenSSH config.';

  @override
  String get dataExchangeExportIdentityMetadataTitle =>
      'Export identity metadata';

  @override
  String get dataExchangeExportIdentityMetadataSubtitle =>
      'Display names, hints, and public fingerprints.';

  @override
  String get dataExchangeImportBackupTitle => 'Import encrypted backup';

  @override
  String get dataExchangeImportBackupSubtitle =>
      'Merge records from a Serlink backup.';

  @override
  String get dataExchangeImportOpenSshConfigTitle => 'Import OpenSSH config';

  @override
  String get dataExchangeImportOpenSshConfigSubtitle =>
      'Create hosts from an ssh config file.';

  @override
  String get dataExchangeImportKnownHostsTitle => 'Import known_hosts';

  @override
  String get dataExchangeImportKnownHostsSubtitle =>
      'Add fingerprints for existing hosts.';

  @override
  String get dataExchangeImportOpenSshCertificateTitle =>
      'Import OpenSSH certificate';

  @override
  String get dataExchangeImportOpenSshCertificateSubtitle =>
      'Create an identity from key and certificate.';

  @override
  String get exportVaultBackupTitle => 'Export encrypted backup?';

  @override
  String get exportVaultBackupBody =>
      'The backup contains encrypted vault records and the vault header. Keep it private.';

  @override
  String get backupExportedSnack => 'Encrypted backup exported.';

  @override
  String get noHostsAvailableExportSnack => 'No hosts are available to export.';

  @override
  String get exportHostMetadataTitle => 'Export host metadata?';

  @override
  String get exportHostMetadataBody =>
      'Exports host names, addresses, usernames, tags, jump host links, and connection options. Credentials and private key material are excluded.';

  @override
  String get hostMetadataExportedSnack => 'Host metadata exported.';

  @override
  String get hostMetadataExportFailedSnack =>
      'Host metadata could not be exported.';

  @override
  String get exportOpenSshConfigTitle => 'Export OpenSSH config?';

  @override
  String get exportOpenSshConfigBody =>
      'Exports selected hosts and any required jump hosts as an OpenSSH config. Credentials and private key material are excluded.';

  @override
  String get openSshConfigExportedSnack => 'OpenSSH config exported.';

  @override
  String get exportIdentityMetadataTitle => 'Export identity metadata?';

  @override
  String get identityMetadataExportedSnack => 'Identity metadata exported.';

  @override
  String get exportDiagnosticBundleTitle => 'Export diagnostic logs?';

  @override
  String get exportDiagnosticBundleBody =>
      'Diagnostic logs are redacted and exclude terminal output, commands, hosts, usernames, paths, credentials, and private keys.';

  @override
  String get diagnosticBundleExportedSnack => 'Diagnostic logs exported.';

  @override
  String get backupOperationFailed => 'Backup operation failed.';

  @override
  String get diagnosticExportFailed => 'Diagnostic logs could not be exported.';

  @override
  String get openSshConfigExportFailed =>
      'OpenSSH config could not be exported.';

  @override
  String get identityMetadataExportFailed =>
      'Identity metadata could not be exported.';

  @override
  String get importFailed => 'Import failed.';

  @override
  String get importEncryptedBackupTitle => 'Import encrypted backup?';

  @override
  String get importEncryptedBackupBody =>
      'This replaces the local vault header and merges encrypted records from the selected backup.';

  @override
  String get backupImportedSnack => 'Encrypted backup imported.';

  @override
  String get noImportableOpenSshHostsSnack =>
      'No importable OpenSSH hosts found.';

  @override
  String openSshHostsImportedSnack(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Imported $count hosts.',
      one: 'Imported 1 host.',
    );
    return '$_temp0';
  }

  @override
  String openSshHostsImportedSkippedSnack(num count, num skipped) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Imported $count hosts, skipped $skipped.',
      one: 'Imported 1 host, skipped $skipped.',
    );
    return '$_temp0';
  }

  @override
  String get importKnownHostsTitle => 'Import known_hosts?';

  @override
  String get importKnownHostsBody =>
      'Serlink will import fingerprints that match existing hosts by hostname and port. Hostnames and fingerprints are stored as encrypted vault records.';

  @override
  String knownHostsImportedSnack(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Imported $count fingerprints.',
      one: 'Imported 1 fingerprint.',
    );
    return '$_temp0';
  }

  @override
  String knownHostsImportedUnmatchedSnack(num count, num unmatched) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Imported $count fingerprints, $unmatched unmatched.',
      one: 'Imported 1 fingerprint, $unmatched unmatched.',
    );
    return '$_temp0';
  }

  @override
  String identityImportedSnack(String name) {
    return 'Imported $name.';
  }

  @override
  String get importOpenSshConfigTitle => 'Import OpenSSH config?';

  @override
  String openSshConfigHostsReady(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hosts ready to import.',
      one: '1 host ready to import.',
    );
    return '$_temp0';
  }

  @override
  String openSshConfigHostsReadySkipped(num count, num skipped) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hosts ready to import, $skipped skipped.',
      one: '1 host ready to import, $skipped skipped.',
    );
    return '$_temp0';
  }

  @override
  String get importWarningsTitle => 'Import warnings';

  @override
  String moreWarnings(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count more warnings.',
      one: '1 more warning.',
    );
    return '$_temp0';
  }

  @override
  String certificateDefaultName(String comment) {
    return 'Certificate $comment';
  }

  @override
  String get importOpenSshCertificateTitle => 'Import OpenSSH certificate?';

  @override
  String get importAlgorithmLabel => 'Algorithm';

  @override
  String get importCommentLabel => 'Comment';

  @override
  String get passphraseWhitespaceError =>
      'Passphrase cannot have leading or trailing spaces.';

  @override
  String get exportFieldHostnames => 'hostnames';

  @override
  String get exportFieldUsernames => 'usernames';

  @override
  String get exportFieldPorts => 'ports';

  @override
  String get exportFieldJumpHostAliases => 'jump host aliases';

  @override
  String get exportFieldConnectionSettings => 'connection settings';

  @override
  String get exportFieldDisplayNames => 'display names';

  @override
  String get exportFieldUsernameHints => 'username hints';

  @override
  String get exportFieldPublicKeyFingerprints => 'public key fingerprints';

  @override
  String get exportFieldCertificatePrincipals => 'certificate principals';

  @override
  String get cancelAction => 'Cancel';

  @override
  String get selectAction => 'Select';

  @override
  String get searchAction => 'Search';
}
