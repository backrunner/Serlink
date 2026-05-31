part of '../workspace_screen.dart';

class _SnippetsSurface extends ConsumerWidget {
  const _SnippetsSurface();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final vaultSession = ref.watch(vaultSessionControllerProvider).value;
    if (vaultSession?.vaultState != VaultState.unlocked) {
      return _PlaceholderSurface(
        title: l10n.snippetsTitle,
        body: l10n.snippetsLockedBody,
      );
    }

    final snippets = ref.watch(snippetsProvider);
    final searchQuery = ref.watch(_workspaceSearchQueryProvider);
    return snippets.when(
      loading: () => _PlaceholderSurface(
        title: l10n.snippetsTitle,
        body: l10n.snippetsLoading,
      ),
      error: (error, stackTrace) => _PlaceholderSurface(
        title: l10n.snippetsTitle,
        body: error.toString(),
      ),
      data: (items) {
        final filteredItems = filterCommandSnippets(items, searchQuery);
        return Column(
          children: [
            _SnippetsHeader(
              count: filteredItems.length,
              onAdd: () => _showSnippetDialog(context),
            ),
            Expanded(
              child: items.isEmpty
                  ? _SnippetsEmptyState(
                      onAdd: () => _showSnippetDialog(context),
                    )
                  : filteredItems.isEmpty
                  ? _PlaceholderSurface(
                      title: l10n.hostsNoMatchesTitle,
                      body: l10n.snippetsNoMatchesBody,
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: filteredItems.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final snippet = filteredItems[index];
                        return _SnippetRow(
                          snippet: snippet,
                          onInsert: () => _insertSnippet(
                            context,
                            ref,
                            snippet,
                            submit: false,
                          ),
                          onRun: () => _insertSnippet(
                            context,
                            ref,
                            snippet,
                            submit: true,
                          ),
                          onEdit: () =>
                              _showSnippetDialog(context, snippet: snippet),
                          onDelete: () => _deleteSnippet(context, ref, snippet),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _SnippetsHeader extends StatelessWidget {
  const _SnippetsHeader({required this.count, required this.onAdd});

  final int count;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    return SurfaceToolbar(
      child: Row(
        children: [
          Text(
            l10n.snippetsTitle,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: t.textPrimary,
            ),
          ),
          const SizedBox(width: 8),
          _CountBadge(count: count),
          const Spacer(),
          SerlinkTooltip(
            message: l10n.snippetsAddTooltip,
            child: SerlinkIconButton(
              key: const ValueKey('add-snippet-button'),
              onPressed: onAdd,
              icon: const Icon(Icons.add),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small pill that shows a count next to a section title.
class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.surfaceSunken,
        borderRadius: SerlinkRadii.pill,
        border: Border.all(color: t.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Text(
          count.toString(),
          style: TextStyle(
            color: t.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

class _SnippetsEmptyState extends StatelessWidget {
  const _SnippetsEmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SerlinkFilledButton.icon(
        key: const ValueKey('empty-add-snippet-button'),
        onPressed: onAdd,
        icon: const Icon(Icons.add, size: 18),
        label: Text(context.l10n.snippetsAddAction),
      ),
    );
  }
}

class _SnippetRow extends StatelessWidget {
  const _SnippetRow({
    required this.snippet,
    required this.onInsert,
    required this.onRun,
    required this.onEdit,
    required this.onDelete,
  });

  final CommandSnippet snippet;
  final VoidCallback onInsert;
  final VoidCallback onRun;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ListRow(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  snippet.name,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: t.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _singleLineCommand(snippet.command),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    color: t.textSecondary,
                  ),
                ),
                if (snippet.tags.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final tag in snippet.tags) SerlinkTag(label: tag),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          SerlinkTooltip(
            message: context.l10n.snippetInsertTooltip,
            child: SerlinkIconButton(
              key: ValueKey('snippet-insert-${snippet.id.value}'),
              onPressed: onInsert,
              icon: const Icon(Icons.input_outlined),
            ),
          ),
          SerlinkTooltip(
            message: context.l10n.snippetRunTooltip,
            child: SerlinkIconButton(
              key: ValueKey('snippet-run-${snippet.id.value}'),
              onPressed: onRun,
              icon: const Icon(Icons.play_arrow_outlined),
            ),
          ),
          SerlinkTooltip(
            message: context.l10n.snippetEditTooltip,
            child: SerlinkIconButton(
              key: ValueKey('snippet-edit-${snippet.id.value}'),
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
          ),
          SerlinkTooltip(
            message: context.l10n.snippetDeleteTooltip,
            child: SerlinkIconButton(
              key: ValueKey('snippet-delete-${snippet.id.value}'),
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _showSnippetDialog(
  BuildContext context, {
  CommandSnippet? snippet,
}) {
  return showSerlinkDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _SnippetDialog(snippet: snippet),
  );
}

class _SnippetDialog extends ConsumerStatefulWidget {
  const _SnippetDialog({this.snippet});

  final CommandSnippet? snippet;

  @override
  ConsumerState<_SnippetDialog> createState() => _SnippetDialogState();
}

class _SnippetDialogState extends ConsumerState<_SnippetDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _commandController;
  late final TextEditingController _tagsController;
  late final FocusNode _commandFocusNode;
  late final FocusNode _tagsFocusNode;
  late final List<String> _tags;
  late bool _confirmBeforeRun;
  var _saving = false;
  String? _errorMessage;

  bool get _isEditing => widget.snippet != null;

  @override
  void initState() {
    super.initState();
    final snippet = widget.snippet;
    _nameController = TextEditingController(text: snippet?.name ?? '');
    _commandController = TextEditingController(text: snippet?.command ?? '');
    _tagsController = TextEditingController();
    _commandFocusNode = FocusNode();
    _tagsFocusNode = FocusNode();
    _tags = (snippet?.tags.toList() ?? [])..sort();
    _confirmBeforeRun = snippet?.confirmBeforeRun ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _commandController.dispose();
    _tagsController.dispose();
    _commandFocusNode.dispose();
    _tagsFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SerlinkDialog(
      title: _SnippetDialogTitle(
        title: _isEditing
            ? l10n.snippetDialogEditTitle
            : l10n.snippetDialogAddTitle,
      ),
      content: SizedBox(
        width: 600,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SerlinkTextField(
              key: const ValueKey('snippet-name-field'),
              controller: _nameController,
              decoration: InputDecoration(labelText: l10n.snippetNameLabel),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 14),
            _SnippetCommandField(
              label: l10n.snippetCommandLabel,
              controller: _commandController,
              focusNode: _commandFocusNode,
            ),
            const SizedBox(height: 14),
            _SnippetTagsField(
              controller: _tagsController,
              focusNode: _tagsFocusNode,
              tags: _tags,
              onChanged: _handleTagInputChanged,
              onRemoveTag: _removeTag,
              onSubmitted: _handleTagInputSubmitted,
            ),
            const SizedBox(height: 18),
            _SnippetConfirmOption(
              value: _confirmBeforeRun,
              label: l10n.snippetConfirmBeforeRun,
              onChanged: (value) {
                setState(() {
                  _confirmBeforeRun = value;
                });
              },
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              SerlinkAlert.danger(message: _errorMessage!, compact: true),
            ],
          ],
        ),
      ),
      actions: [
        SerlinkTextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.cancelAction),
        ),
        SerlinkFilledButton(
          key: const ValueKey('snippet-save-button'),
          onPressed: _saving ? null : _save,
          child: Text(_saving ? l10n.savingAction : l10n.saveAction),
        ),
      ],
    );
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _errorMessage = null;
    });
    try {
      final draft = SnippetDraft(
        name: _nameController.text,
        command: _commandController.text,
        tags: _currentTags(),
        confirmBeforeRun: _confirmBeforeRun,
      );
      final service = ref.read(snippetWriteServiceProvider);
      final snippet = widget.snippet;
      if (snippet == null) {
        await service.create(draft);
      } else {
        await service.update(snippet.id, draft);
      }
      ref.invalidate(snippetsProvider);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } on SnippetWriteException catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _errorMessage = error.message;
        });
      }
    } on Object {
      if (mounted) {
        setState(() {
          _saving = false;
          _errorMessage = context.l10n.snippetSaveFailed;
        });
      }
    }
  }

  void _handleTagInputChanged(String value) {
    if (!_snippetTagDelimiterPattern.hasMatch(value)) {
      return;
    }

    final segments = value.split(_snippetTagDelimiterPattern);
    _addTags(segments.take(segments.length - 1));

    final remaining = segments.last.trimLeft();
    _tagsController.value = TextEditingValue(
      text: remaining,
      selection: TextSelection.collapsed(offset: remaining.length),
    );
  }

  void _handleTagInputSubmitted(String value) {
    if (_commitPendingTags()) {
      return;
    }
    _save();
  }

  bool _commitPendingTags() {
    final pendingTags = _parseSnippetTags(_tagsController.text);
    if (pendingTags.isEmpty) {
      return false;
    }
    _addTags(pendingTags);
    _tagsController.clear();
    return true;
  }

  void _addTags(Iterable<String> values) {
    final nextTags = [
      for (final tag in values.map((value) => value.trim()))
        if (tag.isNotEmpty && !_tags.contains(tag)) tag,
    ];
    if (nextTags.isEmpty) {
      return;
    }
    setState(() {
      _tags.addAll(nextTags);
    });
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
  }

  Set<String> _currentTags() {
    return {..._tags, ..._parseSnippetTags(_tagsController.text)};
  }
}

class _SnippetDialogTitle extends StatelessWidget {
  const _SnippetDialogTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: t.accentPrimary.withValues(alpha: 0.13),
            borderRadius: SerlinkRadii.control,
            border: Border.all(color: t.accentPrimary.withValues(alpha: 0.26)),
          ),
          child: Icon(Icons.terminal_rounded, size: 20, color: t.accentPrimary),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(title)),
      ],
    );
  }
}

