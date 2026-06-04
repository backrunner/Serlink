part of '../workspace_screen.dart';

class _SftpPane extends ConsumerStatefulWidget {
  const _SftpPane({
    super.key,
    required this.tabId,
    required this.hostId,
    required this.sourceMachineName,
    required this.sessionId,
    required this.path,
    required this.rootPath,
    required this.lifecycle,
    required this.onOpenTerminal,
  });

  final WorkspaceTabId tabId;
  final HostId? hostId;
  final String sourceMachineName;
  final SessionId sessionId;
  final String path;
  final String rootPath;
  final SessionLifecycleState lifecycle;
  final VoidCallback? onOpenTerminal;

  @override
  ConsumerState<_SftpPane> createState() => _SftpPaneState();
}

class _SftpPaneState extends ConsumerState<_SftpPane> {
  static const _listCacheTtl = Duration(seconds: 5);

  final TextEditingController _filterController = TextEditingController();
  final TextEditingController _pathController = TextEditingController();
  final FocusNode _pathFocusNode = FocusNode();
  final Map<String, _SftpListCacheEntry> _listCache = {};
  Future<List<SftpEntry>>? _entriesFuture;
  String _filterText = '';
  String? _promptedDefaultDirectoryForPath;
  bool _dropUploadActive = false;
  bool _editingPath = false;
  bool _pathSubmitting = false;
  bool _showHidden = false;
  bool _showingDefaultDirectoryPrompt = false;

  @override
  void initState() {
    super.initState();
    _pathController.text = widget.path;
    _pathFocusNode.addListener(_handlePathFocusChanged);
    _reload();
  }

