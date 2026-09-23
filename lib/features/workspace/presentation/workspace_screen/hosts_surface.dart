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

final _collapsedHostGroupsProvider =
    NotifierProvider<_CollapsedHostGroupsController, Set<String>>(
      _CollapsedHostGroupsController.new,
    );

class _CollapsedHostGroupsController extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  void toggle(String groupKey) {
    final next = {...state};
    if (!next.add(groupKey)) {
      next.remove(groupKey);
    }
    state = next;
  }

  void expand(String groupKey) {
    state = {...state}..remove(groupKey);
  }
}

sealed class _HostListEntry {
  String get key;
}

class _HostEntry extends _HostListEntry {
  _HostEntry(this.host);

  final HostSummary host;

  @override
  String get key => 'host-${host.id.value}';
}

class _HostGroupEntry extends _HostListEntry {
  _HostGroupEntry({
    required this.groupId,
    required this.label,
    required this.count,
    required this.collapsed,
  });

  final String? groupId;
  final String label;
  final int count;
  final bool collapsed;

  @override
  String get key => 'group-${groupId ?? ''}';
}

List<_HostListEntry> _buildHostListEntries(
  List<HostSummary> hosts,
  Set<String> collapsedGroups, {
  required String ungroupedLabel,
  required List<String> savedGroups,
}) {
  final grouped = <String, List<HostSummary>>{
    for (final name in savedGroups) name: [],
  };
  final ungrouped = <HostSummary>[];
  for (final host in hosts) {
    final groupId = host.groupId;
    if (groupId == null) {
      ungrouped.add(host);
    } else {
      grouped.putIfAbsent(groupId, () => []).add(host);
    }
  }
  if (grouped.isEmpty) {
    return [for (final host in hosts) _HostEntry(host)];
  }
  final groupIds = grouped.keys.toList()
    ..sort((left, right) => left.toLowerCase().compareTo(right.toLowerCase()));
  final entries = <_HostListEntry>[];
  void addGroup(String? groupId, String label, List<HostSummary> members) {
    final key = groupId ?? '';
    final collapsed = collapsedGroups.contains(key);
    entries.add(
      _HostGroupEntry(
        groupId: groupId,
        label: label,
        count: members.length,
        collapsed: collapsed,
      ),
    );
    if (!collapsed) {
      entries.addAll([for (final host in members) _HostEntry(host)]);
    }
  }

  for (final groupId in groupIds) {
    addGroup(groupId, groupId, grouped[groupId]!);
  }
  addGroup(null, ungroupedLabel, ungrouped);
  return entries;
}

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
        final groupsAsync = ref.watch(
          hostGroupNamesProvider(session.unlockGeneration),
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
            if (!groupsAsync.hasValue) {
              return _PlaceholderSurface(
                title: l10n.hostsTitle,
                body: groupsAsync.hasError
                    ? l10n.hostGroupLoadFailed
                    : l10n.hostsLoading,
                loading: !groupsAsync.hasError,
              );
            }
            final savedGroups = groupsAsync.requireValue;
            final filteredHosts = _sortHostSummaries(
              filterHostSummaries(hosts, searchQuery),
              sortOrder,
            );
            // While searching, expand all groups so matches stay visible.
            final collapsedGroups =
                normalizeWorkspaceSearchQuery(searchQuery) == null
                ? ref.watch(_collapsedHostGroupsProvider)
                : const <String>{};
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
                  child: SerlinkContextMenu(
                    key: const ValueKey('hosts-background-menu'),
                    enabled: !mobile,
                    actions: [
                      SerlinkMenuAction(
                        label: l10n.hostGroupNew,
                        icon: Icons.create_new_folder_outlined,
                        onPressed: () => _showCreateHostGroupDialog(context),
                      ),
                    ],
                    child: AnimatedSwitcher(
                      duration: contentChangeDuration,
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      child: hosts.isEmpty && savedGroups.isEmpty
                          ? KeyedSubtree(
                              key: const ValueKey('hosts-empty'),
                              child: _HostsEmptyState(
                                onAddHost: () => _showAddHostDialog(context),
                              ),
                            )
                          : filteredHosts.isEmpty &&
                                normalizeWorkspaceSearchQuery(searchQuery) !=
                                    null
                          ? KeyedSubtree(
                              key: const ValueKey('hosts-no-matches'),
                              child: _PlaceholderSurface(
                                icon: Icons.search_off_outlined,
                                title: l10n.hostsNoMatchesTitle,
                                body: l10n.hostsNoMatchesBody,
                              ),
                            )
                          : _HostList(
                              key: PageStorageKey(
                                'hosts-list-${session.unlockGeneration}',
                              ),
                              entries: _buildHostListEntries(
                                filteredHosts,
                                collapsedGroups,
                                ungroupedLabel: l10n.hostsUngroupedGroup,
                                savedGroups:
                                    normalizeWorkspaceSearchQuery(
                                          searchQuery,
                                        ) ==
                                        null
                                    ? savedGroups
                                    : const [],
                              ),
                              unlockGeneration: session.unlockGeneration,
                              mobile: mobile,
                            ),
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
    required this.entries,
    required this.unlockGeneration,
    required this.mobile,
  });

  final List<_HostListEntry> entries;
  final int unlockGeneration;
  final bool mobile;

  @override
  ConsumerState<_HostList> createState() => _HostListState();
}

