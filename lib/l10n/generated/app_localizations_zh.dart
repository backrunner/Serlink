// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Serlink';

  @override
  String get navHosts => '主机';

  @override
  String get navSessions => '会话';

  @override
  String get navTransfers => '传输';

  @override
  String get navSnippets => '片段';

  @override
  String get navSettings => '设置';

  @override
  String get searchHostsPlaceholder => '搜索主机、地址或标签';

  @override
  String get searchSnippetsPlaceholder => '搜索片段和命令';

  @override
  String get searchSessionsPlaceholder => '搜索活动会话';

  @override
  String get searchTransfersPlaceholder => '搜索传输';

  @override
  String get searchSettingsPlaceholder => '搜索设置';

  @override
  String get openLocalTerminalTooltip => '打开本地终端标签';

  @override
  String get clearSearchTooltip => '清除搜索';

  @override
  String get vaultTitle => '保险库';

  @override
  String get hostsTitle => '主机';

  @override
  String get hostsLoading => '正在加载加密主机记录';

  @override
  String get hostsNoMatchesTitle => '没有匹配项';

  @override
  String get hostsNoMatchesBody => '没有主机匹配当前工作区搜索。';

  @override
  String get hostsDeleteTitle => '删除主机？';

  @override
  String get hostsDeleteBody => '这会移除该主机，以及未被其他主机使用的所有凭据。';

  @override
  String get hostsDeleteAction => '删除';

  @override
  String get hostsDeletedSnack => '主机已删除。';

  @override
  String get hostsDeleteFailedSnack => '无法删除主机。';

  @override
  String get hostsAddTooltip => '添加主机';

  @override
  String get hostsEmptyTitle => '没有主机';

  @override
  String get hostsEmptyBody => '导入 SSH 配置或添加主机以开始会话。';

  @override
  String get hostsAddAction => '添加主机';

  @override
  String get sessionsEmptyTitle => '没有活动标签';

  @override
  String get sessionsEmptyBody => '从“主机”打开一个主机以创建终端或 SFTP 标签。';

  @override
  String get snippetsTitle => '片段';

  @override
  String get snippetsLockedBody => '解锁保险库以管理命令片段。';

  @override
  String get snippetsLoading => '正在加载加密片段。';

  @override
  String get snippetsNoMatchesBody => '没有片段匹配当前工作区搜索。';

  @override
  String get snippetsAddTooltip => '添加片段';

  @override
  String get snippetsAddAction => '添加片段';

  @override
  String get transfersTitle => '传输';

  @override
  String get transfersPreparing => '正在准备传输队列。';

  @override
  String get transfersEmptyTitle => '没有传输';

  @override
  String get transfersEmptyBody => 'SFTP 上传和下载会显示在这里。';

  @override
  String transfersItemCount(num count) {
    return '$count 项';
  }

  @override
  String transfersActiveCount(num count) {
    return '$count 个活动';
  }

  @override
  String get transfersClearAction => '清除';

  @override
  String get settingsTitle => '设置';

  @override
  String get settingsSubtitle => '安全、同步、导入/导出与运行时控制。';

  @override
  String get settingsGeneralSection => '通用';

  @override
  String get settingsLanguageTitle => '语言';

  @override
  String get settingsLanguageSubtitle => '选择应用显示语言。';

  @override
  String get settingsLanguageSystem => '跟随系统';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsLanguageChinese => '简体中文';

  @override
  String get settingsLanguageJapanese => '日本語';

  @override
  String get settingsLanguageSaved => '语言已更新。';

  @override
  String get settingsLanguageSaveFailed => '语言无法更新。';

  @override
  String get settingsSecuritySection => '安全';

  @override
  String get settingsVaultTitle => '保险库';

  @override
  String get settingsVaultPreparing => '正在准备加密存储';

  @override
  String get settingsVaultNotCreatedPill => '保险库未创建';

  @override
  String get settingsVaultLockedPill => '保险库已锁定';

  @override
  String get settingsVaultUnlockedPill => '保险库已解锁';

  @override
  String get settingsVaultLoadingPill => '保险库加载中';

  @override
  String get settingsVaultNotCreated => '尚未创建。';

  @override
  String get settingsVaultLocked => '已锁定。现有连接会继续运行。';

  @override
  String get settingsVaultUnlocked => '已解锁，可解析新的连接配置。';

  @override
  String get settingsLockAction => '锁定';

  @override
  String get settingsRecoverResetAction => '恢复 / 重置';

  @override
  String get settingsLocalUnlockTitle => '本地解锁';

  @override
  String get settingsLocalUnlockSemantics => '启用本地解锁';

  @override
  String get settingsLocalUnlockNeedsVault => '请先创建保险库，再启用设备保护的本地解锁。';

  @override
  String get settingsLocalUnlockEnabled => '已启用。锁定保险库后可用此设备解锁。';

  @override
  String get settingsLocalUnlockDisabled => '已停用。锁定后需要密码短语或恢复密钥。';

  @override
  String get settingsUnlockWithDeviceAction => '用设备解锁';

  @override
  String get settingsHostKeyConfirmationTitle => '主机密钥确认';

  @override
  String get settingsCredentialsTitle => '凭据';

  @override
  String get settingsCredentialsLocked => '解锁保险库以查看加密凭据。';

  @override
  String get settingsKnownHostsTitle => '已知主机';

  @override
  String get settingsKnownHostsLocked => '解锁保险库以查看受信任的主机指纹。';

  @override
  String get settingsManageAction => '管理';

  @override
  String get settingsDataSection => '数据';

  @override
  String get settingsImportExportTitle => '导入 / 导出';

  @override
  String get settingsImportExportSubtitle =>
      '备份、OpenSSH 文件、证书、known_hosts 与元数据。';

  @override
  String get settingsOpenAction => '打开';

  @override
  String get settingsRuntimeSection => '运行时';

  @override
  String get settingsDiagnosticBundleTitle => '诊断日志';

  @override
  String get settingsExportAction => '导出';

  @override
  String get settingsEnableLocalUnlockTitle => '启用本地解锁？';

  @override
  String get settingsDisableLocalUnlockTitle => '停用本地解锁？';

  @override
  String get settingsEnableLocalUnlockBody =>
      'Serlink 会在系统安全存储中保存一个随机设备密钥。不会保存你的保险库密码短语。';

  @override
  String get settingsDisableLocalUnlockBody => '这会移除此设备密钥。现有连接会继续运行。';

  @override
  String get settingsEnableAction => '启用';

  @override
  String get settingsDisableAction => '停用';

  @override
  String get settingsLocalUnlockEnabledSnack => '本地解锁已启用。锁定保险库后即可使用设备解锁。';

  @override
  String get settingsLocalUnlockVerifyFailedSnack => '无法验证本地解锁。';

  @override
  String get settingsLocalUnlockDisabledSnack => '本地解锁已停用。';

  @override
  String get settingsLocalUnlockStillAvailableSnack => '此设备上仍可使用本地解锁。';

  @override
  String get settingsLocalUnlockUpdateFailed => '无法更新本地解锁。';

  @override
  String get syncSectionTitle => '同步';

  @override
  String get syncLoadingEncryptedSettings => '正在加载加密同步设置。';

  @override
  String get syncConfigureAction => '配置';

  @override
  String get syncEditAction => '编辑';

  @override
  String get syncWebDavLocked => '解锁保险库以配置加密同步。';

  @override
  String get syncICloudChecking => '正在检查 iCloud 可用性。';

  @override
  String get syncICloudLocked => '解锁保险库以通过 iCloud 同步。';

  @override
  String get syncDevicesTitle => '设备';

  @override
  String get syncDevicesLoading => '正在加载加密设备记录。';

  @override
  String get syncViewAction => '查看';

  @override
  String get syncResetAction => '重置';

  @override
  String get syncRepairTitle => '同步修复';

  @override
  String get syncRepairAction => '修复';

  @override
  String get syncRemoteRepaired => '远程同步已修复。';

  @override
  String get syncWebDavCertificateTrustSaved => 'WebDAV 证书信任已保存。';

  @override
  String get syncICloudEnabledSnack => 'iCloud 同步已启用。';

  @override
  String get syncICloudPausedSnack => 'iCloud 同步已暂停。';

  @override
  String syncConflictsResolvedSnack(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '同步冲突已解决。已同步 $count 条加密记录。',
      one: '同步冲突已解决。已同步 1 条加密记录。',
    );
    return '$_temp0';
  }

  @override
  String get syncSettingsLoadFailed => '无法加载同步设置。';

  @override
  String syncLocalTimeLabel(String time) {
    return '本地时间：$time';
  }

  @override
  String syncEndpointLabel(String endpoint) {
    return '端点：$endpoint';
  }

  @override
  String syncValidFromLabel(String time) {
    return '生效时间：$time';
  }

  @override
  String syncValidUntilLabel(String time) {
    return '有效期至：$time';
  }

  @override
  String get doneAction => '完成';

  @override
  String get syncConflictsTitle => '同步冲突';

  @override
  String syncConflictsSubtitle(num count) {
    return '有 $count 条加密记录需要检查。';
  }

  @override
  String get syncReviewAction => '检查';

  @override
  String get syncUseRemoteAction => '使用远端';

  @override
  String get syncKeepLocalAction => '保留本地';

  @override
  String get syncUseRemoteTitle => '使用远端记录？';

  @override
  String get syncKeepLocalTitle => '保留本地记录？';

  @override
  String get syncUseRemoteBody => '同步前，远端加密记录会替换冲突的本地记录。';

  @override
  String get syncKeepLocalBody => '本地加密记录会覆盖冲突的远端记录。';

  @override
  String get syncPausedICloudSubtitle => '已暂停。加密记录会通过你的私有 iCloud 数据库同步。';

  @override
  String get syncEnabledStatus => '已启用';

  @override
  String get syncPausedStatus => '已暂停';

  @override
  String get syncWebDavNotConfiguredSubtitle => '未配置。仅同步加密清单和记录。';

  @override
  String get syncHttpAllowedStatus => '允许 HTTP';

  @override
  String get syncHttpsStatus => 'HTTPS';

  @override
  String get syncAutoSyncWaiting => '自动同步等待中';

  @override
  String get syncAutoSyncReady => '自动同步就绪';

  @override
  String syncLastSynced(String time) {
    return '上次同步 $time';
  }

  @override
  String get syncAutoSyncQueued => '自动同步已排队';

  @override
  String get syncSyncingAutomatically => '正在自动同步';

  @override
  String syncConflictCount(num count) {
    return '$count 个冲突';
  }

  @override
  String get syncAutoSyncFailed => '自动同步失败';

  @override
  String get saveAction => '保存';

  @override
  String get savingAction => '保存中';

  @override
  String get closeAction => '关闭';

  @override
  String get removeAction => '移除';

  @override
  String get importAction => '导入';

  @override
  String get deleteAction => '删除';

  @override
  String get renameAction => '重命名';

  @override
  String get skipAction => '跳过';

  @override
  String get pasteAction => '粘贴';

  @override
  String get confirmAction => '确认';

  @override
  String get applyAction => '应用';

  @override
  String get createAction => '创建';

  @override
  String get runAction => '运行';

  @override
  String get pauseAction => '暂停';

  @override
  String get resumeAction => '继续';

  @override
  String get retryAction => '重试';

  @override
  String get connectAction => '连接';

  @override
  String get chooseFolderAction => '选择文件夹';

  @override
  String get loadingSemantics => '正在加载';

  @override
  String get securityWebDavCertificateChangedTitle => 'WebDAV 证书已变更';

  @override
  String get securityTrustWebDavCertificateTitle => '信任 WebDAV 证书？';

  @override
  String get securityHostKeyChangedTitle => '主机密钥已变更';

  @override
  String get securityConfirmFingerprintTitle => '确认指纹';

  @override
  String securityAlgorithmLabel(String value) {
    return '算法：$value';
  }

  @override
  String securityPreviousLabel(String value) {
    return '之前：$value';
  }

  @override
  String securitySubjectLabel(String value) {
    return '主题：$value';
  }

  @override
  String securityIssuerLabel(String value) {
    return '签发者：$value';
  }

  @override
  String securityValidRangeLabel(String from, String to) {
    return '有效期：$from 至 $to';
  }

  @override
  String get securityCertificateClockWarning => '此证书尚未生效。信任前请检查此设备的时钟。';

  @override
  String get securityTrustOnceAction => '仅本次信任';

  @override
  String get securityTrustAndSaveAction => '信任并保存';

  @override
  String get securityEncryptedExport => '加密导出';

  @override
  String get securityUnencryptedExport => '未加密导出';

  @override
  String securitySensitiveFields(String fields) {
    return '敏感字段：$fields';
  }

  @override
  String get securityCannotBeUndone => '此操作无法撤销。';

  @override
  String get securityPasteMultipleLinesTitle => '粘贴多行？';

  @override
  String securityPasteMultipleLinesBody(num count) {
    return '$count 行将发送到当前终端。';
  }

  @override
  String get hostEditTitle => '编辑主机';

  @override
  String get hostAddTitle => '添加主机';

  @override
  String get hostSectionConnection => '连接';

  @override
  String get hostSectionAuthentication => '认证';

  @override
  String get hostSectionStartup => '启动';

  @override
  String get hostSectionRouting => '路由';

  @override
  String get hostDisplayNameLabel => '显示名称';

  @override
  String get hostDisplayNameOptionalLabel => '显示名称（可选）';

  @override
  String get hostDisplayNameHostnameHint => '与主机名一致';

  @override
  String get hostDisplayNameHostnameHelper => '留空则使用主机名。';

  @override
  String get hostHostnameLabel => '主机名';

  @override
  String get hostPortLabel => '端口';

  @override
  String get hostUsernameLabel => '用户名';

  @override
  String get hostStartupCommandsLabel => '启动命令';

  @override
  String get hostTagsLabel => '标签';

  @override
  String get hostStartFolderLabel => '起始文件夹';

  @override
  String get hostPrivateKeyLabel => '私钥';

  @override
  String get hostImportPrivateKeyTooltip => '导入私钥';

  @override
  String get hostKeyPassphraseLabel => '密钥密码短语';

  @override
  String get hostAdvancedConnectionTitle => '高级连接';

  @override
  String get hostTimeoutLabel => '超时（秒）';

  @override
  String get hostKeepaliveLabel => '保活（秒）';

  @override
  String get hostAutoReconnectLabel => '自动重连';

  @override
  String get hostBackoffLabel => '退避（秒）';

  @override
  String get hostAuthPasswordSegment => '密码';

  @override
  String get hostAuthKeySegment => '密钥';

  @override
  String get hostAuthAgentSegment => '代理';

  @override
  String get hostAuthSavedSegment => '已保存';

  @override
  String get hostPasswordLabel => '密码';

  @override
  String get hostShowPasswordTooltip => '显示密码';

  @override
  String get hostHidePasswordTooltip => '隐藏密码';

  @override
  String get hostSshAgentNote =>
      '使用本地 SSH agent 中的身份。在 macOS 上，载入 ssh-agent 的密钥可以由钥匙串保护。';

  @override
  String get hostNoSavedCredentials => '还没有可用的已保存凭据。';

  @override
  String get hostCredentialsHeading => '凭据';

  @override
  String get hostEditCredentialTooltip => '编辑凭据';

  @override
  String get hostCredentialOptionalNote => '你可以先保存不带凭据的主机，稍后再添加。';

  @override
  String get hostJumpHostsHeading => '跳板主机';

  @override
  String get hostPortNumberError => '端口必须是数字。';

  @override
  String get hostSaveFailed => '无法保存主机。';

  @override
  String get hostConfigurationLoadFailed => '无法加载主机配置。';

  @override
  String get hostConnectionSettingsWholeNumbers => '连接设置必须是整数。';

  @override
  String get identityKindPassword => '密码';

  @override
  String get identityKindPrivateKey => '私钥';

  @override
  String get identityKindKeyboard => '键盘交互';

  @override
  String get identityKindCertificate => '证书';

  @override
  String get identityKindSshAgent => 'SSH Agent';

  @override
  String get identityKindHardwareKey => '硬件密钥';

  @override
  String identityUserLabel(String username) {
    return '用户 $username';
  }

  @override
  String identityPrincipalLabel(String principal) {
    return '主体 $principal';
  }

  @override
  String get snippetInsertTooltip => '插入到当前终端';

  @override
  String get snippetRunTooltip => '在当前终端运行';

  @override
  String get snippetEditTooltip => '编辑片段';

  @override
  String get snippetDeleteTooltip => '删除片段';

  @override
  String get snippetDialogEditTitle => '编辑片段';

  @override
  String get snippetDialogAddTitle => '添加片段';

  @override
  String get snippetNameLabel => '名称';

  @override
  String get snippetCommandLabel => '命令';

  @override
  String get snippetTagsLabel => '标签';

  @override
  String get snippetConfirmBeforeRun => '运行前确认';

  @override
  String get snippetAddTagsHint => '添加标签';

  @override
  String get snippetAddTagHint => '添加标签';

  @override
  String get snippetRemoveTagTooltip => '移除标签';

  @override
  String get snippetRunTitle => '运行片段？';

  @override
  String get snippetDeleteTitle => '删除片段？';

  @override
  String get snippetSaveFailed => '无法保存片段。';

  @override
  String get snippetSentSnack => '片段已发送到终端。';

  @override
  String get snippetInsertedSnack => '片段已插入终端。';

  @override
  String get snippetNoTerminalSnack => '请先打开已连接的终端标签。';

  @override
  String get snippetDeletedSnack => '片段已删除。';

  @override
  String get snippetDeleteFailedSnack => '无法删除片段。';

  @override
  String get syncDevicesDialogTitle => '同步设备';

  @override
  String syncDeviceRemoveTitle(String name) {
    return '移除 $name？';
  }

  @override
  String get syncDeviceRemoveBody => '这会从此保险库中移除加密同步设备记录。';

  @override
  String get syncDeviceRemovedSnack => '同步设备已移除。';

  @override
  String get syncDeviceRemoveFailedSnack => '无法移除同步设备。';

  @override
  String get syncDeviceResetTitle => '重置同步设备？';

  @override
  String get syncDeviceResetBody =>
      '这会从加密同步中移除当前设备注册，并创建新的本地设备身份。其他设备会看到旧设备已被移除。';

  @override
  String get syncDeviceResetSnack => '同步设备已重置。下次同步时会创建新的注册。';

  @override
  String get syncDeviceResetFailedSnack => '无法重置同步设备。';

  @override
  String get syncDevicesEmptyTitle => '还没有同步设备';

  @override
  String get syncDevicesEmptyBody => '首次加密同步成功后，此设备会显示在这里。';

  @override
  String get syncDeviceRemoveTooltip => '移除设备';

  @override
  String get syncDevicesWillRegister => '此设备将在首次同步时注册。';

  @override
  String syncDeviceSingleSubtitle(String name) {
    return '$name 已注册用于加密同步。';
  }

  @override
  String syncDevicesMultipleSubtitle(num count, String name) {
    return '$count 台设备已注册。最后写入者：$name。';
  }

  @override
  String syncDeviceThisDevice(String name) {
    return '$name（此设备）';
  }

  @override
  String syncDeviceSubtitle(String platform, String time) {
    return '$platform / 上次出现 $time';
  }

  @override
  String get webDavSyncTitle => 'WebDAV 同步';

  @override
  String get webDavEndpointLabel => '端点';

  @override
  String get webDavEndpointHint => 'https://example.com/webdav';

  @override
  String get webDavUsernameLabel => '用户名';

  @override
  String get webDavPasswordLabel => '密码';

  @override
  String get webDavPasswordKeepLabel => '密码（留空则保留）';

  @override
  String get webDavBasePathLabel => '基础路径';

  @override
  String get webDavEnableTitle => '启用 WebDAV 同步';

  @override
  String get webDavAllowHttpTitle => '允许 HTTP 端点';

  @override
  String get webDavUseHttpTitle => '使用 HTTP WebDAV？';

  @override
  String get webDavUseHttpBody => 'HTTP 同步可能在传输中暴露元数据和凭据。仅应在可信的本地测试服务器上使用。';

  @override
  String get webDavAllowHttpAction => '允许 HTTP';

  @override
  String get webDavSavedSnack => 'WebDAV 同步设置已保存。';

  @override
  String get webDavRemoveTitle => '移除 WebDAV 同步？';

  @override
  String get webDavRemoveBody => '这会移除本地 WebDAV 配置和保存的密码。';

  @override
  String get webDavRemovedSnack => 'WebDAV 同步设置已移除。';

  @override
  String get credentialsDialogTitle => '凭据';

  @override
  String get credentialsEmptyTitle => '没有保存的凭据';

  @override
  String get credentialsEmptyBody => '导入的密码、私钥、证书和身份元数据会显示在这里。';

  @override
  String get credentialsEditTooltip => '编辑凭据';

  @override
  String get credentialsDeleteTooltip => '删除凭据';

  @override
  String get credentialUpdatedSnack => '凭据已更新。';

  @override
  String get credentialDeleteTitle => '删除凭据？';

  @override
  String get credentialDeleteBody => '这会移除凭据及其加密密钥材料。';

  @override
  String credentialDeleteLinkedBody(String hosts) {
    return '此凭据仍关联到：$hosts。请先移除这些主机关联后再删除。';
  }

  @override
  String get credentialDeletedSnack => '凭据已删除。';

  @override
  String get credentialDeleteFailedSnack => '无法删除凭据。';

  @override
  String get knownHostsDialogTitle => '已知主机';

  @override
  String get knownHostsEmptyTitle => '没有受信任的指纹';

  @override
  String get knownHostsEmptyBody => '连接确认时接受的主机指纹会显示在这里。';

  @override
  String get knownHostDeleteTooltip => '删除已知主机';

  @override
  String get knownHostDeleteTitle => '删除已知主机？';

  @override
  String knownHostDeleteBody(String host) {
    return '这会移除 $host 保存的指纹。下次连接时需要再次确认。';
  }

  @override
  String get knownHostDeletedSnack => '已知主机已删除。';

  @override
  String get knownHostDeleteFailedSnack => '无法删除已知主机。';

  @override
  String get startAction => '开始';

  @override
  String get stopAction => '停止';

  @override
  String get uploadAction => '上传';

  @override
  String get downloadAction => '下载';

  @override
  String get moveAction => '移动';

  @override
  String get replaceAction => '替换';

  @override
  String get mergeAction => '合并';

  @override
  String get copiedAction => '已复制';

  @override
  String get clearAllAction => '全部清除';

  @override
  String get selectAllAction => '全选';

  @override
  String get restartAction => '重新启动';

  @override
  String get reconnectAction => '重新连接';

  @override
  String get windowCloseActiveTerminalsTitle => '关闭活动终端？';

  @override
  String windowCloseActiveTerminalsBody(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '仍有 $count 个终端窗格在运行。关闭此窗口会断开它们。',
      one: '仍有 1 个终端窗格在运行。关闭此窗口会断开它。',
    );
    return '$_temp0';
  }

  @override
  String get windowCloseWindowAction => '关闭窗口';

  @override
  String get windowCloseLabel => '关闭窗口';

  @override
  String get windowMinimizeLabel => '最小化窗口';

  @override
  String get windowZoomLabel => '缩放窗口';

  @override
  String get hostEditMenu => '编辑主机';

  @override
  String get hostDeleteMenu => '删除主机';

  @override
  String get hostTerminalAction => '终端';

  @override
  String get hostSftpAction => 'SFTP';

  @override
  String get hostTrustTrusted => '已信任';

  @override
  String get hostTrustVerify => '待验证';

  @override
  String get hostTrustChanged => '已变更';

  @override
  String get tabsCloseTooltip => '关闭标签页';

  @override
  String get tabsNewConnectionTooltip => '新建连接';

  @override
  String get localShellInactive => '本地 shell 未运行。';

  @override
  String get connectionInactive => '连接未激活。';

  @override
  String get localShellTitle => '本地 Shell';

  @override
  String get terminalSearchTooltip => '搜索终端';

  @override
  String get terminalOpenSftpTooltip => '打开 SFTP 标签页';

  @override
  String get terminalSplitRightTooltip => '向右拆分';

  @override
  String get terminalSplitDownTooltip => '向下拆分';

  @override
  String get terminalClosePaneTooltip => '关闭活动窗格';

  @override
  String get terminalSettingsTitle => '终端设置';

  @override
  String get terminalForwardingUpdating => '正在更新端口转发';

  @override
  String get terminalForwardingManage => '管理端口转发';

  @override
  String terminalForwardingManageActive(num count) {
    return '管理端口转发（$count 个活动）';
  }

  @override
  String get terminalNoSearchResults => '无结果';

  @override
  String get terminalPreviousMatchTooltip => '上一个匹配';

  @override
  String get terminalNextMatchTooltip => '下一个匹配';

  @override
  String get terminalCloseSearchTooltip => '关闭搜索';

  @override
  String get terminalAppearanceSection => '外观';

  @override
  String get terminalThemeLabel => '主题';

  @override
  String get terminalLayoutSection => '布局';

  @override
  String get terminalFontSizeLabel => '字号';

  @override
  String get terminalLineHeightLabel => '行高';

  @override
  String get terminalScrollbackLabel => '回滚行数';

  @override
  String get terminalSaveForHostAction => '为主机保存';

  @override
  String get terminalUseGlobalAction => '使用全局';

  @override
  String get terminalFontLabel => '字体';

  @override
  String get terminalSearchFontsHint => '搜索字体';

  @override
  String get terminalSelectFontHint => '选择字体';

  @override
  String get terminalCustomFamilyLabel => '自定义字体族';

  @override
  String get terminalCustomFamilyHelper => '输入已安装的字体族，然后应用。';

  @override
  String get terminalCustomFamilyHint => '例如 JetBrains Mono';

  @override
  String get terminalApplyCustomFontTooltip => '应用自定义字体';

  @override
  String get terminalScanningFonts => '正在扫描字体';

  @override
  String get terminalNerdFontReady => 'Nerd Font 已就绪';

  @override
  String get terminalNoNerdFont => '没有 Nerd Font';

  @override
  String get terminalLifecycleRunning => '运行中';

  @override
  String get terminalLifecycleStarting => '正在启动';

  @override
  String get terminalLifecycleExited => '已退出';

  @override
  String get terminalLifecycleFailed => '失败';

  @override
  String get terminalLifecycleStopping => '正在停止';

  @override
  String get terminalLifecycleConnected => '已连接';

  @override
  String get terminalLifecycleConnecting => '正在连接';

  @override
  String get terminalLifecycleReconnecting => '正在重连';

  @override
  String get terminalLifecycleDisconnected => '已断开';

  @override
  String get terminalLifecyclePreparing => '准备中';

  @override
  String get terminalLifecycleVerifying => '验证中';

  @override
  String get terminalLifecycleAuthenticating => '认证中';

  @override
  String get terminalLifecycleDisconnecting => '正在断开';

  @override
  String get terminalLifecycleIdle => '空闲';

  @override
  String get forwardingDialogTitle => '端口转发';

  @override
  String get forwardingLocalTitle => '本地';

  @override
  String get forwardingLocalSubtitle => '在此设备上暴露远程服务。';

  @override
  String get forwardingRemoteTitle => '远程';

  @override
  String get forwardingRemoteSubtitle => '在远程主机上暴露本地服务。';

  @override
  String get forwardingSocksTitle => 'SOCKS 代理';

  @override
  String get forwardingSocksSubtitle => '为此 SSH 会话启动本地动态代理。';

  @override
  String get forwardingLocalPortLabel => '本地端口';

  @override
  String get forwardingRemoteHostLabel => '远程主机';

  @override
  String get forwardingRemotePortLabel => '远程端口';

  @override
  String get forwardingBindHostLabel => '绑定主机';

  @override
  String get forwardingBindPortLabel => '绑定端口';

  @override
  String get forwardingLocalHostLabel => '本地主机';

  @override
  String get forwardingLocalValidationError => '端口必须为 1-65535，且远程主机必填。';

  @override
  String get forwardingRemoteValidationError => '绑定主机、本地主机和端口必须有效。';

  @override
  String get forwardingDynamicValidationError => '绑定主机和端口必须有效。';

  @override
  String get forwardingLocalStartedSnack => '本地端口转发已启动。';

  @override
  String get forwardingLocalStartFailedSnack => '无法启动本地端口转发。';

  @override
  String get forwardingLocalStoppedSnack => '本地端口转发已停止。';

  @override
  String get forwardingLocalStopFailedSnack => '无法停止本地端口转发。';

  @override
  String get forwardingRemoteStartedSnack => '远程端口转发已启动。';

  @override
  String get forwardingRemoteStartFailedSnack => '无法启动远程端口转发。';

  @override
  String get forwardingRemoteStoppedSnack => '远程端口转发已停止。';

  @override
  String get forwardingRemoteStopFailedSnack => '无法停止远程端口转发。';

  @override
  String get forwardingSocksStartedSnack => 'SOCKS 代理已启动。';

  @override
  String get forwardingSocksStartFailedSnack => '无法启动 SOCKS 代理。';

  @override
  String get forwardingSocksStoppedSnack => 'SOCKS 代理已停止。';

  @override
  String get forwardingSocksStopFailedSnack => '无法停止 SOCKS 代理。';

  @override
  String get vaultCreateTitle => '创建保险库';

  @override
  String get vaultUnlockTitle => '解锁保险库';

  @override
  String get vaultCreateSubtitle => '用强密码短语加密主机和密钥。';

  @override
  String get vaultUnlockSubtitle => '输入密码短语以解密工作区。';

  @override
  String get vaultNewPassphraseLabel => '新密码短语';

  @override
  String get vaultPassphraseLabel => '密码短语';

  @override
  String get vaultCreateAction => '创建保险库';

  @override
  String get vaultUnlockAction => '解锁';

  @override
  String get vaultUnlockWithDeviceAction => '用设备解锁';

  @override
  String get vaultUseRecoveryCodeAction => '使用恢复码';

  @override
  String get vaultPassphraseRequired => '请输入保险库密码短语以继续。';

  @override
  String get vaultRecoveryKeyTitle => '恢复密钥';

  @override
  String get vaultRecoveryKeySaveInstruction => '继续前请保存此密钥。';

  @override
  String get vaultRecoveryKeyWarningTitle => '立即保存此密钥';

  @override
  String get vaultRecoveryKeyWarningBody => '此密钥只会显示一次。若丢失，Serlink 无法为你找回。';

  @override
  String get vaultCopyRecoveryKeyAction => '复制恢复密钥';

  @override
  String get vaultRecoveryKeySavedAction => '我已保存';

  @override
  String get vaultResetTitle => '重置保险库';

  @override
  String get vaultRecoveryCodeTitle => '恢复码';

  @override
  String get vaultResetSubtitle => '仅在无法用密码短语或恢复码解锁此保险库时重置。';

  @override
  String get vaultRecoveryCodeSubtitle => '输入恢复码以解锁此保险库。';

  @override
  String get vaultRecoveryCodeLabel => '恢复码';

  @override
  String get vaultRecoveryCodeHelper => '粘贴完整恢复码。';

  @override
  String get vaultResetVaultAction => '重置保险库';

  @override
  String get vaultResetPermanentlyAction => '永久重置保险库';

  @override
  String get vaultRecoveryCodeRequired => '请输入恢复码以继续。';

  @override
  String vaultResetTypePhraseError(String phrase) {
    return '输入 $phrase 以确认重置。';
  }

  @override
  String vaultResetTypePhraseLabel(String phrase) {
    return '输入 $phrase';
  }

  @override
  String get vaultResetPhraseHelper => '该短语区分大小写，重置时必填。';

  @override
  String get vaultResetWarningTitle => '此操作会永久影响此设备';

  @override
  String get vaultResetWarningRecords => '加密主机、身份、片段、传输历史、同步设置和恢复数据将被删除。';

  @override
  String get vaultResetWarningSecrets => '重置不会找回密码短语，也不会显示现有机密。';

  @override
  String get vaultResetWarningBackup => '继续前你需要备份或新的保险库。';

  @override
  String get credentialEditTitle => '编辑凭据';

  @override
  String get credentialLoadingSecretSemantics => '正在加载凭据机密';

  @override
  String get credentialNameLabel => '凭据名称';

  @override
  String get credentialUsernameHintLabel => '用户名提示';

  @override
  String get credentialPasswordLabel => '密码';

  @override
  String get credentialKeyboardResponsesLabel => '键盘交互响应';

  @override
  String get credentialKeyboardResponsesHelper => '每行一个响应。';

  @override
  String get credentialNoSecretMaterial => '此凭据没有保存的机密材料。';

  @override
  String get credentialSecretLoadFailed => '无法加载凭据机密。';

  @override
  String get credentialSaveFailed => '无法保存凭据。';

  @override
  String get credentialSshPrivateKeyTypeLabel => 'SSH 私钥';

  @override
  String get credentialOpenSshCertificateTypeLabel => 'OpenSSH 证书';

  @override
  String get credentialCertificateLabel => '证书';

  @override
  String get credentialImportCertificateTooltip => '导入证书';

  @override
  String get syncConflictReviewDialogTitle => '查看同步冲突';

  @override
  String get syncConflictApplying => '正在应用';

  @override
  String get syncConflictApplyMergeAction => '应用合并';

  @override
  String get syncConflictLocalLabel => '本地';

  @override
  String get syncConflictRemoteLabel => '远程';

  @override
  String get syncConflictUnsupportedBody =>
      '此记录类型当前需要整条记录解决。请对该冲突使用已有的本地或远程操作。';

  @override
  String get sftpParentFolderTooltip => '前往上级文件夹';

  @override
  String get sftpSearchPlaceholder => '搜索文件';

  @override
  String get sftpHideHiddenFilesTooltip => '隐藏隐藏文件';

  @override
  String get sftpShowHiddenFilesTooltip => '显示隐藏文件';

  @override
  String get sftpOpenTerminalTooltip => '打开终端标签页';

  @override
  String get sftpUploadFileAction => '上传文件';

  @override
  String get sftpUploadFolderAction => '上传文件夹';

  @override
  String get sftpNewFolderTooltip => '新建文件夹';

  @override
  String get sftpRefreshTooltip => '刷新';

  @override
  String get sftpWaitingTitle => 'SFTP';

  @override
  String get sftpWaitingBody => '正在等待 SFTP 连接。';

  @override
  String get sftpStartFolderTitle => 'SFTP 起始文件夹';

  @override
  String sftpStartFolderBody(String path) {
    return 'Serlink 无法列出 $path。请选择此账户可访问的文件夹。';
  }

  @override
  String get sftpErrorTitle => 'SFTP 错误';

  @override
  String get sftpEmptyFolderTitle => '空文件夹';

  @override
  String get sftpNoEntriesFilter => '没有条目匹配当前筛选。';

  @override
  String get sftpHiddenOnly => '此远程目录只包含隐藏条目。';

  @override
  String get sftpNoVisible => '此远程目录没有可见条目。';

  @override
  String get sftpDirectoryLabel => '文件夹';

  @override
  String get sftpFileLabel => '文件';

  @override
  String get sftpSymlinkLabel => '符号链接';

  @override
  String get sftpUnknownLabel => '未知';

  @override
  String get sftpNewFolderTitle => '新建文件夹';

  @override
  String get sftpFolderNameLabel => '文件夹名称';

  @override
  String get sftpFolderCreatedSnack => '文件夹已创建。';

  @override
  String get sftpSelectedFileNoPathSnack => '所选文件没有本地路径。';

  @override
  String get sftpUploadQueuedSnack => '上传已加入队列。';

  @override
  String get sftpFolderUploadQueuedSnack => '文件夹上传已加入队列。';

  @override
  String get sftpFolderDownloadQueuedSnack => '文件夹下载已加入队列。';

  @override
  String get sftpDownloadQueuedSnack => '下载已加入队列。';

  @override
  String get sftpMergeRemoteFolderTitle => '合并远程文件夹？';

  @override
  String get sftpReplaceRemoteFileTitle => '替换远程文件？';

  @override
  String sftpRemoteExistsOverwriteBody(String path) {
    return '$path 已存在于服务器上。匹配的文件可能会被覆盖。';
  }

  @override
  String sftpRemoteExistsBody(String path) {
    return '$path 已存在于服务器上。';
  }

  @override
  String get sftpMergeLocalFolderTitle => '合并本地文件夹？';

  @override
  String get sftpReplaceLocalFileTitle => '替换本地文件？';

  @override
  String sftpLocalExistsOverwriteBody(String path) {
    return '$path 已存在于此设备上。匹配的文件可能会被覆盖。';
  }

  @override
  String sftpLocalExistsBody(String path) {
    return '$path 已存在于此设备上。';
  }

  @override
  String get sftpNewNameLabel => '新名称';

  @override
  String get sftpTargetPathLabel => '目标路径';

  @override
  String get sftpTargetExistsSnack => '目标路径已存在。';

  @override
  String get sftpEntryRenamedSnack => '条目已重命名。';

  @override
  String get sftpEntryMovedSnack => '条目已移动。';

  @override
  String get sftpChangePermissionsTitle => '更改权限';

  @override
  String get sftpOctalPermissionsLabel => '权限（八进制或符号）';

  @override
  String get sftpPermissionsOctalError => '权限必须是八进制（如 0644）或符号格式（如 rw-r--r--）。';

  @override
  String get sftpPermissionsUpdatedSnack => '权限已更新。';

  @override
  String sftpDeleteEntryTitle(String name) {
    return '删除 $name？';
  }

  @override
  String get sftpDeleteDirectoryBody => '这会删除远程目录及其内容。';

  @override
  String get sftpDeleteFileBody => '这会删除远程文件。';

  @override
  String get sftpEntryDeletedSnack => '条目已删除。';

  @override
  String get sftpFileSavedSnack => '文件已保存。';

  @override
  String remoteFilePreviewLimited(String bytes) {
    return '预览限制为 $bytes。';
  }

  @override
  String get sftpDefaultDirectoryDialogTitle => '选择 SFTP 起始文件夹';

  @override
  String sftpDefaultDirectoryFailedMessage(String path, String reason) {
    return '无法列出 $path。$reason';
  }

  @override
  String get sftpStartFolderLabel => '起始文件夹';

  @override
  String get sftpStartFolderHint => '/home/user';

  @override
  String get sftpAbsolutePathError => '请输入绝对远程路径。';

  @override
  String get transferDeleteMenu => '删除传输';

  @override
  String transferEtaLeft(String time) {
    return '剩余 $time';
  }

  @override
  String get transferClearTitle => '清除传输？';

  @override
  String transferClearBody(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '从历史中清除 $count 条传输记录。',
      one: '从历史中清除 1 条传输记录。',
    );
    return '$_temp0';
  }

  @override
  String transferClearActiveBody(num count, num activeCount) {
    return '从历史中清除 $count 条传输记录，并取消 $activeCount 个活动传输。';
  }

  @override
  String get transferClearedSnack => '传输已清除。';

  @override
  String get transferRemoveLocalFailedSnack => '传输已移除，但无法删除本地文件。';

  @override
  String get transferAndLocalDeletedSnack => '传输和本地文件已删除。';

  @override
  String get transferDeletedSnack => '传输已删除。';

  @override
  String get transferCompletedMissingSnack => '已完成项目在本地不再可用。';

  @override
  String get transferOpenFailedSnack => '无法打开已完成项目。';

  @override
  String get transferDeleteTitle => '删除传输？';

  @override
  String transferDeleteLocalBody(String kind, String path) {
    return '本地 $kind 仍位于 $path。仅移除传输，还是同时删除本地 $kind？';
  }

  @override
  String get transferRemoveOnlyAction => '仅移除传输';

  @override
  String transferDeleteLocalTooAction(String kind) {
    return '同时删除 $kind';
  }

  @override
  String transferMachineFrom(String name) {
    return '来自 $name';
  }

  @override
  String transferMachineTo(String name) {
    return '到 $name';
  }

  @override
  String get transferRemoteMachineFallback => '远程机器';

  @override
  String get transferFolderKind => '文件夹';

  @override
  String get transferLinkKind => '链接';

  @override
  String get transferFileKind => '文件';

  @override
  String transferBytesTransferred(String bytes) {
    return '已传输 $bytes';
  }

  @override
  String get transferStateQueued => '排队中';

  @override
  String get transferStateRunning => '运行中';

  @override
  String get transferStatePaused => '已暂停';

  @override
  String get transferStateCompleted => '已完成';

  @override
  String get transferStateFailed => '失败';

  @override
  String get transferStateCanceled => '已取消';

  @override
  String get dataExchangeLockedSubtitle => '解锁保险库以使用此操作。';

  @override
  String get dataExchangeTitle => '导入 / 导出';

  @override
  String get dataExchangeSubtitle => '备份随时可用。主机、身份和 SSH 数据需要解锁保险库。';

  @override
  String get dataExchangeExportSection => '导出';

  @override
  String get dataExchangeImportSection => '导入';

  @override
  String get dataExchangeExportBackupTitle => '导出加密备份';

  @override
  String get dataExchangeExportBackupSubtitle => '加密保险库记录和头部。';

  @override
  String get dataExchangeExportDiagnosticBundleTitle => '导出诊断日志';

  @override
  String get dataExchangeExportDiagnosticBundleSubtitle => '脱敏运行信息和故障线索。';

  @override
  String get dataExchangeExportHostMetadataTitle => '导出主机元数据';

  @override
  String get dataExchangeExportHostMetadataSubtitle => '主机名、地址、标签和选项。';

  @override
  String get dataExchangeExportOpenSshConfigTitle => '导出 OpenSSH 配置';

  @override
  String get dataExchangeExportOpenSshConfigSubtitle => '将所选主机导出为 OpenSSH 配置。';

  @override
  String get dataExchangeExportIdentityMetadataTitle => '导出身份元数据';

  @override
  String get dataExchangeExportIdentityMetadataSubtitle => '显示名称、提示和公钥指纹。';

  @override
  String get dataExchangeImportBackupTitle => '导入加密备份';

  @override
  String get dataExchangeImportBackupSubtitle => '从 Serlink 备份合并记录。';

  @override
  String get dataExchangeImportOpenSshConfigTitle => '导入 OpenSSH 配置';

  @override
  String get dataExchangeImportOpenSshConfigSubtitle => '从 ssh 配置文件创建主机。';

  @override
  String get dataExchangeImportKnownHostsTitle => '导入 known_hosts';

  @override
  String get dataExchangeImportKnownHostsSubtitle => '为现有主机添加指纹。';

  @override
  String get dataExchangeImportOpenSshCertificateTitle => '导入 OpenSSH 证书';

  @override
  String get dataExchangeImportOpenSshCertificateSubtitle => '从密钥和证书创建身份。';

  @override
  String get exportVaultBackupTitle => '导出加密备份？';

  @override
  String get exportVaultBackupBody => '备份包含加密保险库记录和保险库头部。请妥善保管。';

  @override
  String get backupExportedSnack => '加密备份已导出。';

  @override
  String get noHostsAvailableExportSnack => '没有可导出的主机。';

  @override
  String get exportHostMetadataTitle => '导出主机元数据？';

  @override
  String get exportHostMetadataBody =>
      '导出主机名称、地址、用户名、标签、跳板主机关联和连接选项。不包含凭据和私钥材料。';

  @override
  String get hostMetadataExportedSnack => '主机元数据已导出。';

  @override
  String get hostMetadataExportFailedSnack => '无法导出主机元数据。';

  @override
  String get exportOpenSshConfigTitle => '导出 OpenSSH 配置？';

  @override
  String get exportOpenSshConfigBody =>
      '将所选主机和所需跳板主机导出为 OpenSSH 配置。不包含凭据和私钥材料。';

  @override
  String get openSshConfigExportedSnack => 'OpenSSH 配置已导出。';

  @override
  String get exportIdentityMetadataTitle => '导出身份元数据？';

  @override
  String get identityMetadataExportedSnack => '身份元数据已导出。';

  @override
  String get exportDiagnosticBundleTitle => '导出诊断日志？';

  @override
  String get exportDiagnosticBundleBody =>
      '诊断日志会被脱敏，并排除终端输出、命令、主机、用户名、路径、凭据和私钥。';

  @override
  String get diagnosticBundleExportedSnack => '诊断日志已导出。';

  @override
  String get backupOperationFailed => '备份操作失败。';

  @override
  String get diagnosticExportFailed => '无法导出诊断日志。';

  @override
  String get openSshConfigExportFailed => '无法导出 OpenSSH 配置。';

  @override
  String get identityMetadataExportFailed => '无法导出身份元数据。';

  @override
  String get importFailed => '导入失败。';

  @override
  String get importEncryptedBackupTitle => '导入加密备份？';

  @override
  String get importEncryptedBackupBody => '这会替换本地保险库头部，并合并所选备份中的加密记录。';

  @override
  String get backupImportedSnack => '加密备份已导入。';

  @override
  String get noImportableOpenSshHostsSnack => '没有找到可导入的 OpenSSH 主机。';

  @override
  String openSshHostsImportedSnack(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已导入 $count 台主机。',
      one: '已导入 1 台主机。',
    );
    return '$_temp0';
  }

  @override
  String openSshHostsImportedSkippedSnack(num count, num skipped) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已导入 $count 台主机，跳过 $skipped 台。',
      one: '已导入 1 台主机，跳过 $skipped 台。',
    );
    return '$_temp0';
  }

  @override
  String get importKnownHostsTitle => '导入 known_hosts？';

  @override
  String get importKnownHostsBody =>
      'Serlink 会导入与现有主机的主机名和端口匹配的指纹。主机名和指纹会保存为加密保险库记录。';

  @override
  String knownHostsImportedSnack(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已导入 $count 个指纹。',
      one: '已导入 1 个指纹。',
    );
    return '$_temp0';
  }

  @override
  String knownHostsImportedUnmatchedSnack(num count, num unmatched) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已导入 $count 个指纹，$unmatched 个未匹配。',
      one: '已导入 1 个指纹，$unmatched 个未匹配。',
    );
    return '$_temp0';
  }

  @override
  String identityImportedSnack(String name) {
    return '已导入 $name。';
  }

  @override
  String get importOpenSshConfigTitle => '导入 OpenSSH 配置？';

  @override
  String openSshConfigHostsReady(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 台主机可导入。',
      one: '1 台主机可导入。',
    );
    return '$_temp0';
  }

  @override
  String openSshConfigHostsReadySkipped(num count, num skipped) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 台主机可导入，$skipped 台已跳过。',
      one: '1 台主机可导入，$skipped 台已跳过。',
    );
    return '$_temp0';
  }

  @override
  String get importWarningsTitle => '导入警告';

  @override
  String moreWarnings(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '还有 $count 条警告。',
      one: '还有 1 条警告。',
    );
    return '$_temp0';
  }

  @override
  String certificateDefaultName(String comment) {
    return '证书 $comment';
  }

  @override
  String get importOpenSshCertificateTitle => '导入 OpenSSH 证书？';

  @override
  String get importAlgorithmLabel => '算法';

  @override
  String get importCommentLabel => '备注';

  @override
  String get passphraseWhitespaceError => '密码短语不能有首尾空格。';

  @override
  String get exportFieldHostnames => '主机名';

  @override
  String get exportFieldUsernames => '用户名';

  @override
  String get exportFieldPorts => '端口';

  @override
  String get exportFieldJumpHostAliases => '跳板主机别名';

  @override
  String get exportFieldConnectionSettings => '连接设置';

  @override
  String get exportFieldDisplayNames => '显示名称';

  @override
  String get exportFieldUsernameHints => '用户名提示';

  @override
  String get exportFieldPublicKeyFingerprints => '公钥指纹';

  @override
  String get exportFieldCertificatePrincipals => '证书主体';

  @override
  String get cancelAction => '取消';

  @override
  String get selectAction => '选择';

  @override
  String get searchAction => '搜索';
}
