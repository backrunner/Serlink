part of '../workspace_screen.dart';

class _TerminalPane extends ConsumerStatefulWidget {
  const _TerminalPane({
    super.key,
    required this.tabId,
    required this.hostId,
    required this.title,
    required this.panes,
    required this.showSplit,
    required this.layout,
    required this.activePane,
    required this.local,
    required this.onOpenSftp,
    required this.onToolbarSnapshotChanged,
  });

  final WorkspaceTabId tabId;
  final HostId? hostId;
  final String title;
  final List<TerminalPaneState> panes;
  final bool showSplit;
  final TerminalPaneLayout layout;
  final int activePane;
  final bool local;
  final VoidCallback? onOpenSftp;
  final ValueChanged<_TerminalToolbarSnapshot> onToolbarSnapshotChanged;

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
    _scheduleToolbarSnapshot(activePaneState);
    return Column(
      children: [
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
                  layout: widget.layout,
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

  void _scheduleToolbarSnapshot(TerminalPaneState activePaneState) {
    final snapshot = _TerminalToolbarSnapshot(
      tabId: widget.tabId,
      searchActive: _showSearch,
      activeLocalForward: _activeLocalForward,
      activeRemoteForward: _activeRemoteForward,
      activeDynamicForward: _activeDynamicForward,
      forwardBusy: _forwardBusy,
      forwardEnabled:
          !widget.local &&
          widget.hostId != null &&
          activePaneState.lifecycle == SessionLifecycleState.connected,
      showForwarding: !widget.local,
      showOpenSftp: !widget.local && widget.onOpenSftp != null,
      onToggleSearch: _toggleSearch,
      onManageForwarding: _manageForwarding,
      onOpenSftp: widget.onOpenSftp,
      showSplit: widget.showSplit,
      onSplitRight: _splitRight,
      onSplitDown: _splitDown,
      onCloseActivePane: _closeActivePane,
      onSettings: () => _showTerminalSettingsDialog(
        context,
        tabId: widget.tabId,
        hostId: widget.hostId,
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      widget.onToolbarSnapshotChanged(snapshot);
    });
  }

  void _splitRight() {
    ref
        .read(workspaceTabControllerProvider.notifier)
        .enableTerminalSplit(widget.tabId, axis: Axis.horizontal);
  }

  void _splitDown() {
    ref
        .read(workspaceTabControllerProvider.notifier)
        .enableTerminalSplit(widget.tabId, axis: Axis.vertical);
  }

  void _closeActivePane() {
    ref
        .read(workspaceTabControllerProvider.notifier)
        .closeActiveTerminalPane(widget.tabId);
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
    final action = await showSerlinkDialog<_ForwardDialogAction>(
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