class _HostListState extends ConsumerState<_HostList> {
  final _listKey = GlobalKey<AnimatedListState>();
  Timer? _settleTimer;
  late List<_HostListEntry> _displayedEntries;
  Set<HostId> _entranceHostIds = const {};
  bool _playEntrance = false;

  @override
  void initState() {
    super.initState();
    _displayedEntries = List.of(widget.entries);
    _claimEntrance(widget.unlockGeneration);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A return visit should reveal the settled list, even if navigation
    // interrupted its initial entrance animation.
    if (!TickerMode.valuesOf(context).enabled ||
        MediaQuery.disableAnimationsOf(context)) {
      _settleTimer?.cancel();
      _playEntrance = false;
      _entranceHostIds = const {};
    }
  }

  @override
  void didUpdateWidget(covariant _HostList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.unlockGeneration != widget.unlockGeneration) {
      _displayedEntries = List.of(widget.entries);
      _claimEntrance(widget.unlockGeneration);
      return;
    }
    _reconcileEntries(widget.entries);
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
        ? {
            for (final entry in _displayedEntries)
              if (entry is _HostEntry) entry.host.id,
          }
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

  void _reconcileEntries(List<_HostListEntry> nextEntries) {
    final listState = _listKey.currentState;
    if (listState == null) {
      _displayedEntries = List.of(nextEntries);
      return;
    }

    final nextKeys = {for (final entry in nextEntries) entry.key};
    final previousKeys = {for (final entry in _displayedEntries) entry.key};
    final duration = MediaQuery.maybeOf(context)?.disableAnimations == true
        ? Duration.zero
        : _hostListChangeDuration;

    for (var index = _displayedEntries.length - 1; index >= 0; index -= 1) {
      final entry = _displayedEntries[index];
      if (nextKeys.contains(entry.key)) {
        continue;
      }
      _displayedEntries.removeAt(index);
      listState.removeItem(
        index,
        (context, animation) => _buildAnimatedEntry(
          context,
          entry,
          index,
          animation,
          removing: true,
        ),
        duration: duration,
      );
    }

    final nextByKey = {for (final entry in nextEntries) entry.key: entry};
    for (var index = 0; index < _displayedEntries.length; index += 1) {
      _displayedEntries[index] = nextByKey[_displayedEntries[index].key]!;
    }
    for (var index = 0; index < nextEntries.length; index += 1) {
      final entry = nextEntries[index];
      if (previousKeys.contains(entry.key)) {
        continue;
      }
      _displayedEntries.insert(index, entry);
      listState.insertItem(index, duration: duration);
    }

    if (!_sameEntryOrder(_displayedEntries, nextEntries)) {
      _displayedEntries = List.of(nextEntries);
    }
  }

