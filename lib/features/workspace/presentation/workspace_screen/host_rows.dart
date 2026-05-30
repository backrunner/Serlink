part of '../workspace_screen.dart';

class _HostRow extends StatelessWidget {
  const _HostRow({
    required this.host,
    required this.onTerminal,
    required this.onSftp,
    required this.onBoth,
    required this.onEdit,
    required this.onDelete,
  });

  final HostSummary host;
  final VoidCallback onTerminal;
  final VoidCallback onSftp;
  final VoidCallback onBoth;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final subtitle = '${host.username}@${host.hostname}:${host.port}';

    return ListRow(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  host.displayName,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: t.textPrimary,
                  ),
                ),
              ),
              _TrustText(state: host.trustState),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: t.textSecondary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            overflow: TextOverflow.ellipsis,
          ),
          if (host.tags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final tag in host.tags) Chip(label: Text(tag))],
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: onTerminal,
                icon: const Icon(Icons.terminal, size: 16),
                label: const Text('Terminal'),
              ),
              OutlinedButton.icon(
                onPressed: onSftp,
                icon: const Icon(Icons.folder_open, size: 16),
                label: const Text('SFTP'),
              ),
              IconButton(
                tooltip: 'Open terminal and SFTP',
                onPressed: onBoth,
                icon: const Icon(Icons.splitscreen_outlined),
              ),
              IconButton(
                key: ValueKey('host-edit-${host.id.value}'),
                tooltip: 'Edit host',
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                key: ValueKey('host-delete-${host.id.value}'),
                tooltip: 'Delete host',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrustText extends StatelessWidget {
  const _TrustText({required this.state});

  final HostTrustState state;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = switch (state) {
      HostTrustState.trusted => t.statusSuccess,
      HostTrustState.unknown => t.statusWarning,
      HostTrustState.changed => t.statusDanger,
    };
    final label = switch (state) {
      HostTrustState.trusted => 'trusted',
      HostTrustState.unknown => 'verify',
      HostTrustState.changed => 'changed',
    };
    return StatusPill(label: label, color: color);
  }
}

class _WorkspaceHint extends StatelessWidget {
  const _WorkspaceHint();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Text(
          'Open a host as Terminal, SFTP, or both. Tabs share one workspace and reconnect in place.',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: context.tokens.textSecondary),
        ),
      ),
    );
  }
}
