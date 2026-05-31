part of '../workspace_screen.dart';

class _TransfersSurface extends ConsumerWidget {
  const _TransfersSurface();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final queue = ref.watch(transferQueueStateProvider);
    final state = queue.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TransfersHeader(
          state: state,
          onClear: state == null || state.tasks.isEmpty
              ? null
              : () => unawaited(_clearTransfers(context, ref, state)),
        ),
        Expanded(
          child: queue.when(
            loading: () => _PlaceholderSurface(
              title: l10n.transfersTitle,
              body: l10n.transfersPreparing,
            ),
            error: (error, stackTrace) => _PlaceholderSurface(
              title: l10n.transfersTitle,
              body: error.toString(),
            ),
            data: (state) {
              if (state.tasks.isEmpty) {
                return _PlaceholderSurface(
                  title: l10n.transfersEmptyTitle,
                  body: l10n.transfersEmptyBody,
                );
              }
              return _TransferTaskList(tasks: state.tasks);
            },
          ),
        ),
      ],
    );
  }
}

class _TransfersHeader extends StatelessWidget {
  const _TransfersHeader({required this.state, required this.onClear});

  final TransferQueueState? state;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    final tasks = state?.tasks ?? const <TransferTask>[];
    final activeCount = tasks.where(_transferIsActive).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: Row(
        children: [
          Icon(Icons.swap_vert, size: 19, color: t.textSecondary),
          const SizedBox(width: 10),
          Text(
            l10n.transfersTitle,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: t.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 10),
          SerlinkTag(label: l10n.transfersItemCount(tasks.length)),
          if (activeCount > 0) ...[
            const SizedBox(width: 6),
            StatusPill(
              label: l10n.transfersActiveCount(activeCount),
              color: t.statusInfo,
            ),
          ],
          const Spacer(),
          SerlinkTextButton.icon(
            onPressed: onClear,
            icon: const Icon(Icons.delete_sweep_outlined, size: 17),
            label: Text(l10n.transfersClearAction),
          ),
        ],
      ),
    );
  }
}

class _TransferTaskList extends StatelessWidget {
  const _TransferTaskList({required this.tasks});

  final List<TransferTask> tasks;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      key: const PageStorageKey('transfers-list'),
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      scrollCacheExtent: const ScrollCacheExtent.pixels(960),
      itemCount: tasks.length,
      addAutomaticKeepAlives: false,
      addSemanticIndexes: false,
      findChildIndexCallback: (key) {
        if (key is! ValueKey<String>) {
          return null;
        }
        final position = tasks.indexWhere((task) => task.id.value == key.value);
        if (position == -1) {
          return null;
        }
        return tasks.length - 1 - position;
      },
      itemBuilder: (context, index) {
        final task = tasks[tasks.length - 1 - index];
        return Padding(
          key: ValueKey(task.id.value),
          padding: EdgeInsets.only(bottom: index == tasks.length - 1 ? 0 : 8),
          child: RepaintBoundary(child: _TransferTaskRow(task: task)),
        );
      },
    );
  }
}

class _TransferTaskRow extends ConsumerWidget {
  const _TransferTaskRow({required this.task});

  final TransferTask task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final t = context.tokens;
    final queue = ref.read(transferQueueControllerProvider);
    final progress = task.totalBytes == null || task.totalBytes == 0
        ? null
        : task.transferredBytes / task.totalBytes!;
    final isActive =
        task.state == TransferState.running ||
        task.state == TransferState.paused;
    final canOpen = task.state == TransferState.completed;

