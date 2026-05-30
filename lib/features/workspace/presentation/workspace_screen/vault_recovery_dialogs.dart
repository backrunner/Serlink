part of '../workspace_screen.dart';

class _RecoveryKeyDialogGate extends ConsumerStatefulWidget {
  const _RecoveryKeyDialogGate({
    required this.recoveryKey,
    required this.child,
  });

  final VaultRecoveryKey recoveryKey;
  final Widget child;

  @override
  ConsumerState<_RecoveryKeyDialogGate> createState() =>
      _RecoveryKeyDialogGateState();
}

class _RecoveryKeyDialogGateState
    extends ConsumerState<_RecoveryKeyDialogGate> {
  String? _shownRecoveryKey;

  @override
  void initState() {
    super.initState();
    _scheduleDialog();
  }

  @override
  void didUpdateWidget(_RecoveryKeyDialogGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleDialog();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }

  void _scheduleDialog() {
    final recoveryKey = widget.recoveryKey.value;
    if (_shownRecoveryKey == recoveryKey) {
      return;
    }
    _shownRecoveryKey = recoveryKey;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _showRecoveryKeyDialog(recoveryKey);
    });
  }

  Future<void> _showRecoveryKeyDialog(String recoveryKey) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _RecoveryKeyDialog(recoveryKey: recoveryKey),
    );
    if (!mounted) {
      return;
    }
    ref.read(vaultSessionControllerProvider.notifier).dismissRecoveryKey();
  }
}

class _RecoveryKeyDialog extends StatefulWidget {
  const _RecoveryKeyDialog({required this.recoveryKey});

  final String recoveryKey;

  @override
  State<_RecoveryKeyDialog> createState() => _RecoveryKeyDialogState();
}

class _RecoveryKeyDialogState extends State<_RecoveryKeyDialog> {
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
      actionsPadding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: serlinkAccentGradient(context.tokens),
              borderRadius: SerlinkRadii.control,
              boxShadow: [
                BoxShadow(
                  color: context.tokens.accentPrimary.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              Icons.key_outlined,
              size: 20,
              color: context.tokens.onAccent,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(child: Text('Recovery Key')),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Save this key before continuing.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.errorContainer.withValues(alpha: 0.44),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: scheme.error.withValues(alpha: 0.22)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: scheme.error,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'This key is shown only once. If it is lost, Serlink cannot retrieve it for you.',
                        key: const ValueKey('recovery-key-warning'),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onErrorContainer,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.64),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: SelectableText(
                  widget.recoveryKey,
                  key: const ValueKey('recovery-key-value'),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontFamily: 'monospace',
                    height: 1.35,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        OutlinedButton.icon(
          key: const ValueKey('recovery-key-copy-button'),
          onPressed: _copyRecoveryKey,
          icon: Icon(_copied ? Icons.check_rounded : Icons.copy_rounded),
          label: Text(_copied ? 'Copied' : 'Copy Recovery Key'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('I have saved it'),
        ),
      ],
    );
  }

  Future<void> _copyRecoveryKey() async {
    await Clipboard.setData(ClipboardData(text: widget.recoveryKey));
    if (!mounted) {
      return;
    }
    setState(() {
      _copied = true;
    });
  }
}

class _RecoveryCodeDialog extends ConsumerStatefulWidget {
  const _RecoveryCodeDialog();

  @override
  ConsumerState<_RecoveryCodeDialog> createState() =>
      _RecoveryCodeDialogState();
}

Future<void> _showVaultRecoveryCodeDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => const _RecoveryCodeDialog(),
  );
}

class _RecoveryCodeDialogState extends ConsumerState<_RecoveryCodeDialog> {
  final TextEditingController _recoveryCodeController = TextEditingController();
  final TextEditingController _resetConfirmationController =
      TextEditingController();

  var _resetMode = false;
  var _busy = false;
  String? _errorMessage;

