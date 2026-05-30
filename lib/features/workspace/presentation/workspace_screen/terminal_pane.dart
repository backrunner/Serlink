part of '../workspace_screen.dart';

class _TerminalPane extends ConsumerStatefulWidget {
  const _TerminalPane({
    super.key,
    required this.tabId,
    required this.hostId,
    required this.title,
    required this.panes,
    required this.showSplit,
    required this.splitAxis,
    required this.activePane,
    required this.local,
    required this.onOpenSftp,
  });

  final WorkspaceTabId tabId;
  final HostId? hostId;
  final String title;
  final List<TerminalPaneState> panes;
  final bool showSplit;
  final Axis splitAxis;
  final int activePane;
  final bool local;
  final VoidCallback? onOpenSftp;

  @override
  ConsumerState<_TerminalPane> createState() => _TerminalPaneState();
}

class _TerminalPaneState extends ConsumerState<_TerminalPane> {
  late final WorkspaceRuntimeRegistry _runtimeRegistry;
  late final TextEditingController _searchTextController;
  late List<TerminalController> _terminalControllers;
  late List<TerminalBufferSearchController> _searchControllers;
  late List<Terminal> _cachedTerminals;
  var _showSearch = false;
  var _searchResult = const TerminalSearchResult.empty();
  _LocalForwardDraft? _activeLocalForward;
  _RemoteForwardDraft? _activeRemoteForward;
  _DynamicForwardDraft? _activeDynamicForward;
  bool _forwardBusy = false;

  @override
  void initState() {
    super.initState();
    _runtimeRegistry = ref.read(workspaceRuntimeRegistryProvider);
    _searchTextController = TextEditingController();
    _buildPaneControllers();
  }

