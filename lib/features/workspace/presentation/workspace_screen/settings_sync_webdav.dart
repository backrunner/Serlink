part of '../workspace_screen.dart';

Future<void> _showWebDavSyncDialog(
  BuildContext context,
  WidgetRef ref,
  WebDavSyncSettings? settings,
) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _WebDavSyncDialog(initialSettings: settings),
  );
}

class _WebDavSyncDialog extends ConsumerStatefulWidget {
  const _WebDavSyncDialog({required this.initialSettings});

  final WebDavSyncSettings? initialSettings;

  @override
  ConsumerState<_WebDavSyncDialog> createState() => _WebDavSyncDialogState();
}

class _WebDavSyncDialogState extends ConsumerState<_WebDavSyncDialog> {
  late final TextEditingController _endpointController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  late final TextEditingController _basePathController;
  late bool _enabled;
  late bool _allowInsecureHttp;
  var _saving = false;
  String? _errorMessage;

  bool get _isEditing => widget.initialSettings != null;

  @override
  void initState() {
    super.initState();
    final settings = widget.initialSettings;
    _endpointController = TextEditingController(
      text: settings?.endpoint.toString() ?? '',
    );
    _usernameController = TextEditingController(text: settings?.username ?? '');
    _passwordController = TextEditingController();
    _basePathController = TextEditingController(
      text: settings?.basePath ?? '/serlink',
    );
    _enabled = settings?.enabled ?? true;
    _allowInsecureHttp = settings?.allowInsecureHttp ?? false;
  }

  @override
  void dispose() {
    _endpointController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _basePathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('WebDAV Sync'),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const ValueKey('webdav-endpoint-field'),
              controller: _endpointController,
              decoration: const InputDecoration(
                labelText: 'Endpoint',
                hintText: 'https://example.com/webdav',
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('webdav-username-field'),
              controller: _usernameController,
              decoration: const InputDecoration(labelText: 'Username'),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('webdav-password-field'),
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: _isEditing
                    ? 'Password (leave blank to keep)'
                    : 'Password',
              ),
              obscureText: true,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('webdav-base-path-field'),
              controller: _basePathController,
              decoration: const InputDecoration(labelText: 'Base path'),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _enabled,
              title: const Text('Enable WebDAV sync'),
              onChanged: (value) {
                setState(() {
                  _enabled = value;
                });
              },
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _allowInsecureHttp,
              title: const Text('Allow HTTP endpoint'),
              onChanged: (value) {
                setState(() {
                  _allowInsecureHttp = value ?? false;
                });
              },
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (_isEditing)
          TextButton(
            onPressed: _saving ? null : _delete,
            child: const Text('Remove'),
          ),
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('webdav-save-button'),
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving' : 'Save'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    var allowInsecureHttp = _allowInsecureHttp;
    final endpoint = Uri.tryParse(_endpointController.text.trim());
    if (endpoint?.scheme == 'http' && !allowInsecureHttp) {
      final confirmed = await _confirmDialog(
        context,
        title: 'Use HTTP WebDAV?',
        body:
            'HTTP sync can expose metadata and credentials in transit. Use only for trusted local test servers.',
        confirmLabel: 'Allow HTTP',
        destructive: true,
      );
      if (!confirmed) {
        return;
      }
      allowInsecureHttp = true;
      if (mounted) {
        setState(() {
          _allowInsecureHttp = true;
        });
      }
    }

    setState(() {
      _saving = true;
      _errorMessage = null;
    });
    try {
      await ref
          .read(syncSettingsServiceProvider)
          .saveWebDav(
            WebDavSyncSettingsDraft(
              endpoint: _endpointController.text,
              username: _usernameController.text,
              password: _passwordController.text,
              basePath: _basePathController.text,
              allowInsecureHttp: allowInsecureHttp,
              enabled: _enabled,
            ),
          );
      ref.invalidate(webDavSyncSettingsProvider);
      if (mounted) {
        Navigator.of(context).pop();
        _showSnackBar(context, 'WebDAV sync settings saved.');
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _errorMessage = _syncSettingsErrorMessage(error);
        });
      }
    }
  }

  Future<void> _delete() async {
    final confirmed = await _confirmDialog(
      context,
      title: 'Remove WebDAV sync?',
      body: 'This removes the local WebDAV configuration and stored password.',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (!confirmed) {
      return;
    }
    setState(() {
      _saving = true;
      _errorMessage = null;
    });
    try {
      await ref.read(syncSettingsServiceProvider).deleteWebDav();
      ref.invalidate(webDavSyncSettingsProvider);
      if (mounted) {
        Navigator.of(context).pop();
        _showSnackBar(context, 'WebDAV sync settings removed.');
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _errorMessage = _syncSettingsErrorMessage(error);
        });
      }
    }
  }
}
