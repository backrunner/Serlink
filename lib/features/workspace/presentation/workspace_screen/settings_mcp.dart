part of '../workspace_screen.dart';

/// Settings entry for the embedded MCP server: a single status row that
/// opens the agent-access manager dialog (server, token, client config,
/// grants, and sessions).
class _McpSettingsSection extends ConsumerWidget {
  const _McpSettingsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final serverState = ref.watch(mcpServerControllerProvider);
    return _SettingsSection(
      key: const ValueKey('settings-mcp-section'),
      title: l10n.settingsMcpSection,
      icon: Icons.hub_outlined,
      children: [
        _SettingsActionRow(
          icon: Icons.hub_outlined,
          title: l10n.settingsMcpServerTitle,
          subtitle: _mcpServerSubtitle(
            l10n,
            serverState,
            _mcpServerUrl(serverState),
          ),
          action: _SettingsTextButton(
            key: const ValueKey('settings-mcp-manage-button'),
            onPressed: () => _showMcpManagerDialog(context),
            child: Text(l10n.settingsManageAction),
          ),
        ),
      ],
    );
  }
}

String? _mcpServerUrl(McpServerState state) {
  return state.running && state.port != null
      ? 'http://127.0.0.1:${state.port}/mcp'
      : null;
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

Future<void> _showMcpManagerDialog(BuildContext context) {
  return showSerlinkDialog<void>(
    context: context,
    builder: (dialogContext) => const _McpManagerDialog(),
  );
}

enum _McpConfigTab { http, stdio }

class _McpManagerDialog extends ConsumerStatefulWidget {
  const _McpManagerDialog();

  @override
  ConsumerState<_McpManagerDialog> createState() => _McpManagerDialogState();
}

class _McpManagerDialogState extends ConsumerState<_McpManagerDialog> {
  var _tab = _McpConfigTab.http;
  var _installExpanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final capabilities = ref.watch(platformCapabilitiesProvider);
    final serverState = ref.watch(mcpServerControllerProvider);
    final grants = ref.watch(mcpGrantsProvider).value ?? const <AgentGrant>[];
    final sessions =
        ref.watch(agentSessionsProvider).value ?? const <AgentSessionHandle>[];
    final hostNames = _mcpHostDisplayNames(ref);
    final url = _mcpServerUrl(serverState);
    final showStdioTab = capabilities.mcpStdioHelper;

    return SerlinkDialog(
      maxWidth: _adaptiveDialogWidth(context, _dialogWidthManagement),
      title: Text(l10n.settingsMcpSection),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildServerCard(l10n, serverState, url),
            const SizedBox(height: 18),
            _buildConfigGroup(l10n, serverState, url, showStdioTab),
            if (showStdioTab) ...[
              const SizedBox(height: 18),
              _buildInstallGroup(l10n),
            ],
            const SizedBox(height: 18),
            _buildGrantsGroup(l10n, grants, hostNames),
            const SizedBox(height: 18),
            _buildSessionsGroup(l10n, sessions, hostNames),
            const SizedBox(height: 4),
          ],
        ),
      ),
      actions: [
        SerlinkTextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.closeAction),
        ),
      ],
    );
  }

  Widget _buildServerCard(
    AppLocalizations l10n,
    McpServerState serverState,
    String? url,
  ) {
    final t = context.tokens;
    final running = serverState.running;
    final token = serverState.token;
    return _McpCard(
      children: [
        Row(
          children: [
            _McpStatusDot(active: running),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.settingsMcpServerTitle,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: t.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _mcpServerSubtitle(l10n, serverState, url),
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: t.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _SettingsSwitch(
              key: const ValueKey('settings-mcp-server-switch'),
              semanticsLabel: l10n.settingsMcpServerSemantics,
              value: running,
              onChanged: (value) => unawaited(_setMcpServerEnabled(ref, value)),
            ),
          ],
        ),
        const _McpCardGap(),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.key_outlined, size: 16, color: t.textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.settingsMcpTokenTitle,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: t.textMuted,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 3),
                  if (token == null)
                    Text(
                      l10n.settingsMcpTokenNotAvailable,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: t.textMuted),
                    )
                  else
                    SelectableText(
                      token,
                      style: TextStyle(
                        color: t.textSecondary,
                        fontFamily: _mcpMonoFontFamily,
                        fontFamilyFallback: _mcpMonoFontFallback,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                ],
              ),
            ),
            if (token != null) ...[
              const SizedBox(width: 8),
              SerlinkIconButton(
                key: const ValueKey('settings-mcp-token-copy-button'),
                tooltip: l10n.settingsMcpTokenCopyTooltip,
                constraints: const BoxConstraints.tightFor(
                  width: 30,
                  height: 30,
                ),
                iconSize: 15,
                onPressed: () => unawaited(_copyMcpToken(context, token)),
                icon: const Icon(Icons.copy_outlined),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildConfigGroup(
    AppLocalizations l10n,
    McpServerState serverState,
    String? url,
    bool showStdioTab,
  ) {
    final t = context.tokens;
    final effectiveTab = showStdioTab ? _tab : _McpConfigTab.http;
    final helperPath = _mcpStdioHelperPath();
    final helperInstalled = mcpStdioHelperFileExists(helperPath);
    final config = switch (effectiveTab) {
      _McpConfigTab.http =>
        url == null ? null : _mcpHttpClientConfig(url, serverState.token),
      _McpConfigTab.stdio =>
        helperInstalled ? _mcpStdioClientConfig(helperPath) : null,
    };
    final unavailableHint = switch (effectiveTab) {
      _McpConfigTab.http => l10n.settingsMcpHttpConfigNeedsServer,
      _McpConfigTab.stdio => l10n.settingsMcpStdioNotInstalled,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: _McpGroupLabel(title: l10n.settingsMcpConfigTitle)),
            if (showStdioTab)
              SerlinkSegmentedControl<_McpConfigTab>(
                compact: true,
                value: effectiveTab,
                segments: const [
                  SerlinkSegment(
                    value: _McpConfigTab.http,
                    label: 'HTTP',
                    icon: Icons.cloud_outlined,
                  ),
                  SerlinkSegment(
                    value: _McpConfigTab.stdio,
                    label: 'stdio',
                    icon: Icons.terminal_outlined,
                  ),
                ],
                onChanged: (tab) => setState(() => _tab = tab),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: t.surfaceSunken,
            borderRadius: SerlinkRadii.control,
            border: Border.all(color: t.borderSubtle),
          ),
          padding: const EdgeInsets.fromLTRB(12, 4, 6, 4),
          child: config == null
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    unavailableHint,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: t.textMuted),
                  ),
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: SelectableText.rich(
                          TextSpan(
                            style: const TextStyle(
                              fontFamily: _mcpMonoFontFamily,
                              fontFamilyFallback: _mcpMonoFontFallback,
                              fontSize: 11.5,
                              height: 1.45,
                            ).copyWith(color: t.textMuted),
                            children: _jsonHighlightSpans(config, t),
                          ),
                        ),
                      ),
                    ),
                    SerlinkIconButton(
                      key: ValueKey(
                        effectiveTab == _McpConfigTab.http
                            ? 'settings-mcp-copy-http-config-button'
                            : 'settings-mcp-copy-stdio-config-button',
                      ),
                      tooltip: l10n.copyAction,
                      constraints: const BoxConstraints.tightFor(
                        width: 30,
                        height: 30,
                      ),
                      iconSize: 15,
                      onPressed: () => _copyMcpClientConfig(context, config),
                      icon: const Icon(Icons.copy_outlined),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildInstallGroup(AppLocalizations l10n) {
    final t = context.tokens;
    final helperPath = _mcpStdioHelperPath();
    if (!mcpStdioHelperFileExists(helperPath)) {
      return const SizedBox.shrink();
    }
    final installer = ref.watch(agentConfigInstallerProvider);
    final targets = installer.detectInstalledAgents();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SerlinkPressable(
          key: const ValueKey('settings-mcp-install-toggle'),
          onTap: () => setState(() => _installExpanded = !_installExpanded),
          borderRadius: SerlinkRadii.control,
          hoverColor: t.surfaceOverlay,
          pressedColor: t.textPrimary.withValues(alpha: 0.08),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
            child: Row(
              children: [
                _McpGroupLabel(title: l10n.settingsMcpInstallTitle),
                if (targets.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 1.5,
                    ),
                    decoration: BoxDecoration(
                      color: t.surfaceSunken,
                      borderRadius: SerlinkRadii.pill,
                      border: Border.all(color: t.borderSubtle),
                    ),
                    child: Text(
                      '${targets.length}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: t.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                AnimatedRotation(
                  turns: _installExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 150),
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    size: 18,
                    color: t.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: !_installExpanded
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: targets.isEmpty
                      ? _McpEmptyCard(
                          label: l10n.settingsMcpInstallNoneDetected,
                        )
                      : _McpCard(
                          children: [
                            for (
                              var index = 0;
                              index < targets.length;
                              index += 1
                            ) ...[
                              if (index > 0) const _McpCardGap(),
                              _McpListItem.branded(
                                iconAsset: _mcpAgentIconAsset(
                                  targets[index].id,
                                ),
                                title: targets[index].displayName,
                                subtitle: _mcpShortPath(
                                  targets[index].configPath,
                                ),
                                action: _mcpInstallAction(
                                  l10n,
                                  installer,
                                  targets[index],
                                  helperPath,
                                ),
                              ),
                            ],
                          ],
                        ),
                ),
        ),
      ],
    );
  }

  Widget _mcpInstallAction(
    AppLocalizations l10n,
    AgentConfigInstaller installer,
    AgentConfigTarget target,
    String helperPath,
  ) {
    final status = installer.statusFor(target, helperPath: helperPath);
    if (status == AgentConfigStatus.installed) {
      final t = context.tokens;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline, size: 15, color: t.accentPrimary),
          const SizedBox(width: 5),
          Text(
            l10n.settingsMcpInstalledLabel,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: t.accentPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }
    return _SettingsTextButton(
      key: ValueKey('settings-mcp-install-${target.id}'),
      onPressed: () =>
          unawaited(_installAgentConfig(installer, target, helperPath)),
      child: Text(
        status == AgentConfigStatus.outdated
            ? l10n.settingsMcpUpdateAction
            : l10n.settingsMcpInstallAction,
      ),
    );
  }

  Future<void> _installAgentConfig(
    AgentConfigInstaller installer,
    AgentConfigTarget target,
    String helperPath,
  ) async {
    final l10n = context.l10n;
    try {
      await installer.install(target, helperPath: helperPath);
      if (!mounted) {
        return;
      }
      setState(() {});
      _showSnackBar(
        context,
        l10n.settingsMcpInstallSuccess(target.displayName),
      );
    } on Object catch (error) {
      if (mounted) {
        _showSnackBar(context, l10n.settingsMcpInstallFailed('$error'));
      }
    }
  }

  Widget _buildGrantsGroup(
    AppLocalizations l10n,
    List<AgentGrant> grants,
    Map<HostId, String> hostNames,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _McpGroupLabel(title: l10n.settingsMcpGrantsTitle),
        const SizedBox(height: 10),
        if (grants.isEmpty)
          _McpEmptyCard(label: l10n.settingsMcpGrantsEmpty)
        else
          _McpCard(
            children: [
              for (var index = 0; index < grants.length; index += 1) ...[
                if (index > 0) const _McpCardGap(),
                _McpListItem(
                  icon: Icons.verified_user_outlined,
                  title: grants[index].clientName,
                  subtitle:
                      '${_mcpHostLabel(hostNames, grants[index].hostId)} · '
                      '${l10n.settingsMcpGrantExpiry}',
                  action: _SettingsTextButton(
                    key: ValueKey(
                      'settings-mcp-grant-revoke-${grants[index].grantId}',
                    ),
                    onPressed: () => ref
                        .read(mcpAuthorizationServiceProvider)
                        .revokeGrant(grants[index].grantId),
                    child: Text(l10n.settingsMcpRevokeAction),
                  ),
                ),
              ],
            ],
          ),
      ],
    );
  }

  Widget _buildSessionsGroup(
    AppLocalizations l10n,
    List<AgentSessionHandle> sessions,
    Map<HostId, String> hostNames,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _McpGroupLabel(title: l10n.settingsMcpSessionsTitle),
        const SizedBox(height: 10),
        if (sessions.isEmpty)
          _McpEmptyCard(label: l10n.settingsMcpSessionsEmpty)
        else
          _McpCard(
            children: [
              for (var index = 0; index < sessions.length; index += 1) ...[
                if (index > 0) const _McpCardGap(),
                _McpListItem(
                  icon: Icons.smart_toy_outlined,
                  title: sessions[index].clientName,
                  subtitle:
                      '${_mcpHostLabel(hostNames, sessions[index].hostId)} · '
                      '${sessions[index].state.name} · '
                      '${l10n.settingsMcpSessionOpenedAt(_mcpTimeLabel(sessions[index].openedAt))}',
                  action: _SettingsTextButton(
                    key: ValueKey(
                      'settings-mcp-session-close-${sessions[index].sessionId.value}',
                    ),
                    onPressed: () => unawaited(
                      _closeAgentSession(ref, sessions[index].sessionId),
                    ),
                    child: Text(l10n.closeAction),
                  ),
                ),
              ],
            ],
          ),
      ],
    );
  }
}

