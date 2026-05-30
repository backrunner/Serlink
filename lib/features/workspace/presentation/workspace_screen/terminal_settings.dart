part of '../workspace_screen.dart';

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
    final t = context.tokens;
    final hasMatches = result.matchCount > 0;
    final countLabel = hasMatches
        ? '${result.displayIndex}/${result.matchCount}'
        : 'No results';
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
                      child: TextField(
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
                          hintText: 'Search terminal',
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
                    Container(
                      width: 1,
                      height: 18,
                      color: t.borderSubtle,
                    ),
                    IconButton(
                      tooltip: 'Previous match',
                      visualDensity: VisualDensity.compact,
                      onPressed: hasMatches ? onPrevious : null,
                      icon: const Icon(Icons.keyboard_arrow_up, size: 18),
                    ),
                    IconButton(
                      tooltip: 'Next match',
                      visualDensity: VisualDensity.compact,
                      onPressed: hasMatches ? onNext : null,
                      icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Close search',
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
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _TerminalSettingsDialog(tabId: tabId, hostId: hostId),
  );
}

class _TerminalSettingsDialog extends ConsumerWidget {
  const _TerminalSettingsDialog({required this.tabId, required this.hostId});

  final WorkspaceTabId tabId;
  final HostId? hostId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspaceState = ref.watch(workspaceTabControllerProvider);
    final hostSettings = _terminalDisplaySettingsForTab(workspaceState, tabId);
    final globalSettings =
        ref.watch(terminalDisplaySettingsProvider).value ??
        const TerminalDisplaySettings();
    final settings = hostSettings ?? globalSettings;
    final fontCatalogAsync = ref.watch(terminalFontCatalogProvider);
    final fontCatalog =
        fontCatalogAsync.value ?? TerminalFontCatalog.fallback();
    final editingHostProfile = hostId != null && hostSettings != null;
    final globalController = ref.read(terminalDisplaySettingsProvider.notifier);
    final workspaceController = ref.read(
      workspaceTabControllerProvider.notifier,
    );

    void updateSettings(TerminalDisplaySettings next) {
      if (editingHostProfile) {
        workspaceController.saveTerminalDisplaySettingsForHost(tabId, next);
      } else {
        globalController.setSettings(next);
      }
    }

    return AlertDialog(
      title: const Text('Terminal Settings'),
      content: SizedBox(
        width: 560,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.72,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _TerminalSettingsGroup(
                  title: 'Appearance',
                  children: [
                    SerlinkLabeledField(
                      label: 'Theme',
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
                          updateSettings(settings.copyWith(themeId: themeId));
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    _TerminalFontPicker(
                      settings: settings,
                      catalog: fontCatalog,
                      catalogLoading: fontCatalogAsync.isLoading,
                      editingHostProfile: editingHostProfile,
                      onFontFamilyChanged: (fontFamily) {
                        updateSettings(
                          settings.copyWith(fontFamily: fontFamily),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                _TerminalSettingsGroup(
                  title: 'Layout',
                  children: [
                    _SettingsSlider(
                      label: 'Font size',
                      value: settings.fontSize,
                      min: 10,
                      max: 24,
                      divisions: 14,
                      displayValue:
                          '${settings.fontSize.toStringAsFixed(0)} px',
                      onChanged: (value) =>
                          updateSettings(settings.copyWith(fontSize: value)),
                    ),
                    const SizedBox(height: 10),
                    _SettingsSlider(
                      label: 'Line height',
                      value: settings.lineHeight,
                      min: 1,
                      max: 1.5,
                      divisions: 10,
                      displayValue: settings.lineHeight.toStringAsFixed(2),
                      onChanged: (value) =>
                          updateSettings(settings.copyWith(lineHeight: value)),
                    ),
                    const SizedBox(height: 10),
                    _SettingsSlider(
                      label: 'Scrollback',
                      value: settings.scrollbackLines.toDouble(),
                      min: 1000,
                      max: 100000,
                      divisions: 99,
                      displayValue: _formatScrollbackLines(
                        settings.scrollbackLines,
                      ),
                      onChanged: (value) => updateSettings(
                        settings.copyWith(scrollbackLines: value.round()),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        if (hostId != null && hostSettings == null)
          TextButton(
            onPressed: () => workspaceController
                .saveTerminalDisplaySettingsForHost(tabId, settings),
            child: const Text('Save for host'),
          ),
        if (hostId != null && hostSettings != null)
          TextButton(
            onPressed: () =>
                workspaceController.resetTerminalDisplaySettingsForHost(tabId),
            child: const Text('Use global'),
          ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

class _TerminalSettingsGroup extends StatelessWidget {
  const _TerminalSettingsGroup({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 10),
          child: Text(
            title,
            style: TextStyle(
              color: t.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ),
        SurfacePanel(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ],
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
    final fonts = widget.catalog.withCurrentFamily(widget.settings.fontFamily);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SerlinkLabeledField(
          label: 'Font',
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
            searchHint: 'Search fonts',
            hintText: 'Select a font',
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
          label: 'Custom family',
          helper: 'Type an installed font family, then apply.',
          child: TextFormField(
            controller: _customFontController,
            decoration: InputDecoration(
              isDense: true,
              hintText: 'e.g. JetBrains Mono',
              prefixIcon: const Icon(Icons.edit_outlined, size: 18),
              suffixIcon: IconButton(
                tooltip: 'Apply custom font',
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
    final hasNerdFont = catalog.hasNerdFont;
    final color = hasNerdFont ? t.statusSuccess : t.textMuted;
    final text = loading
        ? 'Scanning fonts'
        : hasNerdFont
        ? 'Nerd Font ready'
        : 'No Nerd Font';

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
    final theme = settings.terminalTheme;
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
) {
  final tab = state.tabs
      .where((candidate) => candidate.id == tabId)
      .firstOrNull;
  final content = tab?.content;
  return content is TerminalTabContent
      ? content.activePaneState?.displaySettings ??
            content.primaryPane.displaySettings
      : null;
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
            DecoratedBox(
              decoration: BoxDecoration(
                color: t.accentPrimary.withValues(alpha: 0.14),
                borderRadius: SerlinkRadii.pill,
                border: Border.all(
                  color: t.accentPrimary.withValues(alpha: 0.3),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                child: Text(
                  displayValue,
                  style: TextStyle(
                    color: t.accentPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          label: displayValue,
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
