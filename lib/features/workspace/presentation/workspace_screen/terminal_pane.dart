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
  late List<FocusNode> _terminalFocusNodes;
  late List<TerminalBufferSearchController> _searchControllers;
  late List<Terminal> _cachedTerminals;
  BoxConstraints? _terminalViewportConstraints;
  var _showSearch = false;
  var _searchResult = const TerminalSearchResult.empty();
  final Map<SessionId, _LocalForwardDraft> _localForwards = {};
  final Map<SessionId, _RemoteForwardDraft> _remoteForwards = {};
  final Map<SessionId, _DynamicForwardDraft> _dynamicForwards = {};
  final Set<SessionId> _forwardBusySessions = {};
  bool _ctrlLatched = false;
  bool _altLatched = false;
  bool _shiftLatched = false;

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
    for (final focusNode in _terminalFocusNodes) {
      focusNode.dispose();
    }
    _searchTextController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_TerminalPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    _pruneForwardingState();
    if (oldWidget.panes.length != widget.panes.length ||
        !_samePaneSessions(oldWidget.panes, widget.panes)) {
      for (final terminal in _terminals(oldWidget.panes)) {
        terminal.removeListener(_refreshSearchAfterTerminalChange);
      }
      for (final controller in _searchControllers) {
        controller.clear();
      }
      for (final focusNode in _terminalFocusNodes) {
        focusNode.dispose();
      }
      _buildPaneControllers();
    }
    if (_modifierLatch.isActive &&
        widget
                .panes[widget.activePane.clamp(0, widget.panes.length - 1)]
                .lifecycle !=
            SessionLifecycleState.connected) {
      _ctrlLatched = false;
      _altLatched = false;
      _shiftLatched = false;
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
    final capabilities = ref.watch(platformCapabilitiesProvider);
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              _terminalViewportConstraints = constraints;
              _scheduleToolbarSnapshot(activePaneState);
              return ClipRect(
                key: const ValueKey('terminal-viewport-clip'),
                child: widget.showSplit
                    ? _SplitTerminalViewport(
                        tabId: widget.tabId,
                        panes: widget.panes,
                        terminals: _terminals(),
                        controllers: _terminalControllers,
                        focusNodes: _terminalFocusNodes,
                        globalSettings: globalSettings,
                        layout: widget.layout,
                        activePane: widget.activePane,
                        local: widget.local,
                        onActivatePane: _setActivePane,
                        onClosePane: _closePane,
                        onReconnectPane: _reconnectPane,
                        onSwapPanes: _swapPanes,
                        onDropTabPane: _dropTabPane,
                        onResizeSplit: _resizeSplit,
                        onKeyEvent: _terminalViewKeyHandler,
                        onInsertText: _handleTerminalTextInsert,
                      )
                    : _SingleTerminalViewport(
                        terminal: _terminals().first,
                        controller: _terminalControllers.first,
                        focusNode: _terminalFocusNodes.first,
                        settings: settings,
                        pane: activePaneState,
                        local:
                            activePaneState.endpoint?.isLocal ?? widget.local,
                        onReconnect: () => _reconnectPane(0),
                        onKeyEvent: _terminalViewKeyHandler,
                        onInsertText: _handleTerminalTextInsert,
                      ),
              );
            },
          ),
        ),
        if (capabilities.mobileTerminalAccessory)
          _TerminalAccessoryBar(
            connected:
                activePaneState.lifecycle == SessionLifecycleState.connected,
            ctrlLatched: _ctrlLatched,
            altLatched: _altLatched,
            shiftLatched: _shiftLatched,
            onToggleCtrl: _toggleCtrlLatch,
            onToggleAlt: _toggleAltLatch,
            onToggleShift: _toggleShiftLatch,
            onControlKey: _sendActiveTerminalControlKey,
            onPaste: _pasteClipboard,
            onToggleSearch: _toggleSearch,
            onOpenSnippets: () => _showTerminalSnippetPicker(context, ref),
          ),
      ],
    );
  }

  void _scheduleToolbarSnapshot(TerminalPaneState activePaneState) {
    final activePaneSize = _activePaneApproximateSize();
    final activeEndpoint = activePaneState.endpoint;
    final activeSessionId = activePaneState.sessionId;
    final activeLocal = activeEndpoint?.isLocal ?? widget.local;
    final activeHostId = activeEndpoint?.hostId ?? widget.hostId;
    final snapshot = _TerminalToolbarSnapshot(
      tabId: widget.tabId,
      activePane: widget.activePane,
      activeHostId: activeHostId,
      searchActive: _showSearch,
      activeLocalForward: _localForwards[activeSessionId],
      activeRemoteForward: _remoteForwards[activeSessionId],
      activeDynamicForward: _dynamicForwards[activeSessionId],
      forwardBusy: _forwardBusySessions.contains(activeSessionId),
      forwardEnabled:
          !activeLocal &&
          activeHostId != null &&
          activePaneState.lifecycle == SessionLifecycleState.connected,
      showForwarding: !activeLocal,
      showOpenSftp: !activeLocal && widget.onOpenSftp != null,
      showSplitControls:
          !activeLocal || ref.read(platformCapabilitiesProvider).localTerminal,
      onToggleSearch: _toggleSearch,
      onManageForwarding: _manageForwarding,
      onOpenSftp: widget.onOpenSftp,
      canSplitRight: activePaneSize.width >= _terminalMinPaneWidth * 2,
      canSplitDown: activePaneSize.height >= _terminalMinPaneHeight * 2,
      onSplitRight: _splitRight,
      onSplitDown: _splitDown,
      onSettings: () => _showTerminalSettingsDialog(
        context,
        tabId: widget.tabId,
        hostId: activeHostId,
        paneIndex: widget.activePane,
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

  void _closePane(int paneIndex) {
    ref
        .read(workspaceTabControllerProvider.notifier)
        .closeTerminalPane(widget.tabId, paneIndex);
  }

  void _reconnectPane(int paneIndex) {
    ref
        .read(workspaceTabControllerProvider.notifier)
        .reconnectTerminalPane(widget.tabId, paneIndex);
  }

  void _resizeSplit(List<int> splitPath, double ratio) {
    ref
        .read(workspaceTabControllerProvider.notifier)
        .resizeTerminalSplit(widget.tabId, splitPath, ratio);
  }

  void _swapPanes(int fromPaneIndex, int toPaneIndex) {
    ref
        .read(workspaceTabControllerProvider.notifier)
        .swapTerminalPanes(widget.tabId, fromPaneIndex, toPaneIndex);
  }

  void _dropTabPane(
    WorkspaceTabId sourceTabId,
    int targetPaneIndex,
    _TerminalPaneDropPlacement placement,
  ) {
    final axis =
        placement == _TerminalPaneDropPlacement.left ||
            placement == _TerminalPaneDropPlacement.right
        ? Axis.horizontal
        : Axis.vertical;
    final before =
        placement == _TerminalPaneDropPlacement.left ||
        placement == _TerminalPaneDropPlacement.top;
    ref
        .read(workspaceTabControllerProvider.notifier)
        .mergeSinglePaneTabIntoSplit(
          sourceTabId: sourceTabId,
          targetTabId: widget.tabId,
          targetPaneIndex: targetPaneIndex,
          axis: axis,
          before: before,
        );
  }

  void _sendActiveTerminalInput(String text) {
    _runtimeRegistry.sendTerminalInput(_activePaneState.sessionId, text);
  }

  void _sendActiveTerminalControlKey(TerminalControlInputKey key) {
    if (_activePaneState.lifecycle != SessionLifecycleState.connected) {
      return;
    }
    final latch = _modifierLatch;
    final sequence = _terminalControlInputSequence(key, latch);
    _clearLatchedModifiers();
    _sendActiveTerminalInput(sequence);
  }

  String _terminalControlInputSequence(
    TerminalControlInputKey key,
    TerminalModifierLatch latch,
  ) {
    final terminalKey = _terminalKeyForControlInput(key);
    if (terminalKey == null) {
      return terminalControlInputSequence(key, latch);
    }
    final terminal = _activeTerminal;
    final sequence = terminal.inputHandler?.call(
      TerminalKeyboardEvent(
        key: terminalKey,
        shift: latch.shift,
        alt: latch.alt,
        ctrl: latch.ctrl,
        state: terminal,
        altBuffer: terminal.isUsingAltBuffer,
        platform: terminal.platform,
      ),
    );
    return sequence ?? terminalControlInputSequence(key, latch);
  }

  String? _handleTerminalTextInsert(String text) {
    final latch = _modifierLatch;
    if (!latch.isActive) {
      return text;
    }
    final transformed = applyTerminalModifierLatchToText(text, latch);
    _clearLatchedModifiers();
    return transformed;
  }

  void _toggleCtrlLatch() {
    _setModifierLatch(ctrl: !_ctrlLatched);
  }

  void _toggleAltLatch() {
    _setModifierLatch(alt: !_altLatched);
  }

  void _toggleShiftLatch() {
    _setModifierLatch(shift: !_shiftLatched);
  }

  void _setModifierLatch({bool? ctrl, bool? alt, bool? shift}) {
    if (_activePaneState.lifecycle != SessionLifecycleState.connected) {
      return;
    }
    setState(() {
      _ctrlLatched = ctrl ?? _ctrlLatched;
      _altLatched = alt ?? _altLatched;
      _shiftLatched = shift ?? _shiftLatched;
    });
  }

  void _clearLatchedModifiers() {
    if (!_modifierLatch.isActive || !mounted) {
      return;
    }
    setState(() {
      _ctrlLatched = false;
      _altLatched = false;
      _shiftLatched = false;
    });
  }

  Future<void> _pasteClipboard() async {
    if (_activePaneState.lifecycle != SessionLifecycleState.connected) {
      return;
    }
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (!mounted ||
        text == null ||
        text.isEmpty ||
        _activePaneState.lifecycle != SessionLifecycleState.connected) {
      return;
    }
    _clearLatchedModifiers();
    _activeTerminal.paste(text);
  }

  void _setActivePane(int index) {
    final normalizedIndex = index.clamp(0, widget.panes.length - 1);
    if (normalizedIndex < _terminalFocusNodes.length &&
        !_terminalFocusNodes[normalizedIndex].hasFocus) {
      _terminalFocusNodes[normalizedIndex].requestFocus();
    }
    ref
        .read(workspaceTabControllerProvider.notifier)
        .setActiveTerminalPane(widget.tabId, normalizedIndex);
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
    final pane = _activePaneState;
    final sessionId = pane.sessionId;
    if (_forwardBusySessions.contains(sessionId) ||
        _activePaneHostId == null ||
        pane.lifecycle != SessionLifecycleState.connected) {
      return;
    }
    final action = await showSerlinkDialog<_ForwardDialogAction>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ForwardingDialog(
        activeLocalForward: _localForwards[sessionId],
        activeRemoteForward: _remoteForwards[sessionId],
        activeDynamicForward: _dynamicForwards[sessionId],
      ),
    );
    if (action == null || !_paneSessionConnected(sessionId)) {
      return;
    }
    switch (action.kind) {
      case _ForwardDialogActionKind.startLocal:
        await _startLocalForward(sessionId, action.localDraft!);
      case _ForwardDialogActionKind.stopLocal:
        await _stopLocalForward(sessionId);
      case _ForwardDialogActionKind.startRemote:
        await _startRemoteForward(sessionId, action.remoteDraft!);
      case _ForwardDialogActionKind.stopRemote:
        await _stopRemoteForward(sessionId);
      case _ForwardDialogActionKind.startDynamic:
        await _startDynamicForward(sessionId, action.dynamicDraft!);
      case _ForwardDialogActionKind.stopDynamic:
        await _stopDynamicForward(sessionId);
    }
  }

  Future<void> _startLocalForward(
    SessionId sessionId,
    _LocalForwardDraft draft,
  ) async {
    final l10n = context.l10n;
    setState(() {
      _forwardBusySessions.add(sessionId);
    });
    try {
      await ref
          .read(sshSessionServiceProvider)
          .startLocalForward(
            sessionId: sessionId,
            localPort: draft.localPort,
            remoteHost: draft.remoteHost,
            remotePort: draft.remotePort,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        if (_paneSessionConnected(sessionId)) {
          _localForwards[sessionId] = draft;
        }
        _forwardBusySessions.remove(sessionId);
      });
      _showSnackBar(context, l10n.forwardingLocalStartedSnack);
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() {
        _forwardBusySessions.remove(sessionId);
      });
      _showSnackBar(context, l10n.forwardingLocalStartFailedSnack);
    }
  }

  Future<void> _stopLocalForward(SessionId sessionId) async {
    final l10n = context.l10n;
    setState(() {
      _forwardBusySessions.add(sessionId);
    });
    try {
      await ref
          .read(sshSessionServiceProvider)
          .stopLocalForward(sessionId: sessionId);
      if (!mounted) {
        return;
      }
      setState(() {
        _localForwards.remove(sessionId);
        _forwardBusySessions.remove(sessionId);
      });
      _showSnackBar(context, l10n.forwardingLocalStoppedSnack);
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() {
        _forwardBusySessions.remove(sessionId);
      });
      _showSnackBar(context, l10n.forwardingLocalStopFailedSnack);
    }
  }

  Future<void> _startRemoteForward(
    SessionId sessionId,
    _RemoteForwardDraft draft,
  ) async {
    final l10n = context.l10n;
    setState(() {
      _forwardBusySessions.add(sessionId);
    });
    try {
      final binding = await ref
          .read(sshSessionServiceProvider)
          .startRemoteForward(
            sessionId: sessionId,
            bindHost: draft.bindHost,
            bindPort: draft.bindPort,
            localHost: draft.localHost,
            localPort: draft.localPort,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        if (_paneSessionConnected(sessionId)) {
          _remoteForwards[sessionId] = _RemoteForwardDraft(
            bindHost: binding.bindHost,
            bindPort: binding.bindPort,
            localHost: binding.localHost,
            localPort: binding.localPort,
          );
        }
        _forwardBusySessions.remove(sessionId);
      });
      _showSnackBar(context, l10n.forwardingRemoteStartedSnack);
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() {
        _forwardBusySessions.remove(sessionId);
      });
      _showSnackBar(context, l10n.forwardingRemoteStartFailedSnack);
    }
  }

  Future<void> _stopRemoteForward(SessionId sessionId) async {
    final l10n = context.l10n;
    setState(() {
      _forwardBusySessions.add(sessionId);
    });
    try {
      await ref
          .read(sshSessionServiceProvider)
          .stopRemoteForward(sessionId: sessionId);
      if (!mounted) {
        return;
      }
      setState(() {
        _remoteForwards.remove(sessionId);
        _forwardBusySessions.remove(sessionId);
      });
      _showSnackBar(context, l10n.forwardingRemoteStoppedSnack);
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() {
        _forwardBusySessions.remove(sessionId);
      });
      _showSnackBar(context, l10n.forwardingRemoteStopFailedSnack);
    }
  }

  Future<void> _startDynamicForward(
    SessionId sessionId,
    _DynamicForwardDraft draft,
  ) async {
    final l10n = context.l10n;
    setState(() {
      _forwardBusySessions.add(sessionId);
    });
    try {
      final binding = await ref
          .read(sshSessionServiceProvider)
          .startDynamicForward(
            sessionId: sessionId,
            bindHost: draft.bindHost,
            bindPort: draft.bindPort,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        if (_paneSessionConnected(sessionId)) {
          _dynamicForwards[sessionId] = _DynamicForwardDraft(
            bindHost: binding.bindHost,
            bindPort: binding.bindPort,
          );
        }
        _forwardBusySessions.remove(sessionId);
      });
      _showSnackBar(context, l10n.forwardingSocksStartedSnack);
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() {
        _forwardBusySessions.remove(sessionId);
      });
      _showSnackBar(context, l10n.forwardingSocksStartFailedSnack);
    }
  }

  Future<void> _stopDynamicForward(SessionId sessionId) async {
    final l10n = context.l10n;
    setState(() {
      _forwardBusySessions.add(sessionId);
    });
    try {
      await ref
          .read(sshSessionServiceProvider)
          .stopDynamicForward(sessionId: sessionId);
      if (!mounted) {
        return;
      }
      setState(() {
        _dynamicForwards.remove(sessionId);
        _forwardBusySessions.remove(sessionId);
      });
      _showSnackBar(context, l10n.forwardingSocksStoppedSnack);
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() {
        _forwardBusySessions.remove(sessionId);
      });
      _showSnackBar(context, l10n.forwardingSocksStopFailedSnack);
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
    final latchResult = _handleLatchedHardwareKey(event);
    if (latchResult != KeyEventResult.ignored) {
      return latchResult;
    }
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

  KeyEventResult _handleLatchedHardwareKey(KeyEvent event) {
    final latch = _modifierLatch;
    if (!latch.isActive ||
        (event is! KeyDownEvent && event is! KeyRepeatEvent)) {
      return KeyEventResult.ignored;
    }

    final character = event.character;
    if (character != null && character.isNotEmpty) {
      final transformed = applyTerminalModifierLatchToText(character, latch);
      _clearLatchedModifiers();
      if (transformed == character) {
        return KeyEventResult.ignored;
      }
      _sendActiveTerminalInput(transformed);
      return KeyEventResult.handled;
    }

    final controlKey = _terminalControlKeyForLogicalKey(event.logicalKey);
    if (controlKey == null) {
      return KeyEventResult.ignored;
    }
    _clearLatchedModifiers();
    _sendActiveTerminalInput(terminalControlInputSequence(controlKey, latch));
    return KeyEventResult.handled;
  }

  TerminalModifierLatch get _modifierLatch {
    return TerminalModifierLatch(
      ctrl: _ctrlLatched,
      alt: _altLatched,
      shift: _shiftLatched,
    );
  }

  TerminalPaneState get _activePaneState {
    return widget.panes[widget.activePane.clamp(0, widget.panes.length - 1)];
  }

  void _pruneForwardingState() {
    final connectedSessionIds = {
      for (final pane in widget.panes)
        if (pane.lifecycle == SessionLifecycleState.connected) pane.sessionId,
    };
    _localForwards.removeWhere(
      (sessionId, _) => !connectedSessionIds.contains(sessionId),
    );
    _remoteForwards.removeWhere(
      (sessionId, _) => !connectedSessionIds.contains(sessionId),
    );
    _dynamicForwards.removeWhere(
      (sessionId, _) => !connectedSessionIds.contains(sessionId),
    );
    _forwardBusySessions.removeWhere(
      (sessionId) => !connectedSessionIds.contains(sessionId),
    );
  }

  bool _paneSessionConnected(SessionId sessionId) {
    final tab = ref
        .read(workspaceTabControllerProvider)
        .tabs
        .where((candidate) => candidate.id == widget.tabId)
        .firstOrNull;
    final panes = switch (tab?.content) {
      TerminalTabContent(:final panes) => panes,
      LocalTerminalTabContent(:final panes) => panes,
      _ => widget.panes,
    };
    return panes.any(
      (pane) =>
          pane.sessionId == sessionId &&
          pane.lifecycle == SessionLifecycleState.connected,
    );
  }

  HostId? get _activePaneHostId {
    final endpoint = _activePaneState.endpoint;
    if (endpoint?.isLocal == true) {
      return null;
    }
    return endpoint?.hostId ?? widget.hostId;
  }

  Terminal get _activeTerminal {
    final terminals = _terminals();
    return terminals[widget.activePane.clamp(0, terminals.length - 1)];
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
    _terminalFocusNodes = [
      for (var i = 0; i < widget.panes.length; i += 1)
        FocusNode(debugLabel: 'terminal-pane-$i')
          ..addListener(() => _handlePaneFocusChanged(i)),
    ];
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

  void _handlePaneFocusChanged(int paneIndex) {
    if (!mounted || paneIndex >= _terminalFocusNodes.length) {
      return;
    }
    if (_terminalFocusNodes[paneIndex].hasFocus &&
        widget.activePane != paneIndex) {
      ref
          .read(workspaceTabControllerProvider.notifier)
          .setActiveTerminalPane(widget.tabId, paneIndex);
    }
  }

  Size _activePaneApproximateSize() {
    final constraints = _terminalViewportConstraints;
    if (constraints == null) {
      return const Size(_terminalMinPaneWidth * 2, _terminalMinPaneHeight * 2);
    }
    if (!widget.showSplit || widget.panes.length <= 1) {
      return Size(constraints.maxWidth, constraints.maxHeight);
    }
    final viewportSize = Size(
      math.max(0, constraints.maxWidth - _terminalPaneGap * 2),
      math.max(0, constraints.maxHeight - _terminalPaneGap * 2),
    );
    return _paneApproximateSizeForLayout(
      widget.layout,
      widget.activePane.clamp(0, widget.panes.length - 1),
      viewportSize,
    );
  }

  Size _paneApproximateSizeForLayout(
    TerminalPaneLayout layout,
    int targetPaneIndex,
    Size size,
  ) {
    return switch (layout) {
      TerminalPaneLeaf() => size,
      TerminalPaneSplit(
        :final axis,
        :final ratio,
        :final first,
        :final second,
      ) =>
        _paneApproximateSizeForSplit(
          axis: axis,
          ratio: ratio,
          first: first,
          second: second,
          targetPaneIndex: targetPaneIndex,
          size: size,
        ),
    };
  }

  Size _paneApproximateSizeForSplit({
    required Axis axis,
    required double ratio,
    required TerminalPaneLayout first,
    required TerminalPaneLayout second,
    required int targetPaneIndex,
    required Size size,
  }) {
    final firstSide = first.paneIndexes.contains(targetPaneIndex);
    final totalExtent = axis == Axis.horizontal ? size.width : size.height;
    final availableExtent = math.max(0, totalExtent - _terminalDividerHitSize);
    final firstExtent = availableExtent * ratio.clamp(0.1, 0.9).toDouble();
    final secondExtent = math.max(0, availableExtent - firstExtent).toDouble();
    final childSize = axis == Axis.horizontal
        ? Size(firstSide ? firstExtent : secondExtent, size.height)
        : Size(size.width, firstSide ? firstExtent : secondExtent);
    return _paneApproximateSizeForLayout(
      firstSide ? first : second,
      targetPaneIndex,
      childSize,
    );
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

TerminalControlInputKey? _terminalControlKeyForLogicalKey(
  LogicalKeyboardKey key,
) {
  return switch (key) {
    LogicalKeyboardKey.escape => TerminalControlInputKey.escape,
    LogicalKeyboardKey.tab => TerminalControlInputKey.tab,
    LogicalKeyboardKey.enter => TerminalControlInputKey.enter,
    LogicalKeyboardKey.backspace => TerminalControlInputKey.backspace,
    LogicalKeyboardKey.insert => TerminalControlInputKey.insert,
    LogicalKeyboardKey.delete => TerminalControlInputKey.delete,
    LogicalKeyboardKey.arrowUp => TerminalControlInputKey.arrowUp,
    LogicalKeyboardKey.arrowDown => TerminalControlInputKey.arrowDown,
    LogicalKeyboardKey.arrowLeft => TerminalControlInputKey.arrowLeft,
    LogicalKeyboardKey.arrowRight => TerminalControlInputKey.arrowRight,
    LogicalKeyboardKey.pageUp => TerminalControlInputKey.pageUp,
    LogicalKeyboardKey.pageDown => TerminalControlInputKey.pageDown,
    LogicalKeyboardKey.home => TerminalControlInputKey.home,
    LogicalKeyboardKey.end => TerminalControlInputKey.end,
    LogicalKeyboardKey.f1 => TerminalControlInputKey.f1,
    LogicalKeyboardKey.f2 => TerminalControlInputKey.f2,
    LogicalKeyboardKey.f3 => TerminalControlInputKey.f3,
    LogicalKeyboardKey.f4 => TerminalControlInputKey.f4,
    LogicalKeyboardKey.f5 => TerminalControlInputKey.f5,
    LogicalKeyboardKey.f6 => TerminalControlInputKey.f6,
    LogicalKeyboardKey.f7 => TerminalControlInputKey.f7,
    LogicalKeyboardKey.f8 => TerminalControlInputKey.f8,
    LogicalKeyboardKey.f9 => TerminalControlInputKey.f9,
    LogicalKeyboardKey.f10 => TerminalControlInputKey.f10,
    LogicalKeyboardKey.f11 => TerminalControlInputKey.f11,
    LogicalKeyboardKey.f12 => TerminalControlInputKey.f12,
    _ => null,
  };
}

TerminalKey? _terminalKeyForControlInput(TerminalControlInputKey key) {
  return switch (key) {
    TerminalControlInputKey.escape => TerminalKey.escape,
    TerminalControlInputKey.tab => TerminalKey.tab,
    TerminalControlInputKey.enter => TerminalKey.enter,
    TerminalControlInputKey.backspace => TerminalKey.backspace,
    TerminalControlInputKey.insert => TerminalKey.insert,
    TerminalControlInputKey.delete => TerminalKey.delete,
    TerminalControlInputKey.arrowUp => TerminalKey.arrowUp,
    TerminalControlInputKey.arrowDown => TerminalKey.arrowDown,
    TerminalControlInputKey.arrowLeft => TerminalKey.arrowLeft,
    TerminalControlInputKey.arrowRight => TerminalKey.arrowRight,
    TerminalControlInputKey.pageUp => TerminalKey.pageUp,
    TerminalControlInputKey.pageDown => TerminalKey.pageDown,
    TerminalControlInputKey.home => TerminalKey.home,
    TerminalControlInputKey.end => TerminalKey.end,
    TerminalControlInputKey.f1 => TerminalKey.f1,
    TerminalControlInputKey.f2 => TerminalKey.f2,
    TerminalControlInputKey.f3 => TerminalKey.f3,
    TerminalControlInputKey.f4 => TerminalKey.f4,
    TerminalControlInputKey.f5 => TerminalKey.f5,
    TerminalControlInputKey.f6 => TerminalKey.f6,
    TerminalControlInputKey.f7 => TerminalKey.f7,
    TerminalControlInputKey.f8 => TerminalKey.f8,
    TerminalControlInputKey.f9 => TerminalKey.f9,
    TerminalControlInputKey.f10 => TerminalKey.f10,
    TerminalControlInputKey.f11 => TerminalKey.f11,
    TerminalControlInputKey.f12 => TerminalKey.f12,
  };
}

class _TerminalAccessoryBar extends StatefulWidget {
  const _TerminalAccessoryBar({
    required this.connected,
    required this.ctrlLatched,
    required this.altLatched,
    required this.shiftLatched,
    required this.onToggleCtrl,
    required this.onToggleAlt,
    required this.onToggleShift,
    required this.onControlKey,
    required this.onPaste,
    required this.onToggleSearch,
    required this.onOpenSnippets,
  });

  final bool connected;
  final bool ctrlLatched;
  final bool altLatched;
  final bool shiftLatched;
  final VoidCallback onToggleCtrl;
  final VoidCallback onToggleAlt;
  final VoidCallback onToggleShift;
  final ValueChanged<TerminalControlInputKey> onControlKey;
  final VoidCallback onPaste;
  final VoidCallback onToggleSearch;
  final VoidCallback onOpenSnippets;

  @override
  State<_TerminalAccessoryBar> createState() => _TerminalAccessoryBarState();
}

class _TerminalAccessoryBarState extends State<_TerminalAccessoryBar> {
  var _functionKeysExpanded = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.surfaceRaised,
        border: Border(top: BorderSide(color: t.borderSubtle)),
      ),
      child: SizedBox(
        key: const ValueKey('terminal-accessory-bar'),
        height: 70,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 5, 0, 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TerminalAccessoryCluster(
                  top: [
                    _TerminalAccessoryKey(
                      keyValue: 'terminal-key-ctrl',
                      label: 'Ctrl',
                      enabled: widget.connected,
                      selected: widget.ctrlLatched,
                      onPressed: widget.onToggleCtrl,
                    ),
                    _TerminalAccessoryKey(
                      keyValue: 'terminal-key-shift',
                      label: 'Shift',
                      enabled: widget.connected,
                      selected: widget.shiftLatched,
                      onPressed: widget.onToggleShift,
                    ),
                    _TerminalAccessoryKey(
                      keyValue: 'terminal-key-alt',
                      label: 'Alt',
                      enabled: widget.connected,
                      selected: widget.altLatched,
                      onPressed: widget.onToggleAlt,
                    ),
                    _TerminalAccessoryKey(
                      keyValue: 'terminal-key-esc',
                      label: 'Esc',
                      enabled: widget.connected,
                      onPressed: () =>
                          widget.onControlKey(TerminalControlInputKey.escape),
                    ),
                  ],
                  bottom: [
                    _TerminalAccessoryKey(
                      keyValue: 'terminal-key-tab',
                      label: 'Tab',
                      enabled: widget.connected,
                      onPressed: () =>
                          widget.onControlKey(TerminalControlInputKey.tab),
                    ),
                    _TerminalAccessoryKey(
                      keyValue: 'terminal-key-function-toggle',
                      label: 'Fn',
                      enabled: true,
                      selected: _functionKeysExpanded,
                      onPressed: () {
                        setState(() {
                          _functionKeysExpanded = !_functionKeysExpanded;
                        });
                      },
                    ),
                    _TerminalAccessoryIconKey(
                      keyValue: 'terminal-key-paste',
                      icon: Icons.content_paste,
                      enabled: widget.connected,
                      onPressed: widget.onPaste,
                    ),
                  ],
                ),
                const SizedBox(width: _terminalAccessoryGroupGap),
                if (_functionKeysExpanded) ...[
                  _TerminalFunctionKeyCluster(
                    connected: widget.connected,
                    onControlKey: widget.onControlKey,
                  ),
                  const SizedBox(width: _terminalAccessoryGroupGap),
                ],
                _TerminalEditKeyCluster(
                  connected: widget.connected,
                  onControlKey: widget.onControlKey,
                ),
                const SizedBox(width: _terminalAccessoryGroupGap),
                _TerminalArrowKeyCluster(
                  connected: widget.connected,
                  onControlKey: widget.onControlKey,
                ),
                const SizedBox(width: _terminalAccessoryGroupGap),
                _TerminalAccessoryCluster(
                  top: [
                    _TerminalAccessoryIconKey(
                      keyValue: 'terminal-key-search',
                      icon: Icons.search,
                      enabled: true,
                      onPressed: widget.onToggleSearch,
                    ),
                    _TerminalAccessoryIconKey(
                      keyValue: 'terminal-key-snippets',
                      icon: Icons.code_outlined,
                      enabled: true,
                      onPressed: widget.onOpenSnippets,
                    ),
                  ],
                  bottom: [
                    const SizedBox.square(
                      dimension: _terminalAccessorySquareSide,
                    ),
                    const SizedBox(width: _terminalAccessoryGap),
                    _TerminalAccessoryIconKey(
                      keyValue: 'terminal-key-keyboard',
                      icon: Icons.keyboard_hide_outlined,
                      enabled: true,
                      onPressed: () => FocusManager.instance.primaryFocus
                          ?.unfocus(disposition: UnfocusDisposition.scope),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

const double _terminalAccessoryGap = 4;
const double _terminalAccessoryGroupGap = 6;
const double _terminalAccessorySquareSide = 28;
const BorderRadius _terminalAccessoryBorderRadius = BorderRadius.all(
  Radius.circular(5),
);

class _TerminalAccessoryCluster extends StatelessWidget {
  const _TerminalAccessoryCluster({required this.top, required this.bottom});

  final List<Widget> top;
  final List<Widget> bottom;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: top),
        const SizedBox(height: _terminalAccessoryGap),
        Row(children: bottom),
      ],
    );
  }
}

class _TerminalFunctionKeyCluster extends StatelessWidget {
  const _TerminalFunctionKeyCluster({
    required this.connected,
    required this.onControlKey,
  });

  final bool connected;
  final ValueChanged<TerminalControlInputKey> onControlKey;

  @override
  Widget build(BuildContext context) {
    return _TerminalAccessoryCluster(
      top: [
        _functionKey('F1', TerminalControlInputKey.f1),
        _functionKey('F2', TerminalControlInputKey.f2),
        _functionKey('F3', TerminalControlInputKey.f3),
        _functionKey('F4', TerminalControlInputKey.f4),
        _functionKey('F5', TerminalControlInputKey.f5),
        _functionKey('F6', TerminalControlInputKey.f6),
      ],
      bottom: [
        _functionKey('F7', TerminalControlInputKey.f7),
        _functionKey('F8', TerminalControlInputKey.f8),
        _functionKey('F9', TerminalControlInputKey.f9),
        _functionKey('F10', TerminalControlInputKey.f10),
        _functionKey('F11', TerminalControlInputKey.f11),
        _functionKey('F12', TerminalControlInputKey.f12),
      ],
    );
  }

  Widget _functionKey(String label, TerminalControlInputKey key) {
    return _TerminalAccessoryKey(
      keyValue: 'terminal-key-${label.toLowerCase()}',
      label: label,
      enabled: connected,
      onPressed: () => onControlKey(key),
    );
  }
}

class _TerminalEditKeyCluster extends StatelessWidget {
  const _TerminalEditKeyCluster({
    required this.connected,
    required this.onControlKey,
  });

  final bool connected;
  final ValueChanged<TerminalControlInputKey> onControlKey;

  @override
  Widget build(BuildContext context) {
    return _TerminalAccessoryCluster(
      top: [
        _TerminalAccessoryKey(
          keyValue: 'terminal-key-insert',
          label: 'Ins',
          enabled: connected,
          onPressed: () => onControlKey(TerminalControlInputKey.insert),
        ),
        _TerminalAccessoryKey(
          keyValue: 'terminal-key-delete',
          label: 'Del',
          enabled: connected,
          onPressed: () => onControlKey(TerminalControlInputKey.delete),
        ),
      ],
      bottom: [
        _TerminalAccessoryKey(
          keyValue: 'terminal-key-home',
          label: 'Home',
          enabled: connected,
          onPressed: () => onControlKey(TerminalControlInputKey.home),
        ),
        _TerminalAccessoryKey(
          keyValue: 'terminal-key-end',
          label: 'End',
          enabled: connected,
          onPressed: () => onControlKey(TerminalControlInputKey.end),
        ),
      ],
    );
  }
}

class _TerminalArrowKeyCluster extends StatelessWidget {
  const _TerminalArrowKeyCluster({
    required this.connected,
    required this.onControlKey,
  });

  final bool connected;
  final ValueChanged<TerminalControlInputKey> onControlKey;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            _TerminalAccessoryKey(
              keyValue: 'terminal-key-page-up',
              label: 'PgUp',
              enabled: connected,
              onPressed: () => onControlKey(TerminalControlInputKey.pageUp),
            ),
            _TerminalAccessoryIconKey(
              keyValue: 'terminal-key-arrow-up',
              icon: Icons.keyboard_arrow_up,
              enabled: connected,
              onPressed: () => onControlKey(TerminalControlInputKey.arrowUp),
            ),
            _TerminalAccessoryKey(
              keyValue: 'terminal-key-page-down',
              label: 'PgDn',
              enabled: connected,
              onPressed: () => onControlKey(TerminalControlInputKey.pageDown),
            ),
          ],
        ),
        const SizedBox(height: _terminalAccessoryGap),
        Row(
          children: [
            _TerminalAccessoryIconKey(
              keyValue: 'terminal-key-arrow-left',
              icon: Icons.keyboard_arrow_left,
              enabled: connected,
              onPressed: () => onControlKey(TerminalControlInputKey.arrowLeft),
            ),
            _TerminalAccessoryIconKey(
              keyValue: 'terminal-key-arrow-down',
              icon: Icons.keyboard_arrow_down,
              enabled: connected,
              onPressed: () => onControlKey(TerminalControlInputKey.arrowDown),
            ),
            _TerminalAccessoryIconKey(
              keyValue: 'terminal-key-arrow-right',
              icon: Icons.keyboard_arrow_right,
              enabled: connected,
              onPressed: () => onControlKey(TerminalControlInputKey.arrowRight),
            ),
          ],
        ),
      ],
    );
  }
}

