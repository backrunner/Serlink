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
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.key_outlined,
              size: 20,
              color: scheme.onPrimaryContainer,
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

class _VaultAccessSurface extends ConsumerStatefulWidget {
  const _VaultAccessSurface({this.session, this.error});

  final VaultSessionState? session;
  final Object? error;

  @override
  ConsumerState<_VaultAccessSurface> createState() =>
      _VaultAccessSurfaceState();
}

class _VaultAccessSurfaceState extends ConsumerState<_VaultAccessSurface> {
  final TextEditingController _passphraseController = TextEditingController();
  String? _localErrorMessage;

  @override
  void dispose() {
    _passphraseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(vaultSessionControllerProvider);
    final session = asyncState.value ?? widget.session;
    final isInitializing = session?.vaultState == VaultState.uninitialized;
    final recoveryKey = session?.recoveryKey;
    final errorMessage =
        _localErrorMessage ??
        session?.failureMessage ??
        (asyncState.hasError ? asyncState.error.toString() : null) ??
        widget.error?.toString();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isInitializing ? 'Create Vault' : 'Unlock Vault',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              TextField(
                key: const ValueKey('vault-passphrase-field'),
                controller: _passphraseController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: isInitializing ? 'New passphrase' : 'Passphrase',
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => _submit(isInitializing),
              ),
              const SizedBox(height: 12),
              FilledButton(
                key: const ValueKey('vault-submit-button'),
                onPressed: asyncState.isLoading
                    ? null
                    : () => _submit(isInitializing),
                child: Text(isInitializing ? 'Create Vault' : 'Unlock'),
              ),
              if (!isInitializing && session?.localUnlockAvailable == true) ...[
                const SizedBox(height: 8),
                OutlinedButton(
                  key: const ValueKey('vault-local-unlock-button'),
                  onPressed: asyncState.isLoading
                      ? null
                      : () => ref
                            .read(vaultSessionControllerProvider.notifier)
                            .unlockWithLocalKey(),
                  child: const Text('Unlock with device'),
                ),
              ],
              if (errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  errorMessage,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              if (recoveryKey != null) ...[
                const SizedBox(height: 20),
                SelectableText(recoveryKey.value),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => ref
                      .read(vaultSessionControllerProvider.notifier)
                      .dismissRecoveryKey(),
                  child: const Text('Done'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _submit(bool isInitializing) {
    final passphrase = _passphraseController.text;
    if (passphrase.isEmpty) {
      setState(() {
        _localErrorMessage = 'Enter a vault passphrase to continue.';
      });
      return;
    }
    setState(() {
      _localErrorMessage = null;
    });
    if (isInitializing) {
      ref
          .read(vaultSessionControllerProvider.notifier)
          .initialize(passphrase: passphrase);
    } else {
      ref
          .read(vaultSessionControllerProvider.notifier)
          .unlock(passphrase: passphrase);
    }
  }
}