  @override
  void dispose() {
    _pathFocusNode.removeListener(_handlePathFocusChanged);
    _pathFocusNode.dispose();
    _pathController.dispose();
    _filterController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_SftpPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sessionId != widget.sessionId) {
      _invalidateListCache();
      _syncPathControllerToCurrentPath();
      _reload(bypassCache: true);
      return;
    }
    if (oldWidget.path != widget.path ||
        oldWidget.lifecycle != widget.lifecycle) {
      if (oldWidget.path != widget.path) {
        _syncPathControllerToCurrentPath();
      }
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final capabilities = ref.watch(platformCapabilitiesProvider);
    final canList = widget.lifecycle == SessionLifecycleState.connected;
    final canOpenParent = canList && _showParentEntry;
    final canTransferDirectories = capabilities.localDirectoryTransfer;
    final canDropUpload = canList && capabilities.isDesktop;
    final pathContent = _buildPathContent(context, enabled: canList);
    final pathWidget = capabilities.prefersTouchUi
        ? SizedBox(width: _sftpToolbarPathWidth(context), child: pathContent)
        : Expanded(child: pathContent);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: _SftpToolbarContainer(
            scrollable: capabilities.prefersTouchUi,
            child: Row(
              children: [
                const Icon(Icons.folder_open, size: 18),
                const SizedBox(width: 8),
                SerlinkTooltip(
                  message: l10n.sftpParentFolderTooltip,
                  child: SerlinkIconButton(
                    key: const ValueKey('sftp-parent-button'),
                    onPressed: canOpenParent ? _openParentDirectory : null,
                    icon: const Icon(Icons.arrow_upward, size: 18),
                  ),
                ),
                const SizedBox(width: 4),
                pathWidget,
                SizedBox(
                  width: 220,
                  child: _WorkspaceSearchPill(
                    fieldKey: const ValueKey('sftp-search-field'),
                    controller: _filterController,
                    placeholder: l10n.sftpSearchPlaceholder,
                    enabled: canList,
                    hasQuery: _filterText.trim().isNotEmpty,
                    onChanged: (value) {
                      setState(() {
                        _filterText = value;
                      });
                    },
                    onClear: () {
                      _filterController.clear();
                      setState(() {
                        _filterText = '';
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                SerlinkTooltip(
                  message: _showHidden
                      ? l10n.sftpHideHiddenFilesTooltip
                      : l10n.sftpShowHiddenFilesTooltip,
                  child: SerlinkIconButton(
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
                SerlinkTooltip(
                  message: l10n.sftpOpenTerminalTooltip,
                  child: SerlinkIconButton(
                    onPressed: widget.onOpenTerminal,
                    icon: const Icon(Icons.terminal_outlined, size: 18),
                  ),
                ),
                const SizedBox(width: 4),
                SerlinkMenuButton(
                  key: const ValueKey('sftp-upload-button'),
                  tooltip: l10n.uploadAction,
                  enabled: canList,
                  icon: const Icon(Icons.upload_file_outlined, size: 18),
                  actions: [
                    SerlinkMenuAction(
                      label: l10n.sftpUploadFileAction,
                      icon: Icons.insert_drive_file_outlined,
                      onPressed: _enqueueUploadFile,
                    ),
                    if (canTransferDirectories)
                      SerlinkMenuAction(
                        label: l10n.sftpUploadFolderAction,
                        icon: Icons.folder_outlined,
                        onPressed: _enqueueUploadDirectory,
                      ),
                  ],
                ),
                SerlinkTooltip(
                  message: l10n.sftpNewFolderTooltip,
                  child: SerlinkIconButton(
                    key: const ValueKey('sftp-new-folder-button'),
                    onPressed: canList ? _createDirectory : null,
                    icon: const Icon(
                      Icons.create_new_folder_outlined,
                      size: 18,
                    ),
                  ),
                ),
                SerlinkTooltip(
                  message: l10n.sftpRefreshTooltip,
                  child: SerlinkIconButton(
                    onPressed: canList
                        ? () {
                            setState(() => _reload(bypassCache: true));
                          }
                        : null,
                    icon: const Icon(Icons.refresh, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _buildDropUploadTarget(
            enabled: canDropUpload,
            canTransferDirectories: canTransferDirectories,
            child: _SftpDropUploadSurface(
              active: canDropUpload && _dropUploadActive,
              child: _buildBody(
                context,
                canList: canList,
                canTransferDirectories: canTransferDirectories,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropUploadTarget({
    required bool enabled,
    required bool canTransferDirectories,
    required Widget child,
  }) {
    if (!enabled) {
      return child;
    }
    return DropTarget(
      enable: enabled,
      onDragEntered: (_) => _setDropUploadActive(true),
      onDragExited: (_) => _setDropUploadActive(false),
      onDragDone: (details) {
        unawaited(
          _enqueueDroppedUploads(
            details.files,
            canTransferDirectories: canTransferDirectories,
          ),
        );
      },
      child: child,
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required bool canList,
    required bool canTransferDirectories,
  }) {
    final l10n = context.l10n;
    final future = _entriesFuture;
    if (!canList || future == null) {
      return _PlaceholderSurface(
        title: l10n.sftpWaitingTitle,
        body: l10n.sftpWaitingBody,
      );
    }

    return FutureBuilder<List<SftpEntry>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          if (_shouldPromptForDefaultDirectory(snapshot.error!)) {
            _scheduleDefaultDirectoryPrompt(snapshot.error!);
            return _PlaceholderSurface(
              title: l10n.sftpStartFolderTitle,
              body: l10n.sftpStartFolderBody(widget.path),
              action: SerlinkTextButton.icon(
                onPressed: () => _chooseDefaultDirectory(snapshot.error!),
                icon: const Icon(Icons.folder_open_outlined, size: 18),
                label: Text(l10n.chooseFolderAction),
              ),
            );
          }
          return _PlaceholderSurface(
            title: l10n.sftpErrorTitle,
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
            title: _filterText.trim().isEmpty
                ? l10n.sftpEmptyFolderTitle
                : l10n.hostsNoMatchesTitle,
            body: _sftpEmptyBody(
              l10n,
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
                typeLabel: l10n.sftpDirectoryLabel,
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
              typeLabel: _entryTypeLabel(l10n, entry.type),
              icon: isDirectory
                  ? Icons.folder_outlined
                  : Icons.description_outlined,
              sizeLabel: isDirectory ? '' : _formatBytes(entry.size),
              permissionsLabel: entry.permissions?.symbolic ?? '',
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
                      (entry.type == SftpEntryType.directory &&
                          canTransferDirectories)
                  ? () => _enqueueDownload(entry)
                  : null,
            );
          },
        );
      },
    );
  }

  bool get _showParentEntry => !_sameRemotePath(widget.path, widget.rootPath);

  Widget _buildPathContent(BuildContext context, {required bool enabled}) {
    final t = context.tokens;
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: enabled ? t.textPrimary : t.textMuted,
    );
    if (_editingPath) {
      return SerlinkTextField(
        key: const ValueKey('sftp-path-field'),
        controller: _pathController,
        enabled: enabled,
        focusNode: _pathFocusNode,
        readOnly: _pathSubmitting,
        autofocus: true,
        autocorrect: false,
        enableSuggestions: false,
        selectAllOnFocus: true,
        textInputAction: TextInputAction.go,
        style: style,
        decoration: const InputDecoration(
          isCollapsed: true,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          filled: false,
        ),
        onSubmitted: (_) => _submitPath(),
      );
    }
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      child: GestureDetector(
        key: const ValueKey('sftp-path-display'),
        behavior: HitTestBehavior.translucent,
        onTap: enabled ? _startPathEditing : null,
        child: Text(widget.path, overflow: TextOverflow.ellipsis, style: style),
      ),
    );
  }

  void _startPathEditing() {
    if (_editingPath) {
      return;
    }
    setState(() {
      _editingPath = true;
      _pathSubmitting = false;
      _pathController.text = widget.path;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_editingPath) {
        return;
      }
      _pathFocusNode.requestFocus();
      _selectPathText();
    });
  }

  void _handlePathFocusChanged() {
    if (_pathFocusNode.hasFocus || !_editingPath || _pathSubmitting) {
      return;
    }
    setState(() {
      _editingPath = false;
      _pathController.text = widget.path;
    });
  }

  Future<void> _submitPath() async {
    if (_pathSubmitting) {
      return;
    }
    final rawPath = _pathController.text.trim();
    if (rawPath.isEmpty || !rawPath.startsWith('/')) {
      _showPathValidationMessage(context.l10n.sftpAbsolutePathError);
      return;
    }
    final normalizedPath = _joinRemotePath(rawPath);
    if (_sameRemotePath(normalizedPath, widget.path)) {
      setState(() {
        _editingPath = false;
        _pathController.text = widget.path;
      });
      _pathFocusNode.unfocus();
      return;
    }
    setState(() {
      _pathSubmitting = true;
    });
    try {
      await _listDirectory(_connection(), normalizedPath, bypassCache: true);
      if (!mounted) {
        return;
      }
      setState(() {
        _editingPath = false;
        _pathSubmitting = false;
        _pathController.text = normalizedPath;
      });
      _pathFocusNode.unfocus();
      _openDirectory(normalizedPath);
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _pathSubmitting = false;
      });
      _showPathValidationMessage(sftpFailureMessage(error));
    }
  }

  void _showPathValidationMessage(String message) {
    _pathFocusNode.requestFocus();
    _selectPathText();
    _showSnackBar(context, message);
  }

  void _selectPathText() {
    _pathController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _pathController.text.length,
    );
  }

  void _syncPathControllerToCurrentPath() {
    _editingPath = false;
    _pathSubmitting = false;
    _pathController.text = widget.path;
  }

  void _reload({bool bypassCache = false}) {
    final connection = ref
        .read(workspaceRuntimeRegistryProvider)
        .sftpFor(widget.sessionId);
    _entriesFuture = connection == null
        ? null
        : _listDirectory(connection, widget.path, bypassCache: bypassCache);
  }

  Future<List<SftpEntry>> _listDirectory(
    SftpConnection connection,
    String path, {
    bool bypassCache = false,
  }) async {
    final normalizedPath = _joinRemotePath(path);
    if (!bypassCache) {
      final cached = _listCache[normalizedPath];
      if (cached != null &&
          DateTime.now().difference(cached.cachedAt) < _listCacheTtl) {
        return cached.entries;
      }
    }
    final entries = await connection.list(normalizedPath);
    _listCache[normalizedPath] = _SftpListCacheEntry(
      entries: List<SftpEntry>.unmodifiable(entries),
      cachedAt: DateTime.now(),
    );
    return entries;
  }

  void _invalidateListCache([String? path]) {
    if (path == null) {
      _listCache.clear();
      return;
    }
    _listCache.remove(_joinRemotePath(path));
  }

  void _openParentDirectory() {
    _openDirectory(_parentPath(widget.path));
  }

  bool _shouldPromptForDefaultDirectory(Object error) {
    if (widget.hostId == null ||
        !_sameRemotePath(widget.path, widget.rootPath)) {
      return false;
    }
    final failure = sftpFailureFrom(error);
    return failure.code == SftpFailureCode.notFound ||
        failure.code == SftpFailureCode.permissionDenied;
  }

  void _scheduleDefaultDirectoryPrompt(Object error) {
    if (_showingDefaultDirectoryPrompt ||
        _promptedDefaultDirectoryForPath == widget.path) {
      return;
    }
    _promptedDefaultDirectoryForPath = widget.path;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_chooseDefaultDirectory(error));
    });
  }

  Future<void> _chooseDefaultDirectory(Object error) async {
    if (_showingDefaultDirectoryPrompt) {
      return;
    }
    setState(() {
      _showingDefaultDirectoryPrompt = true;
    });
    final selectedPath = await showSerlinkDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _SftpDefaultDirectoryDialog(
        initialValue: _sameRemotePath(widget.rootPath, '/')
            ? ''
            : widget.rootPath,
        failedPath: widget.path,
        failureMessage: sftpFailureMessage(error),
      ),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _showingDefaultDirectoryPrompt = false;
    });
    if (selectedPath == null) {
      return;
    }
    final normalizedPath = _joinRemotePath(selectedPath);
    try {
      await _listDirectory(_connection(), normalizedPath, bypassCache: true);
      final hostId = widget.hostId;
      if (hostId != null) {
        await ref
            .read(hostWriteServiceProvider)
            .updateSftpDefaultDirectory(hostId, normalizedPath);
        ref.invalidate(hostSummariesProvider);
      }
      ref
          .read(workspaceTabControllerProvider.notifier)
          .setSftpRootDirectory(widget.tabId, normalizedPath);
    } on Object catch (validationError) {
      if (!mounted) {
        return;
      }
      setState(() {
        _promptedDefaultDirectoryForPath = null;
      });
      _showSnackBar(context, sftpFailureMessage(validationError));
    }
  }

  void _openDirectory(String path) {
    ref
        .read(workspaceTabControllerProvider.notifier)
        .changeSftpDirectory(widget.tabId, path);
  }

  void _setDropUploadActive(bool value) {
    if (!mounted || _dropUploadActive == value) {
      return;
    }
    setState(() {
      _dropUploadActive = value;
    });
  }

  Future<void> _createDirectory() async {
    final l10n = context.l10n;
    final name = await _showTextInputDialog(
      context,
      title: l10n.sftpNewFolderTitle,
      label: l10n.sftpFolderNameLabel,
      confirmLabel: l10n.createAction,
    );
    if (name == null || name.trim().isEmpty) {
      return;
    }
    await _runSftpOperation(
      () => _connection().mkdir(_remoteChildPath(widget.path, name.trim())),
      successMessage: l10n.sftpFolderCreatedSnack,
    );
  }

  Future<void> _enqueueUploadFile() async {
    final l10n = context.l10n;
    final file = await ref
        .read(documentGatewayProvider)
        .pickUploadFile(confirmButtonText: l10n.uploadAction);
    if (file == null) {
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
          sourceHostId: widget.hostId,
          sourceMachineName: widget.sourceMachineName,
          localPath: file.path,
          remotePath: remotePath,
        );
    _invalidateListCache(widget.path);
    if (mounted) {
      _showSnackBar(context, l10n.sftpUploadQueuedSnack);
    }
  }

  Future<void> _enqueueUploadDirectory() async {
    final l10n = context.l10n;
    final directoryPath = await ref
        .read(documentGatewayProvider)
        .pickUploadDirectory(confirmButtonText: l10n.uploadAction);
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
          sourceHostId: widget.hostId,
          sourceMachineName: widget.sourceMachineName,
          localPath: directoryPath,
          remotePath: remotePath,
        );
    _invalidateListCache(widget.path);
    if (mounted) {
      _showSnackBar(context, l10n.sftpFolderUploadQueuedSnack);
    }
  }

  Future<void> _enqueueDroppedUploads(
    List<DropItem> items, {
    required bool canTransferDirectories,
  }) async {
    _setDropUploadActive(false);
    var queued = 0;
    var queuedDirectory = false;
    for (final item in items) {
      if (!mounted) {
        return;
      }
      final kind = await _enqueueDroppedUpload(
        item,
        canTransferDirectories: canTransferDirectories,
      );
      if (kind == null) {
        continue;
      }
      queued += 1;
      queuedDirectory = queuedDirectory || kind == TransferItemKind.directory;
    }
    if (queued == 0 || !mounted) {
      return;
    }
    _invalidateListCache(widget.path);
    _showSnackBar(
      context,
      queued == 1 && queuedDirectory
          ? context.l10n.sftpFolderUploadQueuedSnack
          : context.l10n.sftpUploadQueuedSnack,
    );
  }

  Future<TransferItemKind?> _enqueueDroppedUpload(
    DropItem item, {
    required bool canTransferDirectories,
  }) async {
    final localPath = item.path.trim();
    if (localPath.isEmpty) {
      return null;
    }
    final itemKind = await _droppedItemKind(
      item,
      localPath,
      canTransferDirectories: canTransferDirectories,
    );
    if (itemKind == null) {
      return null;
    }
    final name = _droppedItemName(item, localPath);
    if (name == null) {
      return null;
    }
    final remotePath = await _resolveRemoteTransferConflict(
      desiredRemotePath: _remoteChildPath(widget.path, name),
      itemKind: itemKind,
    );
    if (remotePath == null) {
      return null;
    }
    ref
        .read(transferQueueControllerProvider)
        .enqueueUpload(
          connection: _connection(),
          itemKind: itemKind,
          sourceHostId: widget.hostId,
          sourceMachineName: widget.sourceMachineName,
          localPath: localPath,
          remotePath: remotePath,
        );
    return itemKind;
  }

  Future<TransferItemKind?> _droppedItemKind(
    DropItem item,
    String localPath, {
    required bool canTransferDirectories,
  }) async {
    if (item is DropItemDirectory) {
      return canTransferDirectories ? TransferItemKind.directory : null;
    }
    final type = await FileSystemEntity.type(localPath);
    return switch (type) {
      FileSystemEntityType.directory =>
        canTransferDirectories ? TransferItemKind.directory : null,
      FileSystemEntityType.file ||
      FileSystemEntityType.link => TransferItemKind.file,
      FileSystemEntityType.notFound => null,
      _ => null,
    };
  }

  Future<void> _enqueueDownload(SftpEntry entry) async {
    final l10n = context.l10n;
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
          sourceHostId: widget.hostId,
          sourceMachineName: widget.sourceMachineName,
          remotePath: entry.path,
          localPath: localPath,
        );
    if (mounted) {
      _showSnackBar(
        context,
        itemKind == TransferItemKind.directory
            ? l10n.sftpFolderDownloadQueuedSnack
            : l10n.sftpDownloadQueuedSnack,
      );
    }
  }

  Future<String?> _pickFileDownloadPath(SftpEntry entry) async {
    final location = await ref
        .read(documentGatewayProvider)
        .pickFileDownloadPath(suggestedName: entry.name);
    if (location == null || location.isEmpty) {
      return null;
    }
    return _resolveLocalTransferConflict(
      desiredLocalPath: location,
      itemKind: TransferItemKind.file,
    );
  }

  Future<String?> _pickDirectoryDownloadPath(SftpEntry entry) async {
    final l10n = context.l10n;
    final location = await ref
        .read(documentGatewayProvider)
        .pickDirectoryDownloadPath(
          suggestedName: entry.name,
          confirmButtonText: l10n.downloadAction,
        );
    if (location == null || location.isEmpty) {
      return null;
    }
    return _resolveLocalTransferConflict(
      desiredLocalPath: location,
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
          ? context.l10n.sftpMergeRemoteFolderTitle
          : context.l10n.sftpReplaceRemoteFileTitle,
      body: itemKind == TransferItemKind.directory
          ? context.l10n.sftpRemoteExistsOverwriteBody(desiredRemotePath)
          : context.l10n.sftpRemoteExistsBody(desiredRemotePath),
      replaceLabel: itemKind == TransferItemKind.directory
          ? context.l10n.mergeAction
          : context.l10n.replaceAction,
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
          ? context.l10n.sftpMergeLocalFolderTitle
          : context.l10n.sftpReplaceLocalFileTitle,
      body: itemKind == TransferItemKind.directory
          ? context.l10n.sftpLocalExistsOverwriteBody(desiredLocalPath)
          : context.l10n.sftpLocalExistsBody(desiredLocalPath),
      replaceLabel: itemKind == TransferItemKind.directory
          ? context.l10n.mergeAction
          : context.l10n.replaceAction,
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
    final entries = await _listDirectory(
      _connection(),
      parent,
      bypassCache: true,
    );
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
    final l10n = context.l10n;
    final name = await _showTextInputDialog(
      context,
      title: l10n.renameAction,
      label: l10n.sftpNewNameLabel,
      initialValue: entry.name,
      confirmLabel: l10n.renameAction,
    );
    if (name == null || name.trim().isEmpty || name.trim() == entry.name) {
      return;
    }
    await _runSftpOperation(
      () => _connection().rename(
        entry.path,
        _remoteChildPath(_parentPath(entry.path), name.trim()),
      ),
      successMessage: l10n.sftpEntryRenamedSnack,
    );
  }

  Future<void> _moveEntry(SftpEntry entry) async {
    final l10n = context.l10n;
    final target = await _showTextInputDialog(
      context,
      title: l10n.moveAction,
      label: l10n.sftpTargetPathLabel,
      initialValue: entry.path,
      confirmLabel: l10n.moveAction,
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
        _showSnackBar(context, l10n.sftpTargetExistsSnack);
      }
      return;
    }
    await _runSftpOperation(
      () => _connection().rename(entry.path, resolvedTarget),
      successMessage: l10n.sftpEntryMovedSnack,
    );
  }

  Future<void> _chmodEntry(SftpEntry entry) async {
    final l10n = context.l10n;
    final input = await _showTextInputDialog(
      context,
      title: l10n.sftpChangePermissionsTitle,
      label: l10n.sftpOctalPermissionsLabel,
      initialValue: entry.permissions?.symbolic ?? '',
      confirmLabel: l10n.applyAction,
    );
    final permissions = input == null ? null : SftpPermissions.tryParse(input);
    if (permissions == null) {
      if (mounted && input != null) {
        _showSnackBar(context, l10n.sftpPermissionsOctalError);
      }
      return;
    }
    await _runSftpOperation(
      () => _connection().chmod(entry.path, permissions),
      successMessage: l10n.sftpPermissionsUpdatedSnack,
    );
  }

  Future<void> _deleteEntry(SftpEntry entry) async {
    final l10n = context.l10n;
    final confirmed = await _confirmDialog(
      context,
      title: l10n.sftpDeleteEntryTitle(entry.name),
      body: entry.type == SftpEntryType.directory
          ? l10n.sftpDeleteDirectoryBody
          : l10n.sftpDeleteFileBody,
      confirmLabel: l10n.deleteAction,
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
    }, successMessage: l10n.sftpEntryDeletedSnack);
  }