  @override
  void dispose() {
    _recoveryCodeController.dispose();
    _resetConfirmationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final canReset =
        _resetConfirmationController.text.trim() ==
        _vaultResetConfirmationPhrase;
    final availableWidth = math.max(
      320.0,
      MediaQuery.sizeOf(context).width - 96,
    );
    final dialogWidth = math.min(680.0, availableWidth);

    return AlertDialog(
      title: Text(_resetMode ? 'Reset Vault' : 'Recovery Code'),
      content: SizedBox(
        width: dialogWidth,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.72,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _resetMode
                      ? 'Reset only if you cannot unlock this vault with your passphrase or recovery code.'
                      : 'Enter your recovery code to unlock this vault.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                if (_resetMode)
                  _VaultResetConfirmationSection(
                    controller: _resetConfirmationController,
                    onChanged: (_) => setState(() {
                      _errorMessage = null;
                    }),
                  )
                else
                  TextField(
                    key: const ValueKey('vault-recovery-code-field'),
                    controller: _recoveryCodeController,
                    autofocus: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    keyboardType: TextInputType.visiblePassword,
                    textInputAction: TextInputAction.done,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(fontFamily: 'monospace'),
                    decoration: const InputDecoration(
                      labelText: 'Recovery code',
                      helperText: 'Paste the full recovery code.',
                      prefixIcon: Icon(Icons.key_outlined, size: 19),
                    ),
                    onSubmitted: (_) => _unlockWithRecoveryCode(),
                  ),
                _VaultErrorText(message: _errorMessage),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        if (_resetMode)
          TextButton(
            key: const ValueKey('vault-recovery-code-return-button'),
            onPressed: _busy
                ? null
                : () => setState(() {
                    _resetMode = false;
                    _errorMessage = null;
                  }),
            child: const Text('Use recovery code'),
          )
        else
          TextButton(
            key: const ValueKey('vault-reset-entry-button'),
            onPressed: _busy
                ? null
                : () => setState(() {
                    _resetMode = true;
                    _errorMessage = null;
                  }),
            style: TextButton.styleFrom(foregroundColor: scheme.error),
            child: const Text('Reset vault'),
          ),
        if (_resetMode)
          FilledButton(
            key: const ValueKey('vault-reset-confirm-button'),
            onPressed: !_busy && canReset ? _resetVault : null,
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
              disabledBackgroundColor: scheme.error.withValues(alpha: 0.22),
              disabledForegroundColor: scheme.error.withValues(alpha: 0.82),
            ),
            child: _busy
                ? _DialogButtonSpinner(color: scheme.onError)
                : const Text('Reset Vault Permanently'),
          )
        else
          FilledButton(
            key: const ValueKey('vault-recovery-unlock-button'),
            onPressed: _busy ? null : _unlockWithRecoveryCode,
            child: _busy
                ? _DialogButtonSpinner(color: scheme.onPrimary)
                : const Text('Unlock'),
          ),
      ],
    );
  }

  Future<void> _unlockWithRecoveryCode() async {
    final recoveryCode = _normalizedRecoveryCode(_recoveryCodeController.text);
    if (recoveryCode.isEmpty) {
      setState(() {
        _errorMessage = 'Enter a recovery code to continue.';
      });
      return;
    }
    setState(() {
      _busy = true;
      _errorMessage = null;
    });
    final error = await ref
        .read(vaultSessionControllerProvider.notifier)
        .unlockWithRecoveryCode(recoveryCode: recoveryCode);
    if (!mounted) {
      return;
    }
    if (error == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _busy = false;
      _errorMessage = error;
    });
  }

  Future<void> _resetVault() async {
    if (_resetConfirmationController.text.trim() !=
        _vaultResetConfirmationPhrase) {
      setState(() {
        _errorMessage = 'Type $_vaultResetConfirmationPhrase to confirm reset.';
      });
      return;
    }
    setState(() {
      _busy = true;
      _errorMessage = null;
    });
    final error = await ref
        .read(vaultSessionControllerProvider.notifier)
        .resetVault();
    if (!mounted) {
      return;
    }
    if (error == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _busy = false;
      _errorMessage = error;
    });
  }
}

class _VaultResetConfirmationSection extends StatelessWidget {
  const _VaultResetConfirmationSection({
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _VaultResetWarning(),
        const SizedBox(height: 14),
        TextField(
          key: const ValueKey('vault-reset-confirmation-field'),
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontFamily: 'monospace',
            fontWeight: FontWeight.w700,
          ),
          decoration: InputDecoration(
            labelText: 'Type $_vaultResetConfirmationPhrase',
            helperText: 'The phrase is case-sensitive and required to reset.',
            prefixIcon: const Icon(
              Icons.report_gmailerrorred_outlined,
              size: 19,
            ),
          ),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _VaultResetWarning extends StatelessWidget {
  const _VaultResetWarning();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.surfaceSunken,
        borderRadius: SerlinkRadii.dialog,
        border: Border.all(color: scheme.error.withValues(alpha: 0.38)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.warning_amber_rounded, color: scheme.error, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'This is permanent on this device',
                    style: textTheme.titleSmall?.copyWith(
                      color: t.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const _VaultResetWarningLine(
                    text:
                        'Encrypted hosts, identities, snippets, transfer history, sync settings, and recovery data will be deleted.',
                  ),
                  const SizedBox(height: 6),
                  const _VaultResetWarningLine(
                    text:
                        'Reset does not recover your passphrase or reveal existing secrets.',
                  ),
                  const SizedBox(height: 6),
                  const _VaultResetWarningLine(
                    text:
                        'You will need a backup or a new vault before continuing.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VaultResetWarningLine extends StatelessWidget {
  const _VaultResetWarningLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = context.tokens;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 7),
          child: Icon(Icons.circle, size: 5, color: scheme.error),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: t.textSecondary,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _DialogButtonSpinner extends StatelessWidget {
  const _DialogButtonSpinner({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 18,
      child: CircularProgressIndicator(
        strokeWidth: 2.2,
        valueColor: AlwaysStoppedAnimation(color),
      ),
    );
  }
}

String _normalizedRecoveryCode(String value) {
  return value.trim().replaceAll(RegExp(r'\s+'), '');
}
