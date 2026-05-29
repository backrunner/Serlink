import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:xterm/xterm.dart';

import '../../../app/app_dependencies.dart';
import '../../../core/ids/entity_id.dart';
import '../../../core/security/local_file_security.dart';
import '../../../platform/app_window.dart';
import '../../hosts/application/host_store.dart';
import '../../hosts/application/host_write_service.dart';
import '../../hosts/domain/host.dart';
import '../../identities/domain/identity.dart';
import '../../import_export/application/open_ssh_certificate_import_service.dart';
import '../../import_export/application/open_ssh_config_import_service.dart';
import '../../import_export/application/vault_backup_service.dart';
import '../../security/application/security_modal_service.dart';
import '../../sftp/application/sftp_connection.dart';
import '../../sftp/application/sftp_failure.dart';
import '../../sftp/domain/sftp_entry.dart';
import '../../snippets/application/snippet_write_service.dart';
import '../../snippets/domain/snippet.dart';
import '../../sync/application/auto_sync_controller.dart';
import '../../sync/application/sync_delete_tombstone_repository.dart';
import '../../sync/application/sync_device_service.dart';
import '../../sync/application/sync_field_merge_service.dart';
import '../../sync/application/sync_repair_service.dart';
import '../../sync/application/sync_run_service.dart';
import '../../sync/application/sync_settings_service.dart';
import '../../sync/domain/sync_provider.dart';
import '../../sync/domain/webdav_tls_certificate_details.dart';
import '../../ssh/application/known_host_repository.dart';
import '../../terminal/application/terminal_buffer_search_controller.dart';
import '../../terminal/application/terminal_display_settings.dart';
import '../../terminal/application/terminal_font_discovery.dart';
import '../../terminal/application/terminal_shortcut_policy.dart';
import '../../transfers/application/transfer_queue_controller.dart';
import '../../transfers/domain/transfer_conflict.dart';
import '../../transfers/domain/transfer_task.dart';
import '../../vault/application/vault_service.dart';
import '../application/workspace_tab_controller.dart';
import '../application/workspace_runtime_registry.dart';
import '../domain/workspace_tab.dart';
import 'workspace_search.dart';

final _workspaceSearchQueryProvider =
    NotifierProvider<_WorkspaceSearchQueryController, String>(
      _WorkspaceSearchQueryController.new,
    );

class _WorkspaceSearchQueryController extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) {
    state = query;
  }

  void clear() {
    state = '';
  }
}

class WorkspaceScreen extends ConsumerWidget {
  const WorkspaceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(workspaceTabControllerProvider);
    final controller = ref.read(workspaceTabControllerProvider.notifier);
    final showSearch = _showsWorkspaceSearch(state.area);
    final showLocalTerminal = _showsLocalTerminalAction(state.area);
    final showTopBar =
        showSearch || showLocalTerminal || AppWindow.usesTrailingWindowControls;

    return Scaffold(
      body: Row(
        children: [
          _Sidebar(selected: state.area, onSelected: controller.selectArea),
          const VerticalDivider(width: 1),
          Expanded(
            child: Column(
              children: [
                if (showTopBar) ...[
                  _TopBar(
                    showSearch: showSearch,
                    searchPlaceholder: _workspaceSearchPlaceholder(state.area),
                    showLocalTerminal: showLocalTerminal,
                    onOpenLocalTerminal: controller.openLocalTerminal,
                  ),
                  const Divider(height: 1),
                ],
                Expanded(child: _MainSurface(state: state)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

bool _showsWorkspaceSearch(WorkspaceArea area) {
  return switch (area) {
    WorkspaceArea.hosts || WorkspaceArea.snippets => true,
    WorkspaceArea.sessions ||
    WorkspaceArea.transfers ||
    WorkspaceArea.settings => false,
  };
}

bool _showsLocalTerminalAction(WorkspaceArea area) {
  return switch (area) {
    WorkspaceArea.hosts ||
    WorkspaceArea.sessions ||
    WorkspaceArea.snippets => true,
    WorkspaceArea.transfers || WorkspaceArea.settings => false,
  };
}

String _workspaceSearchPlaceholder(WorkspaceArea area) {
  return switch (area) {
    WorkspaceArea.hosts => 'Search hosts by name, host, user, tag',
    WorkspaceArea.snippets => 'Search snippets by name, command, tag',
    WorkspaceArea.sessions => 'Search sessions',
    WorkspaceArea.transfers => 'Search transfers',
    WorkspaceArea.settings => 'Search settings',
  };
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.selected, required this.onSelected});

  final WorkspaceArea selected;
  final ValueChanged<WorkspaceArea> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 196,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _BrandHeader(),
          _NavItem(
            icon: Icons.dns_outlined,
            label: 'Hosts',
            selected: selected == WorkspaceArea.hosts,
            onTap: () => onSelected(WorkspaceArea.hosts),
          ),
          _NavItem(
            icon: Icons.terminal_outlined,
            label: 'Sessions',
            selected: selected == WorkspaceArea.sessions,
            onTap: () => onSelected(WorkspaceArea.sessions),
          ),
          _NavItem(
            icon: Icons.sync_alt_outlined,
            label: 'Transfers',
            selected: selected == WorkspaceArea.transfers,
            onTap: () => onSelected(WorkspaceArea.transfers),
          ),
          _NavItem(
            icon: Icons.code_outlined,
            label: 'Snippets',
            selected: selected == WorkspaceArea.snippets,
            onTap: () => onSelected(WorkspaceArea.snippets),
          ),
          const Spacer(),
          _NavItem(
            icon: Icons.settings_outlined,
            label: 'Settings',
            selected: selected == WorkspaceArea.settings,
            onTap: () => onSelected(WorkspaceArea.settings),
          ),
          if (AppWindow.usesMacStyleChrome) ...[
            const SizedBox(height: 6),
            const _SidebarBrandFooter(),
          ],
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    final content = AppWindow.usesMacStyleChrome
        ? SizedBox(
            height: 48,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  const _MacWindowControls(),
                  const SizedBox(width: 12),
                  const Expanded(child: _WindowDragRegion()),
                ],
              ),
            ),
          )
        : Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: const _BrandMark(),
          );

    if (!AppWindow.usesCustomChrome) {
      return content;
    }
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (_) => unawaited(AppWindow.startDrag()),
      onDoubleTap: () => unawaited(AppWindow.toggleMaximize()),
      child: content,
    );
  }
}

class _SidebarBrandFooter extends StatelessWidget {
  const _SidebarBrandFooter();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(18, 5, 18, 2),
      child: _BrandMark(compact: true),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final iconSize = compact ? 24.0 : 28.0;
    return Row(
      children: [
        Container(
          width: iconSize,
          height: iconSize,
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(compact ? 7 : 8),
          ),
          child: Icon(
            Icons.hub_outlined,
            size: compact ? 15 : 18,
            color: scheme.onPrimaryContainer,
          ),
        ),
        SizedBox(width: compact ? 9 : 10),
        Flexible(
          child: Text(
            'Serlink',
            overflow: TextOverflow.ellipsis,
            style:
                (compact
                        ? Theme.of(context).textTheme.titleSmall
                        : Theme.of(context).textTheme.titleMedium)
                    ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: selected
            ? scheme.primary.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: selected ? scheme.primary : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? scheme.primary : scheme.onSurface,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends ConsumerStatefulWidget {
  const _TopBar({
    required this.showSearch,
    required this.searchPlaceholder,
    required this.showLocalTerminal,
    required this.onOpenLocalTerminal,
  });

  final bool showSearch;
  final String searchPlaceholder;
  final bool showLocalTerminal;
  final VoidCallback onOpenLocalTerminal;

  @override
  ConsumerState<_TopBar> createState() => _TopBarState();
}

class _TopBarState extends ConsumerState<_TopBar> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(_workspaceSearchQueryProvider);
    if (_searchController.text != query) {
      _searchController.value = TextEditingValue(
        text: query,
        selection: TextSelection.collapsed(offset: query.length),
      );
    }
    return SizedBox(
      height: 48,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            if (widget.showSearch) ...[
              SizedBox(
                width: 312,
                child: TextField(
                  key: const ValueKey('workspace-search-field'),
                  controller: _searchController,
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.48),
                    hintText: widget.searchPlaceholder,
                    prefixIcon: const Icon(Icons.search, size: 18),
                    suffixIcon: query.trim().isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            onPressed: () {
                              _searchController.clear();
                              ref
                                  .read(_workspaceSearchQueryProvider.notifier)
                                  .clear();
                            },
                            icon: const Icon(Icons.close, size: 16),
                          ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    border: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(999)),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(999)),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(999),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 1,
                      ),
                    ),
                  ),
                  onChanged: (value) {
                    ref
                        .read(_workspaceSearchQueryProvider.notifier)
                        .setQuery(value);
                  },
                ),
              ),
              const SizedBox(width: 12),
            ],
            const Expanded(child: _WindowDragRegion()),
            if (widget.showLocalTerminal)
              Tooltip(
                message: 'Open local terminal tab',
                child: IconButton(
                  onPressed: widget.onOpenLocalTerminal,
                  icon: const Icon(Icons.terminal_outlined),
                ),
              ),
            if (AppWindow.usesTrailingWindowControls) ...[
              const SizedBox(width: 6),
              const _WindowControls(),
            ],
          ],
        ),
      ),
    );
  }
}

class _MacWindowControls extends StatefulWidget {
  const _MacWindowControls();

  @override
  State<_MacWindowControls> createState() => _MacWindowControlsState();
}

class _MacWindowControlsState extends State<_MacWindowControls> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() {
        _hovered = true;
      }),
      onExit: (_) => setState(() {
        _hovered = false;
      }),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MacWindowControlButton(
            label: 'Close window',
            color: const Color(0xFFFF5F57),
            borderColor: const Color(0xFFE0443E),
            icon: Icons.close_rounded,
            showIcon: _hovered,
            onPressed: () => unawaited(AppWindow.close()),
          ),
          const SizedBox(width: 8),
          _MacWindowControlButton(
            label: 'Minimize window',
            color: const Color(0xFFFFBD2E),
            borderColor: const Color(0xFFDEA123),
            icon: Icons.remove_rounded,
            showIcon: _hovered,
            onPressed: () => unawaited(AppWindow.minimize()),
          ),
          const SizedBox(width: 8),
          _MacWindowControlButton(
            label: 'Zoom window',
            color: const Color(0xFF28C840),
            borderColor: const Color(0xFF1DAC2B),
            icon: Icons.add_rounded,
            showIcon: _hovered,
            onPressed: () => unawaited(AppWindow.toggleMaximize()),
          ),
        ],
      ),
    );
  }
}

class _MacWindowControlButton extends StatelessWidget {
  const _MacWindowControlButton({
    required this.label,
    required this.color,
    required this.borderColor,
    required this.icon,
    required this.showIcon,
    required this.onPressed,
  });

  final String label;
  final Color color;
  final Color borderColor;
  final IconData icon;
  final bool showIcon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: SizedBox.square(
          dimension: 14,
          child: Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: borderColor, width: 0.7),
              ),
              child: SizedBox.square(
                dimension: 12,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 90),
                  opacity: showIcon ? 1 : 0,
                  child: Icon(
                    icon,
                    size: 8.5,
                    color: const Color(0xFF4E1111).withValues(alpha: 0.82),
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

class _WindowDragRegion extends StatelessWidget {
  const _WindowDragRegion();

  @override
  Widget build(BuildContext context) {
    if (!AppWindow.usesCustomChrome) {
      return const SizedBox.shrink();
    }
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (_) => unawaited(AppWindow.startDrag()),
      onDoubleTap: () => unawaited(AppWindow.toggleMaximize()),
      child: const SizedBox.expand(),
    );
  }
}

class _WindowControls extends StatefulWidget {
  const _WindowControls();

  @override
  State<_WindowControls> createState() => _WindowControlsState();
}

class _WindowControlsState extends State<_WindowControls> {
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    unawaited(_refreshMaximized());
  }

  Future<void> _refreshMaximized() async {
    final maximized = await AppWindow.isMaximized();
    if (!mounted) {
      return;
    }
    setState(() {
      _isMaximized = maximized;
    });
  }

  Future<void> _toggleMaximize() async {
    final maximized = await AppWindow.toggleMaximize();
    if (!mounted) {
      return;
    }
    setState(() {
      _isMaximized = maximized;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _WindowControlButton(
          icon: Icons.remove_rounded,
          onPressed: () => unawaited(AppWindow.minimize()),
        ),
        _WindowControlButton(
          icon: _isMaximized
              ? Icons.filter_none_rounded
              : Icons.crop_square_rounded,
          onPressed: () => unawaited(_toggleMaximize()),
        ),
        _WindowControlButton(
          icon: Icons.close_rounded,
          isClose: true,
          onPressed: () => unawaited(AppWindow.close()),
        ),
      ],
    );
  }
}

class _WindowControlButton extends StatefulWidget {
  const _WindowControlButton({
    required this.icon,
    required this.onPressed,
    this.isClose = false,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final bool isClose;

  @override
  State<_WindowControlButton> createState() => _WindowControlButtonState();
}

class _WindowControlButtonState extends State<_WindowControlButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = _hovered
        ? widget.isClose
              ? const Color(0xFFE81123)
              : scheme.onSurface.withValues(alpha: 0.08)
        : Colors.transparent;
    final foreground = _hovered && widget.isClose
        ? Colors.white
        : scheme.onSurfaceVariant;

    return MouseRegion(
      onEnter: (_) => setState(() {
        _hovered = true;
      }),
      onExit: (_) => setState(() {
        _hovered = false;
      }),
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: widget.onPressed,
          child: SizedBox.square(
            dimension: 34,
            child: Icon(widget.icon, size: 16, color: foreground),
          ),
        ),
      ),
    );
  }
}

class _MainSurface extends ConsumerWidget {
  const _MainSurface({required this.state});

  final WorkspaceState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (state.area) {
      WorkspaceArea.hosts => const _HostsSurface(),
      WorkspaceArea.sessions => _WorkspaceTabs(state: state),
      WorkspaceArea.transfers => const _TransfersSurface(),
      WorkspaceArea.snippets => const _SnippetsSurface(),
      WorkspaceArea.settings => const _SettingsSurface(),
    };
  }
}

class _HostsSurface extends ConsumerWidget {
  const _HostsSurface();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vaultSession = ref.watch(vaultSessionControllerProvider);
    final controller = ref.read(workspaceTabControllerProvider.notifier);
    final searchQuery = ref.watch(_workspaceSearchQueryProvider);

    return vaultSession.when(
      loading: () => const _PlaceholderSurface(
        title: 'Vault',
        body: 'Preparing encrypted storage.',
      ),
      error: (error, stackTrace) => _VaultAccessSurface(error: error),
      data: (session) {
        if (session.vaultState != VaultState.unlocked) {
          return _VaultAccessSurface(session: session);
        }
        final hostsAsync = ref.watch(hostSummariesProvider);
        final content = hostsAsync.when(
          loading: () => const _PlaceholderSurface(
            title: 'Hosts',
            body: 'Loading encrypted host records.',
          ),
          error: (error, stackTrace) =>
              _PlaceholderSurface(title: 'Hosts', body: error.toString()),
          data: (hosts) {
            final filteredHosts = filterHostSummaries(hosts, searchQuery);
            if (hosts.isEmpty) {
              return _HostsEmptyState(
                onAddHost: () => _showAddHostDialog(context),
              );
            }
            return Row(
              children: [
                SizedBox(
                  width: 420,
                  child: Column(
                    children: [
                      _HostsHeader(
                        count: filteredHosts.length,
                        onAddHost: () => _showAddHostDialog(context),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: filteredHosts.isEmpty
                            ? const _PlaceholderSurface(
                                title: 'No Matches',
                                body:
                                    'No hosts match the current workspace search.',
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.all(12),
                                itemCount: filteredHosts.length,
                                separatorBuilder: (context, index) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final host = filteredHosts[index];
                                  return _HostRow(
                                    host: host,
                                    onTerminal: () =>
                                        controller.openTerminal(host),
                                    onSftp: () => controller.openSftp(host),
                                    onBoth: () =>
                                        controller.openTerminalAndSftp(host),
                                    onEdit: () =>
                                        _showEditHostDialog(context, host),
                                    onDelete: () =>
                                        _confirmDeleteHost(context, ref, host),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1),
                const Expanded(child: _WorkspaceHint()),
              ],
            );
          },
        );
        final recoveryKey = session.recoveryKey;
        if (recoveryKey == null) {
          return content;
        }
        return _RecoveryKeyDialogGate(recoveryKey: recoveryKey, child: content);
      },
    );
  }
}

Future<void> _showAddHostDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => const _HostFormDialog(),
  );
}

Future<void> _showEditHostDialog(BuildContext context, HostSummary host) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _HostFormDialog(host: host),
  );
}

Future<void> _confirmDeleteHost(
  BuildContext context,
  WidgetRef ref,
  HostSummary host,
) async {
  final confirmed = await _confirmDialog(
    context,
    title: 'Delete host?',
    body:
        'This removes the host and any credentials that are not used by another host.',
    confirmLabel: 'Delete',
    destructive: true,
  );
  if (!confirmed) {
    return;
  }
  try {
    await ref.read(hostWriteServiceProvider).deleteHost(host.id);
    ref.invalidate(hostSummariesProvider);
    if (context.mounted) {
      _showSnackBar(context, 'Host deleted.');
    }
  } on Object {
    if (context.mounted) {
      _showSnackBar(context, 'Host could not be deleted.');
    }
  }
}

class _HostsHeader extends StatelessWidget {
  const _HostsHeader({required this.count, required this.onAddHost});

  final int count;
  final VoidCallback onAddHost;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Text('Hosts', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(width: 8),
            Text(
              count.toString(),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const Spacer(),
            Tooltip(
              message: 'Add host',
              child: IconButton(
                key: const ValueKey('add-host-button'),
                onPressed: onAddHost,
                icon: const Icon(Icons.add),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HostsEmptyState extends StatelessWidget {
  const _HostsEmptyState({required this.onAddHost});

  final VoidCallback onAddHost;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('No Hosts', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Import SSH config or add hosts to start a session.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const ValueKey('empty-add-host-button'),
              onPressed: onAddHost,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Host'),
            ),
          ],
        ),
      ),
    );
  }
}

enum _HostAuthInputMode { password, privateKey, existingIdentity }

class _HostFormDialog extends ConsumerStatefulWidget {
  const _HostFormDialog({this.host});

  final HostSummary? host;

  @override
  ConsumerState<_HostFormDialog> createState() => _HostFormDialogState();
}

class _HostFormDialogState extends ConsumerState<_HostFormDialog> {
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _hostnameController = TextEditingController();
  final TextEditingController _portController = TextEditingController(
    text: '22',
  );
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _privateKeyController = TextEditingController();
  final TextEditingController _keyPassphraseController =
      TextEditingController();
  final TextEditingController _startupCommandsController =
      TextEditingController();
  final TextEditingController _tagsController = TextEditingController();
  final TextEditingController _connectTimeoutController = TextEditingController(
    text: '20',
  );
  final TextEditingController _keepAliveIntervalController =
      TextEditingController(text: '10');
  final TextEditingController _reconnectAttemptsController =
      TextEditingController(text: '0');
  final TextEditingController _reconnectBackoffController =
      TextEditingController(text: '5');

