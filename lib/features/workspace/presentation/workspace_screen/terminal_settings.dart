part of '../workspace_screen.dart';

/// Viewport sizing for the terminal settings dialog/sheet: the content height
/// follows a fraction of the available window height, clamped so the dialog
/// stays usable on small windows and does not stretch on large ones.
const double _settingsSheetHeightFactor = 0.62;
const double _settingsSheetMinHeight = 300;
const double _settingsSheetMaxHeight = 460;
const double _settingsDialogHeightFactorIOS = 0.58;
const double _settingsDialogMinHeightIOS = 320;
const double _settingsDialogMaxHeightIOS = 500;
const double _settingsDialogHeightFactor = 0.72;
const double _settingsDialogMaxHeight = 640;

class _TerminalSearchBar extends StatelessWidget {
  const _TerminalSearchBar({
    required this.controller,
    required this.result,
    required this.onChanged,
    required this.onPrevious,
    required this.onNext,
    required this.onClose,
  });

  final TextEditingController controller;
  final TerminalSearchResult result;
  final ValueChanged<String> onChanged;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    final hasMatches = result.matchCount > 0;
    final countLabel = hasMatches
        ? '${result.displayIndex}/${result.matchCount}'
        : l10n.terminalNoSearchResults;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.surfaceRaised,
        border: Border(bottom: BorderSide(color: t.borderSubtle)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          children: [
            // Unified find-bar pill: borderless field + inline count + nav.
            Expanded(
              child: Container(
                height: 38,
                padding: const EdgeInsets.only(left: 12, right: 4),
                decoration: BoxDecoration(
                  color: t.surfaceSunken,
                  borderRadius: SerlinkRadii.control,
                  border: Border.all(color: t.borderSubtle),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search, size: 16, color: t.textMuted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SerlinkTextField(
                        key: const ValueKey('terminal-search-field'),
                        controller: controller,
                        autofocus: true,
                        style: TextStyle(color: t.textPrimary, fontSize: 13.5),
                        decoration: InputDecoration(
                          isCollapsed: true,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          hintText: l10n.terminalSearchTooltip,
                          hintStyle: TextStyle(color: t.textMuted),
                        ),
                        onChanged: onChanged,
                        onSubmitted: (_) => onNext(),
                      ),
                    ),
                    Text(
                      countLabel,
                      style: TextStyle(
                        color: hasMatches ? t.textSecondary : t.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(width: 1, height: 18, color: t.borderSubtle),
                    SerlinkIconButton(
                      tooltip: l10n.terminalPreviousMatchTooltip,
                      visualDensity: VisualDensity.compact,
                      onPressed: hasMatches ? onPrevious : null,
                      icon: const Icon(Icons.keyboard_arrow_up, size: 18),
                    ),
                    SerlinkIconButton(
                      tooltip: l10n.terminalNextMatchTooltip,
                      visualDensity: VisualDensity.compact,
                      onPressed: hasMatches ? onNext : null,
                      icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            SerlinkIconButton(
              tooltip: l10n.terminalCloseSearchTooltip,
              onPressed: onClose,
              icon: const Icon(Icons.close, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showTerminalSettingsDialog(
  BuildContext context, {
  required WorkspaceTabId tabId,
  required HostId? hostId,
  required int paneIndex,
  required bool preferSheet,
}) {
  if (preferSheet) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _TerminalSettingsDialog(
        tabId: tabId,
        hostId: hostId,
        paneIndex: paneIndex,
        presentation: _TerminalSettingsPresentation.sheet,
      ),
    );
  }
  return showSerlinkDialog<void>(
    context: context,
    useSafeArea: true,
    builder: (context) => _TerminalSettingsDialog(
      tabId: tabId,
      hostId: hostId,
      paneIndex: paneIndex,
    ),
  );
}

enum _TerminalSettingsPresentation { dialog, sheet }

class _TerminalSettingsDialog extends ConsumerStatefulWidget {
  const _TerminalSettingsDialog({
    required this.tabId,
    required this.hostId,
    required this.paneIndex,
    this.presentation = _TerminalSettingsPresentation.dialog,
  });

  final WorkspaceTabId tabId;
  final HostId? hostId;
  final int paneIndex;
  final _TerminalSettingsPresentation presentation;

  @override
  ConsumerState<_TerminalSettingsDialog> createState() =>
      _TerminalSettingsDialogState();
}

class _TerminalSettingsDialogState
    extends ConsumerState<_TerminalSettingsDialog> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final workspaceState = ref.watch(workspaceTabControllerProvider);
    final hostSettings = _terminalDisplaySettingsForTab(
      workspaceState,
      widget.tabId,
      widget.paneIndex,
    );
    final globalSettings =
        ref.watch(terminalDisplaySettingsProvider).value ??
        const TerminalDisplaySettings();
    final settings = hostSettings ?? globalSettings;
    final fontCatalogAsync = ref.watch(terminalFontCatalogProvider);
    final fontCatalog =
        fontCatalogAsync.value ?? TerminalFontCatalog.fallback();
    final editingHostProfile = widget.hostId != null && hostSettings != null;
    final globalController = ref.read(terminalDisplaySettingsProvider.notifier);
    final workspaceController = ref.read(
      workspaceTabControllerProvider.notifier,
    );
    final isIOS = ref.watch(
      platformCapabilitiesProvider.select((capabilities) => capabilities.isIOS),
    );

    void updateSettings(TerminalDisplaySettings next) {
      if (editingHostProfile) {
        workspaceController.saveTerminalDisplaySettingsForHost(
          widget.tabId,
          next,
          paneIndex: widget.paneIndex,
        );
      } else {
        globalController.setSettings(next);
      }
    }

    final sheet = widget.presentation == _TerminalSettingsPresentation.sheet;
    final mediaQuery = MediaQuery.of(context);
    final availableHeight =
        mediaQuery.size.height - mediaQuery.viewPadding.vertical;
    final viewportHeight = sheet
        ? math.min(
            _settingsSheetMaxHeight,
            math.max(
              _settingsSheetMinHeight,
              availableHeight * _settingsSheetHeightFactor,
            ),
          )
        : isIOS
        ? math.min(
            _settingsDialogMaxHeightIOS,
            math.max(
              _settingsDialogMinHeightIOS,
              availableHeight * _settingsDialogHeightFactorIOS,
            ),
          )
        : math.min(
            _settingsDialogMaxHeight,
            mediaQuery.size.height * _settingsDialogHeightFactor,
          );

    final scrollFrame = SizedBox(
      key: const ValueKey('terminal-settings-scroll-frame'),
      width: sheet ? double.infinity : _dialogWidthSmall,
      height: viewportHeight,
      child: ClipRect(
        child: Scrollbar(
          controller: _scrollController,
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(
              context,
            ).copyWith(scrollbars: false),
            child: SingleChildScrollView(
              controller: _scrollController,
              physics: const ClampingScrollPhysics(),
              child: _TerminalSettingsContent(
                settings: settings,
                fontCatalog: fontCatalog,
                catalogLoading: fontCatalogAsync.isLoading,
                editingHostProfile: editingHostProfile,
                onChanged: updateSettings,
              ),
            ),
          ),
        ),
      ),
    );

    final hostAction = widget.hostId != null && hostSettings == null
        ? SerlinkTextButton(
            onPressed: () =>
                workspaceController.saveTerminalDisplaySettingsForHost(
                  widget.tabId,
                  settings,
                  paneIndex: widget.paneIndex,
                ),
            child: Text(l10n.terminalSaveForHostAction),
          )
        : widget.hostId != null && hostSettings != null
        ? SerlinkTextButton(
            onPressed: () =>
                workspaceController.resetTerminalDisplaySettingsForHost(
                  widget.tabId,
                  paneIndex: widget.paneIndex,
                ),
            child: Text(l10n.terminalUseGlobalAction),
          )
        : null;

    if (sheet) {
      final t = context.tokens;
      return Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Container(
            key: const ValueKey('terminal-settings-sheet'),
            width: double.infinity,
            decoration: BoxDecoration(
              color: t.surfaceRaised,
              borderRadius: const BorderRadius.vertical(
                top: SerlinkRadii.dialogR,
              ),
              border: Border.all(color: t.borderSubtle),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  Center(
                    child: Container(
                      width: 36,
                      height: 5,
                      decoration: BoxDecoration(
                        color: t.textMuted.withValues(alpha: 0.45),
                        borderRadius: SerlinkRadii.pill,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.terminalSettingsTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: t.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                        ?hostAction,
                        if (hostAction != null) const SizedBox(width: 6),
                        SerlinkFilledButton(
                          size: SerlinkButtonSize.sm,
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(l10n.doneAction),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: t.borderSubtle),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 6, 14),
                    child: scrollFrame,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return SerlinkDialog(
      key: const ValueKey('terminal-settings-dialog'),
      maxWidth: _adaptiveDialogWidth(context, _dialogWidthMedium),
      title: Text(l10n.terminalSettingsTitle),
      content: scrollFrame,
      actions: [
        ?hostAction,
        SerlinkFilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.doneAction),
        ),
      ],
    );
  }
}

class _TerminalSettingsContent extends StatelessWidget {
  const _TerminalSettingsContent({
    required this.settings,
    required this.fontCatalog,
    required this.catalogLoading,
    required this.editingHostProfile,
    required this.onChanged,
  });

  final TerminalDisplaySettings settings;
  final TerminalFontCatalog fontCatalog;
  final bool catalogLoading;
  final bool editingHostProfile;
  final ValueChanged<TerminalDisplaySettings> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SurfaceSection(
            title: l10n.terminalAppearanceSection,
            showDividers: false,
            contentPadding: const EdgeInsets.all(16),
            children: [
              SerlinkLabeledField(
                label: l10n.terminalDarkThemeLabel,
                child: SerlinkSelect<SerlinkTerminalThemeId>(
                  key: ValueKey(
                    'terminal-theme-${settings.themeId.name}-$editingHostProfile',
                  ),
                  value: settings.themeId,
                  items: [
                    for (final themeId in SerlinkTerminalThemeId.values)
                      SerlinkSelectItem(
                        value: themeId,
                        label: themeId.label,
                        icon: Icons.palette_outlined,
                      ),
                  ],
                  onChanged: (themeId) {
                    onChanged(settings.copyWith(themeId: themeId));
                  },
                ),
              ),
              const SizedBox(height: 16),
              SerlinkLabeledField(
                label: l10n.terminalLightThemeLabel,
                child: SerlinkSelect<SerlinkTerminalThemeId>(
                  key: ValueKey(
                    'terminal-light-theme-${settings.lightThemeId.name}-$editingHostProfile',
                  ),
                  value: settings.lightThemeId,
                  items: [
                    for (final themeId in SerlinkTerminalThemeId.values)
                      SerlinkSelectItem(
                        value: themeId,
                        label: themeId.label,
                        icon: Icons.palette_outlined,
                      ),
                  ],
                  onChanged: (themeId) {
                    onChanged(settings.copyWith(lightThemeId: themeId));
                  },
                ),
              ),
              const SizedBox(height: 16),
              _TerminalFontPicker(
                settings: settings,
                catalog: fontCatalog,
                catalogLoading: catalogLoading,
                editingHostProfile: editingHostProfile,
                onFontFamilyChanged: (fontFamily) {
                  onChanged(settings.copyWith(fontFamily: fontFamily));
                },
              ),
            ],
          ),
          const SizedBox(height: 22),
          SurfaceSection(
            title: l10n.terminalLayoutSection,
            showDividers: false,
            contentPadding: const EdgeInsets.all(16),
            children: [
              _SettingsSlider(
                label: l10n.terminalFontSizeLabel,
                value: settings.fontSize,
                min: 10,
                max: 24,
                divisions: 14,
                displayValue: '${settings.fontSize.toStringAsFixed(0)} px',
                onChanged: (value) {
                  onChanged(settings.copyWith(fontSize: value));
                },
              ),
              const SizedBox(height: 10),
              _SettingsSlider(
                label: l10n.terminalLineHeightLabel,
                value: settings.lineHeight,
                min: 1,
                max: 1.5,
                divisions: 10,
                displayValue: settings.lineHeight.toStringAsFixed(2),
                onChanged: (value) {
                  onChanged(settings.copyWith(lineHeight: value));
                },
              ),
              const SizedBox(height: 10),
              _SettingsSlider(
                label: l10n.terminalScrollbackLabel,
                value: settings.scrollbackLines.toDouble(),
                min: 1000,
                max: 100000,
                divisions: 99,
                displayValue: _formatScrollbackLines(settings.scrollbackLines),
                onChanged: (value) {
                  onChanged(settings.copyWith(scrollbackLines: value.round()));
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TerminalFontPicker extends StatefulWidget {
  const _TerminalFontPicker({
    required this.settings,
    required this.catalog,
    required this.catalogLoading,
    required this.editingHostProfile,
    required this.onFontFamilyChanged,
  });

  final TerminalDisplaySettings settings;
  final TerminalFontCatalog catalog;
  final bool catalogLoading;
  final bool editingHostProfile;
  final ValueChanged<String> onFontFamilyChanged;

  @override
  State<_TerminalFontPicker> createState() => _TerminalFontPickerState();
}

class _TerminalFontPickerState extends State<_TerminalFontPicker> {
  late final TextEditingController _customFontController;

  @override
  void initState() {
    super.initState();
    _customFontController = TextEditingController(
      text: widget.settings.fontFamily,
    );
  }

  @override
  void didUpdateWidget(covariant _TerminalFontPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.settings.fontFamily != oldWidget.settings.fontFamily &&
        _customFontController.text != widget.settings.fontFamily) {
      _customFontController.text = widget.settings.fontFamily;
    }
  }

  @override
  void dispose() {
    _customFontController.dispose();
    super.dispose();
  }

  void _applyCustomFont() {
    final fontFamily = _customFontController.text.trim();
    if (fontFamily.isNotEmpty) {
      widget.onFontFamilyChanged(fontFamily);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fonts = widget.catalog.withCurrentFamily(widget.settings.fontFamily);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SerlinkLabeledField(
          label: l10n.terminalFontLabel,
          trailing: _TerminalFontStatus(
            catalog: widget.catalog,
            loading: widget.catalogLoading,
          ),
          child: SerlinkSelect<String>(
            key: ValueKey(
              'terminal-font-family-${widget.settings.fontFamily}-${widget.editingHostProfile}',
            ),
            value: widget.settings.fontFamily,
            searchable: true,
            searchHint: l10n.terminalSearchFontsHint,
            hintText: l10n.terminalSelectFontHint,
            items: [
              for (final font in fonts)
                SerlinkSelectItem(
                  value: font.family,
                  label: font.label,
                  icon: _terminalFontIcon(font),
                ),
            ],
            onChanged: (fontFamily) {
              _customFontController.text = fontFamily;
              widget.onFontFamilyChanged(fontFamily);
            },
          ),
        ),
        const SizedBox(height: 16),
        SerlinkLabeledField(
          label: l10n.terminalCustomFamilyLabel,
          helper: l10n.terminalCustomFamilyHelper,
          child: SerlinkTextFormField(
            controller: _customFontController,
            decoration: InputDecoration(
              isDense: true,
              hintText: l10n.terminalCustomFamilyHint,
              prefixIcon: const Icon(Icons.edit_outlined, size: 18),
              suffixIcon: SerlinkIconButton(
                tooltip: l10n.terminalApplyCustomFontTooltip,
                onPressed: _applyCustomFont,
                icon: const Icon(Icons.check_rounded, size: 18),
              ),
            ),
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _applyCustomFont(),
          ),
        ),
        const SizedBox(height: 16),
        _TerminalFontPreview(settings: widget.settings),
      ],
    );
  }
}

IconData _terminalFontIcon(TerminalFontCandidate font) {
  if (font.hasEnhancedGlyphs) {
    return Icons.auto_awesome_outlined;
  }
  if (font.isBuiltIn) {
    return Icons.computer_outlined;
  }
  return Icons.font_download_outlined;
}

class _TerminalFontStatus extends StatelessWidget {
  const _TerminalFontStatus({required this.catalog, required this.loading});

  final TerminalFontCatalog catalog;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = context.l10n;
    final hasNerdFont = catalog.hasNerdFont;
    final color = hasNerdFont ? t.statusSuccess : t.textMuted;
    final text = loading
        ? l10n.terminalScanningFonts
        : hasNerdFont
        ? l10n.terminalNerdFontReady
        : l10n.terminalNoNerdFont;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          hasNerdFont ? Icons.check_circle : Icons.circle_outlined,
          size: 13,
          color: color,
        ),
        const SizedBox(width: 5),
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _TerminalFontPreview extends StatelessWidget {
  const _TerminalFontPreview({required this.settings});

  static const _sample = 'serlink    ~/vault    main  ❯  echo ready';

  final TerminalDisplaySettings settings;

  @override
  Widget build(BuildContext context) {
    final theme = settings.terminalThemeFor(Theme.of(context).brightness);
    final t = context.tokens;
    return ClipRRect(
      borderRadius: SerlinkRadii.control,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.background,
          border: Border.all(color: t.borderSubtle),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Text(
              _sample,
              maxLines: 1,
              style: settings.textStyle.toTextStyle(color: theme.foreground),
            ),
          ),
        ),
      ),
    );
  }
}

TerminalDisplaySettings? _terminalDisplaySettingsForTab(
  WorkspaceState state,
  WorkspaceTabId tabId,
  int paneIndex,
) {
  final tab = state.tabs
      .where((candidate) => candidate.id == tabId)
      .firstOrNull;
  final content = tab?.content;
  final panes = switch (content) {
    TerminalTabContent(:final panes) => panes,
    LocalTerminalTabContent(:final panes) => panes,
    _ => null,
  };
  if (panes == null || panes.isEmpty) {
    return null;
  }
  return panes[paneIndex.clamp(0, panes.length - 1)].displaySettings;
}

class _SettingsSlider extends StatelessWidget {
  const _SettingsSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.displayValue,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String displayValue;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: t.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            StatusPill(label: displayValue, color: t.accentPrimary),
          ],
        ),
        const SizedBox(height: 10),
        SerlinkSlider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

String _formatScrollbackLines(int lines) {
  if (lines >= 1000) {
    return '${(lines / 1000).toStringAsFixed(0)}k lines';
  }
  return '$lines lines';
}
