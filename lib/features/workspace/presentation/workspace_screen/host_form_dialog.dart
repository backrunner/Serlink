part of '../workspace_screen.dart';

enum _HostAuthInputMode { password, privateKey, sshAgent, savedOrNone }

class _HostFormDialog extends ConsumerStatefulWidget {
  const _HostFormDialog({this.host});

  final HostSummary? host;

  @override
  ConsumerState<_HostFormDialog> createState() => _HostFormDialogState();
}

class _HostFormDialogState extends ConsumerState<_HostFormDialog> {
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _hostnameController = TextEditingController();
  final TextEditingController _portController = TextEditingController(
    text: '22',
  );
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _privateKeyController = TextEditingController();
  final TextEditingController _keyPassphraseController =
      TextEditingController();
  final TextEditingController _startupCommandsController =
      TextEditingController();
  final TextEditingController _tagsController = TextEditingController();
  final TextEditingController _sftpDefaultDirectoryController =
      TextEditingController(text: '/');
  final TextEditingController _connectTimeoutController = TextEditingController(
    text: '20',
  );
  final TextEditingController _keepAliveIntervalController =
      TextEditingController(text: '10');
  final TextEditingController _reconnectAttemptsController =
      TextEditingController(text: '0');
  final TextEditingController _reconnectBackoffController =
      TextEditingController(text: '5');
  final ScrollController _scrollController = ScrollController();

  _HostAuthInputMode _authMode = _HostAuthInputMode.password;
  List<IdentityConfig> _identityOptions = const [];
  List<HostSummary> _jumpHostOptions = const [];
  Set<IdentityId> _selectedIdentityIds = const {};
  Set<HostId> _selectedJumpHostIds = const {};
  bool _showAdvancedConnection = false;
  bool _passwordVisible = false;
  bool _loadingOptions = true;
  bool _saving = false;
  String? _errorMessage;

  bool get _isEditing => widget.host != null;

  @override
  void initState() {
    super.initState();
    final host = widget.host;
    if (host == null) {
      return;
    }
    _displayNameController.text = host.displayName;
    _hostnameController.text = host.hostname;
    _portController.text = host.port.toString();
    _usernameController.text = host.username;
    _tagsController.text = host.tags.join(', ');
    unawaited(_loadOptions());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isEditing && _loadingOptions) {
      unawaited(_loadOptions());
    }
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _hostnameController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _privateKeyController.dispose();
    _keyPassphraseController.dispose();
    _startupCommandsController.dispose();
    _tagsController.dispose();
    _sftpDefaultDirectoryController.dispose();
    _connectTimeoutController.dispose();
    _keepAliveIntervalController.dispose();
    _reconnectAttemptsController.dispose();
    _reconnectBackoffController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final mediaSize = MediaQuery.sizeOf(context);
    final dialogWidth = math.min(680.0, math.max(360.0, mediaSize.width - 96));
    final dialogHeight = math.min(
      720.0,
      math.max(420.0, mediaSize.height - 140),
    );