  _HostAuthInputMode _authMode = _HostAuthInputMode.password;
  List<IdentityConfig> _identityOptions = const [];
  List<HostSummary> _jumpHostOptions = const [];
  Set<IdentityId> _selectedIdentityIds = const {};
  Set<HostId> _selectedJumpHostIds = const {};
  bool _showAdvancedConnection = false;
  bool _loadingOptions = true;
  bool _saving = false;
  String? _errorMessage;

  bool get _isEditing => widget.host != null;

  @override
  void initState() {
    super.initState();
    final host = widget.host;
    if (host == null) {
      return;
    }
    _displayNameController.text = host.displayName;
    _hostnameController.text = host.hostname;
    _portController.text = host.port.toString();
    _usernameController.text = host.username;
    _tagsController.text = host.tags.join(', ');
    unawaited(_loadOptions());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isEditing && _loadingOptions) {
      unawaited(_loadOptions());
    }
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _hostnameController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _privateKeyController.dispose();
    _keyPassphraseController.dispose();
    _startupCommandsController.dispose();
    _tagsController.dispose();
    _connectTimeoutController.dispose();
    _keepAliveIntervalController.dispose();
    _reconnectAttemptsController.dispose();
    _reconnectBackoffController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Edit Host' : 'Add Host'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const ValueKey('host-display-name-field'),
                controller: _displayNameController,
                decoration: const InputDecoration(labelText: 'Display name'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('host-hostname-field'),
                controller: _hostnameController,
                decoration: const InputDecoration(labelText: 'Hostname'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      key: const ValueKey('host-username-field'),
                      controller: _usernameController,
                      decoration: const InputDecoration(labelText: 'Username'),
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _portController,
                      decoration: const InputDecoration(labelText: 'Port'),
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('host-startup-commands-field'),
                controller: _startupCommandsController,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Startup commands',
                ),
              ),
              if (!_isEditing) ...[
                const SizedBox(height: 12),
                SegmentedButton<_HostAuthInputMode>(
                  segments: [
                    ButtonSegment(
                      value: _HostAuthInputMode.password,
                      icon: Icon(Icons.password, size: 16),
                      label: Text('Password'),
                    ),
                    ButtonSegment(
                      value: _HostAuthInputMode.privateKey,
                      icon: Icon(Icons.key, size: 16),
                      label: Text('Private Key'),
                    ),
                    ButtonSegment(
                      value: _HostAuthInputMode.existingIdentity,
                      icon: const Icon(Icons.badge_outlined, size: 16),
                      label: const Text('Existing'),
                      enabled: _identityOptions.isNotEmpty,
                    ),
                  ],
                  selected: {_authMode},
                  onSelectionChanged: (selection) {
                    setState(() {
                      _authMode = selection.single;
                    });
                  },
                ),
                const SizedBox(height: 12),
                switch (_authMode) {
                  _HostAuthInputMode.password => TextField(
                    key: const ValueKey('host-password-field'),
                    controller: _passwordController,
                    decoration: const InputDecoration(labelText: 'Password'),
                    obscureText: true,
                    onSubmitted: (_) => _save(),
                  ),
                  _HostAuthInputMode.privateKey => _PrivateKeyFields(
                    privateKeyController: _privateKeyController,
                    passphraseController: _keyPassphraseController,
                    onImportKey: _importPrivateKey,
                  ),
                  _HostAuthInputMode.existingIdentity =>
                    _IdentitySelectionSection(
                      identities: _identityOptions,
                      selectedIdentityIds: _selectedIdentityIds,
                      enabled: !_loadingOptions,
                      onToggle: _toggleIdentity,
                    ),
                },
              ],
              if (_isEditing) ...[
                const SizedBox(height: 12),
                _IdentitySelectionSection(
                  identities: _identityOptions,
                  selectedIdentityIds: _selectedIdentityIds,
                  enabled: !_loadingOptions,
                  onToggle: _toggleIdentity,
                ),
              ],
              if (_jumpHostOptions.isNotEmpty) ...[
                const SizedBox(height: 12),
                _JumpHostSelectionSection(
                  hosts: _jumpHostOptions,
                  selectedHostIds: _selectedJumpHostIds,
                  enabled: !_loadingOptions,
                  onToggle: _toggleJumpHost,
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _tagsController,
                decoration: const InputDecoration(labelText: 'Tags'),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _save(),
              ),
              const SizedBox(height: 12),
              _AdvancedConnectionSettingsSection(
                expanded: _showAdvancedConnection,
                connectTimeoutController: _connectTimeoutController,
                keepAliveIntervalController: _keepAliveIntervalController,
                reconnectAttemptsController: _reconnectAttemptsController,
                reconnectBackoffController: _reconnectBackoffController,
                onToggle: () {
                  setState(() {
                    _showAdvancedConnection = !_showAdvancedConnection;
                  });
                },
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('host-save-button'),
          onPressed: _saving || _loadingOptions ? null : _save,
          child: Text(_saving ? 'Saving' : 'Save'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final port = int.tryParse(_portController.text.trim());
    if (port == null) {
      setState(() {
        _errorMessage = 'Port must be a number.';
      });
      return;
    }
    final connectionSettings = _parseConnectionSettings();
    if (connectionSettings == null) {
      return;
    }

    setState(() {
      _saving = true;
      _errorMessage = null;
    });
    try {
      final service = ref.read(hostWriteServiceProvider);
      final host = widget.host;
      final startupCommands = _parseStartupCommands(
        _startupCommandsController.text,
      );
      final jumpHostIds = _selectedJumpHostIds.toList(growable: false);
      if (host != null) {
        await service.updateHostMetadata(
          HostMetadataDraft(
            id: host.id,
            displayName: _displayNameController.text,
            hostname: _hostnameController.text,
            port: port,
            username: _usernameController.text,
            tags: _parseTags(_tagsController.text),
            identityIds: _selectedIdentityIds.toList(growable: false),
            startupCommands: startupCommands,
            jumpHostIds: jumpHostIds,
            connectionSettings: connectionSettings,
          ),
        );
      } else if (_authMode == _HostAuthInputMode.password) {
        await service.createPasswordHost(
          PasswordHostDraft(
            displayName: _displayNameController.text,
            hostname: _hostnameController.text,
            port: port,
            username: _usernameController.text,
            password: _passwordController.text,
            tags: _parseTags(_tagsController.text),
            startupCommands: startupCommands,
            jumpHostIds: jumpHostIds,
            connectionSettings: connectionSettings,
          ),
        );
      } else if (_authMode == _HostAuthInputMode.privateKey) {
        await service.createPrivateKeyHost(
          PrivateKeyHostDraft(
            displayName: _displayNameController.text,
            hostname: _hostnameController.text,
            port: port,
            username: _usernameController.text,
            privateKeyPem: _privateKeyController.text,
            privateKeyPassphrase: _keyPassphraseController.text,
            tags: _parseTags(_tagsController.text),
            startupCommands: startupCommands,
            jumpHostIds: jumpHostIds,
            connectionSettings: connectionSettings,
          ),
        );
      } else {
        await service.createHostWithExistingIdentities(
          ExistingIdentitiesHostDraft(
            displayName: _displayNameController.text,
            hostname: _hostnameController.text,
            port: port,
            username: _usernameController.text,
            identityIds: _selectedIdentityIds.toList(growable: false),
            tags: _parseTags(_tagsController.text),
            startupCommands: startupCommands,
            jumpHostIds: jumpHostIds,
            connectionSettings: connectionSettings,
          ),
        );
      }
      ref.invalidate(hostSummariesProvider);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } on HostWriteException catch (error) {
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
          _errorMessage = 'Host could not be saved.';
        });
      }
    }
  }

  Future<void> _importPrivateKey() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'SSH Private Key', extensions: ['pem', 'key', 'txt']),
      ],
    );
    if (file == null) {
      return;
    }
    _privateKeyController.text = await file.readAsString();
  }

  Future<void> _loadOptions() async {
    try {
      final identities = await ref.read(identityRepositoryProvider).list();
      final hostConfigs = await ref.read(hostRepositoryProvider).list();
      final editingHostId = widget.host?.id;
      final hostConfig = editingHostId == null
          ? null
          : await ref.read(hostRepositoryProvider).read(editingHostId);
      if (!mounted) {
        return;
      }
      identities.sort(
        (left, right) => left.displayName.toLowerCase().compareTo(
          right.displayName.toLowerCase(),
        ),
      );
      final jumpHosts = [
        for (final host
            in hostConfigs.map((host) => host.toSummary()).toList()..sort(
              (left, right) => left.displayName.toLowerCase().compareTo(
                right.displayName.toLowerCase(),
              ),
            ))
          if (host.id != editingHostId) host,
      ];
      setState(() {
        _identityOptions = List<IdentityConfig>.unmodifiable(identities);
        _jumpHostOptions = List<HostSummary>.unmodifiable(jumpHosts);
        if (hostConfig != null) {
          _selectedIdentityIds = {...hostConfig.identityIds};
          _selectedJumpHostIds = {...hostConfig.jumpHostIds};
          _startupCommandsController.text = hostConfig.startupCommands.join(
            '\n',
          );
          _connectTimeoutController.text = hostConfig
              .connectionSettings
              .connectTimeoutSeconds
              .toString();
          _keepAliveIntervalController.text = hostConfig
              .connectionSettings
              .keepAliveIntervalSeconds
              .toString();
          _reconnectAttemptsController.text = hostConfig
              .connectionSettings
              .reconnectAttempts
              .toString();
          _reconnectBackoffController.text = hostConfig
              .connectionSettings
              .reconnectBackoffSeconds
              .toString();
        } else if (_authMode == _HostAuthInputMode.existingIdentity &&
            identities.isEmpty) {
          _authMode = _HostAuthInputMode.password;
        }
        _loadingOptions = false;
      });
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingOptions = false;
        _errorMessage = 'Host configuration could not be loaded.';
      });
    }
  }

  void _toggleIdentity(IdentityId identityId) {
    final next = {..._selectedIdentityIds};
    if (!next.add(identityId)) {
      next.remove(identityId);
    }
    setState(() {
      _selectedIdentityIds = next;
    });
  }

  void _toggleJumpHost(HostId hostId) {
    final next = {..._selectedJumpHostIds};
    if (!next.add(hostId)) {
      next.remove(hostId);
    }
    setState(() {
      _selectedJumpHostIds = next;
    });
  }

  HostConnectionSettings? _parseConnectionSettings() {
    final connectTimeout = int.tryParse(_connectTimeoutController.text.trim());
    final keepAlive = int.tryParse(_keepAliveIntervalController.text.trim());
    final reconnectAttempts = int.tryParse(
      _reconnectAttemptsController.text.trim(),
    );
    final reconnectBackoff = int.tryParse(
      _reconnectBackoffController.text.trim(),
    );
    if (connectTimeout == null ||
        keepAlive == null ||
        reconnectAttempts == null ||
        reconnectBackoff == null) {
      setState(() {
        _errorMessage = 'Connection settings must be whole numbers.';
      });
      return null;
    }
    return HostConnectionSettings(
      connectTimeoutSeconds: connectTimeout,
      keepAliveIntervalSeconds: keepAlive,
      reconnectAttempts: reconnectAttempts,
      reconnectBackoffSeconds: reconnectBackoff,
    );
  }
}

class _PrivateKeyFields extends StatelessWidget {
  const _PrivateKeyFields({
    required this.privateKeyController,
    required this.passphraseController,
    required this.onImportKey,
  });

  final TextEditingController privateKeyController;
  final TextEditingController passphraseController;
  final VoidCallback onImportKey;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const ValueKey('host-private-key-field'),
                controller: privateKeyController,
                minLines: 5,
                maxLines: 8,
                decoration: const InputDecoration(labelText: 'Private key'),
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: 'Import private key',
              child: IconButton(
                key: const ValueKey('host-import-private-key-button'),
                onPressed: onImportKey,
                icon: const Icon(Icons.file_open_outlined),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('host-key-passphrase-field'),
          controller: passphraseController,
          decoration: const InputDecoration(labelText: 'Key passphrase'),
          obscureText: true,
        ),
      ],
    );
  }
}

class _AdvancedConnectionSettingsSection extends StatelessWidget {
  const _AdvancedConnectionSettingsSection({
    required this.expanded,
    required this.connectTimeoutController,
    required this.keepAliveIntervalController,
    required this.reconnectAttemptsController,
    required this.reconnectBackoffController,
    required this.onToggle,
  });

  final bool expanded;
  final TextEditingController connectTimeoutController;
  final TextEditingController keepAliveIntervalController;
  final TextEditingController reconnectAttemptsController;
  final TextEditingController reconnectBackoffController;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onToggle,
            icon: Icon(
              expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              size: 18,
            ),
            label: const Text('Advanced connection'),
          ),
        ),
        if (expanded) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _ConnectionNumberField(
                  key: const ValueKey('host-connect-timeout-field'),
                  controller: connectTimeoutController,
                  label: 'Timeout (s)',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ConnectionNumberField(
                  key: const ValueKey('host-keepalive-interval-field'),
                  controller: keepAliveIntervalController,
                  label: 'Keepalive (s)',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ConnectionNumberField(
                  key: const ValueKey('host-reconnect-attempts-field'),
                  controller: reconnectAttemptsController,
                  label: 'Auto reconnect',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ConnectionNumberField(
                  key: const ValueKey('host-reconnect-backoff-field'),
                  controller: reconnectBackoffController,
                  label: 'Backoff (s)',
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ConnectionNumberField extends StatelessWidget {
  const _ConnectionNumberField({
    super.key,
    required this.controller,
    required this.label,
  });

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.next,
    );
  }
}

class _IdentitySelectionSection extends StatelessWidget {
  const _IdentitySelectionSection({
    required this.identities,
    required this.selectedIdentityIds,
    required this.enabled,
    required this.onToggle,
  });

  final List<IdentityConfig> identities;
  final Set<IdentityId> selectedIdentityIds;
  final bool enabled;
  final ValueChanged<IdentityId> onToggle;

  @override
  Widget build(BuildContext context) {
    if (identities.isEmpty) {
      return const Align(
        alignment: Alignment.centerLeft,
        child: Text('No imported identities are available yet.'),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Credentials', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final identity in identities)
              FilterChip(
                label: Text(
                  '${identity.displayName} · ${_identityKindLabel(identity.kind)}',
                ),
                selected: selectedIdentityIds.contains(identity.id),
                onSelected: enabled ? (_) => onToggle(identity.id) : null,
              ),
          ],
        ),
      ],
    );
  }
}

class _JumpHostSelectionSection extends StatelessWidget {
  const _JumpHostSelectionSection({
    required this.hosts,
    required this.selectedHostIds,
    required this.enabled,
    required this.onToggle,
  });

  final List<HostSummary> hosts;
  final Set<HostId> selectedHostIds;
  final bool enabled;
  final ValueChanged<HostId> onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Jump hosts', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final host in hosts)
              FilterChip(
                label: Text(host.displayName),
                selected: selectedHostIds.contains(host.id),
                onSelected: enabled ? (_) => onToggle(host.id) : null,
              ),
          ],
        ),
      ],
    );
  }
}

Set<String> _parseTags(String value) {
  return {
    for (final tag in value.split(',').map((tag) => tag.trim()))
      if (tag.isNotEmpty) tag,
  };
}

List<String> _parseStartupCommands(String value) {
  return [
    for (final command in value.split('\n').map((command) => command.trim()))
      if (command.isNotEmpty) command,
  ];
}

String _identityKindLabel(IdentityKind kind) {
  return switch (kind) {
    IdentityKind.password => 'Password',
    IdentityKind.privateKey => 'Private Key',
    IdentityKind.keyboardInteractive => 'Keyboard',
    IdentityKind.openSshCertificate => 'Certificate',
    IdentityKind.sshAgent => 'SSH Agent',
    IdentityKind.hardwareKey => 'Hardware Key',
  };
}

class _RecoveryKeyDialogGate extends ConsumerStatefulWidget {
  const _RecoveryKeyDialogGate({
    required this.recoveryKey,
    required this.child,
  });

  final VaultRecoveryKey recoveryKey;
  final Widget child;

  @override
  ConsumerState<_RecoveryKeyDialogGate> createState() =>
      _RecoveryKeyDialogGateState();
}

class _RecoveryKeyDialogGateState
    extends ConsumerState<_RecoveryKeyDialogGate> {
  String? _shownRecoveryKey;

  @override
  void initState() {
    super.initState();
    _scheduleDialog();
  }

  @override
  void didUpdateWidget(_RecoveryKeyDialogGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleDialog();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }

  void _scheduleDialog() {
    final recoveryKey = widget.recoveryKey.value;
    if (_shownRecoveryKey == recoveryKey) {
      return;
    }
    _shownRecoveryKey = recoveryKey;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _showRecoveryKeyDialog(recoveryKey);
    });
  }

  Future<void> _showRecoveryKeyDialog(String recoveryKey) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _RecoveryKeyDialog(recoveryKey: recoveryKey),
    );
    if (!mounted) {
      return;
    }
    ref.read(vaultSessionControllerProvider.notifier).dismissRecoveryKey();
  }
}

class _RecoveryKeyDialog extends StatefulWidget {
  const _RecoveryKeyDialog({required this.recoveryKey});

  final String recoveryKey;

  @override
  State<_RecoveryKeyDialog> createState() => _RecoveryKeyDialogState();
}

class _RecoveryKeyDialogState extends State<_RecoveryKeyDialog> {
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
      actionsPadding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.key_outlined,
              size: 20,
              color: scheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(child: Text('Recovery Key')),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Save this key before continuing.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.errorContainer.withValues(alpha: 0.44),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: scheme.error.withValues(alpha: 0.22)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: scheme.error,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'This key is shown only once. If it is lost, Serlink cannot retrieve it for you.',
                        key: const ValueKey('recovery-key-warning'),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onErrorContainer,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.64),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: SelectableText(
                  widget.recoveryKey,
                  key: const ValueKey('recovery-key-value'),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontFamily: 'monospace',
                    height: 1.35,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        OutlinedButton.icon(
          key: const ValueKey('recovery-key-copy-button'),
          onPressed: _copyRecoveryKey,
          icon: Icon(_copied ? Icons.check_rounded : Icons.copy_rounded),
          label: Text(_copied ? 'Copied' : 'Copy Recovery Key'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('I have saved it'),
        ),
      ],
    );
  }

  Future<void> _copyRecoveryKey() async {
    await Clipboard.setData(ClipboardData(text: widget.recoveryKey));
    if (!mounted) {
      return;
    }
    setState(() {
      _copied = true;
    });
  }
}

class _VaultAccessSurface extends ConsumerStatefulWidget {
  const _VaultAccessSurface({this.session, this.error});

  final VaultSessionState? session;
  final Object? error;

