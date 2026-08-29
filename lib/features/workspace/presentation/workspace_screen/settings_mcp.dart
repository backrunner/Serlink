part of '../workspace_screen.dart';

const String _mcpMaskedToken = '••••••••••••';

/// Settings section for the embedded MCP server: server status and toggle,
/// bearer token, copyable client configs, and the live grant/session lists.
class _McpSettingsSection extends ConsumerWidget {
  const _McpSettingsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final capabilities = ref.watch(platformCapabilitiesProvider);
    final serverState = ref.watch(mcpServerControllerProvider);
    final grants = ref.watch(mcpGrantsProvider).value ?? const <AgentGrant>[];
    final sessions =
        ref.watch(agentSessionsProvider).value ?? const <AgentSessionHandle>[];
    final hostNames = _mcpHostDisplayNames(ref);
    final url = serverState.running && serverState.port != null
        ? 'http://127.0.0.1:${serverState.port}/mcp'
        : null;

    return SurfaceSection(
      key: const ValueKey('settings-mcp-section'),
      title: l10n.settingsMcpSection,
      children: [
        _SettingsActionRow(
          icon: Icons.hub_outlined,
          title: l10n.settingsMcpServerTitle,
          subtitle: _mcpServerSubtitle(l10n, serverState, url),
          action: _SettingsSwitch(
            key: const ValueKey('settings-mcp-server-switch'),
            semanticsLabel: l10n.settingsMcpServerSemantics,
            value: serverState.running,
            onChanged: (value) => unawaited(_setMcpServerEnabled(ref, value)),
          ),
        ),
        _McpTokenRow(token: serverState.token),
        _SettingsActionRow(
          icon: Icons.copy_outlined,
          title: l10n.settingsMcpCopyHttpConfigAction,
          action: _SettingsTextButton.icon(
            key: const ValueKey('settings-mcp-copy-http-config-button'),
            onPressed: url == null
                ? null
                : () => _copyMcpClientConfig(
                    context,
                    _mcpHttpClientConfig(url, serverState.token),
                  ),
            icon: const Icon(Icons.copy_outlined),
            label: Text(l10n.copyAction),
          ),
        ),
        if (capabilities.mcpStdioHelper)
          const _McpStdioConfigRow(),
        _McpListHeader(title: l10n.settingsMcpGrantsTitle),
        if (grants.isEmpty)
          _McpListEmpty(label: l10n.settingsMcpGrantsEmpty)
        else
          for (final grant in grants)
            _SettingsActionRow(
              icon: Icons.verified_user_outlined,
              title: grant.clientName,
              subtitle:
                  '${_mcpHostLabel(hostNames, grant.hostId)} · '
                  '${l10n.settingsMcpGrantExpiry}',
              action: _SettingsTextButton(
                key: ValueKey('settings-mcp-grant-revoke-${grant.grantId}'),
                onPressed: () => ref
                    .read(mcpAuthorizationServiceProvider)
                    .revokeGrant(grant.grantId),
                child: Text(l10n.settingsMcpRevokeAction),
              ),
            ),
        _McpListHeader(title: l10n.settingsMcpSessionsTitle),
        if (sessions.isEmpty)
          _McpListEmpty(label: l10n.settingsMcpSessionsEmpty)
        else
          for (final session in sessions)
            _SettingsActionRow(
              icon: Icons.smart_toy_outlined,
              title: session.clientName,
              subtitle:
                  '${_mcpHostLabel(hostNames, session.hostId)} · '
                  '${session.state.name} · '
                  '${l10n.settingsMcpSessionOpenedAt(_mcpTimeLabel(session.openedAt))}',
              action: _SettingsTextButton(
                key: ValueKey(
                  'settings-mcp-session-close-${session.sessionId.value}',
                ),
                onPressed: () =>
                    unawaited(_closeAgentSession(ref, session.sessionId)),
                child: Text(l10n.closeAction),
              ),
            ),
      ],
    );
  }
}

String _mcpServerSubtitle(
  AppLocalizations l10n,
  McpServerState state,
  String? url,
) {
  final error = state.lastError;
  if (error != null) {
    return l10n.settingsMcpServerError(error);
  }
  if (url != null) {
    return l10n.settingsMcpServerRunning(url);
  }
  return l10n.settingsMcpServerStopped;
}

/// Best-effort host display-name lookup; empty while the vault is locked.
Map<HostId, String> _mcpHostDisplayNames(WidgetRef ref) {
  final vault = ref.watch(vaultSessionControllerProvider).value;
  if (vault == null || vault.vaultState != VaultState.unlocked) {
    return const {};
  }
  final hosts = ref
      .watch(hostSummariesProvider(vault.unlockGeneration))
      .value;
  return {
    for (final host in hosts ?? const <HostSummary>[])
      host.id: host.displayName,
  };
}

String _mcpHostLabel(Map<HostId, String> hostNames, HostId hostId) {
  return hostNames[hostId] ?? hostId.value;
}

