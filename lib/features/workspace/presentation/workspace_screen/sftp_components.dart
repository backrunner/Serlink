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
    return AlertDialog(
      title: Text(widget.entry.name, overflow: TextOverflow.ellipsis),
      content: SizedBox(
        width: 720,
        height: 460,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (preview.truncated) ...[
              Text(
                'Preview limited to ${_formatBytes(preview.bytesRead)}.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
            ],
            Expanded(
              child: TextField(
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
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(preview.truncated ? 'Close' : 'Cancel'),
        ),
        if (!preview.truncated)
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_controller.text),
            child: const Text('Save'),
          ),
      ],
    );
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
    return ListTile(
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
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Download',
              onPressed: onDownload,
              icon: const Icon(Icons.download_outlined, size: 16),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Rename',
              onPressed: onRename,
              icon: const Icon(Icons.drive_file_rename_outline, size: 16),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Move',
              onPressed: onMove,
              icon: const Icon(Icons.drive_file_move_outline, size: 16),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Change permissions',
              onPressed: onChmod,
              icon: const Icon(Icons.admin_panel_settings_outlined, size: 16),
            ),
            IconButton(
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