  @override
  ConsumerState<_VaultAccessSurface> createState() =>
      _VaultAccessSurfaceState();
}

class _VaultAccessSurfaceState extends ConsumerState<_VaultAccessSurface> {
  final TextEditingController _passphraseController = TextEditingController();
  String? _localErrorMessage;

  @override
  void dispose() {
    _passphraseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(vaultSessionControllerProvider);
    final session = asyncState.value ?? widget.session;
    final isInitializing = session?.vaultState == VaultState.uninitialized;
    final recoveryKey = session?.recoveryKey;
    final errorMessage =
        _localErrorMessage ??
        session?.failureMessage ??
        (asyncState.hasError ? asyncState.error.toString() : null) ??
        widget.error?.toString();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isInitializing ? 'Create Vault' : 'Unlock Vault',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              TextField(
                key: const ValueKey('vault-passphrase-field'),
                controller: _passphraseController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: isInitializing ? 'New passphrase' : 'Passphrase',
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => _submit(isInitializing),
              ),
              const SizedBox(height: 12),
              FilledButton(
                key: const ValueKey('vault-submit-button'),
                onPressed: asyncState.isLoading
                    ? null
                    : () => _submit(isInitializing),
                child: Text(isInitializing ? 'Create Vault' : 'Unlock'),
              ),
              if (!isInitializing && session?.localUnlockAvailable == true) ...[
                const SizedBox(height: 8),
                OutlinedButton(
                  key: const ValueKey('vault-local-unlock-button'),
                  onPressed: asyncState.isLoading
                      ? null
                      : () => ref
                            .read(vaultSessionControllerProvider.notifier)
                            .unlockWithLocalKey(),
                  child: const Text('Unlock with device'),
                ),
              ],
              if (errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  errorMessage,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              if (recoveryKey != null) ...[
                const SizedBox(height: 20),
                SelectableText(recoveryKey.value),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => ref
                      .read(vaultSessionControllerProvider.notifier)
                      .dismissRecoveryKey(),
                  child: const Text('Done'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _submit(bool isInitializing) {
    final passphrase = _passphraseController.text;
    if (passphrase.isEmpty) {
      setState(() {
        _localErrorMessage = 'Enter a vault passphrase to continue.';
      });
      return;
    }
    setState(() {
      _localErrorMessage = null;
    });
    if (isInitializing) {
      ref
          .read(vaultSessionControllerProvider.notifier)
          .initialize(passphrase: passphrase);
    } else {
      ref
          .read(vaultSessionControllerProvider.notifier)
          .unlock(passphrase: passphrase);
    }
  }
}

class _HostRow extends StatelessWidget {
  const _HostRow({
    required this.host,
    required this.onTerminal,
    required this.onSftp,
    required this.onBoth,
    required this.onEdit,
    required this.onDelete,
  });

  final HostSummary host;
  final VoidCallback onTerminal;
  final VoidCallback onSftp;
  final VoidCallback onBoth;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final subtitle = '${host.username}@${host.hostname}:${host.port}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    host.displayName,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _TrustText(state: host.trustState),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final tag in host.tags) Chip(label: Text(tag))],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: onTerminal,
                  icon: const Icon(Icons.terminal, size: 16),
                  label: const Text('Terminal'),
                ),
                OutlinedButton.icon(
                  onPressed: onSftp,
                  icon: const Icon(Icons.folder_open, size: 16),
                  label: const Text('SFTP'),
                ),
                IconButton(
                  tooltip: 'Open terminal and SFTP',
                  onPressed: onBoth,
                  icon: const Icon(Icons.splitscreen_outlined),
                ),
                IconButton(
                  key: ValueKey('host-edit-${host.id.value}'),
                  tooltip: 'Edit host',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  key: ValueKey('host-delete-${host.id.value}'),
                  tooltip: 'Delete host',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TrustText extends StatelessWidget {
  const _TrustText({required this.state});

  final HostTrustState state;

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      HostTrustState.trusted => Colors.green,
      HostTrustState.unknown => Colors.amber,
      HostTrustState.changed => Colors.redAccent,
    };
    final label = switch (state) {
      HostTrustState.trusted => 'trusted',
      HostTrustState.unknown => 'verify',
      HostTrustState.changed => 'changed',
    };
    return Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
    );
  }
}

class _WorkspaceHint extends StatelessWidget {
  const _WorkspaceHint();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Text(
          'Open a host as Terminal, SFTP, or both. Tabs share one workspace and reconnect in place.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}

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
            const Divider(height: 1),
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
    return SizedBox(
      height: 48,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Text('Snippets', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(width: 8),
            Text(
              count.toString(),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const Spacer(),
            Tooltip(
              message: 'Add snippet',
              child: IconButton(
                key: const ValueKey('add-snippet-button'),
                onPressed: onAdd,
                icon: const Icon(Icons.add),
              ),
            ),
          ],
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
      child: FilledButton.icon(
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
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
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _singleLineCommand(snippet.command),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                  ),
                  if (snippet.tags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final tag in snippet.tags) Chip(label: Text(tag)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Tooltip(
              message: 'Insert into active terminal',
              child: IconButton(
                key: ValueKey('snippet-insert-${snippet.id.value}'),
                onPressed: onInsert,
                icon: const Icon(Icons.input_outlined),
              ),
            ),
            Tooltip(
              message: 'Run in active terminal',
              child: IconButton(
                key: ValueKey('snippet-run-${snippet.id.value}'),
                onPressed: onRun,
                icon: const Icon(Icons.play_arrow_outlined),
              ),
            ),
            Tooltip(
              message: 'Edit snippet',
              child: IconButton(
                key: ValueKey('snippet-edit-${snippet.id.value}'),
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
              ),
            ),
            Tooltip(
              message: 'Delete snippet',
              child: IconButton(
                key: ValueKey('snippet-delete-${snippet.id.value}'),
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showSnippetDialog(
  BuildContext context, {
  CommandSnippet? snippet,
}) {
  return showDialog<void>(
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
    return AlertDialog(
      title: Text(_isEditing ? 'Edit Snippet' : 'Add Snippet'),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const ValueKey('snippet-name-field'),
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name'),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('snippet-command-field'),
              controller: _commandController,
              minLines: 3,
              maxLines: 8,
              decoration: const InputDecoration(labelText: 'Command'),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('snippet-tags-field'),
              controller: _tagsController,
              decoration: const InputDecoration(labelText: 'Tags'),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
            ),
            CheckboxListTile(
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
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
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

class _WorkspaceTabs extends ConsumerWidget {
  const _WorkspaceTabs({required this.state});

  final WorkspaceState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(workspaceTabControllerProvider.notifier);
    final active = state.activeTab ?? state.tabs.firstOrNull;

    void openNewConnection() {
      ref.read(_workspaceSearchQueryProvider.notifier).clear();
      controller.selectArea(WorkspaceArea.hosts);
    }

    if (state.tabs.isEmpty || active == null) {
      return _PlaceholderSurface(
        title: 'No active tabs',
        body: 'Open a host from Hosts to create a terminal or SFTP tab.',
        action: IconButton.filledTonal(
          tooltip: 'New connection',
          onPressed: openNewConnection,
          icon: const Icon(Icons.add),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 42,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            itemBuilder: (context, index) {
              if (index == state.tabs.length) {
                return _NewTabButton(onPressed: openNewConnection);
              }
              final tab = state.tabs[index];
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _TabPill(
                    tab: tab,
                    selected: tab.id == active.id,
                    onTap: () => controller.setActiveTab(tab.id),
                    onClose: () => controller.closeTab(tab.id),
                  ),
                  const SizedBox(width: 6),
                ],
              );
            },
            separatorBuilder: (context, index) => const SizedBox.shrink(),
            itemCount: state.tabs.length + 1,
          ),
        ),
        const Divider(height: 1),
        Expanded(child: _ActiveTabView(tab: active)),
      ],
    );
  }
}

class _TabPill extends StatelessWidget {
  const _TabPill({
    required this.tab,
    required this.selected,
    required this.onTap,
    required this.onClose,
  });

  final WorkspaceTabState tab;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final icon = switch (tab.content.kind) {
      WorkspaceTabKind.terminal => Icons.terminal,
      WorkspaceTabKind.sftp => Icons.folder_open,
      WorkspaceTabKind.localTerminal => Icons.computer,
    };
    final stateIcon = switch (tab.lifecycle) {
      SessionLifecycleState.connected => null,
      SessionLifecycleState.connecting ||
      SessionLifecycleState.authenticating ||
      SessionLifecycleState.verifyingHostKey ||
      SessionLifecycleState.resolvingProfile ||
      SessionLifecycleState.reconnecting => Icons.sync,
      SessionLifecycleState.disconnected => Icons.link_off,
      SessionLifecycleState.failed => Icons.error_outline,
      _ => null,
    };

    return Material(
      color: selected ? scheme.primary.withValues(alpha: 0.16) : scheme.surface,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.only(left: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 180),
                child: Text(tab.title, overflow: TextOverflow.ellipsis),
              ),
              if (stateIcon != null) ...[
                const SizedBox(width: 6),
                Icon(stateIcon, size: 14, color: scheme.error),
              ],
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Close tab',
                onPressed: onClose,
                icon: const Icon(Icons.close, size: 15),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewTabButton extends StatelessWidget {
  const _NewTabButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: 'New connection',
      child: Material(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onPressed,
          child: SizedBox.square(
            dimension: 30,
            child: Icon(Icons.add, size: 17, color: scheme.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}

class _ActiveTabView extends ConsumerWidget {
  const _ActiveTabView({required this.tab});

  final WorkspaceTabState tab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(workspaceTabControllerProvider.notifier);
    final isLocalTerminal = tab.content is LocalTerminalTabContent;
    final showBanner =
        tab.lifecycle == SessionLifecycleState.disconnected ||
        tab.lifecycle == SessionLifecycleState.failed;
    final banner = showBanner
        ? _RecoverableFailureBanner(
            message:
                tab.failure?.message ??
                (isLocalTerminal
                    ? 'Local shell is not running.'
                    : 'Connection is not active.'),
            actionLabel: isLocalTerminal ? 'Restart' : 'Reconnect',
            onReconnect: () => controller.reconnect(tab.id),
            onClose: () => controller.closeTab(tab.id),
          )
        : const SizedBox.shrink();

    return Column(
      children: [
        banner,
        Expanded(
          child: switch (tab.content) {
            TerminalTabContent(
              :final panes,
              :final showSplit,
              :final splitAxis,
              :final activePane,
            ) =>
              _TerminalPane(
                key: ValueKey(
                  panes.map((pane) => pane.sessionId.value).join(':'),
                ),
                tabId: tab.id,
                hostId: tab.hostId,
                title: tab.title,
                panes: panes,
                showSplit: showSplit,
                splitAxis: splitAxis,
                activePane: activePane,
                local: false,
                onOpenSftp: tab.hostId == null
                    ? null
                    : () => controller.openSftpFromTab(tab.id),
              ),
            LocalTerminalTabContent(:final sessionId) => _TerminalPane(
              key: ValueKey(sessionId.value),
              tabId: tab.id,
              hostId: null,
              title: 'Local Shell',
              panes: [
                TerminalPaneState(
                  sessionId: sessionId,
                  title: 'Local Shell',
                  lifecycle: tab.lifecycle,
                ),
              ],
              showSplit: false,
              splitAxis: Axis.horizontal,
              activePane: 0,
              local: true,
              onOpenSftp: null,
            ),
            SftpTabContent(:final sessionId, :final currentPath) => _SftpPane(
              key: ValueKey('${sessionId.value}:$currentPath'),
              tabId: tab.id,
              sessionId: sessionId,
              path: currentPath,
              lifecycle: tab.lifecycle,
              onOpenTerminal: tab.hostId == null
                  ? null
                  : () => controller.openTerminalFromTab(tab.id),
            ),
          },
        ),
      ],
    );
  }
}

class _RecoverableFailureBanner extends StatelessWidget {
  const _RecoverableFailureBanner({
    required this.message,
    required this.actionLabel,
    required this.onReconnect,
    required this.onClose,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onReconnect;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(child: Text(message)),
            TextButton(onPressed: onReconnect, child: Text(actionLabel)),
            TextButton(onPressed: onClose, child: const Text('Close')),
          ],
        ),
      ),
    );
  }
}

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

class _LocalForwardDraft {
  const _LocalForwardDraft({
    required this.localPort,
    required this.remoteHost,
    required this.remotePort,
  });

  final int localPort;
  final String remoteHost;
  final int remotePort;
}

class _RemoteForwardDraft {
  const _RemoteForwardDraft({
    required this.bindHost,
    required this.bindPort,
    required this.localHost,
    required this.localPort,
  });

  final String bindHost;
  final int bindPort;
  final String localHost;
  final int localPort;
}

class _DynamicForwardDraft {
  const _DynamicForwardDraft({required this.bindHost, required this.bindPort});

  final String bindHost;
  final int bindPort;
}

enum _ForwardDialogActionKind {
  startLocal,
  stopLocal,
  startRemote,
  stopRemote,
  startDynamic,
  stopDynamic,
}

class _ForwardDialogAction {
  const _ForwardDialogAction._({
    required this.kind,
    this.localDraft,
    this.remoteDraft,
    this.dynamicDraft,
  });

  const _ForwardDialogAction.startLocal(_LocalForwardDraft draft)
    : this._(kind: _ForwardDialogActionKind.startLocal, localDraft: draft);

  const _ForwardDialogAction.stopLocal()
    : this._(kind: _ForwardDialogActionKind.stopLocal);

  const _ForwardDialogAction.startRemote(_RemoteForwardDraft draft)
    : this._(kind: _ForwardDialogActionKind.startRemote, remoteDraft: draft);

  const _ForwardDialogAction.stopRemote()
    : this._(kind: _ForwardDialogActionKind.stopRemote);

  const _ForwardDialogAction.startDynamic(_DynamicForwardDraft draft)
    : this._(kind: _ForwardDialogActionKind.startDynamic, dynamicDraft: draft);

  const _ForwardDialogAction.stopDynamic()
    : this._(kind: _ForwardDialogActionKind.stopDynamic);

  final _ForwardDialogActionKind kind;
  final _LocalForwardDraft? localDraft;
  final _RemoteForwardDraft? remoteDraft;
  final _DynamicForwardDraft? dynamicDraft;
}

class _ForwardingDialog extends StatefulWidget {
  const _ForwardingDialog({
    required this.activeLocalForward,
    required this.activeRemoteForward,
    required this.activeDynamicForward,
  });

  final _LocalForwardDraft? activeLocalForward;
  final _RemoteForwardDraft? activeRemoteForward;
  final _DynamicForwardDraft? activeDynamicForward;

  @override
  State<_ForwardingDialog> createState() => _ForwardingDialogState();
}

class _ForwardingDialogState extends State<_ForwardingDialog> {
  final TextEditingController _localPortController = TextEditingController();
  final TextEditingController _remoteHostController = TextEditingController(
    text: '127.0.0.1',
  );
  final TextEditingController _remotePortController = TextEditingController();
  final TextEditingController _remoteBindHostController = TextEditingController(
    text: '127.0.0.1',
  );
  final TextEditingController _remoteBindPortController =
      TextEditingController();
  final TextEditingController _remoteLocalHostController =
      TextEditingController(text: '127.0.0.1');
  final TextEditingController _remoteLocalPortController =
      TextEditingController();
  final TextEditingController _dynamicBindHostController =
      TextEditingController(text: '127.0.0.1');
  final TextEditingController _dynamicBindPortController =
      TextEditingController();
  String? _localErrorMessage;
  String? _remoteErrorMessage;
  String? _dynamicErrorMessage;

  @override
  void initState() {
    super.initState();
    final local = widget.activeLocalForward;
    if (local != null) {
      _localPortController.text = local.localPort.toString();
      _remoteHostController.text = local.remoteHost;
      _remotePortController.text = local.remotePort.toString();
    }
    final remote = widget.activeRemoteForward;
    if (remote != null) {
      _remoteBindHostController.text = remote.bindHost;
      _remoteBindPortController.text = remote.bindPort.toString();
      _remoteLocalHostController.text = remote.localHost;
      _remoteLocalPortController.text = remote.localPort.toString();
    }
    final dynamic = widget.activeDynamicForward;
    if (dynamic != null) {
      _dynamicBindHostController.text = dynamic.bindHost;
      _dynamicBindPortController.text = dynamic.bindPort.toString();
    }
  }

  @override
  void dispose() {
    _localPortController.dispose();
    _remoteHostController.dispose();
    _remotePortController.dispose();
    _remoteBindHostController.dispose();
    _remoteBindPortController.dispose();
    _remoteLocalHostController.dispose();
    _remoteLocalPortController.dispose();
    _dynamicBindHostController.dispose();
    _dynamicBindPortController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Port Forwarding'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ForwardSection(
                title: 'Local',
                subtitle: widget.activeLocalForward == null
                    ? 'Expose a remote service on this device.'
                    : '127.0.0.1:${widget.activeLocalForward!.localPort}'
                          ' -> ${widget.activeLocalForward!.remoteHost}'
                          ':${widget.activeLocalForward!.remotePort}',
                actionLabel: widget.activeLocalForward == null
                    ? 'Start'
                    : 'Stop',
                destructive: widget.activeLocalForward != null,
                onPressed: widget.activeLocalForward == null
                    ? _submitLocal
                    : () => Navigator.of(
                        context,
                      ).pop(const _ForwardDialogAction.stopLocal()),
                child: widget.activeLocalForward != null
                    ? null
                    : Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  key: const ValueKey(
                                    'local-forward-local-port-field',
                                  ),
                                  controller: _localPortController,
                                  decoration: const InputDecoration(
                                    labelText: 'Local port',
                                  ),
                                  keyboardType: TextInputType.number,
                                  textInputAction: TextInputAction.next,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  key: const ValueKey(
                                    'local-forward-remote-host-field',
                                  ),
                                  controller: _remoteHostController,
                                  decoration: const InputDecoration(
                                    labelText: 'Remote host',
                                  ),
                                  textInputAction: TextInputAction.next,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            key: const ValueKey(
                              'local-forward-remote-port-field',
                            ),
                            controller: _remotePortController,
                            decoration: const InputDecoration(
                              labelText: 'Remote port',
                            ),
                            keyboardType: TextInputType.number,
                            onSubmitted: (_) => _submitLocal(),
                          ),
                          if (_localErrorMessage != null) ...[
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _localErrorMessage!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
              ),
              const SizedBox(height: 16),
              _ForwardSection(
                title: 'Remote',
                subtitle: widget.activeRemoteForward == null
                    ? 'Expose a local service on the remote host.'
                    : '${widget.activeRemoteForward!.bindHost}'
                          ':${widget.activeRemoteForward!.bindPort}'
                          ' -> ${widget.activeRemoteForward!.localHost}'
                          ':${widget.activeRemoteForward!.localPort}',
                actionLabel: widget.activeRemoteForward == null
                    ? 'Start'
                    : 'Stop',
                destructive: widget.activeRemoteForward != null,
                onPressed: widget.activeRemoteForward == null
                    ? _submitRemote
                    : () => Navigator.of(
                        context,
                      ).pop(const _ForwardDialogAction.stopRemote()),
                child: widget.activeRemoteForward != null
                    ? null
                    : Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  key: const ValueKey(
                                    'remote-forward-bind-host-field',
                                  ),
                                  controller: _remoteBindHostController,
                                  decoration: const InputDecoration(
                                    labelText: 'Bind host',
                                  ),
                                  textInputAction: TextInputAction.next,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  key: const ValueKey(
                                    'remote-forward-bind-port-field',
                                  ),
                                  controller: _remoteBindPortController,
                                  decoration: const InputDecoration(
                                    labelText: 'Bind port',
                                  ),
                                  keyboardType: TextInputType.number,
                                  textInputAction: TextInputAction.next,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  key: const ValueKey(
                                    'remote-forward-local-host-field',
                                  ),
                                  controller: _remoteLocalHostController,
                                  decoration: const InputDecoration(
                                    labelText: 'Local host',
                                  ),
                                  textInputAction: TextInputAction.next,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  key: const ValueKey(
                                    'remote-forward-local-port-field',
                                  ),
                                  controller: _remoteLocalPortController,
                                  decoration: const InputDecoration(
                                    labelText: 'Local port',
                                  ),
                                  keyboardType: TextInputType.number,
                                  onSubmitted: (_) => _submitRemote(),
                                ),
                              ),
                            ],
                          ),
                          if (_remoteErrorMessage != null) ...[
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _remoteErrorMessage!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
              ),
              const SizedBox(height: 16),
              _ForwardSection(
                title: 'SOCKS Proxy',
                subtitle: widget.activeDynamicForward == null
                    ? 'Start a local dynamic proxy for this SSH session.'
                    : '${widget.activeDynamicForward!.bindHost}'
                          ':${widget.activeDynamicForward!.bindPort}',
                actionLabel: widget.activeDynamicForward == null
                    ? 'Start'
                    : 'Stop',
                destructive: widget.activeDynamicForward != null,
                onPressed: widget.activeDynamicForward == null
                    ? _submitDynamic
                    : () => Navigator.of(
                        context,
                      ).pop(const _ForwardDialogAction.stopDynamic()),
                child: widget.activeDynamicForward != null
                    ? null
                    : Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextField(
                              key: const ValueKey(
                                'dynamic-forward-bind-host-field',
                              ),
                              controller: _dynamicBindHostController,
                              decoration: const InputDecoration(
                                labelText: 'Bind host',
                              ),
                              textInputAction: TextInputAction.next,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              key: const ValueKey(
                                'dynamic-forward-bind-port-field',
                              ),
                              controller: _dynamicBindPortController,
                              decoration: const InputDecoration(
                                labelText: 'Bind port',
                              ),
                              keyboardType: TextInputType.number,
                              onSubmitted: (_) => _submitDynamic(),
                            ),
                          ),
                        ],
                      ),
              ),
              if (_dynamicErrorMessage != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _dynamicErrorMessage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  void _submitLocal() {
    final localPort = _parsePort(_localPortController.text);
    final remotePort = _parsePort(_remotePortController.text);
    final remoteHost = _remoteHostController.text.trim();
    if (localPort == null || remotePort == null || remoteHost.isEmpty) {
      setState(() {
        _localErrorMessage =
            'Ports must be 1-65535 and remote host is required.';
      });
      return;
    }
    Navigator.of(context).pop(
      _ForwardDialogAction.startLocal(
        _LocalForwardDraft(
          localPort: localPort,
          remoteHost: remoteHost,
          remotePort: remotePort,
        ),
      ),
    );
  }

  void _submitRemote() {
    final bindHost = _remoteBindHostController.text.trim();
    final bindPort = _parsePort(_remoteBindPortController.text);
    final localHost = _remoteLocalHostController.text.trim();
    final localPort = _parsePort(_remoteLocalPortController.text);
    if (bindHost.isEmpty ||
        localHost.isEmpty ||
        bindPort == null ||
        localPort == null) {
      setState(() {
        _remoteErrorMessage = 'Bind host, local host, and ports must be valid.';
      });
      return;
    }
    Navigator.of(context).pop(
      _ForwardDialogAction.startRemote(
        _RemoteForwardDraft(
          bindHost: bindHost,
          bindPort: bindPort,
          localHost: localHost,
          localPort: localPort,
        ),
      ),
    );
  }

  void _submitDynamic() {
    final bindHost = _dynamicBindHostController.text.trim();
    final bindPort = _parsePort(_dynamicBindPortController.text);
    if (bindHost.isEmpty || bindPort == null) {
      setState(() {
        _dynamicErrorMessage = 'Bind host and port must be valid.';
      });
      return;
    }
    Navigator.of(context).pop(
      _ForwardDialogAction.startDynamic(
        _DynamicForwardDraft(bindHost: bindHost, bindPort: bindPort),
      ),
    );
  }
}

class _ForwardSection extends StatelessWidget {
  const _ForwardSection({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.destructive,
    required this.onPressed,
    this.child,
  });

  final String title;
  final String subtitle;
  final String actionLabel;
  final bool destructive;
  final VoidCallback onPressed;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            FilledButton.tonal(
              onPressed: onPressed,
              style: destructive
                  ? FilledButton.styleFrom(
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.errorContainer,
                      foregroundColor: Theme.of(
                        context,
                      ).colorScheme.onErrorContainer,
                    )
                  : null,
              child: Text(actionLabel),
            ),
          ],
        ),
        if (child != null) ...[const SizedBox(height: 12), child!],
      ],
    );
  }
}

