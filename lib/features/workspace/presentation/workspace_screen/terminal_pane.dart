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
                  onInsertText: _handleTerminalTextInsert,
                )
              : _SingleTerminalViewport(
                  terminal: _terminals().first,
                  controller: _terminalControllers.first,
                  settings: settings,
                  onKeyEvent: _terminalViewKeyHandler,
                  onInsertText: _handleTerminalTextInsert,
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

  void _sendActiveTerminalInput(String text) {
    _runtimeRegistry.sendTerminalInput(_activePaneState.sessionId, text);
  }

  void _sendActiveTerminalControlKey(TerminalControlInputKey key) {
    if (_activePaneState.lifecycle != SessionLifecycleState.connected) {
      return;
    }
    final sequence = terminalControlInputSequence(key, _modifierLatch);
    _clearLatchedModifiers();
    _sendActiveTerminalInput(sequence);
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
    final l10n = context.l10n;
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
      _showSnackBar(context, l10n.forwardingLocalStartedSnack);
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() {
        _forwardBusy = false;
      });
      _showSnackBar(context, l10n.forwardingLocalStartFailedSnack);
    }
  }

  Future<void> _stopLocalForward() async {
    final l10n = context.l10n;
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
      _showSnackBar(context, l10n.forwardingLocalStoppedSnack);
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() {
        _forwardBusy = false;
      });
      _showSnackBar(context, l10n.forwardingLocalStopFailedSnack);
    }
  }

  Future<void> _startRemoteForward(_RemoteForwardDraft draft) async {
    final l10n = context.l10n;
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
      _showSnackBar(context, l10n.forwardingRemoteStartedSnack);
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() {
        _forwardBusy = false;
      });
      _showSnackBar(context, l10n.forwardingRemoteStartFailedSnack);
    }
  }

  Future<void> _stopRemoteForward() async {
    final l10n = context.l10n;
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
      _showSnackBar(context, l10n.forwardingRemoteStoppedSnack);
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() {
        _forwardBusy = false;
      });
      _showSnackBar(context, l10n.forwardingRemoteStopFailedSnack);
    }
  }

  Future<void> _startDynamicForward(_DynamicForwardDraft draft) async {
    final l10n = context.l10n;
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
      _showSnackBar(context, l10n.forwardingSocksStartedSnack);
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() {
        _forwardBusy = false;
      });
      _showSnackBar(context, l10n.forwardingSocksStartFailedSnack);
    }
  }

  Future<void> _stopDynamicForward() async {
    final l10n = context.l10n;
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
      _showSnackBar(context, l10n.forwardingSocksStoppedSnack);
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() {
        _forwardBusy = false;
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

TerminalControlInputKey? _terminalControlKeyForLogicalKey(
  LogicalKeyboardKey key,
) {
  return switch (key) {
    LogicalKeyboardKey.escape => TerminalControlInputKey.escape,
    LogicalKeyboardKey.tab => TerminalControlInputKey.tab,
    LogicalKeyboardKey.enter => TerminalControlInputKey.enter,
    LogicalKeyboardKey.backspace => TerminalControlInputKey.backspace,
    LogicalKeyboardKey.delete => TerminalControlInputKey.delete,
    LogicalKeyboardKey.arrowUp => TerminalControlInputKey.arrowUp,
    LogicalKeyboardKey.arrowDown => TerminalControlInputKey.arrowDown,
    LogicalKeyboardKey.arrowLeft => TerminalControlInputKey.arrowLeft,
    LogicalKeyboardKey.arrowRight => TerminalControlInputKey.arrowRight,
    LogicalKeyboardKey.pageUp => TerminalControlInputKey.pageUp,
    LogicalKeyboardKey.pageDown => TerminalControlInputKey.pageDown,
    LogicalKeyboardKey.home => TerminalControlInputKey.home,
    LogicalKeyboardKey.end => TerminalControlInputKey.end,
    _ => null,
  };
}

class _TerminalAccessoryBar extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final t = context.tokens;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.surfaceRaised,
        border: Border(top: BorderSide(color: t.borderSubtle)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          key: const ValueKey('terminal-accessory-bar'),
          height: 72,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 0, 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TerminalAccessoryCluster(
                    top: [
                      _TerminalAccessoryKey(
                        keyValue: 'terminal-key-ctrl',
                        label: 'Ctrl',
                        enabled: connected,
                        selected: ctrlLatched,
                        onPressed: onToggleCtrl,
                      ),
                      _TerminalAccessoryKey(
                        keyValue: 'terminal-key-shift',
                        label: 'Shift',
                        enabled: connected,
                        selected: shiftLatched,
                        onPressed: onToggleShift,
                      ),
                      _TerminalAccessoryKey(
                        keyValue: 'terminal-key-alt',
                        label: 'Alt',
                        enabled: connected,
                        selected: altLatched,
                        onPressed: onToggleAlt,
                      ),
                      _TerminalAccessoryKey(
                        keyValue: 'terminal-key-esc',
                        label: 'Esc',
                        enabled: connected,
                        onPressed: () =>
                            onControlKey(TerminalControlInputKey.escape),
                      ),
                    ],
                    bottom: [
                      _TerminalAccessoryKey(
                        keyValue: 'terminal-key-tab',
                        label: 'Tab',
                        enabled: connected,
                        onPressed: () =>
                            onControlKey(TerminalControlInputKey.tab),
                      ),
                      _TerminalAccessoryKey(
                        keyValue: 'terminal-key-home',
                        label: 'Home',
                        enabled: connected,
                        onPressed: () =>
                            onControlKey(TerminalControlInputKey.home),
                      ),
                      _TerminalAccessoryKey(
                        keyValue: 'terminal-key-end',
                        label: 'End',
                        enabled: connected,
                        onPressed: () =>
                            onControlKey(TerminalControlInputKey.end),
                      ),
                      _TerminalAccessoryIconKey(
                        keyValue: 'terminal-key-paste',
                        icon: Icons.content_paste,
                        enabled: connected,
                        onPressed: onPaste,
                      ),
                    ],
                  ),
                  const SizedBox(width: _terminalAccessoryGroupGap),
                  _TerminalArrowKeyCluster(
                    connected: connected,
                    onControlKey: onControlKey,
                  ),
                  const SizedBox(width: _terminalAccessoryGroupGap),
                  _TerminalAccessoryCluster(
                    top: [
                      _TerminalAccessoryKey(
                        keyValue: 'terminal-key-page-up',
                        label: 'PgUp',
                        enabled: connected,
                        onPressed: () =>
                            onControlKey(TerminalControlInputKey.pageUp),
                      ),
                      _TerminalAccessoryKey(
                        keyValue: 'terminal-key-page-down',
                        label: 'PgDn',
                        enabled: connected,
                        onPressed: () =>
                            onControlKey(TerminalControlInputKey.pageDown),
                      ),
                    ],
                    bottom: [
                      _TerminalAccessoryIconKey(
                        keyValue: 'terminal-key-search',
                        icon: Icons.search,
                        enabled: true,
                        onPressed: onToggleSearch,
                      ),
                      _TerminalAccessoryIconKey(
                        keyValue: 'terminal-key-snippets',
                        icon: Icons.code_outlined,
                        enabled: true,
                        onPressed: onOpenSnippets,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const double _terminalAccessoryGap = 4;
const double _terminalAccessoryGroupGap = 6;
const double _terminalAccessoryKeyHeight = 28;
const double _terminalAccessoryShortKeyWidth = 38;
const double _terminalAccessoryLongKeyWidth = 44;
const double _terminalAccessoryIconSide = 28;

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

class _TerminalArrowKeyCluster extends StatelessWidget {
  const _TerminalArrowKeyCluster({
    required this.connected,
    required this.onControlKey,
  });

  final bool connected;
  final ValueChanged<TerminalControlInputKey> onControlKey;

  @override
  Widget build(BuildContext context) {
    const spacerWidth = _terminalAccessoryIconSide + _terminalAccessoryGap;
    return Column(
      children: [
        Row(
          children: [
            const SizedBox(width: spacerWidth),
            _TerminalAccessoryIconKey(
              keyValue: 'terminal-key-arrow-up',
              icon: Icons.keyboard_arrow_up,
              enabled: connected,
              onPressed: () => onControlKey(TerminalControlInputKey.arrowUp),
            ),
            const SizedBox(width: spacerWidth),
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
        borderRadius: SerlinkRadii.control,
        hoverColor: t.accentPrimary.withValues(alpha: 0.08),
        pressedColor: t.accentPrimary.withValues(alpha: 0.14),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 120),
          opacity: enabled ? 1 : 0.45,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: selected
                  ? t.accentPrimary.withValues(alpha: 0.16)
                  : t.surfaceSunken,
              borderRadius: SerlinkRadii.control,
              border: Border.all(
                color: selected ? t.accentPrimary : t.borderSubtle,
              ),
            ),
            child: SizedBox(
              height: _terminalAccessoryKeyHeight,
              width: label.length > 4
                  ? _terminalAccessoryLongKeyWidth
                  : _terminalAccessoryShortKeyWidth,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      style: TextStyle(
                        color: selected ? t.accentPrimary : t.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 11.5,
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
        borderRadius: SerlinkRadii.control,
        hoverColor: t.accentPrimary.withValues(alpha: 0.08),
        pressedColor: t.accentPrimary.withValues(alpha: 0.14),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 120),
          opacity: enabled ? 1 : 0.45,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: t.surfaceSunken,
              borderRadius: SerlinkRadii.control,
              border: Border.all(color: t.borderSubtle),
            ),
            child: SizedBox.square(
              dimension: _terminalAccessoryIconSide,
              child: Icon(icon, size: 18, color: t.textPrimary),
            ),
          ),
        ),
      ),
    );
  }
}
