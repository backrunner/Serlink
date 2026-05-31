part of '../workspace_screen.dart';

Future<void> _showWebDavSyncDialog(
  BuildContext context,
  WidgetRef ref,
  WebDavSyncSettings? settings,
) {
  return showSerlinkDialog<void>(
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
    final l10n = context.l10n;
    return SerlinkDialog(
      maxWidth: _adaptiveDialogWidth(context, _dialogWidthMedium),
      title: Text(l10n.webDavSyncTitle),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SerlinkTextField(
              key: const ValueKey('webdav-endpoint-field'),
              controller: _endpointController,
              decoration: InputDecoration(
                labelText: l10n.webDavEndpointLabel,
                hintText: l10n.webDavEndpointHint,
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            SerlinkTextField(
              key: const ValueKey('webdav-username-field'),
              controller: _usernameController,
              decoration: InputDecoration(labelText: l10n.webDavUsernameLabel),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            SerlinkTextField(
              key: const ValueKey('webdav-password-field'),
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: _isEditing
                    ? l10n.webDavPasswordKeepLabel
                    : l10n.webDavPasswordLabel,
              ),
              obscureText: true,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            SerlinkTextField(
              key: const ValueKey('webdav-base-path-field'),
              controller: _basePathController,
              decoration: InputDecoration(labelText: l10n.webDavBasePathLabel),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 8),
            SerlinkSwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _enabled,
              title: Text(l10n.webDavEnableTitle),
              onChanged: (value) {
                setState(() {
                  _enabled = value;
                });
              },
            ),
            SerlinkCheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _allowInsecureHttp,
              title: Text(l10n.webDavAllowHttpTitle),
              onChanged: (value) {
                setState(() {
                  _allowInsecureHttp = value ?? false;
                });
              },
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              SerlinkAlert.danger(message: _errorMessage!, compact: true),
            ],
          ],
        ),
      ),
      actions: [
        if (_isEditing)
          SerlinkTextButton(
            onPressed: _saving ? null : _delete,
            child: Text(l10n.removeAction),
          ),
        SerlinkTextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.cancelAction),
        ),
        SerlinkFilledButton(
          key: const ValueKey('webdav-save-button'),
          onPressed: _saving ? null : _save,
          child: Text(_saving ? l10n.savingAction : l10n.saveAction),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    var allowInsecureHttp = _allowInsecureHttp;
    final endpoint = Uri.tryParse(_endpointController.text.trim());
    if (endpoint?.scheme == 'http' && !allowInsecureHttp) {
      final confirmed = await _confirmDialog(
        context,
        title: l10n.webDavUseHttpTitle,
        body: l10n.webDavUseHttpBody,
        confirmLabel: l10n.webDavAllowHttpAction,
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
        _showSnackBar(context, l10n.webDavSavedSnack);
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _errorMessage = _syncSettingsErrorMessage(l10n, error);
        });
      }
    }
  }

  Future<void> _delete() async {
    final l10n = context.l10n;
    final confirmed = await _confirmDialog(
      context,
      title: l10n.webDavRemoveTitle,
      body: l10n.webDavRemoveBody,
      confirmLabel: l10n.removeAction,
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
        _showSnackBar(context, l10n.webDavRemovedSnack);
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _errorMessage = _syncSettingsErrorMessage(l10n, error);
        });
      }
    }
  }
}