  @override
  void dispose() {
    for (final terminal in _terminals()) {
      terminal.removeListener(_refreshSearchAfterTerminalChange);
    }
    for (final controller in _searchControllers) {
      controller.clear();
    }
    _searchTextController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_TerminalPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.panes.every(
          (pane) => pane.lifecycle != SessionLifecycleState.connected,
        ) &&
        (_activeLocalForward != null ||
            _activeRemoteForward != null ||
            _activeDynamicForward != null)) {
      _activeLocalForward = null;
      _activeRemoteForward = null;
      _activeDynamicForward = null;
    }
    if (oldWidget.panes.length != widget.panes.length ||
        !_samePaneSessions(oldWidget.panes, widget.panes)) {
      for (final terminal in _terminals(oldWidget.panes)) {
        terminal.removeListener(_refreshSearchAfterTerminalChange);
      }
      for (final controller in _searchControllers) {
        controller.clear();
      }
      _buildPaneControllers();
    }
  }

  @override
  Widget build(BuildContext context) {
    final globalSettings =
        ref.watch(terminalDisplaySettingsProvider).value ??
        const TerminalDisplaySettings();
    final activePaneState =
        widget.panes[widget.activePane.clamp(0, widget.panes.length - 1)];
    final settings = activePaneState.displaySettings ?? globalSettings;
    return Column(
      children: [
        _TerminalToolbar(
          searchActive: _showSearch,
          activeLocalForward: _activeLocalForward,
          activeRemoteForward: _activeRemoteForward,
          activeDynamicForward: _activeDynamicForward,
          forwardBusy: _forwardBusy,
          forwardEnabled:
              widget.hostId != null &&
              activePaneState.lifecycle == SessionLifecycleState.connected,
          onToggleSearch: _toggleSearch,
          onManageForwarding: _manageForwarding,
          onOpenSftp: widget.onOpenSftp,
          showSplit: widget.showSplit,
          splitAxis: widget.splitAxis,
          onToggleSplit: _toggleSplit,
          onSetSplitAxis: _setSplitAxis,
          onSettings: () => _showTerminalSettingsDialog(
            context,
            tabId: widget.tabId,
            hostId: widget.hostId,
          ),
        ),
        if (_showSearch)
          _TerminalSearchBar(
            controller: _searchTextController,
            result: _searchResult,
            onChanged: _search,
            onPrevious: _previousSearchMatch,
            onNext: _nextSearchMatch,
            onClose: _closeSearch,
          ),
        Expanded(
          child: widget.showSplit
              ? _SplitTerminalViewport(
                  panes: widget.panes,
                  terminals: _terminals(),
                  controllers: _terminalControllers,
                  globalSettings: globalSettings,
                  axis: widget.splitAxis,
                  activePane: widget.activePane,
                  local: widget.local,
                  onActivatePane: _setActivePane,
                  onKeyEvent: _terminalViewKeyHandler,
                )
              : _SingleTerminalViewport(
                  terminal: _terminals().first,
                  controller: _terminalControllers.first,
                  settings: settings,
                  onKeyEvent: _terminalViewKeyHandler,
                ),
        ),
      ],
    );
  }

  void _toggleSplit() {
    final controller = ref.read(workspaceTabControllerProvider.notifier);
    if (widget.showSplit) {
      controller.disableTerminalSplit(widget.tabId);
      return;
    }
    controller.enableTerminalSplit(widget.tabId);
  }

  void _setSplitAxis(Axis axis) {
    ref
        .read(workspaceTabControllerProvider.notifier)
        .setTerminalSplitAxis(widget.tabId, axis);
  }

  void _setActivePane(int index) {
    ref
        .read(workspaceTabControllerProvider.notifier)
        .setActiveTerminalPane(widget.tabId, index);
  }

  void _toggleSearch() {
    setState(() {
      _showSearch = !_showSearch;
      if (!_showSearch) {
        _searchTextController.clear();
        _activeSearchController.clear();
        _searchResult = const TerminalSearchResult.empty();
      }
    });
  }

  void _closeSearch() {
    setState(() {
      _showSearch = false;
      _searchTextController.clear();
      _activeSearchController.clear();
      _searchResult = const TerminalSearchResult.empty();
    });
  }

  void _search(String query) {
    setState(() {
      _searchResult = _activeSearchController.search(query);
    });
  }

  void _nextSearchMatch() {
    setState(() {
      _searchResult = _activeSearchController.next();
    });
  }

  void _previousSearchMatch() {
    setState(() {
      _searchResult = _activeSearchController.previous();
    });
  }

  Future<void> _manageForwarding() async {
    if (_forwardBusy ||
        widget.hostId == null ||
        _activePaneState.lifecycle != SessionLifecycleState.connected) {
      return;
    }
    final action = await showDialog<_ForwardDialogAction>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ForwardingDialog(
        activeLocalForward: _activeLocalForward,
        activeRemoteForward: _activeRemoteForward,
        activeDynamicForward: _activeDynamicForward,
      ),
    );
    if (action == null) {
      return;
    }
    switch (action.kind) {
      case _ForwardDialogActionKind.startLocal:
        await _startLocalForward(action.localDraft!);
      case _ForwardDialogActionKind.stopLocal:
        await _stopLocalForward();
      case _ForwardDialogActionKind.startRemote:
        await _startRemoteForward(action.remoteDraft!);
      case _ForwardDialogActionKind.stopRemote:
        await _stopRemoteForward();
      case _ForwardDialogActionKind.startDynamic:
        await _startDynamicForward(action.dynamicDraft!);
      case _ForwardDialogActionKind.stopDynamic:
        await _stopDynamicForward();
    }
  }

  Future<void> _startLocalForward(_LocalForwardDraft draft) async {
    setState(() {
      _forwardBusy = true;
    });
    try {
      await ref
          .read(sshSessionServiceProvider)
          .startLocalForward(
            sessionId: _activePaneState.sessionId,
            localPort: draft.localPort,
            remoteHost: draft.remoteHost,
            remotePort: draft.remotePort,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _activeLocalForward = draft;
        _forwardBusy = false;
      });
      _showSnackBar(context, 'Local port forward started.');
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() {
        _forwardBusy = false;
      });
      _showSnackBar(context, 'Local port forward could not start.');
    }
  }

  Future<void> _stopLocalForward() async {
    setState(() {
      _forwardBusy = true;
    });
    try {
      await ref
          .read(sshSessionServiceProvider)
          .stopLocalForward(sessionId: _activePaneState.sessionId);
      if (!mounted) {
        return;
      }
      setState(() {
        _activeLocalForward = null;
        _forwardBusy = false;
      });
      _showSnackBar(context, 'Local port forward stopped.');
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() {
        _forwardBusy = false;
      });
      _showSnackBar(context, 'Local port forward could not stop.');
    }
  }

  Future<void> _startRemoteForward(_RemoteForwardDraft draft) async {
    setState(() {
      _forwardBusy = true;
    });
    try {
      final binding = await ref
          .read(sshSessionServiceProvider)
          .startRemoteForward(
            sessionId: _activePaneState.sessionId,
            bindHost: draft.bindHost,
            bindPort: draft.bindPort,
            localHost: draft.localHost,
            localPort: draft.localPort,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _activeRemoteForward = _RemoteForwardDraft(
          bindHost: binding.bindHost,
          bindPort: binding.bindPort,
          localHost: binding.localHost,
          localPort: binding.localPort,
        );
        _forwardBusy = false;
      });
      _showSnackBar(context, 'Remote port forward started.');
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() {
        _forwardBusy = false;
      });
      _showSnackBar(context, 'Remote port forward could not start.');
    }
  }

  Future<void> _stopRemoteForward() async {
    setState(() {
      _forwardBusy = true;
    });
    try {
      await ref
          .read(sshSessionServiceProvider)
          .stopRemoteForward(sessionId: _activePaneState.sessionId);
      if (!mounted) {
        return;
      }
      setState(() {
        _activeRemoteForward = null;
        _forwardBusy = false;
      });
      _showSnackBar(context, 'Remote port forward stopped.');
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() {
        _forwardBusy = false;
      });
      _showSnackBar(context, 'Remote port forward could not stop.');
    }
  }

  Future<void> _startDynamicForward(_DynamicForwardDraft draft) async {
    setState(() {
      _forwardBusy = true;
    });
    try {
      final binding = await ref
          .read(sshSessionServiceProvider)
          .startDynamicForward(
            sessionId: _activePaneState.sessionId,
            bindHost: draft.bindHost,
            bindPort: draft.bindPort,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _activeDynamicForward = _DynamicForwardDraft(
          bindHost: binding.bindHost,
          bindPort: binding.bindPort,
        );
        _forwardBusy = false;
      });
      _showSnackBar(context, 'SOCKS proxy started.');
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() {
        _forwardBusy = false;
      });
      _showSnackBar(context, 'SOCKS proxy could not start.');
    }
  }

  Future<void> _stopDynamicForward() async {
    setState(() {
      _forwardBusy = true;
    });
    try {
      await ref
          .read(sshSessionServiceProvider)
          .stopDynamicForward(sessionId: _activePaneState.sessionId);
      if (!mounted) {
        return;
      }
      setState(() {
        _activeDynamicForward = null;
        _forwardBusy = false;
      });
      _showSnackBar(context, 'SOCKS proxy stopped.');
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() {
        _forwardBusy = false;
      });
      _showSnackBar(context, 'SOCKS proxy could not stop.');
    }
  }

  void _refreshSearchAfterTerminalChange() {
    if (!_showSearch || _searchTextController.text.trim().isEmpty || !mounted) {
      return;
    }
    setState(() {
      _searchResult = _activeSearchController.refresh();
    });
  }

  KeyEventResult _terminalViewKeyHandler(FocusNode node, KeyEvent event) {
    if (!shouldHandleTerminalShortcutLocally(event)) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.keyF) {
      if (!_showSearch) {
        _toggleSearch();
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  TerminalPaneState get _activePaneState {
    return widget.panes[widget.activePane.clamp(0, widget.panes.length - 1)];
  }

  TerminalBufferSearchController get _activeSearchController {
    return _searchControllers[widget.activePane.clamp(
      0,
      _searchControllers.length - 1,
    )];
  }

  void _buildPaneControllers() {
    _cachedTerminals = [
      for (final pane in widget.panes)
        _runtimeRegistry.terminalFor(pane.sessionId) ??
            Terminal(maxLines: 10000),
    ];
    _terminalControllers = [for (final _ in widget.panes) TerminalController()];
    _searchControllers = [
      for (var i = 0; i < widget.panes.length; i += 1)
        TerminalBufferSearchController(
          terminal: _cachedTerminals[i],
          controller: _terminalControllers[i],
        ),
    ];
    for (final terminal in _cachedTerminals) {
      terminal.addListener(_refreshSearchAfterTerminalChange);
    }
  }

  List<Terminal> _terminals([List<TerminalPaneState>? panes]) {
    if (panes == null || identical(panes, widget.panes)) {
      return _cachedTerminals;
    }
    final source = panes;
    return [
      for (final pane in source)
        _runtimeRegistry.terminalFor(pane.sessionId) ??
            Terminal(maxLines: 10000),
    ];
  }

  bool _samePaneSessions(
    List<TerminalPaneState> before,
    List<TerminalPaneState> after,
  ) {
    if (before.length != after.length) {
      return false;
    }
    for (var index = 0; index < before.length; index += 1) {
      if (before[index].sessionId != after[index].sessionId) {
        return false;
      }
    }
    return true;
  }
}

class _TerminalToolbar extends StatelessWidget {
  const _TerminalToolbar({
    required this.searchActive,
    required this.activeLocalForward,
    required this.activeRemoteForward,
    required this.activeDynamicForward,
    required this.forwardBusy,
    required this.forwardEnabled,
    required this.onToggleSearch,
    required this.onManageForwarding,
    required this.onOpenSftp,
    required this.showSplit,
    required this.splitAxis,
    required this.onToggleSplit,
    required this.onSetSplitAxis,
    required this.onSettings,
  });

  final bool searchActive;
  final _LocalForwardDraft? activeLocalForward;
  final _RemoteForwardDraft? activeRemoteForward;
  final _DynamicForwardDraft? activeDynamicForward;
  final bool forwardBusy;
  final bool forwardEnabled;
  final VoidCallback onToggleSearch;
  final VoidCallback onManageForwarding;
  final VoidCallback? onOpenSftp;
  final bool showSplit;
  final Axis splitAxis;
  final VoidCallback onToggleSplit;
  final ValueChanged<Axis> onSetSplitAxis;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: Row(
        children: [
          const Spacer(),
          Tooltip(
            message: 'Search terminal',
            child: IconButton(
              isSelected: searchActive,
              onPressed: onToggleSearch,
              icon: const Icon(Icons.search, size: 18),
            ),
          ),
          Tooltip(
            message: _forwardingTooltip(
              activeLocalForward,
              activeRemoteForward,
              activeDynamicForward,
              busy: forwardBusy,
            ),
            child: IconButton(
              isSelected:
                  activeLocalForward != null ||
                  activeRemoteForward != null ||
                  activeDynamicForward != null,
              onPressed: forwardEnabled && !forwardBusy
                  ? onManageForwarding
                  : null,
              icon: const Icon(Icons.settings_ethernet_outlined, size: 18),
            ),
          ),
          Tooltip(
            message: 'Open SFTP tab',
            child: IconButton(
              onPressed: onOpenSftp,
              icon: const Icon(Icons.folder_open_outlined, size: 18),
            ),
          ),
          Tooltip(
            message: showSplit ? 'Close split' : 'Split terminal',
            child: IconButton(
              onPressed: onToggleSplit,
              icon: Icon(
                showSplit
                    ? Icons.close_fullscreen_outlined
                    : Icons.splitscreen_outlined,
                size: 18,
              ),
            ),
          ),
          if (showSplit)
            SegmentedButton<Axis>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment<Axis>(
                  value: Axis.horizontal,
                  icon: Icon(Icons.view_column_outlined, size: 16),
                  tooltip: 'Vertical split',
                ),
                ButtonSegment<Axis>(
                  value: Axis.vertical,
                  icon: Icon(Icons.view_agenda_outlined, size: 16),
                  tooltip: 'Horizontal split',
                ),
              ],
              selected: {splitAxis},
              onSelectionChanged: (selection) {
                final axis = selection.firstOrNull;
                if (axis != null) {
                  onSetSplitAxis(axis);
                }
              },
            ),
          Tooltip(
            message: 'Terminal settings',
            child: IconButton(
              onPressed: onSettings,
              icon: const Icon(Icons.tune_outlined, size: 18),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class _SingleTerminalViewport extends StatelessWidget {
  const _SingleTerminalViewport({
    required this.terminal,
    required this.controller,
    required this.settings,
    this.onKeyEvent,
  });

  final Terminal terminal;
  final TerminalController controller;
  final TerminalDisplaySettings settings;
  final FocusOnKeyEventCallback? onKeyEvent;

  @override
  Widget build(BuildContext context) {
    return TerminalView(
      terminal,
      controller: controller,
      autofocus: true,
      padding: const EdgeInsets.all(12),
      theme: settings.terminalTheme,
      textStyle: settings.textStyle,
      onKeyEvent: onKeyEvent,
    );
  }
}

class _SplitTerminalViewport extends StatelessWidget {
  const _SplitTerminalViewport({
    required this.panes,
    required this.terminals,
    required this.controllers,
    required this.globalSettings,
    required this.axis,
    required this.activePane,
    required this.local,
    required this.onActivatePane,
    this.onKeyEvent,
  });

  final List<TerminalPaneState> panes;
  final List<Terminal> terminals;
  final List<TerminalController> controllers;
  final TerminalDisplaySettings globalSettings;
  final Axis axis;
  final int activePane;
  final bool local;
  final ValueChanged<int> onActivatePane;
  final FocusOnKeyEventCallback? onKeyEvent;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var index = 0; index < panes.length; index += 1) {
      if (index > 0) {
        children.add(_splitDivider(axis));
      }
      final pane = panes[index];
      children.add(
        Expanded(
          child: _TerminalViewportPane(
            terminal: terminals[index],
            controller: controllers[index],
            settings: pane.displaySettings ?? globalSettings,
            active: activePane == index,
            label: pane.title,
            lifecycle: pane.lifecycle,
            local: local,
            onKeyEvent: onKeyEvent,
            onTap: () => onActivatePane(index),
          ),
        ),
      );
    }
    return axis == Axis.horizontal
        ? Row(children: children)
        : Column(children: children);
  }

  Widget _splitDivider(Axis axis) {
    return axis == Axis.horizontal
        ? const VerticalDivider(width: 1, thickness: 1)
        : const Divider(height: 1, thickness: 1);
  }
}

class _TerminalViewportPane extends StatelessWidget {
  const _TerminalViewportPane({
    required this.terminal,
    required this.controller,
    required this.settings,
    required this.active,
    required this.label,
    required this.lifecycle,
    required this.local,
    this.onKeyEvent,
    required this.onTap,
  });

  final Terminal terminal;
  final TerminalController controller;
  final TerminalDisplaySettings settings;
  final bool active;
  final String label;
  final SessionLifecycleState lifecycle;
  final bool local;
  final FocusOnKeyEventCallback? onKeyEvent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(
          color: active ? scheme.primary : scheme.outlineVariant,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              height: 28,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              alignment: Alignment.centerLeft,
              color: active
                  ? scheme.primary.withValues(alpha: 0.10)
                  : scheme.surfaceContainerHighest,
              child: Text(
                '$label · ${_terminalPaneLifecycleLabel(lifecycle, local: local)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            Expanded(
              child: TerminalView(
                terminal,
                controller: controller,
                autofocus: active,
                padding: const EdgeInsets.all(12),
                theme: settings.terminalTheme,
                textStyle: settings.textStyle,
                onKeyEvent: onKeyEvent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _terminalPaneLifecycleLabel(
  SessionLifecycleState lifecycle, {
  required bool local,
}) {
  if (local) {
    return switch (lifecycle) {
      SessionLifecycleState.connected => 'Running',
      SessionLifecycleState.connecting ||
      SessionLifecycleState.reconnecting ||
      SessionLifecycleState.resolvingProfile => 'Starting',
      SessionLifecycleState.disconnected => 'Exited',
      SessionLifecycleState.failed => 'Failed',
      SessionLifecycleState.disconnecting => 'Stopping',
      SessionLifecycleState.verifyingHostKey ||
      SessionLifecycleState.authenticating ||
      SessionLifecycleState.idle => 'Starting',
    };
  }
  return switch (lifecycle) {
    SessionLifecycleState.connected => 'Connected',
    SessionLifecycleState.connecting => 'Connecting',
    SessionLifecycleState.reconnecting => 'Reconnecting',
    SessionLifecycleState.disconnected => 'Disconnected',
    SessionLifecycleState.failed => 'Failed',
    SessionLifecycleState.resolvingProfile => 'Preparing',
    SessionLifecycleState.verifyingHostKey => 'Verifying',
    SessionLifecycleState.authenticating => 'Authenticating',
    SessionLifecycleState.disconnecting => 'Disconnecting',
    SessionLifecycleState.idle => 'Idle',
  };
}

String _forwardingTooltip(
  _LocalForwardDraft? activeForward,
  _RemoteForwardDraft? activeRemoteForward,
  _DynamicForwardDraft? activeDynamicForward, {
  required bool busy,
}) {
  if (busy) {
    return 'Updating port forwarding';
  }
  final activeCount = [
    activeForward,
    activeRemoteForward,
    activeDynamicForward,
  ].whereType<Object>().length;
  if (activeCount == 0) {
    return 'Manage port forwarding';
  }
  return 'Manage port forwarding ($activeCount active)';
}
