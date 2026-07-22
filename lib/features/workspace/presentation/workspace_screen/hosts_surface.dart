part of '../workspace_screen.dart';

final _hostSortOrderProvider =
    NotifierProvider<_HostSortOrderController, _HostSortOrder>(
      _HostSortOrderController.new,
    );

final _hostListEntranceTrackerProvider = Provider<_HostListEntranceTracker>(
  (ref) => _HostListEntranceTracker(),
);

const _hostListEntranceDurationMs = 420;
const _hostListEntranceDuration = Duration(
  milliseconds: _hostListEntranceDurationMs,
);
const _hostListEntranceStaggerMs = 40;
const _hostListEntranceMaxStaggerItems = 8;
const _hostListEntranceSettleDelay = Duration(
  milliseconds:
      _hostListEntranceDurationMs +
      _hostListEntranceStaggerMs * _hostListEntranceMaxStaggerItems +
      40,
);
const _hostListChangeDuration = Duration(milliseconds: 240);

enum _HostSortOrder { addedAt, name, lastConnectedAt }

class _HostSortOrderController extends Notifier<_HostSortOrder> {
  @override
  _HostSortOrder build() => _HostSortOrder.addedAt;

  void setOrder(_HostSortOrder order) {
    state = order;
  }
}

class _HostListEntranceTracker {
  int? _unlockGeneration;

  bool claim(int unlockGeneration) {
    if (_unlockGeneration == unlockGeneration) {
      return false;
    }
    _unlockGeneration = unlockGeneration;
    return true;
  }
}

class _HostsSurface extends ConsumerWidget {
  const _HostsSurface();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final vaultSession = ref.watch(vaultSessionControllerProvider);
    final session = vaultSession.value;
    final vaultBusyReason =
        session?.busyReason ?? ref.watch(vaultSessionBusyReasonProvider);
    final searchQuery = ref.watch(_workspaceSearchQueryProvider);
    final sortOrder = ref.watch(_hostSortOrderProvider);
    final mobile = ref.watch(
      platformCapabilitiesProvider.select(
        (capabilities) => capabilities.prefersMobileWorkspaceShell,
      ),
    );