int? _parsePort(String value) {
  final port = int.tryParse(value.trim());
  if (port == null || port < 1 || port > 65535) {
    return null;
  }
  return port;
}

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

enum _SftpUploadKind { file, directory }

class _SftpPane extends ConsumerStatefulWidget {
  const _SftpPane({
    super.key,
    required this.tabId,
    required this.sessionId,
    required this.path,
    required this.lifecycle,
    required this.onOpenTerminal,
  });

  final WorkspaceTabId tabId;
  final SessionId sessionId;
  final String path;
  final SessionLifecycleState lifecycle;
  final VoidCallback? onOpenTerminal;

  @override
  ConsumerState<_SftpPane> createState() => _SftpPaneState();
}

class _SftpPaneState extends ConsumerState<_SftpPane> {
  final TextEditingController _filterController = TextEditingController();
  Future<List<SftpEntry>>? _entriesFuture;
  String _filterText = '';
  bool _showHidden = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_SftpPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sessionId != widget.sessionId ||
        oldWidget.path != widget.path ||
        oldWidget.lifecycle != widget.lifecycle) {
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final canList = widget.lifecycle == SessionLifecycleState.connected;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.folder_open, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(widget.path, overflow: TextOverflow.ellipsis),
              ),
              SizedBox(
                width: 220,
                child: TextField(
                  key: const ValueKey('sftp-search-field'),
                  controller: _filterController,
                  enabled: canList,
                  decoration: const InputDecoration(
                    isDense: true,
                    prefixIcon: Icon(Icons.search, size: 16),
                    hintText: 'Filter',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _filterText = value;
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: _showHidden
                    ? 'Hide hidden files'
                    : 'Show hidden files',
                child: IconButton(
                  key: const ValueKey('sftp-hidden-toggle'),
                  onPressed: canList
                      ? () {
                          setState(() {
                            _showHidden = !_showHidden;
                          });
                        }
                      : null,
                  icon: Icon(
                    _showHidden
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Tooltip(
                message: 'Open terminal tab',
                child: IconButton(
                  onPressed: widget.onOpenTerminal,
                  icon: const Icon(Icons.terminal_outlined, size: 18),
                ),
              ),
              const SizedBox(width: 4),
              PopupMenuButton<_SftpUploadKind>(
                key: const ValueKey('sftp-upload-button'),
                tooltip: 'Upload',
                enabled: canList,
                icon: const Icon(Icons.upload_file_outlined, size: 18),
                onSelected: (kind) {
                  switch (kind) {
                    case _SftpUploadKind.file:
                      _enqueueUploadFile();
                    case _SftpUploadKind.directory:
                      _enqueueUploadDirectory();
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: _SftpUploadKind.file,
                    child: Text('Upload file'),
                  ),
                  PopupMenuItem(
                    value: _SftpUploadKind.directory,
                    child: Text('Upload folder'),
                  ),
                ],
              ),
              Tooltip(
                message: 'New folder',
                child: IconButton(
                  key: const ValueKey('sftp-new-folder-button'),
                  onPressed: canList ? _createDirectory : null,
                  icon: const Icon(Icons.create_new_folder_outlined, size: 18),
                ),
              ),
              Tooltip(
                message: 'Refresh',
                child: IconButton(
                  onPressed: canList
                      ? () {
                          setState(_reload);
                        }
                      : null,
                  icon: const Icon(Icons.refresh, size: 18),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(child: _buildBody(context, canList: canList)),
      ],
    );
  }

  Widget _buildBody(BuildContext context, {required bool canList}) {
    final future = _entriesFuture;
    if (!canList || future == null) {
      return const _PlaceholderSurface(
        title: 'SFTP',
        body: 'Waiting for the SFTP connection.',
      );
    }

    return FutureBuilder<List<SftpEntry>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _PlaceholderSurface(
            title: 'SFTP Error',
            body: sftpFailureMessage(snapshot.error!),
          );
        }
        final allEntries = _sortedEntries(snapshot.data ?? const []);
        final visibleEntries = _showHidden
            ? allEntries
            : [
                for (final entry in allEntries)
                  if (!entry.isHidden) entry,
              ];
        final entries = _filterEntries(visibleEntries, _filterText);
        if (entries.isEmpty) {
          return _PlaceholderSurface(
            title: _filterText.trim().isEmpty ? 'Empty Folder' : 'No Matches',
            body: _sftpEmptyBody(
              allEntries: allEntries,
              visibleEntries: visibleEntries,
              filterText: _filterText,
              showHidden: _showHidden,
            ),
          );
        }
        return ListView.separated(
          itemCount: _showParentEntry ? entries.length + 1 : entries.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            if (_showParentEntry && index == 0) {
              return _SftpEntryRow(
                name: '..',
                typeLabel: 'Directory',
                icon: Icons.drive_folder_upload_outlined,
                sizeLabel: '',
                permissionsLabel: '',
                metadataLabel: '',
                onTap: () => _openDirectory(_parentPath(widget.path)),
                onRename: null,
                onMove: null,
                onChmod: null,
                onDelete: null,
                onDownload: null,
              );
            }
            final entry = entries[_showParentEntry ? index - 1 : index];
            final isDirectory = entry.type == SftpEntryType.directory;
            return _SftpEntryRow(
              name: entry.name,
              typeLabel: _entryTypeLabel(entry.type),
              icon: isDirectory
                  ? Icons.folder_outlined
                  : Icons.description_outlined,
              sizeLabel: isDirectory ? '' : _formatBytes(entry.size),
              permissionsLabel: entry.permissions?.octal ?? '',
              metadataLabel: _sftpEntryMetadataLabel(entry),
              onTap: isDirectory
                  ? () => _openDirectory(entry.path)
                  : () => _previewFile(entry),
              onRename: () => _renameEntry(entry),
              onMove: () => _moveEntry(entry),
              onChmod: () => _chmodEntry(entry),
              onDelete: () => _deleteEntry(entry),
              onDownload:
                  entry.type == SftpEntryType.file ||
                      entry.type == SftpEntryType.directory
                  ? () => _enqueueDownload(entry)
                  : null,
            );
          },
        );
      },
    );
  }

  bool get _showParentEntry => widget.path != '/';

  void _reload() {
    final connection = ref
        .read(workspaceRuntimeRegistryProvider)
        .sftpFor(widget.sessionId);
    _entriesFuture = connection?.list(widget.path);
  }

  void _openDirectory(String path) {
    ref
        .read(workspaceTabControllerProvider.notifier)
        .changeSftpDirectory(widget.tabId, path);
  }

  Future<void> _createDirectory() async {
    final name = await _showTextInputDialog(
      context,
      title: 'New Folder',
      label: 'Folder name',
      confirmLabel: 'Create',
    );
    if (name == null || name.trim().isEmpty) {
      return;
    }
    await _runSftpOperation(
      () => _connection().mkdir(_remoteChildPath(widget.path, name.trim())),
      successMessage: 'Folder created.',
    );
  }

  Future<void> _enqueueUploadFile() async {
    final file = await openFile();
    if (file == null) {
      return;
    }
    final localPath = file.path;
    if (localPath.isEmpty) {
      if (mounted) {
        _showSnackBar(context, 'Selected file has no local path.');
      }
      return;
    }
    final remotePath = await _resolveRemoteTransferConflict(
      desiredRemotePath: _remoteChildPath(widget.path, file.name),
      itemKind: TransferItemKind.file,
    );
    if (remotePath == null) {
      return;
    }
    ref
        .read(transferQueueControllerProvider)
        .enqueueUpload(
          connection: _connection(),
          itemKind: TransferItemKind.file,
          localPath: localPath,
          remotePath: remotePath,
        );
    if (mounted) {
      _showSnackBar(context, 'Upload queued.');
    }
  }

  Future<void> _enqueueUploadDirectory() async {
    final directoryPath = await getDirectoryPath(confirmButtonText: 'Upload');
    if (directoryPath == null || directoryPath.isEmpty) {
      return;
    }
    final directoryName = p.basename(directoryPath);
    final remotePath = await _resolveRemoteTransferConflict(
      desiredRemotePath: _remoteChildPath(widget.path, directoryName),
      itemKind: TransferItemKind.directory,
    );
    if (remotePath == null) {
      return;
    }
    ref
        .read(transferQueueControllerProvider)
        .enqueueUpload(
          connection: _connection(),
          itemKind: TransferItemKind.directory,
          localPath: directoryPath,
          remotePath: remotePath,
        );
    if (mounted) {
      _showSnackBar(context, 'Folder upload queued.');
    }
  }

  Future<void> _enqueueDownload(SftpEntry entry) async {
    final itemKind = entry.type == SftpEntryType.directory
        ? TransferItemKind.directory
        : TransferItemKind.file;
    final localPath = switch (itemKind) {
      TransferItemKind.file => await _pickFileDownloadPath(entry),
      TransferItemKind.directory => await _pickDirectoryDownloadPath(entry),
    };
    if (localPath == null) {
      return;
    }
    ref
        .read(transferQueueControllerProvider)
        .enqueueDownload(
          connection: _connection(),
          itemKind: itemKind,
          remotePath: entry.path,
          localPath: localPath,
        );
    if (mounted) {
      _showSnackBar(
        context,
        itemKind == TransferItemKind.directory
            ? 'Folder download queued.'
            : 'Download queued.',
      );
    }
  }

  Future<String?> _pickFileDownloadPath(SftpEntry entry) async {
    final location = await getSaveLocation(suggestedName: entry.name);
    if (location == null) {
      return null;
    }
    return _resolveLocalTransferConflict(
      desiredLocalPath: location.path,
      itemKind: TransferItemKind.file,
    );
  }

  Future<String?> _pickDirectoryDownloadPath(SftpEntry entry) async {
    final parentPath = await getDirectoryPath(
      confirmButtonText: 'Download',
      canCreateDirectories: true,
    );
    if (parentPath == null || parentPath.isEmpty) {
      return null;
    }
    return _resolveLocalTransferConflict(
      desiredLocalPath: p.join(parentPath, entry.name),
      itemKind: TransferItemKind.directory,
    );
  }

  Future<String?> _resolveRemoteTransferConflict({
    required String desiredRemotePath,
    required TransferItemKind itemKind,
  }) async {
    if (!await _remoteEntryExists(desiredRemotePath)) {
      return desiredRemotePath;
    }
    if (!mounted) {
      return null;
    }
    final action = await _showTransferConflictDialog(
      context,
      title: itemKind == TransferItemKind.directory
          ? 'Merge remote folder?'
          : 'Replace remote file?',
      body: itemKind == TransferItemKind.directory
          ? '$desiredRemotePath already exists on the server. Matching files may be overwritten.'
          : '$desiredRemotePath already exists on the server.',
      replaceLabel: itemKind == TransferItemKind.directory
          ? 'Merge'
          : 'Replace',
    );
    return switch (action) {
      TransferConflictAction.replace => desiredRemotePath,
      TransferConflictAction.rename => _nextAvailableRemotePath(
        desiredRemotePath,
      ),
      TransferConflictAction.skip || null => null,
    };
  }

  Future<String?> _resolveLocalTransferConflict({
    required String desiredLocalPath,
    required TransferItemKind itemKind,
  }) async {
    if (await FileSystemEntity.type(desiredLocalPath) ==
        FileSystemEntityType.notFound) {
      return desiredLocalPath;
    }
    if (!mounted) {
      return null;
    }
    final action = await _showTransferConflictDialog(
      context,
      title: itemKind == TransferItemKind.directory
          ? 'Merge local folder?'
          : 'Replace local file?',
      body: itemKind == TransferItemKind.directory
          ? '$desiredLocalPath already exists on this device. Matching files may be overwritten.'
          : '$desiredLocalPath already exists on this device.',
      replaceLabel: itemKind == TransferItemKind.directory
          ? 'Merge'
          : 'Replace',
    );
    return switch (action) {
      TransferConflictAction.replace => desiredLocalPath,
      TransferConflictAction.rename => _nextAvailableLocalPath(
        desiredLocalPath,
      ),
      TransferConflictAction.skip || null => null,
    };
  }

  Future<String> _nextAvailableRemotePath(String desiredRemotePath) async {
    final parent = _parentPath(desiredRemotePath);
    final entries = await _connection().list(parent);
    return nextRemoteConflictPath(desiredRemotePath, {
      for (final entry in entries) entry.path,
    });
  }

  Future<String> _nextAvailableLocalPath(String desiredLocalPath) async {
    final existingPaths = <String>{};
    final parentPath = p.dirname(desiredLocalPath);
    final parent = Directory(parentPath);
    if (await parent.exists()) {
      await for (final entity in parent.list()) {
        existingPaths.add(entity.path);
      }
    }
    return nextLocalConflictPath(desiredLocalPath, existingPaths);
  }

  Future<void> _renameEntry(SftpEntry entry) async {
    final name = await _showTextInputDialog(
      context,
      title: 'Rename',
      label: 'New name',
      initialValue: entry.name,
      confirmLabel: 'Rename',
    );
    if (name == null || name.trim().isEmpty || name.trim() == entry.name) {
      return;
    }
    await _runSftpOperation(
      () => _connection().rename(
        entry.path,
        _remoteChildPath(_parentPath(entry.path), name.trim()),
      ),
      successMessage: 'Entry renamed.',
    );
  }

  Future<void> _moveEntry(SftpEntry entry) async {
    final target = await _showTextInputDialog(
      context,
      title: 'Move',
      label: 'Target path',
      initialValue: entry.path,
      confirmLabel: 'Move',
    );
    if (target == null || target.trim().isEmpty) {
      return;
    }
    final resolvedTarget = _resolveMoveTarget(target.trim(), entry.name);
    if (resolvedTarget == entry.path) {
      return;
    }
    if (await _remoteEntryExists(resolvedTarget)) {
      if (mounted) {
        _showSnackBar(context, 'Target path already exists.');
      }
      return;
    }
    await _runSftpOperation(
      () => _connection().rename(entry.path, resolvedTarget),
      successMessage: 'Entry moved.',
    );
  }

  Future<void> _chmodEntry(SftpEntry entry) async {
    final octal = await _showTextInputDialog(
      context,
      title: 'Change Permissions',
      label: 'Octal permissions',
      initialValue: entry.permissions?.octal ?? '',
      confirmLabel: 'Apply',
    );
    if (octal == null || !_isOctalPermissions(octal.trim())) {
      if (mounted && octal != null) {
        _showSnackBar(context, 'Permissions must be a 3 or 4 digit octal.');
      }
      return;
    }
    await _runSftpOperation(
      () => _connection().chmod(entry.path, SftpPermissions(octal.trim())),
      successMessage: 'Permissions updated.',
    );
  }

  Future<void> _deleteEntry(SftpEntry entry) async {
    final confirmed = await _confirmDialog(
      context,
      title: 'Delete ${entry.name}?',
      body: entry.type == SftpEntryType.directory
          ? 'This deletes the remote directory and its contents.'
          : 'This deletes the remote file.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed) {
      return;
    }
    await _runSftpOperation(() {
      if (entry.type == SftpEntryType.directory) {
        return _connection().deleteDirectory(entry.path, recursive: true);
      }
      return _connection().deleteFile(entry.path);
    }, successMessage: 'Entry deleted.');
  }

  Future<void> _previewFile(SftpEntry entry) async {
    try {
      final preview = await _connection().readTextPreview(entry.path);
      if (!mounted) {
        return;
      }
      final updatedText = await showDialog<String>(
        context: context,
        builder: (context) => _RemoteFileDialog(entry: entry, preview: preview),
      );
      if (updatedText == null || updatedText == preview.text) {
        return;
      }
      await _runSftpOperation(
        () => _connection().writeTextFile(entry.path, updatedText),
        successMessage: 'File saved.',
      );
    } on Object catch (error) {
      if (mounted) {
        _showSnackBar(context, sftpFailureMessage(error));
      }
    }
  }

  Future<void> _runSftpOperation(
    Future<void> Function() operation, {
    required String successMessage,
  }) async {
    try {
      await operation();
      if (!mounted) {
        return;
      }
      setState(_reload);
      _showSnackBar(context, successMessage);
    } on Object catch (error) {
      if (mounted) {
        _showSnackBar(context, sftpFailureMessage(error));
      }
    }
  }

  SftpConnection _connection() {
    final connection = ref
        .read(workspaceRuntimeRegistryProvider)
        .sftpFor(widget.sessionId);
    if (connection == null) {
      throw StateError('SFTP connection is not active.');
    }
    return connection;
  }

  Future<bool> _remoteEntryExists(String remotePath) async {
    final parent = _parentPath(remotePath);
    final entries = await _connection().list(parent);
    return entries.any((entry) => entry.path == remotePath);
  }
}