  Future<void> _previewFile(SftpEntry entry) async {
    final l10n = context.l10n;
    try {
      final preview = await _connection().readTextPreview(entry.path);
      if (!mounted) {
        return;
      }
      final updatedText = await showSerlinkDialog<String>(
        context: context,
        builder: (context) => _RemoteFileDialog(entry: entry, preview: preview),
      );
      if (updatedText == null || updatedText == preview.text) {
        return;
      }
      await _runSftpOperation(
        () => _connection().writeTextFile(entry.path, updatedText),
        successMessage: l10n.sftpFileSavedSnack,
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
      setState(() {
        _invalidateListCache();
        _reload(bypassCache: true);
      });
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
    final entries = await _listDirectory(
      _connection(),
      parent,
      bypassCache: true,
    );
    return entries.any((entry) => entry.path == remotePath);
  }
}

class _SftpListCacheEntry {
  const _SftpListCacheEntry({required this.entries, required this.cachedAt});

  final List<SftpEntry> entries;
  final DateTime cachedAt;
}

class _SftpDropUploadSurface extends StatelessWidget {
  const _SftpDropUploadSurface({required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Stack(
      children: [
        Positioned.fill(child: child),
        if (active)
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: t.accentPrimary.withValues(alpha: 0.08),
                  border: Border.all(
                    color: t.accentPrimary.withValues(alpha: 0.7),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: t.surfaceGlass,
                      border: Border.all(
                        color: t.accentPrimary.withValues(alpha: 0.45),
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.upload_file_outlined,
                      size: 30,
                      color: t.accentPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

double _sftpToolbarPathWidth(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  return math.max(140, math.min(360, width * 0.32));
}

class _SftpToolbarContainer extends StatelessWidget {
  const _SftpToolbarContainer({required this.scrollable, required this.child});

  final bool scrollable;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!scrollable) {
      return child;
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: child,
    );
  }
}