    return vaultSession.when(
      skipLoadingOnReload: false,
      skipLoadingOnRefresh: false,
      loading: () => _PlaceholderSurface(
        title: l10n.vaultTitle,
        body: _vaultPreparingLabel(l10n, vaultBusyReason),
        loading: true,
      ),
      error: (error, stackTrace) => _VaultAccessSurface(error: error),
      data: (session) {
        if (session.vaultState != VaultState.unlocked) {
          return _VaultAccessSurface(session: session);
        }
        final hostsAsync = ref.watch(
          hostSummariesProvider(session.unlockGeneration),
        );
        final content = hostsAsync.when(
          skipLoadingOnReload: true,
          skipLoadingOnRefresh: true,
          loading: () => _PlaceholderSurface(
            title: l10n.hostsTitle,
            body: l10n.hostsLoading,
            loading: true,
          ),
          error: (error, stackTrace) => _PlaceholderSurface(
            title: l10n.hostsTitle,
            body: error.toString(),
          ),
          data: (hosts) {
            final filteredHosts = _sortHostSummaries(
              filterHostSummaries(hosts, searchQuery),
              sortOrder,
            );
            final contentChangeDuration =
                MediaQuery.maybeOf(context)?.disableAnimations == true
                ? Duration.zero
                : const Duration(milliseconds: 180);
            return Column(
              children: [
                if (!mobile)
                  _HostsHeader(
                    count: filteredHosts.length,
                    sortOrder: sortOrder,
                    onSortOrderChanged: ref
                        .read(_hostSortOrderProvider.notifier)
                        .setOrder,
                    onAddHost: () => _showAddHostDialog(context),
                  ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: contentChangeDuration,
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: hosts.isEmpty
                        ? KeyedSubtree(
                            key: const ValueKey('hosts-empty'),
                            child: _HostsEmptyState(
                              onAddHost: () => _showAddHostDialog(context),
                            ),
                          )
                        : filteredHosts.isEmpty
                        ? KeyedSubtree(
                            key: const ValueKey('hosts-no-matches'),
                            child: _PlaceholderSurface(
                              title: l10n.hostsNoMatchesTitle,
                              body: l10n.hostsNoMatchesBody,
                            ),
                          )
                        : _HostList(
                            key: PageStorageKey(
                              'hosts-list-${session.unlockGeneration}',
                            ),
                            hosts: filteredHosts,
                            unlockGeneration: session.unlockGeneration,
                            mobile: mobile,
                          ),
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

class _HostList extends ConsumerStatefulWidget {
  const _HostList({
    super.key,
    required this.hosts,
    required this.unlockGeneration,
    required this.mobile,
  });

  final List<HostSummary> hosts;
  final int unlockGeneration;
  final bool mobile;

  @override
  ConsumerState<_HostList> createState() => _HostListState();
}

class _HostListState extends ConsumerState<_HostList> {
  final _listKey = GlobalKey<AnimatedListState>();
  Timer? _settleTimer;
  late List<HostSummary> _displayedHosts;
  Set<HostId> _entranceHostIds = const {};
  bool _playEntrance = false;

  @override
  void initState() {
    super.initState();
    _displayedHosts = List.of(widget.hosts);
    _claimEntrance(widget.unlockGeneration);
  }

  @override
  void didUpdateWidget(covariant _HostList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.unlockGeneration != widget.unlockGeneration) {
      _displayedHosts = List.of(widget.hosts);
      _claimEntrance(widget.unlockGeneration);
      return;
    }
    _reconcileHosts(widget.hosts);
  }

  @override
  void dispose() {
    _settleTimer?.cancel();
    super.dispose();
  }

  void _claimEntrance(int unlockGeneration) {
    _settleTimer?.cancel();
    _playEntrance = ref
        .read(_hostListEntranceTrackerProvider)
        .claim(unlockGeneration);
    _entranceHostIds = _playEntrance
        ? {for (final host in _displayedHosts) host.id}
        : const {};
    if (!_playEntrance) {
      return;
    }
    _settleTimer = Timer(_hostListEntranceSettleDelay, () {
      if (mounted) {
        setState(() {
          _playEntrance = false;
          _entranceHostIds = const {};
        });
      }
    });
  }

  void _reconcileHosts(List<HostSummary> nextHosts) {
    final listState = _listKey.currentState;
    if (listState == null) {
      _displayedHosts = List.of(nextHosts);
      return;
    }

    final nextIds = {for (final host in nextHosts) host.id};
    final previousIds = {for (final host in _displayedHosts) host.id};
    final duration = MediaQuery.maybeOf(context)?.disableAnimations == true
        ? Duration.zero
        : _hostListChangeDuration;

    for (var index = _displayedHosts.length - 1; index >= 0; index -= 1) {
      final host = _displayedHosts[index];
      if (nextIds.contains(host.id)) {
        continue;
      }
      _displayedHosts.removeAt(index);
      listState.removeItem(
        index,
        (context, animation) =>
            _buildAnimatedHost(context, host, index, animation, removing: true),
        duration: duration,
      );
    }

    final nextById = {for (final host in nextHosts) host.id: host};
    for (var index = 0; index < _displayedHosts.length; index += 1) {
      _displayedHosts[index] = nextById[_displayedHosts[index].id]!;
    }
    for (var index = 0; index < nextHosts.length; index += 1) {
      final host = nextHosts[index];
      if (previousIds.contains(host.id)) {
        continue;
      }
      _displayedHosts.insert(index, host);
      listState.insertItem(index, duration: duration);
    }

    if (!_sameHostOrder(_displayedHosts, nextHosts)) {
      _displayedHosts = List.of(nextHosts);
    }
  }

  bool _sameHostOrder(List<HostSummary> left, List<HostSummary> right) {
    if (left.length != right.length) {
      return false;
    }
    for (var index = 0; index < left.length; index += 1) {
      if (left[index].id != right[index].id) {
        return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedList(
      key: _listKey,
      padding: widget.mobile
          ? _mobileSurfaceListPadding
          : const EdgeInsets.all(16),
      initialItemCount: _displayedHosts.length,
      itemBuilder: (context, index, animation) =>
          _buildAnimatedHost(context, _displayedHosts[index], index, animation),
    );
  }

  Widget _buildAnimatedHost(
    BuildContext context,
    HostSummary host,
    int index,
    Animation<double> animation, {
    bool removing = false,
  }) {
    final controller = ref.read(workspaceTabControllerProvider.notifier);
    Widget row = KeyedSubtree(
      key: ValueKey('host-row-${host.id.value}'),
      child: _HostRow(
        mobile: widget.mobile,
        host: host,
        onTerminal: () => controller.openTerminal(host),
        onSftp: () => controller.openSftp(host),
        onEdit: () => _showEditHostDialog(context, host),
        onDuplicate: () => _showDuplicateHostDialog(context, host),
        onDelete: () => _confirmDeleteHost(context, ref, host),
      ),
    );
    if (_playEntrance && _entranceHostIds.contains(host.id)) {
      row = EntranceFade(
        duration: _hostListEntranceDuration,
        delay: Duration(
          milliseconds:
              _hostListEntranceStaggerMs *
              math.min(index, _hostListEntranceMaxStaggerItems),
        ),
        child: row,
      );
    }
    return IgnorePointer(
      ignoring: removing,
      child: _HostListChangeTransition(
        animation: animation,
        child: Padding(padding: const EdgeInsets.only(bottom: 8), child: row),
      ),
    );
  }
}

class _HostListChangeTransition extends StatelessWidget {
  const _HostListChangeTransition({
    required this.animation,
    required this.child,
  });

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeOf(context)?.disableAnimations == true) {
      return child;
    }
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return SizeTransition(
      sizeFactor: curved,
      alignment: Alignment.topCenter,
      child: FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.04),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      ),
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
    builder: (context) => _HostFormDialog(host: host, mode: _HostFormMode.edit),
  );
}

Future<void> _showDuplicateHostDialog(BuildContext context, HostSummary host) {
  return showSerlinkDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) =>
        _HostFormDialog(host: host, mode: _HostFormMode.duplicate),
  );
}

Future<void> _confirmDeleteHost(
  BuildContext context,
  WidgetRef ref,
  HostSummary host,
) async {
  final confirmed = await _confirmDialog(
    context,
    title: context.l10n.hostsDeleteTitle,
    body: context.l10n.hostsDeleteBody,
    confirmLabel: context.l10n.hostsDeleteAction,
    destructive: true,
  );
  if (!confirmed) {
    return;
  }
  try {
    await ref.read(hostWriteServiceProvider).deleteHost(host.id);
    ref.invalidate(hostSummariesProvider);
    if (context.mounted) {
      _showSnackBar(context, context.l10n.hostsDeletedSnack);
    }
  } on Object {
    if (context.mounted) {
      _showSnackBar(context, context.l10n.hostsDeleteFailedSnack);
    }
  }
}

class _HostsHeader extends ConsumerWidget {
  const _HostsHeader({
    required this.count,
    required this.sortOrder,
    required this.onSortOrderChanged,
    required this.onAddHost,
  });

  final int count;
  final _HostSortOrder sortOrder;
  final ValueChanged<_HostSortOrder> onSortOrderChanged;
  final VoidCallback onAddHost;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final t = context.tokens;
    final showLocalTerminal = ref.watch(
      platformCapabilitiesProvider.select(
        (capabilities) => capabilities.localTerminal,
      ),
    );
    final workspaceController = ref.read(
      workspaceTabControllerProvider.notifier,
    );
    return SurfaceToolbar(
      child: Row(
        children: [
          Text(
            l10n.hostsTitle,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: t.textPrimary,
            ),
          ),
          const SizedBox(width: 8),
          _CountBadge(count: count),
          const Spacer(),
          Flexible(
            child: _WorkspaceHeaderSearch(
              placeholder: l10n.searchHostsPlaceholder,
            ),
          ),
          const SizedBox(width: 8),
          _HostSortMenuButton(
            selectedOrder: sortOrder,
            onSelected: onSortOrderChanged,
          ),
          if (showLocalTerminal) ...[
            const SizedBox(width: 8),
            SerlinkTooltip(
              message: l10n.openLocalTerminalTooltip,
              child: SerlinkIconButton(
                key: const ValueKey('open-local-terminal-button'),
                constraints: const BoxConstraints.tightFor(
                  width: 30,
                  height: 30,
                ),
                padding: EdgeInsets.zero,
                onPressed: workspaceController.openLocalTerminal,
                icon: const Icon(Icons.terminal_outlined, size: 18),
              ),
            ),
          ],
          const SizedBox(width: 8),
          SerlinkTooltip(
            message: l10n.hostsAddTooltip,
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

class _HostSortMenuButton extends StatelessWidget {
  const _HostSortMenuButton({
    required this.selectedOrder,
    required this.onSelected,
    this.mobile = false,
  });

  final _HostSortOrder selectedOrder;
  final ValueChanged<_HostSortOrder> onSelected;
  final bool mobile;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SerlinkMenuButton(
      key: const ValueKey('sort-hosts-button'),
      tooltip: l10n.hostsSortTooltip,
      icon: const Icon(Icons.sort),
      constraints: mobile
          ? const BoxConstraints.tightFor(
              width: _mobileHeaderActionSide,
              height: _mobileHeaderActionSide,
            )
          : null,
      iconSize: mobile ? _mobileHeaderActionIconSize : null,
      actions: [
        _hostSortAction(
          label: l10n.hostsSortByName,
          order: _HostSortOrder.name,
        ),
        _hostSortAction(
          label: l10n.hostsSortByLastConnected,
          order: _HostSortOrder.lastConnectedAt,
        ),
        _hostSortAction(
          label: l10n.hostsSortByAdded,
          order: _HostSortOrder.addedAt,
        ),
      ],
    );
  }

  SerlinkMenuAction _hostSortAction({
    required String label,
    required _HostSortOrder order,
  }) {
    return SerlinkMenuAction(
      label: label,
      icon: selectedOrder == order ? Icons.check : null,
      onPressed: () => onSelected(order),
    );
  }
}

class _HostsEmptyState extends StatelessWidget {
  const _HostsEmptyState({required this.onAddHost});

  final VoidCallback onAddHost;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.hostsEmptyTitle,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: t.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.hostsEmptyBody,
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
              label: Text(l10n.hostsAddAction),
            ),
          ],
        ),
      ),
    );
  }
}

List<HostSummary> _sortHostSummaries(
  List<HostSummary> hosts,
  _HostSortOrder order,
) {
  final sorted = [...hosts]
    ..sort((left, right) {
      final byPrimary = switch (order) {
        _HostSortOrder.addedAt => _compareDateDesc(
          left.createdAt,
          right.createdAt,
        ),
        _HostSortOrder.name => _compareHostName(left, right),
        _HostSortOrder.lastConnectedAt => _compareNullableDateDesc(
          left.lastConnectedAt,
          right.lastConnectedAt,
        ),
      };
      if (byPrimary != 0) {
        return byPrimary;
      }
      final byAdded = _compareDateDesc(left.createdAt, right.createdAt);
      return byAdded == 0 ? _compareHostName(left, right) : byAdded;
    });
  return sorted;
}

int _compareHostName(HostSummary left, HostSummary right) {
  final byDisplayName = left.displayName.toLowerCase().compareTo(
    right.displayName.toLowerCase(),
  );
  if (byDisplayName != 0) {
    return byDisplayName;
  }
  final byHostname = left.hostname.toLowerCase().compareTo(
    right.hostname.toLowerCase(),
  );
  return byHostname == 0 ? left.id.value.compareTo(right.id.value) : byHostname;
}

int _compareDateDesc(DateTime left, DateTime right) {
  return right.compareTo(left);
}

int _compareNullableDateDesc(DateTime? left, DateTime? right) {
  return switch ((left, right)) {
    (null, null) => 0,
    (null, _) => 1,
    (_, null) => -1,
    (final leftDate?, final rightDate?) => rightDate.compareTo(leftDate),
  };
}