    return SerlinkContextMenu(
      actions: [
        SerlinkMenuAction(
          label: l10n.transferDeleteMenu,
          icon: Icons.delete_outline,
          onPressed: () => unawaited(_deleteTransfer(context, ref, task)),
        ),
      ],
      child: MouseRegion(
        cursor: canOpen ? SystemMouseCursors.click : MouseCursor.defer,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onDoubleTap: canOpen
              ? () => unawaited(_openCompletedTransfer(context, task))
              : null,
          child: ListRow(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      task.itemKind == TransferItemKind.directory
                          ? Icons.folder_outlined
                          : task.direction == TransferDirection.upload
                          ? Icons.upload_outlined
                          : Icons.download_outlined,
                      size: 18,
                      color: t.textSecondary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        task.direction == TransferDirection.upload
                            ? _fileName(task.localPath)
                            : _fileName(task.remotePath),
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: t.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    StatusPill(
                      label: _transferStateLabel(l10n, task.state),
                      color: _transferStateColor(task.state, t),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 180),
                      child: SerlinkTag(label: _transferMachineTag(l10n, task)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        task.direction == TransferDirection.upload
                            ? '${task.localPath} -> ${task.remotePath}'
                            : '${task.remotePath} -> ${task.localPath}',
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: t.textSecondary),
                      ),
                    ),
                  ],
                ),
                if (isActive) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: SerlinkRadii.pill,
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 5,
                      backgroundColor: t.surfaceSunken,
                      color: t.accentPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _transferProgressLabel(l10n, task),
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: t.textSecondary),
                  ),
                  if (task.bytesPerSecond != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${_formatBytes(task.bytesPerSecond!.round())}/s'
                      '${task.eta == null ? '' : ' · ${l10n.transferEtaLeft(_formatDuration(task.eta!))}'}',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: t.textMuted),
                    ),
                  ],
                ],
                if (task.state == TransferState.failed &&
                    task.failure != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    task.failure!.message,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: t.statusDanger),
                  ),
                ],
                if (_transferHasInlineActions(task, queue)) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (task.state == TransferState.running)
                        SerlinkTextButton(
                          onPressed: () => queue.pause(task.id),
                          child: Text(l10n.pauseAction),
                        ),
                      if (task.state == TransferState.paused)
                        SerlinkTextButton(
                          onPressed: () => queue.resume(task.id),
                          child: Text(l10n.resumeAction),
                        ),
                      if (queue.canRetry(task.id))
                        SerlinkTextButton(
                          onPressed: () => queue.retry(task.id),
                          child: Text(l10n.retryAction),
                        ),
                      if (task.state == TransferState.running ||
                          task.state == TransferState.paused ||
                          task.state == TransferState.queued)
                        SerlinkTextButton(
                          onPressed: () => queue.cancel(task.id),
                          child: Text(l10n.cancelAction),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _clearTransfers(
  BuildContext context,
  WidgetRef ref,
  TransferQueueState state,
) async {
  final l10n = context.l10n;
  final activeCount = state.tasks.where(_transferIsActive).length;
  final confirmed = await _confirmDialog(
    context,
    title: l10n.transferClearTitle,
    body: activeCount == 0
        ? l10n.transferClearBody(state.tasks.length)
        : l10n.transferClearActiveBody(state.tasks.length, activeCount),
    confirmLabel: l10n.transfersClearAction,
    destructive: true,
  );
  if (!context.mounted || !confirmed) {
    return;
  }
  await ref.read(transferQueueControllerProvider).clear();
  if (context.mounted) {
    _showSnackBar(context, l10n.transferClearedSnack);
  }
}

Future<void> _deleteTransfer(
  BuildContext context,
  WidgetRef ref,
  TransferTask task,
) async {
  final l10n = context.l10n;
  final localType = await FileSystemEntity.type(
    task.localPath,
    followLinks: false,
  );
  if (!context.mounted) {
    return;
  }

  var deleteLocalFile = false;
  if (localType != FileSystemEntityType.notFound) {
    final choice = await _showTransferDeleteDialog(
      context,
      task: task,
      localType: localType,
    );
    if (!context.mounted || choice == null) {
      return;
    }
    deleteLocalFile = choice == _TransferDeleteChoice.transferAndLocalFile;
  }

  await ref.read(transferQueueControllerProvider).delete(task.id);
  if (deleteLocalFile) {
    try {
      await _deleteLocalPath(task.localPath, localType);
    } on Object {
      if (context.mounted) {
        _showSnackBar(context, l10n.transferRemoveLocalFailedSnack);
      }
      return;
    }
  }
  if (context.mounted) {
    _showSnackBar(
      context,
      deleteLocalFile
          ? l10n.transferAndLocalDeletedSnack
          : l10n.transferDeletedSnack,
    );
  }
}

Future<void> _openCompletedTransfer(
  BuildContext context,
  TransferTask task,
) async {
  if (task.state != TransferState.completed) {
    return;
  }
  final localType = await FileSystemEntity.type(task.localPath);
  if (!context.mounted) {
    return;
  }
  if (localType == FileSystemEntityType.notFound) {
    _showSnackBar(context, context.l10n.transferCompletedMissingSnack);
    return;
  }
  try {
    await _openLocalPath(task.localPath);
  } on Object {
    if (context.mounted) {
      _showSnackBar(context, context.l10n.transferOpenFailedSnack);
    }
  }
}

enum _TransferDeleteChoice { transferOnly, transferAndLocalFile }

Future<_TransferDeleteChoice?> _showTransferDeleteDialog(
  BuildContext context, {
  required TransferTask task,
  required FileSystemEntityType localType,
}) {
  final l10n = context.l10n;
  final localKind = _localEntityKindLabel(l10n, localType);
  return showSerlinkDialog<_TransferDeleteChoice>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return SerlinkDialog(
        title: Text(l10n.transferDeleteTitle),
        content: SerlinkAlert.warning(
          message: l10n.transferDeleteLocalBody(localKind, task.localPath),
        ),
        actions: [
          SerlinkTextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancelAction),
          ),
          SerlinkTextButton(
            onPressed: () =>
                Navigator.of(context).pop(_TransferDeleteChoice.transferOnly),
            child: Text(l10n.transferRemoveOnlyAction),
          ),
          SerlinkFilledButton.danger(
            onPressed: () => Navigator.of(
              context,
            ).pop(_TransferDeleteChoice.transferAndLocalFile),
            child: Text(l10n.transferDeleteLocalTooAction(localKind)),
          ),
        ],
      );
    },
  );
}