class _RemoteFileDialog extends StatefulWidget {
  const _RemoteFileDialog({required this.entry, required this.preview});

  final SftpEntry entry;
  final SftpFilePreview preview;

  @override
  State<_RemoteFileDialog> createState() => _RemoteFileDialogState();
}

class _RemoteFileDialogState extends State<_RemoteFileDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.preview.text);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final preview = widget.preview;
    return AlertDialog(
      title: Text(widget.entry.name, overflow: TextOverflow.ellipsis),
      content: SizedBox(
        width: 720,
        height: 460,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (preview.truncated) ...[
              Text(
                'Preview limited to ${_formatBytes(preview.bytesRead)}.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
            ],
            Expanded(
              child: TextField(
                key: const ValueKey('remote-file-editor'),
                controller: _controller,
                readOnly: preview.truncated,
                expands: true,
                maxLines: null,
                minLines: null,
                keyboardType: TextInputType.multiline,
                style: const TextStyle(fontFamily: 'monospace'),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(preview.truncated ? 'Close' : 'Cancel'),
        ),
        if (!preview.truncated)
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_controller.text),
            child: const Text('Save'),
          ),
      ],
    );
  }
}

class _SftpEntryRow extends StatelessWidget {
  const _SftpEntryRow({
    required this.name,
    required this.typeLabel,
    required this.icon,
    required this.sizeLabel,
    required this.permissionsLabel,
    required this.metadataLabel,
    required this.onTap,
    required this.onRename,
    required this.onMove,
    required this.onChmod,
    required this.onDelete,
    required this.onDownload,
  });

  final String name;
  final String typeLabel;
  final IconData icon;
  final String sizeLabel;
  final String permissionsLabel;
  final String metadataLabel;
  final VoidCallback? onTap;
  final VoidCallback? onRename;
  final VoidCallback? onMove;
  final VoidCallback? onChmod;
  final VoidCallback? onDelete;
  final VoidCallback? onDownload;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(icon),
      title: Text(name, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        metadataLabel.isEmpty ? typeLabel : '$typeLabel · $metadataLabel',
        overflow: TextOverflow.ellipsis,
      ),
      trailing: SizedBox(
        width: 360,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Flexible(child: Text(sizeLabel, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 16),
            SizedBox(width: 44, child: Text(permissionsLabel)),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Download',
              onPressed: onDownload,
              icon: const Icon(Icons.download_outlined, size: 16),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Rename',
              onPressed: onRename,
              icon: const Icon(Icons.drive_file_rename_outline, size: 16),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Move',
              onPressed: onMove,
              icon: const Icon(Icons.drive_file_move_outline, size: 16),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Change permissions',
              onPressed: onChmod,
              icon: const Icon(Icons.admin_panel_settings_outlined, size: 16),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Delete',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline, size: 16),
            ),
          ],
        ),
      ),
      onTap: onTap,
    );
  }
}

class _TransfersSurface extends ConsumerWidget {
  const _TransfersSurface();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(transferQueueStateProvider);
    return queue.when(
      loading: () => const _PlaceholderSurface(
        title: 'Transfers',
        body: 'Preparing transfer queue.',
      ),
      error: (error, stackTrace) =>
          _PlaceholderSurface(title: 'Transfers', body: error.toString()),
      data: (state) {
        if (state.tasks.isEmpty) {
          return const _PlaceholderSurface(
            title: 'No Transfers',
            body: 'SFTP uploads and downloads will appear here.',
          );
        }
        final tasks = [...state.tasks.reversed];
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: tasks.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            return _TransferTaskRow(task: tasks[index]);
          },
        );
      },
    );
  }
}

class _TransferTaskRow extends ConsumerWidget {
  const _TransferTaskRow({required this.task});

