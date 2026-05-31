part of '../workspace_screen.dart';

class _HostsSurface extends ConsumerWidget {
  const _HostsSurface();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vaultSession = ref.watch(vaultSessionControllerProvider);
    final controller = ref.read(workspaceTabControllerProvider.notifier);
    final searchQuery = ref.watch(_workspaceSearchQueryProvider);

    return vaultSession.when(
      loading: () => const _PlaceholderSurface(
        title: 'Vault',
        body: 'Preparing encrypted storage',
        loading: true,
      ),
      error: (error, stackTrace) => _VaultAccessSurface(error: error),
      data: (session) {
        if (session.vaultState != VaultState.unlocked) {
          return _VaultAccessSurface(session: session);
        }
        final hostsAsync = ref.watch(hostSummariesProvider);
        final content = hostsAsync.isLoading
            ? const _PlaceholderSurface(
                title: 'Hosts',
                body: 'Loading encrypted host records',
                loading: true,
              )
            : hostsAsync.when(
                loading: () => const _PlaceholderSurface(
                  title: 'Hosts',
                  body: 'Loading encrypted host records',
                  loading: true,
                ),
                error: (error, stackTrace) =>
                    _PlaceholderSurface(title: 'Hosts', body: error.toString()),
                data: (hosts) {
                  final filteredHosts = filterHostSummaries(hosts, searchQuery);
                  if (hosts.isEmpty) {
                    return _HostsEmptyState(
                      onAddHost: () => _showAddHostDialog(context),
                    );
                  }
                  return Column(
                    children: [
                      _HostsHeader(
                        count: filteredHosts.length,
                        onAddHost: () => _showAddHostDialog(context),
                      ),
                      Expanded(
                        child: filteredHosts.isEmpty
                            ? const _PlaceholderSurface(
                                title: 'No Matches',
                                body:
                                    'No hosts match the current workspace search.',
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.all(16),
                                itemCount: filteredHosts.length,
                                separatorBuilder: (context, index) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final host = filteredHosts[index];
                                  return EntranceFade(
                                    key: ValueKey('host-row-${host.id.value}'),
                                    delay: Duration(
                                      milliseconds: 40 * (index.clamp(0, 8)),
                                    ),
                                    child: _HostRow(
                                      host: host,
                                      onTerminal: () =>
                                          controller.openTerminal(host),
                                      onSftp: () => controller.openSftp(host),
                                      onEdit: () =>
                                          _showEditHostDialog(context, host),
                                      onDelete: () => _confirmDeleteHost(
                                        context,
                                        ref,
                                        host,
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  );
                },
              );
        final recoveryKey = session.recoveryKey;
        if (recoveryKey == null) {
          return content;
        }
        return _RecoveryKeyDialogGate(recoveryKey: recoveryKey, child: content);
      },
    );
  }
}

Future<void> _showAddHostDialog(BuildContext context) {
  return showSerlinkDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => const _HostFormDialog(),
  );
}

Future<void> _showEditHostDialog(BuildContext context, HostSummary host) {
  return showSerlinkDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _HostFormDialog(host: host),
  );
}

Future<void> _confirmDeleteHost(
  BuildContext context,
  WidgetRef ref,
  HostSummary host,
) async {
  final confirmed = await _confirmDialog(
    context,
    title: 'Delete host?',
    body:
        'This removes the host and any credentials that are not used by another host.',
    confirmLabel: 'Delete',
    destructive: true,
  );
  if (!confirmed) {
    return;
  }
  try {
    await ref.read(hostWriteServiceProvider).deleteHost(host.id);
    ref.invalidate(hostSummariesProvider);
    if (context.mounted) {
      _showSnackBar(context, 'Host deleted.');
    }
  } on Object {
    if (context.mounted) {
      _showSnackBar(context, 'Host could not be deleted.');
    }
  }
}

class _HostsHeader extends StatelessWidget {
  const _HostsHeader({required this.count, required this.onAddHost});

  final int count;
  final VoidCallback onAddHost;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SurfaceToolbar(
      child: Row(
        children: [
          Text(
            'Hosts',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: t.textPrimary,
            ),
          ),
          const SizedBox(width: 8),
          _CountBadge(count: count),
          const Spacer(),
          SerlinkTooltip(
            message: 'Add host',
            child: SerlinkIconButton(
              key: const ValueKey('add-host-button'),
              onPressed: onAddHost,
              icon: const Icon(Icons.add),
            ),
          ),
        ],
      ),
    );
  }
}

class _HostsEmptyState extends StatelessWidget {
  const _HostsEmptyState({required this.onAddHost});

  final VoidCallback onAddHost;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'No Hosts',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: t.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Import SSH config or add hosts to start a session.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: t.textSecondary),
            ),
            const SizedBox(height: 16),
            SerlinkFilledButton.icon(
              key: const ValueKey('empty-add-host-button'),
              onPressed: onAddHost,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Host'),
            ),
          ],
        ),
      ),
    );
  }
}