class _TerminalAccessoryKey extends StatelessWidget {
  const _TerminalAccessoryKey({
    this.keyValue,
    required this.label,
    required this.enabled,
    required this.onPressed,
    this.selected = false,
  });

  final String? keyValue;
  final String label;
  final bool enabled;
  final VoidCallback? onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      key: keyValue == null ? null : ValueKey<String>(keyValue!),
      padding: const EdgeInsets.only(right: _terminalAccessoryGap),
      child: SerlinkPressable(
        onTap: enabled ? onPressed : null,
        borderRadius: _terminalAccessoryBorderRadius,
        hoverColor: t.accentPrimary.withValues(alpha: 0.1),
        pressedColor: t.accentPrimary.withValues(alpha: 0.2),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 120),
          opacity: enabled ? 1 : 0.45,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: selected
                  ? t.accentPrimary.withValues(alpha: 0.16)
                  : t.surfaceSunken,
              borderRadius: _terminalAccessoryBorderRadius,
              border: Border.all(
                color: selected ? t.accentPrimary : t.borderSubtle,
              ),
            ),
            child: SizedBox(
              height: _terminalAccessorySquareSide,
              width: _terminalAccessorySquareSide,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      style: TextStyle(
                        color: selected ? t.accentPrimary : t.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TerminalAccessoryIconKey extends StatelessWidget {
  const _TerminalAccessoryIconKey({
    this.keyValue,
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });

  final String? keyValue;
  final IconData icon;
  final bool enabled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      key: keyValue == null ? null : ValueKey<String>(keyValue!),
      padding: const EdgeInsets.only(right: _terminalAccessoryGap),
      child: SerlinkPressable(
        onTap: enabled ? onPressed : null,
        borderRadius: _terminalAccessoryBorderRadius,
        hoverColor: t.accentPrimary.withValues(alpha: 0.1),
        pressedColor: t.accentPrimary.withValues(alpha: 0.2),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 120),
          opacity: enabled ? 1 : 0.45,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: t.surfaceSunken,
              borderRadius: _terminalAccessoryBorderRadius,
              border: Border.all(color: t.borderSubtle),
            ),
            child: SizedBox.square(
              dimension: _terminalAccessorySquareSide,
              child: Icon(icon, size: 18, color: t.textPrimary),
            ),
          ),
        ),
      ),
    );
  }
}