    return SerlinkDialog(
      title: Text(_isEditing ? l10n.hostEditTitle : l10n.hostAddTitle),
      content: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: Scrollbar(
          controller: _scrollController,
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(
              context,
            ).copyWith(scrollbars: false),
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(2, 8, 10, 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _HostFormSection(
                    title: l10n.hostSectionConnection,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: SerlinkTextField(
                                key: const ValueKey('host-hostname-field'),
                                controller: _hostnameController,
                                decoration: InputDecoration(
                                  labelText: l10n.hostHostnameLabel,
                                ),
                                textInputAction: TextInputAction.next,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: SerlinkTextField(
                                controller: _portController,
                                decoration: InputDecoration(
                                  labelText: l10n.hostPortLabel,
                                ),
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.next,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        SerlinkTextField(
                          key: const ValueKey('host-display-name-field'),
                          controller: _displayNameController,
                          decoration: InputDecoration(
                            labelText: l10n.hostDisplayNameOptionalLabel,
                            hintText: l10n.hostDisplayNameHostnameHint,
                            helperText: l10n.hostDisplayNameHostnameHelper,
                          ),
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 14),
                        SerlinkTextField(
                          key: const ValueKey('host-username-field'),
                          controller: _usernameController,
                          decoration: InputDecoration(
                            labelText: l10n.hostUsernameLabel,
                          ),
                          textInputAction: TextInputAction.next,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _HostFormSection(
                    title: l10n.hostSectionAuthentication,
                    child: _HostAuthenticationFields(
                      isEditing: _isEditing,
                      authMode: _authMode,
                      loadingOptions: _loadingOptions,
                      passwordController: _passwordController,
                      passwordVisible: _passwordVisible,
                      privateKeyController: _privateKeyController,
                      keyPassphraseController: _keyPassphraseController,
                      identityOptions: _identityOptions,
                      selectedIdentityIds: _selectedIdentityIds,
                      onAuthModeChanged: (authMode) {
                        setState(() {
                          _authMode = authMode;
                        });
                      },
                      onImportPrivateKey: _importPrivateKey,
                      onTogglePasswordVisible: () {
                        setState(() {
                          _passwordVisible = !_passwordVisible;
                        });
                      },
                      onToggleIdentity: _toggleIdentity,
                      onEditIdentity: _editIdentity,
                      onSubmit: _save,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _HostFormSection(
                    title: l10n.hostSectionStartup,
                    child: Column(
                      children: [
                        SerlinkTextField(
                          key: const ValueKey('host-startup-commands-field'),
                          controller: _startupCommandsController,
                          minLines: 2,
                          maxLines: 5,
                          decoration: InputDecoration(
                            labelText: l10n.hostStartupCommandsLabel,
                          ),
                        ),
                        const SizedBox(height: 14),
                        SerlinkTextField(
                          controller: _tagsController,
                          decoration: InputDecoration(
                            labelText: l10n.hostTagsLabel,
                          ),
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _save(),
                        ),
                      ],
                    ),
                  ),
                  if (_jumpHostOptions.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _HostFormSection(
                      title: l10n.hostSectionRouting,
                      child: _JumpHostSelectionSection(
                        hosts: _jumpHostOptions,
                        selectedHostIds: _selectedJumpHostIds,
                        enabled: !_loadingOptions,
                        onToggle: _toggleJumpHost,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _HostFormSection(
                    title: 'SFTP',
                    child: SerlinkTextField(
                      key: const ValueKey('host-sftp-default-directory-field'),
                      controller: _sftpDefaultDirectoryController,
                      decoration: InputDecoration(
                        labelText: l10n.hostStartFolderLabel,
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _AdvancedConnectionSettingsSection(
                    expanded: _showAdvancedConnection,
                    connectTimeoutController: _connectTimeoutController,
                    keepAliveIntervalController: _keepAliveIntervalController,
                    reconnectAttemptsController: _reconnectAttemptsController,
                    reconnectBackoffController: _reconnectBackoffController,
                    onToggle: () {
                      setState(() {
                        _showAdvancedConnection = !_showAdvancedConnection;
                      });
                    },
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    _HostFormError(message: _errorMessage!),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        SerlinkTextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.cancelAction),
        ),
        SerlinkFilledButton(
          key: const ValueKey('host-save-button'),
          onPressed: _saving || _loadingOptions ? null : _save,
          child: Text(_saving ? l10n.savingAction : l10n.saveAction),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final port = int.tryParse(_portController.text.trim());
    if (port == null) {
      setState(() {
        _errorMessage = context.l10n.hostPortNumberError;
      });
      return;
    }
    final connectionSettings = _parseConnectionSettings();
    if (connectionSettings == null) {
      return;
    }

    setState(() {
      _saving = true;
      _errorMessage = null;
    });
    try {
      final service = ref.read(hostWriteServiceProvider);
      final host = widget.host;
      final startupCommands = _parseStartupCommands(
        _startupCommandsController.text,
      );
      final jumpHostIds = _selectedJumpHostIds.toList(growable: false);
      if (host != null) {
        await service.updateHostMetadata(
          HostMetadataDraft(
            id: host.id,
            displayName: _displayNameController.text,
            hostname: _hostnameController.text,
            port: port,
            username: _usernameController.text,
            tags: _parseTags(_tagsController.text),
            identityIds: _selectedIdentityIds.toList(growable: false),
            startupCommands: startupCommands,
            jumpHostIds: jumpHostIds,
            sftpDefaultDirectory: _sftpDefaultDirectoryController.text,
            connectionSettings: connectionSettings,
          ),
        );
      } else if (_authMode == _HostAuthInputMode.password) {
        await service.createPasswordHost(
          PasswordHostDraft(
            displayName: _displayNameController.text,
            hostname: _hostnameController.text,
            port: port,
            username: _usernameController.text,
            password: _passwordController.text,
            tags: _parseTags(_tagsController.text),
            startupCommands: startupCommands,
            jumpHostIds: jumpHostIds,
            sftpDefaultDirectory: _sftpDefaultDirectoryController.text,
            connectionSettings: connectionSettings,
          ),
        );
      } else if (_authMode == _HostAuthInputMode.privateKey) {
        await service.createPrivateKeyHost(
          PrivateKeyHostDraft(
            displayName: _displayNameController.text,
            hostname: _hostnameController.text,
            port: port,
            username: _usernameController.text,
            privateKeyPem: _privateKeyController.text,
            privateKeyPassphrase: _keyPassphraseController.text,
            tags: _parseTags(_tagsController.text),
            startupCommands: startupCommands,
            jumpHostIds: jumpHostIds,
            sftpDefaultDirectory: _sftpDefaultDirectoryController.text,
            connectionSettings: connectionSettings,
          ),
        );
      } else if (_authMode == _HostAuthInputMode.sshAgent) {
        await service.createSshAgentHost(
          SshAgentHostDraft(
            displayName: _displayNameController.text,
            hostname: _hostnameController.text,
            port: port,
            username: _usernameController.text,
            tags: _parseTags(_tagsController.text),
            startupCommands: startupCommands,
            jumpHostIds: jumpHostIds,
            sftpDefaultDirectory: _sftpDefaultDirectoryController.text,
            connectionSettings: connectionSettings,
          ),
        );
      } else {
        await service.createHostWithExistingIdentities(
          ExistingIdentitiesHostDraft(
            displayName: _displayNameController.text,
            hostname: _hostnameController.text,
            port: port,
            username: _usernameController.text,
            identityIds: _selectedIdentityIds.toList(growable: false),
            tags: _parseTags(_tagsController.text),
            startupCommands: startupCommands,
            jumpHostIds: jumpHostIds,
            sftpDefaultDirectory: _sftpDefaultDirectoryController.text,
            connectionSettings: connectionSettings,
          ),
        );
      }
      ref.invalidate(hostSummariesProvider);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } on HostWriteException catch (error) {
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
          _errorMessage = context.l10n.hostSaveFailed;
        });
      }
    }
  }

  Future<void> _importPrivateKey() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'SSH Private Key', extensions: ['pem', 'key', 'txt']),
      ],
    );
    if (file == null) {
      return;
    }
    _privateKeyController.text = await file.readAsString();
  }

  Future<void> _loadOptions() async {
    try {
      final identities = await ref.read(identityRepositoryProvider).list();
      final hostConfigs = await ref.read(hostRepositoryProvider).list();
      final editingHostId = widget.host?.id;
      final hostConfig = editingHostId == null
          ? null
          : await ref.read(hostRepositoryProvider).read(editingHostId);
      if (!mounted) {
        return;
      }
      identities.sort(
        (left, right) => left.displayName.toLowerCase().compareTo(
          right.displayName.toLowerCase(),
        ),
      );
      final jumpHosts = [
        for (final host
            in hostConfigs.map((host) => host.toSummary()).toList()..sort(
              (left, right) => left.displayName.toLowerCase().compareTo(
                right.displayName.toLowerCase(),
              ),
            ))
          if (host.id != editingHostId) host,
      ];
      setState(() {
        _identityOptions = List<IdentityConfig>.unmodifiable(identities);
        _jumpHostOptions = List<HostSummary>.unmodifiable(jumpHosts);
        if (hostConfig != null) {
          _selectedIdentityIds = {...hostConfig.identityIds};
          _selectedJumpHostIds = {...hostConfig.jumpHostIds};
          _startupCommandsController.text = hostConfig.startupCommands.join(
            '\n',
          );
          _sftpDefaultDirectoryController.text =
              hostConfig.sftpDefaultDirectory;
          _connectTimeoutController.text = hostConfig
              .connectionSettings
              .connectTimeoutSeconds
              .toString();
          _keepAliveIntervalController.text = hostConfig
              .connectionSettings
              .keepAliveIntervalSeconds
              .toString();
          _reconnectAttemptsController.text = hostConfig
              .connectionSettings
              .reconnectAttempts
              .toString();
          _reconnectBackoffController.text = hostConfig
              .connectionSettings
              .reconnectBackoffSeconds
              .toString();
        }
        _loadingOptions = false;
      });
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingOptions = false;
        _errorMessage = context.l10n.hostConfigurationLoadFailed;
      });
    }
  }

  void _toggleIdentity(IdentityId identityId) {
    final next = {..._selectedIdentityIds};
    if (!next.add(identityId)) {
      next.remove(identityId);
    }
    setState(() {
      _selectedIdentityIds = next;
    });
  }

  void _toggleJumpHost(HostId hostId) {
    final next = {..._selectedJumpHostIds};
    if (!next.add(hostId)) {
      next.remove(hostId);
    }
    setState(() {
      _selectedJumpHostIds = next;
    });
  }

  Future<void> _editIdentity(IdentityConfig identity) async {
    final updated = await showSerlinkDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _IdentityEditDialog(identity: identity),
    );
    if (updated != true || !mounted) {
      return;
    }
    final identities = await ref.read(identityRepositoryProvider).list();
    identities.sort(
      (left, right) => left.displayName.toLowerCase().compareTo(
        right.displayName.toLowerCase(),
      ),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _identityOptions = List<IdentityConfig>.unmodifiable(identities);
    });
  }

  HostConnectionSettings? _parseConnectionSettings() {
    final connectTimeout = int.tryParse(_connectTimeoutController.text.trim());
    final keepAlive = int.tryParse(_keepAliveIntervalController.text.trim());
    final reconnectAttempts = int.tryParse(
      _reconnectAttemptsController.text.trim(),
    );
    final reconnectBackoff = int.tryParse(
      _reconnectBackoffController.text.trim(),
    );
    if (connectTimeout == null ||
        keepAlive == null ||
        reconnectAttempts == null ||
        reconnectBackoff == null) {
      setState(() {
        _errorMessage = context.l10n.hostConnectionSettingsWholeNumbers;
      });
      return null;
    }
    return HostConnectionSettings(
      connectTimeoutSeconds: connectTimeout,
      keepAliveIntervalSeconds: keepAlive,
      reconnectAttempts: reconnectAttempts,
      reconnectBackoffSeconds: reconnectBackoff,
    );
  }
}

Set<String> _parseTags(String value) {
  return {
    for (final tag in value.split(',').map((tag) => tag.trim()))
      if (tag.isNotEmpty) tag,
  };
}

List<String> _parseStartupCommands(String value) {
  return [
    for (final command in value.split('\n').map((command) => command.trim()))
      if (command.isNotEmpty) command,
  ];
}

String _identityKindLabel(AppLocalizations l10n, IdentityKind kind) {
  return switch (kind) {
    IdentityKind.password => l10n.identityKindPassword,
    IdentityKind.privateKey => l10n.identityKindPrivateKey,
    IdentityKind.keyboardInteractive => l10n.identityKindKeyboard,
    IdentityKind.openSshCertificate => l10n.identityKindCertificate,
    IdentityKind.sshAgent => l10n.identityKindSshAgent,
    IdentityKind.hardwareKey => l10n.identityKindHardwareKey,
  };
}