Future<void> _deleteLocalPath(String path, FileSystemEntityType localType) {
  return switch (localType) {
    FileSystemEntityType.directory => Directory(path).delete(recursive: true),
    FileSystemEntityType.link => Link(path).delete(),
    _ => File(path).delete(),
  };
}

Future<void> _openLocalPath(String path) async {
  final (command, arguments) = switch (Platform.operatingSystem) {
    'macos' => ('open', [path]),
    'windows' => ('explorer', [path]),
    'linux' => ('xdg-open', [path]),
    _ => throw UnsupportedError('Opening files is not supported.'),
  };
  await Process.start(command, arguments, mode: ProcessStartMode.detached);
}

bool _transferHasInlineActions(
  TransferTask task,
  TransferQueueController queue,
) {
  return task.state == TransferState.running ||
      task.state == TransferState.paused ||
      task.state == TransferState.queued ||
      queue.canRetry(task.id);
}

bool _transferIsActive(TransferTask task) {
  return task.state == TransferState.queued ||
      task.state == TransferState.running ||
      task.state == TransferState.paused;
}

String _transferMachineTag(AppLocalizations l10n, TransferTask task) {
  final machine = task.sourceMachineName?.trim();
  final displayName = machine == null || machine.isEmpty
      ? l10n.transferRemoteMachineFallback
      : machine;
  return task.direction == TransferDirection.download
      ? l10n.transferMachineFrom(displayName)
      : l10n.transferMachineTo(displayName);
}

String _localEntityKindLabel(AppLocalizations l10n, FileSystemEntityType type) {
  return switch (type) {
    FileSystemEntityType.directory => l10n.transferFolderKind,
    FileSystemEntityType.link => l10n.transferLinkKind,
    _ => l10n.transferFileKind,
  };
}

String _sourceMachineNameFromTabTitle(AppLocalizations l10n, String title) {
  final name = title.split(' /').first.trim();
  return name.isEmpty ? l10n.transferRemoteMachineFallback : name;
}

Color _transferStateColor(TransferState state, SerlinkTokens t) {
  return switch (state) {
    TransferState.queued => t.textMuted,
    TransferState.running => t.statusInfo,
    TransferState.paused => t.statusWarning,
    TransferState.completed => t.statusSuccess,
    TransferState.failed => t.statusDanger,
    TransferState.canceled => t.textMuted,
  };
}

