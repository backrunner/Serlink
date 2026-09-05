part of '../workspace_screen.dart';

Future<void> _showWebDavSyncDialog(
  BuildContext context,
  WidgetRef ref,
  WebDavSyncSettings? settings,
) {
  return showSerlinkDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _WebDavSyncDialog(initialSettings: settings),
  );
}

class _WebDavSyncDialog extends ConsumerStatefulWidget {
  const _WebDavSyncDialog({required this.initialSettings});

  final WebDavSyncSettings? initialSettings;

  @override
  ConsumerState<_WebDavSyncDialog> createState() => _WebDavSyncDialogState();
}

class _WebDavSyncDialogState extends ConsumerState<_WebDavSyncDialog> {
  late final TextEditingController _endpointController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  late final TextEditingController _basePathController;
  late bool _enabled;
  late bool _allowInsecureHttp;
  var _saving = false;
  String? _errorMessage;

  bool get _isEditing => widget.initialSettings != null;

  @override
  void initState() {
    super.initState();
    final settings = widget.initialSettings;
    _endpointController = TextEditingController(
      text: settings?.endpoint.toString() ?? '',
    );
    _usernameController = TextEditingController(text: settings?.username ?? '');
    _passwordController = TextEditingController();
    _basePathController = TextEditingController(
      text: settings?.basePath ?? '/serlink',
    );
    _enabled = settings?.enabled ?? true;
    _allowInsecureHttp = settings?.allowInsecureHttp ?? false;
  }

