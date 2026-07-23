import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ja'),
    Locale('zh'),
  ];

  /// Application title.
  ///
  /// In en, this message translates to:
  /// **'Serlink'**
  String get appTitle;

  /// No description provided for @navHosts.
  ///
  /// In en, this message translates to:
  /// **'Hosts'**
  String get navHosts;

  /// No description provided for @navSessions.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get navSessions;

  /// No description provided for @navTransfers.
  ///
  /// In en, this message translates to:
  /// **'Transfers'**
  String get navTransfers;

  /// No description provided for @navSnippets.
  ///
  /// In en, this message translates to:
  /// **'Snippets'**
  String get navSnippets;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @searchHostsPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Search hosts, addresses, or tags'**
  String get searchHostsPlaceholder;

  /// No description provided for @searchSnippetsPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Search snippets and commands'**
  String get searchSnippetsPlaceholder;

  /// No description provided for @searchSessionsPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Search active sessions'**
  String get searchSessionsPlaceholder;

  /// No description provided for @searchTransfersPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Search transfers'**
  String get searchTransfersPlaceholder;

  /// No description provided for @searchSettingsPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Search settings'**
  String get searchSettingsPlaceholder;

  /// No description provided for @openLocalTerminalTooltip.
  ///
  /// In en, this message translates to:
  /// **'Open local terminal tab'**
  String get openLocalTerminalTooltip;

  /// No description provided for @clearSearchTooltip.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get clearSearchTooltip;

  /// No description provided for @vaultTitle.
  ///
  /// In en, this message translates to:
  /// **'Vault'**
  String get vaultTitle;

  /// No description provided for @hostsTitle.
  ///
  /// In en, this message translates to:
  /// **'Hosts'**
  String get hostsTitle;

  /// No description provided for @hostsLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading encrypted host records'**
  String get hostsLoading;

  /// No description provided for @hostsNoMatchesTitle.
  ///
  /// In en, this message translates to:
  /// **'No Matches'**
  String get hostsNoMatchesTitle;

  /// No description provided for @hostsNoMatchesBody.
  ///
  /// In en, this message translates to:
  /// **'No hosts match the current workspace search.'**
  String get hostsNoMatchesBody;

  /// No description provided for @hostsDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete host?'**
  String get hostsDeleteTitle;

  /// No description provided for @hostsDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'This removes the host and any credentials that are not used by another host.'**
  String get hostsDeleteBody;

  /// No description provided for @hostsDeleteAction.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get hostsDeleteAction;

  /// No description provided for @hostsDeletedSnack.
  ///
  /// In en, this message translates to:
  /// **'Host deleted.'**
  String get hostsDeletedSnack;

  /// No description provided for @hostsDeleteFailedSnack.
  ///
  /// In en, this message translates to:
  /// **'Host could not be deleted.'**
  String get hostsDeleteFailedSnack;

  /// No description provided for @hostsAddTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add host'**
  String get hostsAddTooltip;

  /// No description provided for @hostsSortTooltip.
  ///
  /// In en, this message translates to:
  /// **'Sort hosts'**
  String get hostsSortTooltip;

  /// No description provided for @hostsSortByName.
  ///
  /// In en, this message translates to:
  /// **'Sort by name'**
  String get hostsSortByName;

  /// No description provided for @hostsSortByLastConnected.
  ///
  /// In en, this message translates to:
  /// **'Sort by last connection'**
  String get hostsSortByLastConnected;

  /// No description provided for @hostsSortByAdded.
  ///
  /// In en, this message translates to:
  /// **'Sort by date added'**
  String get hostsSortByAdded;

  /// No description provided for @hostsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No Hosts'**
  String get hostsEmptyTitle;

  /// No description provided for @hostsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Import SSH config or add hosts to start a session.'**
  String get hostsEmptyBody;

  /// No description provided for @hostsAddAction.
  ///
  /// In en, this message translates to:
  /// **'Add Host'**
  String get hostsAddAction;

  /// No description provided for @sessionsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No active tabs'**
  String get sessionsEmptyTitle;

  /// No description provided for @sessionsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Open a host from Hosts to create a terminal or SFTP tab.'**
  String get sessionsEmptyBody;

  /// No description provided for @snippetsTitle.
  ///
  /// In en, this message translates to:
  /// **'Snippets'**
  String get snippetsTitle;

  /// No description provided for @snippetsLockedBody.
  ///
  /// In en, this message translates to:
  /// **'Unlock the vault to manage command snippets.'**
  String get snippetsLockedBody;

  /// No description provided for @snippetsLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading encrypted snippets.'**
  String get snippetsLoading;

  /// No description provided for @snippetsNoMatchesBody.
  ///
  /// In en, this message translates to:
  /// **'No snippets match the current workspace search.'**
  String get snippetsNoMatchesBody;

  /// No description provided for @snippetsAddTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add snippet'**
  String get snippetsAddTooltip;

  /// No description provided for @snippetsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No Snippets'**
  String get snippetsEmptyTitle;

  /// No description provided for @snippetsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Add command snippets to reuse frequent terminal commands.'**
  String get snippetsEmptyBody;

  /// No description provided for @snippetsAddAction.
  ///
  /// In en, this message translates to:
  /// **'Add Snippet'**
  String get snippetsAddAction;

  /// No description provided for @transfersTitle.
  ///
  /// In en, this message translates to:
  /// **'Transfers'**
  String get transfersTitle;

  /// No description provided for @transfersPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing transfer queue.'**
  String get transfersPreparing;

  /// No description provided for @transfersEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No Transfers'**
  String get transfersEmptyTitle;

  /// No description provided for @transfersEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'SFTP uploads and downloads will appear here.'**
  String get transfersEmptyBody;

  /// No description provided for @transfersNoMatchesBody.
  ///
  /// In en, this message translates to:
  /// **'No transfer tasks match the current workspace search.'**
  String get transfersNoMatchesBody;

  /// No description provided for @transfersItemCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item} other{{count} items}}'**
  String transfersItemCount(num count);

  /// No description provided for @transfersActiveCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 active} other{{count} active}}'**
  String transfersActiveCount(num count);

  /// No description provided for @transfersClearAction.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get transfersClearAction;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Security, sync, import/export, and runtime controls.'**
  String get settingsSubtitle;

  /// No description provided for @settingsGeneralSection.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get settingsGeneralSection;

  /// No description provided for @settingsLanguageTitle.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguageTitle;

  /// No description provided for @settingsLanguageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose the app display language.'**
  String get settingsLanguageSubtitle;

  /// No description provided for @settingsLanguageSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsLanguageSystem;

  /// No description provided for @settingsLanguageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get settingsLanguageEnglish;

  /// No description provided for @settingsLanguageChinese.
  ///
  /// In en, this message translates to:
  /// **'Simplified Chinese'**
  String get settingsLanguageChinese;

  /// No description provided for @settingsLanguageJapanese.
  ///
  /// In en, this message translates to:
  /// **'Japanese'**
  String get settingsLanguageJapanese;

  /// No description provided for @settingsLanguageSaved.
  ///
  /// In en, this message translates to:
  /// **'Language updated.'**
  String get settingsLanguageSaved;

  /// No description provided for @settingsLanguageSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Language could not be updated.'**
  String get settingsLanguageSaveFailed;

  /// No description provided for @settingsSecuritySection.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get settingsSecuritySection;

  /// No description provided for @settingsVaultTitle.
  ///
  /// In en, this message translates to:
  /// **'Vault'**
  String get settingsVaultTitle;

  /// No description provided for @settingsVaultPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing encrypted storage'**
  String get settingsVaultPreparing;

  /// No description provided for @settingsVaultWaitingICloud.
  ///
  /// In en, this message translates to:
  /// **'Waiting for iCloud sync. Please wait.'**
  String get settingsVaultWaitingICloud;

  /// No description provided for @settingsVaultNotCreatedPill.
  ///
  /// In en, this message translates to:
  /// **'Vault not created'**
  String get settingsVaultNotCreatedPill;

  /// No description provided for @settingsVaultLockedPill.
  ///
  /// In en, this message translates to:
  /// **'Vault locked'**
  String get settingsVaultLockedPill;

  /// No description provided for @settingsVaultUnlockedPill.
  ///
  /// In en, this message translates to:
  /// **'Vault unlocked'**
  String get settingsVaultUnlockedPill;

  /// No description provided for @settingsVaultLoadingPill.
  ///
  /// In en, this message translates to:
  /// **'Vault loading'**
  String get settingsVaultLoadingPill;

  /// No description provided for @settingsVaultNotCreated.
  ///
  /// In en, this message translates to:
  /// **'Not created.'**
  String get settingsVaultNotCreated;

  /// No description provided for @settingsVaultLocked.
  ///
  /// In en, this message translates to:
  /// **'Locked. Existing connections keep running.'**
  String get settingsVaultLocked;

  /// No description provided for @settingsVaultUnlocked.
  ///
  /// In en, this message translates to:
  /// **'Unlocked for new connection profile resolution.'**
  String get settingsVaultUnlocked;

  /// No description provided for @settingsLockAction.
  ///
  /// In en, this message translates to:
  /// **'Lock'**
  String get settingsLockAction;

  /// No description provided for @settingsRecoverResetAction.
  ///
  /// In en, this message translates to:
  /// **'Recover / Reset'**
  String get settingsRecoverResetAction;

  /// No description provided for @settingsLocalUnlockTitle.
  ///
  /// In en, this message translates to:
  /// **'Face ID unlock'**
  String get settingsLocalUnlockTitle;

  /// No description provided for @settingsLocalUnlockSemantics.
  ///
  /// In en, this message translates to:
  /// **'Enable Face ID unlock'**
  String get settingsLocalUnlockSemantics;

  /// No description provided for @settingsLocalUnlockNeedsVault.
  ///
  /// In en, this message translates to:
  /// **'Create the vault before enabling Face ID unlock.'**
  String get settingsLocalUnlockNeedsVault;

  /// No description provided for @settingsLocalUnlockEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled. Lock the vault to unlock with Face ID.'**
  String get settingsLocalUnlockEnabled;

  /// No description provided for @settingsLocalUnlockUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Face ID is not available on this device.'**
  String get settingsLocalUnlockUnavailable;

  /// No description provided for @settingsLocalUnlockDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled. Passphrase or recovery key is required after lock.'**
  String get settingsLocalUnlockDisabled;

  /// No description provided for @settingsUnlockWithDeviceAction.
  ///
  /// In en, this message translates to:
  /// **'Use Face ID'**
  String get settingsUnlockWithDeviceAction;

  /// No description provided for @settingsBackgroundPrivacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Background privacy'**
  String get settingsBackgroundPrivacyTitle;

  /// No description provided for @settingsBackgroundPrivacySemantics.
  ///
  /// In en, this message translates to:
  /// **'Show privacy screen in the background'**
  String get settingsBackgroundPrivacySemantics;

  /// No description provided for @settingsBackgroundPrivacyEnabled.
  ///
  /// In en, this message translates to:
  /// **'On. Show a lock screen when Serlink is backgrounded.'**
  String get settingsBackgroundPrivacyEnabled;

  /// No description provided for @settingsBackgroundPrivacyDisabled.
  ///
  /// In en, this message translates to:
  /// **'Off. Keep the current screen visible in the background.'**
  String get settingsBackgroundPrivacyDisabled;

  /// No description provided for @settingsBackgroundPrivacySaved.
  ///
  /// In en, this message translates to:
  /// **'Background privacy updated.'**
  String get settingsBackgroundPrivacySaved;

  /// No description provided for @settingsBackgroundPrivacySaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Background privacy could not be updated.'**
  String get settingsBackgroundPrivacySaveFailed;

  /// No description provided for @settingsSshConfigAutoImportTitle.
  ///
  /// In en, this message translates to:
  /// **'SSH config auto-import'**
  String get settingsSshConfigAutoImportTitle;

  /// No description provided for @settingsSshConfigAutoImportSemantics.
  ///
  /// In en, this message translates to:
  /// **'Automatically import new SSH config hosts'**
  String get settingsSshConfigAutoImportSemantics;

  /// No description provided for @settingsSshConfigAutoImportEnabled.
  ///
  /// In en, this message translates to:
  /// **'On. New hosts from ~/.ssh/config are imported automatically.'**
  String get settingsSshConfigAutoImportEnabled;

  /// No description provided for @settingsSshConfigAutoImportDisabled.
  ///
  /// In en, this message translates to:
  /// **'Off. Serlink asks before importing new hosts.'**
  String get settingsSshConfigAutoImportDisabled;

  /// No description provided for @settingsSshConfigAutoImportSaved.
  ///
  /// In en, this message translates to:
  /// **'SSH config auto-import updated.'**
  String get settingsSshConfigAutoImportSaved;

  /// No description provided for @settingsSshConfigAutoImportSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'SSH config auto-import could not be updated.'**
  String get settingsSshConfigAutoImportSaveFailed;

  /// No description provided for @sshConfigNewHostsTitle.
  ///
  /// In en, this message translates to:
  /// **'New SSH config hosts'**
  String get sshConfigNewHostsTitle;

  /// No description provided for @sshConfigNewHostsBody.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 new host was found in ~/.ssh/config.} other{{count} new hosts were found in ~/.ssh/config.}}'**
  String sshConfigNewHostsBody(num count);

  /// No description provided for @sshConfigAutoImportFutureTitle.
  ///
  /// In en, this message translates to:
  /// **'Automatically import future additions'**
  String get sshConfigAutoImportFutureTitle;

  /// No description provided for @settingsCredentialsTitle.
  ///
  /// In en, this message translates to:
  /// **'Credentials'**
  String get settingsCredentialsTitle;

  /// No description provided for @settingsCredentialsLocked.
  ///
  /// In en, this message translates to:
  /// **'Unlock the vault to review encrypted credentials.'**
  String get settingsCredentialsLocked;

  /// No description provided for @settingsKnownHostsTitle.
  ///
  /// In en, this message translates to:
  /// **'Known hosts'**
  String get settingsKnownHostsTitle;

  /// No description provided for @settingsKnownHostsLocked.
  ///
  /// In en, this message translates to:
  /// **'Unlock the vault to review trusted host fingerprints.'**
  String get settingsKnownHostsLocked;

  /// No description provided for @settingsManageAction.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get settingsManageAction;

  /// No description provided for @settingsDataSection.
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get settingsDataSection;

  /// No description provided for @settingsImportExportTitle.
  ///
  /// In en, this message translates to:
  /// **'Import / Export'**
  String get settingsImportExportTitle;

  /// No description provided for @settingsImportExportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Backups, OpenSSH files, certificates, known_hosts, and metadata.'**
  String get settingsImportExportSubtitle;

  /// No description provided for @settingsOpenAction.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get settingsOpenAction;

  /// No description provided for @settingsRuntimeSection.
  ///
  /// In en, this message translates to:
  /// **'Runtime'**
  String get settingsRuntimeSection;

  /// No description provided for @settingsDiagnosticBundleTitle.
  ///
  /// In en, this message translates to:
  /// **'Diagnostic logs'**
  String get settingsDiagnosticBundleTitle;

  /// No description provided for @settingsExportAction.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get settingsExportAction;

  /// No description provided for @settingsAboutSection.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAboutSection;

  /// No description provided for @settingsRepositoryOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Repository link could not be opened.'**
  String get settingsRepositoryOpenFailed;

  /// No description provided for @settingsAppVersionOnly.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String settingsAppVersionOnly(String version);

  /// No description provided for @settingsAppVersionLabel.
  ///
  /// In en, this message translates to:
  /// **'Version {version} ({buildNumber})'**
  String settingsAppVersionLabel(String version, String buildNumber);

  /// No description provided for @settingsAppVersionLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading version'**
  String get settingsAppVersionLoading;

  /// No description provided for @settingsAppVersionUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Version unavailable'**
  String get settingsAppVersionUnavailable;

  /// No description provided for @settingsEnableLocalUnlockTitle.
  ///
  /// In en, this message translates to:
  /// **'Enable Face ID unlock?'**
  String get settingsEnableLocalUnlockTitle;

  /// No description provided for @settingsDisableLocalUnlockTitle.
  ///
  /// In en, this message translates to:
  /// **'Disable Face ID unlock?'**
  String get settingsDisableLocalUnlockTitle;

  /// No description provided for @settingsEnableLocalUnlockBody.
  ///
  /// In en, this message translates to:
  /// **'Serlink will store a random device key protected by Face ID. Your vault passphrase is not stored.'**
  String get settingsEnableLocalUnlockBody;

  /// No description provided for @settingsDisableLocalUnlockBody.
  ///
  /// In en, this message translates to:
  /// **'This removes this device key from Face ID protection. Existing connections keep running.'**
  String get settingsDisableLocalUnlockBody;

  /// No description provided for @vaultEnableFaceIdUnlockTitle.
  ///
  /// In en, this message translates to:
  /// **'Enable Face ID unlock?'**
  String get vaultEnableFaceIdUnlockTitle;

  /// No description provided for @vaultEnableFaceIdUnlockBody.
  ///
  /// In en, this message translates to:
  /// **'Use Face ID to unlock this vault on this device. Serlink stores a random device key protected by Face ID, not your vault passphrase.'**
  String get vaultEnableFaceIdUnlockBody;

  /// No description provided for @settingsEnableAction.
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get settingsEnableAction;

  /// No description provided for @settingsDisableAction.
  ///
  /// In en, this message translates to:
  /// **'Disable'**
  String get settingsDisableAction;

  /// No description provided for @settingsLocalUnlockEnabledSnack.
  ///
  /// In en, this message translates to:
  /// **'Face ID unlock enabled. Lock the vault to use Face ID.'**
  String get settingsLocalUnlockEnabledSnack;

  /// No description provided for @settingsLocalUnlockVerifyFailedSnack.
  ///
  /// In en, this message translates to:
  /// **'Face ID unlock could not be verified.'**
  String get settingsLocalUnlockVerifyFailedSnack;

  /// No description provided for @settingsLocalUnlockDisabledSnack.
  ///
  /// In en, this message translates to:
  /// **'Face ID unlock disabled.'**
  String get settingsLocalUnlockDisabledSnack;

  /// No description provided for @settingsLocalUnlockStillAvailableSnack.
  ///
  /// In en, this message translates to:
  /// **'Face ID unlock is still available on this device.'**
  String get settingsLocalUnlockStillAvailableSnack;

  /// No description provided for @settingsLocalUnlockUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Face ID unlock could not be updated.'**
  String get settingsLocalUnlockUpdateFailed;

  /// No description provided for @copyAction.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copyAction;

  /// No description provided for @syncSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get syncSectionTitle;

  /// No description provided for @syncLoadingSettings.
  ///
  /// In en, this message translates to:
  /// **'Loading sync settings.'**
  String get syncLoadingSettings;

  /// No description provided for @syncLoadingEncryptedSettings.
  ///
  /// In en, this message translates to:
  /// **'Loading encrypted sync settings.'**
  String get syncLoadingEncryptedSettings;

  /// No description provided for @syncConfigureAction.
  ///
  /// In en, this message translates to:
  /// **'Configure'**
  String get syncConfigureAction;

  /// No description provided for @syncEditAction.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get syncEditAction;

  /// No description provided for @syncWebDavLocked.
  ///
  /// In en, this message translates to:
  /// **'Unlock the vault to configure encrypted sync.'**
  String get syncWebDavLocked;

  /// No description provided for @syncICloudChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking iCloud availability.'**
  String get syncICloudChecking;

  /// No description provided for @syncICloudLocked.
  ///
  /// In en, this message translates to:
  /// **'Unlock the vault to sync through iCloud.'**
  String get syncICloudLocked;

  /// No description provided for @syncDevicesTitle.
  ///
  /// In en, this message translates to:
  /// **'Devices'**
  String get syncDevicesTitle;

  /// No description provided for @syncDevicesLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading encrypted device records.'**
  String get syncDevicesLoading;

  /// No description provided for @syncViewAction.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get syncViewAction;

  /// No description provided for @syncResetAction.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get syncResetAction;

  /// No description provided for @syncRepairTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync repair'**
  String get syncRepairTitle;

  /// No description provided for @syncRepairAction.
  ///
  /// In en, this message translates to:
  /// **'Repair'**
  String get syncRepairAction;

  /// No description provided for @syncRepairClockTitle.
  ///
  /// In en, this message translates to:
  /// **'Check local clock'**
  String get syncRepairClockTitle;

  /// No description provided for @syncRepairClockBody.
  ///
  /// In en, this message translates to:
  /// **'The WebDAV certificate is not valid yet. Check this device clock and time zone, then let automatic sync retry.'**
  String get syncRepairClockBody;

  /// No description provided for @syncRepairTrustCertificateTitle.
  ///
  /// In en, this message translates to:
  /// **'Trust WebDAV certificate?'**
  String get syncRepairTrustCertificateTitle;

  /// No description provided for @syncRepairTrustCertificateBody.
  ///
  /// In en, this message translates to:
  /// **'The WebDAV server uses an untrusted certificate. Review the fingerprint before saving trust for this endpoint.'**
  String get syncRepairTrustCertificateBody;

  /// No description provided for @syncRepairRemoteRebuildTitle.
  ///
  /// In en, this message translates to:
  /// **'Repair remote sync?'**
  String get syncRepairRemoteRebuildTitle;

  /// No description provided for @syncRepairRemoteRebuildBody.
  ///
  /// In en, this message translates to:
  /// **'The remote manifest or record objects are incomplete or corrupted. Serlink can rebuild them from local encrypted records.'**
  String get syncRepairRemoteRebuildBody;

  /// No description provided for @syncRepairInitializeRemoteTitle.
  ///
  /// In en, this message translates to:
  /// **'Initialize remote sync?'**
  String get syncRepairInitializeRemoteTitle;

  /// No description provided for @syncRepairInitializeRemoteBody.
  ///
  /// In en, this message translates to:
  /// **'The remote location has no Serlink manifest. Serlink can create one from this encrypted vault.'**
  String get syncRepairInitializeRemoteBody;

  /// No description provided for @syncRepairReplaceRemoteTitle.
  ///
  /// In en, this message translates to:
  /// **'Replace remote vault?'**
  String get syncRepairReplaceRemoteTitle;

  /// No description provided for @syncRepairReplaceRemoteBody.
  ///
  /// In en, this message translates to:
  /// **'The remote location belongs to another vault. Replacing it will overwrite that remote Serlink sync set with this encrypted vault.'**
  String get syncRepairReplaceRemoteBody;

  /// No description provided for @syncRepairRestoreLocalTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore local sync data?'**
  String get syncRepairRestoreLocalTitle;

  /// No description provided for @syncRepairRestoreLocalBody.
  ///
  /// In en, this message translates to:
  /// **'Local vault data needs recovery before remote sync can be rebuilt. Serlink can restore local encrypted records from the current remote sync set.'**
  String get syncRepairRestoreLocalBody;

  /// No description provided for @syncRemoteRepaired.
  ///
  /// In en, this message translates to:
  /// **'Remote sync repaired.'**
  String get syncRemoteRepaired;

  /// No description provided for @syncWebDavCertificateTrustSaved.
  ///
  /// In en, this message translates to:
  /// **'WebDAV certificate trust saved.'**
  String get syncWebDavCertificateTrustSaved;

  /// No description provided for @syncICloudEnabledSnack.
  ///
  /// In en, this message translates to:
  /// **'iCloud sync enabled.'**
  String get syncICloudEnabledSnack;

  /// No description provided for @syncICloudPausedSnack.
  ///
  /// In en, this message translates to:
  /// **'iCloud sync paused.'**
  String get syncICloudPausedSnack;

  /// No description provided for @syncICloudRemoteVaultAdoptedSnack.
  ///
  /// In en, this message translates to:
  /// **'iCloud already has a Serlink vault. Use that vault passphrase to finish syncing.'**
  String get syncICloudRemoteVaultAdoptedSnack;

  /// No description provided for @syncConflictsResolvedSnack.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Resolved sync conflicts. Synced 1 encrypted record.} other{Resolved sync conflicts. Synced {count} encrypted records.}}'**
  String syncConflictsResolvedSnack(num count);

  /// No description provided for @syncSettingsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Sync settings could not be loaded.'**
  String get syncSettingsLoadFailed;

  /// No description provided for @syncLocalTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Local time: {time}'**
  String syncLocalTimeLabel(String time);

  /// No description provided for @syncEndpointLabel.
  ///
  /// In en, this message translates to:
  /// **'Endpoint: {endpoint}'**
  String syncEndpointLabel(String endpoint);

  /// No description provided for @syncValidFromLabel.
  ///
  /// In en, this message translates to:
  /// **'Valid from: {time}'**
  String syncValidFromLabel(String time);

  /// No description provided for @syncValidUntilLabel.
  ///
  /// In en, this message translates to:
  /// **'Valid until: {time}'**
  String syncValidUntilLabel(String time);

  /// No description provided for @doneAction.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get doneAction;

  /// No description provided for @syncConflictsTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync conflicts'**
  String get syncConflictsTitle;

  /// No description provided for @syncConflictsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 encrypted record needs review.} other{{count} encrypted records need review.}}'**
  String syncConflictsSubtitle(num count);

  /// No description provided for @syncReviewAction.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get syncReviewAction;

  /// No description provided for @syncUseRemoteAction.
  ///
  /// In en, this message translates to:
  /// **'Use remote'**
  String get syncUseRemoteAction;

  /// No description provided for @syncKeepLocalAction.
  ///
  /// In en, this message translates to:
  /// **'Keep local'**
  String get syncKeepLocalAction;

  /// No description provided for @syncUseRemoteTitle.
  ///
  /// In en, this message translates to:
  /// **'Use remote records?'**
  String get syncUseRemoteTitle;

  /// No description provided for @syncKeepLocalTitle.
  ///
  /// In en, this message translates to:
  /// **'Keep local records?'**
  String get syncKeepLocalTitle;

  /// No description provided for @syncUseRemoteBody.
  ///
  /// In en, this message translates to:
  /// **'Remote encrypted records will replace conflicting local records before syncing.'**
  String get syncUseRemoteBody;

  /// No description provided for @syncKeepLocalBody.
  ///
  /// In en, this message translates to:
  /// **'Local encrypted records will overwrite conflicting remote records.'**
  String get syncKeepLocalBody;

  /// No description provided for @syncPausedICloudSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Paused. Encrypted records sync through your private iCloud database.'**
  String get syncPausedICloudSubtitle;

  /// No description provided for @syncEnabledStatus.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get syncEnabledStatus;

  /// No description provided for @syncPausedStatus.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get syncPausedStatus;

  /// No description provided for @syncWebDavNotConfiguredSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Not configured. Encrypted manifest and records only.'**
  String get syncWebDavNotConfiguredSubtitle;

  /// No description provided for @syncHttpAllowedStatus.
  ///
  /// In en, this message translates to:
  /// **'HTTP allowed'**
  String get syncHttpAllowedStatus;

  /// No description provided for @syncHttpsStatus.
  ///
  /// In en, this message translates to:
  /// **'HTTPS'**
  String get syncHttpsStatus;

  /// No description provided for @syncAutoSyncWaiting.
  ///
  /// In en, this message translates to:
  /// **'auto-sync waiting'**
  String get syncAutoSyncWaiting;

  /// No description provided for @syncAutoSyncNeedsVault.
  ///
  /// In en, this message translates to:
  /// **'create a vault to start syncing'**
  String get syncAutoSyncNeedsVault;

  /// No description provided for @syncAutoSyncNeedsUnlock.
  ///
  /// In en, this message translates to:
  /// **'unlock the vault to continue syncing'**
  String get syncAutoSyncNeedsUnlock;

  /// No description provided for @syncAutoSyncReady.
  ///
  /// In en, this message translates to:
  /// **'auto-sync ready'**
  String get syncAutoSyncReady;

  /// No description provided for @syncLastSynced.
  ///
  /// In en, this message translates to:
  /// **'last synced {time}'**
  String syncLastSynced(String time);

  /// No description provided for @syncLastFailed.
  ///
  /// In en, this message translates to:
  /// **'sync failed at {time}'**
  String syncLastFailed(String time);

  /// No description provided for @syncAutoSyncQueued.
  ///
  /// In en, this message translates to:
  /// **'auto-sync queued'**
  String get syncAutoSyncQueued;

  /// No description provided for @syncSyncingAutomatically.
  ///
  /// In en, this message translates to:
  /// **'syncing automatically'**
  String get syncSyncingAutomatically;

  /// No description provided for @syncConflictCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 conflict} other{{count} conflicts}}'**
  String syncConflictCount(num count);

  /// No description provided for @syncAutoSyncFailed.
  ///
  /// In en, this message translates to:
  /// **'auto-sync failed'**
  String get syncAutoSyncFailed;

  /// No description provided for @saveAction.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get saveAction;

  /// No description provided for @savingAction.
  ///
  /// In en, this message translates to:
  /// **'Saving'**
  String get savingAction;

  /// No description provided for @closeAction.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get closeAction;

  /// No description provided for @removeAction.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removeAction;

  /// No description provided for @importAction.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get importAction;

  /// No description provided for @deleteAction.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteAction;

  /// No description provided for @renameAction.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get renameAction;

  /// No description provided for @skipAction.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skipAction;

  /// No description provided for @pasteAction.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get pasteAction;

  /// No description provided for @confirmAction.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirmAction;

  /// No description provided for @applyAction.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get applyAction;

  /// No description provided for @createAction.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get createAction;

  /// No description provided for @runAction.
  ///
  /// In en, this message translates to:
  /// **'Run'**
  String get runAction;

  /// No description provided for @pauseAction.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pauseAction;

  /// No description provided for @resumeAction.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resumeAction;

  /// No description provided for @retryAction.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retryAction;

  /// No description provided for @connectAction.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connectAction;

  /// No description provided for @chooseFolderAction.
  ///
  /// In en, this message translates to:
  /// **'Choose Folder'**
  String get chooseFolderAction;

  /// No description provided for @loadingSemantics.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get loadingSemantics;

  /// No description provided for @securityWebDavCertificateChangedTitle.
  ///
  /// In en, this message translates to:
  /// **'WebDAV Certificate Changed'**
  String get securityWebDavCertificateChangedTitle;

  /// No description provided for @securityTrustWebDavCertificateTitle.
  ///
  /// In en, this message translates to:
  /// **'Trust WebDAV Certificate?'**
  String get securityTrustWebDavCertificateTitle;

  /// No description provided for @securityHostKeyChangedTitle.
  ///
  /// In en, this message translates to:
  /// **'Host Key Changed'**
  String get securityHostKeyChangedTitle;

  /// No description provided for @securityConfirmFingerprintTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm Fingerprint'**
  String get securityConfirmFingerprintTitle;

  /// No description provided for @securityAlgorithmLabel.
  ///
  /// In en, this message translates to:
  /// **'Algorithm: {value}'**
  String securityAlgorithmLabel(String value);

  /// No description provided for @securityPreviousLabel.
  ///
  /// In en, this message translates to:
  /// **'Previous: {value}'**
  String securityPreviousLabel(String value);

  /// No description provided for @securitySubjectLabel.
  ///
  /// In en, this message translates to:
  /// **'Subject: {value}'**
  String securitySubjectLabel(String value);

  /// No description provided for @securityIssuerLabel.
  ///
  /// In en, this message translates to:
  /// **'Issuer: {value}'**
  String securityIssuerLabel(String value);

  /// No description provided for @securityValidRangeLabel.
  ///
  /// In en, this message translates to:
  /// **'Valid: {from} to {to}'**
  String securityValidRangeLabel(String from, String to);

  /// No description provided for @securityCertificateClockWarning.
  ///
  /// In en, this message translates to:
  /// **'This certificate is not valid yet. Check this device clock before trusting it.'**
  String get securityCertificateClockWarning;

  /// No description provided for @securityTrustOnceAction.
  ///
  /// In en, this message translates to:
  /// **'Trust Once'**
  String get securityTrustOnceAction;

  /// No description provided for @securityTrustAndSaveAction.
  ///
  /// In en, this message translates to:
  /// **'Trust and Save'**
  String get securityTrustAndSaveAction;

  /// No description provided for @securityEncryptedExport.
  ///
  /// In en, this message translates to:
  /// **'Encrypted export'**
  String get securityEncryptedExport;

  /// No description provided for @securityUnencryptedExport.
  ///
  /// In en, this message translates to:
  /// **'Unencrypted export'**
  String get securityUnencryptedExport;

  /// No description provided for @securitySensitiveFields.
  ///
  /// In en, this message translates to:
  /// **'Sensitive fields: {fields}'**
  String securitySensitiveFields(String fields);

  /// No description provided for @securityCannotBeUndone.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone.'**
  String get securityCannotBeUndone;

  /// No description provided for @securityPasteMultipleLinesTitle.
  ///
  /// In en, this message translates to:
  /// **'Paste multiple lines?'**
  String get securityPasteMultipleLinesTitle;

  /// No description provided for @securityPasteMultipleLinesBody.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 line will be sent to the active terminal.} other{{count} lines will be sent to the active terminal.}}'**
  String securityPasteMultipleLinesBody(num count);

  /// No description provided for @hostEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Host'**
  String get hostEditTitle;

  /// No description provided for @hostAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Host'**
  String get hostAddTitle;

  /// No description provided for @hostSectionConnection.
  ///
  /// In en, this message translates to:
  /// **'Connection'**
  String get hostSectionConnection;

  /// No description provided for @hostSectionAuthentication.
  ///
  /// In en, this message translates to:
  /// **'Authentication'**
  String get hostSectionAuthentication;

  /// No description provided for @hostSectionStartup.
  ///
  /// In en, this message translates to:
  /// **'Startup'**
  String get hostSectionStartup;

  /// No description provided for @hostRemoteSessionTitle.
  ///
  /// In en, this message translates to:
  /// **'Remote session'**
  String get hostRemoteSessionTitle;

  /// No description provided for @hostSectionRouting.
  ///
  /// In en, this message translates to:
  /// **'Routing'**
  String get hostSectionRouting;

  /// No description provided for @hostSectionPortForwarding.
  ///
  /// In en, this message translates to:
  /// **'Port forwarding'**
  String get hostSectionPortForwarding;

  /// No description provided for @hostDisplayNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get hostDisplayNameLabel;

  /// No description provided for @hostDisplayNameOptionalLabel.
  ///
  /// In en, this message translates to:
  /// **'Display name (optional)'**
  String get hostDisplayNameOptionalLabel;

  /// No description provided for @hostDisplayNameHostnameHint.
  ///
  /// In en, this message translates to:
  /// **'Same as hostname'**
  String get hostDisplayNameHostnameHint;

  /// No description provided for @hostDisplayNameHostnameHelper.
  ///
  /// In en, this message translates to:
  /// **'Leave blank to use the hostname.'**
  String get hostDisplayNameHostnameHelper;

  /// No description provided for @hostHostnameLabel.
  ///
  /// In en, this message translates to:
  /// **'Hostname'**
  String get hostHostnameLabel;

  /// No description provided for @hostPortLabel.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get hostPortLabel;

  /// No description provided for @hostUsernameLabel.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get hostUsernameLabel;

  /// No description provided for @hostWriteBackToSshConfigTitle.
  ///
  /// In en, this message translates to:
  /// **'Write to SSH config'**
  String get hostWriteBackToSshConfigTitle;

  /// No description provided for @hostStartupCommandsLabel.
  ///
  /// In en, this message translates to:
  /// **'Startup commands'**
  String get hostStartupCommandsLabel;

  /// No description provided for @hostRemoteSessionEnableTitle.
  ///
  /// In en, this message translates to:
  /// **'Attach to tmux/screen'**
  String get hostRemoteSessionEnableTitle;

  /// No description provided for @hostRemoteSessionManagerAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get hostRemoteSessionManagerAuto;

  /// No description provided for @hostRemoteSessionManagerTmux.
  ///
  /// In en, this message translates to:
  /// **'tmux'**
  String get hostRemoteSessionManagerTmux;

  /// No description provided for @hostRemoteSessionManagerScreen.
  ///
  /// In en, this message translates to:
  /// **'screen'**
  String get hostRemoteSessionManagerScreen;

  /// No description provided for @hostRemoteSessionNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Session name'**
  String get hostRemoteSessionNameLabel;

  /// No description provided for @hostRemoteSessionCreateIfMissing.
  ///
  /// In en, this message translates to:
  /// **'Create when missing'**
  String get hostRemoteSessionCreateIfMissing;

  /// No description provided for @hostRemoteSessionFallbackToShell.
  ///
  /// In en, this message translates to:
  /// **'Fall back to shell'**
  String get hostRemoteSessionFallbackToShell;

  /// No description provided for @hostTagsLabel.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get hostTagsLabel;

  /// No description provided for @hostStartFolderLabel.
  ///
  /// In en, this message translates to:
  /// **'Start folder'**
  String get hostStartFolderLabel;

  /// No description provided for @hostPrivateKeyLabel.
  ///
  /// In en, this message translates to:
  /// **'Private key'**
  String get hostPrivateKeyLabel;

  /// No description provided for @hostImportPrivateKeyTooltip.
  ///
  /// In en, this message translates to:
  /// **'Import private key'**
  String get hostImportPrivateKeyTooltip;

  /// No description provided for @hostKeyPassphraseLabel.
  ///
  /// In en, this message translates to:
  /// **'Key passphrase'**
  String get hostKeyPassphraseLabel;

  /// No description provided for @hostAdvancedConnectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Connection options'**
  String get hostAdvancedConnectionTitle;

  /// No description provided for @hostPortForwardingLocalHint.
  ///
  /// In en, this message translates to:
  /// **'Start these local forwards with every SSH session.'**
  String get hostPortForwardingLocalHint;

  /// No description provided for @hostPortForwardingRemoteHint.
  ///
  /// In en, this message translates to:
  /// **'Start these remote forwards with every SSH session.'**
  String get hostPortForwardingRemoteHint;

  /// No description provided for @hostPortForwardingDynamicHint.
  ///
  /// In en, this message translates to:
  /// **'Start these SOCKS proxies with every SSH session.'**
  String get hostPortForwardingDynamicHint;

  /// No description provided for @hostTimeoutLabel.
  ///
  /// In en, this message translates to:
  /// **'Timeout (s)'**
  String get hostTimeoutLabel;

  /// No description provided for @hostKeepaliveLabel.
  ///
  /// In en, this message translates to:
  /// **'Keepalive (s)'**
  String get hostKeepaliveLabel;

  /// No description provided for @hostAutoReconnectLabel.
  ///
  /// In en, this message translates to:
  /// **'Auto reconnect'**
  String get hostAutoReconnectLabel;

  /// No description provided for @hostBackoffLabel.
  ///
  /// In en, this message translates to:
  /// **'Backoff (s)'**
  String get hostBackoffLabel;

  /// No description provided for @hostAuthPasswordSegment.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get hostAuthPasswordSegment;

  /// No description provided for @hostAuthKeySegment.
  ///
  /// In en, this message translates to:
  /// **'Key'**
  String get hostAuthKeySegment;

  /// No description provided for @hostAuthAgentSegment.
  ///
  /// In en, this message translates to:
  /// **'Agent'**
  String get hostAuthAgentSegment;

  /// No description provided for @hostAuthSavedSegment.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get hostAuthSavedSegment;

  /// No description provided for @hostPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get hostPasswordLabel;

  /// No description provided for @hostShowPasswordTooltip.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get hostShowPasswordTooltip;

  /// No description provided for @hostHidePasswordTooltip.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hostHidePasswordTooltip;

  /// No description provided for @hostSshAgentNote.
  ///
  /// In en, this message translates to:
  /// **'Uses identities from the local SSH agent. On macOS, keys loaded into ssh-agent can be backed by Keychain.'**
  String get hostSshAgentNote;

  /// No description provided for @hostNoSavedCredentials.
  ///
  /// In en, this message translates to:
  /// **'No saved credentials are available yet.'**
  String get hostNoSavedCredentials;

  /// No description provided for @hostCredentialsHeading.
  ///
  /// In en, this message translates to:
  /// **'Credentials'**
  String get hostCredentialsHeading;

  /// No description provided for @hostEditCredentialTooltip.
  ///
  /// In en, this message translates to:
  /// **'Edit credential'**
  String get hostEditCredentialTooltip;

  /// No description provided for @hostCredentialOptionalNote.
  ///
  /// In en, this message translates to:
  /// **'You can save the host without credentials and add one later.'**
  String get hostCredentialOptionalNote;

  /// No description provided for @hostJumpHostsHeading.
  ///
  /// In en, this message translates to:
  /// **'Jump hosts'**
  String get hostJumpHostsHeading;

  /// No description provided for @hostPortNumberError.
  ///
  /// In en, this message translates to:
  /// **'Port must be a number.'**
  String get hostPortNumberError;

  /// No description provided for @hostSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Host could not be saved.'**
  String get hostSaveFailed;

  /// No description provided for @hostConfigurationLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Host configuration could not be loaded.'**
  String get hostConfigurationLoadFailed;

  /// No description provided for @hostConnectionSettingsWholeNumbers.
  ///
  /// In en, this message translates to:
  /// **'Connection settings must be whole numbers.'**
  String get hostConnectionSettingsWholeNumbers;

  /// No description provided for @identityKindPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get identityKindPassword;

  /// No description provided for @identityKindPrivateKey.
  ///
  /// In en, this message translates to:
  /// **'Private Key'**
  String get identityKindPrivateKey;

  /// No description provided for @identityKindKeyboard.
  ///
  /// In en, this message translates to:
  /// **'Keyboard'**
  String get identityKindKeyboard;

  /// No description provided for @identityKindCertificate.
  ///
  /// In en, this message translates to:
  /// **'Certificate'**
  String get identityKindCertificate;

  /// No description provided for @identityKindSshAgent.
  ///
  /// In en, this message translates to:
  /// **'SSH Agent'**
  String get identityKindSshAgent;

  /// No description provided for @identityKindHardwareKey.
  ///
  /// In en, this message translates to:
  /// **'Hardware Key'**
  String get identityKindHardwareKey;

  /// No description provided for @identityUserLabel.
  ///
  /// In en, this message translates to:
  /// **'user {username}'**
  String identityUserLabel(String username);

  /// No description provided for @identityPrincipalLabel.
  ///
  /// In en, this message translates to:
  /// **'principal {principal}'**
  String identityPrincipalLabel(String principal);

  /// No description provided for @snippetInsertTooltip.
  ///
  /// In en, this message translates to:
  /// **'Insert into active terminal'**
  String get snippetInsertTooltip;

  /// No description provided for @snippetRunTooltip.
  ///
  /// In en, this message translates to:
  /// **'Run in active terminal'**
  String get snippetRunTooltip;

  /// No description provided for @snippetEditTooltip.
  ///
  /// In en, this message translates to:
  /// **'Edit snippet'**
  String get snippetEditTooltip;

  /// No description provided for @snippetDeleteTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete snippet'**
  String get snippetDeleteTooltip;

  /// No description provided for @snippetDialogEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Snippet'**
  String get snippetDialogEditTitle;

  /// No description provided for @snippetDialogAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Snippet'**
  String get snippetDialogAddTitle;

  /// No description provided for @snippetNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get snippetNameLabel;

  /// No description provided for @snippetCommandLabel.
  ///
  /// In en, this message translates to:
  /// **'Command'**
  String get snippetCommandLabel;

  /// No description provided for @snippetTagsLabel.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get snippetTagsLabel;

  /// No description provided for @snippetConfirmBeforeRun.
  ///
  /// In en, this message translates to:
  /// **'Confirm before run'**
  String get snippetConfirmBeforeRun;

  /// No description provided for @snippetAddTagsHint.
  ///
  /// In en, this message translates to:
  /// **'Add tags'**
  String get snippetAddTagsHint;

  /// No description provided for @snippetAddTagHint.
  ///
  /// In en, this message translates to:
  /// **'Add tag'**
  String get snippetAddTagHint;

  /// No description provided for @snippetRemoveTagTooltip.
  ///
  /// In en, this message translates to:
  /// **'Remove tag'**
  String get snippetRemoveTagTooltip;

  /// No description provided for @snippetRunTitle.
  ///
  /// In en, this message translates to:
  /// **'Run snippet?'**
  String get snippetRunTitle;

  /// No description provided for @snippetDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete snippet?'**
  String get snippetDeleteTitle;

  /// No description provided for @snippetSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Snippet could not be saved.'**
  String get snippetSaveFailed;

  /// No description provided for @snippetSentSnack.
  ///
  /// In en, this message translates to:
  /// **'Snippet sent to terminal.'**
  String get snippetSentSnack;

  /// No description provided for @snippetInsertedSnack.
  ///
  /// In en, this message translates to:
  /// **'Snippet inserted into terminal.'**
  String get snippetInsertedSnack;

  /// No description provided for @snippetNoTerminalSnack.
  ///
  /// In en, this message translates to:
  /// **'Open a connected terminal tab first.'**
  String get snippetNoTerminalSnack;

  /// No description provided for @snippetDeletedSnack.
  ///
  /// In en, this message translates to:
  /// **'Snippet deleted.'**
  String get snippetDeletedSnack;

  /// No description provided for @snippetDeleteFailedSnack.
  ///
  /// In en, this message translates to:
  /// **'Snippet could not be deleted.'**
  String get snippetDeleteFailedSnack;

  /// No description provided for @syncDevicesDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync Devices'**
  String get syncDevicesDialogTitle;

  /// No description provided for @syncDeviceRemoveTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}?'**
  String syncDeviceRemoveTitle(String name);

  /// No description provided for @syncDeviceRemoveBody.
  ///
  /// In en, this message translates to:
  /// **'This removes the encrypted sync device record from this vault.'**
  String get syncDeviceRemoveBody;

  /// No description provided for @syncDeviceRemovedSnack.
  ///
  /// In en, this message translates to:
  /// **'Sync device removed.'**
  String get syncDeviceRemovedSnack;

  /// No description provided for @syncDeviceRemoveFailedSnack.
  ///
  /// In en, this message translates to:
  /// **'Sync device could not be removed.'**
  String get syncDeviceRemoveFailedSnack;

  /// No description provided for @syncDeviceResetTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset sync device?'**
  String get syncDeviceResetTitle;

  /// No description provided for @syncDeviceResetBody.
  ///
  /// In en, this message translates to:
  /// **'This removes the current device registration from encrypted sync and creates a new local device identity. Other devices will see the old device as removed.'**
  String get syncDeviceResetBody;

  /// No description provided for @syncDeviceResetSnack.
  ///
  /// In en, this message translates to:
  /// **'Sync device reset. A new registration will be created on the next sync.'**
  String get syncDeviceResetSnack;

  /// No description provided for @syncDeviceResetFailedSnack.
  ///
  /// In en, this message translates to:
  /// **'Sync device could not be reset.'**
  String get syncDeviceResetFailedSnack;

  /// No description provided for @syncDevicesEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No sync devices yet'**
  String get syncDevicesEmptyTitle;

  /// No description provided for @syncDevicesEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'This device will be registered here after the first successful encrypted sync.'**
  String get syncDevicesEmptyBody;

  /// No description provided for @syncDeviceRemoveTooltip.
  ///
  /// In en, this message translates to:
  /// **'Remove device'**
  String get syncDeviceRemoveTooltip;

  /// No description provided for @syncDevicesWillRegister.
  ///
  /// In en, this message translates to:
  /// **'This device will be registered on first sync.'**
  String get syncDevicesWillRegister;

  /// No description provided for @syncDeviceSingleSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{name} registered for encrypted sync.'**
  String syncDeviceSingleSubtitle(String name);

  /// No description provided for @syncDevicesRegisteredSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 device registered.} other{{count} devices registered.}}'**
  String syncDevicesRegisteredSubtitle(num count);

  /// No description provided for @syncDevicesMultipleSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{count} devices registered. Last writer: {name}.'**
  String syncDevicesMultipleSubtitle(num count, String name);

  /// No description provided for @syncDeviceThisDevice.
  ///
  /// In en, this message translates to:
  /// **'{name} (this device)'**
  String syncDeviceThisDevice(String name);

  /// No description provided for @syncDeviceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{platform} / last seen {time}'**
  String syncDeviceSubtitle(String platform, String time);

  /// No description provided for @webDavSyncTitle.
  ///
  /// In en, this message translates to:
  /// **'WebDAV Sync'**
  String get webDavSyncTitle;

  /// No description provided for @webDavEndpointLabel.
  ///
  /// In en, this message translates to:
  /// **'Endpoint'**
  String get webDavEndpointLabel;

  /// No description provided for @webDavEndpointHint.
  ///
  /// In en, this message translates to:
  /// **'https://example.com/webdav'**
  String get webDavEndpointHint;

  /// No description provided for @webDavUsernameLabel.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get webDavUsernameLabel;

  /// No description provided for @webDavPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get webDavPasswordLabel;

  /// No description provided for @webDavPasswordKeepLabel.
  ///
  /// In en, this message translates to:
  /// **'Password (leave blank to keep)'**
  String get webDavPasswordKeepLabel;

  /// No description provided for @webDavBasePathLabel.
  ///
  /// In en, this message translates to:
  /// **'Base path'**
  String get webDavBasePathLabel;

  /// No description provided for @webDavEnableTitle.
  ///
  /// In en, this message translates to:
  /// **'Enable WebDAV sync'**
  String get webDavEnableTitle;

  /// No description provided for @webDavAllowHttpTitle.
  ///
  /// In en, this message translates to:
  /// **'Allow HTTP endpoint'**
  String get webDavAllowHttpTitle;

  /// No description provided for @webDavUseHttpTitle.
  ///
  /// In en, this message translates to:
  /// **'Use HTTP WebDAV?'**
  String get webDavUseHttpTitle;

  /// No description provided for @webDavUseHttpBody.
  ///
  /// In en, this message translates to:
  /// **'HTTP sync can expose metadata and credentials in transit. Use only for trusted local test servers.'**
  String get webDavUseHttpBody;

  /// No description provided for @webDavAllowHttpAction.
  ///
  /// In en, this message translates to:
  /// **'Allow HTTP'**
  String get webDavAllowHttpAction;

  /// No description provided for @webDavSavedSnack.
  ///
  /// In en, this message translates to:
  /// **'WebDAV sync settings saved.'**
  String get webDavSavedSnack;

  /// No description provided for @webDavRemoveTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove WebDAV sync?'**
  String get webDavRemoveTitle;

  /// No description provided for @webDavRemoveBody.
  ///
  /// In en, this message translates to:
  /// **'This removes the local WebDAV configuration and stored password.'**
  String get webDavRemoveBody;

  /// No description provided for @webDavRemovedSnack.
  ///
  /// In en, this message translates to:
  /// **'WebDAV sync settings removed.'**
  String get webDavRemovedSnack;

  /// No description provided for @credentialsDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Credentials'**
  String get credentialsDialogTitle;

  /// No description provided for @credentialsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No credentials stored'**
  String get credentialsEmptyTitle;

  /// No description provided for @credentialsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Imported passwords, private keys, certificates, and identity metadata will appear here.'**
  String get credentialsEmptyBody;

  /// No description provided for @credentialsEditTooltip.
  ///
  /// In en, this message translates to:
  /// **'Edit credential'**
  String get credentialsEditTooltip;

  /// No description provided for @credentialsDeleteTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete credential'**
  String get credentialsDeleteTooltip;

  /// No description provided for @credentialUpdatedSnack.
  ///
  /// In en, this message translates to:
  /// **'Credential updated.'**
  String get credentialUpdatedSnack;

  /// No description provided for @credentialDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete credential?'**
  String get credentialDeleteTitle;

  /// No description provided for @credentialDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'This removes the credential and its encrypted secret material.'**
  String get credentialDeleteBody;

  /// No description provided for @credentialDeleteLinkedBody.
  ///
  /// In en, this message translates to:
  /// **'This credential is still linked to: {hosts}. Delete it only after removing those host links.'**
  String credentialDeleteLinkedBody(String hosts);

  /// No description provided for @credentialDeletedSnack.
  ///
  /// In en, this message translates to:
  /// **'Credential deleted.'**
  String get credentialDeletedSnack;

  /// No description provided for @credentialDeleteFailedSnack.
  ///
  /// In en, this message translates to:
  /// **'Credential could not be deleted.'**
  String get credentialDeleteFailedSnack;

  /// No description provided for @knownHostsDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Known Hosts'**
  String get knownHostsDialogTitle;

  /// No description provided for @knownHostsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No trusted fingerprints'**
  String get knownHostsEmptyTitle;

  /// No description provided for @knownHostsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Host fingerprints accepted during connection review will be listed here.'**
  String get knownHostsEmptyBody;

  /// No description provided for @knownHostDeleteTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete known host'**
  String get knownHostDeleteTooltip;

  /// No description provided for @knownHostDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete known host?'**
  String get knownHostDeleteTitle;

  /// No description provided for @knownHostDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'This removes the stored fingerprint for {host}. The next connection will require confirmation again.'**
  String knownHostDeleteBody(String host);

  /// No description provided for @knownHostDeletedSnack.
  ///
  /// In en, this message translates to:
  /// **'Known host deleted.'**
  String get knownHostDeletedSnack;

  /// No description provided for @knownHostDeleteFailedSnack.
  ///
  /// In en, this message translates to:
  /// **'Known host could not be deleted.'**
  String get knownHostDeleteFailedSnack;

  /// No description provided for @startAction.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get startAction;

  /// No description provided for @stopAction.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stopAction;

  /// No description provided for @uploadAction.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get uploadAction;

  /// No description provided for @downloadAction.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get downloadAction;

  /// No description provided for @moveAction.
  ///
  /// In en, this message translates to:
  /// **'Move'**
  String get moveAction;

  /// No description provided for @replaceAction.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get replaceAction;

  /// No description provided for @mergeAction.
  ///
  /// In en, this message translates to:
  /// **'Merge'**
  String get mergeAction;

  /// No description provided for @copiedAction.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get copiedAction;

  /// No description provided for @clearAllAction.
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get clearAllAction;

  /// No description provided for @selectAllAction.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get selectAllAction;

  /// No description provided for @restartAction.
  ///
  /// In en, this message translates to:
  /// **'Restart'**
  String get restartAction;

  /// No description provided for @reconnectAction.
  ///
  /// In en, this message translates to:
  /// **'Reconnect'**
  String get reconnectAction;

  /// No description provided for @windowCloseActiveTerminalsTitle.
  ///
  /// In en, this message translates to:
  /// **'Close active terminals?'**
  String get windowCloseActiveTerminalsTitle;

  /// No description provided for @windowCloseActiveTerminalsBody.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 active terminal pane is still running. Closing this window will disconnect it.} other{{count} active terminal panes are still running. Closing this window will disconnect them.}}'**
  String windowCloseActiveTerminalsBody(num count);

  /// No description provided for @windowCloseWindowAction.
  ///
  /// In en, this message translates to:
  /// **'Close Window'**
  String get windowCloseWindowAction;

  /// No description provided for @windowCloseLabel.
  ///
  /// In en, this message translates to:
  /// **'Close window'**
  String get windowCloseLabel;

  /// No description provided for @windowMinimizeLabel.
  ///
  /// In en, this message translates to:
  /// **'Minimize window'**
  String get windowMinimizeLabel;

  /// No description provided for @windowZoomLabel.
  ///
  /// In en, this message translates to:
  /// **'Zoom window'**
  String get windowZoomLabel;

  /// No description provided for @hostEditMenu.
  ///
  /// In en, this message translates to:
  /// **'Edit host'**
  String get hostEditMenu;

  /// No description provided for @hostDuplicateMenu.
  ///
  /// In en, this message translates to:
  /// **'Duplicate session'**
  String get hostDuplicateMenu;

  /// No description provided for @hostDuplicateTitle.
  ///
  /// In en, this message translates to:
  /// **'Duplicate session'**
  String get hostDuplicateTitle;

  /// No description provided for @hostDeleteMenu.
  ///
  /// In en, this message translates to:
  /// **'Delete host'**
  String get hostDeleteMenu;

  /// No description provided for @hostTerminalAction.
  ///
  /// In en, this message translates to:
  /// **'Terminal'**
  String get hostTerminalAction;

  /// No description provided for @hostSftpAction.
  ///
  /// In en, this message translates to:
  /// **'SFTP'**
  String get hostSftpAction;

  /// No description provided for @hostTrustTrusted.
  ///
  /// In en, this message translates to:
  /// **'trusted'**
  String get hostTrustTrusted;

  /// No description provided for @hostTrustVerify.
  ///
  /// In en, this message translates to:
  /// **'verify'**
  String get hostTrustVerify;

  /// No description provided for @hostTrustChanged.
  ///
  /// In en, this message translates to:
  /// **'changed'**
  String get hostTrustChanged;

  /// No description provided for @tabsCloseTooltip.
  ///
  /// In en, this message translates to:
  /// **'Close tab'**
  String get tabsCloseTooltip;

  /// No description provided for @tabsNewConnectionTooltip.
  ///
  /// In en, this message translates to:
  /// **'New connection'**
  String get tabsNewConnectionTooltip;

  /// No description provided for @terminalToolbarMoreActionsTooltip.
  ///
  /// In en, this message translates to:
  /// **'More terminal actions'**
  String get terminalToolbarMoreActionsTooltip;

  /// No description provided for @localShellInactive.
  ///
  /// In en, this message translates to:
  /// **'Local shell is not running.'**
  String get localShellInactive;

  /// No description provided for @connectionInactive.
  ///
  /// In en, this message translates to:
  /// **'Connection is not active.'**
  String get connectionInactive;

  /// No description provided for @sessionDisconnectedMessage.
  ///
  /// In en, this message translates to:
  /// **'Connection interrupted. Reconnect starts a new session.'**
  String get sessionDisconnectedMessage;

  /// No description provided for @connectionFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Connection failed.'**
  String get connectionFailedMessage;

  /// No description provided for @connectionProfileVaultLockedMessage.
  ///
  /// In en, this message translates to:
  /// **'Unlock the vault before starting a new connection.'**
  String get connectionProfileVaultLockedMessage;

  /// No description provided for @connectionProfileNotFoundMessage.
  ///
  /// In en, this message translates to:
  /// **'Connection profile could not be found.'**
  String get connectionProfileNotFoundMessage;

  /// No description provided for @connectionProfileHostNotFoundMessage.
  ///
  /// In en, this message translates to:
  /// **'Host could not be found.'**
  String get connectionProfileHostNotFoundMessage;

  /// No description provided for @connectionProfileIdentityNotFoundMessage.
  ///
  /// In en, this message translates to:
  /// **'Identity could not be found.'**
  String get connectionProfileIdentityNotFoundMessage;

  /// No description provided for @connectionProfileNoAuthMethodsMessage.
  ///
  /// In en, this message translates to:
  /// **'This host has no identity configured.'**
  String get connectionProfileNoAuthMethodsMessage;

  /// No description provided for @connectionProfileJumpChainTooDeepMessage.
  ///
  /// In en, this message translates to:
  /// **'Jump host chain has too many hops.'**
  String get connectionProfileJumpChainTooDeepMessage;

  /// No description provided for @connectionProfileJumpCycleMessage.
  ///
  /// In en, this message translates to:
  /// **'Jump host chain contains a cycle.'**
  String get connectionProfileJumpCycleMessage;

  /// No description provided for @connectionProfileSshAgentUnsupportedMessage.
  ///
  /// In en, this message translates to:
  /// **'SSH agent authentication is not available on this platform.'**
  String get connectionProfileSshAgentUnsupportedMessage;

  /// No description provided for @connectionProfileHardwareKeyUnsupportedMessage.
  ///
  /// In en, this message translates to:
  /// **'Hardware key authentication is not available on this platform.'**
  String get connectionProfileHardwareKeyUnsupportedMessage;

  /// No description provided for @connectionProfileIdentitySecretMissingMessage.
  ///
  /// In en, this message translates to:
  /// **'Identity does not reference a secret record.'**
  String get connectionProfileIdentitySecretMissingMessage;

  /// No description provided for @connectionProfileSecretNotFoundMessage.
  ///
  /// In en, this message translates to:
  /// **'Secret record could not be found.'**
  String get connectionProfileSecretNotFoundMessage;

  /// No description provided for @connectionProfilePasswordMissingMessage.
  ///
  /// In en, this message translates to:
  /// **'Identity does not contain a password.'**
  String get connectionProfilePasswordMissingMessage;

  /// No description provided for @connectionProfilePrivateKeyMissingMessage.
  ///
  /// In en, this message translates to:
  /// **'Identity does not contain a private key.'**
  String get connectionProfilePrivateKeyMissingMessage;

  /// No description provided for @connectionProfileCertificateMissingMessage.
  ///
  /// In en, this message translates to:
  /// **'Identity does not contain an OpenSSH certificate.'**
  String get connectionProfileCertificateMissingMessage;

  /// No description provided for @sshAuthAgentUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'SSH agent is not available.'**
  String get sshAuthAgentUnavailableMessage;

  /// No description provided for @sshAuthHardwareKeyUnsupportedMessage.
  ///
  /// In en, this message translates to:
  /// **'Hardware security key authentication requires platform support.'**
  String get sshAuthHardwareKeyUnsupportedMessage;

  /// No description provided for @sshAuthAgentEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'SSH agent has no loaded identities.'**
  String get sshAuthAgentEmptyMessage;

  /// No description provided for @sshAuthEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Connection profile does not contain a supported authentication method.'**
  String get sshAuthEmptyMessage;

  /// No description provided for @sshAuthCertificateInvalidMessage.
  ///
  /// In en, this message translates to:
  /// **'OpenSSH certificate material is invalid.'**
  String get sshAuthCertificateInvalidMessage;

  /// No description provided for @localTerminalExitedMessage.
  ///
  /// In en, this message translates to:
  /// **'Local shell exited. Restart opens a new shell.'**
  String get localTerminalExitedMessage;

  /// No description provided for @localTerminalFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Local terminal failed.'**
  String get localTerminalFailedMessage;

  /// No description provided for @localTerminalShellMissingMessage.
  ///
  /// In en, this message translates to:
  /// **'No local shell executable was found.'**
  String get localTerminalShellMissingMessage;

  /// No description provided for @localTerminalStartFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Local terminal could not start.'**
  String get localTerminalStartFailedMessage;

  /// No description provided for @localShellTitle.
  ///
  /// In en, this message translates to:
  /// **'Local Shell'**
  String get localShellTitle;

  /// No description provided for @terminalSearchTooltip.
  ///
  /// In en, this message translates to:
  /// **'Search terminal'**
  String get terminalSearchTooltip;

  /// No description provided for @terminalOpenSftpTooltip.
  ///
  /// In en, this message translates to:
  /// **'Open SFTP tab'**
  String get terminalOpenSftpTooltip;

  /// No description provided for @terminalSplitRightTooltip.
  ///
  /// In en, this message translates to:
  /// **'Split right'**
  String get terminalSplitRightTooltip;

  /// No description provided for @terminalSplitDownTooltip.
  ///
  /// In en, this message translates to:
  /// **'Split down'**
  String get terminalSplitDownTooltip;

  /// No description provided for @terminalClosePaneTooltip.
  ///
  /// In en, this message translates to:
  /// **'Close pane'**
  String get terminalClosePaneTooltip;

  /// No description provided for @terminalPaneSessionLabel.
  ///
  /// In en, this message translates to:
  /// **'Session {index}'**
  String terminalPaneSessionLabel(int index);

  /// No description provided for @terminalSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Terminal Settings'**
  String get terminalSettingsTitle;

  /// No description provided for @terminalForwardingUpdating.
  ///
  /// In en, this message translates to:
  /// **'Updating port forwarding'**
  String get terminalForwardingUpdating;

  /// No description provided for @terminalForwardingManage.
  ///
  /// In en, this message translates to:
  /// **'Manage port forwarding'**
  String get terminalForwardingManage;

  /// No description provided for @terminalForwardingManageActive.
  ///
  /// In en, this message translates to:
  /// **'Manage port forwarding ({count} active)'**
  String terminalForwardingManageActive(num count);

  /// No description provided for @terminalNoSearchResults.
  ///
  /// In en, this message translates to:
  /// **'No results'**
  String get terminalNoSearchResults;

  /// No description provided for @terminalPreviousMatchTooltip.
  ///
  /// In en, this message translates to:
  /// **'Previous match'**
  String get terminalPreviousMatchTooltip;

  /// No description provided for @terminalNextMatchTooltip.
  ///
  /// In en, this message translates to:
  /// **'Next match'**
  String get terminalNextMatchTooltip;

  /// No description provided for @terminalCloseSearchTooltip.
  ///
  /// In en, this message translates to:
  /// **'Close search'**
  String get terminalCloseSearchTooltip;

  /// No description provided for @terminalAppearanceSection.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get terminalAppearanceSection;

  /// No description provided for @terminalThemeLabel.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get terminalThemeLabel;

  /// No description provided for @terminalLayoutSection.
  ///
  /// In en, this message translates to:
  /// **'Layout'**
  String get terminalLayoutSection;

  /// No description provided for @terminalFontSizeLabel.
  ///
  /// In en, this message translates to:
  /// **'Font size'**
  String get terminalFontSizeLabel;

  /// No description provided for @terminalLineHeightLabel.
  ///
  /// In en, this message translates to:
  /// **'Line height'**
  String get terminalLineHeightLabel;

  /// No description provided for @terminalScrollbackLabel.
  ///
  /// In en, this message translates to:
  /// **'Scrollback'**
  String get terminalScrollbackLabel;

  /// No description provided for @terminalSaveForHostAction.
  ///
  /// In en, this message translates to:
  /// **'Save for host'**
  String get terminalSaveForHostAction;

  /// No description provided for @terminalUseGlobalAction.
  ///
  /// In en, this message translates to:
  /// **'Use global'**
  String get terminalUseGlobalAction;

  /// No description provided for @terminalFontLabel.
  ///
  /// In en, this message translates to:
  /// **'Font'**
  String get terminalFontLabel;

  /// No description provided for @terminalSearchFontsHint.
  ///
  /// In en, this message translates to:
  /// **'Search fonts'**
  String get terminalSearchFontsHint;

  /// No description provided for @terminalSelectFontHint.
  ///
  /// In en, this message translates to:
  /// **'Select a font'**
  String get terminalSelectFontHint;

  /// No description provided for @terminalCustomFamilyLabel.
  ///
  /// In en, this message translates to:
  /// **'Custom family'**
  String get terminalCustomFamilyLabel;

  /// No description provided for @terminalCustomFamilyHelper.
  ///
  /// In en, this message translates to:
  /// **'Type an installed font family, then apply.'**
  String get terminalCustomFamilyHelper;

  /// No description provided for @terminalCustomFamilyHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. JetBrains Mono'**
  String get terminalCustomFamilyHint;

  /// No description provided for @terminalApplyCustomFontTooltip.
  ///
  /// In en, this message translates to:
  /// **'Apply custom font'**
  String get terminalApplyCustomFontTooltip;

  /// No description provided for @terminalScanningFonts.
  ///
  /// In en, this message translates to:
  /// **'Scanning fonts'**
  String get terminalScanningFonts;

  /// No description provided for @terminalNerdFontReady.
  ///
  /// In en, this message translates to:
  /// **'Nerd Font ready'**
  String get terminalNerdFontReady;

  /// No description provided for @terminalNoNerdFont.
  ///
  /// In en, this message translates to:
  /// **'No Nerd Font'**
  String get terminalNoNerdFont;

  /// No description provided for @terminalLifecycleRunning.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get terminalLifecycleRunning;

  /// No description provided for @terminalLifecycleStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting'**
  String get terminalLifecycleStarting;

  /// No description provided for @terminalLifecycleExited.
  ///
  /// In en, this message translates to:
  /// **'Exited'**
  String get terminalLifecycleExited;

  /// No description provided for @terminalLifecycleFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get terminalLifecycleFailed;

  /// No description provided for @terminalLifecycleStopping.
  ///
  /// In en, this message translates to:
  /// **'Stopping'**
  String get terminalLifecycleStopping;

  /// No description provided for @terminalLifecycleConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get terminalLifecycleConnected;

  /// No description provided for @terminalLifecycleConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting'**
  String get terminalLifecycleConnecting;

  /// No description provided for @terminalLifecycleReconnecting.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting'**
  String get terminalLifecycleReconnecting;

  /// No description provided for @terminalLifecycleDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get terminalLifecycleDisconnected;

  /// No description provided for @terminalLifecyclePreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing'**
  String get terminalLifecyclePreparing;

  /// No description provided for @terminalLifecycleVerifying.
  ///
  /// In en, this message translates to:
  /// **'Verifying'**
  String get terminalLifecycleVerifying;

  /// No description provided for @terminalLifecycleAuthenticating.
  ///
  /// In en, this message translates to:
  /// **'Authenticating'**
  String get terminalLifecycleAuthenticating;

  /// No description provided for @terminalLifecycleDisconnecting.
  ///
  /// In en, this message translates to:
  /// **'Disconnecting'**
  String get terminalLifecycleDisconnecting;

  /// No description provided for @terminalLifecycleIdle.
  ///
  /// In en, this message translates to:
  /// **'Idle'**
  String get terminalLifecycleIdle;

  /// No description provided for @forwardingDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Port Forwarding'**
  String get forwardingDialogTitle;

  /// No description provided for @forwardingLocalTitle.
  ///
  /// In en, this message translates to:
  /// **'Local'**
  String get forwardingLocalTitle;

  /// No description provided for @forwardingLocalSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Expose a remote service on this device.'**
  String get forwardingLocalSubtitle;

  /// No description provided for @forwardingRemoteTitle.
  ///
  /// In en, this message translates to:
  /// **'Remote'**
  String get forwardingRemoteTitle;

  /// No description provided for @forwardingRemoteSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Expose a local service on the remote host.'**
  String get forwardingRemoteSubtitle;

  /// No description provided for @forwardingSocksTitle.
  ///
  /// In en, this message translates to:
  /// **'SOCKS Proxy'**
  String get forwardingSocksTitle;

  /// No description provided for @forwardingSocksSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Start a local dynamic proxy for this SSH session.'**
  String get forwardingSocksSubtitle;

  /// No description provided for @forwardingLocalPortLabel.
  ///
  /// In en, this message translates to:
  /// **'Local port'**
  String get forwardingLocalPortLabel;

  /// No description provided for @forwardingRemoteHostLabel.
  ///
  /// In en, this message translates to:
  /// **'Remote host'**
  String get forwardingRemoteHostLabel;

  /// No description provided for @forwardingRemotePortLabel.
  ///
  /// In en, this message translates to:
  /// **'Remote port'**
  String get forwardingRemotePortLabel;

  /// No description provided for @forwardingBindHostLabel.
  ///
  /// In en, this message translates to:
  /// **'Bind host'**
  String get forwardingBindHostLabel;

  /// No description provided for @forwardingBindPortLabel.
  ///
  /// In en, this message translates to:
  /// **'Bind port'**
  String get forwardingBindPortLabel;

  /// No description provided for @forwardingLocalHostLabel.
  ///
  /// In en, this message translates to:
  /// **'Local host'**
  String get forwardingLocalHostLabel;

  /// No description provided for @forwardingLocalValidationError.
  ///
  /// In en, this message translates to:
  /// **'Ports must be 1-65535 and remote host is required.'**
  String get forwardingLocalValidationError;

  /// No description provided for @forwardingRemoteValidationError.
  ///
  /// In en, this message translates to:
  /// **'Bind host, local host, and ports must be valid.'**
  String get forwardingRemoteValidationError;

  /// No description provided for @forwardingDynamicValidationError.
  ///
  /// In en, this message translates to:
  /// **'Bind host and port must be valid.'**
  String get forwardingDynamicValidationError;

  /// No description provided for @forwardingLocalStartedSnack.
  ///
  /// In en, this message translates to:
  /// **'Local port forward started.'**
  String get forwardingLocalStartedSnack;

  /// No description provided for @forwardingLocalStartFailedSnack.
  ///
  /// In en, this message translates to:
  /// **'Local port forward could not start.'**
  String get forwardingLocalStartFailedSnack;

  /// No description provided for @forwardingLocalStoppedSnack.
  ///
  /// In en, this message translates to:
  /// **'Local port forward stopped.'**
  String get forwardingLocalStoppedSnack;

  /// No description provided for @forwardingLocalStopFailedSnack.
  ///
  /// In en, this message translates to:
  /// **'Local port forward could not stop.'**
  String get forwardingLocalStopFailedSnack;

  /// No description provided for @forwardingRemoteStartedSnack.
  ///
  /// In en, this message translates to:
  /// **'Remote port forward started.'**
  String get forwardingRemoteStartedSnack;

  /// No description provided for @forwardingRemoteStartFailedSnack.
  ///
  /// In en, this message translates to:
  /// **'Remote port forward could not start.'**
  String get forwardingRemoteStartFailedSnack;

  /// No description provided for @forwardingRemoteStoppedSnack.
  ///
  /// In en, this message translates to:
  /// **'Remote port forward stopped.'**
  String get forwardingRemoteStoppedSnack;

  /// No description provided for @forwardingRemoteStopFailedSnack.
  ///
  /// In en, this message translates to:
  /// **'Remote port forward could not stop.'**
  String get forwardingRemoteStopFailedSnack;

  /// No description provided for @forwardingSocksStartedSnack.
  ///
  /// In en, this message translates to:
  /// **'SOCKS proxy started.'**
  String get forwardingSocksStartedSnack;

  /// No description provided for @forwardingSocksStartFailedSnack.
  ///
  /// In en, this message translates to:
  /// **'SOCKS proxy could not start.'**
  String get forwardingSocksStartFailedSnack;

  /// No description provided for @forwardingSocksStoppedSnack.
  ///
  /// In en, this message translates to:
  /// **'SOCKS proxy stopped.'**
  String get forwardingSocksStoppedSnack;

  /// No description provided for @forwardingSocksStopFailedSnack.
  ///
  /// In en, this message translates to:
  /// **'SOCKS proxy could not stop.'**
  String get forwardingSocksStopFailedSnack;

  /// No description provided for @vaultCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Vault'**
  String get vaultCreateTitle;

  /// No description provided for @vaultUnlockTitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock Vault'**
  String get vaultUnlockTitle;

  /// No description provided for @vaultCreateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use a strong passphrase for hosts and keys.'**
  String get vaultCreateSubtitle;

  /// No description provided for @vaultUnlockSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your passphrase to decrypt your workspace.'**
  String get vaultUnlockSubtitle;

  /// No description provided for @vaultNewPassphraseLabel.
  ///
  /// In en, this message translates to:
  /// **'New passphrase'**
  String get vaultNewPassphraseLabel;

  /// No description provided for @vaultPassphraseLabel.
  ///
  /// In en, this message translates to:
  /// **'Passphrase'**
  String get vaultPassphraseLabel;

  /// No description provided for @vaultCreateAction.
  ///
  /// In en, this message translates to:
  /// **'Create Vault'**
  String get vaultCreateAction;

  /// No description provided for @vaultUnlockAction.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get vaultUnlockAction;

  /// No description provided for @vaultUnlockWithDeviceAction.
  ///
  /// In en, this message translates to:
  /// **'Use Face ID'**
  String get vaultUnlockWithDeviceAction;

  /// No description provided for @vaultUseRecoveryCodeAction.
  ///
  /// In en, this message translates to:
  /// **'Use recovery code'**
  String get vaultUseRecoveryCodeAction;

  /// No description provided for @vaultPassphraseRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a vault passphrase to continue.'**
  String get vaultPassphraseRequired;

  /// No description provided for @vaultInvalidPassphraseError.
  ///
  /// In en, this message translates to:
  /// **'Passphrase did not unlock the vault.'**
  String get vaultInvalidPassphraseError;

  /// No description provided for @vaultInvalidRecoveryKeyError.
  ///
  /// In en, this message translates to:
  /// **'Recovery key did not unlock the vault.'**
  String get vaultInvalidRecoveryKeyError;

  /// No description provided for @vaultInvalidRecoveryKeyFormatError.
  ///
  /// In en, this message translates to:
  /// **'Recovery key format is not supported.'**
  String get vaultInvalidRecoveryKeyFormatError;

  /// No description provided for @vaultLocalUnlockNotEnabledError.
  ///
  /// In en, this message translates to:
  /// **'Face ID vault unlock is not enabled on this device.'**
  String get vaultLocalUnlockNotEnabledError;

  /// No description provided for @vaultLocalUnlockFailedError.
  ///
  /// In en, this message translates to:
  /// **'Face ID unlock failed. Use the vault passphrase.'**
  String get vaultLocalUnlockFailedError;

  /// No description provided for @vaultLocalUnlockUnavailableError.
  ///
  /// In en, this message translates to:
  /// **'Face ID is not available on this device.'**
  String get vaultLocalUnlockUnavailableError;

  /// No description provided for @vaultEmptyPassphraseError.
  ///
  /// In en, this message translates to:
  /// **'Vault passphrase cannot be empty.'**
  String get vaultEmptyPassphraseError;

  /// No description provided for @vaultRecoveryKeyTitle.
  ///
  /// In en, this message translates to:
  /// **'Recovery Key'**
  String get vaultRecoveryKeyTitle;

  /// No description provided for @vaultRecoveryKeySaveInstruction.
  ///
  /// In en, this message translates to:
  /// **'Save this key before continuing.'**
  String get vaultRecoveryKeySaveInstruction;

  /// No description provided for @vaultRecoveryKeyWarningTitle.
  ///
  /// In en, this message translates to:
  /// **'Save this key now'**
  String get vaultRecoveryKeyWarningTitle;

  /// No description provided for @vaultRecoveryKeyWarningBody.
  ///
  /// In en, this message translates to:
  /// **'This key is shown only once. If it is lost, Serlink cannot retrieve it for you.'**
  String get vaultRecoveryKeyWarningBody;

  /// No description provided for @vaultCopyRecoveryKeyAction.
  ///
  /// In en, this message translates to:
  /// **'Copy Recovery Key'**
  String get vaultCopyRecoveryKeyAction;

  /// No description provided for @vaultRecoveryKeySavedAction.
  ///
  /// In en, this message translates to:
  /// **'I have saved it'**
  String get vaultRecoveryKeySavedAction;

  /// No description provided for @vaultRecoveryTitle.
  ///
  /// In en, this message translates to:
  /// **'Vault recovery'**
  String get vaultRecoveryTitle;

  /// No description provided for @vaultRecoveryBody.
  ///
  /// In en, this message translates to:
  /// **'Vault recovery tools are available.'**
  String get vaultRecoveryBody;

  /// No description provided for @vaultRecoveryDatabaseTitle.
  ///
  /// In en, this message translates to:
  /// **'Database recovery'**
  String get vaultRecoveryDatabaseTitle;

  /// No description provided for @vaultRecoveryDatabaseBody.
  ///
  /// In en, this message translates to:
  /// **'Serlink could not open this local database safely.'**
  String get vaultRecoveryDatabaseBody;

  /// No description provided for @vaultRecoveryHeaderTitle.
  ///
  /// In en, this message translates to:
  /// **'Vault header recovery'**
  String get vaultRecoveryHeaderTitle;

  /// No description provided for @vaultRecoveryHeaderBody.
  ///
  /// In en, this message translates to:
  /// **'The local vault header is invalid or incomplete.'**
  String get vaultRecoveryHeaderBody;

  /// No description provided for @vaultRecoveryRecordsTitle.
  ///
  /// In en, this message translates to:
  /// **'Record recovery'**
  String get vaultRecoveryRecordsTitle;

  /// No description provided for @vaultRecoveryRecordsBody.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one {# encrypted record failed authentication.} other {# encrypted records failed authentication.}}'**
  String vaultRecoveryRecordsBody(num count);

  /// No description provided for @vaultRecoveryRemoteTitle.
  ///
  /// In en, this message translates to:
  /// **'Remote sync recovery'**
  String get vaultRecoveryRemoteTitle;

  /// No description provided for @vaultRecoveryRemoteBody.
  ///
  /// In en, this message translates to:
  /// **'The remote sync set needs repair before it can be used.'**
  String get vaultRecoveryRemoteBody;

  /// No description provided for @vaultRestoreLatestBackupAction.
  ///
  /// In en, this message translates to:
  /// **'Restore latest backup'**
  String get vaultRestoreLatestBackupAction;

  /// No description provided for @vaultQuarantineRecordsAction.
  ///
  /// In en, this message translates to:
  /// **'Quarantine corrupt records'**
  String get vaultQuarantineRecordsAction;

  /// No description provided for @vaultCorruptRecordsQuarantinedSnack.
  ///
  /// In en, this message translates to:
  /// **'Corrupt records quarantined.'**
  String get vaultCorruptRecordsQuarantinedSnack;

  /// No description provided for @vaultResetTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset Vault'**
  String get vaultResetTitle;

  /// No description provided for @vaultRecoveryCodeTitle.
  ///
  /// In en, this message translates to:
  /// **'Recovery Code'**
  String get vaultRecoveryCodeTitle;

  /// No description provided for @vaultResetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Reset only if you cannot unlock this vault with your passphrase or recovery code.'**
  String get vaultResetSubtitle;

  /// No description provided for @vaultRecoveryCodeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your recovery code to unlock this vault.'**
  String get vaultRecoveryCodeSubtitle;

  /// No description provided for @vaultRecoveryCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Recovery code'**
  String get vaultRecoveryCodeLabel;

  /// No description provided for @vaultRecoveryCodeHelper.
  ///
  /// In en, this message translates to:
  /// **'Paste the full recovery code.'**
  String get vaultRecoveryCodeHelper;

  /// No description provided for @vaultResetVaultAction.
  ///
  /// In en, this message translates to:
  /// **'Reset vault'**
  String get vaultResetVaultAction;

  /// No description provided for @vaultResetPermanentlyAction.
  ///
  /// In en, this message translates to:
  /// **'Reset Vault Permanently'**
  String get vaultResetPermanentlyAction;

  /// No description provided for @vaultRecoveryCodeRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a recovery code to continue.'**
  String get vaultRecoveryCodeRequired;

  /// No description provided for @vaultResetTypePhraseError.
  ///
  /// In en, this message translates to:
  /// **'Type {phrase} to confirm reset.'**
  String vaultResetTypePhraseError(String phrase);

  /// No description provided for @vaultResetTypePhraseLabel.
  ///
  /// In en, this message translates to:
  /// **'Type {phrase}'**
  String vaultResetTypePhraseLabel(String phrase);

  /// No description provided for @vaultResetPhraseHelper.
  ///
  /// In en, this message translates to:
  /// **'The phrase is case-sensitive and required to reset.'**
  String get vaultResetPhraseHelper;

  /// No description provided for @vaultResetWarningTitle.
  ///
  /// In en, this message translates to:
  /// **'This is permanent on this device'**
  String get vaultResetWarningTitle;

  /// No description provided for @vaultResetWarningRecords.
  ///
  /// In en, this message translates to:
  /// **'Encrypted hosts, identities, snippets, transfer history, sync settings, and recovery data will be deleted.'**
  String get vaultResetWarningRecords;

  /// No description provided for @vaultResetWarningSyncedDevices.
  ///
  /// In en, this message translates to:
  /// **'If this vault is synced, other devices using the same synced vault will also be reset and cleared.'**
  String get vaultResetWarningSyncedDevices;

  /// No description provided for @vaultResetWarningSecrets.
  ///
  /// In en, this message translates to:
  /// **'Reset does not recover your passphrase or reveal existing secrets.'**
  String get vaultResetWarningSecrets;

  /// No description provided for @vaultResetWarningBackup.
  ///
  /// In en, this message translates to:
  /// **'You will need a backup or a new vault before continuing.'**
  String get vaultResetWarningBackup;

  /// No description provided for @credentialEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Credential'**
  String get credentialEditTitle;

  /// No description provided for @credentialLoadingSecretSemantics.
  ///
  /// In en, this message translates to:
  /// **'Loading credential secret'**
  String get credentialLoadingSecretSemantics;

  /// No description provided for @credentialNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Credential name'**
  String get credentialNameLabel;

  /// No description provided for @credentialUsernameHintLabel.
  ///
  /// In en, this message translates to:
  /// **'Username hint'**
  String get credentialUsernameHintLabel;

  /// No description provided for @credentialPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get credentialPasswordLabel;

  /// No description provided for @credentialKeyboardResponsesLabel.
  ///
  /// In en, this message translates to:
  /// **'Keyboard responses'**
  String get credentialKeyboardResponsesLabel;

  /// No description provided for @credentialKeyboardResponsesHelper.
  ///
  /// In en, this message translates to:
  /// **'One response per line.'**
  String get credentialKeyboardResponsesHelper;

  /// No description provided for @credentialNoSecretMaterial.
  ///
  /// In en, this message translates to:
  /// **'This credential has no stored secret material.'**
  String get credentialNoSecretMaterial;

  /// No description provided for @credentialSecretLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Credential secret could not be loaded.'**
  String get credentialSecretLoadFailed;

  /// No description provided for @credentialSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Credential could not be saved.'**
  String get credentialSaveFailed;

  /// No description provided for @credentialSshPrivateKeyTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'SSH Private Key'**
  String get credentialSshPrivateKeyTypeLabel;

  /// No description provided for @credentialOpenSshCertificateTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'OpenSSH Certificate'**
  String get credentialOpenSshCertificateTypeLabel;

  /// No description provided for @credentialCertificateLabel.
  ///
  /// In en, this message translates to:
  /// **'Certificate'**
  String get credentialCertificateLabel;

  /// No description provided for @credentialImportCertificateTooltip.
  ///
  /// In en, this message translates to:
  /// **'Import certificate'**
  String get credentialImportCertificateTooltip;

  /// No description provided for @syncConflictReviewDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Review sync conflicts'**
  String get syncConflictReviewDialogTitle;

  /// No description provided for @syncConflictApplying.
  ///
  /// In en, this message translates to:
  /// **'Applying'**
  String get syncConflictApplying;

  /// No description provided for @syncConflictApplyMergeAction.
  ///
  /// In en, this message translates to:
  /// **'Apply merge'**
  String get syncConflictApplyMergeAction;

  /// No description provided for @syncConflictLocalLabel.
  ///
  /// In en, this message translates to:
  /// **'Local'**
  String get syncConflictLocalLabel;

  /// No description provided for @syncConflictRemoteLabel.
  ///
  /// In en, this message translates to:
  /// **'Remote'**
  String get syncConflictRemoteLabel;

  /// No description provided for @syncConflictUnsupportedBody.
  ///
  /// In en, this message translates to:
  /// **'This record type currently requires whole-record resolution. Use the existing local or remote action for this conflict.'**
  String get syncConflictUnsupportedBody;

  /// No description provided for @sftpParentFolderTooltip.
  ///
  /// In en, this message translates to:
  /// **'Go to parent folder'**
  String get sftpParentFolderTooltip;

  /// No description provided for @sftpSearchPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Search files'**
  String get sftpSearchPlaceholder;

  /// No description provided for @sftpHideHiddenFilesTooltip.
  ///
  /// In en, this message translates to:
  /// **'Hide hidden files'**
  String get sftpHideHiddenFilesTooltip;

  /// No description provided for @sftpShowHiddenFilesTooltip.
  ///
  /// In en, this message translates to:
  /// **'Show hidden files'**
  String get sftpShowHiddenFilesTooltip;

  /// No description provided for @sftpOpenTerminalTooltip.
  ///
  /// In en, this message translates to:
  /// **'Open terminal tab'**
  String get sftpOpenTerminalTooltip;

  /// No description provided for @sftpUploadFileAction.
  ///
  /// In en, this message translates to:
  /// **'Upload file'**
  String get sftpUploadFileAction;

  /// No description provided for @sftpUploadFolderAction.
  ///
  /// In en, this message translates to:
  /// **'Upload folder'**
  String get sftpUploadFolderAction;

  /// No description provided for @sftpNewFolderTooltip.
  ///
  /// In en, this message translates to:
  /// **'New folder'**
  String get sftpNewFolderTooltip;

  /// No description provided for @sftpRefreshTooltip.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get sftpRefreshTooltip;

  /// No description provided for @sftpWaitingTitle.
  ///
  /// In en, this message translates to:
  /// **'SFTP'**
  String get sftpWaitingTitle;

  /// No description provided for @sftpWaitingBody.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the SFTP connection.'**
  String get sftpWaitingBody;

  /// No description provided for @sftpStartFolderTitle.
  ///
  /// In en, this message translates to:
  /// **'SFTP Start Folder'**
  String get sftpStartFolderTitle;

  /// No description provided for @sftpStartFolderBody.
  ///
  /// In en, this message translates to:
  /// **'Serlink could not list {path}. Choose a folder this account can access.'**
  String sftpStartFolderBody(String path);

  /// No description provided for @sftpErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'SFTP Error'**
  String get sftpErrorTitle;

  /// No description provided for @sftpEmptyFolderTitle.
  ///
  /// In en, this message translates to:
  /// **'Empty Folder'**
  String get sftpEmptyFolderTitle;

  /// No description provided for @sftpNoEntriesFilter.
  ///
  /// In en, this message translates to:
  /// **'No entries match the current filter.'**
  String get sftpNoEntriesFilter;

  /// No description provided for @sftpHiddenOnly.
  ///
  /// In en, this message translates to:
  /// **'This remote directory only contains hidden entries.'**
  String get sftpHiddenOnly;

  /// No description provided for @sftpNoVisible.
  ///
  /// In en, this message translates to:
  /// **'This remote directory has no visible entries.'**
  String get sftpNoVisible;

  /// No description provided for @sftpDirectoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Directory'**
  String get sftpDirectoryLabel;

  /// No description provided for @sftpFileLabel.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get sftpFileLabel;

  /// No description provided for @sftpSymlinkLabel.
  ///
  /// In en, this message translates to:
  /// **'Symlink'**
  String get sftpSymlinkLabel;

  /// No description provided for @sftpUnknownLabel.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get sftpUnknownLabel;

  /// No description provided for @sftpNewFolderTitle.
  ///
  /// In en, this message translates to:
  /// **'New Folder'**
  String get sftpNewFolderTitle;

  /// No description provided for @sftpFolderNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Folder name'**
  String get sftpFolderNameLabel;

  /// No description provided for @sftpFolderCreatedSnack.
  ///
  /// In en, this message translates to:
  /// **'Folder created.'**
  String get sftpFolderCreatedSnack;

  /// No description provided for @sftpSelectedFileNoPathSnack.
  ///
  /// In en, this message translates to:
  /// **'Selected file has no local path.'**
  String get sftpSelectedFileNoPathSnack;

  /// No description provided for @sftpUploadQueuedSnack.
  ///
  /// In en, this message translates to:
  /// **'Upload queued.'**
  String get sftpUploadQueuedSnack;

  /// No description provided for @sftpFolderUploadQueuedSnack.
  ///
  /// In en, this message translates to:
  /// **'Folder upload queued.'**
  String get sftpFolderUploadQueuedSnack;

  /// No description provided for @sftpFolderDownloadQueuedSnack.
  ///
  /// In en, this message translates to:
  /// **'Folder download queued.'**
  String get sftpFolderDownloadQueuedSnack;

  /// No description provided for @sftpDownloadQueuedSnack.
  ///
  /// In en, this message translates to:
  /// **'Download queued.'**
  String get sftpDownloadQueuedSnack;

  /// No description provided for @sftpMergeRemoteFolderTitle.
  ///
  /// In en, this message translates to:
  /// **'Merge remote folder?'**
  String get sftpMergeRemoteFolderTitle;

  /// No description provided for @sftpReplaceRemoteFileTitle.
  ///
  /// In en, this message translates to:
  /// **'Replace remote file?'**
  String get sftpReplaceRemoteFileTitle;

  /// No description provided for @sftpRemoteExistsOverwriteBody.
  ///
  /// In en, this message translates to:
  /// **'{path} already exists on the server. Matching files may be overwritten.'**
  String sftpRemoteExistsOverwriteBody(String path);

  /// No description provided for @sftpRemoteExistsBody.
  ///
  /// In en, this message translates to:
  /// **'{path} already exists on the server.'**
  String sftpRemoteExistsBody(String path);

  /// No description provided for @sftpMergeLocalFolderTitle.
  ///
  /// In en, this message translates to:
  /// **'Merge local folder?'**
  String get sftpMergeLocalFolderTitle;

  /// No description provided for @sftpReplaceLocalFileTitle.
  ///
  /// In en, this message translates to:
  /// **'Replace local file?'**
  String get sftpReplaceLocalFileTitle;

  /// No description provided for @sftpLocalExistsOverwriteBody.
  ///
  /// In en, this message translates to:
  /// **'{path} already exists on this device. Matching files may be overwritten.'**
  String sftpLocalExistsOverwriteBody(String path);

  /// No description provided for @sftpLocalExistsBody.
  ///
  /// In en, this message translates to:
  /// **'{path} already exists on this device.'**
  String sftpLocalExistsBody(String path);

  /// No description provided for @sftpNewNameLabel.
  ///
  /// In en, this message translates to:
  /// **'New name'**
  String get sftpNewNameLabel;

  /// No description provided for @sftpTargetPathLabel.
  ///
  /// In en, this message translates to:
  /// **'Target path'**
  String get sftpTargetPathLabel;

  /// No description provided for @sftpTargetExistsSnack.
  ///
  /// In en, this message translates to:
  /// **'Target path already exists.'**
  String get sftpTargetExistsSnack;

  /// No description provided for @sftpEntryRenamedSnack.
  ///
  /// In en, this message translates to:
  /// **'Entry renamed.'**
  String get sftpEntryRenamedSnack;

  /// No description provided for @sftpEntryMovedSnack.
  ///
  /// In en, this message translates to:
  /// **'Entry moved.'**
  String get sftpEntryMovedSnack;

  /// No description provided for @sftpChangePermissionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Change permissions'**
  String get sftpChangePermissionsTitle;

  /// No description provided for @sftpOctalPermissionsLabel.
  ///
  /// In en, this message translates to:
  /// **'Permissions (octal or symbolic)'**
  String get sftpOctalPermissionsLabel;

  /// No description provided for @sftpPermissionsOctalError.
  ///
  /// In en, this message translates to:
  /// **'Permissions must be octal, like 0644, or symbolic, like rw-r--r--.'**
  String get sftpPermissionsOctalError;

  /// No description provided for @sftpPermissionsUpdatedSnack.
  ///
  /// In en, this message translates to:
  /// **'Permissions updated.'**
  String get sftpPermissionsUpdatedSnack;

  /// No description provided for @sftpDeleteEntryTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}?'**
  String sftpDeleteEntryTitle(String name);

  /// No description provided for @sftpDeleteDirectoryBody.
  ///
  /// In en, this message translates to:
  /// **'This deletes the remote directory and its contents.'**
  String get sftpDeleteDirectoryBody;

  /// No description provided for @sftpDeleteFileBody.
  ///
  /// In en, this message translates to:
  /// **'This deletes the remote file.'**
  String get sftpDeleteFileBody;

  /// No description provided for @sftpEntryDeletedSnack.
  ///
  /// In en, this message translates to:
  /// **'Entry deleted.'**
  String get sftpEntryDeletedSnack;

  /// No description provided for @sftpFileSavedSnack.
  ///
  /// In en, this message translates to:
  /// **'File saved.'**
  String get sftpFileSavedSnack;

  /// No description provided for @remoteFilePreviewLimited.
  ///
  /// In en, this message translates to:
  /// **'Preview limited to {bytes}.'**
  String remoteFilePreviewLimited(String bytes);

  /// No description provided for @sftpDefaultDirectoryDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose SFTP Start Folder'**
  String get sftpDefaultDirectoryDialogTitle;

  /// No description provided for @sftpDefaultDirectoryFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'{path} could not be listed. {reason}'**
  String sftpDefaultDirectoryFailedMessage(String path, String reason);

  /// No description provided for @sftpStartFolderLabel.
  ///
  /// In en, this message translates to:
  /// **'Start folder'**
  String get sftpStartFolderLabel;

  /// No description provided for @sftpStartFolderHint.
  ///
  /// In en, this message translates to:
  /// **'/home/user'**
  String get sftpStartFolderHint;

  /// No description provided for @sftpAbsolutePathError.
  ///
  /// In en, this message translates to:
  /// **'Enter an absolute remote path.'**
  String get sftpAbsolutePathError;

  /// No description provided for @transferDeleteMenu.
  ///
  /// In en, this message translates to:
  /// **'Delete transfer'**
  String get transferDeleteMenu;

  /// No description provided for @transferEtaLeft.
  ///
  /// In en, this message translates to:
  /// **'{time} left'**
  String transferEtaLeft(String time);

  /// No description provided for @transferClearTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear transfers?'**
  String get transferClearTitle;

  /// No description provided for @transferClearBody.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Remove 1 transfer record from history.} other{Remove {count} transfer records from history.}}'**
  String transferClearBody(num count);

  /// No description provided for @transferClearActiveBody.
  ///
  /// In en, this message translates to:
  /// **'Remove {count} transfer records from history and cancel {activeCount} active transfers.'**
  String transferClearActiveBody(num count, num activeCount);

  /// No description provided for @transferClearedSnack.
  ///
  /// In en, this message translates to:
  /// **'Transfers cleared.'**
  String get transferClearedSnack;

  /// No description provided for @transferRemoveLocalFailedSnack.
  ///
  /// In en, this message translates to:
  /// **'Transfer removed, but the local file could not be deleted.'**
  String get transferRemoveLocalFailedSnack;

  /// No description provided for @transferAndLocalDeletedSnack.
  ///
  /// In en, this message translates to:
  /// **'Transfer and local file deleted.'**
  String get transferAndLocalDeletedSnack;

  /// No description provided for @transferDeletedSnack.
  ///
  /// In en, this message translates to:
  /// **'Transfer deleted.'**
  String get transferDeletedSnack;

  /// No description provided for @transferCompletedMissingSnack.
  ///
  /// In en, this message translates to:
  /// **'Completed item is no longer available locally.'**
  String get transferCompletedMissingSnack;

  /// No description provided for @transferOpenFailedSnack.
  ///
  /// In en, this message translates to:
  /// **'Completed item could not be opened.'**
  String get transferOpenFailedSnack;

  /// No description provided for @transferDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete transfer?'**
  String get transferDeleteTitle;

  /// No description provided for @transferDeleteLocalBody.
  ///
  /// In en, this message translates to:
  /// **'A local {kind} still exists at {path}. Remove the transfer only, or also delete the local {kind}?'**
  String transferDeleteLocalBody(String kind, String path);

  /// No description provided for @transferRemoveOnlyAction.
  ///
  /// In en, this message translates to:
  /// **'Remove transfer'**
  String get transferRemoveOnlyAction;

  /// No description provided for @transferDeleteLocalTooAction.
  ///
  /// In en, this message translates to:
  /// **'Delete {kind} too'**
  String transferDeleteLocalTooAction(String kind);

  /// No description provided for @transferMachineFrom.
  ///
  /// In en, this message translates to:
  /// **'From {name}'**
  String transferMachineFrom(String name);

  /// No description provided for @transferMachineTo.
  ///
  /// In en, this message translates to:
  /// **'To {name}'**
  String transferMachineTo(String name);

  /// No description provided for @transferRemoteMachineFallback.
  ///
  /// In en, this message translates to:
  /// **'Remote machine'**
  String get transferRemoteMachineFallback;

  /// No description provided for @transferFolderKind.
  ///
  /// In en, this message translates to:
  /// **'folder'**
  String get transferFolderKind;

  /// No description provided for @transferLinkKind.
  ///
  /// In en, this message translates to:
  /// **'link'**
  String get transferLinkKind;

  /// No description provided for @transferFileKind.
  ///
  /// In en, this message translates to:
  /// **'file'**
  String get transferFileKind;

  /// No description provided for @transferBytesTransferred.
  ///
  /// In en, this message translates to:
  /// **'{bytes} transferred'**
  String transferBytesTransferred(String bytes);

  /// No description provided for @transferStateQueued.
  ///
  /// In en, this message translates to:
  /// **'queued'**
  String get transferStateQueued;

  /// No description provided for @transferStateRunning.
  ///
  /// In en, this message translates to:
  /// **'running'**
  String get transferStateRunning;

  /// No description provided for @transferStatePaused.
  ///
  /// In en, this message translates to:
  /// **'paused'**
  String get transferStatePaused;

  /// No description provided for @transferStateCompleted.
  ///
  /// In en, this message translates to:
  /// **'completed'**
  String get transferStateCompleted;

  /// No description provided for @transferStateFailed.
  ///
  /// In en, this message translates to:
  /// **'failed'**
  String get transferStateFailed;

  /// No description provided for @transferStateCanceled.
  ///
  /// In en, this message translates to:
  /// **'canceled'**
  String get transferStateCanceled;

  /// No description provided for @dataExchangeLockedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock the vault to use this action.'**
  String get dataExchangeLockedSubtitle;

  /// No description provided for @dataExchangeTitle.
  ///
  /// In en, this message translates to:
  /// **'Import / Export'**
  String get dataExchangeTitle;

  /// No description provided for @dataExchangeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Backups stay available anytime. Host, identity, and SSH data require an unlocked vault.'**
  String get dataExchangeSubtitle;

  /// No description provided for @dataExchangeExportSection.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get dataExchangeExportSection;

  /// No description provided for @dataExchangeImportSection.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get dataExchangeImportSection;

  /// No description provided for @dataExchangeExportBackupTitle.
  ///
  /// In en, this message translates to:
  /// **'Export encrypted backup'**
  String get dataExchangeExportBackupTitle;

  /// No description provided for @dataExchangeExportBackupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Encrypted vault records and header.'**
  String get dataExchangeExportBackupSubtitle;

  /// No description provided for @dataExchangeExportDiagnosticBundleTitle.
  ///
  /// In en, this message translates to:
  /// **'Export diagnostic logs'**
  String get dataExchangeExportDiagnosticBundleTitle;

  /// No description provided for @dataExchangeExportDiagnosticBundleSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Redacted runtime details and failure clues.'**
  String get dataExchangeExportDiagnosticBundleSubtitle;

  /// No description provided for @dataExchangeExportHostMetadataTitle.
  ///
  /// In en, this message translates to:
  /// **'Export host metadata'**
  String get dataExchangeExportHostMetadataTitle;

  /// No description provided for @dataExchangeExportHostMetadataSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Host names, addresses, tags, and options.'**
  String get dataExchangeExportHostMetadataSubtitle;

  /// No description provided for @dataExchangeExportOpenSshConfigTitle.
  ///
  /// In en, this message translates to:
  /// **'Export OpenSSH config'**
  String get dataExchangeExportOpenSshConfigTitle;

  /// No description provided for @dataExchangeExportOpenSshConfigSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Selected hosts as an OpenSSH config.'**
  String get dataExchangeExportOpenSshConfigSubtitle;

  /// No description provided for @dataExchangeExportIdentityMetadataTitle.
  ///
  /// In en, this message translates to:
  /// **'Export identity metadata'**
  String get dataExchangeExportIdentityMetadataTitle;

  /// No description provided for @dataExchangeExportIdentityMetadataSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Display names, hints, and public fingerprints.'**
  String get dataExchangeExportIdentityMetadataSubtitle;

  /// No description provided for @dataExchangeImportBackupTitle.
  ///
  /// In en, this message translates to:
  /// **'Import encrypted backup'**
  String get dataExchangeImportBackupTitle;

  /// No description provided for @dataExchangeImportBackupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Merge records from a Serlink backup.'**
  String get dataExchangeImportBackupSubtitle;

  /// No description provided for @dataExchangeImportOpenSshConfigTitle.
  ///
  /// In en, this message translates to:
  /// **'Import OpenSSH config'**
  String get dataExchangeImportOpenSshConfigTitle;

  /// No description provided for @dataExchangeImportOpenSshConfigSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create hosts from an ssh config file.'**
  String get dataExchangeImportOpenSshConfigSubtitle;

  /// No description provided for @dataExchangeImportKnownHostsTitle.
  ///
  /// In en, this message translates to:
  /// **'Import known_hosts'**
  String get dataExchangeImportKnownHostsTitle;

  /// No description provided for @dataExchangeImportKnownHostsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add fingerprints for existing hosts.'**
  String get dataExchangeImportKnownHostsSubtitle;

  /// No description provided for @dataExchangeImportOpenSshCertificateTitle.
  ///
  /// In en, this message translates to:
  /// **'Import OpenSSH certificate'**
  String get dataExchangeImportOpenSshCertificateTitle;

  /// No description provided for @dataExchangeImportOpenSshCertificateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create an identity from key and certificate.'**
  String get dataExchangeImportOpenSshCertificateSubtitle;

  /// No description provided for @exportVaultBackupTitle.
  ///
  /// In en, this message translates to:
  /// **'Export encrypted backup?'**
  String get exportVaultBackupTitle;

  /// No description provided for @exportVaultBackupBody.
  ///
  /// In en, this message translates to:
  /// **'The backup contains encrypted vault records and the vault header. Keep it private.'**
  String get exportVaultBackupBody;

  /// No description provided for @backupExportedSnack.
  ///
  /// In en, this message translates to:
  /// **'Encrypted backup exported.'**
  String get backupExportedSnack;

  /// No description provided for @noHostsAvailableExportSnack.
  ///
  /// In en, this message translates to:
  /// **'No hosts are available to export.'**
  String get noHostsAvailableExportSnack;

  /// No description provided for @exportHostMetadataTitle.
  ///
  /// In en, this message translates to:
  /// **'Export host metadata?'**
  String get exportHostMetadataTitle;

  /// No description provided for @exportHostMetadataBody.
  ///
  /// In en, this message translates to:
  /// **'Exports host names, addresses, usernames, tags, jump host links, and connection options. Credentials and private key material are excluded.'**
  String get exportHostMetadataBody;

  /// No description provided for @hostMetadataExportedSnack.
  ///
  /// In en, this message translates to:
  /// **'Host metadata exported.'**
  String get hostMetadataExportedSnack;

  /// No description provided for @hostMetadataExportFailedSnack.
  ///
  /// In en, this message translates to:
  /// **'Host metadata could not be exported.'**
  String get hostMetadataExportFailedSnack;

  /// No description provided for @exportOpenSshConfigTitle.
  ///
  /// In en, this message translates to:
  /// **'Export OpenSSH config?'**
  String get exportOpenSshConfigTitle;

  /// No description provided for @exportOpenSshConfigBody.
  ///
  /// In en, this message translates to:
  /// **'Exports selected hosts and any required jump hosts as an OpenSSH config. Credentials and private key material are excluded.'**
  String get exportOpenSshConfigBody;

  /// No description provided for @openSshConfigExportedSnack.
  ///
  /// In en, this message translates to:
  /// **'OpenSSH config exported.'**
  String get openSshConfigExportedSnack;

  /// No description provided for @exportIdentityMetadataTitle.
  ///
  /// In en, this message translates to:
  /// **'Export identity metadata?'**
  String get exportIdentityMetadataTitle;

  /// No description provided for @identityMetadataExportedSnack.
  ///
  /// In en, this message translates to:
  /// **'Identity metadata exported.'**
  String get identityMetadataExportedSnack;

  /// No description provided for @exportDiagnosticBundleTitle.
  ///
  /// In en, this message translates to:
  /// **'Export diagnostic logs?'**
  String get exportDiagnosticBundleTitle;

  /// No description provided for @exportDiagnosticBundleBody.
  ///
  /// In en, this message translates to:
  /// **'Diagnostic logs are redacted and exclude terminal output, commands, hosts, usernames, paths, credentials, and private keys.'**
  String get exportDiagnosticBundleBody;

  /// No description provided for @diagnosticBundleExportedSnack.
  ///
  /// In en, this message translates to:
  /// **'Diagnostic logs exported.'**
  String get diagnosticBundleExportedSnack;

  /// No description provided for @backupOperationFailed.
  ///
  /// In en, this message translates to:
  /// **'Backup operation failed.'**
  String get backupOperationFailed;

  /// No description provided for @diagnosticExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Diagnostic logs could not be exported.'**
  String get diagnosticExportFailed;

  /// No description provided for @openSshConfigExportFailed.
  ///
  /// In en, this message translates to:
  /// **'OpenSSH config could not be exported.'**
  String get openSshConfigExportFailed;

  /// No description provided for @identityMetadataExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Identity metadata could not be exported.'**
  String get identityMetadataExportFailed;

  /// No description provided for @importFailed.
  ///
  /// In en, this message translates to:
  /// **'Import failed.'**
  String get importFailed;

  /// No description provided for @importEncryptedBackupTitle.
  ///
  /// In en, this message translates to:
  /// **'Import encrypted backup?'**
  String get importEncryptedBackupTitle;

  /// No description provided for @importEncryptedBackupBody.
  ///
  /// In en, this message translates to:
  /// **'This replaces the local vault header and merges encrypted records from the selected backup.'**
  String get importEncryptedBackupBody;

  /// No description provided for @backupImportedSnack.
  ///
  /// In en, this message translates to:
  /// **'Encrypted backup imported.'**
  String get backupImportedSnack;

  /// No description provided for @noImportableOpenSshHostsSnack.
  ///
  /// In en, this message translates to:
  /// **'No importable OpenSSH hosts found.'**
  String get noImportableOpenSshHostsSnack;

  /// No description provided for @openSshHostsImportedSnack.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Imported 1 host.} other{Imported {count} hosts.}}'**
  String openSshHostsImportedSnack(num count);

  /// No description provided for @openSshHostsImportedSkippedSnack.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Imported 1 host, skipped {skipped}.} other{Imported {count} hosts, skipped {skipped}.}}'**
  String openSshHostsImportedSkippedSnack(num count, num skipped);

  /// No description provided for @importKnownHostsTitle.
  ///
  /// In en, this message translates to:
  /// **'Import known_hosts?'**
  String get importKnownHostsTitle;

  /// No description provided for @importKnownHostsBody.
  ///
  /// In en, this message translates to:
  /// **'Serlink will import fingerprints that match existing hosts by hostname and port. Hostnames and fingerprints are stored as encrypted vault records.'**
  String get importKnownHostsBody;

  /// No description provided for @knownHostsImportedSnack.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Imported 1 fingerprint.} other{Imported {count} fingerprints.}}'**
  String knownHostsImportedSnack(num count);

  /// No description provided for @knownHostsImportedUnmatchedSnack.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Imported 1 fingerprint, {unmatched} unmatched.} other{Imported {count} fingerprints, {unmatched} unmatched.}}'**
  String knownHostsImportedUnmatchedSnack(num count, num unmatched);

  /// No description provided for @identityImportedSnack.
  ///
  /// In en, this message translates to:
  /// **'Imported {name}.'**
  String identityImportedSnack(String name);

  /// No description provided for @importOpenSshConfigTitle.
  ///
  /// In en, this message translates to:
  /// **'Import OpenSSH config?'**
  String get importOpenSshConfigTitle;

  /// No description provided for @openSshConfigHostsReady.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 host ready to import.} other{{count} hosts ready to import.}}'**
  String openSshConfigHostsReady(num count);

  /// No description provided for @openSshConfigHostsReadySkipped.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 host ready to import, {skipped} skipped.} other{{count} hosts ready to import, {skipped} skipped.}}'**
  String openSshConfigHostsReadySkipped(num count, num skipped);

  /// No description provided for @importWarningsTitle.
  ///
  /// In en, this message translates to:
  /// **'Import warnings'**
  String get importWarningsTitle;

  /// No description provided for @moreWarnings.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 more warning.} other{{count} more warnings.}}'**
  String moreWarnings(num count);

  /// No description provided for @certificateDefaultName.
  ///
  /// In en, this message translates to:
  /// **'Certificate {comment}'**
  String certificateDefaultName(String comment);

  /// No description provided for @importOpenSshCertificateTitle.
  ///
  /// In en, this message translates to:
  /// **'Import OpenSSH certificate?'**
  String get importOpenSshCertificateTitle;

  /// No description provided for @importAlgorithmLabel.
  ///
  /// In en, this message translates to:
  /// **'Algorithm'**
  String get importAlgorithmLabel;

  /// No description provided for @importCommentLabel.
  ///
  /// In en, this message translates to:
  /// **'Comment'**
  String get importCommentLabel;

  /// No description provided for @passphraseWhitespaceError.
  ///
  /// In en, this message translates to:
  /// **'Passphrase cannot have leading or trailing spaces.'**
  String get passphraseWhitespaceError;

  /// No description provided for @exportFieldHostnames.
  ///
  /// In en, this message translates to:
  /// **'hostnames'**
  String get exportFieldHostnames;

  /// No description provided for @exportFieldUsernames.
  ///
  /// In en, this message translates to:
  /// **'usernames'**
  String get exportFieldUsernames;

  /// No description provided for @exportFieldPorts.
  ///
  /// In en, this message translates to:
  /// **'ports'**
  String get exportFieldPorts;

  /// No description provided for @exportFieldJumpHostAliases.
  ///
  /// In en, this message translates to:
  /// **'jump host aliases'**
  String get exportFieldJumpHostAliases;

  /// No description provided for @exportFieldConnectionSettings.
  ///
  /// In en, this message translates to:
  /// **'connection settings'**
  String get exportFieldConnectionSettings;

  /// No description provided for @exportFieldDisplayNames.
  ///
  /// In en, this message translates to:
  /// **'display names'**
  String get exportFieldDisplayNames;

  /// No description provided for @exportFieldUsernameHints.
  ///
  /// In en, this message translates to:
  /// **'username hints'**
  String get exportFieldUsernameHints;

  /// No description provided for @exportFieldPublicKeyFingerprints.
  ///
  /// In en, this message translates to:
  /// **'public key fingerprints'**
  String get exportFieldPublicKeyFingerprints;

  /// No description provided for @exportFieldCertificatePrincipals.
  ///
  /// In en, this message translates to:
  /// **'certificate principals'**
  String get exportFieldCertificatePrincipals;

  /// No description provided for @cancelAction.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelAction;

  /// No description provided for @selectAction.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get selectAction;

  /// No description provided for @searchAction.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchAction;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ja', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
