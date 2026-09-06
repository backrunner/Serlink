part of '../workspace_screen.dart';

const int _recoveryCodePromptFailureThreshold = 2;
const String _vaultResetConfirmationPhrase = 'RESET VAULT';

class _VaultAccessSurface extends ConsumerStatefulWidget {
  const _VaultAccessSurface({this.session, this.error});

  final VaultSessionState? session;
  final Object? error;

  @override
  ConsumerState<_VaultAccessSurface> createState() =>
      _VaultAccessSurfaceState();
}

class _VaultAccessSurfaceState extends ConsumerState<_VaultAccessSurface>
    with TickerProviderStateMixin {
  final TextEditingController _passphraseController = TextEditingController();
  final FocusNode _passphraseFocusNode = FocusNode(
    debugLabel: 'vault-passphrase-field',
  );
  String? _localErrorMessage;
  VaultSessionNotice? _lastShownNotice;
  bool _didRequestInitialPassphraseFocus = false;
  bool _probingRemoteVault = false;
  bool _passphraseVisible = false;

  // Created lazily so the recovery-surface early return (which never reaches
  // the AnimatedBuilder below) does not allocate a controller, and so dispose
  // never has to create one on a deactivated widget.
  AnimationController? _shakeController;

  AnimationController get _shake => _shakeController ??= AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 480),
  );
  String? _lastShownError;

  @override
  void dispose() {
    _passphraseController.dispose();
    _passphraseFocusNode.dispose();
    _shakeController?.dispose();
    super.dispose();
  }

  void _triggerShake(String? errorMessage) {
    if (errorMessage == null || errorMessage == _lastShownError) {
      _lastShownError = errorMessage;
      return;
    }
    _lastShownError = errorMessage;
    _shake.forward(from: 0);
  }

  void _showOneShotNotice(VaultSessionNotice? notice) {
    if (notice == null) {
      _lastShownNotice = null;
      return;
    }
    if (notice == _lastShownNotice) {
      return;
    }
    _lastShownNotice = notice;
    final message = switch (notice) {
      VaultSessionNotice.cloudKitRemoteVaultAdopted =>
        context.l10n.syncICloudRemoteVaultAdoptedSnack,
      VaultSessionNotice.cloudKitRemoteVaultAdoptedAfterInitialize =>
        context.l10n.syncICloudRemoteVaultAdoptedAfterInitializeSnack,
      VaultSessionNotice.webDavRemoteVaultAdopted =>
        context.l10n.syncWebDavRemoteVaultAdoptedSnack,
    };
    _showSnackBar(context, message);
    ref.read(vaultSessionControllerProvider.notifier).dismissNotice(notice);
  }

  void _requestInitialPassphraseFocus() {
    if (_didRequestInitialPassphraseFocus ||
        _passphraseFocusNode.context == null) {
      return;
    }
    _didRequestInitialPassphraseFocus = true;
    _passphraseFocusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    final asyncState = ref.watch(vaultSessionControllerProvider);
    final session = asyncState.value ?? widget.session;
    final busy =
        (session?.isBusy ?? asyncState.isLoading) || _probingRemoteVault;
    final isInitializing = session?.vaultState == VaultState.uninitialized;
    final recoveryKey = session?.recoveryKey;
    final showRecoveryCodeAccess =
        !isInitializing &&
        (session?.unlockFailureCount ?? 0) >=
            _recoveryCodePromptFailureThreshold;
    final errorMessage =
        _localErrorMessage ??
        session?.failureMessage ??
        (asyncState.hasError ? asyncState.error.toString() : null) ??
        widget.error?.toString();

    if (session != null && !session.localDataHealthy) {
      return _VaultRecoverySurface(session: session);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _triggerShake(errorMessage);
      _showOneShotNotice(session?.notice);
      _requestInitialPassphraseFocus();
    });

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: AnimatedBuilder(
            animation: _shake,
            builder: (context, child) {
              // Damped oscillation: amplitude decays as the controller runs.
              final decay = 1 - _shake.value;
              final dx = decay * 10 * _sineShake(_shake.value);
              return Transform.translate(offset: Offset(dx, 0), child: child);
            },
            child: GlassPanel(
              elevation: 28,
              padding: const EdgeInsets.fromLTRB(32, 36, 32, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _VaultLockBadge(initializing: isInitializing),
                  const SizedBox(height: 22),
                  Text(
                    isInitializing
                        ? l10n.vaultCreateTitle
                        : l10n.vaultUnlockTitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: t.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isInitializing
                        ? l10n.vaultCreateSubtitle
                        : l10n.vaultUnlockSubtitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: t.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SerlinkTextField(
                    key: const ValueKey('vault-passphrase-field'),
                    controller: _passphraseController,
                    focusNode: _passphraseFocusNode,
                    obscureText: !_passphraseVisible,
                    keyboardType: TextInputType.visiblePassword,
                    autocorrect: false,
                    enableSuggestions: false,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: isInitializing
                          ? l10n.vaultNewPassphraseLabel
                          : l10n.vaultPassphraseLabel,
                      prefixIcon: const Icon(Icons.lock_outline, size: 19),
                      suffixIcon: SerlinkIconButton(
                        key: const ValueKey('vault-passphrase-visibility-toggle'),
                        tooltip: _passphraseVisible
                            ? l10n.hostHidePasswordTooltip
                            : l10n.hostShowPasswordTooltip,
                        onPressed: () => setState(() {
                          _passphraseVisible = !_passphraseVisible;
                        }),
                        icon: Icon(
                          _passphraseVisible
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 19,
                        ),
                      ),
                    ),
                    onSubmitted: (_) => _submit(isInitializing),
                  ),
                  const SizedBox(height: 14),
                  _VaultPrimaryButton(
                    key: const ValueKey('vault-submit-button'),
                    label: isInitializing
                        ? l10n.vaultCreateAction
                        : l10n.vaultUnlockAction,
                    loading: busy,
                    onPressed: busy ? null : () => _submit(isInitializing),
                  ),
                  if (!isInitializing &&
                      session?.localUnlockAvailable == true) ...[
                    const SizedBox(height: 10),
                    SerlinkOutlinedButton.icon(
                      key: const ValueKey('vault-local-unlock-button'),
                      onPressed: busy
                          ? null
                          : () => ref
                                .read(vaultSessionControllerProvider.notifier)
                                .unlockWithLocalKey(),
                      icon: const Icon(Icons.fingerprint, size: 19),
                      label: Text(l10n.vaultUnlockWithDeviceAction),
                    ),
                  ],
                  if (showRecoveryCodeAccess) ...[
                    const SizedBox(height: 10),
                    SerlinkTextButton.icon(
                      key: const ValueKey('vault-recovery-code-button'),
                      onPressed: busy ? null : _showRecoveryCodeDialog,
                      icon: const Icon(Icons.key_outlined, size: 19),
                      label: Text(l10n.vaultUseRecoveryCodeAction),
                    ),
                  ],
                  _VaultErrorText(message: errorMessage),
                  if (recoveryKey != null) ...[
                    const SizedBox(height: 20),
                    _RecoveryKeyValueBox(recoveryKey: recoveryKey.value),
                    const SizedBox(height: 8),
                    SerlinkOutlinedButton(
                      onPressed: () => ref
                          .read(vaultSessionControllerProvider.notifier)
                          .dismissRecoveryKey(),
                      child: Text(l10n.doneAction),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showRecoveryCodeDialog() {
    return _showVaultRecoveryCodeDialog(context);
  }

  void _submit(bool isInitializing) {
    final passphrase = _passphraseController.text;
    if (passphrase.isEmpty) {
      setState(() {
        _localErrorMessage = context.l10n.vaultPassphraseRequired;
      });
      return;
    }
    setState(() {
      _localErrorMessage = null;
    });
    if (isInitializing) {
      unawaited(_createVaultWithRemoteProbe(passphrase));
    } else {
      ref
          .read(vaultSessionControllerProvider.notifier)
          .unlock(passphrase: passphrase);
    }
  }

  /// Before creating a vault, check whether iCloud already holds one so the
  /// user can restore it instead of silently discarding the vault they just
  /// created. Probe failures fall through to normal creation.
  Future<void> _createVaultWithRemoteProbe(String passphrase) async {
    final controller = ref.read(vaultSessionControllerProvider.notifier);
    setState(() {
      _probingRemoteVault = true;
    });
    final RemoteVaultDiscovery? discovery;
    try {
      discovery = await controller.probeRemoteVaultBeforeInitialize();
    } finally {
      if (mounted) {
        setState(() {
          _probingRemoteVault = false;
        });
      }
    }
    if (!mounted) {
      return;
    }
    if (discovery == null) {
      await controller.initialize(passphrase: passphrase);
      return;
    }
    final action = await _showICloudVaultExistsDialog();
    if (!mounted || action == null) {
      return;
    }
    switch (action) {
      case _ICloudVaultExistsAction.restore:
        await controller.adoptRemoteVaultHeader(
          discovery.header,
          kind: SyncProviderKind.cloudKit,
          notice: VaultSessionNotice.cloudKitRemoteVaultAdoptedAfterInitialize,
        );
      case _ICloudVaultExistsAction.createNew:
        final confirmed = await _confirmDialog(
          context,
          title: context.l10n.vaultCreateReplaceICloudConfirmTitle,
          body: context.l10n.vaultCreateReplaceICloudConfirmBody,
          confirmLabel: context.l10n.replaceAction,
          destructive: true,
        );
        if (!mounted || !confirmed) {
          return;
        }
        await controller.initialize(passphrase: passphrase);
    }
  }

  Future<_ICloudVaultExistsAction?> _showICloudVaultExistsDialog() {
    return showSerlinkDialog<_ICloudVaultExistsAction>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final l10n = context.l10n;
        return SerlinkDialog(
          maxWidth: _adaptiveDialogWidth(context, _dialogWidthPrompt),
          title: Text(l10n.vaultCreateICloudVaultExistsTitle),
          content: SerlinkAlert.warning(
            message: l10n.vaultCreateICloudVaultExistsBody,
          ),
          actions: [
            SerlinkTextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.cancelAction),
            ),
            SerlinkTextButton(
              key: const ValueKey('icloud-vault-exists-create-button'),
              onPressed: () =>
                  Navigator.of(context).pop(_ICloudVaultExistsAction.createNew),
              child: Text(l10n.vaultCreateNewAnywayAction),
            ),
            SerlinkFilledButton(
              key: const ValueKey('icloud-vault-exists-restore-button'),
              onPressed: () =>
                  Navigator.of(context).pop(_ICloudVaultExistsAction.restore),
              child: Text(l10n.vaultCreateRestoreICloudVaultAction),
            ),
          ],
        );
      },
    );
  }
}