  bool _sameEntryOrder(List<_HostListEntry> left, List<_HostListEntry> right) {
    if (left.length != right.length) {
      return false;
    }
    for (var index = 0; index < left.length; index += 1) {
      if (left[index].key != right[index].key) {
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
          : SerlinkSizes.listPadding,
      initialItemCount: _displayedEntries.length,
      itemBuilder: (context, index, animation) => _buildAnimatedEntry(
        context,
        _displayedEntries[index],
        index,
        animation,
      ),
    );
  }

  Widget _buildAnimatedEntry(
    BuildContext context,
    _HostListEntry entry,
    int index,
    Animation<double> animation, {
    bool removing = false,
  }) {
    final Widget child = switch (entry) {
      _HostGroupEntry() => _buildGroupHeader(context, entry),
      _HostEntry() => _buildHostRow(context, entry.host, index),
    };
    return IgnorePointer(
      ignoring: removing,
      child: _HostListChangeTransition(
        animation: animation,
        child: Padding(padding: const EdgeInsets.only(bottom: 8), child: child),
      ),
    );
  }

  Widget _buildGroupHeader(BuildContext context, _HostGroupEntry entry) {
    return _HostGroupHeader(
      key: ValueKey('host-group-${entry.groupId ?? ''}'),
      entry: entry,
      onToggle: () => ref
          .read(_collapsedHostGroupsProvider.notifier)
          .toggle(entry.groupId ?? ''),
      onDrop: widget.mobile ? null : (host) => _moveHost(host, entry.groupId),
    );
  }

  Future<void> _moveHost(HostSummary host, String? groupId) async {
    try {
      await ref
          .read(hostWriteServiceProvider)
          .moveHostToGroup(host.id, groupId);
      if (!mounted) return;
      ref.invalidate(hostSummariesProvider);
      ref.invalidate(hostGroupNamesProvider);
      ref.read(_collapsedHostGroupsProvider.notifier).expand(groupId ?? '');
    } on Object {
      if (mounted) _showSnackBar(context, context.l10n.hostGroupMoveFailed);
    }
  }

  Widget _buildHostRow(BuildContext context, HostSummary host, int index) {
    final controller = ref.read(workspaceTabControllerProvider.notifier);
    Widget row = _HostRow(
      mobile: widget.mobile,
      host: host,
      onTerminal: () => controller.openTerminal(host),
      onSftp: () => controller.openSftp(host),
      onEdit: () => _showEditHostDialog(context, host),
      onDuplicate: () => _showDuplicateHostDialog(context, host),
      onDelete: () => _confirmDeleteHost(context, ref, host),
    );
    if (!widget.mobile) {
      row = _HostDraggable(
        data: host,
        feedback: Material(
          color: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 280),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: context.tokens.surfaceRaised,
              borderRadius: SerlinkRadii.control,
              border: Border.all(color: context.tokens.accentPrimary),
            ),
            child: Text(host.displayName, overflow: TextOverflow.ellipsis),
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.4, child: row),
        child: row,
      );
    }
    row = KeyedSubtree(key: ValueKey('host-row-${host.id.value}'), child: row);
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
    return row;
  }
}

class _HostDraggable extends Draggable<HostSummary> {
  const _HostDraggable({
    required super.data,
    required super.feedback,
    required super.childWhenDragging,
    required super.child,
  }) : super(maxSimultaneousDrags: 1);

  @override
  MultiDragGestureRecognizer createRecognizer(
    GestureMultiDragStartCallback onStart,
  ) {
    return ImmediateMultiDragGestureRecognizer(
      supportedDevices: const {PointerDeviceKind.mouse},
      allowedButtonsFilter: (buttons) => buttons == kPrimaryButton,
    )..onStart = onStart;
  }
}

class _HostGroupHeader extends StatelessWidget {
  const _HostGroupHeader({
    super.key,
    required this.entry,
    required this.onToggle,
    this.onDrop,
  });

  final _HostGroupEntry entry;
  final VoidCallback onToggle;
  final ValueChanged<HostSummary>? onDrop;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final header = SerlinkPressable(
      onTap: onToggle,
      borderRadius: SerlinkRadii.control,
      hoverColor: t.surfaceOverlay,
      pressedColor: t.textPrimary.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          children: [
            AnimatedRotation(
              turns: entry.collapsed ? 0 : 0.25,
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              child: Icon(
                Icons.arrow_forward_ios,
                size: 12,
                color: t.textMuted,
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.folder_outlined, size: 16, color: t.textSecondary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                entry.label,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: t.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            _CountBadge(count: entry.count),
          ],
        ),
      ),
    );
    if (onDrop == null) return header;
    return DragTarget<HostSummary>(
      onWillAcceptWithDetails: (details) =>
          details.data.groupId != entry.groupId,
      onAcceptWithDetails: (details) => onDrop!(details.data),
      builder: (context, candidates, rejected) => AnimatedContainer(
        key: ValueKey('host-group-drop-${entry.groupId ?? ''}'),
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: candidates.isEmpty
              ? Colors.transparent
              : t.accentPrimary.withValues(alpha: 0.14),
          borderRadius: SerlinkRadii.control,
          border: Border.all(
            color: candidates.isEmpty ? Colors.transparent : t.accentPrimary,
          ),
        ),
        child: header,
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
  return showSerlinkFormDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => const _HostFormDialog(),
  );
}

Future<void> _showEditHostDialog(BuildContext context, HostSummary host) {
  return showSerlinkFormDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _HostFormDialog(host: host, mode: _HostFormMode.edit),
  );
}

Future<void> _showDuplicateHostDialog(BuildContext context, HostSummary host) {
  return showSerlinkFormDialog<void>(
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
      height: SerlinkSizes.pageHeaderHeight,
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
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: _WorkspaceHeaderSearch(
                placeholder: l10n.searchHostsPlaceholder,
              ),
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
    return _PlaceholderSurface(
      icon: Icons.dns_outlined,
      title: l10n.hostsEmptyTitle,
      body: l10n.hostsEmptyBody,
      action: SerlinkFilledButton.icon(
        key: const ValueKey('empty-add-host-button'),
        onPressed: onAddHost,
        icon: const Icon(Icons.add, size: 18),
        label: Text(l10n.hostsAddAction),
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
