part of '../workspace_screen.dart';

Future<bool> _confirmDialog(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Theme.of(context).colorScheme.onError,
                  )
                : null,
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return result ?? false;
}

Future<TransferConflictAction?> _showTransferConflictDialog(
  BuildContext context, {
  required String title,
  required String body,
  required String replaceLabel,
}) {
  return showDialog<TransferConflictAction>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(TransferConflictAction.skip),
            child: const Text('Skip'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(TransferConflictAction.rename),
            child: const Text('Rename'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(TransferConflictAction.replace),
            child: Text(replaceLabel),
          ),
        ],
      );
    },
  );
}

String _backupErrorMessage(Object error) {
  if (error is VaultException) {
    return error.message;
  }
  return 'Backup operation failed.';
}

String _diagnosticErrorMessage(Object error) {
  return 'Diagnostic bundle could not be exported.';
}

String _openSshConfigExportErrorMessage(Object error) {
  return 'OpenSSH config could not be exported.';
}

String _identityMetadataExportErrorMessage(Object error) {
  return 'Identity metadata could not be exported.';
}

String _importErrorMessage(Object error) {
  if (error is OpenSshConfigImportException) {
    return error.message;
  }
  if (error is OpenSshCertificateImportException) {
    return error.message;
  }
  if (error is VaultException) {
    return error.message;
  }
  return 'Import failed.';
}

String? _defaultImportUsername() {
  final value =
      Platform.environment['USER'] ?? Platform.environment['USERNAME'];
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

void _showSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(212, 0, 16, 16),
        content: Text(message),
      ),
    );
}

class _PlaceholderSurface extends StatelessWidget {
  const _PlaceholderSurface({
    required this.title,
    required this.body,
    this.action,
  });

  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}