enum _ICloudVaultExistsAction { restore, createNew }

class _VaultRecoverySurface extends ConsumerStatefulWidget {
  const _VaultRecoverySurface({required this.session});

  final VaultSessionState session;

  @override
  ConsumerState<_VaultRecoverySurface> createState() =>
      _VaultRecoverySurfaceState();
}

class _VaultRecoverySurfaceState extends ConsumerState<_VaultRecoverySurface> {
  String? _localErrorMessage;
  bool _detailsExpanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    final session =
        ref.watch(vaultSessionControllerProvider).value ?? widget.session;
    final busy = session.isBusy;
    final status = session.recoveryStatus;
    final corruptCount = session.recordHealthReport?.corruptRecords.length ?? 0;
    final isLocalDataDamage =
        status == VaultRecoveryStatus.databaseCorrupt ||
        status == VaultRecoveryStatus.vaultHeaderInvalid;
    final showQuarantine =
        status == VaultRecoveryStatus.recordsCorrupt && corruptCount > 0;
    final showBackupRestore =
        isLocalDataDamage ||
        status == VaultRecoveryStatus.recordsCorrupt ||
        status == VaultRecoveryStatus.healthy;
    final (title, body) = switch (status) {
      VaultRecoveryStatus.databaseCorrupt ||
      VaultRecoveryStatus.vaultHeaderInvalid => (
        l10n.vaultRecoveryLocalDataTitle,
        l10n.vaultRecoveryLocalDataBody,
      ),
      VaultRecoveryStatus.recordsCorrupt => (
        l10n.vaultRecoveryRecordsDamagedTitle,
        l10n.vaultRecoveryRecordsDamagedBody(corruptCount),
      ),
      VaultRecoveryStatus.remoteCorrupt => (
        l10n.vaultRecoveryCloudSyncTitle,
        l10n.vaultRecoveryCloudSyncBody,
      ),
      VaultRecoveryStatus.healthy => (
        l10n.vaultRecoveryTitle,
        l10n.vaultRecoveryBody,
      ),
    };
    final detail = session.failureMessage;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: GlassPanel(
            elevation: 28,
            padding: const EdgeInsets.fromLTRB(32, 36, 32, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.health_and_safety_outlined,
                  size: 42,
                  color: t.accentPrimary,
                ),
                const SizedBox(height: 18),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: t.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: t.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 22),
                if (showQuarantine) ...[
                  SerlinkFilledButton.icon(
                    key: const ValueKey('vault-quarantine-records-button'),
                    onPressed: busy ? null : _quarantineCorruptRecords,
                    icon: const Icon(Icons.inventory_2_outlined, size: 19),
                    label: Text(
                      busy
                          ? context.l10n.savingAction
                          : context.l10n.vaultQuarantineRecordsAction,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                if (showBackupRestore) ...[
                  if (status == VaultRecoveryStatus.recordsCorrupt)
                    SerlinkOutlinedButton.icon(
                      key: const ValueKey('vault-restore-latest-backup-button'),
                      onPressed: busy ? null : _restoreLatestBackup,
                      icon: const Icon(Icons.restore_outlined, size: 19),
                      label: Text(context.l10n.vaultRestoreLatestBackupAction),
                    )
                  else
                    SerlinkFilledButton.icon(
                      key: const ValueKey('vault-restore-latest-backup-button'),
                      onPressed: busy ? null : _restoreLatestBackup,
                      icon: const Icon(Icons.restore_outlined, size: 19),
                      label: Text(
                        busy
                            ? context.l10n.savingAction
                            : context.l10n.vaultRestoreLatestBackupAction,
                      ),
                    ),
                  const SizedBox(height: 10),
                  SerlinkOutlinedButton.icon(
                    key: const ValueKey('vault-import-recovery-backup-button'),
                    onPressed: busy ? null : _importEncryptedBackup,
                    icon: const Icon(Icons.upload_file_outlined, size: 19),
                    label: Text(context.l10n.vaultRecoveryImportBackupAction),
                  ),
                  const SizedBox(height: 10),
                ],
                SerlinkTextButton.icon(
                  onPressed: busy
                      ? null
                      : () => _exportDiagnosticBundle(context, ref),
                  icon: const Icon(Icons.bug_report_outlined, size: 19),
                  label: Text(
                    context.l10n.dataExchangeExportDiagnosticBundleTitle,
                  ),
                ),
                const SizedBox(height: 10),
                SerlinkTextButton.danger(
                  key: const ValueKey('vault-recovery-reset-entry-button'),
                  onPressed: busy ? null : _showRecoveryCodeDialog,
                  child: Text(context.l10n.vaultResetVaultAction),
                ),
                if (detail != null) ...[
                  const SizedBox(height: 4),
                  SerlinkTextButton.icon(
                    key: const ValueKey('vault-recovery-details-toggle'),
                    onPressed: () => setState(() {
                      _detailsExpanded = !_detailsExpanded;
                    }),
                    icon: Icon(
                      _detailsExpanded ? Icons.expand_less : Icons.expand_more,
                      size: 19,
                    ),
                    label: Text(
                      _detailsExpanded
                          ? context.l10n.vaultRecoveryHideDetailsAction
                          : context.l10n.vaultRecoveryViewDetailsAction,
                    ),
                  ),
                  if (_detailsExpanded)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: SelectableText(
                        detail,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: t.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ),
                ],
                _VaultErrorText(message: _localErrorMessage),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _restoreLatestBackup() async {
    final error = await ref
        .read(vaultSessionControllerProvider.notifier)
        .restoreLatestAutomaticBackup();
    if (!mounted) {
      return;
    }
    if (error == null) {
      _showSnackBar(context, context.l10n.backupImportedSnack);
      return;
    }
    setState(() {
      _localErrorMessage = error;
    });
  }

  Future<void> _importEncryptedBackup() async {
    final document = await ref
        .read(documentGatewayProvider)
        .pickUploadFile(
          acceptedTypeGroups: const [
            XTypeGroup(
              label: 'Serlink Vault Backup',
              extensions: ['srlkvault'],
            ),
          ],
        );
    if (document == null) {
      return;
    }
    final error = await ref
        .read(vaultSessionControllerProvider.notifier)
        .restoreFromBackupBytes(await File(document.path).readAsBytes());
    if (!mounted) {
      return;
    }
    if (error == null) {
      _showSnackBar(context, context.l10n.backupImportedSnack);
      return;
    }
    setState(() {
      _localErrorMessage = error;
    });
  }

  Future<void> _quarantineCorruptRecords() async {
    final error = await ref
        .read(vaultSessionControllerProvider.notifier)
        .quarantineCorruptRecords();
    if (!mounted) {
      return;
    }
    if (error == null) {
      _showSnackBar(context, context.l10n.vaultCorruptRecordsQuarantinedSnack);
      return;
    }
    setState(() {
      _localErrorMessage = error;
    });
  }

  Future<void> _showRecoveryCodeDialog() {
    return _showVaultRecoveryCodeDialog(context);
  }
}

/// Damped sine used to make the error-shake oscillate a few times then settle.
double _sineShake(double v) {
  // 3 oscillations across the animation.
  return math.sin(v * math.pi * 6);
}

/// Compact vault badge: a small rounded gradient tile with a soft accent halo
/// that scales up and fades once on mount, while the tile springs in. One-shot
/// (plays once) so it stays friendly to `pumpAndSettle` in widget tests.
class _VaultLockBadge extends StatefulWidget {
  const _VaultLockBadge({required this.initializing});

  final bool initializing;

  @override
  State<_VaultLockBadge> createState() => _VaultLockBadgeState();
}

class _VaultLockBadgeState extends State<_VaultLockBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  late final Animation<double> _badgeScale = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, 0.6, curve: Curves.easeOutBack),
  );
  late final Animation<double> _halo = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.1, 1, curve: Curves.easeOut),
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Center(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final haloValue = _halo.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              // Soft expanding halo — no hard frame, just a glow that settles.
              Opacity(
                opacity: (1 - haloValue) * 0.5,
                child: Transform.scale(
                  scale: 0.7 + haloValue * 1.1,
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          t.accentPrimary.withValues(alpha: 0.55),
                          t.accentPrimary.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Transform.scale(
                scale: _badgeScale.value.clamp(0.0, 1.2),
                child: child,
              ),
            ],
          );
        },
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: serlinkAccentGradient(t),
            borderRadius: SerlinkRadii.dialog,
            boxShadow: [
              BoxShadow(
                color: t.accentStrong.withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(
            widget.initializing
                ? Icons.shield_moon_outlined
                : Icons.lock_rounded,
            size: 26,
            color: t.onAccent,
          ),
        ),
      ),
    );
  }
}

/// Full-width primary action with a gradient fill and inline loading spinner.
class _VaultPrimaryButton extends StatelessWidget {
  const _VaultPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: serlinkAccentGradient(t),
          borderRadius: SerlinkRadii.control,
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: t.accentStrong.withValues(alpha: 0.45),
                    blurRadius: 20,
                    offset: const Offset(0, 9),
                  ),
                ]
              : null,
        ),
        child: SerlinkPressable(
          onTap: onPressed,
          borderRadius: SerlinkRadii.control,
          hoverColor: t.onAccent.withValues(alpha: 0.06),
          pressedColor: Colors.black.withValues(alpha: 0.08),
          child: SizedBox(
            height: 46,
            child: Center(
              child: loading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        valueColor: AlwaysStoppedAnimation(t.onAccent),
                      ),
                    )
                  : Text(
                      label,
                      style: TextStyle(
                        color: t.onAccent,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Animated error line that fades/slides in below the form.
class _VaultErrorText extends StatelessWidget {
  const _VaultErrorText({required this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: message == null
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(top: 14),
              child: SerlinkAlert.danger(message: message, compact: true),
            ),
    );
  }
}
