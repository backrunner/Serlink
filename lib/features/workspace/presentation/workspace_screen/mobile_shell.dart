part of '../workspace_screen.dart';

class MobileWorkspaceScreen extends ConsumerWidget {
  const MobileWorkspaceScreen({super.key});

  static const double _tabletBreakpoint = 768;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(workspaceTabControllerProvider);
    final controller = ref.read(workspaceTabControllerProvider.notifier);
    final selectedIndex = _mobileAreaIndex(state.area);
    final session = ref.watch(vaultSessionControllerProvider).value;
    if (session != null && !session.localDataHealthy) {
      return Scaffold(
        body: DecoratedBox(
          decoration: BoxDecoration(color: context.tokens.surfaceBase),
          child: _VaultAccessSurface(session: session),
        ),
      );
    }

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(color: context.tokens.surfaceBase),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= _tabletBreakpoint;
            return FScaffold(
              childPad: false,
              sidebar: wide
                  ? _MobileSidebar(
                      selected: state.area,
                      onSelected: (area) => _selectMobileArea(
                        ref,
                        controller,
                        current: state.area,
                        next: area,
                      ),
                    )
                  : null,
              header: _MobileHeader(area: state.area),
              footer: wide
                  ? null
                  : _MobileBottomNavigation(
                      index: selectedIndex,
                      onChange: (index) => _selectMobileArea(
                        ref,
                        controller,
                        current: state.area,
                        next: _mobileAreaAt(index),
                      ),
                    ),
              child: _MobileMainSurface(state: state),
            );
          },
        ),
      ),
    );
  }
}

class _MobileHeader extends ConsumerWidget {
  const _MobileHeader({required this.area});

  final WorkspaceArea area;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = _mobileHeaderCount(ref, area);
    return FHeader(
      key: const ValueKey('mobile-workspace-header'),
      style: const FHeaderStyleDelta.delta(
        constraints: BoxConstraints(minHeight: 54),
        padding: EdgeInsetsGeometryDelta.value(
          EdgeInsets.fromLTRB(16, 9, 16, 9),
        ),
      ),
      title: _MobileHeaderTitle(
        title: _mobileAreaTitle(context.l10n, area),
        count: count,
      ),
      suffixes: [_MobileHeaderActions(area: area)],
    );
  }
}

int? _mobileHeaderCount(WidgetRef ref, WorkspaceArea area) {
  switch (area) {
    case WorkspaceArea.hosts:
      final session = ref.watch(vaultSessionControllerProvider).value;
      if (session?.vaultState != VaultState.unlocked) {
        return null;
      }
      final hosts = ref
          .watch(hostSummariesProvider(session!.unlockGeneration))
          .value;
      final query = ref.watch(_workspaceSearchQueryProvider);
      return hosts == null ? null : filterHostSummaries(hosts, query).length;
    case WorkspaceArea.sessions:
      final state = ref.watch(workspaceTabControllerProvider);
      return state.tabs.isEmpty ? null : state.tabs.length;
    case WorkspaceArea.transfers:
      final queue = ref.watch(transferQueueStateProvider).value;
      final query = ref.watch(_workspaceSearchQueryProvider);
      return queue == null
          ? null
          : filterTransferTasks(queue.tasks, query).length;
    case WorkspaceArea.snippets:
      final session = ref.watch(vaultSessionControllerProvider).value;
      if (session?.vaultState != VaultState.unlocked) {
        return null;
      }
      final snippets = ref
          .watch(snippetsProvider(session!.unlockGeneration))
          .value;
      final query = ref.watch(_workspaceSearchQueryProvider);
      return snippets == null
          ? null
          : filterCommandSnippets(snippets, query).length;
    case WorkspaceArea.settings:
      return null;
  }
}

class _MobileHeaderTitle extends StatelessWidget {
  const _MobileHeaderTitle({required this.title, this.count});

