part of '../workspace_screen.dart';

Future<OpenSshCertificateImportDraft?> _showOpenSshCertificateImportDialog(
  BuildContext context, {
  required OpenSshCertificateImportDraft draft,
  required OpenSshCertificateImportPreview preview,
}) {
  return showSerlinkDialog<OpenSshCertificateImportDraft>(
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
  var _controllersInitialized = false;
  String? _errorMessage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controllersInitialized) {
      return;
    }
    final comment = widget.preview.comment?.trim();
    _displayNameController = TextEditingController(
      text: comment == null || comment.isEmpty
          ? ''
          : context.l10n.certificateDefaultName(comment),
    );
    _usernameController = TextEditingController();
    _passphraseController = TextEditingController();
    _controllersInitialized = true;
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
    final l10n = context.l10n;
    final warnings = widget.preview.warnings.take(3).toList(growable: false);
    return SerlinkDialog(
      maxWidth: _adaptiveDialogWidth(context, _dialogWidthMedium),
      title: Text(l10n.importOpenSshCertificateTitle),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ImportPreviewLine(
              label: l10n.importAlgorithmLabel,
              value: widget.preview.algorithm,
            ),
            if (widget.preview.comment != null)
              _ImportPreviewLine(
                label: l10n.importCommentLabel,
                value: widget.preview.comment!,
              ),
            if (warnings.isNotEmpty) ...[
              const SizedBox(height: 8),
              SerlinkAlert.warning(
                title: l10n.importWarningsTitle,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < warnings.length; i++) ...[
                      if (i > 0) const SizedBox(height: 4),
                      Text(
                        warnings[i].message,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.tokens.textSecondary,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            SerlinkTextField(
              key: const ValueKey('openssh-cert-display-name-field'),
              controller: _displayNameController,
              decoration: InputDecoration(
                labelText: l10n.hostDisplayNameLabel,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            SerlinkTextField(
              key: const ValueKey('openssh-cert-username-field'),
              controller: _usernameController,
              decoration: InputDecoration(
                labelText: l10n.credentialUsernameHintLabel,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            SerlinkTextField(
              key: const ValueKey('openssh-cert-passphrase-field'),
              controller: _passphraseController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: l10n.hostKeyPassphraseLabel,
                border: OutlineInputBorder(),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              SerlinkAlert.danger(message: _errorMessage!, compact: true),
            ],
          ],
        ),
      ),
      actions: [
        SerlinkTextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancelAction),
        ),
        SerlinkFilledButton(
          onPressed: _confirm,
          child: Text(l10n.importAction),
        ),
      ],
    );
  }

  void _confirm() {
    final passphrase = _passphraseController.text;
    if (passphrase.trim() != passphrase) {
      setState(() {
        _errorMessage = context.l10n.passphraseWhitespaceError;
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
