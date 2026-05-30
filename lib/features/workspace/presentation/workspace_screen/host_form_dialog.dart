part of '../workspace_screen.dart';

enum _HostAuthInputMode { password, privateKey, existingIdentity }

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
  final TextEditingController _connectTimeoutController = TextEditingController(
    text: '20',
  );
  final TextEditingController _keepAliveIntervalController =
      TextEditingController(text: '10');
  final TextEditingController _reconnectAttemptsController =
      TextEditingController(text: '0');
  final TextEditingController _reconnectBackoffController =
      TextEditingController(text: '5');

  _HostAuthInputMode _authMode = _HostAuthInputMode.password;
  List<IdentityConfig> _identityOptions = const [];
  List<HostSummary> _jumpHostOptions = const [];
  Set<IdentityId> _selectedIdentityIds = const {};
  Set<HostId> _selectedJumpHostIds = const {};
  bool _showAdvancedConnection = false;
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
    _connectTimeoutController.dispose();
    _keepAliveIntervalController.dispose();
    _reconnectAttemptsController.dispose();
    _reconnectBackoffController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Edit Host' : 'Add Host'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const ValueKey('host-display-name-field'),
                controller: _displayNameController,
                decoration: const InputDecoration(labelText: 'Display name'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('host-hostname-field'),
                controller: _hostnameController,
                decoration: const InputDecoration(labelText: 'Hostname'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      key: const ValueKey('host-username-field'),
                      controller: _usernameController,
                      decoration: const InputDecoration(labelText: 'Username'),
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _portController,
                      decoration: const InputDecoration(labelText: 'Port'),
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('host-startup-commands-field'),
                controller: _startupCommandsController,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Startup commands',
                ),
              ),
              if (!_isEditing) ...[
                const SizedBox(height: 12),
                SegmentedButton<_HostAuthInputMode>(
                  segments: [
                    ButtonSegment(
                      value: _HostAuthInputMode.password,
                      icon: Icon(Icons.password, size: 16),
                      label: Text('Password'),
                    ),
                    ButtonSegment(
                      value: _HostAuthInputMode.privateKey,
                      icon: Icon(Icons.key, size: 16),
                      label: Text('Private Key'),
                    ),
                    ButtonSegment(
                      value: _HostAuthInputMode.existingIdentity,
                      icon: const Icon(Icons.badge_outlined, size: 16),
                      label: const Text('Existing'),
                      enabled: _identityOptions.isNotEmpty,
                    ),
                  ],
                  selected: {_authMode},
                  onSelectionChanged: (selection) {
                    setState(() {
                      _authMode = selection.single;
                    });
                  },
                ),
                const SizedBox(height: 12),
                switch (_authMode) {
                  _HostAuthInputMode.password => TextField(
                    key: const ValueKey('host-password-field'),
                    controller: _passwordController,
                    decoration: const InputDecoration(labelText: 'Password'),
                    obscureText: true,
                    onSubmitted: (_) => _save(),
                  ),
                  _HostAuthInputMode.privateKey => _PrivateKeyFields(
                    privateKeyController: _privateKeyController,
                    passphraseController: _keyPassphraseController,
                    onImportKey: _importPrivateKey,
                  ),
                  _HostAuthInputMode.existingIdentity =>
                    _IdentitySelectionSection(
                      identities: _identityOptions,
                      selectedIdentityIds: _selectedIdentityIds,
                      enabled: !_loadingOptions,
                      onToggle: _toggleIdentity,
                    ),
                },
              ],
              if (_isEditing) ...[
                const SizedBox(height: 12),
                _IdentitySelectionSection(
                  identities: _identityOptions,
                  selectedIdentityIds: _selectedIdentityIds,
                  enabled: !_loadingOptions,
                  onToggle: _toggleIdentity,
                ),
              ],
              if (_jumpHostOptions.isNotEmpty) ...[
                const SizedBox(height: 12),
                _JumpHostSelectionSection(
                  hosts: _jumpHostOptions,
                  selectedHostIds: _selectedJumpHostIds,
                  enabled: !_loadingOptions,
                  onToggle: _toggleJumpHost,
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _tagsController,
                decoration: const InputDecoration(labelText: 'Tags'),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _save(),
              ),
              const SizedBox(height: 12),
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
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('host-save-button'),
          onPressed: _saving || _loadingOptions ? null : _save,
          child: Text(_saving ? 'Saving' : 'Save'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final port = int.tryParse(_portController.text.trim());
    if (port == null) {
      setState(() {
        _errorMessage = 'Port must be a number.';
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
          _errorMessage = 'Host could not be saved.';
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
        } else if (_authMode == _HostAuthInputMode.existingIdentity &&
            identities.isEmpty) {
          _authMode = _HostAuthInputMode.password;
        }
        _loadingOptions = false;
      });
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingOptions = false;
        _errorMessage = 'Host configuration could not be loaded.';
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
        _errorMessage = 'Connection settings must be whole numbers.';
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

String _identityKindLabel(IdentityKind kind) {
  return switch (kind) {
    IdentityKind.password => 'Password',
    IdentityKind.privateKey => 'Private Key',
    IdentityKind.keyboardInteractive => 'Keyboard',
    IdentityKind.openSshCertificate => 'Certificate',
    IdentityKind.sshAgent => 'SSH Agent',
    IdentityKind.hardwareKey => 'Hardware Key',
  };
}