  final String title;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(top: 1),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            key: const ValueKey('mobile-header-title-row'),
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: t.textPrimary,
                    fontSize: 18.5,
                    fontWeight: FontWeight.w700,
                    height: 1.08,
                  ),
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 8),
                _CountBadge(
                  key: const ValueKey('mobile-header-count-badge'),
                  count: count!,
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Container(
            width: 28,
            height: 2,
            decoration: BoxDecoration(
              gradient: serlinkAccentGradient(t),
              borderRadius: SerlinkRadii.pill,
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileHeaderActions extends ConsumerWidget {
  const _MobileHeaderActions({required this.area});

  final WorkspaceArea area;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (area) {
      WorkspaceArea.hosts => _buildHostsActions(context, ref),
      WorkspaceArea.sessions => _buildSessionsActions(context, ref),
      WorkspaceArea.transfers => _buildTransfersActions(context, ref),
      WorkspaceArea.snippets => _buildSnippetsActions(context, ref),
      WorkspaceArea.settings => const SizedBox.shrink(),
    };
  }

  Widget _buildHostsActions(BuildContext context, WidgetRef ref) {
    final session = ref.watch(vaultSessionControllerProvider).value;
    if (session?.vaultState != VaultState.unlocked) {
      return const SizedBox.shrink();
    }
    final sortOrder = ref.watch(_hostSortOrderProvider);
    return _MobileHeaderActionGroup(
      action: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _HostSortMenuButton(
            selectedOrder: sortOrder,
            onSelected: ref.read(_hostSortOrderProvider.notifier).setOrder,
            mobile: true,
          ),
          const SizedBox(width: _mobileHeaderControlGap),
          _MobileHeaderIconButton(
            key: const ValueKey('add-host-button'),
            tooltip: context.l10n.hostsAddTooltip,
            icon: Icons.add,
            onPressed: () => _showAddHostDialog(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionsActions(BuildContext context, WidgetRef ref) {
    return _MobileHeaderActionGroup(
      action: _MobileHeaderIconButton(
        key: const ValueKey('mobile-new-session-button'),
        tooltip: context.l10n.tabsNewConnectionTooltip,
        icon: Icons.add,
        onPressed: () {
          ref.read(_workspaceSearchQueryProvider.notifier).clear();
          ref
              .read(workspaceTabControllerProvider.notifier)
              .selectArea(WorkspaceArea.hosts);
        },
      ),
    );
  }

  Widget _buildTransfersActions(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(transferQueueStateProvider).value;
    if (queue == null) {
      return const SizedBox.shrink();
    }
    final activeCount = queue.tasks.where(_transferIsActive).length;
    return _MobileHeaderActionGroup(
      status: activeCount > 0
          ? StatusPill(
              label: context.l10n.transfersActiveCount(activeCount),
              color: context.tokens.statusInfo,
            )
          : null,
      action: _MobileHeaderIconButton(
        key: const ValueKey('clear-transfers-button'),
        tooltip: context.l10n.transfersClearAction,
        icon: Icons.delete_sweep_outlined,
        onPressed: queue.tasks.isEmpty
            ? null
            : () => unawaited(_clearTransfers(context, ref, queue)),
      ),
    );
  }

  Widget _buildSnippetsActions(BuildContext context, WidgetRef ref) {
    final session = ref.watch(vaultSessionControllerProvider).value;
    if (session?.vaultState != VaultState.unlocked) {
      return const SizedBox.shrink();
    }
    return _MobileHeaderActionGroup(
      action: _MobileHeaderIconButton(
        key: const ValueKey('add-snippet-button'),
        tooltip: context.l10n.snippetsAddTooltip,
        icon: Icons.add,
        onPressed: () => _showSnippetDialog(context),
      ),
    );
  }
}

class _MobileHeaderActionGroup extends StatelessWidget {
  const _MobileHeaderActionGroup({this.status, this.action});

  final Widget? status;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (status != null) ...[
          status!,
          const SizedBox(width: _mobileHeaderControlGap),
        ],
        ?action,
      ],
    );
  }
}

const double _mobileHeaderActionSide = 38;
const double _mobileHeaderActionIconSize = 19;
const double _mobileHeaderControlGap = 10;
const double _mobileSurfaceHorizontalPadding = 12;
const double _mobileSurfaceTopGap = 8;
const double _mobileSurfaceBottomPadding = 12;
const EdgeInsets _mobileSurfaceListPadding = EdgeInsets.fromLTRB(
  _mobileSurfaceHorizontalPadding,
  _mobileSurfaceTopGap,
  _mobileSurfaceHorizontalPadding,
  _mobileSurfaceBottomPadding,
);
const EdgeInsets _mobileSearchBarPadding = EdgeInsets.fromLTRB(16, 10, 16, 8);

class _MobileHeaderIconButton extends StatelessWidget {
  const _MobileHeaderIconButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SerlinkIconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon),
      constraints: const BoxConstraints.tightFor(
        width: _mobileHeaderActionSide,
        height: _mobileHeaderActionSide,
      ),
      iconSize: _mobileHeaderActionIconSize,
    );
  }
}

class _MobileMainSurface extends StatelessWidget {
  const _MobileMainSurface({required this.state});

  final WorkspaceState state;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.tokens.surfaceRaised,
        border: Border(top: BorderSide(color: context.tokens.borderSubtle)),
      ),
      child: Column(
        children: [
          if (_showsMobileWorkspaceSearch(state.area))
            _MobileWorkspaceSearchBar(
              placeholder: _workspaceSearchPlaceholder(
                context.l10n,
                state.area,
              ),
            ),
          Expanded(child: _MainSurface(state: state)),
        ],
      ),
    );
  }
}

class _MobileWorkspaceSearchBar extends ConsumerStatefulWidget {
  const _MobileWorkspaceSearchBar({required this.placeholder});

  final String placeholder;

  @override
  ConsumerState<_MobileWorkspaceSearchBar> createState() =>
      _MobileWorkspaceSearchBarState();
}