List<SftpEntry> _sortedEntries(List<SftpEntry> entries) {
  return [...entries]..sort((left, right) {
    final typeCompare = _entryRank(left.type).compareTo(_entryRank(right.type));
    if (typeCompare != 0) {
      return typeCompare;
    }
    return left.name.toLowerCase().compareTo(right.name.toLowerCase());
  });
}

List<SftpEntry> _filterEntries(List<SftpEntry> entries, String filter) {
  final query = filter.trim().toLowerCase();
  if (query.isEmpty) {
    return entries;
  }
  return [
    for (final entry in entries)
      if (entry.name.toLowerCase().contains(query) ||
          entry.path.toLowerCase().contains(query) ||
          (entry.owner?.toLowerCase().contains(query) ?? false) ||
          (entry.group?.toLowerCase().contains(query) ?? false) ||
          (entry.permissions?.octal.contains(query) ?? false))
        entry,
  ];
}

String _sftpEmptyBody(
  AppLocalizations l10n, {
  required List<SftpEntry> allEntries,
  required List<SftpEntry> visibleEntries,
  required String filterText,
  required bool showHidden,
}) {
  if (filterText.trim().isNotEmpty) {
    return l10n.sftpNoEntriesFilter;
  }
  if (!showHidden && allEntries.isNotEmpty && visibleEntries.isEmpty) {
    return l10n.sftpHiddenOnly;
  }
  return l10n.sftpNoVisible;
}

String _sftpEntryMetadataLabel(SftpEntry entry) {
  final ownerGroup = _ownerGroupLabel(entry);
  final parts = [
    if (entry.modifiedAt case final modifiedAt?)
      _shortLocalDateTime(modifiedAt),
    ?ownerGroup,
  ];
  return parts.join(' · ');
}

String? _ownerGroupLabel(SftpEntry entry) {
  final owner = entry.owner?.trim();
  final group = entry.group?.trim();
  if ((owner == null || owner.isEmpty) && (group == null || group.isEmpty)) {
    return null;
  }
  return '${owner?.isEmpty ?? true ? '-' : owner}:'
      '${group?.isEmpty ?? true ? '-' : group}';
}

int _entryRank(SftpEntryType type) {
  return switch (type) {
    SftpEntryType.directory => 0,
    SftpEntryType.symlink => 1,
    SftpEntryType.file => 2,
    SftpEntryType.unknown => 3,
  };
}

String _entryTypeLabel(AppLocalizations l10n, SftpEntryType type) {
  return switch (type) {
    SftpEntryType.directory => l10n.sftpDirectoryLabel,
    SftpEntryType.file => l10n.sftpFileLabel,
    SftpEntryType.symlink => l10n.sftpSymlinkLabel,
    SftpEntryType.unknown => l10n.sftpUnknownLabel,
  };
}

String _formatBytes(int? bytes) {
  if (bytes == null) {
    return '';
  }
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit += 1;
  }
  if (unit == 0) {
    return '$bytes ${units[unit]}';
  }
  return '${value.toStringAsFixed(value >= 10 ? 0 : 1)} ${units[unit]}';
}

String _transferProgressLabel(AppLocalizations l10n, TransferTask task) {
  final total = task.totalBytes;
  if (total == null) {
    return l10n.transferBytesTransferred(_formatBytes(task.transferredBytes));
  }
  return '${_formatBytes(task.transferredBytes)} / ${_formatBytes(total)}';
}

String _transferStateLabel(AppLocalizations l10n, TransferState state) {
  return switch (state) {
    TransferState.queued => l10n.transferStateQueued,
    TransferState.running => l10n.transferStateRunning,
    TransferState.paused => l10n.transferStatePaused,
    TransferState.completed => l10n.transferStateCompleted,
    TransferState.failed => l10n.transferStateFailed,
    TransferState.canceled => l10n.transferStateCanceled,
  };
}

String _formatDuration(Duration duration) {
  final seconds = duration.inSeconds;
  if (seconds < 60) {
    return '${seconds}s';
  }
  final minutes = seconds ~/ 60;
  final remainingSeconds = seconds % 60;
  if (minutes < 60) {
    return '${minutes}m ${remainingSeconds}s';
  }
  final hours = minutes ~/ 60;
  final remainingMinutes = minutes % 60;
  return '${hours}h ${remainingMinutes}m';
}
