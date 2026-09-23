// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'Serlink';

  @override
  String get navHosts => 'ホスト';

  @override
  String get navSessions => 'セッション';

  @override
  String get navTransfers => '転送';

  @override
  String get navSnippets => 'スニペット';

  @override
  String get navSettings => '設定';

  @override
  String get searchHostsPlaceholder => 'ホスト、アドレス、タグを検索';

  @override
  String get searchSnippetsPlaceholder => 'スニペットとコマンドを検索';

  @override
  String get searchSessionsPlaceholder => 'アクティブなセッションを検索';

  @override
  String get searchTransfersPlaceholder => '転送を検索';

  @override
  String get searchSettingsPlaceholder => '設定を検索';

  @override
  String get openLocalTerminalTooltip => 'ローカル端末タブを開く';

  @override
  String get clearSearchTooltip => '検索をクリア';

  @override
  String get vaultTitle => 'ボールト';

  @override
  String get hostsTitle => 'ホスト';

  @override
  String get hostsLoading => '暗号化されたホスト記録を読み込んでいます';

  @override
  String get hostsNoMatchesTitle => '一致なし';

  @override
  String get hostsNoMatchesBody => '現在のワークスペース検索に一致するホストはありません。';

  @override
  String get hostsDeleteTitle => 'ホストを削除しますか？';

  @override
  String get hostsDeleteBody => 'このホストと、他のホストで使われていない認証情報を削除します。';

  @override
  String get hostsDeleteAction => '削除';

  @override
  String get hostsDeletedSnack => 'ホストを削除しました。';

  @override
  String get hostsDeleteFailedSnack => 'ホストを削除できませんでした。';

  @override
  String get hostsAddTooltip => 'ホストを追加';

  @override
  String get hostsSortTooltip => 'ホストを並べ替え';

  @override
  String get hostsSortByName => '名前順';

  @override
  String get hostsSortByLastConnected => '最終接続順';

  @override
  String get hostsSortByAdded => '追加日時順';

  @override
  String get hostsEmptyTitle => 'ホストがありません';

  @override
  String get hostsEmptyBody => 'SSH 設定をインポートするか、ホストを追加してセッションを開始します。';

  @override
  String get hostsAddAction => 'ホストを追加';

  @override
  String get sessionsEmptyTitle => 'アクティブなタブはありません';

  @override
  String get sessionsEmptyBody => 'ホストから開くと、端末または SFTP タブを作成できます。';

  @override
  String get snippetsTitle => 'スニペット';

  @override
  String get snippetsLockedBody => 'コマンドスニペットを管理するにはボールトを解除してください。';

  @override
  String get snippetsLoading => '暗号化されたスニペットを読み込んでいます。';

  @override
  String get snippetsNoMatchesBody => '現在のワークスペース検索に一致するスニペットはありません。';

  @override
  String get snippetsAddTooltip => 'スニペットを追加';

  @override
  String get snippetsEmptyTitle => 'スニペットがありません';

  @override
  String get snippetsEmptyBody => 'よく使う端末コマンドを再利用できるように、コマンドスニペットを追加します。';

  @override
  String get snippetsAddAction => 'スニペットを追加';

  @override
  String get transfersTitle => '転送';

  @override
  String get transfersPreparing => '転送キューを準備しています。';

  @override
  String get transfersEmptyTitle => '転送はありません';

  @override
  String get transfersEmptyBody => 'SFTP のアップロードとダウンロードはここに表示されます。';

  @override
  String get transfersNoMatchesBody => '現在のワークスペース検索に一致する転送タスクはありません。';

  @override
  String transfersItemCount(num count) {
    return '$count 件';
  }

  @override
  String transfersActiveCount(num count) {
    return '$count 件が実行中';
  }

  @override
  String get transfersClearAction => 'クリア';

  @override
  String get settingsTitle => '設定';

  @override
  String get settingsSubtitle => 'セキュリティ、同期、インポート/エクスポート、実行時の制御。';

  @override
  String get settingsGeneralSection => '一般';

  @override
  String get settingsLanguageTitle => '言語';

  @override
  String get settingsLanguageSubtitle => 'アプリの表示言語を選択します。';

  @override
  String get settingsLanguageSubtitleMobile => '表示言語';

  @override
  String get settingsLanguageSystem => 'システムに合わせる';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsLanguageChinese => '简体中文';

  @override
  String get settingsLanguageJapanese => '日本語';

  @override
  String get settingsLanguageSaved => '言語を更新しました。';

  @override
  String get settingsLanguageSaveFailed => '言語を更新できませんでした。';

  @override
  String get settingsSecuritySection => 'セキュリティ';

  @override
  String get settingsVaultTitle => 'ボールト';

  @override
  String get settingsVaultPreparing => '暗号化ストレージを準備しています';

  @override
  String get settingsVaultWaitingICloud => 'iCloud 同期を待っています。しばらくお待ちください。';

  @override
  String get settingsVaultNotCreatedPill => 'ボールト未作成';

  @override
  String get settingsVaultLockedPill => 'ボールトはロック中';

  @override
  String get settingsVaultUnlockedPill => 'ボールトはロック解除済み';

  @override
  String get settingsVaultLoadingPill => 'ボールトを読み込み中';

  @override
  String get settingsVaultNotCreated => '未作成です。';

  @override
  String get settingsVaultLocked => 'ロック中です。既存の接続は動作を続けます。';

  @override
  String get settingsVaultLockedMobile => 'ロック中';

  @override
  String get settingsVaultUnlocked => '新しい接続プロファイルを解決できます。';

  @override
  String get settingsVaultUnlockedMobile => '解除済み';

  @override
  String get settingsLockAction => 'ロック';

  @override
  String get settingsRecoverResetAction => '復旧 / リセット';

  @override
  String get settingsLocalUnlockTitle => 'Face ID 解除';

  @override
  String get settingsLocalUnlockSemantics => 'Face ID 解除を有効にする';

  @override
  String get settingsLocalUnlockNeedsVault =>
      'Face ID 解除を有効にする前にボールトを作成してください。';

  @override
  String get settingsLocalUnlockNeedsVaultMobile => '先に作成';

  @override
  String get settingsLocalUnlockEnabled => '有効です。ボールトをロックすると Face ID で解除できます。';

  @override
  String get settingsLocalUnlockEnabledMobile => 'Face ID 可';

  @override
  String get settingsLocalUnlockUnavailable => 'このデバイスでは Face ID を利用できません。';

  @override
  String get settingsLocalUnlockUnavailableMobile => '利用不可';

  @override
  String get settingsLocalUnlockDisabled => '無効です。ロック後はパスフレーズまたは復旧キーが必要です。';

  @override
  String get settingsLocalUnlockDisabledMobile => 'パスフレーズ必須';

  @override
  String get settingsUnlockWithDeviceAction => 'Face ID を使用';

  @override
  String get settingsBackgroundPrivacyTitle => 'バックグラウンドのプライバシー';

  @override
  String get settingsBackgroundPrivacySemantics => 'バックグラウンドでプライバシー画面を表示';

  @override
  String get settingsBackgroundPrivacyEnabled =>
      'オン。Serlink がバックグラウンドに入るとロック画面を表示します。';

  @override
  String get settingsBackgroundPrivacyDisabled =>
      'オフ。バックグラウンドでも現在の画面を表示したままにします。';

  @override
  String get settingsBackgroundPrivacySaved => 'バックグラウンドのプライバシー設定を更新しました。';

  @override
  String get settingsBackgroundPrivacySaveFailed =>
      'バックグラウンドのプライバシー設定を更新できませんでした。';

  @override
  String get settingsSshConfigAutoImportTitle => 'SSH 設定の自動インポート';

  @override
  String get settingsSshConfigAutoImportSemantics => 'SSH 設定の新しいホストを自動的にインポート';

  @override
  String get settingsSshConfigAutoImportEnabled =>
      'オン。~/.ssh/config の新しいホストを自動的にインポートします。';

  @override
  String get settingsSshConfigAutoImportDisabled => 'オフ。新しいホストをインポートする前に確認します。';

  @override
  String get settingsSshConfigAutoImportSaved => 'SSH 設定の自動インポートを更新しました。';

  @override
  String get settingsSshConfigAutoImportSaveFailed =>
      'SSH 設定の自動インポートを更新できませんでした。';

  @override
  String get sshConfigNewHostsTitle => '新しい SSH 設定ホスト';

  @override
  String sshConfigNewHostsBody(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 台の新しいホスト',
      one: '1 台の新しいホスト',
    );
    return '~/.ssh/config に $_temp0 が見つかりました。';
  }

  @override
  String get sshConfigAutoImportFutureTitle => '今後の追加を自動インポート';

  @override
  String get settingsCredentialsTitle => '認証情報';

  @override
  String get settingsCredentialsLocked => '暗号化された認証情報を確認するにはボールトを解除してください。';

  @override
  String get settingsCredentialsLockedMobile => '解除が必要';

  @override
  String get settingsKnownHostsTitle => '既知のホスト';

  @override
  String get settingsKnownHostsLocked => '信頼済みホスト指紋を確認するにはボールトを解除してください。';

  @override
  String get settingsKnownHostsLockedMobile => '解除が必要';

  @override
  String get settingsManageAction => '管理';

  @override
  String get settingsMcpSection => 'MCP / エージェントアクセス';

  @override
  String get settingsMcpServerTitle => 'エージェントサーバー';

  @override
  String get settingsMcpServerSemantics => 'エージェントサーバーを有効にする';

  @override
  String settingsMcpServerRunning(String url) {
    return '$url で実行中';
  }

  @override
  String get settingsMcpServerStopped => '停止しています。';

  @override
  String settingsMcpServerError(String error) {
    return 'エラー: $error';
  }

  @override
  String get settingsMcpTokenTitle => 'アクセストークン';

  @override
  String get settingsMcpConfigTitle => 'クライアント設定';

  @override
  String get settingsMcpHttpConfigNeedsServer =>
      'エージェントサーバーを起動すると HTTP 設定を利用できます。';

  @override
  String get settingsMcpInstallTitle => 'エージェントへインストール';

  @override
  String get settingsMcpInstallAction => 'インストール';

  @override
  String get settingsMcpUpdateAction => '更新';

  @override
  String get settingsMcpInstalledLabel => 'インストール済み';

  @override
  String get settingsMcpInstallNoneDetected => '対応するエージェントがこの Mac で見つかりません。';

  @override
  String settingsMcpInstallSuccess(String agent) {
    return '$agent に Serlink MCP 設定を書き込みました。';
  }

  @override
  String settingsMcpInstallFailed(String error) {
    return '設定の書き込みに失敗しました: $error';
  }

  @override
  String get settingsMcpTokenNotAvailable => 'サーバーを起動するとトークンが生成されます。';

  @override
  String get settingsMcpTokenRevealTooltip => 'トークンを表示';

  @override
  String get settingsMcpTokenHideTooltip => 'トークンを隠す';

  @override
  String get settingsMcpTokenCopyTooltip => 'トークンをコピー';

  @override
  String get settingsMcpTokenCopied => 'トークンをクリップボードにコピーしました。';

  @override
  String get settingsMcpCopyHttpConfigAction => 'HTTP MCP 設定をコピー (JSON)';

  @override
  String get settingsMcpCopyStdioConfigAction => 'stdio ヘルパー設定をコピー (JSON)';

  @override
  String get settingsMcpConfigCopied => 'MCP クライアント設定をクリップボードにコピーしました。';

  @override
  String get settingsMcpStdioPathHint => 'このパスはアプリが同じ場所にある間有効です。';

  @override
  String get settingsMcpStdioNotInstalled =>
      'stdio ヘルパーは Serlink のリリースビルドに同梱されており、このインストールでは利用できません。';

  @override
  String get settingsMcpGrantsTitle => '有効な許可';

  @override
  String get settingsMcpGrantsEmpty => '現在アクセス権を持つエージェントはありません。';

  @override
  String get settingsMcpGrantExpiry => 'アプリ終了まで';

  @override
  String get settingsMcpRevokeAction => '取り消す';

  @override
  String get settingsMcpSessionsTitle => 'アクティブなエージェントセッション';

  @override
  String get settingsMcpSessionsEmpty => 'アクティブなエージェントセッションはありません。';

  @override
  String settingsMcpSessionOpenedAt(String time) {
    return '$time に開始';
  }

  @override
  String agentPaneBadgeTooltip(String client) {
    return '$client が操作しています。';
  }

  @override
  String get agentPaneBadgeCloseTooltip => 'エージェントセッションを閉じる';

  @override
  String get settingsDataSection => 'データ';

  @override
  String get settingsImportExportTitle => 'インポート / エクスポート';

  @override
  String get settingsImportExportSubtitle =>
      'バックアップ、OpenSSH ファイル、証明書、known_hosts、メタデータ。';

  @override
  String get settingsImportExportSubtitleMobile => 'バックアップと SSH';

  @override
  String get settingsOpenAction => '開く';

  @override
  String get settingsRuntimeSection => '実行時';

  @override
  String get settingsDiagnosticBundleTitle => '診断ログ';

  @override
  String get settingsExportAction => 'エクスポート';

  @override
  String get settingsAboutSection => '情報';

  @override
  String get settingsRepositoryOpenFailed => 'リポジトリのリンクを開けませんでした。';

  @override
  String settingsAppVersionOnly(String version) {
    return 'バージョン $version';
  }

  @override
  String settingsAppVersionLabel(String version, String buildNumber) {
    return 'バージョン $version（$buildNumber）';
  }

  @override
  String get settingsAppVersionLoading => 'バージョンを読み込み中';

  @override
  String get settingsAppVersionUnavailable => 'バージョン情報を取得できません';

  @override
  String get settingsEnableLocalUnlockTitle => 'Face ID 解除を有効にしますか？';

  @override
  String get settingsDisableLocalUnlockTitle => 'Face ID 解除を無効にしますか？';

  @override
  String get settingsEnableLocalUnlockBody =>
      'Serlink は Face ID で保護されたランダムなデバイスキーを保存します。ボールトのパスフレーズは保存されません。';

  @override
  String get settingsDisableLocalUnlockBody =>
      'Face ID で保護されたデバイスキーを削除します。既存の接続は動作を続けます。';

  @override
  String get vaultEnableFaceIdUnlockTitle => 'Face ID での解除を有効にしますか？';

  @override
  String get vaultEnableFaceIdUnlockBody =>
      'このデバイスで Face ID を使ってボールトを解除できます。Serlink は Face ID で保護されたランダムなデバイスキーのみを保存し、ボールトのパスフレーズは保存しません。';

  @override
  String get settingsEnableAction => '有効にする';

  @override
  String get settingsDisableAction => '無効にする';

  @override
  String get settingsLocalUnlockEnabledSnack =>
      'Face ID 解除を有効にしました。ボールトをロックすると Face ID を使用できます。';

  @override
  String get settingsLocalUnlockVerifyFailedSnack => 'Face ID 解除を確認できませんでした。';

  @override
  String get settingsLocalUnlockDisabledSnack => 'Face ID 解除を無効にしました。';

  @override
  String get settingsLocalUnlockStillAvailableSnack =>
      'このデバイスでは Face ID 解除がまだ利用できます。';

  @override
  String get settingsLocalUnlockUpdateFailed => 'Face ID 解除を更新できませんでした。';

  @override
  String get copyAction => 'コピー';

  @override
  String get syncSectionTitle => '同期';

  @override
  String get syncLoadingSettings => '同期設定を読み込んでいます。';

  @override
  String get syncLoadingEncryptedSettings => '暗号化された同期設定を読み込んでいます。';

  @override
  String get syncConfigureAction => '構成';

  @override
  String get syncEditAction => '編集';

  @override
  String get syncWebDavLocked => '暗号化同期を構成するにはボールトを解除してください。';

  @override
  String get syncICloudChecking => 'iCloud の利用可否を確認しています。';

  @override
  String get syncICloudLocked => 'iCloud で同期するにはボールトを解除してください。';

  @override
  String get syncDevicesTitle => 'デバイス';

  @override
  String get syncDevicesLoading => '暗号化されたデバイス記録を読み込んでいます。';

  @override
  String get syncViewAction => '表示';

  @override
  String get syncResetAction => 'リセット';

  @override
  String get syncRepairTitle => '同期の修復';

  @override
  String get syncRepairAction => '修復';

  @override
  String get syncRepairClockTitle => 'ローカル時刻を確認';

  @override
  String get syncRepairClockBody =>
      'WebDAV 証明書はまだ有効ではありません。このデバイスの時刻とタイムゾーンを確認し、自動同期の再試行を待ってください。';

  @override
  String get syncRepairTrustCertificateTitle => 'WebDAV 証明書を信頼しますか?';

  @override
  String get syncRepairTrustCertificateBody =>
      'WebDAV サーバーは信頼されていない証明書を使用しています。このエンドポイントの信頼を保存する前にフィンガープリントを確認してください。';

  @override
  String get syncRepairRemoteRebuildTitle => 'リモート同期を修復しますか?';

  @override
  String get syncRepairRemoteRebuildBody =>
      'リモートのマニフェストまたはレコードオブジェクトが不完全か破損しています。Serlink はローカルの暗号化レコードから再構築できます。';

  @override
  String get syncRepairInitializeRemoteTitle => 'リモート同期を初期化しますか?';

  @override
  String get syncRepairInitializeRemoteBody =>
      'リモートの場所に Serlink マニフェストがありません。Serlink はこの暗号化ボールトから作成できます。';

  @override
  String get syncRepairReplaceRemoteTitle => 'リモートボールトを置き換えますか?';

  @override
  String get syncRepairReplaceRemoteBody =>
      'リモートの場所は別のボールトに属しています。置き換えると、そのリモート Serlink 同期データがこの暗号化ボールトで上書きされます。';

  @override
  String get syncRepairRestoreLocalTitle => 'ローカル同期データを復元しますか?';

  @override
  String get syncRepairRestoreLocalBody =>
      'リモート同期を再構築する前にローカルボールトデータの復旧が必要です。Serlink は現在のリモート同期データからローカルの暗号化レコードを復元できます。';

  @override
  String get syncRemoteRepaired => 'リモート同期を修復しました。';

  @override
  String get syncWebDavCertificateTrustSaved => 'WebDAV 証明書の信頼を保存しました。';

  @override
  String get syncErrorVaultDataMissing => '同期に必要なボールトデータがこのデバイスにありません。';

  @override
  String get syncErrorRemoteDataUnreadable => 'リモート同期データを読み取れませんでした。';

  @override
  String get syncErrorRemoteDataMissing => 'リモート同期データが見つかりません。';

  @override
  String get syncErrorRemoteWrongVault => 'リモート同期データは別のボールトに属しています。';

  @override
  String get syncErrorRemoteDataInvalid => 'リモート同期データが無効または破損しています。';

  @override
  String get syncErrorRemoteDataMismatch => 'リモート同期データがその内容と一致しません。';

  @override
  String get syncErrorRemoteVersionUnsupported =>
      'リモート同期データは新しいバージョンの Serlink で書き込まれました。同期する前に Serlink を更新するか、このデバイスで同期をオフにしてください。';

  @override
  String get syncErrorRemoteVaultDataMissing => 'リモートのボールトデータが見つかりません。';

  @override
  String get syncErrorRemoteVaultDataInvalid => 'リモートのボールトデータが無効または破損しています。';

  @override
  String get syncErrorRemoteResetMarkerInvalid => 'リモートのボールトリセットマーカーが無効です。';

  @override
  String get syncErrorRemoteChanged => '同期中にリモートデータが変更されました。';

  @override
  String get syncErrorRemoteVaultReset => 'リモートのボールトがリセットされました。';

  @override
  String get syncErrorNoConflictsSelected => 'マージする同期競合が選択されていません。';

  @override
  String get syncErrorConflictRecordMissing => '競合するレコードはこのデバイスにもう存在しません。';

  @override
  String get syncErrorVaultLocked => '同期する前にボールトを解除してください。';

  @override
  String get syncErrorLocalUnhealthy => '同期する前にローカルのボールトデータの復旧が必要です。';

  @override
  String get syncErrorProviderMissing => '有効な同期プロバイダーがありません。';

  @override
  String get syncErrorStagedProviderInvalid => 'ステージされた同期プロバイダーが無効です。';

  @override
  String get syncICloudEnabledSnack => 'iCloud 同期を有効にしました。';

  @override
  String get syncICloudPausedSnack => 'iCloud 同期を一時停止しました。';

  @override
  String get syncICloudRemoteVaultAdoptedSnack =>
      'iCloud に既存の Serlink ボールトがあります。そのボールトのパスフレーズで同期を続行してください。';

  @override
  String get syncICloudRemoteVaultAdoptedAfterInitializeSnack =>
      'iCloud の既存ボールトに切り替えたため、入力したパスフレーズは適用されませんでした。iCloud ボールトのパスフレーズで解除してください。';

  @override
  String get syncWebDavRemoteVaultAdoptedSnack =>
      'リモートのボールトに切り替えました。リモートボールトのパスフレーズで解除してください。';

  @override
  String get syncICloudUnavailableError => 'iCloud 同期は利用できません。';

  @override
  String get syncICloudSetupFailedError => 'iCloud 同期を設定できませんでした。';

  @override
  String syncConflictsResolvedSnack(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '同期競合を解決しました。$count 件の暗号化記録を同期しました。',
      one: '同期競合を解決しました。1 件の暗号化記録を同期しました。',
    );
    return '$_temp0';
  }

  @override
  String get syncSettingsLoadFailed => '同期設定を読み込めませんでした。';

  @override
  String syncLocalTimeLabel(String time) {
    return 'ローカル時刻: $time';
  }

  @override
  String syncEndpointLabel(String endpoint) {
    return 'エンドポイント: $endpoint';
  }

  @override
  String syncValidFromLabel(String time) {
    return '有効開始: $time';
  }

  @override
  String syncValidUntilLabel(String time) {
    return '有効期限: $time';
  }

  @override
  String get doneAction => '完了';

  @override
  String get syncConflictsTitle => '同期の競合';

  @override
  String syncConflictsSubtitle(num count) {
    return '$count 件の暗号化レコードの確認が必要です。';
  }

  @override
  String get syncReviewAction => '確認';

  @override
  String get syncUseRemoteAction => 'リモートを使用';

  @override
  String get syncKeepLocalAction => 'ローカルを保持';

  @override
  String get syncUseRemoteTitle => 'リモートの記録を使用しますか？';

  @override
  String get syncKeepLocalTitle => 'ローカルの記録を保持しますか？';

  @override
  String get syncUseRemoteBody => '同期前に、リモートの暗号化レコードが競合しているローカルレコードを置き換えます。';

  @override
  String get syncKeepLocalBody => 'ローカルの暗号化レコードが競合しているリモートレコードを上書きします。';

  @override
  String get syncPausedICloudSubtitle =>
      '一時停止中です。暗号化レコードはプライベート iCloud データベースで同期されます。';

  @override
  String get syncEnabledStatus => '有効';

  @override
  String get syncPausedStatus => '一時停止中';

  @override
  String get syncWebDavNotConfiguredSubtitle =>
      '未構成です。暗号化されたマニフェストとレコードのみを扱います。';

  @override
  String get syncHttpAllowedStatus => 'HTTP 許可';

  @override
  String get syncHttpsStatus => 'HTTPS';

  @override
  String get syncAutoSyncWaiting => '自動同期待機中';

  @override
  String get syncAutoSyncNeedsVault => '同期を開始するにはボールトを作成してください';

  @override
  String get syncAutoSyncNeedsUnlock => '同期を続けるにはボールトを解除してください';

  @override
  String get syncAutoSyncReady => '自動同期準備完了';

  @override
  String syncLastSynced(String time) {
    return '前回の同期 $time';
  }

  @override
  String syncLastFailed(String time) {
    return '$time に同期失敗';
  }

  @override
  String get syncAutoSyncQueued => '自動同期はキューにあります';

  @override
  String get syncSyncingAutomatically => '自動同期中';

  @override
  String syncConflictCount(num count) {
    return '$count 件の競合';
  }

  @override
  String get syncAutoSyncFailed => '自動同期に失敗しました';

  @override
  String get saveAction => '保存';

  @override
  String get savingAction => '保存中';

  @override
  String get closeAction => '閉じる';

  @override
  String get removeAction => '削除';

  @override
  String get importAction => 'インポート';

  @override
  String get deleteAction => '削除';

  @override
  String get renameAction => '名前を変更';

  @override
  String get skipAction => 'スキップ';

  @override
  String get pasteAction => 'ペースト';

  @override
  String get confirmAction => '確認';

  @override
  String get denyAction => '拒否';

  @override
  String get allowAction => '許可';

  @override
  String get applyAction => '適用';

  @override
  String get createAction => '作成';

  @override
  String get runAction => '実行';

  @override
  String get pauseAction => '一時停止';

  @override
  String get resumeAction => '再開';

  @override
  String get retryAction => '再試行';

  @override
  String get connectAction => '接続';

  @override
  String get chooseFolderAction => 'フォルダを選択';

  @override
  String get loadingSemantics => '読み込み中';

  @override
  String get securityWebDavCertificateChangedTitle => 'WebDAV 証明書が変更されました';

  @override
  String get securityTrustWebDavCertificateTitle => 'WebDAV 証明書を信頼しますか？';

  @override
  String get securityHostKeyChangedTitle => 'ホストキーが変更されました';

  @override
  String get securityConfirmFingerprintTitle => '指紋を確認';

  @override
  String securityAlgorithmLabel(String value) {
    return 'アルゴリズム: $value';
  }

  @override
  String securityPreviousLabel(String value) {
    return '以前: $value';
  }

  @override
  String securitySubjectLabel(String value) {
    return 'サブジェクト: $value';
  }

  @override
  String securityIssuerLabel(String value) {
    return '発行者: $value';
  }

  @override
  String securityValidRangeLabel(String from, String to) {
    return '有効期間: $from から $to';
  }

  @override
  String get securityCertificateClockWarning =>
      'この証明書はまだ有効ではありません。信頼する前にこのデバイスの時刻を確認してください。';

  @override
  String get securityTrustOnceAction => '今回のみ信頼';

  @override
  String get securityTrustAndSaveAction => '信頼して保存';

  @override
  String get securityEncryptedExport => '暗号化エクスポート';

  @override
  String get securityUnencryptedExport => '未暗号化エクスポート';

  @override
  String securitySensitiveFields(String fields) {
    return '機密フィールド: $fields';
  }

  @override
  String get securityCannotBeUndone => 'この操作は元に戻せません。';

  @override
  String get securityPasteMultipleLinesTitle => '複数行をペーストしますか？';

  @override
  String securityPasteMultipleLinesBody(num count) {
    return '$count 行がアクティブな端末に送信されます。';
  }

  @override
  String get securityAgentAccessTitle => 'エージェントのアクセス要求';

  @override
  String securityAgentAccessBody(String client, String host) {
    return '$client が $host でセッションを開こうとしています。';
  }

  @override
  String securityAgentAccessHostIdLabel(String id) {
    return 'ホスト ID: $id';
  }

  @override
  String get securityAgentAccessWarning =>
      'アプリを終了するかアクセスを取り消すまで、エージェントはこのホストでコマンドを実行できます。';

  @override
  String get securityAgentCommandTitle => 'エージェントのコマンド確認';

  @override
  String securityAgentCommandBody(String client, String host) {
    return '$client が $host でコマンドを実行しようとしています。';
  }

  @override
  String securityAgentCommandRuleLabel(String rule) {
    return 'フラグ: $rule';
  }

  @override
  String get securityAgentAllowOnceAction => '今回のみ許可';

  @override
  String get securityAgentAllowSessionAction => 'セッション中許可';

  @override
  String get hostEditTitle => 'ホストを編集';

  @override
  String get hostAddTitle => 'ホストを追加';

  @override
  String get hostSectionConnection => '接続';

  @override
  String get hostSectionAuthentication => '認証';

  @override
  String get hostSectionStartup => '起動';

  @override
  String get hostRemoteSessionTitle => 'リモートセッション';

  @override
  String get hostSectionRouting => 'ルーティング';

  @override
  String get hostSectionPortForwarding => 'ポート転送';

  @override
  String get hostDisplayNameLabel => '表示名';

  @override
  String get hostDisplayNameOptionalLabel => '表示名（任意）';

  @override
  String get hostDisplayNameHostnameHint => 'ホスト名と同じ';

  @override
  String get hostDisplayNameHostnameHelper => '空のままにするとホスト名が使われます。';

  @override
  String get hostHostnameLabel => 'ホスト名';

  @override
  String get hostPortLabel => 'ポート';

  @override
  String get hostUsernameLabel => 'ユーザー名';

  @override
  String get hostWriteBackToSshConfigTitle => 'SSH config に書き込む';

  @override
  String get hostWriteBackToSshConfigNoPermissionTooltip =>
      '~/.ssh に書き込めません。フォルダーの権限を確認してください';

  @override
  String get hostStartupCommandsLabel => '起動コマンド';

  @override
  String get hostRemoteSessionEnableTitle => 'tmux/screen に接続';

  @override
  String get hostRemoteSessionManagerAuto => '自動';

  @override
  String get hostRemoteSessionManagerTmux => 'tmux';

  @override
  String get hostRemoteSessionManagerScreen => 'screen';

  @override
  String get hostRemoteSessionNameLabel => 'セッション名';

  @override
  String get hostRemoteSessionCreateIfMissing => '未作成なら作成';

  @override
  String get hostRemoteSessionFallbackToShell => '利用不可なら shell';

  @override
  String get hostTagsLabel => 'タグ';

  @override
  String get hostGroupLabel => 'グループ';

  @override
  String get hostGroupNone => 'グループなし';

  @override
  String get hostGroupNew => '新しいグループ…';

  @override
  String get hostGroupNewHint => 'グループ名';

  @override
  String get hostGroupCreateTitle => '新しいグループ';

  @override
  String get hostGroupNameRequired => '有効なグループ名を入力してください。';

  @override
  String get hostGroupNameExists => '同じ名前のグループが既に存在します。';

  @override
  String get hostGroupSaveFailed => 'グループを作成できませんでした。';

  @override
  String get hostGroupLoadFailed => 'グループを読み込めませんでした。';

  @override
  String get hostGroupMoveFailed => 'ホストをグループに移動できませんでした。';

  @override
  String get hostsUngroupedGroup => '未分類';

  @override
  String get hostStartFolderLabel => '開始フォルダ';

  @override
  String get hostPrivateKeyLabel => '秘密鍵';

  @override
  String get hostImportPrivateKeyTooltip => '秘密鍵をインポート';

  @override
  String get hostKeyPassphraseLabel => '鍵のパスフレーズ';

  @override
  String get hostAdvancedConnectionTitle => '接続オプション';

  @override
  String get hostPortForwardingLocalHint => 'SSH セッションの開始時にこれらのローカル転送を開始します。';

  @override
  String get hostPortForwardingRemoteHint => 'SSH セッションの開始時にこれらのリモート転送を開始します。';

  @override
  String get hostPortForwardingDynamicHint =>
      'SSH セッションの開始時にこれらの SOCKS プロキシを開始します。';

  @override
  String get hostTimeoutLabel => 'タイムアウト（秒）';

  @override
  String get hostKeepaliveLabel => 'キープアライブ（秒）';

  @override
  String get hostAutoReconnectLabel => '自動再接続';

  @override
  String get hostBackoffLabel => 'バックオフ（秒）';

  @override
  String get hostAuthPasswordSegment => 'パスワード';

  @override
  String get hostAuthKeySegment => '鍵';

  @override
  String get hostAuthAgentSegment => 'エージェント';

  @override
  String get hostAuthSavedSegment => '保存済み';

  @override
  String get hostPasswordLabel => 'パスワード';

  @override
  String get hostShowPasswordTooltip => 'パスワードを表示';

  @override
  String get hostHidePasswordTooltip => 'パスワードを非表示';

  @override
  String get hostSshAgentNote =>
      'ローカル SSH agent の ID を使用します。macOS では、ssh-agent に読み込まれた鍵をキーチェーンで保護できます。';

  @override
  String get hostNoSavedCredentials => '保存済みの認証情報はまだありません。';

  @override
  String get hostCredentialsHeading => '認証情報';

  @override
  String get hostEditCredentialTooltip => '認証情報を編集';

  @override
  String get hostCredentialOptionalNote => '認証情報なしでホストを保存し、後で追加できます。';

  @override
  String get hostJumpHostsHeading => '踏み台ホスト';

  @override
  String get hostPortNumberError => 'ポートは数字で入力してください。';

  @override
  String get hostSaveFailed => 'ホストを保存できませんでした。';

  @override
  String get hostConfigurationLoadFailed => 'ホスト設定を読み込めませんでした。';

  @override
  String get hostConnectionSettingsWholeNumbers => '接続設定は整数で入力してください。';

  @override
  String get identityKindPassword => 'パスワード';

  @override
  String get identityKindPrivateKey => '秘密鍵';

  @override
  String get identityKindKeyboard => 'キーボード';

  @override
  String get identityKindCertificate => '証明書';

  @override
  String get identityKindSshAgent => 'SSH Agent';

  @override
  String get identityKindHardwareKey => 'ハードウェアキー';

  @override
  String identityUserLabel(String username) {
    return 'ユーザー $username';
  }

  @override
  String identityPrincipalLabel(String principal) {
    return 'プリンシパル $principal';
  }

  @override
  String get snippetInsertTooltip => 'アクティブな端末に挿入';

  @override
  String get snippetRunTooltip => 'アクティブな端末で実行';

  @override
  String get snippetEditTooltip => 'スニペットを編集';

  @override
  String get snippetDeleteTooltip => 'スニペットを削除';

  @override
  String get snippetDialogEditTitle => 'スニペットを編集';

  @override
  String get snippetDialogAddTitle => 'スニペットを追加';

  @override
  String get snippetNameLabel => '名前';

  @override
  String get snippetNamePlaceholder => '例：nginx の再起動';

  @override
  String get snippetCommandLabel => 'コマンド';

  @override
  String get snippetCommandPlaceholder => '例：sudo systemctl restart nginx';

  @override
  String get snippetTagsLabel => 'タグ';

  @override
  String get snippetConfirmBeforeRun => '実行前に確認';

  @override
  String get snippetCollapseEditorTooltip => 'スニペット情報を表示';

  @override
  String get snippetEditorKeysHint => 'Tab / Shift+Tab インデント · Esc 次の項目';

  @override
  String snippetCursorPosition(int line, int column) {
    return '$line 行、$column 列';
  }

  @override
  String get snippetDiscardTitle => '変更を破棄しますか？';

  @override
  String get snippetDiscardBody => 'このスニペットの変更は保存されていません。';

  @override
  String get snippetDiscardAction => '変更を破棄';

  @override
  String get snippetExpandEditorTooltip => 'エディターを拡大';

  @override
  String get snippetAddTagsHint => 'タグを追加';

  @override
  String get snippetAddTagHint => 'タグを追加';

  @override
  String get snippetRemoveTagTooltip => 'タグを削除';

  @override
  String get snippetRunTitle => 'スニペットを実行しますか？';

  @override
  String get snippetDeleteTitle => 'スニペットを削除しますか？';

  @override
  String get snippetSaveFailed => 'スニペットを保存できませんでした。';

  @override
  String get snippetErrorNameRequired => 'スニペット名を入力してください。';

  @override
  String get snippetErrorCommandRequired => '保存するコマンドを入力してください。';

  @override
  String get snippetErrorNotFound => 'このスニペットはもう存在しません。';

  @override
  String get snippetSentSnack => 'スニペットを端末に送信しました。';

  @override
  String get snippetInsertedSnack => 'スニペットを端末に挿入しました。';

  @override
  String get snippetNoTerminalSnack => '接続済みの端末タブを先に開いてください。';

  @override
  String get snippetDeletedSnack => 'スニペットを削除しました。';

  @override
  String get snippetDeleteFailedSnack => 'スニペットを削除できませんでした。';

  @override
  String get syncDevicesDialogTitle => '同期デバイス';

  @override
  String syncDeviceRemoveTitle(String name) {
    return '$name を削除しますか？';
  }

  @override
  String get syncDeviceRemoveBody => 'このボールトから暗号化同期デバイス記録を削除します。';

  @override
  String get syncDeviceRemovedSnack => '同期デバイスを削除しました。';

  @override
  String get syncDeviceRemoveFailedSnack => '同期デバイスを削除できませんでした。';

  @override
  String get syncDeviceResetTitle => '同期デバイスをリセットしますか？';

  @override
  String get syncDeviceResetBody =>
      '現在のデバイス登録を暗号化同期から削除し、新しいローカルデバイス ID を作成します。他のデバイスには古いデバイスが削除済みとして表示されます。';

  @override
  String get syncDeviceResetSnack => '同期デバイスをリセットしました。次回の同期で新しい登録が作成されます。';

  @override
  String get syncDeviceResetFailedSnack => '同期デバイスをリセットできませんでした。';

  @override
  String get syncDevicesEmptyTitle => '同期デバイスはまだありません';

  @override
  String get syncDevicesEmptyBody => '最初の暗号化同期が成功すると、このデバイスがここに登録されます。';

  @override
  String get syncDeviceRemoveTooltip => 'デバイスを削除';

  @override
  String get syncDevicesWillRegister => 'このデバイスは最初の同期時に登録されます。';

  @override
  String syncDeviceSingleSubtitle(String name) {
    return '$name は暗号化同期用に登録されています。';
  }

  @override
  String syncDevicesRegisteredSubtitle(num count) {
    return '$count 台のデバイスが登録済みです。';
  }

  @override
  String syncDevicesMultipleSubtitle(num count, String name) {
    return '$count 台のデバイスが登録済みです。最後の書き込み: $name。';
  }

  @override
  String syncDeviceThisDevice(String name) {
    return '$name（このデバイス）';
  }

  @override
  String syncDeviceSubtitle(String platform, String time) {
    return '$platform / 最終確認 $time';
  }

  @override
  String get webDavSyncTitle => 'WebDAV 同期';

  @override
  String get webDavEndpointLabel => 'エンドポイント';

  @override
  String get webDavEndpointHint => 'https://example.com/webdav';

  @override
  String get webDavUsernameLabel => 'ユーザー名';

  @override
  String get webDavPasswordLabel => 'パスワード';

  @override
  String get webDavPasswordKeepLabel => 'パスワード（空欄なら保持）';

  @override
  String get webDavBasePathLabel => 'ベースパス';

  @override
  String get webDavEnableTitle => 'WebDAV 同期を有効にする';

  @override
  String get webDavAllowHttpTitle => 'HTTP エンドポイントを許可';

  @override
  String get webDavEnableMobileLabel => '同期を有効化';

  @override
  String get webDavAllowHttpMobileLabel => 'HTTP を許可';

  @override
  String get webDavUseHttpTitle => 'HTTP WebDAV を使用しますか？';

  @override
  String get webDavUseHttpBody =>
      'HTTP 同期では転送中にメタデータと認証情報が露出する可能性があります。信頼できるローカルテストサーバーでのみ使用してください。';

  @override
  String get webDavAllowHttpAction => 'HTTP を許可';

  @override
  String get webDavSavedSnack => 'WebDAV 同期設定を保存しました。';

  @override
  String get webDavRemoveTitle => 'WebDAV 同期を削除しますか？';

  @override
  String get webDavRemoveBody => 'ローカルの WebDAV 設定と保存済みパスワードを削除します。';

  @override
  String get webDavRemovedSnack => 'WebDAV 同期設定を削除しました。';

  @override
  String get webDavRemoteVaultMismatchTitle => 'リモートに別の Serlink ボールトがあります';

  @override
  String get webDavRemoteVaultMismatchBody =>
      'この WebDAV には別の Serlink ボールトの同期データが保存されています。このデバイスのボールトでリモートデータを置き換えるか、リモートのボールトでこのデバイスを復元できます。';

  @override
  String get webDavReplaceRemoteAction => 'ローカルを保持してリモートを置換';

  @override
  String get webDavRestoreFromRemoteAction => 'リモートのボールトでこのデバイスを復元';

  @override
  String get webDavReplaceRemoteConfirmTitle => 'リモートのボールトを置き換えますか？';

  @override
  String get webDavReplaceRemoteConfirmBody =>
      'リモートの Serlink 同期データがこのデバイスのボールトで上書きされます。この操作は取り消せません。';

  @override
  String get webDavRestoreFromRemoteConfirmTitle => 'リモートのボールトでこのデバイスを復元しますか？';

  @override
  String get webDavRestoreFromRemoteConfirmBody =>
      'このデバイスの現在のボールトデータはリモートのボールトに置き換えられ、デバイスはロックされます。リモートボールトのパスフレーズで解除してください。先にローカルバックアップを作成します。';

  @override
  String get credentialsDialogTitle => '認証情報';

  @override
  String get credentialsEmptyTitle => '保存済み認証情報はありません';

  @override
  String get credentialsEmptyBody => 'インポートしたパスワード、秘密鍵、証明書、ID メタデータがここに表示されます。';

  @override
  String get credentialsEditTooltip => '認証情報を編集';

  @override
  String get credentialsDeleteTooltip => '認証情報を削除';

  @override
  String get credentialUpdatedSnack => '認証情報を更新しました。';

  @override
  String get credentialDeleteTitle => '認証情報を削除しますか？';

  @override
  String get credentialDeleteBody => '認証情報と暗号化された秘密データを削除します。';

  @override
  String credentialDeleteLinkedBody(String hosts) {
    return 'この認証情報はまだ $hosts に関連付けられています。これらのホストの関連付けを削除してから削除してください。';
  }

  @override
  String get credentialDeletedSnack => '認証情報を削除しました。';

  @override
  String get credentialDeleteFailedSnack => '認証情報を削除できませんでした。';

  @override
  String get credentialAddedSnack => '認証情報を追加しました。';

  @override
  String get credentialGenerateKeyAction => '鍵ペアを生成';

  @override
  String get credentialGeneratedPublicKeyLabel => '公開鍵';

  @override
  String get credentialGeneratedPublicKeyNote =>
      'この公開鍵をサーバーの authorized_keys に追加してください。秘密鍵はボールトに暗号化して保存されます。';

  @override
  String get credentialCopyPublicKeyTooltip => '公開鍵をコピー';

  @override
  String get credentialPublicKeyCopiedSnack => '公開鍵をコピーしました。';

  @override
  String get credentialKeyGenerationFailed => '鍵の生成に失敗しました。';

  @override
  String get knownHostsDialogTitle => '既知のホスト';

  @override
  String get knownHostsEmptyTitle => '信頼済み指紋はありません';

  @override
  String get knownHostsEmptyBody => '接続確認で承認したホスト指紋がここに表示されます。';

  @override
  String get knownHostDeleteTooltip => '既知のホストを削除';

  @override
  String get knownHostDeleteTitle => '既知のホストを削除しますか？';

  @override
  String knownHostDeleteBody(String host) {
    return '$host に保存された指紋を削除します。次回接続時に再度確認が必要になります。';
  }

  @override
  String get knownHostDeletedSnack => '既知のホストを削除しました。';

  @override
  String get knownHostDeleteFailedSnack => '既知のホストを削除できませんでした。';

  @override
  String get startAction => '開始';

  @override
  String get stopAction => '停止';

  @override
  String get uploadAction => 'アップロード';

  @override
  String get downloadAction => 'ダウンロード';

  @override
  String get moveAction => '移動';

  @override
  String get replaceAction => '置換';

  @override
  String get mergeAction => 'マージ';

  @override
  String get copiedAction => 'コピー済み';

  @override
  String get clearAllAction => 'すべて解除';

  @override
  String get selectAllAction => 'すべて選択';

  @override
  String get restartAction => '再起動';

  @override
  String get reconnectAction => '再接続';

  @override
  String get windowCloseActiveTerminalsTitle => 'アクティブな端末を閉じますか？';

  @override
  String windowCloseActiveTerminalsBody(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 個の端末ペインがまだ実行中です。このウィンドウを閉じると切断されます。',
      one: '1 つの端末ペインがまだ実行中です。このウィンドウを閉じると切断されます。',
    );
    return '$_temp0';
  }

  @override
  String get windowCloseWindowAction => 'ウィンドウを閉じる';

  @override
  String get windowCloseLabel => 'ウィンドウを閉じる';

  @override
  String get windowMinimizeLabel => 'ウィンドウを最小化';

  @override
  String get windowZoomLabel => 'ウィンドウを拡大縮小';

  @override
  String get hostEditMenu => 'ホストを編集';

  @override
  String get hostDuplicateMenu => 'セッションを複製';

  @override
  String get hostDuplicateTitle => 'セッションを複製';

  @override
  String get hostDeleteMenu => 'ホストを削除';

  @override
  String get hostTerminalAction => '端末';

  @override
  String get hostSftpAction => 'SFTP';

  @override
  String get hostTrustTrusted => '信頼済み';

  @override
  String get hostTrustVerify => '確認';

  @override
  String get hostTrustChanged => '変更あり';

  @override
  String get tabsCloseTooltip => 'タブを閉じる';

  @override
  String get tabsNewConnectionTooltip => '新しい接続';

  @override
  String get terminalToolbarMoreActionsTooltip => 'その他の端末操作';

  @override
  String get localShellInactive => 'ローカルシェルは実行されていません。';

  @override
  String get connectionInactive => '接続はアクティブではありません。';

  @override
  String get sessionDisconnectedMessage => '接続が中断されました。再接続すると新しいセッションが開始されます。';

  @override
  String get connectionFailedMessage => '接続に失敗しました。';

  @override
  String get connectionProfileVaultLockedMessage =>
      '新しい接続を開始する前にボールトを解除してください。';

  @override
  String get connectionProfileNotFoundMessage => '接続プロファイルが見つかりません。';

  @override
  String get connectionProfileHostNotFoundMessage => 'ホストが見つかりません。';

  @override
  String get connectionProfileIdentityNotFoundMessage => '認証情報が見つかりません。';

  @override
  String get connectionProfileNoAuthMethodsMessage => 'このホストには認証情報が設定されていません。';

  @override
  String get connectionProfileJumpChainTooDeepMessage => '踏み台ホストのチェーンが長すぎます。';

  @override
  String get connectionProfileJumpCycleMessage => '踏み台ホストのチェーンに循環があります。';

  @override
  String get connectionProfileSshAgentUnsupportedMessage =>
      'このプラットフォームでは SSH agent 認証を利用できません。';

  @override
  String get connectionProfileHardwareKeyUnsupportedMessage =>
      'このプラットフォームではハードウェアキー認証を利用できません。';

  @override
  String get connectionProfileIdentitySecretMissingMessage =>
      '認証情報がシークレット記録を参照していません。';

  @override
  String get connectionProfileSecretNotFoundMessage => 'シークレット記録が見つかりません。';

  @override
  String get connectionProfilePasswordMissingMessage => '認証情報にパスワードが含まれていません。';

  @override
  String get connectionProfilePrivateKeyMissingMessage => '認証情報に秘密鍵が含まれていません。';

  @override
  String get connectionProfileCertificateMissingMessage =>
      '認証情報に OpenSSH 証明書が含まれていません。';

  @override
  String get sshAuthAgentUnavailableMessage => 'SSH agent を利用できません。';

  @override
  String get sshAuthHardwareKeyUnsupportedMessage =>
      'ハードウェアセキュリティキー認証にはプラットフォームの対応が必要です。';

  @override
  String get sshAuthAgentEmptyMessage => 'SSH agent に読み込まれた認証情報がありません。';

  @override
  String get sshAuthEmptyMessage => '接続プロファイルに対応している認証方式がありません。';

  @override
  String get sshAuthCertificateInvalidMessage => 'OpenSSH 証明書の内容が無効です。';

  @override
  String get localTerminalExitedMessage => 'ローカルシェルが終了しました。再起動すると新しいシェルを開きます。';

  @override
  String get localTerminalFailedMessage => 'ローカル端末に失敗しました。';

  @override
  String get localTerminalShellMissingMessage => 'ローカルシェル実行ファイルが見つかりません。';

  @override
  String get localTerminalStartFailedMessage => 'ローカル端末を開始できませんでした。';

  @override
  String get localShellTitle => 'ローカルシェル';

  @override
  String get terminalSearchTooltip => '端末を検索';

  @override
  String get terminalOpenSftpTooltip => 'SFTP タブを開く';

  @override
  String get terminalSplitRightTooltip => '右に分割';

  @override
  String get terminalSplitDownTooltip => '下に分割';

  @override
  String get terminalClosePaneTooltip => 'ペインを閉じる';

  @override
  String terminalPaneSessionLabel(int index) {
    return 'セッション $index';
  }

  @override
  String get terminalSettingsTitle => '端末設定';

  @override
  String get terminalForwardingUpdating => 'ポート転送を更新中';

  @override
  String get terminalForwardingManage => 'ポート転送を管理';

  @override
  String terminalForwardingManageActive(num count) {
    return 'ポート転送を管理（$count 件アクティブ）';
  }

  @override
  String get terminalNoSearchResults => '結果なし';

  @override
  String get terminalPreviousMatchTooltip => '前の一致';

  @override
  String get terminalNextMatchTooltip => '次の一致';

  @override
  String get terminalCloseSearchTooltip => '検索を閉じる';

  @override
  String get terminalAppearanceSection => '外観';

  @override
  String get terminalDarkThemeLabel => 'ダークモードのテーマ';

  @override
  String get terminalLightThemeLabel => 'ライトモードのテーマ';

  @override
  String get terminalLayoutSection => 'レイアウト';

  @override
  String get terminalFontSizeLabel => 'フォントサイズ';

  @override
  String get terminalLineHeightLabel => '行の高さ';

  @override
  String get terminalScrollbackLabel => 'スクロールバック';

  @override
  String get terminalSaveForHostAction => 'ホスト用に保存';

  @override
  String get terminalUseGlobalAction => 'グローバルを使用';

  @override
  String get terminalFontLabel => 'フォント';

  @override
  String get terminalSearchFontsHint => 'フォントを検索';

  @override
  String get terminalSelectFontHint => 'フォントを選択';

  @override
  String get terminalCustomFamilyLabel => 'カスタムファミリー';

  @override
  String get terminalCustomFamilyHelper => 'インストール済みフォントファミリーを入力して適用します。';

  @override
  String get terminalCustomFamilyHint => '例: JetBrains Mono';

  @override
  String get terminalApplyCustomFontTooltip => 'カスタムフォントを適用';

  @override
  String get terminalScanningFonts => 'フォントをスキャン中';

  @override
  String get terminalNerdFontReady => 'Nerd Font 利用可';

  @override
  String get terminalNoNerdFont => 'Nerd Font なし';

  @override
  String get terminalLifecycleRunning => '実行中';

  @override
  String get terminalLifecycleStarting => '起動中';

  @override
  String get terminalLifecycleExited => '終了';

  @override
  String get terminalLifecycleFailed => '失敗';

  @override
  String get terminalLifecycleStopping => '停止中';

  @override
  String get terminalLifecycleConnected => '接続済み';

  @override
  String get terminalLifecycleConnecting => '接続中';

  @override
  String get terminalLifecycleReconnecting => '再接続中';

  @override
  String get terminalLifecycleDisconnected => '切断済み';

  @override
  String get terminalLifecyclePreparing => '準備中';

  @override
  String get terminalLifecycleVerifying => '確認中';

  @override
  String get terminalLifecycleAuthenticating => '認証中';

  @override
  String get terminalLifecycleDisconnecting => '切断中';

  @override
  String get terminalLifecycleIdle => '待機中';

  @override
  String get forwardingDialogTitle => 'ポート転送';

  @override
  String get forwardingLocalTitle => 'ローカル';

  @override
  String get forwardingLocalSubtitle => 'リモートサービスをこのデバイスに公開します。';

  @override
  String get forwardingRemoteTitle => 'リモート';

  @override
  String get forwardingRemoteSubtitle => 'ローカルサービスをリモートホストに公開します。';

  @override
  String get forwardingSocksTitle => 'SOCKS プロキシ';

  @override
  String get forwardingSocksSubtitle => 'この SSH セッション用のローカル動的プロキシを開始します。';

  @override
  String get forwardingLocalPortLabel => 'ローカルポート';

  @override
  String get forwardingRemoteHostLabel => 'リモートホスト';

  @override
  String get forwardingRemotePortLabel => 'リモートポート';

  @override
  String get forwardingBindHostLabel => 'バインドホスト';

  @override
  String get forwardingBindPortLabel => 'バインドポート';

  @override
  String get forwardingLocalHostLabel => 'ローカルホスト';

  @override
  String get forwardingLocalValidationError =>
      'ポートは 1-65535 の範囲で、リモートホストが必要です。';

  @override
  String get forwardingRemoteValidationError =>
      'バインドホスト、ローカルホスト、ポートを正しく入力してください。';

  @override
  String get forwardingDynamicValidationError => 'バインドホストとポートを正しく入力してください。';

  @override
  String get forwardingLocalStartedSnack => 'ローカルポート転送を開始しました。';

  @override
  String get forwardingLocalStartFailedSnack => 'ローカルポート転送を開始できませんでした。';

  @override
  String get forwardingLocalStoppedSnack => 'ローカルポート転送を停止しました。';

  @override
  String get forwardingLocalStopFailedSnack => 'ローカルポート転送を停止できませんでした。';

  @override
  String get forwardingRemoteStartedSnack => 'リモートポート転送を開始しました。';

  @override
  String get forwardingRemoteStartFailedSnack => 'リモートポート転送を開始できませんでした。';

  @override
  String get forwardingRemoteStoppedSnack => 'リモートポート転送を停止しました。';

  @override
  String get forwardingRemoteStopFailedSnack => 'リモートポート転送を停止できませんでした。';

  @override
  String get forwardingSocksStartedSnack => 'SOCKS プロキシを開始しました。';

  @override
  String get forwardingSocksStartFailedSnack => 'SOCKS プロキシを開始できませんでした。';

  @override
  String get forwardingSocksStoppedSnack => 'SOCKS プロキシを停止しました。';

  @override
  String get forwardingSocksStopFailedSnack => 'SOCKS プロキシを停止できませんでした。';

  @override
  String get vaultCreateTitle => 'ボールトを作成';

  @override
  String get vaultUnlockTitle => 'ボールトを解除';

  @override
  String get vaultCreateSubtitle => '強力なパスフレーズでホストと鍵を保護します。';

  @override
  String get vaultUnlockSubtitle => 'ワークスペースを復号するにはパスフレーズを入力してください。';

  @override
  String get vaultNewPassphraseLabel => '新しいパスフレーズ';

  @override
  String get vaultPassphraseLabel => 'パスフレーズ';

  @override
  String get vaultCreateAction => 'ボールトを作成';

  @override
  String get vaultCreateICloudVaultExistsTitle => 'iCloud に既存のボールトがあります';

  @override
  String get vaultCreateICloudVaultExistsBody =>
      '既存のボールトをそのパスフレーズで解除して復元するか、新しいボールトを作成できます。新しく作成すると iCloud に保存されている同期データが置き換えられます。';

  @override
  String get vaultCreateRestoreICloudVaultAction => 'iCloud ボールトを復元';

  @override
  String get vaultCreateNewAnywayAction => 'それでも新しいボールトを作成';

  @override
  String get vaultCreateReplaceICloudConfirmTitle => 'iCloud の同期データを置き換えますか？';

  @override
  String get vaultCreateReplaceICloudConfirmBody =>
      '新しいボールトは iCloud に保存されている既存の Serlink 同期データを置き換えます。この操作は取り消せません。';

  @override
  String get vaultUnlockAction => '解除';

  @override
  String get vaultUnlockWithDeviceAction => 'Face ID を使用';

  @override
  String get vaultUseRecoveryCodeAction => '復旧コードを使用';

  @override
  String get vaultPassphraseRequired => '続行するにはボールトのパスフレーズを入力してください。';

  @override
  String get vaultInvalidPassphraseError => 'パスフレーズではボールトを解除できませんでした。';

  @override
  String get vaultBackupMissingVaultError =>
      'バックアップをエクスポートする前にボールトを作成または解除してください。';

  @override
  String vaultOperationFailedError(String detail) {
    return 'ボールト操作に失敗しました: $detail';
  }

  @override
  String vaultRecoveryFailedError(String detail) {
    return 'ボールトの復旧に失敗しました: $detail';
  }

  @override
  String get vaultDatabaseUnreadableError =>
      'ローカルの Serlink データベースを読み取れないか、復元できません。';

  @override
  String get appProfileLockedError => 'この Serlink プロファイルは別のウィンドウで開かれています。';

  @override
  String get vaultInvalidRecoveryKeyError => '復旧キーではボールトを解除できませんでした。';

  @override
  String get vaultInvalidRecoveryKeyFormatError => 'この復旧キー形式はサポートされていません。';

  @override
  String get vaultLocalUnlockNotEnabledError =>
      'このデバイスでは Face ID 解除が有効ではありません。';

  @override
  String get vaultLocalUnlockFailedError =>
      'Face ID 解除に失敗しました。ボールトのパスフレーズを使用してください。';

  @override
  String get vaultLocalUnlockUnavailableError => 'このデバイスでは Face ID を利用できません。';

  @override
  String get vaultEmptyPassphraseError => 'ボールトのパスフレーズは空にできません。';

  @override
  String get vaultRecoveryKeyTitle => '復旧キー';

  @override
  String get vaultRecoveryKeySaveInstruction => '続行する前にこのキーを保存してください。';

  @override
  String get vaultRecoveryKeyWarningTitle => '今すぐこのキーを保存してください';

  @override
  String get vaultRecoveryKeyWarningBody =>
      'このキーは一度だけ表示されます。失うと Serlink では復元できません。';

  @override
  String get vaultCopyRecoveryKeyAction => '復旧キーをコピー';

  @override
  String get vaultRecoveryKeySavedAction => '保存しました';

  @override
  String get vaultRecoveryTitle => 'ボールト復旧';

  @override
  String get vaultRecoveryBody => 'ボールト復旧ツールを使用できます。';

  @override
  String get vaultRecoveryLocalDataTitle => 'ローカルのボールトデータが破損しています';

  @override
  String get vaultRecoveryLocalDataBody =>
      'このデバイスに保存されたボールトデータを読み取れません。通常は自動バックアップまたはバックアップファイルから復旧できます。';

  @override
  String get vaultRecoveryCloudSyncTitle => 'クラウド同期データの修復が必要です';

  @override
  String get vaultRecoveryCloudSyncBody =>
      'このデバイスのボールトデータに影響はありません。「設定 → 同期」でクラウド同期データを修復してください。';

  @override
  String get vaultRecoveryRecordsDamagedTitle => '一部のボールトレコードが破損しています';

  @override
  String vaultRecoveryRecordsDamagedBody(num count) {
    return '$count 件の暗号化レコードを読み取れませんでした。隔離すると、ボールトの残りのデータを引き続き使用できます。';
  }

  @override
  String get vaultRecoveryImportBackupAction => 'バックアップファイルをインポート';

  @override
  String get vaultRecoveryViewDetailsAction => '詳細を表示';

  @override
  String get vaultRecoveryHideDetailsAction => '詳細を隠す';

  @override
  String get vaultRestoreLatestBackupAction => '自動バックアップから復元';

  @override
  String get vaultQuarantineRecordsAction => '破損レコードを隔離';

  @override
  String get vaultCorruptRecordsQuarantinedSnack => '破損レコードを隔離しました。';

  @override
  String get vaultResetTitle => 'ボールトをリセット';

  @override
  String get vaultRecoveryCodeTitle => '復旧コード';

  @override
  String get vaultResetSubtitle =>
      'パスフレーズまたは復旧コードでこのボールトを解除できない場合のみリセットしてください。';

  @override
  String get vaultRecoveryCodeSubtitle => 'このボールトを解除するには復旧コードを入力してください。';

  @override
  String get vaultRecoveryCodeLabel => '復旧コード';

  @override
  String get vaultRecoveryCodeHelper => '完全な復旧コードを貼り付けてください。';

  @override
  String get vaultResetVaultAction => 'ボールトをリセット';

  @override
  String get vaultResetPermanentlyAction => 'ボールトを完全にリセット';

  @override
  String get vaultRecoveryCodeRequired => '続行するには復旧コードを入力してください。';

  @override
  String vaultResetTypePhraseError(String phrase) {
    return 'リセットを確認するには $phrase と入力してください。';
  }

  @override
  String vaultResetTypePhraseLabel(String phrase) {
    return '$phrase と入力';
  }

  @override
  String get vaultResetPhraseHelper => 'このフレーズは大文字小文字を区別し、リセットに必要です。';

  @override
  String get vaultResetWarningTitle => 'このデバイスでは元に戻せません';

  @override
  String get vaultResetWarningRecords =>
      '暗号化されたホスト、ID、スニペット、転送履歴、同期設定、復旧データが削除されます。';

  @override
  String get vaultResetWarningSyncedDevices =>
      'このボールトが同期されている場合、同じ同期ボールトを使う他のデバイスもリセットされ、消去されます。';

  @override
  String get vaultResetWarningSecrets =>
      'リセットしてもパスフレーズは復元されず、既存のシークレットも表示されません。';

  @override
  String get vaultResetWarningBackup => '続行する前にバックアップまたは新しいボールトが必要です。';

  @override
  String get credentialEditTitle => '認証情報を編集';

  @override
  String get credentialAddTitle => '認証情報を追加';

  @override
  String get hostAddCredentialAction => '認証情報を追加';

  @override
  String get credentialLoadingSecretSemantics => '認証情報のシークレットを読み込み中';

  @override
  String get credentialNameLabel => '認証情報名';

  @override
  String get credentialUsernameHintLabel => 'ユーザー名ヒント';

  @override
  String get credentialPasswordLabel => 'パスワード';

  @override
  String get credentialKeyboardResponsesLabel => 'キーボード応答';

  @override
  String get credentialKeyboardResponsesHelper => '1 行に 1 つの応答を入力します。';

  @override
  String get credentialNoSecretMaterial => 'この認証情報には保存済みのシークレットデータがありません。';

  @override
  String get credentialSecretLoadFailed => '認証情報のシークレットを読み込めませんでした。';

  @override
  String get credentialSaveFailed => '認証情報を保存できませんでした。';

  @override
  String get credentialSshPrivateKeyTypeLabel => 'SSH 秘密鍵';

  @override
  String get credentialOpenSshCertificateTypeLabel => 'OpenSSH 証明書';

  @override
  String get credentialCertificateLabel => '証明書';

  @override
  String get credentialImportCertificateTooltip => '証明書をインポート';

  @override
  String get syncConflictReviewDialogTitle => '同期競合を確認';

  @override
  String get syncConflictApplying => '適用中';

  @override
  String get syncConflictApplyMergeAction => 'マージを適用';

  @override
  String get syncConflictLocalLabel => 'ローカル';

  @override
  String get syncConflictRemoteLabel => 'リモート';

  @override
  String get syncConflictUnsupportedBody =>
      'このレコードタイプは現在、レコード全体での解決が必要です。この競合には既存のローカルまたはリモート操作を使用してください。';

  @override
  String syncConflictFieldCount(num count) {
    return '$count 件のフィールドに差異があります';
  }

  @override
  String get sftpParentFolderTooltip => '親フォルダへ移動';

  @override
  String get sftpSearchPlaceholder => 'ファイルを検索';

  @override
  String get sftpHideHiddenFilesTooltip => '隠しファイルを非表示';

  @override
  String get sftpShowHiddenFilesTooltip => '隠しファイルを表示';

  @override
  String get sftpOpenTerminalTooltip => '端末タブを開く';

  @override
  String get sftpUploadFileAction => 'ファイルをアップロード';

  @override
  String get sftpUploadFolderAction => 'フォルダをアップロード';

  @override
  String get sftpNewFolderTooltip => '新しいフォルダ';

  @override
  String get sftpRefreshTooltip => '更新';

  @override
  String get sftpWaitingTitle => 'SFTP';

  @override
  String get sftpWaitingBody => 'SFTP 接続を待機しています。';

  @override
  String get sftpStartFolderTitle => 'SFTP 開始フォルダ';

  @override
  String sftpStartFolderBody(String path) {
    return 'Serlink は $path を一覧表示できませんでした。このアカウントでアクセスできるフォルダを選択してください。';
  }

  @override
  String get sftpErrorTitle => 'SFTP エラー';

  @override
  String get sftpEmptyFolderTitle => '空のフォルダ';

  @override
  String get sftpNoEntriesFilter => '現在のフィルタに一致する項目はありません。';

  @override
  String get sftpHiddenOnly => 'このリモートディレクトリには隠し項目のみがあります。';

  @override
  String get sftpNoVisible => 'このリモートディレクトリには表示可能な項目がありません。';

  @override
  String get sftpDirectoryLabel => 'フォルダ';

  @override
  String get sftpFileLabel => 'ファイル';

  @override
  String get sftpSymlinkLabel => 'シンボリックリンク';

  @override
  String get sftpUnknownLabel => '不明';

  @override
  String get sftpNewFolderTitle => '新しいフォルダ';

  @override
  String get sftpFolderNameLabel => 'フォルダ名';

  @override
  String get sftpFolderCreatedSnack => 'フォルダを作成しました。';

  @override
  String get sftpSelectedFileNoPathSnack => '選択したファイルにローカルパスがありません。';

  @override
  String get sftpUploadQueuedSnack => 'アップロードをキューに追加しました。';

  @override
  String get sftpFolderUploadQueuedSnack => 'フォルダアップロードをキューに追加しました。';

  @override
  String get sftpFolderDownloadQueuedSnack => 'フォルダダウンロードをキューに追加しました。';

  @override
  String get sftpDownloadQueuedSnack => 'ダウンロードをキューに追加しました。';

  @override
  String get sftpMergeRemoteFolderTitle => 'リモートフォルダをマージしますか？';

  @override
  String get sftpReplaceRemoteFileTitle => 'リモートファイルを置換しますか？';

  @override
  String sftpRemoteExistsOverwriteBody(String path) {
    return '$path はサーバー上にすでに存在します。一致するファイルは上書きされる可能性があります。';
  }

  @override
  String sftpRemoteExistsBody(String path) {
    return '$path はサーバー上にすでに存在します。';
  }

  @override
  String get sftpMergeLocalFolderTitle => 'ローカルフォルダをマージしますか？';

  @override
  String get sftpReplaceLocalFileTitle => 'ローカルファイルを置換しますか？';

  @override
  String sftpLocalExistsOverwriteBody(String path) {
    return '$path はこのデバイス上にすでに存在します。一致するファイルは上書きされる可能性があります。';
  }

  @override
  String sftpLocalExistsBody(String path) {
    return '$path はこのデバイス上にすでに存在します。';
  }

  @override
  String get sftpNewNameLabel => '新しい名前';

  @override
  String get sftpTargetPathLabel => '移動先パス';

  @override
  String get sftpTargetExistsSnack => '移動先パスはすでに存在します。';

  @override
  String get sftpEntryRenamedSnack => '項目名を変更しました。';

  @override
  String get sftpEntryMovedSnack => '項目を移動しました。';

  @override
  String get sftpChangePermissionsTitle => '権限を変更';

  @override
  String get sftpOctalPermissionsLabel => '権限（8 進数または記号）';

  @override
  String get sftpPermissionsOctalError =>
      '権限は 0644 のような 8 進数、または rw-r--r-- のような記号形式で入力してください。';

  @override
  String get sftpPermissionsUpdatedSnack => '権限を更新しました。';

  @override
  String sftpDeleteEntryTitle(String name) {
    return '$name を削除しますか？';
  }

  @override
  String get sftpDeleteDirectoryBody => 'リモートディレクトリとその内容を削除します。';

  @override
  String get sftpDeleteFileBody => 'リモートファイルを削除します。';

  @override
  String get sftpEntryDeletedSnack => '項目を削除しました。';

  @override
  String get sftpFileSavedSnack => 'ファイルを保存しました。';

  @override
  String remoteFilePreviewLimited(String bytes) {
    return 'プレビューは $bytes までです。';
  }

  @override
  String get sftpDefaultDirectoryDialogTitle => 'SFTP 開始フォルダを選択';

  @override
  String sftpDefaultDirectoryFailedMessage(String path, String reason) {
    return '$path を一覧表示できませんでした。$reason';
  }

  @override
  String get sftpStartFolderLabel => '開始フォルダ';

  @override
  String get sftpStartFolderHint => '/home/user';

  @override
  String get sftpAbsolutePathError => '絶対リモートパスを入力してください。';

  @override
  String get transferDeleteMenu => '転送を削除';

  @override
  String transferEtaLeft(String time) {
    return '残り $time';
  }

  @override
  String get transferClearTitle => '転送を消去しますか？';

  @override
  String transferClearBody(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '履歴から $count 件の転送記録を削除します。',
      one: '履歴から 1 件の転送記録を削除します。',
    );
    return '$_temp0';
  }

  @override
  String transferClearActiveBody(num count, num activeCount) {
    return '履歴から $count 件の転送記録を削除し、$activeCount 件のアクティブな転送をキャンセルします。';
  }

  @override
  String get transferClearedSnack => '転送を消去しました。';

  @override
  String get transferRemoveLocalFailedSnack =>
      '転送は削除しましたが、ローカルファイルは削除できませんでした。';

  @override
  String get transferAndLocalDeletedSnack => '転送とローカルファイルを削除しました。';

  @override
  String get transferDeletedSnack => '転送を削除しました。';

  @override
  String get transferCompletedMissingSnack => '完了した項目はローカルで利用できなくなっています。';

  @override
  String get transferOpenFailedSnack => '完了した項目を開けませんでした。';

  @override
  String get transferDeleteTitle => '転送を削除しますか？';

  @override
  String transferDeleteLocalBody(String kind, String path) {
    return 'ローカルの $kind が $path にまだ存在します。転送のみを削除しますか、それともローカルの $kind も削除しますか？';
  }

  @override
  String get transferRemoveOnlyAction => '転送のみ削除';

  @override
  String transferDeleteLocalTooAction(String kind) {
    return '$kind も削除';
  }

  @override
  String transferMachineFrom(String name) {
    return '$name から';
  }

  @override
  String transferMachineTo(String name) {
    return '$name へ';
  }

  @override
  String get transferRemoteMachineFallback => 'リモートマシン';

  @override
  String get transferFolderKind => 'フォルダ';

  @override
  String get transferLinkKind => 'リンク';

  @override
  String get transferFileKind => 'ファイル';

  @override
  String transferBytesTransferred(String bytes) {
    return '$bytes 転送済み';
  }

  @override
  String get transferStateQueued => '待機中';

  @override
  String get transferStateRunning => '実行中';

  @override
  String get transferStatePaused => '一時停止';

  @override
  String get transferStateCompleted => '完了';

  @override
  String get transferStateFailed => '失敗';

  @override
  String get transferStateCanceled => 'キャンセル済み';

  @override
  String get dataExchangeLockedSubtitle => 'この操作を使うにはボールトを解除してください。';

  @override
  String get dataExchangeTitle => 'インポート / エクスポート';

  @override
  String get dataExchangeSubtitle =>
      'バックアップはいつでも利用できます。ホスト、ID、SSH データにはボールトの解除が必要です。';

  @override
  String get dataExchangeExportSection => 'エクスポート';

  @override
  String get dataExchangeImportSection => 'インポート';

  @override
  String get dataExchangeExportBackupTitle => '暗号化バックアップをエクスポート';

  @override
  String get dataExchangeExportBackupSubtitle => '暗号化されたボールト記録とヘッダー。';

  @override
  String get dataExchangeExportDiagnosticBundleTitle => '診断ログをエクスポート';

  @override
  String get dataExchangeExportDiagnosticBundleSubtitle => '編集済みの実行情報と障害の手掛かり。';

  @override
  String get dataExchangeExportHostMetadataTitle => 'ホストメタデータをエクスポート';

  @override
  String get dataExchangeExportHostMetadataSubtitle => 'ホスト名、アドレス、タグ、オプション。';

  @override
  String get dataExchangeExportOpenSshConfigTitle => 'OpenSSH 設定をエクスポート';

  @override
  String get dataExchangeExportOpenSshConfigSubtitle =>
      '選択したホストを OpenSSH 設定として出力します。';

  @override
  String get dataExchangeExportIdentityMetadataTitle => 'ID メタデータをエクスポート';

  @override
  String get dataExchangeExportIdentityMetadataSubtitle => '表示名、ヒント、公開鍵指紋。';

  @override
  String get dataExchangeImportBackupTitle => '暗号化バックアップをインポート';

  @override
  String get dataExchangeImportBackupSubtitle => 'Serlink バックアップから記録をマージします。';

  @override
  String get dataExchangeImportOpenSshConfigTitle => 'OpenSSH 設定をインポート';

  @override
  String get dataExchangeImportOpenSshConfigSubtitle =>
      'ssh 設定ファイルからホストを作成します。';

  @override
  String get dataExchangeImportKnownHostsTitle => 'known_hosts をインポート';

  @override
  String get dataExchangeImportKnownHostsSubtitle => '既存ホストに指紋を追加します。';

  @override
  String get dataExchangeImportOpenSshCertificateTitle => 'OpenSSH 証明書をインポート';

  @override
  String get dataExchangeImportOpenSshCertificateSubtitle =>
      '鍵と証明書から ID を作成します。';

  @override
  String get exportVaultBackupTitle => '暗号化バックアップをエクスポートしますか？';

  @override
  String get exportVaultBackupBody =>
      'バックアップには暗号化されたボールトデータが含まれます。安全に保管してください。';

  @override
  String get backupExportedSnack => '暗号化バックアップをエクスポートしました。';

  @override
  String get noHostsAvailableExportSnack => 'エクスポートできるホストはありません。';

  @override
  String get exportHostMetadataTitle => 'ホストメタデータをエクスポートしますか？';

  @override
  String get exportHostMetadataBody =>
      'ホスト名、アドレス、ユーザー名、タグ、踏み台ホストリンク、接続オプションをエクスポートします。認証情報と秘密鍵データは含まれません。';

  @override
  String get hostMetadataExportedSnack => 'ホストメタデータをエクスポートしました。';

  @override
  String get hostMetadataExportFailedSnack => 'ホストメタデータをエクスポートできませんでした。';

  @override
  String get exportOpenSshConfigTitle => 'OpenSSH 設定をエクスポートしますか？';

  @override
  String get exportOpenSshConfigBody =>
      '選択したホストと必要な踏み台ホストを OpenSSH 設定としてエクスポートします。認証情報と秘密鍵データは含まれません。';

  @override
  String get openSshConfigExportedSnack => 'OpenSSH 設定をエクスポートしました。';

  @override
  String get exportIdentityMetadataTitle => 'ID メタデータをエクスポートしますか？';

  @override
  String get identityMetadataExportedSnack => 'ID メタデータをエクスポートしました。';

  @override
  String get exportDiagnosticBundleTitle => '診断ログをエクスポートしますか？';

  @override
  String get exportDiagnosticBundleBody =>
      '診断ログは編集済みで、端末出力、コマンド、ホスト、ユーザー名、パス、認証情報、秘密鍵は含まれません。';

  @override
  String get diagnosticBundleExportedSnack => '診断ログをエクスポートしました。';

  @override
  String get backupOperationFailed => 'バックアップ操作に失敗しました。';

  @override
  String get diagnosticExportFailed => '診断ログをエクスポートできませんでした。';

  @override
  String get openSshConfigExportFailed => 'OpenSSH 設定をエクスポートできませんでした。';

  @override
  String get identityMetadataExportFailed => 'ID メタデータをエクスポートできませんでした。';

  @override
  String get importFailed => 'インポートに失敗しました。';

  @override
  String get importEncryptedBackupTitle => '暗号化バックアップをインポートしますか？';

  @override
  String get importEncryptedBackupBody =>
      'このデバイスのボールトデータを置き換え、選択したバックアップの暗号化レコードをマージします。';

  @override
  String get backupImportedSnack => '暗号化バックアップをインポートしました。';

  @override
  String get noImportableOpenSshHostsSnack =>
      'インポート可能な OpenSSH ホストは見つかりませんでした。';

  @override
  String openSshHostsImportedSnack(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 台のホストをインポートしました。',
      one: '1 台のホストをインポートしました。',
    );
    return '$_temp0';
  }

  @override
  String openSshHostsImportedSkippedSnack(num count, num skipped) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 台のホストをインポートし、$skipped 台をスキップしました。',
      one: '1 台のホストをインポートし、$skipped 台をスキップしました。',
    );
    return '$_temp0';
  }

  @override
  String get importKnownHostsTitle => 'known_hosts をインポートしますか？';

  @override
  String get importKnownHostsBody =>
      'Serlink は既存ホストのホスト名とポートに一致する指紋をインポートします。ホスト名と指紋は暗号化されたボールト記録として保存されます。';

  @override
  String knownHostsImportedSnack(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 件の指紋をインポートしました。',
      one: '1 件の指紋をインポートしました。',
    );
    return '$_temp0';
  }

  @override
  String knownHostsImportedUnmatchedSnack(num count, num unmatched) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 件の指紋をインポートし、$unmatched 件は未一致でした。',
      one: '1 件の指紋をインポートし、$unmatched 件は未一致でした。',
    );
    return '$_temp0';
  }

  @override
  String identityImportedSnack(String name) {
    return '$name をインポートしました。';
  }

  @override
  String get importOpenSshConfigTitle => 'OpenSSH 設定をインポートしますか？';

  @override
  String openSshConfigHostsReady(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 台のホストをインポートできます。',
      one: '1 台のホストをインポートできます。',
    );
    return '$_temp0';
  }

  @override
  String openSshConfigHostsReadySkipped(num count, num skipped) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 台のホストをインポートできます。$skipped 台はスキップされました。',
      one: '1 台のホストをインポートできます。$skipped 台はスキップされました。',
    );
    return '$_temp0';
  }

  @override
  String get importWarningsTitle => 'インポート警告';

  @override
  String moreWarnings(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'さらに $count 件の警告があります。',
      one: 'さらに 1 件の警告があります。',
    );
    return '$_temp0';
  }

  @override
  String certificateDefaultName(String comment) {
    return '証明書 $comment';
  }

  @override
  String get importOpenSshCertificateTitle => 'OpenSSH 証明書をインポートしますか？';

  @override
  String get importAlgorithmLabel => 'アルゴリズム';

  @override
  String get importCommentLabel => 'コメント';

  @override
  String get passphraseWhitespaceError => 'パスフレーズの先頭または末尾に空白は使えません。';

  @override
  String get exportFieldHostnames => 'ホスト名';

  @override
  String get exportFieldUsernames => 'ユーザー名';

  @override
  String get exportFieldPorts => 'ポート';

  @override
  String get exportFieldJumpHostAliases => '踏み台ホスト別名';

  @override
  String get exportFieldConnectionSettings => '接続設定';

  @override
  String get exportFieldDisplayNames => '表示名';

  @override
  String get exportFieldUsernameHints => 'ユーザー名ヒント';

  @override
  String get exportFieldPublicKeyFingerprints => '公開鍵指紋';

  @override
  String get exportFieldCertificatePrincipals => '証明書プリンシパル';

  @override
  String get cancelAction => 'キャンセル';

  @override
  String get selectAction => '選択';

  @override
  String get searchAction => '検索';
}