class _SnippetCommandField extends StatelessWidget {
  const _SnippetCommandField({
    required this.label,
    required this.controller,
    required this.focusNode,
  });

  final String label;
  final TextEditingController controller;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    return SerlinkLabeledField(
      label: label,
      child: ListenableBuilder(
        listenable: focusNode,
        builder: (context, _) {
          final t = context.tokens;
          final focused = focusNode.hasFocus;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: focusNode.requestFocus,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
              padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
              decoration: BoxDecoration(
                color: t.surfaceSunken,
                borderRadius: SerlinkRadii.control,
                border: Border.all(
                  color: focused
                      ? t.accentPrimary.withValues(alpha: 0.72)
                      : t.borderSubtle,
                ),
                boxShadow: focused
                    ? [
                        BoxShadow(
                          color: t.accentPrimary.withValues(alpha: 0.08),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: t.accentPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SerlinkTextField(
                      key: const ValueKey('snippet-command-field'),
                      controller: controller,
                      focusNode: focusNode,
                      minLines: 4,
                      maxLines: 8,
                      decoration: const InputDecoration.collapsed(hintText: ''),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: t.textPrimary,
                        fontFamily: 'SF Mono',
                        fontFamilyFallback: const [
                          'Menlo',
                          'Cascadia Mono',
                          'Consolas',
                          'monospace',
                        ],
                        fontWeight: FontWeight.w500,
                        height: 1.38,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SnippetConfirmOption extends StatelessWidget {
  const _SnippetConfirmOption({
    required this.value,
    required this.label,
    required this.onChanged,
  });

  final bool value;
  final String label;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SerlinkPressable(
      onTap: () => onChanged(!value),
      borderRadius: SerlinkRadii.control,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            value ? t.accentPrimary.withValues(alpha: 0.08) : t.surfaceOverlay,
            t.surfaceSunken,
          ),
          borderRadius: SerlinkRadii.control,
          border: Border.all(
            color: value
                ? t.accentPrimary.withValues(alpha: 0.34)
                : t.borderSubtle,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: value
                    ? t.accentPrimary.withValues(alpha: 0.14)
                    : t.surfaceOverlay,
                borderRadius: SerlinkRadii.control,
              ),
              child: Icon(
                Icons.verified_user_outlined,
                size: 17,
                color: value ? t.accentPrimary : t.textMuted,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: t.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 12),
            SerlinkSwitch(
              value: value,
              onChanged: onChanged,
              semanticsLabel: label,
            ),
          ],
        ),
      ),
    );
  }
}

class _SnippetTagsField extends StatelessWidget {
  const _SnippetTagsField({
    required this.controller,
    required this.focusNode,
    required this.tags,
    required this.onChanged,
    required this.onSubmitted,
    required this.onRemoveTag,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final List<String> tags;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final ValueChanged<String> onRemoveTag;

  @override
  Widget build(BuildContext context) {
    return SerlinkLabeledField(
      label: context.l10n.snippetTagsLabel,
      child: ListenableBuilder(
        listenable: focusNode,
        builder: (context, _) {
          final t = context.tokens;
          final focused = focusNode.hasFocus;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: focusNode.requestFocus,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
              constraints: const BoxConstraints(minHeight: 50),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(
                color: t.surfaceSunken,
                borderRadius: SerlinkRadii.control,
                border: Border.all(
                  color: focused
                      ? t.accentPrimary.withValues(alpha: 0.72)
                      : t.borderSubtle,
                ),
                boxShadow: focused
                    ? [
                        BoxShadow(
                          color: t.accentPrimary.withValues(alpha: 0.08),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final inputWidth = tags.isEmpty
                      ? constraints.maxWidth
                      : math.min(
                          constraints.maxWidth,
                          math.max(150.0, constraints.maxWidth * 0.36),
                        );
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      for (final tag in tags)
                        _SnippetTagChip(
                          tag: tag,
                          onRemove: () => onRemoveTag(tag),
                        ),
                      SizedBox(
                        width: inputWidth,
                        child: SerlinkTextField(
                          key: const ValueKey('snippet-tags-field'),
                          controller: controller,
                          focusNode: focusNode,
                          decoration: InputDecoration.collapsed(
                            hintText: tags.isEmpty
                                ? context.l10n.snippetAddTagsHint
                                : context.l10n.snippetAddTagHint,
                          ),
                          textInputAction: TextInputAction.done,
                          onChanged: onChanged,
                          onSubmitted: onSubmitted,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SnippetTagChip extends StatelessWidget {
  const _SnippetTagChip({required this.tag, required this.onRemove});

  final String tag;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220),
      child: Container(
        height: 28,
        padding: const EdgeInsetsDirectional.only(start: 10, end: 4),
        decoration: BoxDecoration(
          color: t.accentPrimary.withValues(alpha: 0.11),
          borderRadius: SerlinkRadii.pill,
          border: Border.all(color: t.accentPrimary.withValues(alpha: 0.28)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                tag,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: t.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 4),
            SerlinkTooltip(
              message: context.l10n.snippetRemoveTagTooltip,
              child: SerlinkPressable(
                onTap: onRemove,
                borderRadius: SerlinkRadii.pill,
                padding: const EdgeInsets.all(3),
                child: Icon(Icons.close, size: 13, color: t.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final RegExp _snippetTagDelimiterPattern = RegExp(r'[,;，；、\r\n]+');

Set<String> _parseSnippetTags(String value) {
  return {
    for (final tag
        in value.split(_snippetTagDelimiterPattern).map((tag) => tag.trim()))
      if (tag.isNotEmpty) tag,
  };
}

Future<void> _insertSnippet(
  BuildContext context,
  WidgetRef ref,
  CommandSnippet snippet, {
  required bool submit,
}) async {
  if (submit && snippet.confirmBeforeRun) {
    final confirmed = await _confirmDialog(
      context,
      title: context.l10n.snippetRunTitle,
      body: _singleLineCommand(snippet.command),
      confirmLabel: context.l10n.runAction,
      destructive: true,
    );
    if (!confirmed) {
      return;
    }
  }
  final inserted = ref
      .read(workspaceTabControllerProvider.notifier)
      .insertIntoActiveTerminal(snippet.command, submit: submit);
  if (context.mounted) {
    _showSnackBar(
      context,
      inserted
          ? submit
                ? context.l10n.snippetSentSnack
                : context.l10n.snippetInsertedSnack
          : context.l10n.snippetNoTerminalSnack,
    );
  }
}

Future<void> _deleteSnippet(
  BuildContext context,
  WidgetRef ref,
  CommandSnippet snippet,
) async {
  final confirmed = await _confirmDialog(
    context,
    title: context.l10n.snippetDeleteTitle,
    body: snippet.name,
    confirmLabel: context.l10n.deleteAction,
    destructive: true,
  );
  if (!confirmed) {
    return;
  }
  try {
    await ref.read(snippetWriteServiceProvider).delete(snippet.id);
    ref.invalidate(snippetsProvider);
    if (context.mounted) {
      _showSnackBar(context, context.l10n.snippetDeletedSnack);
    }
  } on Object {
    if (context.mounted) {
      _showSnackBar(context, context.l10n.snippetDeleteFailedSnack);
    }
  }
}

String _singleLineCommand(String command) {
  return command.trim().split(RegExp(r'\s+')).join(' ');
}