class _MobileWorkspaceSearchBarState
    extends ConsumerState<_MobileWorkspaceSearchBar> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(_workspaceSearchQueryProvider);
    if (_controller.text != query) {
      _controller.value = TextEditingValue(
        text: query,
        selection: TextSelection.collapsed(offset: query.length),
      );
    }
    return Padding(
      key: const ValueKey('mobile-workspace-search-bar'),
      padding: _mobileSearchBarPadding,
      child: _WorkspaceSearchPill(
        fieldKey: const ValueKey('mobile-workspace-search-field'),
        controller: _controller,
        placeholder: widget.placeholder,
        enabled: true,
        hasQuery: query.trim().isNotEmpty,
        onChanged: (value) {
          ref.read(_workspaceSearchQueryProvider.notifier).setQuery(value);
        },
        onClear: () {
          _controller.clear();
          ref.read(_workspaceSearchQueryProvider.notifier).clear();
        },
      ),
    );
  }
}

class _MobileSidebar extends StatelessWidget {
  const _MobileSidebar({required this.selected, required this.onSelected});

  final WorkspaceArea selected;
  final ValueChanged<WorkspaceArea> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SizedBox(
      width: 220,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.tokens.surfaceBase,
          border: Border(right: BorderSide(color: context.tokens.borderSubtle)),
        ),
        child: SafeArea(
          right: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(8, 4, 8, 12),
                  child: _BrandMark(),
                ),
                _NavItem(
                  icon: Icons.dns_outlined,
                  label: l10n.navHosts,
                  selected: selected == WorkspaceArea.hosts,
                  onTap: () => onSelected(WorkspaceArea.hosts),
                ),
                _NavItem(
                  icon: Icons.terminal_outlined,
                  label: l10n.navSessions,
                  selected: selected == WorkspaceArea.sessions,
                  onTap: () => onSelected(WorkspaceArea.sessions),
                ),
                _NavItem(
                  icon: Icons.sync_alt_outlined,
                  label: l10n.navTransfers,
                  selected: selected == WorkspaceArea.transfers,
                  onTap: () => onSelected(WorkspaceArea.transfers),
                ),
                _NavItem(
                  icon: Icons.code_outlined,
                  label: l10n.navSnippets,
                  selected: selected == WorkspaceArea.snippets,
                  onTap: () => onSelected(WorkspaceArea.snippets),
                ),
                const Spacer(),
                _NavItem(
                  icon: Icons.settings_outlined,
                  label: l10n.navSettings,
                  selected: selected == WorkspaceArea.settings,
                  onTap: () => onSelected(WorkspaceArea.settings),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileBottomNavigation extends StatelessWidget {
  const _MobileBottomNavigation({required this.index, required this.onChange});

  final int index;
  final ValueChanged<int> onChange;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FBottomNavigationBar(
      key: const ValueKey('mobile-workspace-bottom-navigation'),
      index: index,
      safeAreaBottom: false,
      onChange: onChange,
      children: [
        FBottomNavigationBarItem(
          icon: const Icon(Icons.dns_outlined),
          label: Text(l10n.navHosts),
        ),
        FBottomNavigationBarItem(
          icon: const Icon(Icons.terminal_outlined),
          label: Text(l10n.navSessions),
        ),
        FBottomNavigationBarItem(
          icon: const Icon(Icons.sync_alt_outlined),
          label: Text(l10n.navTransfers),
        ),
        FBottomNavigationBarItem(
          icon: const Icon(Icons.code_outlined),
          label: Text(l10n.navSnippets),
        ),
        FBottomNavigationBarItem(
          icon: const Icon(Icons.settings_outlined),
          label: Text(l10n.navSettings),
        ),
      ],
    );
  }
}

void _selectMobileArea(
  WidgetRef ref,
  WorkspaceTabController controller, {
  required WorkspaceArea current,
  required WorkspaceArea next,
}) {
  if (next != current) {
    ref.read(vaultSessionControllerProvider.notifier).resetUnlockFailureState();
  }
  controller.selectArea(next);
}

int _mobileAreaIndex(WorkspaceArea area) {
  return switch (area) {
    WorkspaceArea.hosts => 0,
    WorkspaceArea.sessions => 1,
    WorkspaceArea.transfers => 2,
    WorkspaceArea.snippets => 3,
    WorkspaceArea.settings => 4,
  };
}

WorkspaceArea _mobileAreaAt(int index) {
  return switch (index) {
    0 => WorkspaceArea.hosts,
    1 => WorkspaceArea.sessions,
    2 => WorkspaceArea.transfers,
    3 => WorkspaceArea.snippets,
    _ => WorkspaceArea.settings,
  };
}

String _mobileAreaTitle(AppLocalizations l10n, WorkspaceArea area) {
  return switch (area) {
    WorkspaceArea.hosts => l10n.navHosts,
    WorkspaceArea.sessions => l10n.navSessions,
    WorkspaceArea.transfers => l10n.navTransfers,
    WorkspaceArea.snippets => l10n.navSnippets,
    WorkspaceArea.settings => l10n.navSettings,
  };
}
