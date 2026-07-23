part of '../workspace_screen.dart';

class _IdentityEditDialog extends ConsumerStatefulWidget {
  const _IdentityEditDialog({required this.identity});

  final IdentityConfig identity;

  @override
  ConsumerState<_IdentityEditDialog> createState() =>
      _IdentityEditDialogState();
}

class _IdentityEditDialogState extends ConsumerState<_IdentityEditDialog> {
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _usernameHintController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _privateKeyController = TextEditingController();
  final TextEditingController _passphraseController = TextEditingController();
  final TextEditingController _certificateController = TextEditingController();
  final TextEditingController _keyboardResponsesController =
      TextEditingController();

  bool _loadingSecret = true;
  bool _saving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _displayNameController.text = widget.identity.displayName;
    _usernameHintController.text = widget.identity.usernameHint ?? '';
    unawaited(_loadSecret());
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _usernameHintController.dispose();
    _passwordController.dispose();
    _privateKeyController.dispose();
    _passphraseController.dispose();
    _certificateController.dispose();
    _keyboardResponsesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SerlinkDialog(
      maxWidth: _adaptiveDialogWidth(context, _dialogWidthMedium),
      title: Text(l10n.credentialEditTitle),
      content: SizedBox(
        width: 560,
        child: _loadingSecret
            ? SizedBox(
                height: 132,
                child: Center(
                  child: SerlinkLoadingIndicator(
                    semanticsLabel: l10n.credentialLoadingSecretSemantics,
                  ),
                ),
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SerlinkTextField(
                      key: const ValueKey('credential-display-name-field'),
                      controller: _displayNameController,
                      decoration: InputDecoration(
                        labelText: l10n.credentialNameLabel,
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 12),
                    SerlinkTextField(
                      key: const ValueKey('credential-username-hint-field'),
                      controller: _usernameHintController,
                      decoration: InputDecoration(
                        labelText: l10n.credentialUsernameHintLabel,
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 12),
                    _secretFields(),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      SerlinkAlert.danger(
                        message: _errorMessage!,
                        compact: true,
                      ),
                    ],
                  ],
                ),
              ),
      ),
      actions: [
        SerlinkTextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: Text(l10n.cancelAction),
        ),
        SerlinkFilledButton(
          key: const ValueKey('credential-save-button'),
          onPressed: _loadingSecret || _saving ? null : _save,
          child: Text(_saving ? l10n.savingAction : l10n.saveAction),
        ),
      ],
    );
  }

  Widget _secretFields() {
    final l10n = context.l10n;
    return switch (widget.identity.kind) {
      IdentityKind.password => SerlinkTextField(
        key: const ValueKey('credential-password-field'),
        controller: _passwordController,
        decoration: InputDecoration(labelText: l10n.credentialPasswordLabel),
        obscureText: true,
        onSubmitted: (_) => _save(),
      ),
      IdentityKind.privateKey => _PrivateKeyFields(
        privateKeyController: _privateKeyController,
        passphraseController: _passphraseController,
        onImportKey: _importPrivateKey,
      ),
      IdentityKind.openSshCertificate => _CertificateFields(
        privateKeyController: _privateKeyController,
        passphraseController: _passphraseController,
        certificateController: _certificateController,
        onImportKey: _importPrivateKey,
        onImportCertificate: _importCertificate,
      ),
      IdentityKind.keyboardInteractive => SerlinkTextField(
        key: const ValueKey('credential-keyboard-responses-field'),
        controller: _keyboardResponsesController,
        minLines: 3,
        maxLines: 6,
        decoration: InputDecoration(
          labelText: l10n.credentialKeyboardResponsesLabel,
          helperText: l10n.credentialKeyboardResponsesHelper,
        ),
      ),
      IdentityKind.sshAgent || IdentityKind.hardwareKey => Align(
        alignment: Alignment.centerLeft,
        child: Text(l10n.credentialNoSecretMaterial),
      ),
    };
  }

  Future<void> _loadSecret() async {
    try {
      final secret = await ref
          .read(identityWriteServiceProvider)
          .readSecretMaterial(widget.identity);
      if (!mounted) {
        return;
      }
      _passwordController.text = secret?.password ?? '';
      _privateKeyController.text = secret?.privateKeyPem ?? '';
      _passphraseController.text = secret?.privateKeyPassphrase ?? '';
      _certificateController.text = secret?.openSshCertificate ?? '';
      _keyboardResponsesController.text =
          secret?.keyboardInteractiveResponses.join('\n') ?? '';
      setState(() {
        _loadingSecret = false;
      });
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingSecret = false;
        _errorMessage = context.l10n.credentialSecretLoadFailed;
      });
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _errorMessage = null;
    });
    try {
      await ref
          .read(identityWriteServiceProvider)
          .update(
            IdentityUpdateDraft(
              id: widget.identity.id,
              displayName: _displayNameController.text,
              usernameHint: _usernameHintController.text,
              password: widget.identity.kind == IdentityKind.password
                  ? _passwordController.text
                  : null,
              privateKeyPem:
                  widget.identity.kind == IdentityKind.privateKey ||
                      widget.identity.kind == IdentityKind.openSshCertificate
                  ? _privateKeyController.text
                  : null,
              privateKeyPassphrase:
                  widget.identity.kind == IdentityKind.privateKey ||
                      widget.identity.kind == IdentityKind.openSshCertificate
                  ? _passphraseController.text
                  : null,
              openSshCertificate:
                  widget.identity.kind == IdentityKind.openSshCertificate
                  ? _certificateController.text
                  : null,
              keyboardInteractiveResponses:
                  widget.identity.kind == IdentityKind.keyboardInteractive
                  ? _parseSecretLines(_keyboardResponsesController.text)
                  : null,
            ),
          );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on IdentityWriteException catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _errorMessage = error.message;
        });
      }
    } on Object {
      if (mounted) {
        setState(() {
          _saving = false;
          _errorMessage = context.l10n.credentialSaveFailed;
        });
      }
    }
  }

  Future<void> _importPrivateKey() async {
    await _importTextFile(
      controller: _privateKeyController,
      typeGroup: XTypeGroup(
        label: context.l10n.credentialSshPrivateKeyTypeLabel,
      ),
    );
  }

  Future<void> _importCertificate() async {
    await _importTextFile(
      controller: _certificateController,
      typeGroup: XTypeGroup(
        label: context.l10n.credentialOpenSshCertificateTypeLabel,
      ),
    );
  }

  Future<void> _importTextFile({
    required TextEditingController controller,
    required XTypeGroup typeGroup,
  }) async {
    final file = await ref
        .read(documentGatewayProvider)
        .pickUploadFile(acceptedTypeGroups: [typeGroup]);
    if (file == null) {
      return;
    }
    controller.text = await File(file.path).readAsString();
  }
}

class _CertificateFields extends StatelessWidget {
  const _CertificateFields({
    required this.privateKeyController,
    required this.passphraseController,
    required this.certificateController,
    required this.onImportKey,
    required this.onImportCertificate,
  });

  final TextEditingController privateKeyController;
  final TextEditingController passphraseController;
  final TextEditingController certificateController;
  final VoidCallback onImportKey;
  final VoidCallback onImportCertificate;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      children: [
        _PrivateKeyFields(
          privateKeyController: privateKeyController,
          passphraseController: passphraseController,
          onImportKey: onImportKey,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: SerlinkTextField(
                key: const ValueKey('credential-certificate-field'),
                controller: certificateController,
                minLines: 3,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: l10n.credentialCertificateLabel,
                ),
              ),
            ),
            const SizedBox(width: 8),
            SerlinkTooltip(
              message: l10n.credentialImportCertificateTooltip,
              child: SerlinkIconButton(
                key: const ValueKey('credential-import-certificate-button'),
                onPressed: onImportCertificate,
                icon: const Icon(Icons.file_open_outlined),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

List<String> _parseSecretLines(String value) {
  return [
    for (final line in value.split('\n').map((line) => line.trim()))
      if (line.isNotEmpty) line,
  ];
}