String _mcpTimeLabel(DateTime openedAt) {
  final local = openedAt.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

Future<void> _setMcpServerEnabled(WidgetRef ref, bool enabled) async {
  final notifier = ref.read(mcpServerControllerProvider.notifier);
  if (enabled) {
    await notifier.start();
  } else {
    await notifier.stop();
  }
}

Future<void> _closeAgentSession(WidgetRef ref, SessionId sessionId) async {
  try {
    await ref.read(agentSessionBridgeProvider).closeSession(sessionId);
  } on Object {
    // The session may already be gone; the list refresh reflects that.
  }
}

String _mcpHttpClientConfig(String url, String? token) {
  return const JsonEncoder.withIndent('  ').convert({
    'mcpServers': {
      'serlink': {
        'type': 'http',
        'url': url,
        'headers': {'Authorization': 'Bearer ${token ?? ''}'},
      },
    },
  });
}

String _mcpStdioClientConfig(String helperPath) {
  return const JsonEncoder.withIndent('  ').convert({
    'mcpServers': {
      'serlink': {'type': 'stdio', 'command': helperPath},
    },
  });
}

/// The stdio helper ships next to the app executable inside the bundle at
/// `Contents/MacOS/serlink-mcp`.
String _mcpStdioHelperPath() {
  return p.join(File(Platform.resolvedExecutable).parent.path, 'serlink-mcp');
}

/// Existence check for the stdio helper binary. A static seam so widget
/// tests can simulate both the installed and the missing state.
bool Function(String path) mcpStdioHelperFileExists = _fileExistsSync;

bool _fileExistsSync(String path) => File(path).existsSync();

/// Copy-stdio-config row. The helper binary only ships in release bundles
/// (see `tool/build_macos_direct.sh`), so under `flutter run` — where
/// distribution defaults to direct and the row would otherwise look usable —
/// the row renders disabled with an explanation instead.
class _McpStdioConfigRow extends StatelessWidget {
  const _McpStdioConfigRow();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final helperPath = _mcpStdioHelperPath();
    final installed = mcpStdioHelperFileExists(helperPath);
    return _SettingsActionRow(
      icon: Icons.terminal_outlined,
      title: l10n.settingsMcpCopyStdioConfigAction,
      subtitle: installed
          ? l10n.settingsMcpStdioPathHint
          : l10n.settingsMcpStdioNotInstalled,
      action: _SettingsTextButton.icon(
        key: const ValueKey('settings-mcp-copy-stdio-config-button'),
        onPressed: installed
            ? () => _copyMcpClientConfig(
                context,
                _mcpStdioClientConfig(helperPath),
              )
            : null,
        icon: const Icon(Icons.copy_outlined),
        label: Text(l10n.copyAction),
      ),
    );
  }
}

Future<void> _copyMcpClientConfig(BuildContext context, String config) async {
  await Clipboard.setData(ClipboardData(text: config));
  if (context.mounted) {
    _showSnackBar(context, context.l10n.settingsMcpConfigCopied);
  }
}

class _McpTokenRow extends StatefulWidget {
  const _McpTokenRow({required this.token});

  final String? token;

  @override
  State<_McpTokenRow> createState() => _McpTokenRowState();
}

class _McpTokenRowState extends State<_McpTokenRow> {
  var _revealed = false;

  Future<void> _copyToken() async {
    final token = widget.token;
    if (token == null) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: token));
    if (mounted) {
      _showSnackBar(context, context.l10n.settingsMcpTokenCopied);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final token = widget.token;
    return _SettingsActionRow(
      icon: Icons.key_outlined,
      title: l10n.settingsMcpTokenTitle,
      subtitle: token == null
          ? l10n.settingsMcpTokenNotAvailable
          : (_revealed ? token : _mcpMaskedToken),
      action: token == null
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SerlinkIconButton(
                  key: const ValueKey('settings-mcp-token-reveal-button'),
                  tooltip: _revealed
                      ? l10n.settingsMcpTokenHideTooltip
                      : l10n.settingsMcpTokenRevealTooltip,
                  constraints: const BoxConstraints.tightFor(
                    width: 32,
                    height: 32,
                  ),
                  iconSize: 16,
                  onPressed: () => setState(() => _revealed = !_revealed),
                  icon: Icon(
                    _revealed
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                ),
                SerlinkIconButton(
                  key: const ValueKey('settings-mcp-token-copy-button'),
                  tooltip: l10n.settingsMcpTokenCopyTooltip,
                  constraints: const BoxConstraints.tightFor(
                    width: 32,
                    height: 32,
                  ),
                  iconSize: 16,
                  onPressed: () => unawaited(_copyToken()),
                  icon: const Icon(Icons.copy_outlined),
                ),
              ],
            ),
    );
  }
}

class _McpListHeader extends StatelessWidget {
  const _McpListHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 2),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: t.textMuted,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _McpListEmpty extends StatelessWidget {
  const _McpListEmpty({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 2, 10, 6),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: t.textSecondary),
      ),
    );
  }
}