  @override
  void dispose() {
    _endpointController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _basePathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SerlinkDialog(
      maxWidth: _adaptiveDialogWidth(context, _dialogWidthMedium),
      title: Text(l10n.webDavSyncTitle),
      content: SizedBox(
        width: 560,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.72,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SerlinkTextField(
                  key: const ValueKey('webdav-endpoint-field'),
                  controller: _endpointController,
                  decoration: InputDecoration(
                    labelText: l10n.webDavEndpointLabel,
                    hintText: l10n.webDavEndpointHint,
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                SerlinkTextField(
                  key: const ValueKey('webdav-username-field'),
                  controller: _usernameController,
                  decoration: InputDecoration(
                    labelText: l10n.webDavUsernameLabel,
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                SerlinkTextField(
                  key: const ValueKey('webdav-password-field'),
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: _isEditing
                        ? l10n.webDavPasswordKeepLabel
                        : l10n.webDavPasswordLabel,
                  ),
                  obscureText: true,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                SerlinkTextField(
                  key: const ValueKey('webdav-base-path-field'),
                  controller: _basePathController,
                  decoration: InputDecoration(
                    labelText: l10n.webDavBasePathLabel,
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _save(),
                ),
                const SizedBox(height: 8),
                _WebDavOptionRow(
                  key: const ValueKey('webdav-enabled-row'),
                  value: _enabled,
                  label: l10n.webDavEnableTitle,
                  mobileLabel: l10n.webDavEnableMobileLabel,
                  onChanged: (value) {
                    setState(() {
                      _enabled = value;
                    });
                  },
                ),
                const SizedBox(height: 8),
                _WebDavOptionRow(
                  key: const ValueKey('webdav-allow-http-row'),
                  value: _allowInsecureHttp,
                  label: l10n.webDavAllowHttpTitle,
                  mobileLabel: l10n.webDavAllowHttpMobileLabel,
                  onChanged: (value) {
                    setState(() {
                      _allowInsecureHttp = value;
                    });
                  },
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 8),
                  SerlinkAlert.danger(message: _errorMessage!, compact: true),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        if (_isEditing)
          SerlinkTextButton(
            onPressed: _saving ? null : _delete,
            child: Text(l10n.removeAction),
          ),
        SerlinkTextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.cancelAction),
        ),
        SerlinkFilledButton(
          key: const ValueKey('webdav-save-button'),
          onPressed: _saving ? null : _save,
          child: Text(_saving ? l10n.savingAction : l10n.saveAction),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    var allowInsecureHttp = _allowInsecureHttp;
    final endpoint = Uri.tryParse(_endpointController.text.trim());
    if (endpoint?.scheme == 'http' && !allowInsecureHttp) {
      final confirmed = await _confirmDialog(
        context,
        title: l10n.webDavUseHttpTitle,
        body: l10n.webDavUseHttpBody,
        confirmLabel: l10n.webDavAllowHttpAction,
        destructive: true,
      );
      if (!confirmed) {
        return;
      }
      allowInsecureHttp = true;
      if (mounted) {
        setState(() {
          _allowInsecureHttp = true;
        });
      }
    }

    setState(() {
      _saving = true;
      _errorMessage = null;
    });
    try {
      final draft = WebDavSyncSettingsDraft(
        endpoint: _endpointController.text,
        username: _usernameController.text,
        password: _passwordController.text,
        basePath: _basePathController.text,
        allowInsecureHttp: allowInsecureHttp,
        enabled: _enabled,
      );
      if (_enabled) {
        final provider = await ref
            .read(syncSettingsServiceProvider)
            .buildWebDavProviderFromDraft(draft);
        await ensureRemoteSyncCompatibleForEnable(provider);
        final discovery = await RemoteVaultDiscoveryService(
          provider,
        ).discover();
        if (discovery != null && _isRemoteVaultMismatch(discovery)) {
          final handled = await _resolveRemoteVaultMismatch(
            draft,
            provider,
            discovery,
          );
          if (!handled) {
            if (mounted) {
              setState(() {
                _saving = false;
              });
            }
            return;
          }
          return;
        }
      }
      await ref.read(syncSettingsServiceProvider).saveWebDav(draft);
      ref.invalidate(webDavSyncSettingsProvider);
      if (_enabled) {
        ref.read(autoSyncControllerProvider.notifier).requestSync();
      }
      if (mounted) {
        Navigator.of(context).pop();
        _showSnackBar(context, l10n.webDavSavedSnack);
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _errorMessage = _syncSettingsErrorMessage(l10n, error);
        });
      }
    }
  }

  bool _isRemoteVaultMismatch(RemoteVaultDiscovery discovery) {
    final localHeader = ref
        .read(vaultSessionControllerProvider.notifier)
        .service
        .header;
    return localHeader == null ||
        syncVaultId(discovery.header) != syncVaultId(localHeader);
  }

  /// Handles a WebDAV remote that already holds a different vault. Returns
  /// true when the chosen resolution ran to completion; false when the user
  /// cancelled and the save must be aborted.
  Future<bool> _resolveRemoteVaultMismatch(
    WebDavSyncSettingsDraft draft,
    SyncProvider provider,
    RemoteVaultDiscovery discovery,
  ) async {
    final action = await _showRemoteVaultMismatchDialog();
    if (action == null || !mounted) {
      return false;
    }
    final l10n = context.l10n;
    final confirmed = await switch (action) {
      _WebDavRemoteVaultMismatchAction.replaceRemote => _confirmDialog(
        context,
        title: l10n.webDavReplaceRemoteConfirmTitle,
        body: l10n.webDavReplaceRemoteConfirmBody,
        confirmLabel: l10n.replaceAction,
        destructive: true,
      ),
      _WebDavRemoteVaultMismatchAction.restoreLocal => _confirmDialog(
        context,
        title: l10n.webDavRestoreFromRemoteConfirmTitle,
        body: l10n.webDavRestoreFromRemoteConfirmBody,
        confirmLabel: l10n.webDavRestoreFromRemoteAction,
        destructive: true,
      ),
    };
    if (!confirmed || !mounted) {
      return false;
    }
    // Persist settings (and the keychain password) before any rebuild or
    // adoption so follow-up sync and the post-adoption unlock can rebuild the
    // provider from stored configuration.
    await ref.read(syncSettingsServiceProvider).saveWebDav(draft);
    ref.invalidate(webDavSyncSettingsProvider);
    switch (action) {
      case _WebDavRemoteVaultMismatchAction.replaceRemote:
        await ref
            .read(syncRunServiceProvider)
            .runRepair(provider, SyncRepairAction.rebuildRemoteFromLocal);
        ref.read(autoSyncControllerProvider.notifier).requestSync();
        if (mounted) {
          Navigator.of(context).pop();
          _showSnackBar(context, l10n.webDavSavedSnack);
        }
      case _WebDavRemoteVaultMismatchAction.restoreLocal:
        await _snapshotLocalVaultBeforeAdoption();
        await ref
            .read(vaultSessionControllerProvider.notifier)
            .adoptRemoteVaultHeader(
              discovery.header,
              kind: SyncProviderKind.webDav,
              notice: VaultSessionNotice.webDavRemoteVaultAdopted,
            );
        if (mounted) {
          Navigator.of(context).pop();
        }
    }
    return true;
  }

  Future<void> _snapshotLocalVaultBeforeAdoption() async {
    try {
      await (await ref.read(
        automaticVaultBackupServiceProvider.future,
      )).createSnapshot(reason: 'before-remote-restore');
    } on Object {
      // The automatic backup is a safety net only; a snapshot failure must not
      // block an explicit, confirmed restore from the remote vault.
    }
  }

  Future<_WebDavRemoteVaultMismatchAction?> _showRemoteVaultMismatchDialog() {
    return showSerlinkDialog<_WebDavRemoteVaultMismatchAction>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final l10n = context.l10n;
        return SerlinkDialog(
          maxWidth: _adaptiveDialogWidth(context, _dialogWidthPrompt),
          title: Text(l10n.webDavRemoteVaultMismatchTitle),
          content: SerlinkAlert.warning(
            message: l10n.webDavRemoteVaultMismatchBody,
          ),
          actions: [
            SerlinkTextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.cancelAction),
            ),
            SerlinkTextButton(
              key: const ValueKey('webdav-mismatch-restore-button'),
              onPressed: () => Navigator.of(
                context,
              ).pop(_WebDavRemoteVaultMismatchAction.restoreLocal),
              child: Text(l10n.webDavRestoreFromRemoteAction),
            ),
            SerlinkFilledButton.danger(
              key: const ValueKey('webdav-mismatch-replace-button'),
              onPressed: () => Navigator.of(
                context,
              ).pop(_WebDavRemoteVaultMismatchAction.replaceRemote),
              child: Text(l10n.webDavReplaceRemoteAction),
            ),
          ],
        );
      },
    );
  }