  final TransferTask task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.read(transferQueueControllerProvider);
    final progress = task.totalBytes == null || task.totalBytes == 0
        ? null
        : task.transferredBytes / task.totalBytes!;
    final isActive =
        task.state == TransferState.running ||
        task.state == TransferState.paused;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  task.itemKind == TransferItemKind.directory
                      ? Icons.folder_outlined
                      : task.direction == TransferDirection.upload
                      ? Icons.upload_outlined
                      : Icons.download_outlined,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    task.direction == TransferDirection.upload
                        ? _fileName(task.localPath)
                        : _fileName(task.remotePath),
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Text(_transferStateLabel(task.state)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              task.direction == TransferDirection.upload
                  ? '${task.localPath} -> ${task.remotePath}'
                  : '${task.remotePath} -> ${task.localPath}',
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (isActive) ...[
              const SizedBox(height: 10),
              LinearProgressIndicator(value: progress),
              const SizedBox(height: 6),
              Text(
                _transferProgressLabel(task),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (task.bytesPerSecond != null) ...[
                const SizedBox(height: 2),
                Text(
                  '${_formatBytes(task.bytesPerSecond!.round())}/s'
                  '${task.eta == null ? '' : ' · ${_formatDuration(task.eta!)} left'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
            if (task.state == TransferState.failed && task.failure != null) ...[
              const SizedBox(height: 8),
              Text(
                task.failure!.message,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (task.state == TransferState.running)
                  TextButton(
                    onPressed: () => queue.pause(task.id),
                    child: const Text('Pause'),
                  ),
                if (task.state == TransferState.paused)
                  TextButton(
                    onPressed: () => queue.resume(task.id),
                    child: const Text('Resume'),
                  ),
                if (queue.canRetry(task.id))
                  TextButton(
                    onPressed: () => queue.retry(task.id),
                    child: const Text('Retry'),
                  ),
                if (task.state == TransferState.running ||
                    task.state == TransferState.paused ||
                    task.state == TransferState.queued)
                  TextButton(
                    onPressed: () => queue.cancel(task.id),
                    child: const Text('Cancel'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

List<SftpEntry> _sortedEntries(List<SftpEntry> entries) {
  return [...entries]..sort((left, right) {
    final typeCompare = _entryRank(left.type).compareTo(_entryRank(right.type));
    if (typeCompare != 0) {
      return typeCompare;
    }
    return left.name.toLowerCase().compareTo(right.name.toLowerCase());
  });
}

List<SftpEntry> _filterEntries(List<SftpEntry> entries, String filter) {
  final query = filter.trim().toLowerCase();
  if (query.isEmpty) {
    return entries;
  }
  return [
    for (final entry in entries)
      if (entry.name.toLowerCase().contains(query) ||
          entry.path.toLowerCase().contains(query) ||
          (entry.owner?.toLowerCase().contains(query) ?? false) ||
          (entry.group?.toLowerCase().contains(query) ?? false) ||
          (entry.permissions?.octal.contains(query) ?? false))
        entry,
  ];
}

String _sftpEmptyBody({
  required List<SftpEntry> allEntries,
  required List<SftpEntry> visibleEntries,
  required String filterText,
  required bool showHidden,
}) {
  if (filterText.trim().isNotEmpty) {
    return 'No entries match the current filter.';
  }
  if (!showHidden && allEntries.isNotEmpty && visibleEntries.isEmpty) {
    return 'This remote directory only contains hidden entries.';
  }
  return 'This remote directory has no visible entries.';
}

String _sftpEntryMetadataLabel(SftpEntry entry) {
  final ownerGroup = _ownerGroupLabel(entry);
  final parts = [
    if (entry.modifiedAt case final modifiedAt?)
      _shortLocalDateTime(modifiedAt),
    ?ownerGroup,
  ];
  return parts.join(' · ');
}

String? _ownerGroupLabel(SftpEntry entry) {
  final owner = entry.owner?.trim();
  final group = entry.group?.trim();
  if ((owner == null || owner.isEmpty) && (group == null || group.isEmpty)) {
    return null;
  }
  return '${owner?.isEmpty ?? true ? '-' : owner}:'
      '${group?.isEmpty ?? true ? '-' : group}';
}

int _entryRank(SftpEntryType type) {
  return switch (type) {
    SftpEntryType.directory => 0,
    SftpEntryType.symlink => 1,
    SftpEntryType.file => 2,
    SftpEntryType.unknown => 3,
  };
}

String _entryTypeLabel(SftpEntryType type) {
  return switch (type) {
    SftpEntryType.directory => 'Directory',
    SftpEntryType.file => 'File',
    SftpEntryType.symlink => 'Symlink',
    SftpEntryType.unknown => 'Unknown',
  };
}

String _formatBytes(int? bytes) {
  if (bytes == null) {
    return '';
  }
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit += 1;
  }
  if (unit == 0) {
    return '$bytes ${units[unit]}';
  }
  return '${value.toStringAsFixed(value >= 10 ? 0 : 1)} ${units[unit]}';
}

String _transferProgressLabel(TransferTask task) {
  final total = task.totalBytes;
  if (total == null) {
    return '${_formatBytes(task.transferredBytes)} transferred';
  }
  return '${_formatBytes(task.transferredBytes)} / ${_formatBytes(total)}';
}

String _transferStateLabel(TransferState state) {
  return switch (state) {
    TransferState.queued => 'queued',
    TransferState.running => 'running',
    TransferState.paused => 'paused',
    TransferState.completed => 'completed',
    TransferState.failed => 'failed',
    TransferState.canceled => 'canceled',
  };
}

String _formatDuration(Duration duration) {
  final seconds = duration.inSeconds;
  if (seconds < 60) {
    return '${seconds}s';
  }
  final minutes = seconds ~/ 60;
  final remainingSeconds = seconds % 60;
  if (minutes < 60) {
    return '${minutes}m ${remainingSeconds}s';
  }
  final hours = minutes ~/ 60;
  final remainingMinutes = minutes % 60;
  return '${hours}h ${remainingMinutes}m';
}

String _fileName(String path) {
  final parts = path
      .split(RegExp(r'[\\/]'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) {
    return path;
  }
  return parts.last;
}

String _parentPath(String path) {
  final normalized = _joinRemotePath(path);
  if (normalized == '/') {
    return '/';
  }
  final index = normalized.lastIndexOf('/');
  if (index <= 0) {
    return '/';
  }
  return normalized.substring(0, index);
}

String _remoteChildPath(String parent, String childName) {
  final normalizedParent = _joinRemotePath(parent);
  final cleanChild = childName
      .split('/')
      .where((segment) => segment.isNotEmpty && segment != '.')
      .join('/');
  if (cleanChild.isEmpty) {
    return normalizedParent;
  }
  if (normalizedParent == '/') {
    return '/$cleanChild';
  }
  return '$normalizedParent/$cleanChild';
}

String _resolveMoveTarget(String target, String entryName) {
  if (target.endsWith('/')) {
    return _remoteChildPath(target, entryName);
  }
  return _joinRemotePath(target);
}

bool _isOctalPermissions(String value) {
  return RegExp(r'^[0-7]{3,4}$').hasMatch(value);
}

String _joinRemotePath(String path) {
  final segments = <String>[];
  for (final segment in path.split('/')) {
    if (segment.isEmpty || segment == '.') {
      continue;
    }
    if (segment == '..') {
      if (segments.isNotEmpty) {
        segments.removeLast();
      }
      continue;
    }
    segments.add(segment);
  }
  return '/${segments.join('/')}';
}

Future<String?> _showTextInputDialog(
  BuildContext context, {
  required String title,
  required String label,
  required String confirmLabel,
  String initialValue = '',
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _TextInputDialog(
      title: title,
      label: label,
      confirmLabel: confirmLabel,
      initialValue: initialValue,
    ),
  );
}

class _TextInputDialog extends StatefulWidget {
  const _TextInputDialog({
    required this.title,
    required this.label,
    required this.confirmLabel,
    required this.initialValue,
  });

  final String title;
  final String label;
  final String confirmLabel;
  final String initialValue;

  @override
  State<_TextInputDialog> createState() => _TextInputDialogState();
}

class _TextInputDialogState extends State<_TextInputDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        key: ValueKey('text-input-${widget.label}'),
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(labelText: widget.label),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}

class _SettingsSurface extends ConsumerWidget {
  const _SettingsSurface();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vault = ref.watch(vaultSessionControllerProvider).value;
    final vaultState = vault?.vaultState;
    final canImportHostData = vaultState == VaultState.unlocked;

    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 36),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Settings',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Security, sync, import/export, and runtime controls.',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    _SettingsStatusPill(
                      label: _vaultStatusPillLabel(vaultState),
                      color: vaultState == VaultState.unlocked
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                _SettingsSection(
                  title: 'Security',
                  children: [
                    _SettingsActionRow(
                      icon: Icons.lock_outline,
                      title: 'Vault',
                      subtitle: _vaultStateLabel(vaultState),
                      action: vaultState == VaultState.unlocked
                          ? TextButton(
                              onPressed: () => ref
                                  .read(vaultSessionControllerProvider.notifier)
                                  .lock(),
                              child: const Text('Lock'),
                            )
                          : null,
                    ),
                    _SettingsActionRow(
                      icon: Icons.key_outlined,
                      title: 'Local unlock',
                      subtitle: _localUnlockLabel(vault),
                      action: vaultState == VaultState.unlocked
                          ? Switch(
                              value: vault?.localUnlockAvailable ?? false,
                              onChanged: (value) =>
                                  _setLocalVaultUnlock(context, ref, value),
                            )
                          : vault?.localUnlockAvailable == true
                          ? TextButton(
                              onPressed: () => ref
                                  .read(vaultSessionControllerProvider.notifier)
                                  .unlockWithLocalKey(),
                              child: const Text('Unlock'),
                            )
                          : null,
                    ),
                    const _SettingsInfoRow(
                      icon: Icons.verified_user_outlined,
                      title: 'Host key confirmation',
                      subtitle:
                          'Unknown or changed fingerprints require modal review.',
                    ),
                    _SettingsActionRow(
                      icon: Icons.badge_outlined,
                      title: 'Credentials',
                      subtitle: canImportHostData
                          ? 'Review imported passwords, keys, and certificates.'
                          : 'Unlock the vault to review encrypted credentials.',
                      action: TextButton(
                        onPressed: canImportHostData
                            ? () => _showIdentityManagerDialog(context, ref)
                            : null,
                        child: const Text('Manage'),
                      ),
                    ),
                    _SettingsActionRow(
                      icon: Icons.verified_outlined,
                      title: 'Known hosts',
                      subtitle: canImportHostData
                          ? 'Review trusted host fingerprints stored in the vault.'
                          : 'Unlock the vault to review trusted host fingerprints.',
                      action: TextButton(
                        onPressed: canImportHostData
                            ? () => _showKnownHostsDialog(context, ref)
                            : null,
                        child: const Text('Manage'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                _SyncSettingsSection(vaultState: vaultState),
                const SizedBox(height: 26),
                _SettingsSection(
                  title: 'Data',
                  children: [
                    _SettingsActionRow(
                      icon: Icons.import_export_outlined,
                      title: 'Import / Export',
                      subtitle:
                          'Backups, OpenSSH files, certificates, known_hosts, and metadata.',
                      action: TextButton(
                        key: const ValueKey('settings-data-exchange-button'),
                        onPressed: () => _showDataExchangeDialog(
                          context,
                          ref,
                          canImportHostData: canImportHostData,
                        ),
                        child: const Text('Open'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                _SettingsSection(
                  title: 'Runtime',
                  children: [
                    const _SettingsInfoRow(
                      icon: Icons.bug_report_outlined,
                      title: 'Debug logging',
                      subtitle: 'Debug builds keep redacted local logs only.',
                    ),
                    const _SettingsInfoRow(
                      icon: Icons.health_and_safety_outlined,
                      title: 'Crash reporting',
                      subtitle:
                          'Release Sentry events are redacted before upload.',
                    ),
                    _SettingsActionRow(
                      icon: Icons.support_agent_outlined,
                      title: 'Diagnostic bundle',
                      subtitle:
                          'Build info, redacted runtime metadata, and log tail.',
                      action: TextButton(
                        onPressed: () => _exportDiagnosticBundle(context, ref),
                        child: Text('Export'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

Future<void> _showDataExchangeDialog(
  BuildContext context,
  WidgetRef ref, {
  required bool canImportHostData,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      Future<void> runAction(_DataExchangeAction action) async {
        Navigator.of(dialogContext).pop();
        await Future<void>.delayed(Duration.zero);
        if (!context.mounted) {
          return;
        }
        switch (action) {
          case _DataExchangeAction.exportVaultBackup:
            await _exportVaultBackup(context, ref);
          case _DataExchangeAction.exportHostMetadata:
            await _exportHostMetadata(context, ref);
          case _DataExchangeAction.exportOpenSshConfig:
            await _exportOpenSshConfig(context, ref);
          case _DataExchangeAction.exportIdentityMetadata:
            await _exportIdentityMetadata(context, ref);
          case _DataExchangeAction.importVaultBackup:
            await _importVaultBackup(context, ref);
          case _DataExchangeAction.importOpenSshConfig:
            await _importOpenSshConfig(context, ref);
          case _DataExchangeAction.importKnownHosts:
            await _importKnownHosts(context, ref);
          case _DataExchangeAction.importOpenSshCertificate:
            await _importOpenSshCertificate(context, ref);
        }
      }

      return _DataExchangeDialog(
        canImportHostData: canImportHostData,
        onActionSelected: (action) => unawaited(runAction(action)),
      );
    },
  );
}

enum _DataExchangeAction {
  exportVaultBackup,
  exportHostMetadata,
  exportOpenSshConfig,
  exportIdentityMetadata,
  importVaultBackup,
  importOpenSshConfig,
  importKnownHosts,
  importOpenSshCertificate,
}

class _DataExchangeDialog extends StatelessWidget {
  const _DataExchangeDialog({
    required this.canImportHostData,
    required this.onActionSelected,
  });

  final bool canImportHostData;
  final ValueChanged<_DataExchangeAction> onActionSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lockedSubtitle = 'Unlock the vault to use this action.';

    return Dialog(
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 660, maxHeight: 720),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Import / Export',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      key: const ValueKey('data-exchange-close-button'),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Backups stay available anytime. Host, identity, and SSH data require an unlocked vault.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                _DataExchangeSection(
                  title: 'Export',
                  children: [
                    _DataExchangeActionTile(
                      icon: Icons.lock_outline,
                      title: 'Export encrypted backup',
                      subtitle: 'Encrypted vault records and header.',
                      onPressed: () => onActionSelected(
                        _DataExchangeAction.exportVaultBackup,
                      ),
                    ),
                    _DataExchangeActionTile(
                      icon: Icons.dns_outlined,
                      title: 'Export host metadata',
                      subtitle: 'Host names, addresses, tags, and options.',
                      enabled: canImportHostData,
                      disabledSubtitle: lockedSubtitle,
                      onPressed: () => onActionSelected(
                        _DataExchangeAction.exportHostMetadata,
                      ),
                    ),
                    _DataExchangeActionTile(
                      icon: Icons.terminal_outlined,
                      title: 'Export OpenSSH config',
                      subtitle: 'Selected hosts as an OpenSSH config.',
                      enabled: canImportHostData,
                      disabledSubtitle: lockedSubtitle,
                      onPressed: () => onActionSelected(
                        _DataExchangeAction.exportOpenSshConfig,
                      ),
                    ),
                    _DataExchangeActionTile(
                      icon: Icons.badge_outlined,
                      title: 'Export identity metadata',
                      subtitle:
                          'Display names, hints, and public fingerprints.',
                      enabled: canImportHostData,
                      disabledSubtitle: lockedSubtitle,
                      onPressed: () => onActionSelected(
                        _DataExchangeAction.exportIdentityMetadata,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _DataExchangeSection(
                  title: 'Import',
                  children: [
                    _DataExchangeActionTile(
                      icon: Icons.restore_outlined,
                      title: 'Import encrypted backup',
                      subtitle: 'Merge records from a Serlink backup.',
                      onPressed: () => onActionSelected(
                        _DataExchangeAction.importVaultBackup,
                      ),
                    ),
                    _DataExchangeActionTile(
                      icon: Icons.terminal_outlined,
                      title: 'Import OpenSSH config',
                      subtitle: 'Create hosts from an ssh config file.',
                      enabled: canImportHostData,
                      disabledSubtitle: lockedSubtitle,
                      onPressed: () => onActionSelected(
                        _DataExchangeAction.importOpenSshConfig,
                      ),
                    ),
                    _DataExchangeActionTile(
                      icon: Icons.verified_outlined,
                      title: 'Import known_hosts',
                      subtitle: 'Add fingerprints for existing hosts.',
                      enabled: canImportHostData,
                      disabledSubtitle: lockedSubtitle,
                      onPressed: () => onActionSelected(
                        _DataExchangeAction.importKnownHosts,
                      ),
                    ),
                    _DataExchangeActionTile(
                      icon: Icons.key_outlined,
                      title: 'Import OpenSSH certificate',
                      subtitle: 'Create an identity from key and certificate.',
                      enabled: canImportHostData,
                      disabledSubtitle: lockedSubtitle,
                      onPressed: () => onActionSelected(
                        _DataExchangeAction.importOpenSshCertificate,
                      ),
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

class _DataExchangeSection extends StatelessWidget {
  const _DataExchangeSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border.symmetric(
              horizontal: BorderSide(color: scheme.outlineVariant),
            ),
          ),
          child: Column(
            children: [
              for (var index = 0; index < children.length; index++) ...[
                if (index > 0)
                  Divider(
                    height: 1,
                    indent: 52,
                    color: scheme.outlineVariant.withValues(alpha: 0.7),
                  ),
                children[index],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _DataExchangeActionTile extends StatelessWidget {
  const _DataExchangeActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onPressed,
    this.enabled = true,
    this.disabledSubtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onPressed;
  final bool enabled;
  final String? disabledSubtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final effectiveSubtitle = enabled ? subtitle : disabledSubtitle ?? subtitle;

    return InkWell(
      onTap: enabled ? onPressed : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
        child: Opacity(
          opacity: enabled ? 1 : 0.48,
          child: Row(
            children: [
              SizedBox.square(
                dimension: 40,
                child: Center(
                  child: Icon(icon, size: 20, color: scheme.onSurfaceVariant),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      effectiveSubtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SyncSettingsSection extends ConsumerWidget {
  const _SyncSettingsSection({required this.vaultState});

  final VaultState? vaultState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canEdit = vaultState == VaultState.unlocked;
    final webDav = canEdit ? ref.watch(webDavSyncSettingsProvider) : null;
    final knownDevices = canEdit ? ref.watch(syncKnownDevicesProvider) : null;
    final conflicts = ref.watch(syncConflictControllerProvider);
    final autoSync = ref.watch(autoSyncControllerProvider);
    final lastFailure = autoSync.lastFailure;
    final repairPlan = lastFailure == null
        ? null
        : ref.watch(syncRepairServiceProvider).planFor(lastFailure);
    final webDavRow =
        webDav?.when(
          loading: () => const _SettingsInfoRow(
            icon: Icons.cloud_queue,
            title: 'WebDAV',
            subtitle: 'Loading encrypted sync settings.',
          ),
          error: (error, stackTrace) => _SettingsActionRow(
            icon: Icons.cloud_queue,
            title: 'WebDAV',
            subtitle: _syncSettingsErrorMessage(error),
            action: TextButton(
              onPressed: () => _showWebDavSyncDialog(context, ref, null),
              child: const Text('Configure'),
            ),
          ),
          data: (settings) => _SettingsActionRow(
            icon: Icons.cloud_queue,
            title: 'WebDAV',
            subtitle: _webDavSettingsSubtitle(settings, autoSync),
            action: TextButton(
              onPressed: () => _showWebDavSyncDialog(context, ref, settings),
              child: Text(settings == null ? 'Configure' : 'Edit'),
            ),
          ),
        ) ??
        const _SettingsInfoRow(
          icon: Icons.cloud_queue,
          title: 'WebDAV',
          subtitle: 'Unlock the vault to configure encrypted sync.',
        );

    return _SettingsSection(
      title: 'Sync',
      children: [
        webDavRow,
        if (repairPlan != null) _SyncRepairRow(plan: repairPlan),
        if (conflicts.isNotEmpty) _SyncConflictRow(conflicts: conflicts),
        if (knownDevices != null)
          knownDevices.when(
            loading: () => const _SettingsInfoRow(
              icon: Icons.devices_outlined,
              title: 'Devices',
              subtitle: 'Loading encrypted device records.',
            ),
            error: (error, stackTrace) => _SettingsInfoRow(
              icon: Icons.devices_outlined,
              title: 'Devices',
              subtitle: _syncSettingsErrorMessage(error),
            ),
            data: (devices) => _SettingsActionRow(
              icon: Icons.devices_outlined,
              title: 'Devices',
              subtitle: _syncDevicesSubtitle(devices),
              action: Wrap(
                spacing: 4,
                children: [
                  TextButton(
                    onPressed: () =>
                        _showSyncDevicesDialog(context, ref, devices),
                    child: Text(devices.isEmpty ? 'View' : 'Manage'),
                  ),
                  TextButton(
                    onPressed: () => _rotateSyncDevice(context, ref),
                    child: const Text('Reset'),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _SyncRepairRow extends ConsumerWidget {
  const _SyncRepairRow({required this.plan});

  final SyncRepairPlan plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _SettingsActionRow(
      icon: Icons.build_outlined,
      title: 'Sync repair',
      subtitle: plan.message,
      action: TextButton(
        onPressed: () => _repairWebDavSync(context, ref, plan),
        child: const Text('Repair'),
      ),
    );
  }
}

Future<void> _repairWebDavSync(
  BuildContext context,
  WidgetRef ref,
  SyncRepairPlan plan,
) async {
  if (plan.action == SyncRepairAction.reviewLocalClock) {
    await _reviewLocalClock(context, ref, plan);
    return;
  }
  if (plan.action == SyncRepairAction.trustWebDavCertificate) {
    await _trustWebDavCertificate(context, ref, plan);
    return;
  }
  final confirmed = await _confirmDialog(
    context,
    title: plan.title,
    body: plan.message,
    confirmLabel: 'Repair',
    destructive: plan.destructive,
  );
  if (!confirmed || !context.mounted) {
    return;
  }
  try {
    final provider = await ref
        .read(syncSettingsServiceProvider)
        .buildWebDavProvider();
    final result = await ref
        .read(syncRunServiceProvider)
        .runRepair(provider, plan.action);
    ref
        .read(autoSyncControllerProvider.notifier)
        .markConflictResolution(result);
    ref.invalidate(syncKnownDevicesProvider);
    if (context.mounted) {
      _showSnackBar(context, 'Remote sync repaired.');
    }
  } on Object catch (error) {
    if (context.mounted) {
      _showSnackBar(context, _syncSettingsErrorMessage(error));
    }
  }
}

Future<void> _trustWebDavCertificate(
  BuildContext context,
  WidgetRef ref,
  SyncRepairPlan plan,
) async {
  final lastFailure = ref.read(autoSyncControllerProvider).lastFailure;
  final certificate = lastFailure is SyncProviderException
      ? WebDavTlsCertificateDetails.tryParse(lastFailure.diagnostic)
      : null;
  if (certificate == null) {
    _showSnackBar(context, plan.message);
    return;
  }
  final decision = await ref
      .read(securityModalServiceProvider)
      .confirmWebDavCertificate(certificate);
  if (decision != CertificateTrustDecision.trustAndSave) {
    return;
  }
  try {
    await ref
        .read(syncSettingsServiceProvider)
        .trustWebDavCertificate(certificate);
    ref.invalidate(webDavSyncSettingsProvider);
    ref
        .read(autoSyncControllerProvider.notifier)
        .requestSync(delay: Duration.zero);
    if (context.mounted) {
      _showSnackBar(context, 'WebDAV certificate trust saved.');
    }
  } on Object catch (error) {
    if (context.mounted) {
      _showSnackBar(context, _syncSettingsErrorMessage(error));
    }
  }
}

Future<void> _reviewLocalClock(
  BuildContext context,
  WidgetRef ref,
  SyncRepairPlan plan,
) async {
  final lastFailure = ref.read(autoSyncControllerProvider).lastFailure;
  final certificate = lastFailure is SyncProviderException
      ? WebDavTlsCertificateDetails.tryParse(lastFailure.diagnostic)
      : null;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: Text(plan.title),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(plan.message),
            const SizedBox(height: 12),
            Text('Local time: ${_shortLocalDateTime(DateTime.now())}'),
            if (certificate != null) ...[
              const SizedBox(height: 8),
              Text('Endpoint: ${certificate.endpoint}'),
              const SizedBox(height: 8),
              Text('Valid from: ${_shortLocalDateTime(certificate.validFrom)}'),
              const SizedBox(height: 8),
              Text(
                'Valid until: ${_shortLocalDateTime(certificate.validUntil)}',
              ),
            ],
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    ),
  );
}

class _SyncConflictRow extends ConsumerWidget {
  const _SyncConflictRow({required this.conflicts});

  final List<SyncRecordConflict> conflicts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _SettingsActionRow(
      icon: Icons.report_problem_outlined,
      title: 'Sync conflicts',
      subtitle:
          '${conflicts.length} encrypted record${conflicts.length == 1 ? '' : 's'} need review.',
      action: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            onPressed: () => _reviewWebDavConflicts(context, ref, conflicts),
            child: const Text('Review'),
          ),
          TextButton(
            onPressed: () => _resolveWebDavConflicts(
              context,
              ref,
              SyncConflictResolution.useRemote,
            ),
            child: const Text('Use remote'),
          ),
          TextButton(
            onPressed: () => _resolveWebDavConflicts(
              context,
              ref,
              SyncConflictResolution.keepLocal,
            ),
            child: const Text('Keep local'),
          ),
        ],
      ),
    );
  }
}

Future<void> _reviewWebDavConflicts(
  BuildContext context,
  WidgetRef ref,
  List<SyncRecordConflict> conflicts,
) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _SyncConflictReviewDialog(conflicts: conflicts),
  );
}

Future<void> _resolveWebDavConflicts(
  BuildContext context,
  WidgetRef ref,
  SyncConflictResolution resolution,
) async {
  final useRemote = resolution == SyncConflictResolution.useRemote;
  final confirmed = await _confirmDialog(
    context,
    title: useRemote ? 'Use remote records?' : 'Keep local records?',
    body: useRemote
        ? 'Remote encrypted records will replace conflicting local records before syncing.'
        : 'Local encrypted records will overwrite conflicting remote records.',
    confirmLabel: useRemote ? 'Use remote' : 'Keep local',
    destructive: true,
  );
  if (!confirmed || !context.mounted) {
    return;
  }
  try {
    final provider = await ref
        .read(syncSettingsServiceProvider)
        .buildWebDavProvider();
    final result = await ref
        .read(syncRunServiceProvider)
        .resolveConflicts(provider, resolution);
    ref.read(syncConflictControllerProvider.notifier).clear();
    ref
        .read(autoSyncControllerProvider.notifier)
        .markConflictResolution(result);
    ref.invalidate(syncKnownDevicesProvider);
    if (context.mounted) {
      _showSnackBar(
        context,
        'Resolved sync conflicts. Synced ${result.recordsUploaded} encrypted records.',
      );
    }
  } on SyncRunConflictException catch (error) {
    ref
        .read(syncConflictControllerProvider.notifier)
        .setConflicts(error.conflicts);
    if (context.mounted) {
      _showSnackBar(context, _syncSettingsErrorMessage(error));
    }
  } on Object catch (error) {
    if (context.mounted) {
      _showSnackBar(context, _syncSettingsErrorMessage(error));
    }
  }
}

class _SyncConflictReviewDialog extends ConsumerStatefulWidget {
  const _SyncConflictReviewDialog({required this.conflicts});

  final List<SyncRecordConflict> conflicts;

  @override
  ConsumerState<_SyncConflictReviewDialog> createState() =>
      _SyncConflictReviewDialogState();
}

class _SyncConflictReviewDialogState
    extends ConsumerState<_SyncConflictReviewDialog> {
  final Map<String, Map<String, bool>> _choices = {};
  var _saving = false;

  @override
  void initState() {
    super.initState();
    for (final conflict in widget.conflicts) {
      final fieldSet = conflict.fieldSet;
      if (fieldSet == null) {
        continue;
      }
      _choices[conflict.id.value] = {
        for (final field in fieldSet.fields) field.key: false,
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Review sync conflicts'),
      content: SizedBox(
        width: 820,
        height: 520,
        child: ListView.separated(
          itemCount: widget.conflicts.length,
          separatorBuilder: (_, _) => const Divider(height: 24),
          itemBuilder: (context, index) {
            final conflict = widget.conflicts[index];
            final fieldSet = conflict.fieldSet;
            if (fieldSet == null) {
              return _SyncConflictUnsupportedCard(conflict: conflict);
            }
            if (!fieldSet.supportsFieldMerge) {
              return _SyncConflictUnsupportedCard(conflict: conflict);
            }
            return _SyncConflictFieldCard(
              conflict: conflict,
              fieldSet: fieldSet,
              useRemoteByField: _choices[conflict.id.value] ?? const {},
              onChanged: (fieldKey, useRemote) {
                setState(() {
                  _choices.putIfAbsent(conflict.id.value, () => {})[fieldKey] =
                      useRemote;
                });
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _apply,
          child: Text(_saving ? 'Applying' : 'Apply merge'),
        ),
      ],
    );
  }

  Future<void> _apply() async {
    setState(() {
      _saving = true;
    });
    try {
      for (final conflict in widget.conflicts) {
        final fieldSet = conflict.fieldSet;
        if (fieldSet == null || !fieldSet.supportsFieldMerge) {
          continue;
        }
        final merged = ref
            .read(syncFieldMergeServiceProvider)
            .merge(
              fieldSet: fieldSet,
              useRemoteByField: _choices[conflict.id.value] ?? const {},
            );
        await ref
            .read(syncRunServiceProvider)
            .applyMergedRecord(recordId: conflict.id, mergedJson: merged);
      }
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
      await _resolveWebDavConflicts(
        context,
        ref,
        SyncConflictResolution.keepLocal,
      );
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
      });
      _showSnackBar(context, _syncSettingsErrorMessage(error));
    }
  }
}

class _SyncConflictFieldCard extends StatelessWidget {
  const _SyncConflictFieldCard({
    required this.conflict,
    required this.fieldSet,
    required this.useRemoteByField,
    required this.onChanged,
  });

  final SyncRecordConflict conflict;
  final SyncConflictFieldSet fieldSet;
  final Map<String, bool> useRemoteByField;
  final void Function(String fieldKey, bool useRemote) onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${conflict.type} · ${conflict.id.value}',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        for (final field in fieldSet.fields) ...[
          Text(field.label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _ConflictChoiceTile(
                  title: 'Local',
                  value: describeConflictValue(field.localValue),
                  selected: !(useRemoteByField[field.key] ?? false),
                  onSelected: () => onChanged(field.key, false),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ConflictChoiceTile(
                  title: 'Remote',
                  value: describeConflictValue(field.remoteValue),
                  selected: useRemoteByField[field.key] ?? false,
                  onSelected: () => onChanged(field.key, true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _ConflictChoiceTile extends StatelessWidget {
  const _ConflictChoiceTile({
    required this.title,
    required this.value,
    required this.selected,
    required this.onSelected,
  });

  final String title;
  final String value;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onSelected,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
          ),
          color: selected ? scheme.primary.withValues(alpha: 0.08) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 6),
            Text(
              value,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _SyncConflictUnsupportedCard extends StatelessWidget {
  const _SyncConflictUnsupportedCard({required this.conflict});

  final SyncRecordConflict conflict;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${conflict.type} · ${conflict.id.value}',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        const Text(
          'This record type currently requires whole-record resolution. Use the existing local or remote action for this conflict.',
        ),
      ],
    );
  }
}

String _webDavSettingsSubtitle(
  WebDavSyncSettings? settings,
  AutoSyncStatus autoSync,
) {
  if (settings == null) {
    return 'Not configured. Encrypted manifest and records only.';
  }
  final state = settings.enabled ? 'Enabled' : 'Paused';
  final security = settings.allowInsecureHttp ? 'HTTP allowed' : 'HTTPS';
  final sync = settings.enabled ? _autoSyncStatusSubtitle(autoSync) : null;
  return [
    state,
    security,
    '${settings.endpoint.host}${settings.basePath}',
    ?sync,
  ].join(' · ');
}

String _autoSyncStatusSubtitle(AutoSyncStatus status) {
  return switch (status.phase) {
    AutoSyncPhase.disabled => 'auto-sync waiting',
    AutoSyncPhase.idle =>
      status.lastCompletedAt == null
          ? 'auto-sync ready'
          : 'last synced ${_shortLocalDateTime(status.lastCompletedAt!)}',
    AutoSyncPhase.scheduled => 'auto-sync queued',
    AutoSyncPhase.syncing => 'syncing automatically',
    AutoSyncPhase.conflicts =>
      '${status.conflictCount} conflict${status.conflictCount == 1 ? '' : 's'}',
    AutoSyncPhase.failed => status.lastFailureMessage ?? 'auto-sync failed',
  };
}

String _syncDevicesSubtitle(List<SyncDeviceMetadata> devices) {
  if (devices.isEmpty) {
    return 'This device will be registered on first sync.';
  }
  if (devices.length == 1) {
    return '${devices.single.displayName} registered for encrypted sync.';
  }
  final latest = [...devices]
    ..sort((a, b) => b.lastSeenAt.compareTo(a.lastSeenAt));
  return '${devices.length} devices registered. Last writer: ${latest.first.displayName}.';
}

Future<void> _showSyncDevicesDialog(
  BuildContext context,
  WidgetRef ref,
  List<SyncDeviceMetadata> devices,
) async {
  final localDevice = await ref
      .read(syncDeviceServiceProvider)
      .readLocalDevice();
  if (!context.mounted) {
    return;
  }
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => _SyncDevicesDialog(
      devices: devices,
      localDeviceId: localDevice?.id,
      onDelete: (device) =>
          _deleteSyncDevice(context, dialogContext, ref, device),
    ),
  );
}

Future<void> _deleteSyncDevice(
  BuildContext pageContext,
  BuildContext dialogContext,
  WidgetRef ref,
  SyncDeviceMetadata device,
) async {
  final confirmed = await _confirmDialog(
    dialogContext,
    title: 'Remove ${device.displayName}?',
    body: 'This removes the encrypted sync device record from this vault.',
    confirmLabel: 'Remove',
    destructive: true,
  );
  if (!confirmed) {
    return;
  }
  try {
    await ref.read(syncDeviceServiceProvider).deleteKnownDevice(device.id);
    ref.invalidate(syncKnownDevicesProvider);
    ref.read(autoSyncControllerProvider.notifier).requestSync();
    if (dialogContext.mounted) {
      Navigator.of(dialogContext).pop();
    }
    if (pageContext.mounted) {
      _showSnackBar(pageContext, 'Sync device removed.');
    }
  } on SyncDeviceException catch (error) {
    if (pageContext.mounted) {
      _showSnackBar(pageContext, error.message);
    }
  } on Object {
    if (pageContext.mounted) {
      _showSnackBar(pageContext, 'Sync device could not be removed.');
    }
  }
}

Future<void> _rotateSyncDevice(BuildContext context, WidgetRef ref) async {
  final confirmed = await _confirmDialog(
    context,
    title: 'Reset sync device?',
    body:
        'This removes the current device registration from encrypted sync and creates a new local device identity. Other devices will see the old device as removed.',
    confirmLabel: 'Reset',
    destructive: true,
  );
  if (!confirmed || !context.mounted) {
    return;
  }
  try {
    await ref.read(syncDeviceServiceProvider).rotateLocalDeviceRegistration();
    ref.invalidate(syncKnownDevicesProvider);
    ref.invalidate(autoSyncControllerProvider);
    ref
        .read(autoSyncControllerProvider.notifier)
        .requestSync(delay: Duration.zero);
    if (context.mounted) {
      _showSnackBar(
        context,
        'Sync device reset. A new registration will be created on the next sync.',
      );
    }
  } on SyncDeviceException catch (error) {
    if (context.mounted) {
      _showSnackBar(context, error.message);
    }
  } on Object {
    if (context.mounted) {
      _showSnackBar(context, 'Sync device could not be reset.');
    }
  }
}

class _SyncDevicesDialog extends StatelessWidget {
  const _SyncDevicesDialog({
    required this.devices,
    required this.localDeviceId,
    required this.onDelete,
  });

  final List<SyncDeviceMetadata> devices;
  final String? localDeviceId;
  final Future<void> Function(SyncDeviceMetadata device) onDelete;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Sync Devices'),
      content: SizedBox(
        width: 520,
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: devices.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final device = devices[index];
            final isLocal = device.id == localDeviceId;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                isLocal
                    ? '${device.displayName} (this device)'
                    : device.displayName,
              ),
              subtitle: Text(_syncDeviceSubtitle(device)),
              trailing: isLocal
                  ? null
                  : IconButton(
                      tooltip: 'Remove device',
                      onPressed: () => onDelete(device),
                      icon: const Icon(Icons.delete_outline, size: 18),
                    ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

String _syncDeviceSubtitle(SyncDeviceMetadata device) {
  return '${device.platform} / last seen ${_shortLocalDateTime(device.lastSeenAt)}';
}

String _shortLocalDateTime(DateTime value) {
  return value.toLocal().toIso8601String().split('.').first;
}

Future<void> _showWebDavSyncDialog(
  BuildContext context,
  WidgetRef ref,
  WebDavSyncSettings? settings,
) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _WebDavSyncDialog(initialSettings: settings),
  );
}

class _WebDavSyncDialog extends ConsumerStatefulWidget {
  const _WebDavSyncDialog({required this.initialSettings});

  final WebDavSyncSettings? initialSettings;

  @override
  ConsumerState<_WebDavSyncDialog> createState() => _WebDavSyncDialogState();
}

class _WebDavSyncDialogState extends ConsumerState<_WebDavSyncDialog> {
  late final TextEditingController _endpointController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  late final TextEditingController _basePathController;
  late bool _enabled;
  late bool _allowInsecureHttp;
  var _saving = false;
  String? _errorMessage;

  bool get _isEditing => widget.initialSettings != null;

  @override
  void initState() {
    super.initState();
    final settings = widget.initialSettings;
    _endpointController = TextEditingController(
      text: settings?.endpoint.toString() ?? '',
    );
    _usernameController = TextEditingController(text: settings?.username ?? '');
    _passwordController = TextEditingController();
    _basePathController = TextEditingController(
      text: settings?.basePath ?? '/serlink',
    );
    _enabled = settings?.enabled ?? true;
    _allowInsecureHttp = settings?.allowInsecureHttp ?? false;
  }

  @override
  void dispose() {
    _endpointController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _basePathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('WebDAV Sync'),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const ValueKey('webdav-endpoint-field'),
              controller: _endpointController,
              decoration: const InputDecoration(
                labelText: 'Endpoint',
                hintText: 'https://example.com/webdav',
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('webdav-username-field'),
              controller: _usernameController,
              decoration: const InputDecoration(labelText: 'Username'),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('webdav-password-field'),
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: _isEditing
                    ? 'Password (leave blank to keep)'
                    : 'Password',
              ),
              obscureText: true,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('webdav-base-path-field'),
              controller: _basePathController,
              decoration: const InputDecoration(labelText: 'Base path'),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _enabled,
              title: const Text('Enable WebDAV sync'),
              onChanged: (value) {
                setState(() {
                  _enabled = value;
                });
              },
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _allowInsecureHttp,
              title: const Text('Allow HTTP endpoint'),
              onChanged: (value) {
                setState(() {
                  _allowInsecureHttp = value ?? false;
                });
              },
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (_isEditing)
          TextButton(
            onPressed: _saving ? null : _delete,
            child: const Text('Remove'),
          ),
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('webdav-save-button'),
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving' : 'Save'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    var allowInsecureHttp = _allowInsecureHttp;
    final endpoint = Uri.tryParse(_endpointController.text.trim());
    if (endpoint?.scheme == 'http' && !allowInsecureHttp) {
      final confirmed = await _confirmDialog(
        context,
        title: 'Use HTTP WebDAV?',
        body:
            'HTTP sync can expose metadata and credentials in transit. Use only for trusted local test servers.',
        confirmLabel: 'Allow HTTP',
        destructive: true,
      );
      if (!confirmed) {
        return;
      }
      allowInsecureHttp = true;
      if (mounted) {
        setState(() {
          _allowInsecureHttp = true;
        });
      }
    }

    setState(() {
      _saving = true;
      _errorMessage = null;
    });
    try {
      await ref
          .read(syncSettingsServiceProvider)
          .saveWebDav(
            WebDavSyncSettingsDraft(
              endpoint: _endpointController.text,
              username: _usernameController.text,
              password: _passwordController.text,
              basePath: _basePathController.text,
              allowInsecureHttp: allowInsecureHttp,
              enabled: _enabled,
            ),
          );
      ref.invalidate(webDavSyncSettingsProvider);
      if (mounted) {
        Navigator.of(context).pop();
        _showSnackBar(context, 'WebDAV sync settings saved.');
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _errorMessage = _syncSettingsErrorMessage(error);
        });
      }
    }
  }

  Future<void> _delete() async {
    final confirmed = await _confirmDialog(
      context,
      title: 'Remove WebDAV sync?',
      body: 'This removes the local WebDAV configuration and stored password.',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (!confirmed) {
      return;
    }
    setState(() {
      _saving = true;
      _errorMessage = null;
    });
    try {
      await ref.read(syncSettingsServiceProvider).deleteWebDav();
      ref.invalidate(webDavSyncSettingsProvider);
      if (mounted) {
        Navigator.of(context).pop();
        _showSnackBar(context, 'WebDAV sync settings removed.');
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _errorMessage = _syncSettingsErrorMessage(error);
        });
      }
    }
  }
}

String _syncSettingsErrorMessage(Object error) {
  if (error is SyncSettingsException) {
    return error.message;
  }
  if (error is SyncDeviceException) {
    return error.message;
  }
  if (error is SyncRunException) {
    return error.message;
  }
  if (error is SyncProviderException) {
    return error.message;
  }
  if (error is VaultException) {
    return error.message;
  }
  return 'Sync settings could not be loaded.';
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border.symmetric(
              horizontal: BorderSide(color: scheme.outlineVariant),
            ),
          ),
          child: Column(
            children: [
              for (var index = 0; index < children.length; index++) ...[
                if (index > 0)
                  Divider(
                    height: 1,
                    indent: 48,
                    color: scheme.outlineVariant.withValues(alpha: 0.72),
                  ),
                children[index],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsStatusPill extends StatelessWidget {
  const _SettingsStatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _SettingsInfoRow extends StatelessWidget {
  const _SettingsInfoRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return _SettingsActionRow(
      icon: icon,
      title: title,
      subtitle: subtitle,
      action: null,
    );
  }
}

class _SettingsActionRow extends StatelessWidget {
  const _SettingsActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.action,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        minLeadingWidth: 28,
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        leading: SizedBox.square(
          dimension: 32,
          child: Icon(icon, size: 19, color: scheme.onSurfaceVariant),
        ),
        title: Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(
            subtitle,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
        trailing: action == null
            ? null
            : Padding(padding: const EdgeInsets.only(left: 16), child: action),
      ),
    );
  }
}

String _vaultStatusPillLabel(VaultState? state) {
  return switch (state) {
    VaultState.uninitialized => 'Vault not created',
    VaultState.locked => 'Vault locked',
    VaultState.unlocked => 'Vault unlocked',
    null => 'Vault loading',
  };
}

String _vaultStateLabel(VaultState? state) {
  return switch (state) {
    VaultState.uninitialized => 'Not created.',
    VaultState.locked => 'Locked. Existing connections keep running.',
    VaultState.unlocked => 'Unlocked for new connection profile resolution.',
    null => 'Preparing encrypted storage.',
  };
}

String _localUnlockLabel(VaultSessionState? session) {
  if (session?.vaultState == VaultState.uninitialized) {
    return 'Create the vault before enabling device-protected unlock.';
  }
  if (session?.localUnlockAvailable == true) {
    return 'Enabled on this device through OS secure storage.';
  }
  return 'Disabled. Passphrase or recovery key is required after lock.';
}

Future<void> _setLocalVaultUnlock(
  BuildContext context,
  WidgetRef ref,
  bool enabled,
) async {
  final confirmed = await _confirmDialog(
    context,
    title: enabled ? 'Enable local unlock?' : 'Disable local unlock?',
    body: enabled
        ? 'Serlink will store a random device key in OS secure storage. Your vault passphrase is not stored.'
        : 'This removes this device key from OS secure storage. Existing connections keep running.',
    confirmLabel: enabled ? 'Enable' : 'Disable',
    destructive: !enabled,
  );
  if (!confirmed) {
    return;
  }
  try {
    if (enabled) {
      await ref
          .read(vaultSessionControllerProvider.notifier)
          .enableLocalUnlock();
    } else {
      await ref
          .read(vaultSessionControllerProvider.notifier)
          .disableLocalUnlock();
    }
    if (context.mounted) {
      _showSnackBar(
        context,
        enabled ? 'Local unlock enabled.' : 'Local unlock disabled.',
      );
    }
  } on Object catch (error) {
    if (context.mounted) {
      _showSnackBar(context, _backupErrorMessage(error));
    }
  }
}

Future<void> _showIdentityManagerDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => const _IdentityManagerDialog(),
  );
}

class _IdentityManagerDialog extends ConsumerWidget {
  const _IdentityManagerDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<IdentityConfig>>(
      future: ref.read(identityRepositoryProvider).list(),
      builder: (context, snapshot) {
        final identities = snapshot.data ?? const <IdentityConfig>[];
        return AlertDialog(
          title: const Text('Credentials'),
          content: SizedBox(
            width: 640,
            child: snapshot.connectionState != ConnectionState.done
                ? const SizedBox(
                    height: 120,
                    child: Center(child: CircularProgressIndicator()),
                  )
                : identities.isEmpty
                ? const SizedBox(
                    height: 120,
                    child: Center(
                      child: Text('No imported credentials are stored yet.'),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: identities.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final identity = identities[index];
                      return ListTile(
                        dense: true,
                        title: Text(identity.displayName),
                        subtitle: Text(
                          [
                            _identityKindLabel(identity.kind),
                            if (identity.usernameHint case final username?)
                              'user $username',
                            if (identity.certificatePrincipal
                                case final principal?)
                              'principal $principal',
                          ].join(' · '),
                        ),
                        trailing: IconButton(
                          tooltip: 'Delete credential',
                          onPressed: () =>
                              _deleteIdentity(context, ref, identity),
                          icon: const Icon(Icons.delete_outline, size: 18),
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }
}

Future<void> _deleteIdentity(
  BuildContext context,
  WidgetRef ref,
  IdentityConfig identity,
) async {
  final hosts = await ref.read(hostRepositoryProvider).list();
  if (!context.mounted) {
    return;
  }
  final linkedHosts = [
    for (final host in hosts)
      if (host.identityIds.contains(identity.id)) host.displayName,
  ];
  final confirmed = await _confirmDialog(
    context,
    title: 'Delete credential?',
    body: linkedHosts.isEmpty
        ? 'This removes the credential and its encrypted secret material.'
        : 'This credential is still linked to: ${linkedHosts.join(', ')}. '
              'Delete it only after removing those host links.',
    confirmLabel: linkedHosts.isEmpty ? 'Delete' : 'Close',
    destructive: linkedHosts.isEmpty,
  );
  if (!confirmed || linkedHosts.isNotEmpty) {
    return;
  }
  try {
    if (identity.secretRecordId case final secretRecordId?) {
      await ref
          .read(syncDeleteTombstoneRepositoryProvider)
          .save(
            SyncDeleteTombstone(
              targetRecordId: secretRecordId,
              targetRecordType: 'identity_secret',
              deletedAt: DateTime.now().toUtc(),
            ),
          );
      await ref.read(vaultRecordRepositoryProvider).delete(secretRecordId);
    }
    await ref
        .read(syncDeleteTombstoneRepositoryProvider)
        .save(
          SyncDeleteTombstone(
            targetRecordId: VaultRecordId('identity:${identity.id.value}'),
            targetRecordType: 'identity',
            deletedAt: DateTime.now().toUtc(),
          ),
        );
    await ref.read(identityRepositoryProvider).delete(identity.id);
    if (context.mounted) {
      Navigator.of(context).pop();
      _showSnackBar(context, 'Credential deleted.');
      await _showIdentityManagerDialog(context, ref);
    }
  } on Object {
    if (context.mounted) {
      _showSnackBar(context, 'Credential could not be deleted.');
    }
  }
}

Future<void> _showKnownHostsDialog(BuildContext context, WidgetRef ref) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => const _KnownHostsDialog(),
  );
}

class _KnownHostsDialog extends ConsumerWidget {
  const _KnownHostsDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<KnownHostRecord>>(
      future: ref.read(knownHostRepositoryProvider).list(),
      builder: (context, snapshot) {
        final records = snapshot.data ?? const <KnownHostRecord>[];
        return AlertDialog(
          title: const Text('Known Hosts'),
          content: SizedBox(
            width: 680,
            child: snapshot.connectionState != ConnectionState.done
                ? const SizedBox(
                    height: 120,
                    child: Center(child: CircularProgressIndicator()),
                  )
                : records.isEmpty
                ? const SizedBox(
                    height: 120,
                    child: Center(
                      child: Text(
                        'No trusted host fingerprints are stored yet.',
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: records.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final record = records[index];
                      return ListTile(
                        dense: true,
                        title: Text('${record.hostname}:${record.port}'),
                        subtitle: Text(
                          '${record.algorithm} · ${record.fingerprint}',
                        ),
                        trailing: IconButton(
                          tooltip: 'Delete known host',
                          onPressed: () =>
                              _deleteKnownHost(context, ref, record),
                          icon: const Icon(Icons.delete_outline, size: 18),
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }
}

Future<void> _deleteKnownHost(
  BuildContext context,
  WidgetRef ref,
  KnownHostRecord record,
) async {
  final confirmed = await _confirmDialog(
    context,
    title: 'Delete known host?',
    body:
        'This removes the stored fingerprint for ${record.hostname}:${record.port}. The next connection will require confirmation again.',
    confirmLabel: 'Delete',
    destructive: true,
  );
  if (!confirmed) {
    return;
  }
  try {
    await ref
        .read(syncDeleteTombstoneRepositoryProvider)
        .save(
          SyncDeleteTombstone(
            targetRecordId: VaultRecordId('known_host:${record.hostId.value}'),
            targetRecordType: 'known_host',
            deletedAt: DateTime.now().toUtc(),
          ),
        );
    await ref.read(knownHostRepositoryProvider).delete(record.hostId);
    if (context.mounted) {
      Navigator.of(context).pop();
      _showSnackBar(context, 'Known host deleted.');
      await _showKnownHostsDialog(context, ref);
    }
  } on Object {
    if (context.mounted) {
      _showSnackBar(context, 'Known host could not be deleted.');
    }
  }
}

Future<void> _exportVaultBackup(BuildContext context, WidgetRef ref) async {
  final confirmed = await _confirmDialog(
    context,
    title: 'Export encrypted backup?',
    body:
        'The backup contains encrypted vault records and the vault header. Keep it private.',
    confirmLabel: 'Export',
  );
  if (!confirmed || !context.mounted) {
    return;
  }

  try {
    final bundle = await ref.read(vaultBackupServiceProvider).exportBackup();
    final location = await getSaveLocation(
      suggestedName: 'serlink-vault-backup.srlkvault',
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Serlink Vault Backup', extensions: ['srlkvault']),
      ],
    );
    if (location == null) {
      return;
    }
    final file = XFile.fromData(
      Uint8List.fromList(bundle.toBytes()),
      mimeType: 'application/json',
      name: 'serlink-vault-backup.srlkvault',
    );
    await file.saveTo(location.path);
    if (context.mounted) {
      _showSnackBar(context, 'Encrypted backup exported.');
    }
  } on Object catch (error) {
    if (context.mounted) {
      _showSnackBar(context, _backupErrorMessage(error));
    }
  }
}

Future<void> _exportHostMetadata(BuildContext context, WidgetRef ref) async {
  try {
    final hosts = await ref.read(hostRepositoryProvider).list();
    hosts.sort(
      (left, right) => left.displayName.toLowerCase().compareTo(
        right.displayName.toLowerCase(),
      ),
    );
    if (!context.mounted) {
      return;
    }
    if (hosts.isEmpty) {
      _showSnackBar(context, 'No hosts are available to export.');
      return;
    }
    final selectedHostIds = await _showHostSelectionDialog(
      context,
      hosts,
      title: 'Export host metadata?',
      description:
          'Exports host names, addresses, usernames, tags, jump host links, and connection options. Credentials and private key material are excluded.',
    );
    if (selectedHostIds == null ||
        selectedHostIds.isEmpty ||
        !context.mounted) {
      return;
    }
    final bundle = await ref
        .read(hostMetadataExportServiceProvider)
        .export(selectedHostIds: selectedHostIds);
    if (!context.mounted) {
      return;
    }
    final location = await getSaveLocation(
      suggestedName: 'serlink-host-metadata.json',
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Serlink Host Metadata', extensions: ['json']),
      ],
    );
    if (location == null) {
      return;
    }
    final file = File(location.path);
    await file.writeAsBytes(bundle.toBytes(), flush: true);
    await LocalFileSecurity.restrictExistingFile(file);
    if (context.mounted) {
      _showSnackBar(context, 'Host metadata exported.');
    }
  } on Object {
    if (context.mounted) {
      _showSnackBar(context, 'Host metadata could not be exported.');
    }
  }
}

Future<void> _exportOpenSshConfig(BuildContext context, WidgetRef ref) async {
  try {
    final hosts = await ref.read(hostRepositoryProvider).list();
    hosts.sort(
      (left, right) => left.displayName.toLowerCase().compareTo(
        right.displayName.toLowerCase(),
      ),
    );
    if (!context.mounted) {
      return;
    }
    if (hosts.isEmpty) {
      _showSnackBar(context, 'No hosts are available to export.');
      return;
    }
    final selectedHostIds = await _showHostSelectionDialog(
      context,
      hosts,
      title: 'Export OpenSSH config?',
      description:
          'Exports selected hosts and any required jump hosts as an OpenSSH config. Credentials and private key material are excluded.',
    );
    if (selectedHostIds == null ||
        selectedHostIds.isEmpty ||
        !context.mounted) {
      return;
    }
    final decision = await ref
        .read(securityModalServiceProvider)
        .confirmExport(
          const ExportPreview(
            title: 'Export OpenSSH config?',
            encrypted: false,
            sensitiveFields: [
              'hostnames',
              'usernames',
              'ports',
              'jump host aliases',
              'connection settings',
            ],
          ),
        );
    if (decision != ExportDecision.confirm || !context.mounted) {
      return;
    }
    final bundle = await ref
        .read(openSshConfigExportServiceProvider)
        .export(selectedHostIds: selectedHostIds);
    final location = await getSaveLocation(
      suggestedName: 'serlink-openssh-config.sshconfig',
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'OpenSSH Config',
          extensions: ['sshconfig', 'config', 'txt'],
        ),
      ],
    );
    if (location == null) {
      return;
    }
    final file = File(location.path);
    await file.writeAsString(bundle.contents, flush: true);
    await LocalFileSecurity.restrictExistingFile(file);
    if (context.mounted) {
      _showSnackBar(context, 'OpenSSH config exported.');
    }
  } on Object catch (error) {
    if (context.mounted) {
      _showSnackBar(context, _openSshConfigExportErrorMessage(error));
    }
  }
}

Future<void> _exportIdentityMetadata(
  BuildContext context,
  WidgetRef ref,
) async {
  final confirmed = await ref
      .read(securityModalServiceProvider)
      .confirmExport(
        const ExportPreview(
          title: 'Export identity metadata?',
          encrypted: false,
          sensitiveFields: [
            'display names',
            'username hints',
            'public key fingerprints',
            'certificate principals',
          ],
        ),
      );
  if (confirmed != ExportDecision.confirm || !context.mounted) {
    return;
  }

  try {
    final bundle = await ref
        .read(identityMetadataExportServiceProvider)
        .export();
    final location = await getSaveLocation(
      suggestedName: 'serlink-identity-metadata.json',
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Serlink Identity Metadata', extensions: ['json']),
      ],
    );
    if (location == null) {
      return;
    }
    final file = File(location.path);
    await file.writeAsBytes(bundle.toBytes(), flush: true);
    await LocalFileSecurity.restrictExistingFile(file);
    if (context.mounted) {
      _showSnackBar(context, 'Identity metadata exported.');
    }
  } on Object catch (error) {
    if (context.mounted) {
      _showSnackBar(context, _identityMetadataExportErrorMessage(error));
    }
  }
}

Future<List<HostId>?> _showHostSelectionDialog(
  BuildContext context,
  List<HostConfig> hosts, {
  required String title,
  required String description,
}) {
  final selected = {for (final host in hosts) host.id};
  return showDialog<List<HostId>>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(title),
            content: SizedBox(
              width: 560,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 320),
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final host in hosts)
                          CheckboxListTile(
                            dense: true,
                            value: selected.contains(host.id),
                            title: Text(host.displayName),
                            subtitle: Text(
                              '${host.username}@${host.hostname}:${host.port}',
                              overflow: TextOverflow.ellipsis,
                            ),
                            onChanged: (value) {
                              setState(() {
                                if (value ?? false) {
                                  selected.add(host.id);
                                } else {
                                  selected.remove(host.id);
                                }
                              });
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    if (selected.length == hosts.length) {
                      selected.clear();
                    } else {
                      selected
                        ..clear()
                        ..addAll(hosts.map((host) => host.id));
                    }
                  });
                },
                child: Text(
                  selected.length == hosts.length ? 'Clear all' : 'Select all',
                ),
              ),
              FilledButton(
                onPressed: selected.isEmpty
                    ? null
                    : () => Navigator.of(
                        context,
                      ).pop(selected.toList(growable: false)),
                child: const Text('Export'),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<void> _exportDiagnosticBundle(
  BuildContext context,
  WidgetRef ref,
) async {
  final confirmed = await _confirmDialog(
    context,
    title: 'Export diagnostic bundle?',
    body:
        'The bundle is redacted and excludes terminal output, commands, hosts, usernames, paths, credentials, and private keys.',
    confirmLabel: 'Export',
  );
  if (!confirmed || !context.mounted) {
    return;
  }

  try {
    final bundle = await ref
        .read(diagnosticBundleServiceProvider)
        .buildRedactedBundle();
    final location = await getSaveLocation(
      suggestedName: 'serlink-diagnostics.json',
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Serlink Diagnostics', extensions: ['json']),
      ],
    );
    if (location == null) {
      return;
    }
    final file = File(location.path);
    await file.writeAsBytes(bundle.bytes, flush: true);
    await LocalFileSecurity.restrictExistingFile(file);
    if (context.mounted) {
      _showSnackBar(context, 'Diagnostic bundle exported.');
    }
  } on Object catch (error) {
    if (context.mounted) {
      _showSnackBar(context, _diagnosticErrorMessage(error));
    }
  }
}

Future<void> _importVaultBackup(BuildContext context, WidgetRef ref) async {
  final file = await openFile(
    acceptedTypeGroups: const [
      XTypeGroup(label: 'Serlink Vault Backup', extensions: ['srlkvault']),
    ],
  );
  if (file == null || !context.mounted) {
    return;
  }

  final confirmed = await _confirmDialog(
    context,
    title: 'Import encrypted backup?',
    body:
        'This replaces the local vault header and merges encrypted records from the selected backup.',
    confirmLabel: 'Import',
    destructive: true,
  );
  if (!confirmed) {
    return;
  }

  try {
    final bundle = VaultBackupBundle.fromBytes(await file.readAsBytes());
    await ref.read(vaultBackupServiceProvider).importBackup(bundle);
    ref.invalidate(vaultSessionControllerProvider);
    ref.invalidate(hostSummariesProvider);
    if (context.mounted) {
      _showSnackBar(context, 'Encrypted backup imported.');
    }
  } on Object catch (error) {
    if (context.mounted) {
      _showSnackBar(context, _backupErrorMessage(error));
    }
  }
}

Future<void> _importOpenSshConfig(BuildContext context, WidgetRef ref) async {
  final file = await openFile();
  if (file == null || !context.mounted) {
    return;
  }

  try {
    final service = ref.read(openSshConfigImportServiceProvider);
    final preview = service.preview(
      await file.readAsString(),
      configSourcePath: file.path,
    );
    if (!context.mounted) {
      return;
    }
    if (preview.entries.isEmpty) {
      if (context.mounted) {
        _showSnackBar(context, 'No importable OpenSSH hosts found.');
      }
      return;
    }
    final confirmed = await _showOpenSshConfigImportDialog(context, preview);
    if (!confirmed || !context.mounted) {
      return;
    }
    final result = await service.applyPreview(
      preview,
      defaultUsername: _defaultImportUsername(),
      configSourcePath: file.path,
    );
    ref.invalidate(hostSummariesProvider);
    if (context.mounted) {
      _showSnackBar(
        context,
        'Imported ${result.hostsCreated} hosts'
        '${result.hostsSkipped == 0 ? '' : ', skipped ${result.hostsSkipped}'}.',
      );
    }
  } on Object catch (error) {
    if (context.mounted) {
      _showSnackBar(context, _importErrorMessage(error));
    }
  }
}

Future<void> _importKnownHosts(BuildContext context, WidgetRef ref) async {
  final file = await openFile();
  if (file == null || !context.mounted) {
    return;
  }

  final confirmed = await _confirmDialog(
    context,
    title: 'Import known_hosts?',
    body:
        'Serlink will import fingerprints that match existing hosts by hostname and port. Hostnames and fingerprints are stored as encrypted vault records.',
    confirmLabel: 'Import',
  );
  if (!confirmed || !context.mounted) {
    return;
  }

  try {
    final result = await ref
        .read(knownHostsImportServiceProvider)
        .importText(await file.readAsString());
    if (context.mounted) {
      _showSnackBar(
        context,
        'Imported ${result.recordsImported} fingerprints'
        '${result.unmatchedHosts == 0 ? '' : ', ${result.unmatchedHosts} unmatched'}.',
      );
    }
  } on Object catch (error) {
    if (context.mounted) {
      _showSnackBar(context, _importErrorMessage(error));
    }
  }
}

Future<void> _importOpenSshCertificate(
  BuildContext context,
  WidgetRef ref,
) async {
  final privateKeyFile = await openFile();
  if (privateKeyFile == null || !context.mounted) {
    return;
  }
  final certificateFile = await openFile();
  if (certificateFile == null || !context.mounted) {
    return;
  }

  try {
    final service = ref.read(openSshCertificateImportServiceProvider);
    final draft = OpenSshCertificateImportDraft(
      privateKeyPem: await privateKeyFile.readAsString(),
      certificateText: await certificateFile.readAsString(),
    );
    final preview = service.preview(draft);
    if (!context.mounted) {
      return;
    }
    final confirmedDraft = await _showOpenSshCertificateImportDialog(
      context,
      draft: draft,
      preview: preview,
    );
    if (confirmedDraft == null || !context.mounted) {
      return;
    }
    final identity = await service.importIdentity(confirmedDraft);
    if (context.mounted) {
      _showSnackBar(context, 'Imported ${identity.displayName}.');
    }
  } on Object catch (error) {
    if (context.mounted) {
      _showSnackBar(context, _importErrorMessage(error));
    }
  }
}

Future<bool> _showOpenSshConfigImportDialog(
  BuildContext context,
  OpenSshConfigImportResult preview,
) async {
  final warnings = preview.warnings.take(4).toList(growable: false);
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return AlertDialog(
        title: const Text('Import OpenSSH config?'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${preview.entries.length} host${preview.entries.length == 1 ? '' : 's'} ready to import'
                '${preview.skippedHosts == 0 ? '' : ', ${preview.skippedHosts} skipped'}.',
              ),
              if (warnings.isNotEmpty) ...[
                const SizedBox(height: 12),
                for (final warning in warnings)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      warning.message,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                if (preview.warnings.length > warnings.length)
                  Text(
                    '${preview.warnings.length - warnings.length} more warnings.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Import'),
          ),
        ],
      );
    },
  );
  return result ?? false;
}

Future<OpenSshCertificateImportDraft?> _showOpenSshCertificateImportDialog(
  BuildContext context, {
  required OpenSshCertificateImportDraft draft,
  required OpenSshCertificateImportPreview preview,
}) {
  return showDialog<OpenSshCertificateImportDraft>(
    context: context,
    barrierDismissible: false,
    builder: (context) =>
        _OpenSshCertificateImportDialog(draft: draft, preview: preview),
  );
}

class _OpenSshCertificateImportDialog extends StatefulWidget {
  const _OpenSshCertificateImportDialog({
    required this.draft,
    required this.preview,
  });

  final OpenSshCertificateImportDraft draft;
  final OpenSshCertificateImportPreview preview;

  @override
  State<_OpenSshCertificateImportDialog> createState() =>
      _OpenSshCertificateImportDialogState();
}

class _OpenSshCertificateImportDialogState
    extends State<_OpenSshCertificateImportDialog> {
  late final TextEditingController _displayNameController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passphraseController;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final comment = widget.preview.comment?.trim();
    _displayNameController = TextEditingController(
      text: comment == null || comment.isEmpty ? '' : 'Certificate $comment',
    );
    _usernameController = TextEditingController();
    _passphraseController = TextEditingController();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _usernameController.dispose();
    _passphraseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final warnings = widget.preview.warnings.take(3).toList(growable: false);
    return AlertDialog(
      title: const Text('Import OpenSSH certificate?'),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ImportPreviewLine(
              label: 'Algorithm',
              value: widget.preview.algorithm,
            ),
            if (widget.preview.comment != null)
              _ImportPreviewLine(
                label: 'Comment',
                value: widget.preview.comment!,
              ),
            if (warnings.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final warning in warnings)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    warning.message,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ],
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('openssh-cert-display-name-field'),
              controller: _displayNameController,
              decoration: const InputDecoration(
                labelText: 'Display name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey('openssh-cert-username-field'),
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'Username hint',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey('openssh-cert-passphrase-field'),
              controller: _passphraseController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Private key passphrase',
                border: OutlineInputBorder(),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _confirm, child: const Text('Import')),
      ],
    );
  }

  void _confirm() {
    final passphrase = _passphraseController.text;
    if (passphrase.trim() != passphrase) {
      setState(() {
        _errorMessage = 'Passphrase cannot have leading or trailing spaces.';
      });
      return;
    }
    Navigator.of(context).pop(
      OpenSshCertificateImportDraft(
        privateKeyPem: widget.draft.privateKeyPem,
        certificateText: widget.draft.certificateText,
        privateKeyPassphrase: passphrase.isEmpty ? null : passphrase,
        displayName: _displayNameController.text,
        usernameHint: _usernameController.text,
      ),
    );
  }
}

class _ImportPreviewLine extends StatelessWidget {
  const _ImportPreviewLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

Future<bool> _confirmDialog(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Theme.of(context).colorScheme.onError,
                  )
                : null,
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return result ?? false;
}

Future<TransferConflictAction?> _showTransferConflictDialog(
  BuildContext context, {
  required String title,
  required String body,
  required String replaceLabel,
}) {
  return showDialog<TransferConflictAction>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(TransferConflictAction.skip),
            child: const Text('Skip'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(TransferConflictAction.rename),
            child: const Text('Rename'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(TransferConflictAction.replace),
            child: Text(replaceLabel),
          ),
        ],
      );
    },
  );
}

String _backupErrorMessage(Object error) {
  if (error is VaultException) {
    return error.message;
  }
  return 'Backup operation failed.';
}

String _diagnosticErrorMessage(Object error) {
  return 'Diagnostic bundle could not be exported.';
}

String _openSshConfigExportErrorMessage(Object error) {
  return 'OpenSSH config could not be exported.';
}

String _identityMetadataExportErrorMessage(Object error) {
  return 'Identity metadata could not be exported.';
}

String _importErrorMessage(Object error) {
  if (error is OpenSshConfigImportException) {
    return error.message;
  }
  if (error is OpenSshCertificateImportException) {
    return error.message;
  }
  if (error is VaultException) {
    return error.message;
  }
  return 'Import failed.';
}

String? _defaultImportUsername() {
  final value =
      Platform.environment['USER'] ?? Platform.environment['USERNAME'];
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

void _showSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(212, 0, 16, 16),
        content: Text(message),
      ),
    );
}

class _PlaceholderSurface extends StatelessWidget {
  const _PlaceholderSurface({
    required this.title,
    required this.body,
    this.action,
  });

  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}
