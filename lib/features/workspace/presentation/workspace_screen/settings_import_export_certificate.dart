part of '../workspace_screen.dart';

Future<OpenSshCertificateImportDraft?> _showOpenSshCertificateImportDialog(
  BuildContext context, {
  required OpenSshCertificateImportDraft draft,
  required OpenSshCertificateImportPreview preview,
}) {
  return showDialog<OpenSshCertificateImportDraft>(
    context: context,
    barrierDismissible: false,
    builder: (context) =>
        _OpenSshCertificateImportDialog(draft: draft, preview: preview),
  );
}

class _OpenSshCertificateImportDialog extends StatefulWidget {
  const _OpenSshCertificateImportDialog({
    required this.draft,
    required this.preview,
  });

  final OpenSshCertificateImportDraft draft;
  final OpenSshCertificateImportPreview preview;

  @override
  State<_OpenSshCertificateImportDialog> createState() =>
      _OpenSshCertificateImportDialogState();
}

class _OpenSshCertificateImportDialogState
    extends State<_OpenSshCertificateImportDialog> {
  late final TextEditingController _displayNameController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passphraseController;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final comment = widget.preview.comment?.trim();
    _displayNameController = TextEditingController(
      text: comment == null || comment.isEmpty ? '' : 'Certificate $comment',
    );
    _usernameController = TextEditingController();
    _passphraseController = TextEditingController();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _usernameController.dispose();
    _passphraseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final warnings = widget.preview.warnings.take(3).toList(growable: false);
    return AlertDialog(
      title: const Text('Import OpenSSH certificate?'),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ImportPreviewLine(
              label: 'Algorithm',
              value: widget.preview.algorithm,
            ),
            if (widget.preview.comment != null)
              _ImportPreviewLine(
                label: 'Comment',
                value: widget.preview.comment!,
              ),
            if (warnings.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final warning in warnings)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    warning.message,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ],
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('openssh-cert-display-name-field'),
              controller: _displayNameController,
              decoration: const InputDecoration(
                labelText: 'Display name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey('openssh-cert-username-field'),
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'Username hint',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey('openssh-cert-passphrase-field'),
              controller: _passphraseController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Private key passphrase',
                border: OutlineInputBorder(),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _confirm, child: const Text('Import')),
      ],
    );
  }

  void _confirm() {
    final passphrase = _passphraseController.text;
    if (passphrase.trim() != passphrase) {
      setState(() {
        _errorMessage = 'Passphrase cannot have leading or trailing spaces.';
      });
      return;
    }
    Navigator.of(context).pop(
      OpenSshCertificateImportDraft(
        privateKeyPem: widget.draft.privateKeyPem,
        certificateText: widget.draft.certificateText,
        privateKeyPassphrase: passphrase.isEmpty ? null : passphrase,
        displayName: _displayNameController.text,
        usernameHint: _usernameController.text,
      ),
    );
  }
}

class _ImportPreviewLine extends StatelessWidget {
  const _ImportPreviewLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
