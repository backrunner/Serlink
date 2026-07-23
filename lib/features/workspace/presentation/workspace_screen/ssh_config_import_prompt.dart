part of '../workspace_screen.dart';

class _SshConfigImportPromptGate extends ConsumerStatefulWidget {
  const _SshConfigImportPromptGate({required this.child});

  final Widget child;

  @override
  ConsumerState<_SshConfigImportPromptGate> createState() =>
      _SshConfigImportPromptGateState();
}

class _SshConfigImportPromptGateState
    extends ConsumerState<_SshConfigImportPromptGate> {
  String? _scheduledPromptKey;
  Object? _scheduledFailure;
  bool _showingPrompt = false;

  @override
  Widget build(BuildContext context) {
    final startup = ref.watch(macOsSshConfigStartupProvider);
    final scan = startup.scan;
    final error = startup.error;
    if (startup.phase == MacOsSshConfigStartupPhase.failed && error != null) {
      _scheduleFailure(error);
    }
    if (startup.hasPendingPrompt && scan != null) {
      _schedulePrompt(scan);
    }
    return widget.child;
  }

  void _scheduleFailure(Object error) {
    if (identical(_scheduledFailure, error)) {
      return;
    }
    _scheduledFailure = error;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _showSnackBar(context, _importErrorMessage(context.l10n, error));
      ref.read(macOsSshConfigStartupProvider.notifier).dismissFailure();
      _scheduledFailure = null;
    });
  }

  void _schedulePrompt(MacOsSshConfigStartupScan scan) {
    if (_showingPrompt || _scheduledPromptKey == scan.promptKey) {
      return;
    }
    _scheduledPromptKey = scan.promptKey;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_showPrompt(scan));
    });
  }

  Future<void> _showPrompt(MacOsSshConfigStartupScan scan) async {
    if (_showingPrompt) {
      return;
    }
    _showingPrompt = true;
    try {
      final decision = await _showSshConfigStartupImportDialog(context, scan);
      if (!mounted) {
        return;
      }
      if (decision == null) {
        await ref.read(macOsSshConfigStartupProvider.notifier).dismissPending();
        return;
      }
      final result = await ref
          .read(macOsSshConfigStartupProvider.notifier)
          .importPending(enableAutoImport: decision.enableAutoImport);
      if (mounted && result != null) {
        final l10n = context.l10n;
        _showSnackBar(
          context,
          result.hostsSkipped == 0
              ? l10n.openSshHostsImportedSnack(result.hostsCreated)
              : l10n.openSshHostsImportedSkippedSnack(
                  result.hostsCreated,
                  result.hostsSkipped,
                ),
        );
      }
    } on Object catch (error) {
      if (mounted) {
        _showSnackBar(context, _importErrorMessage(context.l10n, error));
      }
    } finally {
      _showingPrompt = false;
      _scheduledPromptKey = null;
    }
  }
}

class _SshConfigStartupPromptDecision {
  const _SshConfigStartupPromptDecision({required this.enableAutoImport});

  final bool enableAutoImport;
}

Future<_SshConfigStartupPromptDecision?> _showSshConfigStartupImportDialog(
  BuildContext context,
  MacOsSshConfigStartupScan scan,
) {
  var enableAutoImport = false;
  return showSerlinkDialog<_SshConfigStartupPromptDecision>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          return SerlinkDialog(
            maxWidth: _adaptiveDialogWidth(context, _dialogWidthPrompt),
            title: Text(context.l10n.sshConfigNewHostsTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  context.l10n.sshConfigNewHostsBody(
                    scan.importPreview.entries.length,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.l10n.sshConfigAutoImportFutureTitle,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _SettingsSwitch(
                      key: const ValueKey(
                        'ssh-config-prompt-auto-import-switch',
                      ),
                      semanticsLabel:
                          context.l10n.settingsSshConfigAutoImportSemantics,
                      value: enableAutoImport,
                      onChanged: (value) {
                        setState(() {
                          enableAutoImport = value;
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              SerlinkTextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(context.l10n.skipAction),
              ),
              SerlinkFilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(
                  _SshConfigStartupPromptDecision(
                    enableAutoImport: enableAutoImport,
                  ),
                ),
                child: Text(context.l10n.importAction),
              ),
            ],
          );
        },
      );
    },
  );
}