/// Sunken rounded card grouping rows inside the MCP manager dialog.
class _McpCard extends StatelessWidget {
  const _McpCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      decoration: BoxDecoration(
        color: t.surfaceSunken,
        borderRadius: SerlinkRadii.control,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class _McpCardGap extends StatelessWidget {
  const _McpCardGap();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(height: 20);
  }
}

class _McpStatusDot extends StatelessWidget {
  const _McpStatusDot({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = active ? t.accentPrimary : t.textMuted;
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: active
            ? [BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 6)]
            : null,
      ),
    );
  }
}

class _McpGroupLabel extends StatelessWidget {
  const _McpGroupLabel({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Text(
      title,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: t.textMuted,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
      ),
    );
  }
}

class _McpEmptyCard extends StatelessWidget {
  const _McpEmptyCard({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return _McpCard(
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: t.textSecondary),
        ),
      ],
    );
  }
}

class _McpListItem extends StatelessWidget {
  const _McpListItem({
    required IconData this.icon,
    required this.title,
    required this.subtitle,
    required this.action,
  }) : iconAsset = null;

  const _McpListItem.branded({
    required this.iconAsset,
    required this.title,
    required this.subtitle,
    required this.action,
  }) : icon = null;

  final IconData? icon;
  final String? iconAsset;
  final String title;
  final String subtitle;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final asset = iconAsset;
    return Row(
      children: [
        SizedBox.square(
          dimension: 18,
          child: asset != null
              ? Image.asset(
                  asset,
                  width: 18,
                  height: 18,
                  color: t.textPrimary,
                  colorBlendMode: BlendMode.modulate,
                )
              : Icon(icon, size: 16, color: t.textSecondary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: t.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: t.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        action,
      ],
    );
  }
}

String _mcpAgentIconAsset(String agentId) {
  final name = switch (agentId) {
    'claude-code' => 'claude',
    'cursor' => 'cursor',
    'windsurf' => 'windsurf',
    'kimi-code' => 'kimi',
    'opencode' => 'opencode',
    'codex' => 'openai',
    _ => 'opencode',
  };
  return 'assets/brands/$name.png';
}

String _mcpShortPath(String path) {
  final home = Platform.environment['HOME'] ?? '';
  if (home.isNotEmpty && path.startsWith(home)) {
    return '~${path.substring(home.length)}';
  }
  return path;
}

/// Lightweight JSON syntax highlighting for the client-config preview. A
/// single regex pass: strings are consumed whole (so `:` inside a string is
/// never mistaken for a key separator), and a string becomes a key only when
/// followed by `:`.
final RegExp _jsonTokenPattern = RegExp(
  r'(?<str>"(?:\\.|[^"\\])*")'
  r'|(?<num>-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?)'
  r'|(?<lit>\b(?:true|false|null)\b)',
);

List<TextSpan> _jsonHighlightSpans(String text, SerlinkTokens t) {
  final spans = <TextSpan>[];
  var index = 0;
  for (final match in _jsonTokenPattern.allMatches(text)) {
    if (match.start > index) {
      spans.add(TextSpan(text: text.substring(index, match.start)));
    }
    final token = match.group(0)!;
    final Color color;
    if (match.namedGroup('str') != null) {
      final isKey = text.substring(match.end).trimLeft().startsWith(':');
      color = isKey ? t.accentPrimary : t.statusSuccess;
    } else if (match.namedGroup('num') != null) {
      color = t.statusWarning;
    } else {
      color = t.accentSecondary;
    }
    spans.add(
      TextSpan(
        text: token,
        style: TextStyle(color: color),
      ),
    );
    index = match.end;
  }
  if (index < text.length) {
    spans.add(TextSpan(text: text.substring(index)));
  }
  return spans;
}

/// Explicit monospace stack for code/JSON rendering — the generic 'monospace'
/// alias does not resolve to a real mono face on every platform.
const String _mcpMonoFontFamily = 'Menlo';
const List<String> _mcpMonoFontFallback = [
  'SF Mono',
  'Consolas',
  'Cascadia Mono',
  'DejaVu Sans Mono',
  'Courier New',
];

/// Best-effort host display-name lookup; empty while the vault is locked.
Map<HostId, String> _mcpHostDisplayNames(WidgetRef ref) {
  final vault = ref.watch(vaultSessionControllerProvider).value;
  if (vault == null || vault.vaultState != VaultState.unlocked) {
    return const {};
  }
  final hosts = ref.watch(hostSummariesProvider(vault.unlockGeneration)).value;
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

Future<void> _copyMcpClientConfig(BuildContext context, String config) async {
  await Clipboard.setData(ClipboardData(text: config));
  if (context.mounted) {
    _showSnackBar(context, context.l10n.settingsMcpConfigCopied);
  }
}

Future<void> _copyMcpToken(BuildContext context, String token) async {
  await Clipboard.setData(ClipboardData(text: token));
  if (context.mounted) {
    _showSnackBar(context, context.l10n.settingsMcpTokenCopied);
  }
}
