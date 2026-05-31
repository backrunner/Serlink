part of '../workspace_screen.dart';

class _RemoteFileDialog extends StatefulWidget {
  const _RemoteFileDialog({required this.entry, required this.preview});

  final SftpEntry entry;
  final SftpFilePreview preview;

  @override
  State<_RemoteFileDialog> createState() => _RemoteFileDialogState();
}

class _RemoteFileDialogState extends State<_RemoteFileDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.preview.text);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final preview = widget.preview;
    return SerlinkDialog(
      title: Text(widget.entry.name, overflow: TextOverflow.ellipsis),
      content: SizedBox(
        width: 720,
        height: 460,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (preview.truncated) ...[
              SerlinkAlert.info(
                message:
                    'Preview limited to ${_formatBytes(preview.bytesRead)}.',
                compact: true,
              ),
              const SizedBox(height: 8),
            ],
            Expanded(
              child: SerlinkTextField(
                key: const ValueKey('remote-file-editor'),
                controller: _controller,
                readOnly: preview.truncated,
                expands: true,
                maxLines: null,
                minLines: null,
                keyboardType: TextInputType.multiline,
                style: const TextStyle(fontFamily: 'monospace'),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        SerlinkTextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(preview.truncated ? 'Close' : 'Cancel'),
        ),
        if (!preview.truncated)
          SerlinkFilledButton(
            onPressed: () => Navigator.of(context).pop(_controller.text),
            child: const Text('Save'),
          ),
      ],
    );
  }
}

class _SftpDefaultDirectoryDialog extends StatefulWidget {
  const _SftpDefaultDirectoryDialog({
    required this.initialValue,
    required this.failedPath,
    required this.failureMessage,
  });

  final String initialValue;
  final String failedPath;
  final String failureMessage;

  @override
  State<_SftpDefaultDirectoryDialog> createState() =>
      _SftpDefaultDirectoryDialogState();
}

class _SftpDefaultDirectoryDialogState
    extends State<_SftpDefaultDirectoryDialog> {
  late final TextEditingController _controller;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SerlinkDialog(
      title: const Text('Choose SFTP Start Folder'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SerlinkAlert.warning(
              message:
                  '${widget.failedPath} could not be listed. ${widget.failureMessage}',
              compact: true,
            ),
            const SizedBox(height: 12),
            SerlinkTextField(
              key: const ValueKey('sftp-default-directory-field'),
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Start folder',
                hintText: '/home/user',
                errorText: _errorMessage,
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        SerlinkTextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        SerlinkFilledButton(
          key: const ValueKey('sftp-default-directory-submit-button'),
          onPressed: _submit,
          child: const Text('Connect'),
        ),
      ],
    );
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty || !value.startsWith('/')) {
      setState(() {
        _errorMessage = 'Enter an absolute remote path.';
      });
      return;
    }
    Navigator.of(context).pop(value);
  }
}

class _SftpEntryRow extends StatelessWidget {
  const _SftpEntryRow({
    required this.name,
    required this.typeLabel,
    required this.icon,
    required this.sizeLabel,
    required this.permissionsLabel,
    required this.metadataLabel,
    required this.onTap,
    required this.onRename,
    required this.onMove,
    required this.onChmod,
    required this.onDelete,
    required this.onDownload,
  });

  final String name;
  final String typeLabel;
  final IconData icon;
  final String sizeLabel;
  final String permissionsLabel;
  final String metadataLabel;
  final VoidCallback? onTap;
  final VoidCallback? onRename;
  final VoidCallback? onMove;
  final VoidCallback? onChmod;
  final VoidCallback? onDelete;
  final VoidCallback? onDownload;

  @override
  Widget build(BuildContext context) {
    return SerlinkListTile(
      dense: true,
      leading: Icon(icon),
      title: Text(name, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        metadataLabel.isEmpty ? typeLabel : '$typeLabel · $metadataLabel',
        overflow: TextOverflow.ellipsis,
      ),
      trailing: SizedBox(
        width: 360,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Flexible(child: Text(sizeLabel, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 16),
            SizedBox(width: 44, child: Text(permissionsLabel)),
            SerlinkIconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Download',
              onPressed: onDownload,
              icon: const Icon(Icons.download_outlined, size: 16),
            ),
            SerlinkIconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Rename',
              onPressed: onRename,
              icon: const Icon(Icons.drive_file_rename_outline, size: 16),
            ),
            SerlinkIconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Move',
              onPressed: onMove,
              icon: const Icon(Icons.drive_file_move_outline, size: 16),
            ),
            SerlinkIconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Change permissions',
              onPressed: onChmod,
              icon: const Icon(Icons.admin_panel_settings_outlined, size: 16),
            ),
            SerlinkIconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Delete',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline, size: 16),
            ),
          ],
        ),
      ),
      onTap: onTap,
    );
  }
}
