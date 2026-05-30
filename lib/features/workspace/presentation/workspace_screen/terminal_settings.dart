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
    final countLabel = '${result.displayIndex}/${result.matchCount}';
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: SizedBox(
        height: 44,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            children: [
              SizedBox(
                width: 300,
                child: TextField(
                  key: const ValueKey('terminal-search-field'),
                  controller: controller,
                  autofocus: true,
                  decoration: const InputDecoration(
                    isDense: true,
                    prefixIcon: Icon(Icons.search, size: 16),
                    hintText: 'Search terminal',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: onChanged,
                  onSubmitted: (_) => onNext(),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(width: 48, child: Text(countLabel)),
              IconButton(
                tooltip: 'Previous match',
                onPressed: result.matchCount == 0 ? null : onPrevious,
                icon: const Icon(Icons.keyboard_arrow_up, size: 18),
              ),
              IconButton(
                tooltip: 'Next match',
                onPressed: result.matchCount == 0 ? null : onNext,
                icon: const Icon(Icons.keyboard_arrow_down, size: 18),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Close search',
                onPressed: onClose,
                icon: const Icon(Icons.close, size: 18),
              ),
            ],
          ),
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
                    DropdownMenu<SerlinkTerminalThemeId>(
                      key: ValueKey(
                        'terminal-theme-${settings.themeId.name}-$editingHostProfile',
                      ),
                      initialSelection: settings.themeId,
                      label: const Text('Theme'),
                      expandedInsets: EdgeInsets.zero,
                      inputDecorationTheme: const InputDecorationThemeData(
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      dropdownMenuEntries: [
                        for (final themeId in SerlinkTerminalThemeId.values)
                          DropdownMenuEntry(
                            value: themeId,
                            label: themeId.label,
                          ),
                      ],
                      onSelected: (themeId) {
                        if (themeId != null) {
                          updateSettings(settings.copyWith(themeId: themeId));
                        }
                      },
                    ),
                    const SizedBox(height: 14),
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
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: textTheme.titleSmall),
        const SizedBox(height: 10),
        ...children,
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
        DropdownMenu<String>(
          key: ValueKey(
            'terminal-font-family-${widget.settings.fontFamily}-${widget.editingHostProfile}',
          ),
          initialSelection: widget.settings.fontFamily,
          label: const Text('Font'),
          enableFilter: true,
          requestFocusOnTap: true,
          expandedInsets: EdgeInsets.zero,
          menuHeight: 280,
          inputDecorationTheme: const InputDecorationThemeData(
            border: OutlineInputBorder(),
            isDense: true,
          ),
          dropdownMenuEntries: [
            for (final font in fonts)
              DropdownMenuEntry(
                value: font.family,
                label: font.label,
                leadingIcon: Icon(_terminalFontIcon(font), size: 16),
                labelWidget: Text(
                  font.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onSelected: (fontFamily) {
            if (fontFamily == null) {
              return;
            }
            _customFontController.text = fontFamily;
            widget.onFontFamilyChanged(fontFamily);
          },
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _customFontController,
          decoration: InputDecoration(
            labelText: 'Custom family',
            border: const OutlineInputBorder(),
            isDense: true,
            prefixIcon: const Icon(Icons.edit_outlined, size: 18),
            suffixIcon: IconButton(
              tooltip: 'Apply custom font',
              onPressed: _applyCustomFont,
              icon: const Icon(Icons.check_outlined, size: 18),
            ),
          ),
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _applyCustomFont(),
        ),
        const SizedBox(height: 10),
        _TerminalFontStatus(
          catalog: widget.catalog,
          loading: widget.catalogLoading,
        ),
        const SizedBox(height: 10),
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
    final scheme = Theme.of(context).colorScheme;
    final hasNerdFont = catalog.hasNerdFont;
    final color = hasNerdFont ? scheme.primary : scheme.onSurfaceVariant;
    final text = loading
        ? 'Scanning installed fonts'
        : hasNerdFont
        ? 'Nerd Font detected'
        : 'Nerd Font not found';

    return Align(
      alignment: Alignment.centerLeft,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.20)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                hasNerdFont ? Icons.check_circle_outline : Icons.info_outline,
                size: 15,
                color: color,
              ),
              const SizedBox(width: 6),
              Text(
                text,
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: color),
              ),
            ],
          ),
        ),
      ),
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
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.background,
          border: Border.all(color: scheme.outlineVariant),
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
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(label)),
            DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                child: Text(
                  displayValue,
                  style: Theme.of(context).textTheme.labelMedium,
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
