part of '../workspace_screen.dart';

enum _SftpUploadKind { file, directory }

class _SftpPane extends ConsumerStatefulWidget {
  const _SftpPane({
    super.key,
    required this.tabId,
    required this.sessionId,
    required this.path,
    required this.lifecycle,
    required this.onOpenTerminal,
  });

  final WorkspaceTabId tabId;
  final SessionId sessionId;
  final String path;
  final SessionLifecycleState lifecycle;
  final VoidCallback? onOpenTerminal;

  @override
  ConsumerState<_SftpPane> createState() => _SftpPaneState();
}

class _SftpPaneState extends ConsumerState<_SftpPane> {
  final TextEditingController _filterController = TextEditingController();
  Future<List<SftpEntry>>? _entriesFuture;
  String _filterText = '';
  bool _showHidden = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_SftpPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sessionId != widget.sessionId ||
        oldWidget.path != widget.path ||
        oldWidget.lifecycle != widget.lifecycle) {
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final canList = widget.lifecycle == SessionLifecycleState.connected;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.folder_open, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(widget.path, overflow: TextOverflow.ellipsis),
              ),
              SizedBox(
                width: 220,
                child: TextField(
                  key: const ValueKey('sftp-search-field'),
                  controller: _filterController,
                  enabled: canList,
                  decoration: const InputDecoration(
                    isDense: true,
                    prefixIcon: Icon(Icons.search, size: 16),
                    hintText: 'Filter',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _filterText = value;
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: _showHidden
                    ? 'Hide hidden files'
                    : 'Show hidden files',
                child: IconButton(
                  key: const ValueKey('sftp-hidden-toggle'),
                  onPressed: canList
                      ? () {
                          setState(() {
                            _showHidden = !_showHidden;
                          });
                        }
                      : null,
                  icon: Icon(
                    _showHidden
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Tooltip(
                message: 'Open terminal tab',
                child: IconButton(
                  onPressed: widget.onOpenTerminal,
                  icon: const Icon(Icons.terminal_outlined, size: 18),
                ),
              ),
              const SizedBox(width: 4),
              PopupMenuButton<_SftpUploadKind>(
                key: const ValueKey('sftp-upload-button'),
                tooltip: 'Upload',
                enabled: canList,
                icon: const Icon(Icons.upload_file_outlined, size: 18),
                onSelected: (kind) {
                  switch (kind) {
                    case _SftpUploadKind.file:
                      _enqueueUploadFile();
                    case _SftpUploadKind.directory:
                      _enqueueUploadDirectory();
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: _SftpUploadKind.file,
                    child: Text('Upload file'),
                  ),
                  PopupMenuItem(
                    value: _SftpUploadKind.directory,
                    child: Text('Upload folder'),
                  ),
                ],
              ),
              Tooltip(
                message: 'New folder',
                child: IconButton(
                  key: const ValueKey('sftp-new-folder-button'),
                  onPressed: canList ? _createDirectory : null,
                  icon: const Icon(Icons.create_new_folder_outlined, size: 18),
                ),
              ),
              Tooltip(
                message: 'Refresh',
                child: IconButton(
                  onPressed: canList
                      ? () {
                          setState(_reload);
                        }
                      : null,
                  icon: const Icon(Icons.refresh, size: 18),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(child: _buildBody(context, canList: canList)),
      ],
    );
  }

  Widget _buildBody(BuildContext context, {required bool canList}) {
    final future = _entriesFuture;
    if (!canList || future == null) {
      return const _PlaceholderSurface(
        title: 'SFTP',
        body: 'Waiting for the SFTP connection.',
      );
    }

    return FutureBuilder<List<SftpEntry>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _PlaceholderSurface(
            title: 'SFTP Error',
            body: sftpFailureMessage(snapshot.error!),
          );
        }
        final allEntries = _sortedEntries(snapshot.data ?? const []);
        final visibleEntries = _showHidden
            ? allEntries
            : [
                for (final entry in allEntries)
                  if (!entry.isHidden) entry,
              ];
        final entries = _filterEntries(visibleEntries, _filterText);
        if (entries.isEmpty) {
          return _PlaceholderSurface(
            title: _filterText.trim().isEmpty ? 'Empty Folder' : 'No Matches',
            body: _sftpEmptyBody(
              allEntries: allEntries,
              visibleEntries: visibleEntries,
              filterText: _filterText,
              showHidden: _showHidden,
            ),
          );
        }
        return ListView.separated(
          itemCount: _showParentEntry ? entries.length + 1 : entries.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            if (_showParentEntry && index == 0) {
              return _SftpEntryRow(
                name: '..',
                typeLabel: 'Directory',
                icon: Icons.drive_folder_upload_outlined,
                sizeLabel: '',
                permissionsLabel: '',
                metadataLabel: '',
                onTap: () => _openDirectory(_parentPath(widget.path)),
                onRename: null,
                onMove: null,
                onChmod: null,
                onDelete: null,
                onDownload: null,
              );
            }
            final entry = entries[_showParentEntry ? index - 1 : index];
            final isDirectory = entry.type == SftpEntryType.directory;
            return _SftpEntryRow(
              name: entry.name,
              typeLabel: _entryTypeLabel(entry.type),
              icon: isDirectory
                  ? Icons.folder_outlined
                  : Icons.description_outlined,
              sizeLabel: isDirectory ? '' : _formatBytes(entry.size),
              permissionsLabel: entry.permissions?.octal ?? '',
              metadataLabel: _sftpEntryMetadataLabel(entry),
              onTap: isDirectory
                  ? () => _openDirectory(entry.path)
                  : () => _previewFile(entry),
              onRename: () => _renameEntry(entry),
              onMove: () => _moveEntry(entry),
              onChmod: () => _chmodEntry(entry),
              onDelete: () => _deleteEntry(entry),
              onDownload:
                  entry.type == SftpEntryType.file ||
                      entry.type == SftpEntryType.directory
                  ? () => _enqueueDownload(entry)
                  : null,
            );
          },
        );
      },
    );
  }

  bool get _showParentEntry => widget.path != '/';

  void _reload() {
    final connection = ref
        .read(workspaceRuntimeRegistryProvider)
        .sftpFor(widget.sessionId);
    _entriesFuture = connection?.list(widget.path);
  }

  void _openDirectory(String path) {
    ref
        .read(workspaceTabControllerProvider.notifier)
        .changeSftpDirectory(widget.tabId, path);
  }

  Future<void> _createDirectory() async {
    final name = await _showTextInputDialog(
      context,
      title: 'New Folder',
      label: 'Folder name',
      confirmLabel: 'Create',
    );
    if (name == null || name.trim().isEmpty) {
      return;
    }
    await _runSftpOperation(
      () => _connection().mkdir(_remoteChildPath(widget.path, name.trim())),
      successMessage: 'Folder created.',
    );
  }

  Future<void> _enqueueUploadFile() async {
    final file = await openFile();
    if (file == null) {
      return;
    }
    final localPath = file.path;
    if (localPath.isEmpty) {
      if (mounted) {
        _showSnackBar(context, 'Selected file has no local path.');
      }
      return;
    }
    final remotePath = await _resolveRemoteTransferConflict(
      desiredRemotePath: _remoteChildPath(widget.path, file.name),
      itemKind: TransferItemKind.file,
    );
    if (remotePath == null) {
      return;
    }
    ref
        .read(transferQueueControllerProvider)
        .enqueueUpload(
          connection: _connection(),
          itemKind: TransferItemKind.file,
          localPath: localPath,
          remotePath: remotePath,
        );
    if (mounted) {
      _showSnackBar(context, 'Upload queued.');
    }
  }

  Future<void> _enqueueUploadDirectory() async {
    final directoryPath = await getDirectoryPath(confirmButtonText: 'Upload');
    if (directoryPath == null || directoryPath.isEmpty) {
      return;
    }
    final directoryName = p.basename(directoryPath);
    final remotePath = await _resolveRemoteTransferConflict(
      desiredRemotePath: _remoteChildPath(widget.path, directoryName),
      itemKind: TransferItemKind.directory,
    );
    if (remotePath == null) {
      return;
    }
    ref
        .read(transferQueueControllerProvider)
        .enqueueUpload(
          connection: _connection(),
          itemKind: TransferItemKind.directory,
          localPath: directoryPath,
          remotePath: remotePath,
        );
    if (mounted) {
      _showSnackBar(context, 'Folder upload queued.');
    }
  }

  Future<void> _enqueueDownload(SftpEntry entry) async {
    final itemKind = entry.type == SftpEntryType.directory
        ? TransferItemKind.directory
        : TransferItemKind.file;
    final localPath = switch (itemKind) {
      TransferItemKind.file => await _pickFileDownloadPath(entry),
      TransferItemKind.directory => await _pickDirectoryDownloadPath(entry),
    };
    if (localPath == null) {
      return;
    }
    ref
        .read(transferQueueControllerProvider)
        .enqueueDownload(
          connection: _connection(),
          itemKind: itemKind,
          remotePath: entry.path,
          localPath: localPath,
        );
    if (mounted) {
      _showSnackBar(
        context,
        itemKind == TransferItemKind.directory
            ? 'Folder download queued.'
            : 'Download queued.',
      );
    }
  }

  Future<String?> _pickFileDownloadPath(SftpEntry entry) async {
    final location = await getSaveLocation(suggestedName: entry.name);
    if (location == null) {
      return null;
    }
    return _resolveLocalTransferConflict(
      desiredLocalPath: location.path,
      itemKind: TransferItemKind.file,
    );
  }

  Future<String?> _pickDirectoryDownloadPath(SftpEntry entry) async {
    final parentPath = await getDirectoryPath(
      confirmButtonText: 'Download',
      canCreateDirectories: true,
    );
    if (parentPath == null || parentPath.isEmpty) {
      return null;
    }
    return _resolveLocalTransferConflict(
      desiredLocalPath: p.join(parentPath, entry.name),
      itemKind: TransferItemKind.directory,
    );
  }

  Future<String?> _resolveRemoteTransferConflict({
    required String desiredRemotePath,
    required TransferItemKind itemKind,
  }) async {
    if (!await _remoteEntryExists(desiredRemotePath)) {
      return desiredRemotePath;
    }
    if (!mounted) {
      return null;
    }
    final action = await _showTransferConflictDialog(
      context,
      title: itemKind == TransferItemKind.directory
          ? 'Merge remote folder?'
          : 'Replace remote file?',
      body: itemKind == TransferItemKind.directory
          ? '$desiredRemotePath already exists on the server. Matching files may be overwritten.'
          : '$desiredRemotePath already exists on the server.',
      replaceLabel: itemKind == TransferItemKind.directory
          ? 'Merge'
          : 'Replace',
    );
    return switch (action) {
      TransferConflictAction.replace => desiredRemotePath,
      TransferConflictAction.rename => _nextAvailableRemotePath(
        desiredRemotePath,
      ),
      TransferConflictAction.skip || null => null,
    };
  }

  Future<String?> _resolveLocalTransferConflict({
    required String desiredLocalPath,
    required TransferItemKind itemKind,
  }) async {
    if (await FileSystemEntity.type(desiredLocalPath) ==
        FileSystemEntityType.notFound) {
      return desiredLocalPath;
    }
    if (!mounted) {
      return null;
    }
    final action = await _showTransferConflictDialog(
      context,
      title: itemKind == TransferItemKind.directory
          ? 'Merge local folder?'
          : 'Replace local file?',
      body: itemKind == TransferItemKind.directory
          ? '$desiredLocalPath already exists on this device. Matching files may be overwritten.'
          : '$desiredLocalPath already exists on this device.',
      replaceLabel: itemKind == TransferItemKind.directory
          ? 'Merge'
          : 'Replace',
    );
    return switch (action) {
      TransferConflictAction.replace => desiredLocalPath,
      TransferConflictAction.rename => _nextAvailableLocalPath(
        desiredLocalPath,
      ),
      TransferConflictAction.skip || null => null,
    };
  }

  Future<String> _nextAvailableRemotePath(String desiredRemotePath) async {
    final parent = _parentPath(desiredRemotePath);
    final entries = await _connection().list(parent);
    return nextRemoteConflictPath(desiredRemotePath, {
      for (final entry in entries) entry.path,
    });
  }

  Future<String> _nextAvailableLocalPath(String desiredLocalPath) async {
    final existingPaths = <String>{};
    final parentPath = p.dirname(desiredLocalPath);
    final parent = Directory(parentPath);
    if (await parent.exists()) {
      await for (final entity in parent.list()) {
        existingPaths.add(entity.path);
      }
    }
    return nextLocalConflictPath(desiredLocalPath, existingPaths);
  }

  Future<void> _renameEntry(SftpEntry entry) async {
    final name = await _showTextInputDialog(
      context,
      title: 'Rename',
      label: 'New name',
      initialValue: entry.name,
      confirmLabel: 'Rename',
    );
    if (name == null || name.trim().isEmpty || name.trim() == entry.name) {
      return;
    }
    await _runSftpOperation(
      () => _connection().rename(
        entry.path,
        _remoteChildPath(_parentPath(entry.path), name.trim()),
      ),
      successMessage: 'Entry renamed.',
    );
  }

  Future<void> _moveEntry(SftpEntry entry) async {
    final target = await _showTextInputDialog(
      context,
      title: 'Move',
      label: 'Target path',
      initialValue: entry.path,
      confirmLabel: 'Move',
    );
    if (target == null || target.trim().isEmpty) {
      return;
    }
    final resolvedTarget = _resolveMoveTarget(target.trim(), entry.name);
    if (resolvedTarget == entry.path) {
      return;
    }
    if (await _remoteEntryExists(resolvedTarget)) {
      if (mounted) {
        _showSnackBar(context, 'Target path already exists.');
      }
      return;
    }
    await _runSftpOperation(
      () => _connection().rename(entry.path, resolvedTarget),
      successMessage: 'Entry moved.',
    );
  }

  Future<void> _chmodEntry(SftpEntry entry) async {
    final octal = await _showTextInputDialog(
      context,
      title: 'Change Permissions',
      label: 'Octal permissions',
      initialValue: entry.permissions?.octal ?? '',
      confirmLabel: 'Apply',
    );
    if (octal == null || !_isOctalPermissions(octal.trim())) {
      if (mounted && octal != null) {
        _showSnackBar(context, 'Permissions must be a 3 or 4 digit octal.');
      }
      return;
    }
    await _runSftpOperation(
      () => _connection().chmod(entry.path, SftpPermissions(octal.trim())),
      successMessage: 'Permissions updated.',
    );
  }

  Future<void> _deleteEntry(SftpEntry entry) async {
    final confirmed = await _confirmDialog(
      context,
      title: 'Delete ${entry.name}?',
      body: entry.type == SftpEntryType.directory
          ? 'This deletes the remote directory and its contents.'
          : 'This deletes the remote file.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed) {
      return;
    }
    await _runSftpOperation(() {
      if (entry.type == SftpEntryType.directory) {
        return _connection().deleteDirectory(entry.path, recursive: true);
      }
      return _connection().deleteFile(entry.path);
    }, successMessage: 'Entry deleted.');
  }

  Future<void> _previewFile(SftpEntry entry) async {
    try {
      final preview = await _connection().readTextPreview(entry.path);
      if (!mounted) {
        return;
      }
      final updatedText = await showDialog<String>(
        context: context,
        builder: (context) => _RemoteFileDialog(entry: entry, preview: preview),
      );
      if (updatedText == null || updatedText == preview.text) {
        return;
      }
      await _runSftpOperation(
        () => _connection().writeTextFile(entry.path, updatedText),
        successMessage: 'File saved.',
      );
    } on Object catch (error) {
      if (mounted) {
        _showSnackBar(context, sftpFailureMessage(error));
      }
    }
  }

  Future<void> _runSftpOperation(
    Future<void> Function() operation, {
    required String successMessage,
  }) async {
    try {
      await operation();
      if (!mounted) {
        return;
      }
      setState(_reload);
      _showSnackBar(context, successMessage);
    } on Object catch (error) {
      if (mounted) {
        _showSnackBar(context, sftpFailureMessage(error));
      }
    }
  }

  SftpConnection _connection() {
    final connection = ref
        .read(workspaceRuntimeRegistryProvider)
        .sftpFor(widget.sessionId);
    if (connection == null) {
      throw StateError('SFTP connection is not active.');
    }
    return connection;
  }

  Future<bool> _remoteEntryExists(String remotePath) async {
    final parent = _parentPath(remotePath);
    final entries = await _connection().list(parent);
    return entries.any((entry) => entry.path == remotePath);
  }
}

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
