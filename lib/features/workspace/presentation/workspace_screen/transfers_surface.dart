part of '../workspace_screen.dart';

class _TransfersSurface extends ConsumerWidget {
  const _TransfersSurface();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(transferQueueStateProvider);
    return queue.when(
      loading: () => const _PlaceholderSurface(
        title: 'Transfers',
        body: 'Preparing transfer queue.',
      ),
      error: (error, stackTrace) =>
          _PlaceholderSurface(title: 'Transfers', body: error.toString()),
      data: (state) {
        if (state.tasks.isEmpty) {
          return const _PlaceholderSurface(
            title: 'No Transfers',
            body: 'SFTP uploads and downloads will appear here.',
          );
        }
        final tasks = [...state.tasks.reversed];
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: tasks.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            return _TransferTaskRow(task: tasks[index]);
          },
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
    final t = context.tokens;
    final queue = ref.read(transferQueueControllerProvider);
    final progress = task.totalBytes == null || task.totalBytes == 0
        ? null
        : task.transferredBytes / task.totalBytes!;
    final isActive =
        task.state == TransferState.running ||
        task.state == TransferState.paused;

    return ListRow(
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
              StatusPill(
                label: _transferStateLabel(task.state),
                color: _transferStateColor(task.state, t),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            task.direction == TransferDirection.upload
                ? '${task.localPath} -> ${task.remotePath}'
                : '${task.remotePath} -> ${task.localPath}',
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: t.textSecondary),
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
              _transferProgressLabel(task),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: t.textSecondary),
            ),
            if (task.bytesPerSecond != null) ...[
              const SizedBox(height: 2),
              Text(
                '${_formatBytes(task.bytesPerSecond!.round())}/s'
                '${task.eta == null ? '' : ' · ${_formatDuration(task.eta!)} left'}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: t.textMuted),
              ),
            ],
          ],
          if (task.state == TransferState.failed && task.failure != null) ...[
            const SizedBox(height: 8),
            Text(
              task.failure!.message,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: t.statusDanger),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (task.state == TransferState.running)
                SerlinkTextButton(
                  onPressed: () => queue.pause(task.id),
                  child: const Text('Pause'),
                ),
              if (task.state == TransferState.paused)
                SerlinkTextButton(
                  onPressed: () => queue.resume(task.id),
                  child: const Text('Resume'),
                ),
              if (queue.canRetry(task.id))
                SerlinkTextButton(
                  onPressed: () => queue.retry(task.id),
                  child: const Text('Retry'),
                ),
              if (task.state == TransferState.running ||
                  task.state == TransferState.paused ||
                  task.state == TransferState.queued)
                SerlinkTextButton(
                  onPressed: () => queue.cancel(task.id),
                  child: const Text('Cancel'),
                ),
            ],
          ),
        ],
      ),
    );
  }
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

String _sftpEmptyBody({
  required List<SftpEntry> allEntries,
  required List<SftpEntry> visibleEntries,
  required String filterText,
  required bool showHidden,
}) {
  if (filterText.trim().isNotEmpty) {
    return 'No entries match the current filter.';
  }
  if (!showHidden && allEntries.isNotEmpty && visibleEntries.isEmpty) {
    return 'This remote directory only contains hidden entries.';
  }
  return 'This remote directory has no visible entries.';
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

String _entryTypeLabel(SftpEntryType type) {
  return switch (type) {
    SftpEntryType.directory => 'Directory',
    SftpEntryType.file => 'File',
    SftpEntryType.symlink => 'Symlink',
    SftpEntryType.unknown => 'Unknown',
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

String _transferProgressLabel(TransferTask task) {
  final total = task.totalBytes;
  if (total == null) {
    return '${_formatBytes(task.transferredBytes)} transferred';
  }
  return '${_formatBytes(task.transferredBytes)} / ${_formatBytes(total)}';
}

String _transferStateLabel(TransferState state) {
  return switch (state) {
    TransferState.queued => 'queued',
    TransferState.running => 'running',
    TransferState.paused => 'paused',
    TransferState.completed => 'completed',
    TransferState.failed => 'failed',
    TransferState.canceled => 'canceled',
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
