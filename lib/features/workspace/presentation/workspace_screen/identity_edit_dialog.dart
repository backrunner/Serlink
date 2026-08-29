part of '../workspace_screen.dart';

class _IdentityEditDialog extends ConsumerStatefulWidget {
  const _IdentityEditDialog({this.identity});

  final IdentityConfig? identity;

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

  bool _loadingSecret = false;
  bool _saving = false;
  String? _errorMessage;
  IdentityKind _kind = IdentityKind.password;
  GeneratedSshKeyType _keyType = GeneratedSshKeyType.ed25519;
  GeneratedSshKeyPair? _generatedKey;
  bool _generatingKey = false;

  bool get _creating => widget.identity == null;

  @override
  void initState() {
    super.initState();
    final identity = widget.identity;
    if (identity == null) {
      return;
    }
    _kind = identity.kind;
    _loadingSecret = true;
    _displayNameController.text = identity.displayName;
    _usernameHintController.text = identity.usernameHint ?? '';
    unawaited(_loadSecret(identity));
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
      title: Text(
        _creating ? l10n.credentialAddTitle : l10n.credentialEditTitle,
      ),
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
                    if (_creating) ...[
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: SerlinkSegmentedControl<IdentityKind>(
                            key: const ValueKey('credential-kind-control'),
                            value: _kind,
                            segments: [
                              for (final kind in const [
                                IdentityKind.password,
                                IdentityKind.privateKey,
                                IdentityKind.openSshCertificate,
                                IdentityKind.keyboardInteractive,
                              ])
                                SerlinkSegment(
                                  value: kind,
                                  icon: _identityKindIcon(kind),
                                  label: _identityKindLabel(l10n, kind),
                                ),
                            ],
                            onChanged: (kind) {
                              setState(() {
                                _kind = kind;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
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
    return switch (_kind) {
      IdentityKind.password => SerlinkTextField(
        key: const ValueKey('credential-password-field'),
        controller: _passwordController,
        decoration: InputDecoration(labelText: l10n.credentialPasswordLabel),
        obscureText: true,
        onSubmitted: (_) => _save(),
      ),
      IdentityKind.privateKey => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: SerlinkSegmentedControl<GeneratedSshKeyType>(
                      key: const ValueKey('credential-key-type-control'),
                      value: _keyType,
                      segments: const [
                        SerlinkSegment(
                          value: GeneratedSshKeyType.ed25519,
                          icon: Icons.key_outlined,
                          label: 'Ed25519',
                        ),
                        SerlinkSegment(
                          value: GeneratedSshKeyType.rsa3072,
                          icon: Icons.key_outlined,
                          label: 'RSA 3072',
                        ),
                      ],
                      onChanged: (type) {
                        setState(() {
                          _keyType = type;
                        });
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SerlinkOutlinedButton.icon(
                key: const ValueKey('credential-generate-key-button'),
                onPressed: _generatingKey ? null : _generateKey,
                icon: const Icon(Icons.autorenew_rounded, size: 18),
                label: Text(l10n.credentialGenerateKeyAction),
              ),
            ],
          ),
          if (_generatedKey != null) ...[
            const SizedBox(height: 12),
            _GeneratedPublicKeyPanel(
              generatedKey: _generatedKey!,
              onCopy: _copyPublicKey,
            ),
          ],
          const SizedBox(height: 12),
          _PrivateKeyFields(
            privateKeyController: _privateKeyController,
            passphraseController: _passphraseController,
            onImportKey: _importPrivateKey,
          ),
        ],
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

  Future<void> _generateKey() async {
    setState(() {
      _generatingKey = true;
      _errorMessage = null;
    });
    try {
      final generated = await const SshKeyPairGenerator().generate(
        _keyType,
        comment: _displayNameController.text.trim(),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _generatedKey = generated;
        _generatingKey = false;
        _privateKeyController.text = generated.privateKeyPem;
        _passphraseController.text = '';
      });
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() {
        _generatingKey = false;
        _errorMessage = context.l10n.credentialKeyGenerationFailed;
      });
    }
  }

  Future<void> _copyPublicKey() async {
    final generated = _generatedKey;
    if (generated == null) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: generated.publicKey));
    if (mounted) {
      _showSnackBar(context, context.l10n.credentialPublicKeyCopiedSnack);
    }
  }

  Future<void> _loadSecret(IdentityConfig identity) async {
    try {
      final secret = await ref
          .read(identityWriteServiceProvider)
          .readSecretMaterial(identity);
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
      final service = ref.read(identityWriteServiceProvider);
      final password = _kind == IdentityKind.password
          ? _passwordController.text
          : null;
      final privateKeyPem =
          _kind == IdentityKind.privateKey ||
              _kind == IdentityKind.openSshCertificate
          ? _privateKeyController.text
          : null;
      final privateKeyPassphrase =
          _kind == IdentityKind.privateKey ||
              _kind == IdentityKind.openSshCertificate
          ? _passphraseController.text
          : null;
      final openSshCertificate = _kind == IdentityKind.openSshCertificate
          ? _certificateController.text
          : null;
      final keyboardInteractiveResponses =
          _kind == IdentityKind.keyboardInteractive
          ? _parseSecretLines(_keyboardResponsesController.text)
          : null;
      final publicKeyFingerprint =
          _kind == IdentityKind.privateKey && _generatedKey != null
          ? _generatedKey!.fingerprint
          : null;
      final identity = widget.identity;
      final Object result;
      if (identity == null) {
        result = await service.create(
          IdentityCreateDraft(
            kind: _kind,
            displayName: _displayNameController.text,
            usernameHint: _usernameHintController.text,
            password: password,
            privateKeyPem: privateKeyPem,
            privateKeyPassphrase: privateKeyPassphrase,
            openSshCertificate: openSshCertificate,
            keyboardInteractiveResponses: keyboardInteractiveResponses,
            publicKeyFingerprint: publicKeyFingerprint,
          ),
        );
      } else {
        await service.update(
          IdentityUpdateDraft(
            id: identity.id,
            displayName: _displayNameController.text,
            usernameHint: _usernameHintController.text,
            password: password,
            privateKeyPem: privateKeyPem,
            privateKeyPassphrase: privateKeyPassphrase,
            openSshCertificate: openSshCertificate,
            keyboardInteractiveResponses: keyboardInteractiveResponses,
            publicKeyFingerprint: publicKeyFingerprint,
          ),
        );
        result = true;
      }
      if (mounted) {
        Navigator.of(context).pop(result);
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

class _GeneratedPublicKeyPanel extends StatelessWidget {
  const _GeneratedPublicKeyPanel({
    required this.generatedKey,
    required this.onCopy,
  });

  final GeneratedSshKeyPair generatedKey;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: t.surfaceSunken,
        borderRadius: SerlinkRadii.control,
        border: Border.all(color: t.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.credentialGeneratedPublicKeyLabel,
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(color: t.textPrimary),
                ),
              ),
              SerlinkTooltip(
                message: l10n.credentialCopyPublicKeyTooltip,
                child: SerlinkIconButton(
                  key: const ValueKey('credential-copy-public-key-button'),
                  onPressed: onCopy,
                  icon: const Icon(Icons.copy_outlined, size: 18),
                ),
              ),
            ],
          ),
          SelectableText(
            generatedKey.publicKey,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: t.textPrimary,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 6),
          Text(
            generatedKey.fingerprint,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: t.textMuted),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.credentialGeneratedPublicKeyNote,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: t.textSecondary),
          ),
        ],
      ),
    );
  }
}

List<String> _parseSecretLines(String value) {
  return [
    for (final line in value.split('\n').map((line) => line.trim()))
      if (line.isNotEmpty) line,
  ];
}