  Future<void> _delete() async {
    final l10n = context.l10n;
    final confirmed = await _confirmDialog(
      context,
      title: l10n.webDavRemoveTitle,
      body: l10n.webDavRemoveBody,
      confirmLabel: l10n.removeAction,
      destructive: true,
    );
    if (!confirmed) {
      return;
    }
    setState(() {
      _saving = true;
      _errorMessage = null;
    });
    try {
      await ref.read(syncSettingsServiceProvider).deleteWebDav();
      ref.invalidate(webDavSyncSettingsProvider);
      if (mounted) {
        Navigator.of(context).pop();
        _showSnackBar(context, l10n.webDavRemovedSnack);
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _errorMessage = _syncSettingsErrorMessage(l10n, error);
        });
      }
    }
  }
}

enum _WebDavRemoteVaultMismatchAction { replaceRemote, restoreLocal }

class _WebDavOptionRow extends StatelessWidget {
  const _WebDavOptionRow({
    super.key,
    required this.value,
    required this.label,
    required this.mobileLabel,
    required this.onChanged,
  });

  final bool value;
  final String label;
  final String mobileLabel;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final mobile = MediaQuery.sizeOf(context).width < 560;

    return SerlinkPressable(
      onTap: () => onChanged(!value),
      borderRadius: SerlinkRadii.control,
      hoverColor: t.accentPrimary.withValues(alpha: 0.06),
      pressedColor: t.accentPrimary.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: SerlinkSpacing.md,
          vertical: SerlinkSpacing.sm,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                mobile ? mobileLabel : label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: t.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: SerlinkSpacing.md),
            SerlinkSwitch(
              value: value,
              onChanged: onChanged,
              scale: mobile ? 0.6 : 0.72,
            ),
          ],
        ),
      ),
    );
  }
}
