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
        body: 'Preparing encrypted storage.',
      ),
      error: (error, stackTrace) => _VaultAccessSurface(error: error),
      data: (session) {
        if (session.vaultState != VaultState.unlocked) {
          return _VaultAccessSurface(session: session);
        }
        final hostsAsync = ref.watch(hostSummariesProvider);
        final content = hostsAsync.when(
          loading: () => const _PlaceholderSurface(
            title: 'Hosts',
            body: 'Loading encrypted host records.',
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
            return Row(
              children: [
                SizedBox(
                  width: 420,
                  child: Column(
                    children: [
                      _HostsHeader(
                        count: filteredHosts.length,
                        onAddHost: () => _showAddHostDialog(context),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: filteredHosts.isEmpty
                            ? const _PlaceholderSurface(
                                title: 'No Matches',
                                body:
                                    'No hosts match the current workspace search.',
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.all(12),
                                itemCount: filteredHosts.length,
                                separatorBuilder: (context, index) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final host = filteredHosts[index];
                                  return _HostRow(
                                    host: host,
                                    onTerminal: () =>
                                        controller.openTerminal(host),
                                    onSftp: () => controller.openSftp(host),
                                    onBoth: () =>
                                        controller.openTerminalAndSftp(host),
                                    onEdit: () =>
                                        _showEditHostDialog(context, host),
                                    onDelete: () =>
                                        _confirmDeleteHost(context, ref, host),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1),
                const Expanded(child: _WorkspaceHint()),
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
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => const _HostFormDialog(),
  );
}

Future<void> _showEditHostDialog(BuildContext context, HostSummary host) {
  return showDialog<void>(
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
    return SizedBox(
      height: 48,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Text('Hosts', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(width: 8),
            Text(
              count.toString(),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const Spacer(),
            Tooltip(
              message: 'Add host',
              child: IconButton(
                key: const ValueKey('add-host-button'),
                onPressed: onAddHost,
                icon: const Icon(Icons.add),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HostsEmptyState extends StatelessWidget {
  const _HostsEmptyState({required this.onAddHost});

  final VoidCallback onAddHost;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('No Hosts', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Import SSH config or add hosts to start a session.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
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
