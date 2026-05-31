part of '../workspace_screen.dart';

class _SnippetsSurface extends ConsumerWidget {
  const _SnippetsSurface();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vaultSession = ref.watch(vaultSessionControllerProvider).value;
    if (vaultSession?.vaultState != VaultState.unlocked) {
      return const _PlaceholderSurface(
        title: 'Snippets',
        body: 'Unlock the vault to manage command snippets.',
      );
    }

    final snippets = ref.watch(snippetsProvider);
    final searchQuery = ref.watch(_workspaceSearchQueryProvider);
    return snippets.when(
      loading: () => const _PlaceholderSurface(
        title: 'Snippets',
        body: 'Loading encrypted snippets.',
      ),
      error: (error, stackTrace) =>
          _PlaceholderSurface(title: 'Snippets', body: error.toString()),
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
                  ? const _PlaceholderSurface(
                      title: 'No Matches',
                      body: 'No snippets match the current workspace search.',
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
    final t = context.tokens;
    return SurfaceToolbar(
      child: Row(
        children: [
          Text(
            'Snippets',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: t.textPrimary,
            ),
          ),
          const SizedBox(width: 8),
          _CountBadge(count: count),
          const Spacer(),
          SerlinkTooltip(
            message: 'Add snippet',
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
        label: const Text('Add Snippet'),
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
            message: 'Insert into active terminal',
            child: SerlinkIconButton(
              key: ValueKey('snippet-insert-${snippet.id.value}'),
              onPressed: onInsert,
              icon: const Icon(Icons.input_outlined),
            ),
          ),
          SerlinkTooltip(
            message: 'Run in active terminal',
            child: SerlinkIconButton(
              key: ValueKey('snippet-run-${snippet.id.value}'),
              onPressed: onRun,
              icon: const Icon(Icons.play_arrow_outlined),
            ),
          ),
          SerlinkTooltip(
            message: 'Edit snippet',
            child: SerlinkIconButton(
              key: ValueKey('snippet-edit-${snippet.id.value}'),
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
          ),
          SerlinkTooltip(
            message: 'Delete snippet',
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
    _tagsController = TextEditingController(
      text: snippet?.tags.join(', ') ?? '',
    );
    _confirmBeforeRun = snippet?.confirmBeforeRun ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _commandController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SerlinkDialog(
      title: Text(_isEditing ? 'Edit Snippet' : 'Add Snippet'),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SerlinkTextField(
              key: const ValueKey('snippet-name-field'),
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name'),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            SerlinkTextField(
              key: const ValueKey('snippet-command-field'),
              controller: _commandController,
              minLines: 3,
              maxLines: 8,
              decoration: const InputDecoration(labelText: 'Command'),
            ),
            const SizedBox(height: 12),
            SerlinkTextField(
              key: const ValueKey('snippet-tags-field'),
              controller: _tagsController,
              decoration: const InputDecoration(labelText: 'Tags'),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
            ),
            SerlinkCheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _confirmBeforeRun,
              title: const Text('Confirm before run'),
              onChanged: (value) {
                setState(() {
                  _confirmBeforeRun = value ?? true;
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
          child: const Text('Cancel'),
        ),
        SerlinkFilledButton(
          key: const ValueKey('snippet-save-button'),
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving' : 'Save'),
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
        tags: _parseTags(_tagsController.text),
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
          _errorMessage = 'Snippet could not be saved.';
        });
      }
    }
  }
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
      title: 'Run snippet?',
      body: _singleLineCommand(snippet.command),
      confirmLabel: 'Run',
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
                ? 'Snippet sent to terminal.'
                : 'Snippet inserted into terminal.'
          : 'Open a connected terminal tab first.',
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
    title: 'Delete snippet?',
    body: snippet.name,
    confirmLabel: 'Delete',
    destructive: true,
  );
  if (!confirmed) {
    return;
  }
  try {
    await ref.read(snippetWriteServiceProvider).delete(snippet.id);
    ref.invalidate(snippetsProvider);
    if (context.mounted) {
      _showSnackBar(context, 'Snippet deleted.');
    }
  } on Object {
    if (context.mounted) {
      _showSnackBar(context, 'Snippet could not be deleted.');
    }
  }
}

String _singleLineCommand(String command) {
  return command.trim().split(RegExp(r'\s+')).join(' ');
}
